import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ════════════════════════════════════════════════════════════════════════════════
// SERVICIO DE NOTIFICACIONES WINDOWS — POLLING ROBUSTO
// ════════════════════════════════════════════════════════════════════════════════
//
// ✅ Diseñado específicamente para Windows Desktop (Firebase Messaging NO disponible)
// ✅ Estrategia: Polling Firestore optimizado con deduplicación por ID
// ✅ Previene race conditions, duplicaciones y sobrecarga
// ✅ Compatible con TPV alta frecuencia operaciones
//
// MEJORAS CLAVE vs diseño anterior:
// - ✅ Deduplicación por doc.id (NO por timestamp)
// - ✅ Control concurrencia (_isFetching flag)
// - ✅ Plugin singleton compartido
// - ✅ Backoff exponencial si Firestore falla
// - ✅ Cancelación automática en background
// - ✅ Sin filtros timestamp frágiles
//
// ════════════════════════════════════════════════════════════════════════════════

/// Callback para mostrar notificaciones in-app (SnackBar, overlay, etc).
/// Windows NO soporta notificaciones nativas, así que usamos UI custom.
typedef NotificacionCallback = void Function(String titulo, String cuerpo, String tipo);

/// Servicio de notificaciones para Windows usando polling optimizado.
class NotificacionesWindowsService {
  static final NotificacionesWindowsService _instance =
      NotificacionesWindowsService._();
  factory NotificacionesWindowsService() => _instance;
  NotificacionesWindowsService._();

  Timer? _timer;
  bool _isRunning = false;
  bool _isFetching = false; // 🔴 CRÍTICO: evita race conditions

  DateTime _ultimaConsulta = DateTime.now();

  /// Set de IDs procesados para deduplicación.
  /// VENTAJA: Evita duplicados incluso si Firestore devuelve mismo doc múltiples veces.
  final Set<String> _notificacionesProcesadas = {};

  /// Contador de fallos consecutivos para backoff exponencial.
  int _failCount = 0;

  static const int _maxNotificacionesCache = 1000; // Límite para evitar memory leak

  // Contexto guardado para recalcular timer
  String? _empresaIdActual;
  String? _userIdActual;
  
  // Callback para mostrar notificaciones in-app
  NotificacionCallback? onNotificacion;

  // ── CICLO DE VIDA ─────────────────────────────────────────────────────────────

  /// Inicia el servicio de polling.
  /// [onNotificacion] callback para mostrar notificaciones in-app (SnackBar, overlay).
  Future<void> iniciar(
    String empresaId,
    String userId, {
    NotificacionCallback? onNotificacion,
  }) async {
    if (_isRunning) {
      debugPrint('⚠️ NotificacionesWindowsService ya está corriendo');
      return;
    }

    // Guardar contexto
    _empresaIdActual = empresaId;
    _userIdActual = userId;
    this.onNotificacion = onNotificacion;

    _isRunning = true;
    _failCount = 0;

    debugPrint('🔔 NotificacionesWindowsService iniciado');
    debugPrint('   Empresa: $empresaId');
    debugPrint('   Usuario: $userId');
    debugPrint('   Callback: ${onNotificacion != null ? 'Sí' : 'No'}');
    debugPrint('   Intervalo inicial: ${_interval.inSeconds}s');

    // Ejecutar inmediatamente al iniciar
    _tick(empresaId, userId);

    // Luego cada intervalo
    _timer = Timer.periodic(_interval, (_) => _tick(empresaId, userId));
  }

  /// Detiene el servicio.
  void detener() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _failCount = 0;
    _empresaIdActual = null;
    _userIdActual = null;

    debugPrint('🔔 NotificacionesWindowsService detenido');
  }

  // ── LÓGICA DE POLLING ─────────────────────────────────────────────────────────

  /// Tick del timer periódico.
  Future<void> _tick(String empresaId, String userId) async {
    // 🔴 CRÍTICO: Evitar solapamiento de requests
    if (_isFetching) {
      debugPrint('⏭️ Polling ya en curso, skip');
      return;
    }

    // 🔴 CRÍTICO: Cancelar si app está en background (optimización Windows)
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      debugPrint('⏸️ App en background, skip polling');
      return;
    }

    _isFetching = true;

    try {
      await _verificar(empresaId, userId);

      // Éxito: resetear contador de fallos
      if (_failCount > 0) {
        debugPrint('✅ Recuperado tras $_failCount intentos fallidos');
        _failCount = 0;
        _recalcularIntervalo(); // Volver a intervalo normal
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error en polling notificaciones: $e');
      debugPrint('   Stack: $stackTrace');

      _failCount++;

      // Backoff exponencial
      _recalcularIntervalo();

      debugPrint('   Reintentos fallidos: $_failCount');
      debugPrint('   Próximo intento en: ${_interval.inSeconds}s');
    } finally {
      _isFetching = false;
    }
  }

  /// Verifica nuevas notificaciones en Firestore.
  Future<void> _verificar(String empresaId, String userId) async {
    // ✅ Query optimizada: SIN filtro por timestamp (evita race conditions)
    final snap = await FirebaseFirestore.instance
        .collection('empresas/$empresaId/notificaciones')
        .where('usuario_id', isEqualTo: userId)
        .where('leida', isEqualTo: false)
        .orderBy('creada', descending: true)
        .limit(20) // Suficiente para polling cada 30s
        .get(const GetOptions(source: Source.server)); // 🔴 Forzar server (NO cache)

    if (snap.docs.isEmpty) {
      // No hay notificaciones nuevas
      return;
    }

    debugPrint('📬 Encontradas ${snap.docs.length} notificaciones no leídas');

    for (final doc in snap.docs) {
      final id = doc.id;

      // ✅ Deduplicación por ID (la clave de todo)
      if (_notificacionesProcesadas.contains(id)) {
        continue; // Ya procesada
      }

      // Marcar como procesada ANTES de mostrar (previene duplicados si crashea)
      _notificacionesProcesadas.add(id);

      // Limpiar cache si crece mucho (evitar memory leak)
      if (_notificacionesProcesadas.length > _maxNotificacionesCache) {
        final antiguos = _notificacionesProcesadas.take(500).toList();
        _notificacionesProcesadas.removeAll(antiguos);
        debugPrint('🧹 Limpieza cache: removidos 500 IDs antiguos');
      }

      // Mostrar notificación local
      try {
        await _mostrar(doc.data(), id);
      } catch (e) {
        debugPrint('⚠️ Error mostrando notificación $id: $e');
        // Continuar con siguientes notificaciones
      }
    }

    _ultimaConsulta = DateTime.now();
  }

  /// Muestra una notificación usando callback (in-app para Windows).
  Future<void> _mostrar(Map<String, dynamic> data, String docId) async {
    final titulo = data['titulo'] as String? ?? 'Nueva notificación';
    final cuerpo = data['cuerpo'] as String? ?? '';
    final tipo = data['tipo'] as String? ?? 'general';

    debugPrint('🔔 Nueva notificación: $titulo');
    debugPrint('   Cuerpo: $cuerpo');
    debugPrint('   Tipo: $tipo');
    debugPrint('   ID: $docId');

    // Llamar callback si está configurado
    if (onNotificacion != null) {
      try {
        onNotificacion!(titulo, cuerpo, tipo);
      } catch (e) {
        debugPrint('⚠️ Error en callback notificación: $e');
      }
    } else {
      debugPrint('⚠️ No hay callback configurado, notificación no mostrada');
    }
  }

  // ── BACKOFF EXPONENCIAL ───────────────────────────────────────────────────────

  /// Intervalo de polling con backoff exponencial.
  Duration get _interval {
    if (_failCount == 0) {
      return const Duration(seconds: 30); // Normal: 30s
    }

    // Backoff exponencial: 30s → 60s → 120s (max 2min)
    final seconds = min(120, 30 * (1 << _failCount));
    return Duration(seconds: seconds);
  }

  /// Recalcula el timer con nuevo intervalo tras cambio en _failCount.
  void _recalcularIntervalo() {
    if (!_isRunning) return;

    // Cancelar timer actual
    _timer?.cancel();

    // Verificar que tenemos contexto
    if (_empresaIdActual == null || _userIdActual == null) {
      debugPrint('⚠️ No hay contexto guardado, deteniendo servicio');
      detener();
      return;
    }

    // Reconfigurar timer con nuevo intervalo
    _timer = Timer.periodic(_interval, (_) {
      _tick(_empresaIdActual!, _userIdActual!);
    });

    debugPrint('🔄 Timer reconfigurado: intervalo ${_interval.inSeconds}s');
  }

  // ── UTILIDADES ────────────────────────────────────────────────────────────────

  /// Fuerza un check inmediato (útil para testing o eventos manuales).
  Future<void> checkAhora(String empresaId, String userId) async {
    if (_isFetching) {
      debugPrint('⏳ Check ya en curso, esperando...');
      return;
    }

    debugPrint('🔍 Check manual de notificaciones');
    await _tick(empresaId, userId);
  }

  /// Limpia el cache de notificaciones procesadas (útil tras logout/login).
  void limpiarCache() {
    _notificacionesProcesadas.clear();
    debugPrint('🧹 Cache de notificaciones limpiado');
  }

  /// Estado actual del servicio.
  bool get estaActivo => _isRunning;
  int get notificacionesProcesadas => _notificacionesProcesadas.length;
  int get fallosConsecutivos => _failCount;
}

// ════════════════════════════════════════════════════════════════════════════════
// MEJORAS OPCIONALES AVANZADAS
// ════════════════════════════════════════════════════════════════════════════════

/// Extensión para marcar notificaciones como leídas en Firestore.
/// USO: Desde UI cuando usuario ve la notificación.
extension NotificacionesFirestoreExt on NotificacionesWindowsService {
  Future<void> marcarComoLeida(String empresaId, String notificacionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('empresas/$empresaId/notificaciones')
          .doc(notificacionId)
          .update({'leida': true, 'leida_en': FieldValue.serverTimestamp()});

      debugPrint('✅ Notificación $notificacionId marcada como leída');
    } catch (e) {
      debugPrint('⚠️ Error marcando notificación como leída: $e');
    }
  }

  /// Obtiene el badge count actual (notificaciones no leídas).
  Future<int> obtenerBadgeCount(String empresaId, String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas/$empresaId/notificaciones')
          .where('usuario_id', isEqualTo: userId)
          .where('leida', isEqualTo: false)
          .count()
          .get();

      return snap.count ?? 0;
    } catch (e) {
      debugPrint('⚠️ Error obteniendo badge count: $e');
      return 0;
    }
  }
}






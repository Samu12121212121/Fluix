// ═════════════════════════════════════════════════════════════════════════════
// SERVICIO DE SUSCRIPCIÓN — Lee la suscripción de Firestore y expone
// métodos para verificar módulos, packs y addons dinámicamente.
// ═════════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:planeag_flutter/core/config/planes_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: Datos de suscripción cacheados
// ─────────────────────────────────────────────────────────────────────────────

class DatosSuscripcion {
  final String planBase;
  final List<String> packsActivos;
  final List<String> addonsActivos;
  final int empleadosNomina;
  final double precioTotal;
  final String estado; // ACTIVA, VENCIDA, SUSPENDIDA, PRUEBA
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final DateTime? fechaActualizacion;

  // Campos legacy para compatibilidad
  final String? planLegacy; // campo 'plan' viejo
  final String? planNombre;

  const DatosSuscripcion({
    required this.planBase,
    required this.packsActivos,
    required this.addonsActivos,
    required this.empleadosNomina,
    required this.precioTotal,
    required this.estado,
    this.fechaInicio,
    this.fechaFin,
    this.fechaActualizacion,
    this.planLegacy,
    this.planNombre,
  });

  factory DatosSuscripcion.fromMap(Map<String, dynamic> data) {
    return DatosSuscripcion(
      planBase: data['plan_base'] as String? ?? 'basico',
      packsActivos: _toStringList(data['packs_activos']),
      addonsActivos: _toStringList(data['addons_activos']),
      empleadosNomina: (data['empleados_nomina'] as num?)?.toInt() ?? 0,
      precioTotal: (data['precio_total'] as num?)?.toDouble() ?? 0,
      estado: data['estado'] as String? ?? 'ACTIVA',
      fechaInicio: _toDateTime(data['fecha_inicio']),
      fechaFin: _toDateTime(data['fecha_fin']),
      fechaActualizacion: _toDateTime(data['fecha_actualizacion']),
      planLegacy: data['plan'] as String?,
      planNombre: data['plan_nombre'] as String?,
    );
  }

  /// Si la suscripción está activa (no vencida ni suspendida)
  bool get estaActiva => estado == 'ACTIVA' || estado == 'PRUEBA';

  /// Si está en periodo de prueba
  bool get esPrueba => estado == 'PRUEBA';

  /// Días restantes (-1 si no hay fecha fin)
  int get diasRestantes {
    if (fechaFin == null) return -1;
    return fechaFin!.difference(DateTime.now()).inDays;
  }

  /// Módulos activos calculados dinámicamente
  List<String> get modulosActivos => PlanesConfig.getModulosActivos(
        packsActivos: packsActivos,
        addonsActivos: addonsActivos,
      );

  Map<String, dynamic> toMap() => {
        'plan_base': planBase,
        'packs_activos': packsActivos,
        'addons_activos': addonsActivos,
        'empleados_nomina': empleadosNomina,
        'precio_total': precioTotal,
        'estado': estado,
        if (fechaInicio != null)
          'fecha_inicio': Timestamp.fromDate(fechaInicio!),
        if (fechaFin != null) 'fecha_fin': Timestamp.fromDate(fechaFin!),
        'fecha_actualizacion': FieldValue.serverTimestamp(),
      };

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SERVICIO SINGLETON
// ═════════════════════════════════════════════════════════════════════════════

class SuscripcionService {
  static final SuscripcionService _instancia = SuscripcionService._();
  factory SuscripcionService() => _instancia;
  SuscripcionService._();

  final _db = FirebaseFirestore.instance;

  DatosSuscripcion? _cache;
  String? _empresaIdCacheado;

  /// Datos cacheados (null si no se han cargado)
  DatosSuscripcion? get suscripcion => _cache;

  // ── CARGA DE DATOS ─────────────────────────────────────────────────────────

  /// Carga (o recarga) la suscripción de la empresa.
  /// Soporta tanto el formato nuevo (packs_activos, addons_activos)
  /// como el formato legacy (plan + modulos_activos).
  Future<DatosSuscripcion?> cargarSuscripcion(String empresaId) async {
    try {
      final doc = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('suscripcion')
          .doc('actual')
          .get();

      if (!doc.exists) {
        _cache = null;
        _empresaIdCacheado = null;
        return null;
      }

      final data = doc.data()!;

      // ¿Tiene el formato nuevo (V2)?
      if (data.containsKey('packs_activos') ||
          data.containsKey('plan_base')) {
        _cache = DatosSuscripcion.fromMap(data);
      } else {
        // Formato legacy: inferir packs/addons desde modulos_activos
        _cache = _convertirDesdeFormatoLegacy(data);
      }

      _empresaIdCacheado = empresaId;
      return _cache;
    } catch (e) {
      debugPrint('Error cargando suscripción: $e');
      return null;
    }
  }

  /// Stream reactivo de la suscripción
  Stream<DatosSuscripcion?> streamSuscripcion(String empresaId) {
    return _db
        .collection('empresas')
        .doc(empresaId)
        .collection('suscripcion')
        .doc('actual')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      final data = doc.data()!;
      if (data.containsKey('packs_activos') ||
          data.containsKey('plan_base')) {
        _cache = DatosSuscripcion.fromMap(data);
      } else {
        _cache = _convertirDesdeFormatoLegacy(data);
      }
      _empresaIdCacheado = empresaId;
      return _cache;
    });
  }

  // ── VERIFICACIONES DE MÓDULOS ──────────────────────────────────────────────

  /// ¿La suscripción incluye este módulo?
  /// Combina: suscripción activa + módulo en el plan.
  bool tieneModulo(String moduloId) {
    if (_cache == null) return false;
    if (!_cache!.estaActiva) return false;
    return PlanesConfig.moduloDisponible(
      moduloId: moduloId,
      packsActivos: _cache!.packsActivos,
      addonsActivos: _cache!.addonsActivos,
    );
  }

  /// ¿La empresa tiene contratado este pack?
  bool tienePack(String packId) {
    if (_cache == null) return false;
    return _cache!.packsActivos.contains(packId);
  }

  /// ¿La empresa tiene contratado este addon?
  bool tieneAddon(String addonId) {
    if (_cache == null) return false;
    return _cache!.addonsActivos.contains(addonId);
  }

  /// Lista de módulos activos según el plan contratado.
  List<String> getModulosActivos() {
    if (_cache == null) return PlanesConfig.planBase.modulosIncluidos;
    return _cache!.modulosActivos;
  }

  /// ¿La suscripción está activa?
  bool get estaActiva => _cache?.estaActiva ?? false;

  /// Estado textual (ACTIVA, VENCIDA, etc.)
  String get estado => _cache?.estado ?? 'DESCONOCIDO';

  // ── LIMPIEZA ───────────────────────────────────────────────────────────────

  void limpiar() {
    _cache = null;
    _empresaIdCacheado = null;
  }

  // ── CONVERSIÓN LEGACY ──────────────────────────────────────────────────────

  /// Convierte el formato antiguo de Firestore al nuevo modelo.
  /// Infiere packs y addons desde la lista de módulos activos.
  DatosSuscripcion _convertirDesdeFormatoLegacy(Map<String, dynamic> data) {
    final modulosLegacy = DatosSuscripcion._toStringList(
      data['modulos_activos'],
    );

    final packs = <String>[];
    final addons = <String>[];

    // Inferir packs
    if (modulosLegacy.contains('facturacion') ||
        modulosLegacy.contains('vacaciones')) {
      packs.add('gestion');
    }
    if (modulosLegacy.contains('pedidos')) {
      packs.add('tienda');
    }

    // Inferir addons
    if (modulosLegacy.contains('whatsapp')) addons.add('whatsapp');
    if (modulosLegacy.contains('tareas')) addons.add('tareas');
    if (modulosLegacy.contains('nominas')) addons.add('nominas');

    final precioTotal = PlanesConfig.calcularPrecioTotal(
      packsActivos: packs,
      addonsActivos: addons,
    );

    return DatosSuscripcion(
      planBase: 'basico',
      packsActivos: packs,
      addonsActivos: addons,
      empleadosNomina: 0,
      precioTotal: precioTotal,
      estado: data['estado'] as String? ?? 'ACTIVA',
      fechaInicio: DatosSuscripcion._toDateTime(data['fecha_inicio']),
      fechaFin: DatosSuscripcion._toDateTime(data['fecha_fin']),
      fechaActualizacion:
          DatosSuscripcion._toDateTime(data['fecha_actualizacion']),
      planLegacy: data['plan'] as String?,
      planNombre: data['plan_nombre'] as String?,
    );
  }
}


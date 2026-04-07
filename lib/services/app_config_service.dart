import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio que persiste la configuración de la app:
/// modo oscuro, color primario, y preferencias de notificaciones.
class AppConfigService {
  static final AppConfigService _i = AppConfigService._();
  factory AppConfigService() => _i;
  AppConfigService._();

  // ── Claves SharedPreferences ──────────────────────────────────────────────
  static const _kTema            = 'tema_modo';          // 'claro' | 'oscuro' | 'sistema'
  static const _kColor           = 'color_primario';     // int (ARGB)
  static const _kNotifReservas   = 'notif_reservas';
  static const _kNotifPedidos    = 'notif_pedidos';
  static const _kNotifValoraciones = 'notif_valoraciones';
  static const _kNotifSuscripcion  = 'notif_suscripcion';
  static const _kNotifCancelaciones = 'notif_cancelaciones';

  // ── Color por defecto ────────────────────────────────────────────────────
  static const int colorPorDefecto = 0xFF1976D2; // Azul

  // ── 8 colores de acento disponibles ──────────────────────────────────────
  static const List<Map<String, dynamic>> coloresDisponibles = [
    {'nombre': 'Azul',        'valor': 0xFF1976D2},
    {'nombre': 'Azul marino', 'valor': 0xFF0D47A1},
    {'nombre': 'Índigo',      'valor': 0xFF3949AB},
    {'nombre': 'Morado',      'valor': 0xFF7B1FA2},
    {'nombre': 'Verde',       'valor': 0xFF2E7D32},
    {'nombre': 'Teal',        'valor': 0xFF00796B},
    {'nombre': 'Naranja',     'valor': 0xFFE65100},
    {'nombre': 'Rojo',        'valor': 0xFFC62828},
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // TEMA
  // ─────────────────────────────────────────────────────────────────────────

  Future<ThemeMode> cargarTema() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(_kTema) ?? 'claro';
    return _stringToThemeMode(val);
  }

  Future<void> guardarTema(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTema, _themeModeToString(mode));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COLOR PRIMARIO
  // ─────────────────────────────────────────────────────────────────────────

  Future<Color> cargarColor() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getInt(_kColor) ?? colorPorDefecto;
    return Color(val);
  }

  Future<void> guardarColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kColor, color.toARGB32());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NOTIFICACIONES
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, bool>> cargarNotificaciones() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'reservas':     prefs.getBool(_kNotifReservas)     ?? true,
      'pedidos':      prefs.getBool(_kNotifPedidos)      ?? true,
      'valoraciones': prefs.getBool(_kNotifValoraciones) ?? true,
      'suscripcion':  prefs.getBool(_kNotifSuscripcion)  ?? true,
      'cancelaciones':prefs.getBool(_kNotifCancelaciones)?? true,
    };
  }

  Future<void> guardarNotificacion(String clave, bool valor) async {
    final prefs = await SharedPreferences.getInstance();
    final keyMap = {
      'reservas':     _kNotifReservas,
      'pedidos':      _kNotifPedidos,
      'valoraciones': _kNotifValoraciones,
      'suscripcion':  _kNotifSuscripcion,
      'cancelaciones':_kNotifCancelaciones,
    };
    if (keyMap.containsKey(clave)) {
      await prefs.setBool(keyMap[clave]!, valor);
      // Sincronizar con Firestore si hay usuario logueado
      _sincronizarNotifFirestore(clave, valor);
    }
  }

  void _sincronizarNotifFirestore(String clave, bool valor) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .set({'preferencias_notificaciones': {clave: valor}},
            SetOptions(merge: true))
        .catchError((_) {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BACKUP — exportar datos de la empresa a Firestore
  // ─────────────────────────────────────────────────────────────────────────

  Future<BackupResult> realizarBackup(String empresaId) async {
    try {
      final db = FirebaseFirestore.instance;
      final empresa = db.collection('empresas').doc(empresaId);

      // Colecciones a respaldar
      final colecciones = [
        'clientes', 'empleados', 'servicios', 'reservas',
        'valoraciones', 'pedidos', 'productos', 'facturas',
        'transacciones', 'tareas', 'secciones_web',
      ];

      final Map<String, dynamic> backupData = {
        'fecha': FieldValue.serverTimestamp(),
        'fecha_legible': DateTime.now().toIso8601String(),
        'empresa_id': empresaId,
        'version': 1,
        'colecciones': {},
      };

      int totalDocs = 0;

      for (final col in colecciones) {
        try {
          final snap = await empresa.collection(col).limit(500).get();
          final docs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          (backupData['colecciones'] as Map)[col] = docs;
          totalDocs += docs.length;
        } catch (_) {
          (backupData['colecciones'] as Map)[col] = [];
        }
      }

      // También el perfil de la empresa
      final perfilSnap = await empresa.get();
      backupData['perfil'] = perfilSnap.data() ?? {};

      // Guardar el backup en Firestore bajo empresa/backups
      final backupRef = await empresa
          .collection('backups')
          .add(backupData);

      // Mantener solo los últimos 5 backups
      final backupsSnap = await empresa
          .collection('backups')
          .orderBy('fecha', descending: true)
          .get();

      if (backupsSnap.docs.length > 5) {
        final batch = db.batch();
        for (final old in backupsSnap.docs.skip(5)) {
          batch.delete(old.reference);
        }
        await batch.commit();
      }

      return BackupResult(
        exito: true,
        mensaje: '$totalDocs documentos respaldados correctamente',
        backupId: backupRef.id,
        fecha: DateTime.now(),
        totalDocumentos: totalDocs,
      );
    } catch (e) {
      return BackupResult(
        exito: false,
        mensaje: 'Error al realizar backup: $e',
        backupId: null,
        fecha: DateTime.now(),
        totalDocumentos: 0,
      );
    }
  }

  /// Devuelve lista de backups anteriores
  Future<List<Map<String, dynamic>>> obtenerBackups(String empresaId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('backups')
          .orderBy('fecha', descending: true)
          .limit(5)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  ThemeMode _stringToThemeMode(String s) {
    switch (s) {
      case 'oscuro':  return ThemeMode.dark;
      case 'sistema': return ThemeMode.system;
      default:        return ThemeMode.light;
    }
  }

  String _themeModeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:   return 'oscuro';
      case ThemeMode.system: return 'sistema';
      default:               return 'claro';
    }
  }
}

class BackupResult {
  final bool exito;
  final String mensaje;
  final String? backupId;
  final DateTime fecha;
  final int totalDocumentos;

  const BackupResult({
    required this.exito,
    required this.mensaje,
    required this.backupId,
    required this.fecha,
    required this.totalDocumentos,
  });
}


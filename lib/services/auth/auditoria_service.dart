import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

// ─────────────────────────────────────────────────────────────────────────────
// MODELO
// ─────────────────────────────────────────────────────────────────────────────

enum TipoEventoAuditoria {
  loginOk,
  loginFallido,
  logout,
  sesionExpirada,
}

extension TipoEventoX on TipoEventoAuditoria {
  String get nombre {
    switch (this) {
      case TipoEventoAuditoria.loginOk:       return 'login_ok';
      case TipoEventoAuditoria.loginFallido:  return 'login_fallido';
      case TipoEventoAuditoria.logout:        return 'logout';
      case TipoEventoAuditoria.sesionExpirada: return 'sesion_expirada';
    }
  }

  String get emoji {
    switch (this) {
      case TipoEventoAuditoria.loginOk:       return '✅';
      case TipoEventoAuditoria.loginFallido:  return '❌';
      case TipoEventoAuditoria.logout:        return '🚪';
      case TipoEventoAuditoria.sesionExpirada: return '⏰';
    }
  }
}

enum MetodoAuth { email, google, apple }

class EventoAuditoria {
  final String id;
  final String? usuarioId;
  final String? empresaId;
  final String email;
  final String? rol;
  final TipoEventoAuditoria tipo;
  final DateTime timestamp;
  final Map<String, String> dispositivo;
  final MetodoAuth metodo;
  final String? mensajeError;

  const EventoAuditoria({
    required this.id,
    this.usuarioId,
    this.empresaId,
    required this.email,
    this.rol,
    required this.tipo,
    required this.timestamp,
    required this.dispositivo,
    required this.metodo,
    this.mensajeError,
  });

  factory EventoAuditoria.fromFirestore(String id, Map<String, dynamic> data) =>
      EventoAuditoria(
        id: id,
        usuarioId: data['usuario_id'] as String?,
        empresaId: data['empresa_id'] as String?,
        email: data['email'] as String? ?? '',
        rol: data['rol'] as String?,
        tipo: TipoEventoAuditoria.values.firstWhere(
          (e) => e.nombre == (data['tipo'] as String? ?? ''),
          orElse: () => TipoEventoAuditoria.loginFallido,
        ),
        timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        dispositivo: Map<String, String>.from(data['dispositivo'] ?? {}),
        metodo: MetodoAuth.values.firstWhere(
          (m) => m.name == (data['metodo'] as String? ?? ''),
          orElse: () => MetodoAuth.email,
        ),
        mensajeError: data['mensaje_error'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO
// Estructura Firestore:
//   auditoria/{empresaId}/accesos/{autoId}
// ─────────────────────────────────────────────────────────────────────────────

class AuditoriaService {
  static final AuditoriaService _i = AuditoriaService._();
  factory AuditoriaService() => _i;
  AuditoriaService._();

  final _db = FirebaseFirestore.instance;

  // ── REGISTRAR EVENTO ────────────────────────────────────────────────────

  Future<void> registrar({
    required TipoEventoAuditoria tipo,
    required String email,
    required MetodoAuth metodo,
    String? usuarioId,
    String? empresaId,
    String? rol,
    String? mensajeError,
  }) async {
    try {
      final device = await _infoDispositivo();
      final target = empresaId ?? 'desconocido';

      await _db
          .collection('auditoria')
          .doc(target)
          .collection('accesos')
          .add({
        'usuario_id':     usuarioId,
        'empresa_id':     empresaId,
        'email':          email,
        'rol':            rol,
        'tipo':           tipo.nombre,
        'timestamp':      FieldValue.serverTimestamp(),
        'dispositivo':    device,
        'metodo':         metodo.name,
        'mensaje_error':  mensajeError,
      });
    } catch (e) {
      // Auditoria no bloquea el flujo principal
    }
  }

  // ── LEER EVENTOS ────────────────────────────────────────────────────────

  Stream<List<EventoAuditoria>> eventosStream(String empresaId) =>
      _db
          .collection('auditoria')
          .doc(empresaId)
          .collection('accesos')
          .orderBy('timestamp', descending: true)
          .limit(200)
          .snapshots()
          .map((s) => s.docs
              .map((d) => EventoAuditoria.fromFirestore(d.id, d.data()))
              .toList());

  /// true si hay logins fallidos de cualquier usuario en las últimas 24h.
  Future<bool> hayLoginsFallidosRecientes(String empresaId) async {
    final hace24h = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)));
    final snap = await _db
        .collection('auditoria')
        .doc(empresaId)
        .collection('accesos')
        .where('tipo', isEqualTo: TipoEventoAuditoria.loginFallido.nombre)
        .where('timestamp', isGreaterThan: hace24h)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ── PRIVADO: info del dispositivo ────────────────────────────────────────

  Future<Map<String, String>> _infoDispositivo() async {
    String modelo = 'desconocido';
    String os = 'desconocido';
    String version = '';

    try {
      final pi = await PackageInfo.fromPlatform();
      version = '${pi.version}+${pi.buildNumber}';
    } catch (_) {}

    try {
      if (!kIsWeb) {
        final info = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final a = await info.androidInfo;
          modelo = '${a.manufacturer} ${a.model}';
          os = 'Android ${a.version.release}';
        } else if (Platform.isIOS) {
          final i = await info.iosInfo;
          modelo = i.model;
          os = 'iOS ${i.systemVersion}';
        }
      }
    } catch (_) {}

    return {'modelo': modelo, 'os': os, 'version_app': version};
  }
}


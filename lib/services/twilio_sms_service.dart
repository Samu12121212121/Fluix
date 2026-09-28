import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ia_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO TWILIO SMS
//
// Credenciales guardadas en:
//   usuarios/{uid}/configuracion/api_keys
//   → twilio_sid    : ACxxxxxxxxxxxxxxxxx
//   → twilio_token  : auth token
//   → twilio_from   : +1234567890 (número Twilio)
//
// Uso rápido:
//   final ok = await TwilioSmsService().enviarSMS('+34666123456', 'Hola!');
// ─────────────────────────────────────────────────────────────────────────────

class TwilioSmsService {
  static final TwilioSmsService _i = TwilioSmsService._();
  factory TwilioSmsService() => _i;
  TwilioSmsService._();

  final _ia  = IaService();
  final _db  = FirebaseFirestore.instance;

  // ── Credenciales ──────────────────────────────────────────────────────────

  Future<_TwilioCreds?> _credenciales() async {
    final sid   = await _ia.obtenerApiKey('twilio_sid');
    final token = await _ia.obtenerApiKey('twilio_token');
    final from  = await _ia.obtenerApiKey('twilio_from');
    if (sid == null || sid.isEmpty) return null;
    if (token == null || token.isEmpty) return null;
    if (from == null || from.isEmpty) return null;
    return _TwilioCreds(sid: sid, token: token, from: from);
  }

  Future<bool> estaConfigurado() async => (await _credenciales()) != null;

  Future<void> guardarCredenciales({
    required String sid,
    required String token,
    required String from,
  }) async {
    await Future.wait([
      _ia.guardarApiKey('twilio_sid',   sid.trim()),
      _ia.guardarApiKey('twilio_token', token.trim()),
      _ia.guardarApiKey('twilio_from',  _normalizarTelefono(from.trim())),
    ]);
  }

  // ── Envío principal ───────────────────────────────────────────────────────

  /// Envía un SMS. Devuelve true si se envió correctamente.
  /// El teléfono se normaliza automáticamente a E.164 (+34xxx).
  Future<bool> enviarSMS(String telefono, String mensaje) async {
    final creds = await _credenciales();
    if (creds == null) {
      debugPrint('📵 Twilio no configurado — SMS no enviado');
      return false;
    }

    final to = _normalizarTelefono(telefono);
    if (!to.startsWith('+')) {
      debugPrint('❌ Twilio: teléfono sin formato E.164: $to');
      return false;
    }

    try {
      final url = Uri.parse(
          'https://api.twilio.com/2010-04-01/Accounts/${creds.sid}/Messages.json');

      final credB64 = base64Encode(utf8.encode('${creds.sid}:${creds.token}'));

      final resp = await http.post(
        url,
        headers: {
          'Authorization': 'Basic $credB64',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': creds.from,
          'To': to,
          'Body': mensaje,
        },
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 201) {
        debugPrint('✅ SMS enviado a $to');
        return true;
      }
      debugPrint('❌ Twilio ${resp.statusCode}: ${resp.body}');
      return false;
    } catch (e) {
      debugPrint('❌ Twilio error: $e');
      return false;
    }
  }

  // ── Mensajes predefinidos ─────────────────────────────────────────────────

  Future<bool> smsConfirmacionReserva({
    required String telefono,
    required String nombreCliente,
    required String nombreEmpresa,
    required DateTime fechaHora,
    String? servicio,
  }) async {
    final fecha = _formatearFecha(fechaHora);
    final hora  = _formatearHora(fechaHora);
    final srv   = servicio?.isNotEmpty == true ? ' para $servicio' : '';
    final msg   =
        '✅ Hola $nombreCliente, tu reserva$srv en $nombreEmpresa '
        'está confirmada para el $fecha a las $hora.\n'
        'Si necesitas cancelar, llámanos. ¡Te esperamos!';
    return enviarSMS(telefono, msg);
  }

  Future<bool> smsCancelacionReserva({
    required String telefono,
    required String nombreCliente,
    required String nombreEmpresa,
    required DateTime fechaHora,
  }) async {
    final fecha = _formatearFecha(fechaHora);
    final msg   =
        '❌ Hola $nombreCliente, tu reserva del $fecha en '
        '$nombreEmpresa ha sido cancelada.\n'
        'Disculpa las molestias.';
    return enviarSMS(telefono, msg);
  }

  Future<bool> smsRecordatorioReserva({
    required String telefono,
    required String nombreCliente,
    required String nombreEmpresa,
    required DateTime fechaHora,
    String? servicio,
  }) async {
    final hora  = _formatearHora(fechaHora);
    final srv   = servicio?.isNotEmpty == true ? ' para $servicio' : '';
    final msg   =
        '⏰ Recordatorio: mañana tienes cita$srv en $nombreEmpresa '
        'a las $hora.\n$nombreCliente, ¡te esperamos!';
    return enviarSMS(telefono, msg);
  }

  Future<bool> smsEstadoPedido({
    required String telefono,
    required String nombreCliente,
    required String nombreEmpresa,
    required String numeroPedido,
    required String estado,
  }) async {
    final msg = switch (estado) {
      'confirmado'    => '✅ Hola $nombreCliente! Tu pedido #$numeroPedido en $nombreEmpresa está confirmado.',
      'en_preparacion'=> '👨‍🍳 Hola $nombreCliente! Tu pedido #$numeroPedido está siendo preparado.',
      'listo'         => '🎉 Hola $nombreCliente! Tu pedido #$numeroPedido está listo para recoger.',
      'entregado'     => '📦 Hola $nombreCliente! Tu pedido #$numeroPedido ha sido entregado. ¡Gracias!',
      'cancelado'     => '❌ Hola $nombreCliente, tu pedido #$numeroPedido ha sido cancelado. Disculpa.',
      _               => '📱 Actualización de tu pedido #$numeroPedido: $estado.',
    };
    return enviarSMS(telefono, msg);
  }

  /// Envía SMS a partir de una reserva guardada en Firestore (fire & forget).
  Future<void> notificarReserva({
    required String empresaId,
    required Map<String, dynamic> reservaData,
    required String estadoNuevo,
  }) async {
    final tel    = reservaData['telefono'] as String? ?? '';
    if (tel.isEmpty) return;

    final nombre = reservaData['cliente'] as String? ??
                   reservaData['nombre_cliente'] as String? ?? 'Cliente';

    // Obtener nombre empresa
    String nombreEmpresa = 'Nuestro negocio';
    try {
      final doc = await _db.collection('empresas').doc(empresaId).get();
      nombreEmpresa = doc.data()?['nombre'] as String? ?? nombreEmpresa;
    } catch (_) {}

    DateTime? fechaHora;
    final fh = reservaData['fecha_hora'];
    if (fh is Timestamp) fechaHora = fh.toDate();

    final servicio = reservaData['servicio'] as String? ?? '';

    switch (estadoNuevo.toUpperCase()) {
      case 'CONFIRMADA':
      case 'ACEPTADA':
        if (fechaHora != null) {
          await smsConfirmacionReserva(
            telefono: tel, nombreCliente: nombre,
            nombreEmpresa: nombreEmpresa, fechaHora: fechaHora, servicio: servicio,
          );
        }
        break;
      case 'CANCELADA':
        if (fechaHora != null) {
          await smsCancelacionReserva(
            telefono: tel, nombreCliente: nombre,
            nombreEmpresa: nombreEmpresa, fechaHora: fechaHora,
          );
        }
        break;
    }
  }

  // ── Log de SMS enviados ───────────────────────────────────────────────────

  Future<void> _registrarEnvio({
    required String empresaId,
    required String telefono,
    required String mensaje,
    required bool exito,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('empresas').doc(empresaId)
        .collection('sms_log').add({
      'telefono':  telefono,
      'mensaje':   mensaje,
      'exito':     exito,
      'timestamp': FieldValue.serverTimestamp(),
      'usuario_id': uid,
    });
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  /// Convierte teléfonos españoles al formato E.164 (+34xxx).
  String _normalizarTelefono(String t) {
    var n = t.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (n.startsWith('00')) n = '+${n.substring(2)}';
    if (!n.startsWith('+')) {
      // Asumir España si empieza por 6, 7 o 9
      if (RegExp(r'^[679]').hasMatch(n)) n = '+34$n';
      else n = '+$n';
    }
    return n;
  }

  String _formatearFecha(DateTime dt) {
    const meses = ['','ene','feb','mar','abr','may','jun',
                   'jul','ago','sep','oct','nov','dic'];
    return '${dt.day} ${meses[dt.month]}';
  }

  String _formatearHora(DateTime dt) =>
      '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
}

class _TwilioCreds {
  final String sid, token, from;
  const _TwilioCreds({required this.sid, required this.token, required this.from});
}

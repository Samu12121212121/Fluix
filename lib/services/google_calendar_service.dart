import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO GOOGLE CALENDAR
//
// Sincroniza citas/reservas de Firestore con el calendario personal del
// usuario (OAuth2 via google_sign_in).
//
// No requiere API key — usa el token OAuth del usuario autenticado.
//
// Uso:
//   await GoogleCalendarService().conectar();
//   await GoogleCalendarService().sincronizarReserva(empresaId, reservaDoc);
// ─────────────────────────────────────────────────────────────────────────────

class GoogleCalendarService {
  static final GoogleCalendarService _i = GoogleCalendarService._();
  factory GoogleCalendarService() => _i;
  GoogleCalendarService._();

  static const _scope = 'https://www.googleapis.com/auth/calendar.events';
  static const _calApi = 'https://www.googleapis.com/calendar/v3';

  final _googleSignIn = GoogleSignIn(scopes: ['email', _scope]);
  final _db = FirebaseFirestore.instance;

  GoogleSignInAccount? _cuenta;
  bool get conectado => _cuenta != null;

  // ── Conexión OAuth ────────────────────────────────────────────────────────

  Future<bool> conectar() async {
    try {
      _cuenta = await _googleSignIn.signIn();
      return _cuenta != null;
    } catch (e) {
      debugPrint('❌ GoogleCalendar conectar: $e');
      return false;
    }
  }

  Future<void> desconectar() async {
    await _googleSignIn.signOut();
    _cuenta = null;
  }

  Future<bool> intentarReconectar() async {
    try {
      _cuenta = await _googleSignIn.signInSilently();
      return _cuenta != null;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>?> _authHeaders() async {
    if (_cuenta == null) await intentarReconectar();
    if (_cuenta == null) return null;
    final auth = await _cuenta!.authentication;
    if (auth.accessToken == null) return null;
    return {
      'Authorization': 'Bearer ${auth.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  // ── Crear evento ──────────────────────────────────────────────────────────

  Future<String?> crearEvento({
    required String titulo,
    required DateTime inicio,
    required DateTime fin,
    String? descripcion,
    String? ubicacion,
    String? emailInvitado,
    String calendarId = 'primary',
  }) async {
    final headers = await _authHeaders();
    if (headers == null) return null;

    final body = {
      'summary':     titulo,
      if (descripcion != null) 'description': descripcion,
      if (ubicacion != null)   'location':    ubicacion,
      'start': {
        'dateTime': inicio.toIso8601String(),
        'timeZone': 'Europe/Madrid',
      },
      'end': {
        'dateTime': fin.toIso8601String(),
        'timeZone': 'Europe/Madrid',
      },
      if (emailInvitado != null)
        'attendees': [{'email': emailInvitado}],
      'reminders': {
        'useDefault': false,
        'overrides': [
          {'method': 'popup',  'minutes': 60},
          {'method': 'email',  'minutes': 1440},
        ],
      },
    };

    try {
      final resp = await http.post(
        Uri.parse('$_calApi/calendars/$calendarId/events'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['id'] as String?;
      }
      debugPrint('❌ GoogleCalendar crear evento: ${resp.statusCode}');
      return null;
    } catch (e) {
      debugPrint('❌ GoogleCalendar crear evento: $e');
      return null;
    }
  }

  Future<bool> eliminarEvento(String eventId,
      {String calendarId = 'primary'}) async {
    final headers = await _authHeaders();
    if (headers == null) return false;
    try {
      final resp = await http.delete(
        Uri.parse('$_calApi/calendars/$calendarId/events/$eventId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // ── Sincronizar reserva de Firestore ────────────────────────────────────

  Future<bool> sincronizarReserva({
    required String empresaId,
    required Map<String, dynamic> reservaData,
    required String reservaId,
    String? nombreEmpresa,
  }) async {
    final fechaHora = _parseTs(reservaData['fecha_hora'] ?? reservaData['fecha']);
    if (fechaHora == null) return false;

    final duracion = (reservaData['duracion_minutos'] as num?)?.toInt() ?? 60;
    final fin      = fechaHora.add(Duration(minutes: duracion));

    final cliente  = reservaData['cliente'] as String? ??
                     reservaData['nombre_cliente'] as String? ?? 'Cliente';
    final servicio = reservaData['servicio'] as String? ?? '';
    final email    = reservaData['email'] as String?;

    final negocio  = nombreEmpresa ?? 'Negocio';
    final titulo   = servicio.isNotEmpty
        ? '$servicio — $cliente'
        : 'Cita: $cliente';
    final desc     = '${negocio.isNotEmpty ? "📍 $negocio\n" : ""}'
        '👤 $cliente'
        '${email != null ? "\n✉️ $email" : ""}';

    try {
      final eventId = await crearEvento(
        titulo:        titulo,
        inicio:        fechaHora,
        fin:           fin,
        descripcion:   desc,
        emailInvitado: email,
      );

      if (eventId != null) {
        await _db
            .collection('empresas').doc(empresaId)
            .collection('reservas').doc(reservaId)
            .update({'gcal_event_id': eventId});
        return true;
      }
    } catch (e) {
      debugPrint('❌ GoogleCalendar sincronizar: $e');
    }
    return false;
  }

  // ── Cancelar evento de una reserva ────────────────────────────────────────

  Future<void> cancelarEventoDeReserva({
    required String empresaId,
    required String reservaId,
  }) async {
    try {
      final doc = await _db
          .collection('empresas').doc(empresaId)
          .collection('reservas').doc(reservaId)
          .get();
      final eventId = doc.data()?['gcal_event_id'] as String?;
      if (eventId == null) return;
      await eliminarEvento(eventId);
      await doc.reference.update({'gcal_event_id': FieldValue.delete()});
    } catch (_) {}
  }

  // ── Utilidades ────────────────────────────────────────────────────────────

  DateTime? _parseTs(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

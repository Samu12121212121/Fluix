// lib/services/notification_service.dart

import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationService {
  final String? _emailEndpoint;
  final String? _pushKey;
  final String? _adminEmail;

  NotificationService({
    String? emailEndpoint,
    String? pushKey,
    String? adminEmail,
  })  : _emailEndpoint = emailEndpoint,
        _pushKey        = pushKey,
        _adminEmail     = adminEmail;

  factory NotificationService.fromEnv() => NotificationService(
    emailEndpoint: Platform.environment['NOTIFICATION_EMAIL_ENDPOINT'],
    pushKey:       Platform.environment['PUSH_NOTIFICATION_KEY'],
    adminEmail:    Platform.environment['NOTIFICATION_EMAIL'],
  );

  /// Notificación urgente — también imprime en stderr.
  Future<void> sendUrgent({
    required String title,
    required String body,
  }) async {
    stderr.writeln('🚨 [URGENT] $title\n$body');
    await send(title: title, body: body, urgent: true);
  }

  Future<void> send({
    required String title,
    required String body,
    bool urgent = false,
  }) async {
    _log('[${ urgent ? "URGENT" : "INFO"}] $title — $body');

    // Enviar al endpoint de email si está configurado
    if (_emailEndpoint != null && _emailEndpoint!.isNotEmpty) {
      try {
        await http.post(
          Uri.parse(_emailEndpoint!),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'to':      _adminEmail,
            'subject': title,
            'body':    body,
            'urgent':  urgent,
          }),
        );
      } catch (e) {
        stderr.writeln('⚠️ Error enviando notificación email: $e');
      }
    }

    // Push FCM si está configurado
    if (_pushKey != null && _pushKey!.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          headers: {
            'Authorization': 'key=$_pushKey',
            'Content-Type':  'application/json',
          },
          body: jsonEncode({
            'to':           '/topics/admin',
            'notification': {'title': title, 'body': body},
            'priority':     urgent ? 'high' : 'normal',
          }),
        );
      } catch (e) {
        stderr.writeln('⚠️ Error enviando notificación push: $e');
      }
    }
  }

  void _log(String msg) => stdout.writeln('[NotificationService] $msg');
}


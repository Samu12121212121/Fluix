// lib/services/payments/providers/psd2/psd2_consent_manager.dart

import '../../../../models/psd2_consent.dart';
import '../../../../repositories/consent_repository.dart';
import '../../../../services/notification_service.dart';
import 'psd2_auth_service.dart';

class Psd2ConsentManager {
  final ConsentRepository   _repo;
  final Psd2AuthService     _auth;
  final NotificationService _notifications;

  Psd2ConsentManager({
    required ConsentRepository   repo,
    required Psd2AuthService     auth,
    required NotificationService notifications,
  })  : _repo          = repo,
        _auth          = auth,
        _notifications = notifications;

  /// Ejecutar diariamente. Detecta expirados y envía avisos preventivos.
  Future<void> checkAllConsents() async {
    final consents = await _repo.getAll();
    for (final consent in consents) {
      final days = consent.expiresAt.difference(DateTime.now()).inDays;

      if (days <= 0) {
        await _repo.markExpired(consent.bankId);
        await _notifications.sendUrgent(
          title: '⚠️ Conexión bancaria expirada — ${consent.bankId}',
          body:  'La conexión con ${consent.bankId} ha caducado. '
                 'Los pagos recibidos en esta cuenta no se están facturando.',
        );
      } else if (days <= 7) {
        final notified = await _repo.wasNotifiedRecently(consent.bankId);
        if (!notified) {
          await _notifications.send(
            title: 'Conexión bancaria caduca en $days días — ${consent.bankId}',
            body:  'Renuévala antes del '
                   '${consent.expiresAt.day}/${consent.expiresAt.month}'
                   ' para no interrumpir la facturación automática.',
          );
          await _repo.markNotified(consent.bankId);
        }
      }
    }
  }

  /// Completa el flujo OAuth2 y guarda el consentimiento.
  Future<void> renewConsent({
    required String bankId,
    required String authorizationCode,
    String redirectUri = '',
  }) async {
    final token = await _auth.completeAuth(
      bankId:            bankId,
      authorizationCode: authorizationCode,
      redirectUri:       redirectUri,
    );
    await _repo.upsert(
      Psd2Consent(
        bankId:       bankId,
        accessToken:  token.accessToken,
        refreshToken: token.refreshToken,
        expiresAt:    token.expiresAt,
      ),
    );
  }

  /// Genera la URL de autorización para que el usuario renueve el consentimiento.
  String getAuthorizationUrl({
    required String bankId,
    required String redirectUri,
    String state = '',
  }) => _auth.getAuthorizationUrl(
    bankId:      bankId,
    redirectUri: redirectUri,
    state:       state,
  );
}

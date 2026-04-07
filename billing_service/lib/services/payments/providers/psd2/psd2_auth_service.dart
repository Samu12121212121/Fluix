// lib/services/payments/providers/psd2/psd2_auth_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../../models/psd2_consent.dart';
import 'banks/bank_adapter.dart';

class Psd2AuthService {
  final Map<String, BankAdapter> _adapters = {};

  void registerBank(BankAdapter adapter) {
    _adapters[adapter.bankId] = adapter;
  }

  /// Genera la URL de autorización OAuth2 para iniciar el consentimiento PSD2.
  String getAuthorizationUrl({
    required String bankId,
    required String redirectUri,
    String state = '',
  }) {
    final adapter = _requireAdapter(bankId);
    final clientId = Platform.environment['PSD2_${bankId.toUpperCase()}_CLIENT_ID'] ?? '';

    final params = {
      'response_type': 'code',
      'client_id':     clientId,
      'redirect_uri':  redirectUri,
      'scope':         'AIS:read',
      'state':         state,
    };
    final query = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '${adapter.authorizationEndpoint}?$query';
  }

  /// Intercambia el código de autorización por tokens de acceso.
  Future<Psd2Token> completeAuth({
    required String bankId,
    required String authorizationCode,
    String redirectUri = '',
  }) async {
    final adapter      = _requireAdapter(bankId);
    final clientId     = Platform.environment['PSD2_${bankId.toUpperCase()}_CLIENT_ID'] ?? '';
    final clientSecret = Platform.environment['PSD2_${bankId.toUpperCase()}_CLIENT_SECRET'] ?? '';

    final response = await http.post(
      Uri.parse(adapter.tokenEndpoint),
      headers: {
        'Content-Type':  'application/x-www-form-urlencoded',
        'Authorization': 'Basic ${base64.encode(utf8.encode('$clientId:$clientSecret'))}',
      },
      body: {
        'grant_type':   'authorization_code',
        'code':         authorizationCode,
        'redirect_uri': redirectUri,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'PSD2 auth error para $bankId: ${response.statusCode} — ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final expiresIn = (data['expires_in'] as int?) ?? 7776000; // 90 días
    return Psd2Token(
      accessToken:  data['access_token'] as String,
      refreshToken: data['refresh_token'] as String?,
      expiresAt:    DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  /// Refresca el token de acceso usando el refresh token.
  Future<Psd2Token> refreshToken({
    required String bankId,
    required String refreshToken,
  }) async {
    final adapter      = _requireAdapter(bankId);
    final clientId     = Platform.environment['PSD2_${bankId.toUpperCase()}_CLIENT_ID'] ?? '';
    final clientSecret = Platform.environment['PSD2_${bankId.toUpperCase()}_CLIENT_SECRET'] ?? '';

    final response = await http.post(
      Uri.parse(adapter.tokenEndpoint),
      headers: {
        'Content-Type':  'application/x-www-form-urlencoded',
        'Authorization': 'Basic ${base64.encode(utf8.encode('$clientId:$clientSecret'))}',
      },
      body: {
        'grant_type':    'refresh_token',
        'refresh_token': refreshToken,
      },
    );

    if (response.statusCode != 200) {
      throw Exception('PSD2 refresh error para $bankId: ${response.statusCode}');
    }

    final data      = jsonDecode(response.body) as Map<String, dynamic>;
    final expiresIn = (data['expires_in'] as int?) ?? 7776000;
    return Psd2Token(
      accessToken:  data['access_token'] as String,
      refreshToken: data['refresh_token'] as String? ?? refreshToken,
      expiresAt:    DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  BankAdapter _requireAdapter(String bankId) {
    final adapter = _adapters[bankId];
    if (adapter == null) throw ArgumentError('Banco no registrado: $bankId');
    return adapter;
  }
}


import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO — Protección contra fuerza bruta en login
//
// Migrado a Cloud Function: el cliente ya NO escribe a Firestore directamente.
// La colección login_intentos tiene allow: false — solo Admin SDK puede escribir.
//
// Reglas:  max 5 intentos → bloqueo 15 minutos.
//          Al hacer login exitoso → reset del contador.
// ─────────────────────────────────────────────────────────────────────────────

/// URL base de la Cloud Function verificarLoginIntento.
/// Cambia a tu URL real tras hacer firebase deploy --only functions.
const String _cfBaseUrl =
    'https://europe-west1-planeaapp-4bea4.cloudfunctions.net/verificarLoginIntento';

class EstadoBloqueo {
  final bool bloqueado;
  final DateTime? bloqueadoHasta;
  final int intentos;

  const EstadoBloqueo({
    required this.bloqueado,
    this.bloqueadoHasta,
    required this.intentos,
  });

  /// Tiempo restante de bloqueo.
  Duration get tiempoRestante {
    if (!bloqueado || bloqueadoHasta == null) return Duration.zero;
    final restante = bloqueadoHasta!.difference(DateTime.now());
    return restante.isNegative ? Duration.zero : restante;
  }
}

class FuerzaBrutaService {
  static final FuerzaBrutaService _i = FuerzaBrutaService._();
  factory FuerzaBrutaService() => _i;
  FuerzaBrutaService._();

  static const int _maxIntentos = 5;

  // ── VERIFICAR ESTADO ─────────────────────────────────────────────────────

  Future<EstadoBloqueo> verificarEstado(String email) async {
    try {
      final response = await http.post(
        Uri.parse(_cfBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final bloqueado = data['bloqueado'] as bool? ?? false;
        final segundos = data['segundosRestantes'] as int? ?? 0;
        final intentosRestantes = data['intentosRestantes'] as int? ?? _maxIntentos;

        return EstadoBloqueo(
          bloqueado: bloqueado,
          bloqueadoHasta: bloqueado
              ? DateTime.now().add(Duration(seconds: segundos))
              : null,
          intentos: _maxIntentos - intentosRestantes,
        );
      }
      return const EstadoBloqueo(bloqueado: false, intentos: 0);
    } catch (_) {
      // Si falla la CF (sin red, etc.), NO bloquear al usuario
      return const EstadoBloqueo(bloqueado: false, intentos: 0);
    }
  }

  // ── STREAM EN TIEMPO REAL ────────────────────────────────────────────────

  /// Stream que actualiza el estado cada segundo (para el countdown en UI).
  Stream<EstadoBloqueo> estadoStream(String email) async* {
    while (true) {
      yield await verificarEstado(email);
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  // ── REGISTRAR INTENTO ────────────────────────────────────────────────────

  Future<void> registrarIntento({
    required String email,
    required bool exito,
  }) async {
    try {
      await http.post(
        Uri.parse(_cfBaseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'exito': exito,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      // No bloquear el flujo de login si falla la Cloud Function
    }
  }

  /// Número de intentos restantes antes del bloqueo.
  int intentosRestantes(int intentosActuales) =>
      (_maxIntentos - intentosActuales).clamp(0, _maxIntentos);
}

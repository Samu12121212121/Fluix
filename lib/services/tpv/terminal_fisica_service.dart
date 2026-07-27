import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// ─── Resultado del cobro en terminal ────────────────────────────────────────

class TerminalResultado {
  final bool exito;
  final bool esManual;
  final String? error;
  final String? transaccionId;

  const TerminalResultado._({
    required this.exito,
    this.esManual = false,
    this.error,
    this.transaccionId,
  });

  factory TerminalResultado.manual() =>
      const TerminalResultado._(exito: false, esManual: true);

  factory TerminalResultado.ok([String? txId]) =>
      TerminalResultado._(exito: true, transaccionId: txId);

  factory TerminalResultado.fallo(String msg) =>
      TerminalResultado._(exito: false, error: msg);
}

// ─── Protocolo soportado ─────────────────────────────────────────────────────

enum ProtocoloTerminal {
  manual,   // Solo confirmación manual (sin red)
  sumup,    // SumUp Solo — REST local (http://[ip]:8080)
  generico, // HTTP POST genérico (Ingenico, Verifone, etc.)
}

// ─── Servicio ────────────────────────────────────────────────────────────────

class TerminalFisicaService {
  static final TerminalFisicaService _i = TerminalFisicaService._();
  factory TerminalFisicaService() => _i;
  TerminalFisicaService._();

  String _ip = '';
  int _puerto = 8080;
  ProtocoloTerminal _protocolo = ProtocoloTerminal.manual;

  bool get configurado =>
      _ip.isNotEmpty && _protocolo != ProtocoloTerminal.manual;

  void configurar({
    required String ip,
    required int puerto,
    required ProtocoloTerminal protocolo,
  }) {
    _ip = ip;
    _puerto = puerto;
    _protocolo = protocolo;
  }

  // ── Verificar si hay terminal accesible en red ──────────────────────────

  Future<bool> verificarConexion() async {
    if (!configurado) return false;
    try {
      final socket = await Socket.connect(_ip, _puerto,
          timeout: const Duration(seconds: 3));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Iniciar cobro en terminal ───────────────────────────────────────────

  Future<TerminalResultado> cobrar(
    double importe, {
    String descripcion = 'Venta TPV',
    String moneda = 'EUR',
  }) async {
    if (!configurado) return TerminalResultado.manual();

    try {
      switch (_protocolo) {
        case ProtocoloTerminal.sumup:
          return await _cobrarSumUp(importe, descripcion, moneda);
        case ProtocoloTerminal.generico:
          return await _cobrarGenerico(importe, descripcion, moneda);
        case ProtocoloTerminal.manual:
          return TerminalResultado.manual();
      }
    } on SocketException {
      return TerminalResultado.fallo('Terminal no accesible en $_ip:$_puerto');
    } on TimeoutException {
      return TerminalResultado.fallo('Tiempo de espera agotado. ¿El terminal está encendido?');
    } catch (e) {
      return TerminalResultado.fallo('Error de comunicación: $e');
    }
  }

  // ── SumUp Solo — API local ──────────────────────────────────────────────
  // El SumUp Solo expone una API REST en la red local.
  // Documentación: https://developer.sumup.com/point-of-sale/api/

  Future<TerminalResultado> _cobrarSumUp(
      double importe, String descripcion, String moneda) async {
    final url = Uri.parse('http://$_ip:$_puerto/v0.1/transactions');
    final res = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'amount': importe,
            'currency': moneda,
            'description': descripcion,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode == 200 || res.statusCode == 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final txId = body['transaction_id'] as String? ?? body['id'] as String?;
      final status = body['status'] as String? ?? 'success';
      if (status == 'success' || status == 'SUCCESSFUL') {
        return TerminalResultado.ok(txId);
      }
      return TerminalResultado.fallo('Pago no completado: $status');
    }
    return TerminalResultado.fallo('Error ${res.statusCode} del terminal');
  }

  // ── Genérico — HTTP POST ────────────────────────────────────────────────
  // Compatible con terminales que expongan una API REST básica.

  Future<TerminalResultado> _cobrarGenerico(
      double importe, String descripcion, String moneda) async {
    final url = Uri.parse('http://$_ip:$_puerto/charge');
    final res = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'amount': importe,
            'currency': moneda,
            'description': descripcion,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final txId = body['transaction_id'] as String? ??
            body['id'] as String? ??
            body['reference'] as String?;
        final ok = body['status'] == 'success' ||
            body['status'] == 'approved' ||
            body['result'] == 'ok';
        if (ok) return TerminalResultado.ok(txId);
        return TerminalResultado.fallo('Pago rechazado por el terminal');
      } catch (_) {
        // Si la respuesta HTTP es 2xx asumimos éxito aunque el JSON sea raro
        return TerminalResultado.ok();
      }
    }
    return TerminalResultado.fallo('Error ${res.statusCode} del terminal');
  }
}

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'impresora_bluetooth_service.dart' show TicketData;

// ════════════════════════════════════════════════════════════════════════════════
// SERVICIO DE IMPRESIÓN WINDOWS — COM Port + TCP/IP + ESC/POS
//
// Modo COM (Bluetooth SPP / USB-serial):
//   Escribe directamente a \\.\COMn vía dart:io — sin flutter_libserialport.
//
// Modo TCP (impresoras de red: Epson TM-T88VI, Star TSP654, etc.):
//   Abre socket TCP a IP:9100 (puerto estándar RAW printing).
//
// Multitenant:
//   - Config hardware (COM port, IP) → SharedPreferences (por dispositivo)
//   - Comportamiento cajón → ConfiguracionFacturacionTpv en Firestore (por tenant)
// ════════════════════════════════════════════════════════════════════════════════

enum ModoConexionImpresora { com, tcp }

class ImpresoraWindowsService {
  static final ImpresoraWindowsService _instance = ImpresoraWindowsService._();
  factory ImpresoraWindowsService() => _instance;
  ImpresoraWindowsService._();

  static const _keyPuerto = 'impresora_windows_puerto_com';
  static const _keyIp     = 'impresora_windows_ip';
  static const _keyPort   = 'impresora_windows_port';
  static const _keyModo   = 'impresora_windows_modo'; // 'com' | 'tcp'

  String? _puertoGuardado;
  String? _ipGuardada;
  int _puertoTcp = 9100;
  ModoConexionImpresora _modo = ModoConexionImpresora.com;
  bool _conectada = false;
  Timer? _healthCheckTimer;

  String? get puertoActual   => _puertoGuardado;
  String? get ipActual       => _ipGuardada;
  int    get puertoTcpActual => _puertoTcp;
  bool   get usaTcp          => _modo == ModoConexionImpresora.tcp;
  bool   get estaConectada   => _conectada;

  // ── Inicialización ────────────────────────────────────────────────────────

  Future<void> inicializar() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final modoStr = prefs.getString(_keyModo) ?? 'com';
      _modo = modoStr == 'tcp'
          ? ModoConexionImpresora.tcp
          : ModoConexionImpresora.com;

      if (_modo == ModoConexionImpresora.tcp) {
        _ipGuardada  = prefs.getString(_keyIp);
        _puertoTcp   = prefs.getInt(_keyPort) ?? 9100;
        if (_ipGuardada != null) {
          _conectada = await _testearTcp(_ipGuardada!, _puertoTcp);
        }
      } else {
        final saved = prefs.getString(_keyPuerto);
        if (saved != null) {
          _puertoGuardado = saved;
          _conectada = await _testearCom(saved);
          if (!_conectada) debugPrint('⚠️ Puerto guardado $saved no responde');
        }
        if (!_conectada) await _detectarPuerto();
      }
      _iniciarHealthChecks();
    } catch (e) {
      debugPrint('⚠️ Error al inicializar impresora Windows: $e');
    }
  }

  // ── Configuración COM ─────────────────────────────────────────────────────

  Future<void> setPuerto(String puerto) async {
    _puertoGuardado = puerto;
    _modo = ModoConexionImpresora.com;
    _conectada = await _testearCom(puerto);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPuerto, puerto);
    await prefs.setString(_keyModo, 'com');
    debugPrint('🖨️ COM configurado: $puerto (conectada: $_conectada)');
  }

  Future<void> forzarDeteccion() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    _conectada = false;
    _puertoGuardado = null;
    _modo = ModoConexionImpresora.com;
    await _detectarPuerto();
  }

  Future<void> _detectarPuerto() async {
    debugPrint('🔍 Detectando puerto COM (COM1-COM20)...');
    for (int i = 1; i <= 20; i++) {
      final puerto = 'COM$i';
      if (await _testearCom(puerto)) {
        _puertoGuardado = puerto;
        _conectada = true;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyPuerto, puerto);
        await prefs.setString(_keyModo, 'com');
        debugPrint('✅ Impresora detectada en $puerto');
        return;
      }
    }
    debugPrint('⚠️ No se detectó impresora en ningún puerto COM');
    _conectada = false;
  }

  // ── Configuración TCP/IP ──────────────────────────────────────────────────

  /// Configura impresora de red. [port] suele ser 9100 (RAW printing estándar).
  Future<void> setIp(String ip, {int port = 9100}) async {
    _ipGuardada = ip;
    _puertoTcp  = port;
    _modo = ModoConexionImpresora.tcp;
    _conectada = await _testearTcp(ip, port);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIp, ip);
    await prefs.setInt(_keyPort, port);
    await prefs.setString(_keyModo, 'tcp');
    debugPrint('🖨️ TCP configurado: $ip:$port (conectada: $_conectada)');
  }

  // ── Health checks ─────────────────────────────────────────────────────────

  void _iniciarHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (_modo == ModoConexionImpresora.tcp && _ipGuardada != null) {
        _conectada = await _testearTcp(_ipGuardada!, _puertoTcp);
      } else if (_puertoGuardado != null) {
        _conectada = await _testearCom(_puertoGuardado!);
      }
    });
  }

  // ── Imprimir ticket ───────────────────────────────────────────────────────

  Future<void> imprimirTicket(TicketData ticket) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    _validarConexion();
    debugPrint('🖨️ Imprimiendo ticket...');
    await compute(_imprimirEnBackground,
        _ParametrosImpresion.desde(this, _generarComandosESC(ticket)));
    debugPrint('✅ Ticket impreso');
  }

  static Future<void> _imprimirEnBackground(_ParametrosImpresion p) async {
    await _enviar(p);
  }

  // ── Abrir cajón ───────────────────────────────────────────────────────────

  /// [pin] 0 = Pin 2 (estándar), 1 = Pin 5.
  Future<void> abrirCajon({int pin = 0}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    _validarConexion();
    await compute(_abrirCajonEnBackground,
        _ParametrosCajon.desde(this, pin));
  }

  static Future<void> _abrirCajonEnBackground(_ParametrosCajon p) async {
    // ESC p m t1 t2 — apertura cajón ESC/POS
    // m=0 → Pin 2 (estándar), m=1 → Pin 5
    final bytes = Uint8List.fromList([0x1B, 0x70, p.pin, 0x19, 0xFA]);
    await _enviar(_ParametrosImpresion(
      esTcp: p.esTcp, puerto: p.puerto, ip: p.ip, puertoTcp: p.puertoTcp,
      bytes: bytes,
    ));
  }

  // ── Transporte unificado ──────────────────────────────────────────────────

  static Future<void> _enviar(_ParametrosImpresion p) async {
    if (p.esTcp) {
      await _escribirTcp(p.ip!, p.puertoTcp, p.bytes);
    } else {
      await _escribirCom(p.puerto!, p.bytes);
    }
  }

  // Escribe bytes vía COM. Prefijo \\. requerido para COM10+.
  static Future<void> _escribirCom(String puerto, Uint8List bytes) async {
    final path = '\\\\.\\$puerto';
    final sink = File(path).openWrite();
    try {
      sink.add(bytes);
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  // Escribe bytes vía TCP (RAW printing, puerto 9100).
  static Future<void> _escribirTcp(String ip, int port, Uint8List bytes) async {
    final socket = await Socket.connect(ip, port)
        .timeout(const Duration(seconds: 5));
    try {
      socket.add(bytes);
      await socket.flush();
    } finally {
      socket.destroy();
    }
  }

  static Future<bool> _testearCom(String puerto) async {
    try {
      await _escribirCom(puerto, Uint8List.fromList([0x1B, 0x40]));
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _testearTcp(String ip, int port) async {
    try {
      final socket = await Socket.connect(ip, port)
          .timeout(const Duration(seconds: 3));
      socket.add(Uint8List.fromList([0x1B, 0x40])); // ESC @ wake
      await socket.flush();
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _validarConexion() {
    if (_modo == ModoConexionImpresora.tcp && _ipGuardada == null) {
      throw ImpresoraException('IP de impresora no configurada.');
    }
    if (_modo == ModoConexionImpresora.com && _puertoGuardado == null) {
      throw ImpresoraException('Puerto COM no configurado.');
    }
  }

  // ── ESC/POS builder ───────────────────────────────────────────────────────

  static Uint8List _generarComandosESC(TicketData ticket) {
    final b = <int>[];
    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final fmtFecha = DateFormat('dd/MM/yyyy HH:mm');

    b.addAll([0x1B, 0x40]);
    b.addAll([0x1B, 0x61, 0x01]);
    b.addAll(utf8.encode('================================\n'));
    b.addAll([0x1B, 0x45, 0x01]);
    b.addAll(utf8.encode('${ticket.nombreEmpresa.toUpperCase()}\n'));
    b.addAll([0x1B, 0x45, 0x00]);
    b.addAll(utf8.encode('================================\n\n'));
    b.addAll(utf8.encode('Ticket nº ${ticket.numeroTicket}\n'));
    b.addAll(utf8.encode('${fmtFecha.format(ticket.fecha)}\n'));
    b.addAll(utf8.encode('--------------------------------\n\n'));
    b.addAll([0x1B, 0x61, 0x00]);
    for (final l in ticket.lineas) {
      b.addAll(utf8.encode('${l.nombre}\n'));
      b.addAll(utf8.encode(
          '  ${l.cantidad} x ${fmt.format(l.precioUnitario)} = ${fmt.format(l.subtotal)}\n'));
    }
    b.addAll(utf8.encode('\n--------------------------------\n'));
    b.addAll([0x1B, 0x61, 0x01, 0x1D, 0x21, 0x11]);
    b.addAll(utf8.encode('TOTAL: ${fmt.format(ticket.total)}'));
    b.addAll([0x1D, 0x21, 0x00]);
    b.addAll(utf8.encode('\n\n'));
    b.addAll([0x1B, 0x61, 0x00]);
    b.addAll(utf8.encode('Pago: ${ticket.metodoPago}\n\n\n'));
    b.addAll([0x1B, 0x61, 0x01]);
    b.addAll(utf8.encode('¡Gracias por su compra!\n\n'));
    b.addAll([0x1B, 0x64, 0x05, 0x1D, 0x56, 0x00]);

    return Uint8List.fromList(b);
  }

  void dispose() => _healthCheckTimer?.cancel();
}

// ── Modelos de parámetros para isolates ───────────────────────────────────────

class _ParametrosImpresion {
  final bool esTcp;
  final String? puerto;
  final String? ip;
  final int puertoTcp;
  final Uint8List bytes;

  const _ParametrosImpresion({
    required this.esTcp,
    this.puerto,
    this.ip,
    required this.puertoTcp,
    required this.bytes,
  });

  factory _ParametrosImpresion.desde(ImpresoraWindowsService svc, Uint8List b) =>
      _ParametrosImpresion(
        esTcp: svc.usaTcp,
        puerto: svc.puertoActual,
        ip: svc.ipActual,
        puertoTcp: svc.puertoTcpActual,
        bytes: b,
      );
}

class _ParametrosCajon {
  final bool esTcp;
  final String? puerto;
  final String? ip;
  final int puertoTcp;
  final int pin;

  const _ParametrosCajon({
    required this.esTcp,
    this.puerto,
    this.ip,
    required this.puertoTcp,
    required this.pin,
  });

  factory _ParametrosCajon.desde(ImpresoraWindowsService svc, int pin) =>
      _ParametrosCajon(
        esTcp: svc.usaTcp,
        puerto: svc.puertoActual,
        ip: svc.ipActual,
        puertoTcp: svc.puertoTcpActual,
        pin: pin,
      );
}

class ImpresoraException implements Exception {
  final String message;
  ImpresoraException(this.message);
  @override
  String toString() => 'ImpresoraException: $message';
}

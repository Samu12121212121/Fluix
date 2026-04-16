import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/modelos/cierre_caja.dart';

// ── MODELOS LOCALES ────────────────────────────────────────────────────────────

class LineaTicket {
  final String nombre;
  final int cantidad;
  final double precioUnitario;

  const LineaTicket({
    required this.nombre,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;
}

class TicketData {
  final String nombreEmpresa;
  final int numeroTicket;
  final DateTime fecha;
  final List<LineaTicket> lineas;
  final double total;
  final String metodoPago;

  const TicketData({
    required this.nombreEmpresa,
    required this.numeroTicket,
    required this.fecha,
    required this.lineas,
    required this.total,
    required this.metodoPago,
  });
}

// ── SERVICIO ───────────────────────────────────────────────────────────────────

class ImpressoraBluetooth {
  static final ImpressoraBluetooth _i = ImpressoraBluetooth._();
  factory ImpressoraBluetooth() => _i;
  ImpressoraBluetooth._();

  final _bt = BlueThermalPrinter.instance;
  static const _prefsKey = 'ultima_impresora_bt';

  // ── Escanear ────────────────────────────────────────────────────────────────

  Future<List<BluetoothDevice>> escanearImpresoras() async {
    final bool? on = await _bt.isOn;
    if (on != true) {
      throw Exception('Bluetooth desactivado. Actívalo y vuelve a intentarlo.');
    }
    return await _bt.getBondedDevices();
  }

  // ── Conectar ────────────────────────────────────────────────────────────────

  Future<void> conectar(BluetoothDevice device) async {
    final bool? connected = await _bt.isConnected;
    if (connected == true) await _bt.disconnect();

    await _bt.connect(device);

    // Guardar última usada
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, '${device.address}|${device.name}');
  }

  // ── Obtener última guardada ─────────────────────────────────────────────────

  Future<Map<String, String>?> obtenerUltimaGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return null;
    final parts = raw.split('|');
    if (parts.length < 2) return null;
    return {'address': parts[0], 'name': parts[1]};
  }

  // ── Estado de conexión ──────────────────────────────────────────────────────

  Future<bool> estaConectada() async {
    return (await _bt.isConnected) == true;
  }

  // ── Limpiar última guardada ─────────────────────────────────────────────────

  Future<void> olvidarImpresora() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  // ── Imprimir Ticket ─────────────────────────────────────────────────────────

  Future<void> imprimirTicket(TicketData ticket) async {
    await _verificarConexion();

    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final fmtFecha = DateFormat('dd/MM/yyyy HH:mm');

    _bt.printCustom('================================', 1, 1);
    _bt.printCustom(ticket.nombreEmpresa, 3, 1);
    _bt.printCustom('================================', 1, 1);
    _bt.printNewLine();
    _bt.printCustom('Ticket nº ${ticket.numeroTicket}', 1, 1);
    _bt.printCustom(fmtFecha.format(ticket.fecha), 1, 1);
    _bt.printCustom('--------------------------------', 1, 1);

    for (final linea in ticket.lineas) {
      _bt.printCustom(
        '${linea.nombre}',
        1,
        0,
      );
      _bt.printCustom(
        '  ${linea.cantidad} x ${fmt.format(linea.precioUnitario)} = ${fmt.format(linea.subtotal)}',
        1,
        0,
      );
    }

    _bt.printCustom('--------------------------------', 1, 1);
    _bt.printCustom('TOTAL: ${fmt.format(ticket.total)}', 2, 1);
    _bt.printCustom('Pago: ${ticket.metodoPago}', 1, 1);
    _bt.printNewLine();
    _bt.printCustom('¡Gracias por su compra!', 1, 1);
    _bt.printNewLine();
    _bt.printNewLine();
    _bt.paperCut();
  }

  // ── Imprimir Cierre de Caja ─────────────────────────────────────────────────

  Future<void> imprimirCierreCaja(CierreCaja cierre) async {
    await _verificarConexion();

    final fmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final fmtFecha = DateFormat('dd/MM/yyyy');

    _bt.printCustom('================================', 1, 1);
    _bt.printCustom('CIERRE DE CAJA', 3, 1);
    _bt.printCustom(fmtFecha.format(cierre.fecha), 1, 1);
    _bt.printCustom('================================', 1, 1);
    _bt.printNewLine();
    _bt.printCustom('Efectivo:      ${fmt.format(cierre.totalEfectivo)}', 1, 0);
    _bt.printCustom('Tarjeta:       ${fmt.format(cierre.totalTarjeta)}', 1, 0);
    _bt.printCustom('Transferencia: ${fmt.format(cierre.totalTransferencia)}', 1, 0);
    _bt.printCustom('--------------------------------', 1, 1);
    _bt.printCustom('Nº tickets: ${cierre.numTickets}', 1, 0);
    _bt.printCustom('TOTAL VENTAS: ${fmt.format(cierre.totalVentas)}', 2, 1);
    if (cierre.observaciones != null && cierre.observaciones!.isNotEmpty) {
      _bt.printNewLine();
      _bt.printCustom('Obs: ${cierre.observaciones}', 1, 0);
    }
    _bt.printNewLine();
    _bt.printNewLine();
    _bt.paperCut();
  }

  // ── PRIVADO ─────────────────────────────────────────────────────────────────

  Future<void> _verificarConexion() async {
    final bool? connected = await _bt.isConnected;
    if (connected != true) {
      throw Exception(
          'Impresora no conectada. Selecciona una impresora Bluetooth.');
    }
  }
}


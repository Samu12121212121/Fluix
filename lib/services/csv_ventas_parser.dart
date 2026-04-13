import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../domain/modelos/pedido.dart';

// ── RESULTADO DE PARSEO ───────────────────────────────────────────────────────

class FilaVenta {
  final int numero;
  final DateTime? fecha;
  final String descripcion;
  final double cantidad;
  final double precioUnitario;
  final double total;
  final MetodoPago metodoPago;
  final double ivaPct;
  final List<String> errores;

  FilaVenta({
    required this.numero,
    this.fecha,
    this.descripcion = 'Venta importada',
    this.cantidad = 1,
    this.precioUnitario = 0,
    this.total = 0,
    this.metodoPago = MetodoPago.efectivo,
    this.ivaPct = 10,
    List<String>? errores,
  }) : errores = errores ?? [];

  bool get valida => errores.isEmpty && (total > 0 || precioUnitario > 0) && fecha != null;
}

class ResultadoParseoVentas {
  final List<FilaVenta> filas;
  final List<String> columnasDetectadas;
  final Map<String, int> mapeoColumnas;
  final String separador;

  const ResultadoParseoVentas({
    required this.filas,
    required this.columnasDetectadas,
    required this.mapeoColumnas,
    required this.separador,
  });

  List<FilaVenta> get filaValidas  => filas.where((f) => f.valida).toList();
  List<FilaVenta> get filasConError => filas.where((f) => !f.valida).toList();
}

// ── SERVICIO PARSER CSV VENTAS ────────────────────────────────────────────────

class CsvVentasParser {
  // ── DETECCIÓN DE FORMATO ─────────────────────────────────────────────────

  static String detectarSeparador(String contenido) {
    final primeraLinea = contenido.split('\n').first;
    final comas      = primeraLinea.split(',').length;
    final puntoycoma = primeraLinea.split(';').length;
    return puntoycoma > comas ? ';' : ',';
  }

  static String decodificarBytes(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      try {
        return latin1.decode(bytes);
      } catch (_) {
        return String.fromCharCodes(bytes);
      }
    }
  }

  // ── PARSEO DE FECHA ──────────────────────────────────────────────────────

  static DateTime? parsearFecha(String valor) {
    final v = valor.trim();
    if (v.isEmpty) return null;
    final formatos = [
      'dd/MM/yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm',
      'dd/MM/yyyy',
      'dd-MM-yyyy',
      'yyyy-MM-dd HH:mm:ss',
      'yyyy-MM-dd HH:mm',
      'yyyy-MM-dd',
      'dd/MM/yy',
      'dd-MM-yy',
      'yyyy/MM/dd',
    ];
    for (final fmt in formatos) {
      try {
        return DateFormat(fmt, 'es').parse(v);
      } catch (_) {}
    }
    return null;
  }

  // ── PARSEO DE IMPORTE ────────────────────────────────────────────────────

  static double? parsearImporte(String valor) {
    String limpio = valor
        .replaceAll('€', '')
        .replaceAll('\$', '')
        .replaceAll(' ', '')
        .replaceAll('\u00a0', '') // no-break space
        .trim();
    if (limpio.isEmpty) return null;
    // Formato español: 1.234,56 → tiene punto (miles) Y coma (decimal)
    if (limpio.contains(',') && limpio.contains('.')) {
      // El último separador determina el decimal
      final ultimaComa  = limpio.lastIndexOf(',');
      final ultimoPunto = limpio.lastIndexOf('.');
      if (ultimaComa > ultimoPunto) {
        // Coma = decimal (español): 1.234,56
        limpio = limpio.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // Punto = decimal (inglés): 1,234.56
        limpio = limpio.replaceAll(',', '');
      }
    } else if (limpio.contains(',')) {
      // Solo coma → decimal español: 12,50
      limpio = limpio.replaceAll(',', '.');
    }
    return double.tryParse(limpio);
  }

  // ── PARSEO MÉTODO DE PAGO ────────────────────────────────────────────────

  static MetodoPago parsearMetodoPago(String? texto) {
    if (texto == null || texto.trim().isEmpty) return MetodoPago.efectivo;
    final t = texto.toLowerCase().trim();
    if (t.contains('tarjeta') || t.contains('card')  ||
        t.contains('visa')    || t.contains('master') ||
        t.contains('tpv')     || t.contains('datafono') ||
        t.contains('credito') || t.contains('debito')) {
      return MetodoPago.tarjeta;
    }
    if (t.contains('bizum')) return MetodoPago.bizum;
    if (t.contains('paypal') || t.contains('pay pal')) return MetodoPago.paypal;
    if (t.contains('mixto') || t.contains('mix') || t.contains('combinado')) {
      return MetodoPago.mixto;
    }
    return MetodoPago.efectivo;
  }

  // ── MAPEO AUTOMÁTICO DE COLUMNAS ─────────────────────────────────────────

  static Map<String, int> mapearColumnas(List<String> cabecera) {
    final mapa = <String, int>{};
    for (int i = 0; i < cabecera.length; i++) {
      final col = _normalizar(cabecera[i]);
      if (_match(col, ['fecha', 'date', 'dia', 'fec'])) {
        mapa['fecha'] ??= i;
      } else if (_match(col, ['descripcion', 'descripci', 'desc', 'producto', 'articulo', 'concepto', 'name', 'nombre'])) {
        mapa['descripcion'] ??= i;
      } else if (_match(col, ['cantidad', 'qty', 'cant', 'units', 'uds'])) {
        mapa['cantidad'] ??= i;
      } else if (_match(col, ['precio_unitario', 'precio unit', 'precio', 'price', 'pvp', 'importe_unitario'])) {
        mapa['precio'] ??= i;
      } else if (_match(col, ['total', 'importe', 'amount', 'subtotal', 'total_linea'])) {
        mapa['total'] ??= i;
      } else if (_match(col, ['forma_pago', 'metodo_pago', 'pago', 'payment', 'method'])) {
        mapa['forma_pago'] ??= i;
      } else if (_match(col, ['iva', 'iva_pct', 'iva_porcent', 'tax', 'impuesto'])) {
        mapa['iva'] ??= i;
      }
    }
    return mapa;
  }

  static String _normalizar(String s) {
    return s.toLowerCase().trim()
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ñ', 'n');
  }

  static bool _match(String col, List<String> candidatos) =>
      candidatos.any((c) => col.contains(c));

  // ── PARSEO COMPLETO ──────────────────────────────────────────────────────

  static ResultadoParseoVentas parsear(
    Uint8List bytes, {
    Map<String, int>? mapeoManual,
  }) {
    final contenido = decodificarBytes(bytes);
    final separador = detectarSeparador(contenido);

    final filas = const CsvToListConverter().convert(
      contenido.replaceAll('\r\n', '\n').replaceAll('\r', '\n'),
      fieldDelimiter: separador,
      eol: '\n',
      shouldParseNumbers: false,
    );

    if (filas.isEmpty) {
      return ResultadoParseoVentas(filas: [], columnasDetectadas: [], mapeoColumnas: {}, separador: separador);
    }

    final cabecera = filas.first.map((c) => c.toString().trim()).toList();
    final mapeo = mapeoManual ?? mapearColumnas(cabecera);

    final resultado = <FilaVenta>[];
    for (int i = 1; i < filas.length && i <= 1001; i++) {
      final fila = filas[i];
      if (fila.every((c) => c.toString().trim().isEmpty)) continue;

      String _val(String campo) {
        final idx = mapeo[campo];
        if (idx == null || idx >= fila.length) return '';
        return fila[idx].toString().trim();
      }

      final errores = <String>[];
      final fechaStr   = _val('fecha');
      final fecha      = parsearFecha(fechaStr);
      final totalStr   = _val('total');
      final precioStr  = _val('precio');
      final cantidadStr = _val('cantidad');

      if (fechaStr.isNotEmpty && fecha == null) {
        errores.add('Fecha no reconocida: "$fechaStr"');
      }

      final total = parsearImporte(totalStr);
      final precio = parsearImporte(precioStr);
      final cantidad = parsearImporte(cantidadStr) ?? 1.0;

      if (total == null && precio == null) {
        errores.add('No se encontró importe válido (total o precio)');
      }

      final totalFinal = total ?? ((precio ?? 0) * cantidad);
      final precioFinal = precio ?? (total != null && cantidad > 0 ? total / cantidad : 0);

      // Advertencia (no error) si fecha futura
      final futuro = fecha != null && fecha.isAfter(DateTime.now().add(const Duration(days: 1)));
      if (futuro) errores.add('⚠️ Fecha futura: ${DateFormat('dd/MM/yyyy').format(fecha!)}');

      resultado.add(FilaVenta(
        numero: i + 1,
        fecha: fecha,
        descripcion: _val('descripcion').isNotEmpty ? _val('descripcion') : 'Venta importada',
        cantidad: cantidad,
        precioUnitario: precioFinal,
        total: totalFinal,
        metodoPago: parsearMetodoPago(_val('forma_pago').isNotEmpty ? _val('forma_pago') : null),
        ivaPct: parsearImporte(_val('iva')) ?? 10.0,
        errores: errores.where((e) => !e.startsWith('⚠️')).toList(),
      ));
    }

    return ResultadoParseoVentas(
      filas: resultado,
      columnasDetectadas: cabecera,
      mapeoColumnas: mapeo,
      separador: separador,
    );
  }

  // ── PLANTILLA CSV ────────────────────────────────────────────────────────

  static String generarPlantilla() {
    const conv = ListToCsvConverter(fieldDelimiter: ';');
    return conv.convert([
      ['fecha', 'descripcion', 'cantidad', 'precio_unitario', 'total', 'forma_pago', 'iva_pct'],
      ['13/04/2026', 'Café solo', '2', '1,50', '3,00', 'efectivo', '10'],
      ['13/04/2026', 'Menú del día', '1', '12,00', '12,00', 'tarjeta', '10'],
      ['13/04/2026', 'Cerveza', '3', '2,00', '6,00', 'efectivo', '10'],
      ['13/04/2026', 'Postre especial', '1', '4,50', '4,50', 'mixto', '10'],
    ]);
  }
}




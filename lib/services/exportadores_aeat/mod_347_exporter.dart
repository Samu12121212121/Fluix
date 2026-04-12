import 'dart:typed_data';
import '../../domain/modelos/factura.dart';
import '../../domain/modelos/factura_recibida.dart';

// ── UMBRAL LEGAL ──────────────────────────────────────────────────────────────
const double _kUmbral347 = 3005.06; // Importe mínimo (artículo 33 RD 1065/2007)
const int _kRegistroLen = 500;

// ── MODELOS ───────────────────────────────────────────────────────────────────

enum TipoOperacion347 {
  compra('A', 'Compra a proveedor'),   // A = adquirente
  venta('V', 'Venta a cliente'),       // V = vendedor / proveedor de quien declara
  arrendamiento('A', 'Arrendamiento inmueble');

  final String codigo;
  final String etiqueta;
  const TipoOperacion347(this.codigo, this.etiqueta);
}

/// Operación consolidada con un tercero (proveedor o cliente)
class Operacion347 {
  final String nifTercero;
  final String nombreTercero;
  final TipoOperacion347 tipo;
  final double baseImponibleAnual;
  final double ivaAnual;
  final double totalAnual;
  final int numOperaciones;
  final bool superaUmbral;

  const Operacion347({
    required this.nifTercero,
    required this.nombreTercero,
    required this.tipo,
    required this.baseImponibleAnual,
    required this.ivaAnual,
    required this.totalAnual,
    required this.numOperaciones,
    required this.superaUmbral,
  });
}

/// Resumen completo MOD 347
class Resumen347 {
  final int anio;
  final List<Operacion347> operacionesVenta;    // Clientes > umbral
  final List<Operacion347> operacionesCompra;   // Proveedores > umbral
  final double totalVentas;
  final double totalCompras;
  final int numDeclaraciones;

  const Resumen347({
    required this.anio,
    required this.operacionesVenta,
    required this.operacionesCompra,
    required this.totalVentas,
    required this.totalCompras,
    required this.numDeclaraciones,
  });
}

// ── EXPORTADOR ────────────────────────────────────────────────────────────────

class Mod347Exporter {
  /// Calcula todas las operaciones del ejercicio y agrupa por tercero.
  static Resumen347 calcular({
    required int anio,
    required List<Factura> facturasEmitidas,
    required List<FacturaRecibida> facturasRecibidas,
  }) {
    // ── VENTAS (facturas emitidas) ───────────────────────────────────────────
    final mapaVentas = <String, Map<String, dynamic>>{};

    for (final f in facturasEmitidas) {
      if (f.estado == EstadoFactura.anulada) continue;
      final nif = f.datosFiscales?.nif;
      if (nif == null || nif.isEmpty) continue; // Sin NIF no declarable

      mapaVentas.putIfAbsent(nif, () => {
        'nif': nif,
        'nombre': f.datosFiscales?.razonSocial ?? f.clienteNombre,
        'base': 0.0,
        'iva': 0.0,
        'total': 0.0,
        'num': 0,
      });

      mapaVentas[nif]!['base'] =
          (mapaVentas[nif]!['base'] as double) + f.subtotal;
      mapaVentas[nif]!['iva'] =
          (mapaVentas[nif]!['iva'] as double) + f.totalIva;
      mapaVentas[nif]!['total'] =
          (mapaVentas[nif]!['total'] as double) + f.total;
      mapaVentas[nif]!['num'] = (mapaVentas[nif]!['num'] as int) + 1;
    }

    // ── COMPRAS (facturas recibidas) ─────────────────────────────────────────
    final mapaCompras = <String, Map<String, dynamic>>{};

    for (final f in facturasRecibidas) {
      if (f.estado == EstadoFacturaRecibida.rechazada) continue;
      final nif = f.nifProveedor;
      if (nif.isEmpty) continue;

      mapaCompras.putIfAbsent(nif, () => {
        'nif': nif,
        'nombre': f.nombreProveedor,
        'base': 0.0,
        'iva': 0.0,
        'total': 0.0,
        'num': 0,
      });

      mapaCompras[nif]!['base'] =
          (mapaCompras[nif]!['base'] as double) + f.baseImponible;
      mapaCompras[nif]!['iva'] =
          (mapaCompras[nif]!['iva'] as double) + f.importeIva;
      mapaCompras[nif]!['total'] =
          (mapaCompras[nif]!['total'] as double) + f.totalConImpuestos;
      mapaCompras[nif]!['num'] = (mapaCompras[nif]!['num'] as int) + 1;
    }

    // ── CONSTRUIR LISTAS ─────────────────────────────────────────────────────
    List<Operacion347> _toList(
      Map<String, Map<String, dynamic>> mapa,
      TipoOperacion347 tipo,
    ) =>
        mapa.values.map((m) {
          final total = m['total'] as double;
          return Operacion347(
            nifTercero: m['nif'] as String,
            nombreTercero: m['nombre'] as String,
            tipo: tipo,
            baseImponibleAnual: m['base'] as double,
            ivaAnual: m['iva'] as double,
            totalAnual: total,
            numOperaciones: m['num'] as int,
            superaUmbral: total >= _kUmbral347,
          );
        }).toList()
          ..sort((a, b) => b.totalAnual.compareTo(a.totalAnual));

    final ventas = _toList(mapaVentas, TipoOperacion347.venta);
    final compras = _toList(mapaCompras, TipoOperacion347.compra);

    // Solo declarables (> umbral)
    final ventasDeclarables = ventas.where((o) => o.superaUmbral).toList();
    final comprasDeclarables = compras.where((o) => o.superaUmbral).toList();

    return Resumen347(
      anio: anio,
      operacionesVenta: ventasDeclarables,
      operacionesCompra: comprasDeclarables,
      totalVentas: ventasDeclarables.fold(0, (s, o) => s + o.totalAnual),
      totalCompras: comprasDeclarables.fold(0, (s, o) => s + o.totalAnual),
      numDeclaraciones:
          ventasDeclarables.length + comprasDeclarables.length,
    );
  }

  /// Genera fichero MOD 347 en formato posicional AEAT oficial.
  /// Registros de 500 caracteres, encoding ISO-8859-1, terminador CRLF.
  static Uint8List generarFichero({
    required String nifDeclarante,
    required String nombreDeclarante,
    required Resumen347 resumen,
  }) {
    final lineas = <String>[
      _registroDeclarante(nifDeclarante, nombreDeclarante, resumen),
    ];

    for (final op in resumen.operacionesVenta) {
      lineas.add(_registroOperacion(nifDeclarante, resumen.anio, op));
    }
    for (final op in resumen.operacionesCompra) {
      lineas.add(_registroOperacion(nifDeclarante, resumen.anio, op));
    }

    final contenido = '${lineas.join('\r\n')}\r\n';
    return _encodeIso88591(contenido);
  }

  /// Genera fichero como String (para tests y retrocompatibilidad).
  static String generarFicheroTexto({
    required String nifDeclarante,
    required String nombreDeclarante,
    required Resumen347 resumen,
  }) {
    final bytes = generarFichero(
      nifDeclarante: nifDeclarante,
      nombreDeclarante: nombreDeclarante,
      resumen: resumen,
    );
    return String.fromCharCodes(bytes);
  }

  // ── REGISTRO TIPO 1 — DECLARANTE (500 chars) ─────────────────────────────

  static String _registroDeclarante(
    String nif,
    String nombre,
    Resumen347 r,
  ) {
    final buf = List<String>.filled(_kRegistroLen, ' ');

    // Pos 1:     Tipo registro = "1"
    _write(buf, 0, '1');
    // Pos 2-4:   Modelo = "347"
    _write(buf, 1, '347');
    // Pos 5-8:   Ejercicio
    _write(buf, 4, r.anio.toString().padLeft(4, '0'));
    // Pos 9-17:  NIF declarante (9 chars)
    _write(buf, 8, _padAlpha(_cleanNif(nif), 9));
    // Pos 18-57: Razón social (40 chars)
    _write(buf, 17, _padAlpha(_normalizarTexto(nombre), 40));
    // Pos 58-58: Complementaria (S/N) — siempre N para generación normal
    _write(buf, 57, 'N');
    // Pos 59-72: Nº justificante anterior (14 dígitos, ceros si no aplica)
    _write(buf, 58, ''.padLeft(14, '0'));
    // Pos 73-85: Total importe operaciones (13 dígitos, céntimos, sin signo)
    _write(buf, 72, _importeCentimos(r.totalVentas + r.totalCompras, 13));
    // Pos 86-91: Nº total de operadores declarados (6 dígitos)
    _write(buf, 85, r.numDeclaraciones.toString().padLeft(6, '0'));
    // Pos 92-500: Blancos (ya inicializado a espacios)

    assert(buf.length == _kRegistroLen);
    return buf.join();
  }

  // ── REGISTRO TIPO 2 — OPERADOR (500 chars) ───────────────────────────────

  static String _registroOperacion(
    String nifDeclarante,
    int anio,
    Operacion347 op,
  ) {
    final buf = List<String>.filled(_kRegistroLen, ' ');

    // Pos 1:     Tipo registro = "2"
    _write(buf, 0, '2');
    // Pos 2-4:   Modelo = "347"
    _write(buf, 1, '347');
    // Pos 5-8:   Ejercicio
    _write(buf, 4, anio.toString().padLeft(4, '0'));
    // Pos 9-17:  NIF declarante (9 chars)
    _write(buf, 8, _padAlpha(_cleanNif(nifDeclarante), 9));
    // Pos 18-26: NIF tercero (9 chars)
    _write(buf, 17, _padAlpha(_cleanNif(op.nifTercero), 9));
    // Pos 27-66: Razón social tercero (40 chars)
    _write(buf, 26, _padAlpha(_normalizarTexto(op.nombreTercero), 40));
    // Pos 67-67: Clave operación (A=adquirente/compra, V=vendedor/venta)
    _write(buf, 66, op.tipo.codigo);
    // Pos 68-80: Importe anual (13 dígitos, céntimos, sin signo)
    _write(buf, 67, _importeCentimos(op.totalAnual, 13));
    // Pos 81-81: Operación seguro (S/N)
    _write(buf, 80, 'N');
    // Pos 82-82: Arrendamiento local negocio (S/N)
    _write(buf, 81, op.tipo == TipoOperacion347.arrendamiento ? 'S' : 'N');
    // Pos 83-91: NIF representante (9 chars, blancos si no aplica)
    // Pos 92-500: Blancos

    assert(buf.length == _kRegistroLen);
    return buf.join();
  }

  // ── UTILIDADES ────────────────────────────────────────────────────────────

  static void _write(List<String> buf, int pos, String texto) {
    for (var i = 0; i < texto.length && (pos + i) < buf.length; i++) {
      buf[pos + i] = texto[i];
    }
  }

  static String _padAlpha(String valor, int len) {
    if (valor.length >= len) return valor.substring(0, len);
    return valor.padRight(len);
  }

  /// Convierte euros a céntimos y formatea con ceros a la izquierda.
  static String _importeCentimos(double euros, int len) {
    final centimos = (euros.abs() * 100).round();
    return centimos.toString().padLeft(len, '0');
  }

  static String _cleanNif(String nif) =>
      nif.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static String _normalizarTexto(String input) {
    const map = {
      'á': 'A', 'à': 'A', 'ä': 'A', 'â': 'A',
      'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A',
      'é': 'E', 'è': 'E', 'ë': 'E', 'ê': 'E',
      'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
      'í': 'I', 'ì': 'I', 'ï': 'I', 'î': 'I',
      'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
      'ó': 'O', 'ò': 'O', 'ö': 'O', 'ô': 'O',
      'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O',
      'ú': 'U', 'ù': 'U', 'ü': 'U', 'û': 'U',
      'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
      'ñ': 'N', 'Ñ': 'N', 'ç': 'C', 'Ç': 'C',
    };
    final sb = StringBuffer();
    for (final rune in input.runes) {
      final c = String.fromCharCode(rune);
      sb.write(map[c] ?? c);
    }
    return sb.toString().toUpperCase();
  }

  static Uint8List _encodeIso88591(String s) {
    return Uint8List.fromList(
        s.codeUnits.map((c) => c > 255 ? 0x3F : c).toList());
  }
}

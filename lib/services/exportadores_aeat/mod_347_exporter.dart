import '../../domain/modelos/factura.dart';
import '../../domain/modelos/factura_recibida.dart';

// ── UMBRAL LEGAL ──────────────────────────────────────────────────────────────
const double _kUmbral347 = 3005.06; // Importe mínimo (artículo 33 RD 1065/2007)

// ── MODELOS ───────────────────────────────────────────────────────────────────

enum TipoOperacion347 {
  compra('C', 'Compra a proveedor'),
  venta('V', 'Venta a cliente'),
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

  /// Genera fichero MOD 347 en formato AEAT
  static String generarFichero({
    required String nifDeclarante,
    required String nombreDeclarante,
    required Resumen347 resumen,
  }) {
    final buf = StringBuffer();

    // TIPO 1 — Registro del declarante
    buf.writeln(_registroDeclarante(
      nifDeclarante,
      nombreDeclarante,
      resumen,
    ));

    // TIPO 2 — Un registro por cada operación declarable
    for (final op in resumen.operacionesVenta) {
      buf.writeln(_registroOperacion(nifDeclarante, resumen.anio, op));
    }
    for (final op in resumen.operacionesCompra) {
      buf.writeln(_registroOperacion(nifDeclarante, resumen.anio, op));
    }

    return buf.toString();
  }

  static String _registroDeclarante(
    String nif,
    String nombre,
    Resumen347 r,
  ) =>
      [
        '1',                                         // Tipo de registro
        '347',                                       // Modelo
        r.anio.toString(),                           // Ejercicio
        nif.padRight(9),                             // NIF declarante
        nombre.padRight(40).substring(0, 40),        // Nombre
        'T',                                         // Tipo soporte T=Telemático
        ''.padLeft(13, '0'),                         // Número justificante (vacío)
        r.numDeclaraciones.toString().padLeft(9, '0'), // Núm operaciones
        (r.totalVentas + r.totalCompras)
            .toStringAsFixed(2)
            .replaceAll('.', '')
            .padLeft(16, '0'),                       // Importe total (sin decimales + céntimos)
      ].join('|');

  static String _registroOperacion(
    String nifDeclarante,
    int anio,
    Operacion347 op,
  ) =>
      [
        '2',                                         // Tipo de registro
        '347',
        anio.toString(),
        nifDeclarante.padRight(9),
        op.nifTercero.padRight(9),
        op.nombreTercero.padRight(40).substring(0, 40),
        op.tipo.codigo,                              // C=Compra, V=Venta, A=Arrend.
        op.totalAnual.toStringAsFixed(2)
            .replaceAll('.', '').padLeft(16, '0'),   // Importe total
        op.ivaAnual.toStringAsFixed(2)
            .replaceAll('.', '').padLeft(16, '0'),   // IVA total
        op.numOperaciones.toString().padLeft(6, '0'),
      ].join('|');
}


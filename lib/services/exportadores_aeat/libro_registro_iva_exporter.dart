import '../../domain/modelos/factura.dart';
import '../../domain/modelos/factura_recibida.dart';

/// Exportador de Libro Registro IVA en formato AEAT
/// Genera ficheros LL0 (emitidas) y LL1 (recibidas)
class LibroRegistroIvaExporter {
  /// Genera LIBRO REGISTRO FACTURAS EMITIDAS (LL0) en formato AEAT
  /// Formato ASCII con estructura rígida de registros
  static String generarLibroEmitidas(
    String nifEmpresa,
    int mes,
    int anio,
    List<Factura> facturas,
  ) {
    final buffer = StringBuffer();

    // ENCABEZADO
    buffer.writeln(_buildEncabezado(nifEmpresa, mes, anio, 'LL0'));

    // LÍNEAS DE FACTURAS EMITIDAS
    for (final factura in facturas) {
      buffer.writeln(_buildLineaLL0(factura));
    }

    // PIE
    buffer.writeln(_buildPie(facturas.length));

    return buffer.toString();
  }

  /// Genera LIBRO REGISTRO FACTURAS RECIBIDAS (LL1) en formato AEAT
  static String generarLibroRecibidas(
    String nifEmpresa,
    int mes,
    int anio,
    List<FacturaRecibida> facturas,
  ) {
    final buffer = StringBuffer();

    // ENCABEZADO
    buffer.writeln(_buildEncabezado(nifEmpresa, mes, anio, 'LL1'));

    // LÍNEAS DE FACTURAS RECIBIDAS
    for (final factura in facturas) {
      buffer.writeln(_buildLineaLL1(factura));
    }

    // PIE
    buffer.writeln(_buildPie(facturas.length));

    return buffer.toString();
  }

  /// Construye encabezado del lote
  static String _buildEncabezado(
    String nif,
    int mes,
    int anio,
    String tipo,
  ) {
    return [
      '1',                                      // Tipo registro 1 = Encabezado
      '12',                                     // Versión del formato
      anio.toString().padLeft(4, '0'),
      mes.toString().padLeft(2, '0'),
      tipo,                                     // LL0 o LL1
      nif.padRight(9),
      _fechaHoraAhora(),                       // Fecha hora creación
      '1',                                      // Número lote
    ].join('|');
  }

  /// Construye línea de factura emitida (LL0)
  /// Las facturas rectificativas llevan tipo operación 'R' e incluyen
  /// la referencia a la factura original (Art. 15 RD 1619/2012).
  static String _buildLineaLL0(Factura factura) {
    final tipoOp = factura.esRectificativa ? 'R1' : '01';
    final campos = [
      '2',                                      // Tipo registro 2 = Detalle
      factura.datosFiscales?.nif ?? '',        // NIF cliente
      factura.numeroFactura,                   // Número factura
      factura.subtotal.toStringAsFixed(2),     // Base imponible
      factura.totalIva.toStringAsFixed(2),     // IVA repercutido
      tipoOp,                                  // Tipo operación
      _fmtDate(factura.fechaEmision),         // Fecha emisión
    ];

    // Campos adicionales para rectificativas
    if (factura.esRectificativa) {
      campos.addAll([
        factura.facturaOriginalNumero ?? '',   // Número factura rectificada
        factura.facturaOriginalFecha != null
            ? _fmtDate(factura.facturaOriginalFecha!)
            : '',                              // Fecha factura rectificada
        factura.metodoRectificacion?.codigoAEAT ?? 'S', // S/I
      ]);
    }

    return campos.join('|');
  }

  /// Construye línea de factura recibida (LL1)
  static String _buildLineaLL1(FacturaRecibida factura) {
    return [
      '2',                                      // Tipo registro 2 = Detalle
      factura.nifProveedor,                   // NIF proveedor
      factura.numeroFactura,                   // Número factura
      factura.baseImponible.toStringAsFixed(2), // Base imponible
      factura.ivaDeducibleReal.toStringAsFixed(2), // IVA soportado deducible
      factura.ivaDeducible ? '01' : '02',     // 01: deducible, 02: no deducible
      _fmtDate(factura.fechaRecepcion),       // Fecha recepción
    ].join('|');
  }

  /// Construye pie del lote
  static String _buildPie(int numLineas) {
    return [
      '3',                                      // Tipo registro 3 = Pie
      numLineas.toString(),
      '',
    ].join('|');
  }

  /// Formatea fecha YYYYMMDD
  static String _fmtDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  /// Obtiene fecha/hora actual en formato YYYYMMDDHHMMSS
  static String _fechaHoraAhora() {
    final ahora = DateTime.now();
    return '${ahora.year}'
        '${ahora.month.toString().padLeft(2, '0')}'
        '${ahora.day.toString().padLeft(2, '0')}'
        '${ahora.hour.toString().padLeft(2, '0')}'
        '${ahora.minute.toString().padLeft(2, '0')}'
        '${ahora.second.toString().padLeft(2, '0')}';
  }
}


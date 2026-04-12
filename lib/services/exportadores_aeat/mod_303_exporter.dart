import '../../domain/modelos/factura.dart';
import '../../domain/modelos/factura_recibida.dart';

/// DTO de entrada para exportar Modelo 303 en formato posicional AEAT.
class DatosMod303 {
  final List<Factura> facturasEmitidas;
  final List<FacturaRecibida> facturasRecibidas;
  final String nifEmpresa;
  final String ejercicio; // YYYY
  final String periodo; // 01..04 (T1..T4)

  const DatosMod303({
    required this.facturasEmitidas,
    required this.facturasRecibidas,
    required this.nifEmpresa,
    required this.ejercicio,
    required this.periodo,
  });

  // Base imponible régimen general (21%) desde emitidas (fecha de emisión).
  // Las facturas rectificativas se incluyen (sus importes negativos reducen la base).
  double get baseGeneral => facturasEmitidas
      .where((f) => f.estado != EstadoFactura.anulada)
      .fold<double>(0.0, (sum, f) =>
          sum + f.lineas
              .where((l) => l.porcentajeIva == 21)
              .fold<double>(0.0, (s, l) => s + l.subtotalSinIva));

  // Cuota repercutida total (21% + 10% + 4%) desde emitidas.
  // Las facturas rectificativas reducen la cuota cuando tienen importes negativos.
  double get cuotaRepercutida =>
      cuotaGeneral + cuotaReducida + cuotaSuperReducida;

  // Base imponible soportada deducible desde recibidas.
  double get baseSoportadaDeducible => facturasRecibidas
      .where((f) => f.estado != EstadoFacturaRecibida.rechazada && f.ivaDeducible)
      .fold<double>(0.0, (sum, f) => sum + f.baseImponible);

  // Cuota soportada deducible desde recibidas.
  double get cuotaSoportadaDeducible => facturasRecibidas
      .where((f) => f.estado != EstadoFacturaRecibida.rechazada && f.ivaDeducible)
      .fold<double>(0.0, (sum, f) => sum + f.importeIva);

  // Resultado de liquidación (a ingresar/devolver).
  double get resultado => cuotaRepercutida - cuotaSoportadaDeducible;
}

/// Exportador del Modelo 303 en formato posicional.
///
/// Reglas aplicadas:
/// - Longitud fija por registro: 500 caracteres
/// - Fin de línea: CRLF
/// - Alfanuméricos: izquierda + espacios
/// - Numéricos (importes): derecha + ceros, en céntimos
class Mod303Exporter {
  static const int _registroLen = 500;

  /// API principal solicitada.
  Future<String> exportar(DatosMod303 datos) async {
    final cabecera = _buildRegistroTipo1(datos);
    final detalle = _buildRegistroTipo2(datos);
    return '$cabecera\r\n$detalle\r\n';
  }

  /// Compatibilidad con llamadas existentes del proyecto.
  static Future<String> generar({
    required String nifEmpresa,
    required int trimestre,
    required int anio,
    required double baseGeneral,
    required double cuotaGeneral,
    required double baseReducida,
    required double cuotaReducida,
    required double baseSuperReducida,
    required double cuotaSuperReducida,
    required double ivaRepercutido,
    required double ivaSoportado,
    required double compensaciones,
    String? nifDeclarante,
    String? apellido1,
    String? apellido2,
    String? nombre,
  }) async {
    // Monta un DTO mínimo para mantener compatibilidad sin romper servicios.
    final datos = _fromLegacy(
  double get cuotaRepercutida => facturasEmitidas
      .where((f) => f.estado != EstadoFactura.anulada)
      .fold<double>(0.0, (sum, f) =>
          sum + f.lineas.fold<double>(0.0, (s, l) => s + l.importeIva));
      baseGeneral: baseGeneral,
      cuotaGeneral: cuotaGeneral,
      baseReducida: baseReducida,
      cuotaReducida: cuotaReducida,
      baseSuperReducida: baseSuperReducida,
      cuotaSuperReducida: cuotaSuperReducida,
      ivaSoportado: ivaSoportado,
    );
    return Mod303Exporter().exportar(datos);
  }

  static DatosMod303 _fromLegacy({
    required String nifEmpresa,
    required int trimestre,
    required int anio,
    required double baseGeneral,
    required double cuotaGeneral,
    required double baseReducida,
    required double cuotaReducida,
    required double baseSuperReducida,
    required double cuotaSuperReducida,
    required double ivaSoportado,
  }) {
    // Construimos facturas sintéticas mínimas para reutilizar DTO.
    final emitida = Factura(
      id: 'legacy',
      empresaId: 'legacy',
      numeroFactura: 'LEGACY',
      tipo: TipoFactura.venta_directa,
      estado: EstadoFactura.pagada,
      clienteNombre: 'LEGACY',
      lineas: [
        if (baseGeneral != 0)
          LineaFactura(
              descripcion: 'Base 21',
              precioUnitario: baseGeneral,
              cantidad: 1,
              porcentajeIva: 21),
        if (baseReducida != 0)
          LineaFactura(
              descripcion: 'Base 10',
              precioUnitario: baseReducida,
              cantidad: 1,
              porcentajeIva: 10),
        if (baseSuperReducida != 0)
          LineaFactura(
              descripcion: 'Base 4',
              precioUnitario: baseSuperReducida,
              cantidad: 1,
              porcentajeIva: 4),
      ],
      subtotal: baseGeneral + baseReducida + baseSuperReducida,
      totalIva: cuotaGeneral + cuotaReducida + cuotaSuperReducida,
      total: baseGeneral + baseReducida + baseSuperReducida +
          cuotaGeneral + cuotaReducida + cuotaSuperReducida,
      historial: const [],
      fechaEmision: DateTime.now(),
    );

    final recibida = FacturaRecibida(
      id: 'legacy',
      empresaId: 'legacy',
      numeroFactura: 'LEGACY-R',
      fechaEmision: DateTime.now(),
      fechaRecepcion: DateTime.now(),
      nifProveedor: 'B00000000',
      nombreProveedor: 'LEGACY',
      baseImponible: 0,
      porcentajeIva: 21,
      importeIva: ivaSoportado,
      ivaDeducible: true,
      totalConImpuestos: ivaSoportado,
      fechaCreacion: DateTime.now(),
    );

    return DatosMod303(
      facturasEmitidas: [emitida],
      facturasRecibidas: [recibida],
      nifEmpresa: nifEmpresa,
      ejercicio: anio.toString().padLeft(4, '0'),
      periodo: trimestre.toString().padLeft(2, '0'),
    );
  }

  // ── REGISTRO TIPO 1 (CABECERA) ───────────────────────────────────────────
  String _buildRegistroTipo1(DatosMod303 d) {
    final r = _RegistroPosicional(_registroLen);

    // Pos 1-1: Tipo de registro = "1"
    r.setAlpha(1, 1, '1');

    // Pos 2-4: Modelo = "303"
    r.setAlpha(2, 4, '303');

    // Pos 8-24 (len 17): NIF declarante (9 chars izq + espacios)
    r.setAlpha(8, 24, _normalizarNif9(d.nifEmpresa));

    // Pos 25-28 (len 4): Ejercicio
    r.setNumeric(25, 28, int.tryParse(d.ejercicio) ?? 0);

    // Pos 29-30 (len 2): Periodo (01..04)
    r.setNumeric(29, 30, int.tryParse(d.periodo) ?? 0);

    // Resto de posiciones: espacios
    return r.build();
  }

  // ── REGISTRO TIPO 2 (DATOS) ──────────────────────────────────────────────
  String _buildRegistroTipo2(DatosMod303 d) {
    final r = _RegistroPosicional(_registroLen);

    // Pos 1-1: Tipo de registro = "2"
    r.setAlpha(1, 1, '2');

    // Pos 2-4: Modelo = "303"
    r.setAlpha(2, 4, '303');

    // Pos 8-24 (len 17): NIF declarante
    r.setAlpha(8, 24, _normalizarNif9(d.nifEmpresa));

    // Pos 25-28 (len 4): Ejercicio
    r.setNumeric(25, 28, int.tryParse(d.ejercicio) ?? 0);

    // Pos 29-30 (len 2): Periodo (01..04)
    r.setNumeric(29, 30, int.tryParse(d.periodo) ?? 0);

    // ── IVA DEVENGADO ────────────────────────────────────────────────────────
    // Casillas 01-02: Base y cuota al 21% (régimen general)
    r.setImporteCentimos(31, 45, d.baseGeneral);     // Casilla 01 — Base 21%
    r.setImporteCentimos(46, 60, d.cuotaGeneral);    // Casilla 02 — Cuota 21%

    // Casillas 03-04: Base y cuota al 10% (tipo reducido)
    r.setImporteCentimos(61, 75, d.baseReducida);    // Casilla 03 — Base 10%
    r.setImporteCentimos(76, 90, d.cuotaReducida);   // Casilla 04 — Cuota 10%

    // Casillas 05-06: Base y cuota al 4% (superreducido / VPO)
    r.setImporteCentimos(91, 105, d.baseSuperReducida);   // Casilla 05 — Base 4%
    r.setImporteCentimos(106, 120, d.cuotaSuperReducida); // Casilla 06 — Cuota 4%

    // Casillas 07-08: Base al 0% (exento) y cuota = 0
    r.setImporteCentimos(121, 135, d.baseExenta);   // Casilla 07 — Base 0%
    r.setImporteCentimos(136, 150, 0.0);            // Casilla 08 — Cuota 0% = 0

    // Pos 91-91 (len 1): Signo resultado (+/-)
    r.setAlpha(91, 91, d.resultado < 0 ? '-' : '+');
    // ── IVA SOPORTADO ────────────────────────────────────────────────────────
    // Base imponible soportada deducible
    r.setImporteCentimos(151, 165, d.baseSoportadaDeducible);
    // Cuota soportada deducible
    r.setImporteCentimos(166, 180, d.cuotaSoportadaDeducible);

    // Pos 92-106 (len 15): Resultado en céntimos (valor absoluto)
    r.setImporteCentimos(92, 106, d.resultado.abs());
    // ── RESULTADO ────────────────────────────────────────────────────────────
    // Signo resultado (+/-)
    r.setAlpha(181, 181, d.resultado < 0 ? '-' : '+');
    // Resultado en céntimos (valor absoluto)
    r.setImporteCentimos(182, 196, d.resultado.abs());

    // Resto de posiciones: espacios
    return r.build();
  }

  static String _normalizarNif9(String nif) {
    final limpio = nif.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return limpio.length <= 9 ? limpio : limpio.substring(0, 9);
  }

  /// Calcula trimestre a partir de mes.
  static int trimestresDelMes(int mes) {
    if (mes <= 3) return 1;
    // Pos 31-45 (len 15): Base imponible régimen general (casilla base)
    r.setImporteCentimos(31, 45, d.baseGeneral);
      case 2:
        return (mesInicio: 4, mesFin: 6);
      case 3:
        return (mesInicio: 7, mesFin: 9);
      case 4:
        return (mesInicio: 10, mesFin: 12);
      default:
    // Pos 46-60 (len 15): Cuota repercutida
    r.setImporteCentimos(46, 60, d.cuotaRepercutida);

  void setAlpha(int desde, int hasta, String valor) {
    final len = hasta - desde + 1;
    final v = valor.length > len
    // Pos 61-75 (len 15): Base imponible IVA soportado deducible
    r.setImporteCentimos(61, 75, d.baseSoportadaDeducible);
    final raw = valor.toString();
    final v = raw.length > len
        ? raw.substring(raw.length - len)
    // Pos 76-90 (len 15): Cuota soportada deducible
    r.setImporteCentimos(76, 90, d.cuotaSoportadaDeducible);
    setNumeric(desde, hasta, centimos);
  }

  void _write(int desde1Based, String texto) {
    final start = desde1Based - 1;
    for (var i = 0; i < texto.length; i++) {
      _chars[start + i] = texto[i];
    }
  }

  String build() => _chars.join();
}

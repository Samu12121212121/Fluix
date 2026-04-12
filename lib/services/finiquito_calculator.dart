import '../domain/modelos/finiquito.dart';
import '../domain/modelos/nomina.dart';
import 'nominas_service.dart';

/// Calculador de finiquitos y liquidaciones según ET arts. 49-53.
///
/// Implementa:
/// - Salario pendiente (días trabajados no cobrados)
/// - Vacaciones no disfrutadas (según convenio)
/// - Prorrata de pagas extra
/// - Indemnización por despido (improcedente/procedente/temporal/ERE)
/// - Cálculo dual pre/post 12/02/2012 (Reforma Laboral)
/// - IRPF: exención despido improcedente (art. 7.e LIRPF)
/// - SS: cuota obrera sobre conceptos cotizables
class FiniquitoCalculator {
  // ── Fecha clave: Reforma Laboral 12/02/2012 ──────────────────────────────
  static final DateTime _fechaReformaLaboral = DateTime(2012, 2, 12);

  // ── SMI 2026 (para límite FOGASA) ────────────────────────────────────────
  // ignore: unused_field
  static const double _smiDiario2026 = 43.50; // ≈15.876 / 365
  // ignore: unused_field
  static const double _limiteFogasaDias = 120;

  // ── Cotización SS trabajador (iguales que NominasService) ─────────────────
  static const double _ssCC      = 4.70;
  static const double _ssDesempl = 1.55;
  static const double _ssFP      = 0.10;
  static const double _ssMei     = 0.15;

  // ── Días de vacaciones por convenio ───────────────────────────────────────
  static const Map<String, int> diasVacacionesPorConvenio = {
    'hosteleria-guadalajara':                   30,
    'comercio-guadalajara':                     30,
    'peluqueria-estetica-gimnasios':            30,
    'industrias-carnicas-guadalajara-2025':      31,
    'veterinarios-guadalajara-2026':            30,
    'construccion-obras-publicas-guadalajara':  30,
  };

  /// Meses de devengo de las pagas extra por convenio.
  /// Cada paga se define con [nombre, mesPago].
  /// El devengo va desde mesPago del año anterior hasta mesPago del año actual.
  static const Map<String, List<List<dynamic>>> _pagasExtraPorConvenio = {
    'hosteleria-guadalajara': [
      ['Paga extra marzo', 3],
      ['Paga extra julio', 7],
      ['Paga extra navidad', 12],
    ],
    'comercio-guadalajara': [
      ['Paga extra julio', 7],
      ['Paga extra navidad', 12],
    ],
    'peluqueria-estetica-gimnasios': [
      ['Paga extra julio', 7],
      ['Paga extra navidad', 12],
    ],
    'industrias-carnicas-guadalajara-2025': [
      ['Paga extra julio', 7],
      ['Paga extra navidad', 12],
    ],
    'veterinarios-guadalajara-2026': [
      ['Paga extra julio', 7],
      ['Paga extra navidad', 12],
    ],
    'construccion-obras-publicas-guadalajara': [
      ['Paga extra verano', 6],
      ['Paga extra navidad', 12],
    ],
  };

  /// Calcula un finiquito completo.
  ///
  /// [config] datos salariales del empleado.
  /// [empleadoNombre] nombre del empleado.
  /// [empleadoId] ID del empleado.
  /// [empresaId] ID de la empresa.
  /// [fechaBaja] fecha de baja del trabajador.
  /// [causaBaja] causa legal de la baja.
  /// [diasTrabajadosMes] días del mes de baja ya trabajados.
  /// [diasVacacionesDisfrutadas] días de vacaciones ya disfrutadas en el año.
  /// [diasVacacionesConvenio] días de vacaciones del convenio (30 por defecto).
  /// [convenioId] ID del convenio colectivo (para pagas extra).
  static Finiquito calcular({
    required DatosNominaEmpleado config,
    required String empleadoNombre,
    required String empleadoId,
    required String empresaId,
    String? empleadoNif,
    String? empleadoNss,
    String? empresaNombre,
    String? empresaCif,
    required DateTime fechaBaja,
    required CausaBaja causaBaja,
    required int diasTrabajadosMes,
    required int diasVacacionesDisfrutadas,
    int? diasVacacionesConvenio,
    String? convenioId,
    String? notas,
  }) {
    final fechaInicio = config.fechaInicioContrato ?? DateTime.now();
    final diasMesBaja = _diasEnMes(fechaBaja.year, fechaBaja.month);
    final diasVacConvenio = diasVacacionesConvenio
        ?? diasVacacionesPorConvenio[convenioId]
        ?? 30;

    // Salario anual con complementos (base indemnización)
    final complementoAnual = config.complementoFijo * 12;
    final salarioTotalAnual = config.salarioBrutoAnual + complementoAnual;
    final salarioDiario = salarioTotalAnual / 365;

    // ═══════════════════════════════════════════════════════════════════════
    // 1. SALARIO PENDIENTE
    // ═══════════════════════════════════════════════════════════════════════
    final salarioMensual = config.salarioBrutoAnual / 12 + config.complementoFijo;
    final salarioPendiente = (salarioMensual / diasMesBaja) * diasTrabajadosMes;

    // ═══════════════════════════════════════════════════════════════════════
    // 2. VACACIONES NO DISFRUTADAS
    // ═══════════════════════════════════════════════════════════════════════
    // Se calculan proporcionalmente a los días trabajados del contrato.
    // Para contratos ≥ 1 año se generan los días completos del convenio;
    // para contratos < 1 año se prorratea (art. 38 ET).
    final diasTrabajados = fechaBaja.difference(fechaInicio).inDays + 1;
    final diasVacGeneradosRaw = (diasVacConvenio * diasTrabajados / 365.0).floor();
    final diasVacGenerados = diasVacGeneradosRaw.clamp(0, diasVacConvenio);
    final diasVacPendientes = (diasVacGenerados - diasVacacionesDisfrutadas).clamp(0, diasVacConvenio);
    final baseVacaciones = config.pagasProrrateadas
        ? salarioTotalAnual / 365.0
        : config.salarioBrutoAnual / 365.0 + config.complementoFijo / 30.42;
    final importeVacaciones = baseVacaciones * diasVacPendientes;

    // ═══════════════════════════════════════════════════════════════════════
    // 3. PRORRATA DE PAGAS EXTRA
    // ═══════════════════════════════════════════════════════════════════════
    final pagasInfo = _calcularProrrataPagas(
      config: config,
      fechaBaja: fechaBaja,
      convenioId: convenioId,
    );
    final totalProrrataPagas = pagasInfo.fold(0.0, (s, p) => s + p.importe);

    // ═══════════════════════════════════════════════════════════════════════
    // 4. INDEMNIZACIÓN
    // ═══════════════════════════════════════════════════════════════════════
    double indemnizacion = 0;
    double indemnizacionExenta = 0;
    double indemnizacionSujeta = 0;
    double diasIndemnizacion = 0;
    double? indemnTramoAnterior;
    double? indemnTramoPosterior;

    if (causaBaja.tieneIndemnizacion) {
      final resultado = _calcularIndemnizacion(
        causaBaja: causaBaja,
        fechaInicio: fechaInicio,
        fechaBaja: fechaBaja,
        salarioDiario: salarioDiario,
        salarioMensual: salarioTotalAnual / 12,
      );
      indemnizacion = resultado.total;
      diasIndemnizacion = resultado.diasTotales;
      indemnTramoAnterior = resultado.tramoAnterior;
      indemnTramoPosterior = resultado.tramoPosterior;

      // Exención IRPF: art. 7.e LIRPF — solo despido improcedente
      if (causaBaja.indemnizacionExentaIrpf) {
        // Límite exento = 33 días × años × salarioDiario (módulo legal)
        final anios = fechaBaja.difference(fechaInicio).inDays / 365.25;
        final limiteExento = 33 * anios * salarioDiario;
        indemnizacionExenta = indemnizacion.clamp(0, limiteExento);
        indemnizacionSujeta = (indemnizacion - indemnizacionExenta).clamp(0, double.infinity);
      } else {
        // Despido procedente/objetivo, fin temporal, ERE: tributa todo
        indemnizacionSujeta = indemnizacion;
        indemnizacionExenta = 0;
      }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // 5. RETENCIONES IRPF
    // ═══════════════════════════════════════════════════════════════════════
    // Base IRPF = salario pendiente + vacaciones + pagas + indemnización sujeta
    final baseIrpf = salarioPendiente + importeVacaciones + totalProrrataPagas + indemnizacionSujeta;

    // Tipo IRPF: usar el habitual del empleado
    final porcentajeIrpf = NominasService.calcularPorcentajeIrpf(
      config.salarioBrutoAnual,
      config: config,
      comunidad: config.comunidadAutonoma,
    );
    final importeIrpf = baseIrpf * porcentajeIrpf / 100;

    // ═══════════════════════════════════════════════════════════════════════
    // 6. SS EN FINIQUITO
    // ═══════════════════════════════════════════════════════════════════════
    // Cotizan: salario pendiente + vacaciones + pagas. NO cotiza la indemnización.
    final baseSS = salarioPendiente + importeVacaciones + totalProrrataPagas;
    final totalSSTrabajador = baseSS * (_ssCC + _ssDesempl + _ssFP + _ssMei) / 100;

    return Finiquito(
      id: '',
      empresaId: empresaId,
      empleadoId: empleadoId,
      empleadoNombre: empleadoNombre,
      empleadoNif: empleadoNif ?? config.nif,
      empleadoNss: empleadoNss ?? config.nss,
      empresaNombre: empresaNombre,
      empresaCif: empresaCif,
      fechaBaja: fechaBaja,
      causaBaja: causaBaja,
      fechaInicioContrato: fechaInicio,
      salarioBrutoAnual: config.salarioBrutoAnual,
      numPagas: config.numPagas,
      pagasProrrateadas: config.pagasProrrateadas,
      complementoFijoMensual: config.complementoFijo,
      convenioId: convenioId,
      diasTrabajadosMes: diasTrabajadosMes,
      diasMesBaja: diasMesBaja,
      diasVacacionesDisfrutadas: diasVacacionesDisfrutadas,
      diasVacacionesConvenio: diasVacConvenio,
      salarioPendiente: _round2(salarioPendiente),
      importeVacaciones: _round2(importeVacaciones),
      diasVacacionesPendientes: diasVacPendientes,
      prorrataPagasExtra: pagasInfo,
      totalProrrataPagas: _round2(totalProrrataPagas),
      indemnizacion: _round2(indemnizacion),
      indemnizacionExenta: _round2(indemnizacionExenta),
      indemnizacionSujeta: _round2(indemnizacionSujeta),
      diasIndemnizacion: diasIndemnizacion,
      indemnizacionTramoAnterior: indemnTramoAnterior != null ? _round2(indemnTramoAnterior) : null,
      indemnizacionTramoPosterior: indemnTramoPosterior != null ? _round2(indemnTramoPosterior) : null,
      porcentajeIrpf: _round2(porcentajeIrpf),
      baseIrpf: _round2(baseIrpf),
      importeIrpf: _round2(importeIrpf),
      baseSS: _round2(baseSS),
      cuotaObreraSSFiniquito: _round2(totalSSTrabajador),
      estado: EstadoFiniquito.borrador,
      fechaCreacion: DateTime.now(),
      notas: notas,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO DE INDEMNIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  static _ResultadoIndemnizacion _calcularIndemnizacion({
    required CausaBaja causaBaja,
    required DateTime fechaInicio,
    required DateTime fechaBaja,
    required double salarioDiario,
    required double salarioMensual,
  }) {
    final diasPorAnio = causaBaja.diasPorAnio;
    final maxMens = causaBaja.maxMensualidades;

    // ── Despido improcedente: cálculo dual si contrato anterior a 12/02/2012 ──
    if (causaBaja == CausaBaja.despidoImprocedente &&
        fechaInicio.isBefore(_fechaReformaLaboral)) {
      return _calcularDual(
        fechaInicio: fechaInicio,
        fechaBaja: fechaBaja,
        salarioDiario: salarioDiario,
        salarioMensual: salarioMensual,
      );
    }

    // ── Cálculo estándar ────────────────────────────────────────────────────
    final diasAntiguedad = fechaBaja.difference(fechaInicio).inDays;
    final anios = diasAntiguedad / 365.25;
    final diasIndem = diasPorAnio * anios;

    double total = salarioDiario * diasIndem;

    // Aplicar tope de mensualidades si existe
    if (maxMens > 0) {
      final tope = salarioMensual * maxMens;
      if (total > tope) total = tope;
    }

    return _ResultadoIndemnizacion(
      total: total,
      diasTotales: diasIndem,
    );
  }

  /// Cálculo dual para contratos anteriores a la Reforma Laboral del 12/02/2012.
  /// Tramo anterior: 45 días/año (tope 42 mensualidades / 1.260 días).
  /// Tramo posterior: 33 días/año.
  /// Tope global: 720 días (24 mensualidades), salvo que el tramo anterior sea mayor.
  static _ResultadoIndemnizacion _calcularDual({
    required DateTime fechaInicio,
    required DateTime fechaBaja,
    required double salarioDiario,
    required double salarioMensual,
  }) {
    // Tramo 1: hasta 11/02/2012 → 45 días/año
    final diasTramo1 = _fechaReformaLaboral.difference(fechaInicio).inDays;
    final aniosTramo1 = diasTramo1 / 365.25;
    final diasIndemTramo1 = 45 * aniosTramo1;
    var indemnTramo1 = salarioDiario * diasIndemTramo1;
    // Tope tramo anterior: 42 mensualidades
    final topeTramo1 = salarioMensual * 42;
    if (indemnTramo1 > topeTramo1) indemnTramo1 = topeTramo1;

    // Tramo 2: desde 12/02/2012 → 33 días/año
    final diasTramo2 = fechaBaja.difference(_fechaReformaLaboral).inDays;
    final aniosTramo2 = diasTramo2 / 365.25;
    final diasIndemTramo2 = 33 * aniosTramo2;
    final indemnTramo2 = salarioDiario * diasIndemTramo2;

    var total = indemnTramo1 + indemnTramo2;

    // Tope global: 720 días (24 mensualidades), pero no puede ser inferior
    // a la indemnización del tramo anterior por sí sola
    final topeGlobal = salarioDiario * 720;
    if (total > topeGlobal && indemnTramo1 < topeGlobal) {
      total = topeGlobal;
    }

    return _ResultadoIndemnizacion(
      total: total,
      diasTotales: diasIndemTramo1 + diasIndemTramo2,
      tramoAnterior: indemnTramo1,
      tramoPosterior: indemnTramo2,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRORRATA DE PAGAS EXTRA
  // ═══════════════════════════════════════════════════════════════════════════

  static List<ProrataPagaExtra> _calcularProrrataPagas({
    required DatosNominaEmpleado config,
    required DateTime fechaBaja,
    String? convenioId,
  }) {
    // Si las pagas están prorrateadas, ya están incluidas en el salario mensual
    if (config.pagasProrrateadas) return [];
    // Si 12 pagas no hay pagas extra
    if (config.numPagas <= 12) return [];

    final importePaga = config.salarioBrutoAnual / config.numPagas;

    // Buscar definición de pagas del convenio, o usar default (julio + navidad)
    final pagasDef = _pagasExtraPorConvenio[convenioId]
        ?? [['Paga extra julio', 7], ['Paga extra navidad', 12]];

    // Añadir pagas extra si hay 15
    final List<List<dynamic>> pagasEfectivas;
    if (config.numPagas == 15 && pagasDef.length < 3) {
      pagasEfectivas = [
        ...pagasDef,
        ['Paga extra marzo', 3],
      ];
    } else {
      pagasEfectivas = pagasDef;
    }

    final resultado = <ProrataPagaExtra>[];

    for (final paga in pagasEfectivas) {
      final nombre = paga[0] as String;
      final mesPago = paga[1] as int;

      // Devengo: desde el mes de pago del año anterior hasta el mes de pago actual
      // Calculamos los días devengados desde la última paga hasta la fecha de baja
      final ultimoPago = DateTime(
        fechaBaja.month <= mesPago ? fechaBaja.year - 1 : fechaBaja.year,
        mesPago,
        1,
      );

      // Si el contrato empezó después de la última paga, contar desde inicio contrato
      final fechaInicio = config.fechaInicioContrato;
      final inicioDevengo = (fechaInicio != null && fechaInicio.isAfter(ultimoPago))
          ? fechaInicio
          : ultimoPago;

      final diasDevengados = fechaBaja.difference(inicioDevengo).inDays;
      if (diasDevengados <= 0) continue;

      // Proporción sobre 365 días
      final importe = (importePaga / 365) * diasDevengados;

      resultado.add(ProrataPagaExtra(
        nombre: nombre,
        diasDevengados: diasDevengados,
        importe: _round2(importe),
      ));
    }

    return resultado;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════════════════════

  static int _diasEnMes(int anio, int mes) => DateTime(anio, mes + 1, 0).day;

  static double _round2(double v) => (v * 100).roundToDouble() / 100;
}

// ── Resultado interno ──────────────────────────────────────────────────────────

class _ResultadoIndemnizacion {
  final double total;
  final double diasTotales;
  final double? tramoAnterior;
  final double? tramoPosterior;

  const _ResultadoIndemnizacion({
    required this.total,
    required this.diasTotales,
    this.tramoAnterior,
    this.tramoPosterior,
  });
}



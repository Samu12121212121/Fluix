import '../domain/modelos/complemento_nomina.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE COMPLEMENTOS VARIABLES
// Lógica fiscal para cada tipo de complemento salarial.
// ═══════════════════════════════════════════════════════════════════════════════

class ComplementosService {
  static final ComplementosService _i = ComplementosService._();
  factory ComplementosService() => _i;
  ComplementosService._();

  /// Calcula los importes que cotizan a SS e IRPF para un complemento,
  /// aplicando las exenciones legales 2026 cuando corresponda.
  ///
  /// [transporteAcumuladoAnual] — Para plus transporte, el acumulado del año
  /// antes de este mes (para verificar el límite de 1.500€/año).
  /// [diasLaborablesMes] — Para manutención, nº de días laborables del mes.
  ComplementoNomina calcularFiscalidad({
    required TipoComplemento tipo,
    required String descripcion,
    required double importe,
    double transporteAcumuladoAnual = 0,
    int diasLaborablesMes = 22,
    bool pernoctaExtranjero = false,
    bool pernocta = false,
  }) {
    double importeCotizaSS = importe;
    double importeTributaIRPF = importe;

    switch (tipo) {
      case TipoComplemento.plusTransporte:
        // Exento hasta 1.500€/año (art. 9 RIRPF)
        final limiteRestante = (ConstantesComplementos2026.transporteExentoAnual -
            transporteAcumuladoAnual).clamp(0.0, double.infinity);
        final exento = importe.clamp(0.0, limiteRestante);
        importeCotizaSS = importe - exento;
        importeTributaIRPF = importe - exento;
        break;

      case TipoComplemento.plusMantencion:
        // Exento hasta los límites diarios legales (art. 9 RIRPF)
        final double limiteDiario;
        if (pernoctaExtranjero) {
          limiteDiario = pernocta
              ? ConstantesComplementos2026.manutencionPernoctaExtranjero
              : ConstantesComplementos2026.manutencionSinPernoctaExtranjero;
        } else {
          limiteDiario = pernocta
              ? ConstantesComplementos2026.manutencionPernoctaEspana
              : ConstantesComplementos2026.manutencionSinPernoctaEspana;
        }
        final exentoMes = limiteDiario * diasLaborablesMes;
        final exento = importe.clamp(0.0, exentoMes);
        importeCotizaSS = importe - exento;
        importeTributaIRPF = importe - exento;
        break;

      case TipoComplemento.productividad:
      case TipoComplemento.comisionVentas:
      case TipoComplemento.pagaExtraProrrateada:
      case TipoComplemento.otro:
        // Cotizan y tributan íntegramente
        importeCotizaSS = importe;
        importeTributaIRPF = importe;
        break;

      case TipoComplemento.horasExtra:
        // Las horas extra se manejan aparte en NominasService
        // (cotización adicional separada), aquí solo el IRPF
        importeCotizaSS = 0; // se calcula en la cotización adicional
        importeTributaIRPF = importe;
        break;
    }

    return ComplementoNomina(
      id: '',
      tipo: tipo,
      descripcion: descripcion,
      importe: importe,
      importeCotizaSS: double.parse(importeCotizaSS.toStringAsFixed(2)),
      importeTributaIRPF: double.parse(importeTributaIRPF.toStringAsFixed(2)),
    );
  }

  /// Totaliza una lista de complementos y devuelve las bases adicionales.
  ComplementosTotales totalizar(List<ComplementoNomina> complementos) {
    double importeTotal = 0;
    double baseSS = 0;
    double baseIRPF = 0;

    for (final c in complementos) {
      importeTotal += c.importe;
      baseSS += c.importeCotizaSS;
      baseIRPF += c.importeTributaIRPF;
    }

    return ComplementosTotales(
      importeTotal: double.parse(importeTotal.toStringAsFixed(2)),
      baseAdicionalSS: double.parse(baseSS.toStringAsFixed(2)),
      baseAdicionalIRPF: double.parse(baseIRPF.toStringAsFixed(2)),
      complementos: complementos,
    );
  }
}

/// Resultado de totalizar complementos.
class ComplementosTotales {
  final double importeTotal;
  final double baseAdicionalSS;
  final double baseAdicionalIRPF;
  final List<ComplementoNomina> complementos;

  const ComplementosTotales({
    required this.importeTotal,
    required this.baseAdicionalSS,
    required this.baseAdicionalIRPF,
    required this.complementos,
  });

  static const ComplementosTotales vacio = ComplementosTotales(
    importeTotal: 0, baseAdicionalSS: 0, baseAdicionalIRPF: 0, complementos: [],
  );
}


/// Constantes de cotización a la Seguridad Social 2026 (España)
/// Cuota a cargo de la empresa según RDL 3/2026 + Orden PJC/178/2025
class SS2026Constants {
  static const double contingenciasComunes = 23.60;
  static const double desempleoIndefinido = 5.50;
  static const double desempleoTemporal = 6.70;
  static const double fogasa = 0.20;
  static const double formacionProfesional = 0.60;
  static const double atepBase = 1.50; // Varía según CNAE
  static const double mei = 0.58;

  static double get totalEmpresaIndefinido =>
      contingenciasComunes + desempleoIndefinido + fogasa + formacionProfesional + atepBase + mei;
  static double get totalEmpresaTemporal =>
      contingenciasComunes + desempleoTemporal + fogasa + formacionProfesional + atepBase + mei;
}

/// Resultado del cálculo de coste empresa
class CosteEmpresaDesglose {
  final double salarioBrutoMensual;
  final double salarioBrutoAnual;
  final double contingenciasComunes;
  final double desempleo;
  final double fogasa;
  final double formacionProfesional;
  final double atep;
  final double mei;
  final double totalSsEmpresaMensual;
  final double costeTotalMensual;
  final double costeTotalAnual;
  final double costePorHora;
  final int numPagas;
  final bool esTemporal;
  final double porcentajeDesempleo;

  const CosteEmpresaDesglose({
    required this.salarioBrutoMensual,
    required this.salarioBrutoAnual,
    required this.contingenciasComunes,
    required this.desempleo,
    required this.fogasa,
    required this.formacionProfesional,
    required this.atep,
    required this.mei,
    required this.totalSsEmpresaMensual,
    required this.costeTotalMensual,
    required this.costeTotalAnual,
    required this.costePorHora,
    required this.numPagas,
    required this.esTemporal,
    required this.porcentajeDesempleo,
  });

  double get porcentajeSobreBruto =>
      salarioBrutoMensual > 0 ? (totalSsEmpresaMensual / salarioBrutoMensual) * 100 : 0;
}

/// Servicio para calcular el coste real de un empleado para la empresa
class CosteEmpresaService {
  static final CosteEmpresaService _i = CosteEmpresaService._();
  factory CosteEmpresaService() => _i;
  CosteEmpresaService._();

  CosteEmpresaDesglose calcular({
    required double salarioBrutoAnual,
    int numPagas = 12,
    bool esTemporal = false,
    double? atepPorcentaje,
    double horasSemanales = 40,
    int semanasAnuales = 47,
  }) {
    final mensual = salarioBrutoAnual / 12;
    final pctDesempleo = esTemporal
        ? SS2026Constants.desempleoTemporal
        : SS2026Constants.desempleoIndefinido;
    final pctAtep = atepPorcentaje ?? SS2026Constants.atepBase;

    final cc = mensual * SS2026Constants.contingenciasComunes / 100;
    final desemp = mensual * pctDesempleo / 100;
    final fog = mensual * SS2026Constants.fogasa / 100;
    final fp = mensual * SS2026Constants.formacionProfesional / 100;
    final at = mensual * pctAtep / 100;
    final meiVal = mensual * SS2026Constants.mei / 100;

    final totalSs = cc + desemp + fog + fp + at + meiVal;
    final costeMensual = mensual + totalSs;
    final costeAnual = salarioBrutoAnual + (totalSs * 12);
    final horasAnuales = horasSemanales * semanasAnuales;
    final costePorHora = horasAnuales > 0 ? costeAnual / horasAnuales : 0.0;

    return CosteEmpresaDesglose(
      salarioBrutoMensual: mensual,
      salarioBrutoAnual: salarioBrutoAnual,
      contingenciasComunes: cc,
      desempleo: desemp,
      fogasa: fog,
      formacionProfesional: fp,
      atep: at,
      mei: meiVal,
      totalSsEmpresaMensual: totalSs,
      costeTotalMensual: costeMensual,
      costeTotalAnual: costeAnual,
      costePorHora: costePorHora,
      numPagas: numPagas,
      esTemporal: esTemporal,
      porcentajeDesempleo: pctDesempleo,
    );
  }
}


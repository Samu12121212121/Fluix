// ═══════════════════════════════════════════════════════════════════════════════
// CALCULADORA DE ANTIGÜEDAD — Complemento por convenio colectivo
// ═══════════════════════════════════════════════════════════════════════════════
//
// Reglas por convenio:
// • Hostelería Guadalajara: 5% salario base × trienio (máx. 5 trienios → 25%)
// • Comercio Guadalajara: 5% salario base × bienio (sin límite)
// • Industrias Cárnicas (estatal): importe fijo en € por trienio según nivel
// • Peluquería / Veterinarios: sin antigüedad automática (campo manual)
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';

/// Resultado del cálculo de antigüedad.
class ResultadoAntiguedad {
  /// Importe mensual del plus de antigüedad (€).
  final double importe;

  /// Años completos de antigüedad a la fecha de cálculo.
  final int aniosCompletos;

  /// Número de trienios/bienios cumplidos.
  final int tramosCumplidos;

  /// Tipo de tramo: 'trienio', 'bienio', 'ninguno'.
  final String tipoTramo;

  /// Descripción para la nómina (ej: "Plus antigüedad (7 años / 2 trienios)").
  final String descripcion;

  const ResultadoAntiguedad({
    required this.importe,
    required this.aniosCompletos,
    required this.tramosCumplidos,
    required this.tipoTramo,
    required this.descripcion,
  });

  static const zero = ResultadoAntiguedad(
    importe: 0,
    aniosCompletos: 0,
    tramosCumplidos: 0,
    tipoTramo: 'ninguno',
    descripcion: '',
  );
}

/// Alerta de cambio de tramo de antigüedad próximo.
class AlertaAntiguedad {
  final String empleadoId;
  final String empleadoNombre;
  final DateTime fechaCambio;
  final int aniosAlCambio;
  final int tramosActuales;
  final int tramosNuevos;
  final double importeActual;
  final double importeNuevo;
  final String tipoTramo;
  final String convenio;

  const AlertaAntiguedad({
    required this.empleadoId,
    required this.empleadoNombre,
    required this.fechaCambio,
    required this.aniosAlCambio,
    required this.tramosActuales,
    required this.tramosNuevos,
    required this.importeActual,
    required this.importeNuevo,
    required this.tipoTramo,
    required this.convenio,
  });

  double get incremento => importeNuevo - importeActual;

  String get mensaje =>
      '⚠️ $empleadoNombre cumple $aniosAlCambio años el '
      '${fechaCambio.day.toString().padLeft(2, '0')}/'
      '${fechaCambio.month.toString().padLeft(2, '0')}/'
      '${fechaCambio.year}'
      ' → Plus $convenio sube de $tramosActuales a $tramosNuevos $tipoTramo'
      '${incremento > 0 ? " (+${incremento.toStringAsFixed(2)}€/mes)" : ""}';
}

// ═══════════════════════════════════════════════════════════════════════════════
// CALCULADORA
// ═══════════════════════════════════════════════════════════════════════════════

class AntiguedadCalculator {
  AntiguedadCalculator._();
  static final instance = AntiguedadCalculator._();

  // ── Identificadores de convenio (mismo que nominas_service) ────────────────
  static const String convHosteleria = 'hosteleria_guadalajara';
  static const String convComercio = 'comercio_guadalajara';
  static const String convPeluqueria = 'peluqueria_guadalajara';
  static const String convCarnicas = 'industrias_carnicas';
  static const String convVeterinarios = 'veterinarios';

  // Mapeo de sector → convenio normalizado
  static String normalizarConvenio(String? sector) {
    switch (sector?.toLowerCase().trim()) {
      case 'hosteleria':
        return convHosteleria;
      case 'comercio':
        return convComercio;
      case 'peluqueria':
        return convPeluqueria;
      case 'carniceria':
      case 'industrias_carnicas':
        return convCarnicas;
      case 'veterinarios':
      case 'veterinaria':
      case 'clinica_veterinaria':
        return convVeterinarios;
      default:
        return '';
    }
  }

  // ── Tabla de trienios Industrias Cárnicas (€/trienio por nivel) ────────────
  // Importes orientativos 2025 — verificar con convenio actualizado
  static const Map<int, double> tablaCarnicasTrienio = {
    1: 45.00,
    2: 42.00,
    3: 39.00,
    4: 36.00,
    5: 34.00,
    6: 32.00,
  };

  // ═════════════════════════════════════════════════════════════════════════════
  // CÁLCULO PRINCIPAL
  // ═════════════════════════════════════════════════════════════════════════════

  /// Calcula el plus de antigüedad según convenio.
  ///
  /// [fechaInicio] — fecha de inicio del contrato.
  /// [fechaCalculo] — fecha a la que se calcula (normalmente fin del mes nómina).
  /// [convenio] — identificador de convenio normalizado.
  /// [salarioBase] — salario base mensual del empleado (para % hostelería/comercio).
  /// [nivelCategoriaCarnicas] — nivel salarial (solo para industrias cárnicas).
  static ResultadoAntiguedad calcular({
    required DateTime fechaInicio,
    required DateTime fechaCalculo,
    required String convenio,
    required double salarioBase,
    int nivelCategoriaCarnicas = 5,
  }) {
    final anios = aniosCompletos(fechaInicio, fechaCalculo);
    if (anios <= 0) return ResultadoAntiguedad.zero;

    switch (convenio) {
      case convHosteleria:
        return _calcularHosteleria(anios, salarioBase);
      case convComercio:
        return _calcularComercio(anios, salarioBase);
      case convCarnicas:
        return _calcularCarnicas(anios, nivelCategoriaCarnicas);
      case convPeluqueria:
      case convVeterinarios:
      default:
        return ResultadoAntiguedad.zero;
    }
  }

  // ── Hostelería: 5% × trienio, máx. 5 trienios ────────────────────────────

  static ResultadoAntiguedad _calcularHosteleria(int anios, double salarioBase) {
    final trienios = (anios / 3).floor().clamp(0, 5);
    if (trienios == 0) {
      return ResultadoAntiguedad(
        importe: 0,
        aniosCompletos: anios,
        tramosCumplidos: 0,
        tipoTramo: 'trienio',
        descripcion: '',
      );
    }
    final importe = salarioBase * 0.05 * trienios;
    return ResultadoAntiguedad(
      importe: importe,
      aniosCompletos: anios,
      tramosCumplidos: trienios,
      tipoTramo: 'trienio',
      descripcion: 'Plus antigüedad ($anios años / $trienios trienios)',
    );
  }

  // ── Comercio: 5% × bienio, sin límite ─────────────────────────────────────

  static ResultadoAntiguedad _calcularComercio(int anios, double salarioBase) {
    final bienios = (anios / 2).floor();
    if (bienios == 0) {
      return ResultadoAntiguedad(
        importe: 0,
        aniosCompletos: anios,
        tramosCumplidos: 0,
        tipoTramo: 'bienio',
        descripcion: '',
      );
    }
    final importe = salarioBase * 0.05 * bienios;
    return ResultadoAntiguedad(
      importe: importe,
      aniosCompletos: anios,
      tramosCumplidos: bienios,
      tipoTramo: 'bienio',
      descripcion: 'Plus antigüedad ($anios años / $bienios bienios)',
    );
  }

  // ── Cárnicas: importe fijo por trienio según nivel ─────────────────────────

  static ResultadoAntiguedad _calcularCarnicas(int anios, int nivel) {
    final trienios = (anios / 3).floor();
    if (trienios == 0) {
      return ResultadoAntiguedad(
        importe: 0,
        aniosCompletos: anios,
        tramosCumplidos: 0,
        tipoTramo: 'trienio',
        descripcion: '',
      );
    }
    final importePorTrienio = tablaCarnicasTrienio[nivel] ?? 0.0;
    final importe = importePorTrienio * trienios;
    return ResultadoAntiguedad(
      importe: importe,
      aniosCompletos: anios,
      tramosCumplidos: trienios,
      tipoTramo: 'trienio',
      descripcion: 'Plus antigüedad ($anios años / $trienios trienios, nivel $nivel)',
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // AÑOS COMPLETOS
  // ═════════════════════════════════════════════════════════════════════════════

  /// Calcula los años completos entre [inicio] y [calculo].
  static int aniosCompletos(DateTime inicio, DateTime calculo) {
    int anios = calculo.year - inicio.year;
    if (calculo.month < inicio.month ||
        (calculo.month == inicio.month && calculo.day < inicio.day)) {
      anios--;
    }
    return anios.clamp(0, 999);
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // PRÓXIMO CAMBIO DE TRAMO
  // ═════════════════════════════════════════════════════════════════════════════

  /// Devuelve la fecha del próximo cambio de tramo de antigüedad,
  /// o null si no hay antigüedad automática.
  static DateTime? calcularProximoCambio({
    required DateTime fechaInicioContrato,
    required String convenio,
  }) {
    int periodoAnios;
    int? maxTramos;

    switch (convenio) {
      case convHosteleria:
        periodoAnios = 3;
        maxTramos = 5;
        break;
      case convComercio:
        periodoAnios = 2;
        maxTramos = null; // sin límite
        break;
      case convCarnicas:
        periodoAnios = 3;
        maxTramos = null;
        break;
      default:
        return null; // sin antigüedad automática
    }

    // Calcular cuántos tramos ya tiene
    final ahora = DateTime.now();
    final anios = aniosCompletos(fechaInicioContrato, ahora);
    final tramosActuales = (anios / periodoAnios).floor();

    // Si ya alcanzó el máximo, no hay próximo cambio
    if (maxTramos != null && tramosActuales >= maxTramos) return null;

    // El próximo tramo se cumple en (tramosActuales + 1) × periodo años
    final proximoAnios = (tramosActuales + 1) * periodoAnios;
    try {
      return DateTime(
        fechaInicioContrato.year + proximoAnios,
        fechaInicioContrato.month,
        fechaInicioContrato.day,
      );
    } catch (_) {
      // Caso borde: día 29 feb → mover a 28 feb
      return DateTime(
        fechaInicioContrato.year + proximoAnios,
        fechaInicioContrato.month,
        28,
      );
    }
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // ALERTAS MASIVAS
  // ═════════════════════════════════════════════════════════════════════════════

  /// Genera alertas de cambios de tramo de antigüedad próximos (30 días)
  /// para todos los empleados activos de una empresa.
  static Future<List<AlertaAntiguedad>> generarAlertasAntiguedad(
    String empresaId, {
    int diasAnticipacion = 30,
  }) async {
    final db = FirebaseFirestore.instance;
    final empleados = await db
        .collection('usuarios')
        .where('empresa_id', isEqualTo: empresaId)
        .where('activo', isEqualTo: true)
        .get();

    final alertas = <AlertaAntiguedad>[];
    final ahora = DateTime.now();
    final limite = ahora.add(Duration(days: diasAnticipacion));

    for (final emp in empleados.docs) {
      final data = emp.data();
      final datosNomina = data['datos_nomina'] as Map<String, dynamic>?;
      if (datosNomina == null) continue;

      // Comprobar si tiene antigüedad manual
      final antiguedadManual = datosNomina['antiguedad_manual'] as bool? ?? false;
      if (antiguedadManual) continue;

      final fechaInicioRaw = datosNomina['fecha_inicio_contrato'];
      if (fechaInicioRaw == null) continue;
      final fechaInicio = fechaInicioRaw is Timestamp
          ? fechaInicioRaw.toDate()
          : DateTime.tryParse(fechaInicioRaw.toString());
      if (fechaInicio == null) continue;

      final sector = datosNomina['sector_empresa'] as String?;
      final convenio = normalizarConvenio(sector);
      if (convenio.isEmpty) continue;

      final proximoCambio = calcularProximoCambio(
        fechaInicioContrato: fechaInicio,
        convenio: convenio,
      );
      if (proximoCambio == null) continue;

      // Solo alertar si el cambio está dentro del período de anticipación
      if (proximoCambio.isAfter(ahora) && !proximoCambio.isAfter(limite)) {
        final salarioBase =
            (datosNomina['salario_bruto_anual'] as num?)?.toDouble() ?? 0;
        final salarioMensual = salarioBase / 12;
        final nivelCarnicas =
            (datosNomina['nivel_categoria_carnicas'] as num?)?.toInt() ?? 5;

        final aniosNuevos = aniosCompletos(fechaInicio, proximoCambio);

        final resActual = calcular(
          fechaInicio: fechaInicio,
          fechaCalculo: ahora,
          convenio: convenio,
          salarioBase: salarioMensual,
          nivelCategoriaCarnicas: nivelCarnicas,
        );
        final resNuevo = calcular(
          fechaInicio: fechaInicio,
          fechaCalculo: proximoCambio,
          convenio: convenio,
          salarioBase: salarioMensual,
          nivelCategoriaCarnicas: nivelCarnicas,
        );

        alertas.add(AlertaAntiguedad(
          empleadoId: emp.id,
          empleadoNombre: data['nombre'] as String? ?? 'Sin nombre',
          fechaCambio: proximoCambio,
          aniosAlCambio: aniosNuevos,
          tramosActuales: resActual.tramosCumplidos,
          tramosNuevos: resNuevo.tramosCumplidos,
          importeActual: resActual.importe,
          importeNuevo: resNuevo.importe,
          tipoTramo: resNuevo.tipoTramo,
          convenio: convenio,
        ));
      }
    }

    // Ordenar por fecha de cambio más próxima
    alertas.sort((a, b) => a.fechaCambio.compareTo(b.fechaCambio));
    return alertas;
  }
}



import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/modelos/nomina.dart';
import '../domain/modelos/contabilidad.dart';
import '../domain/modelos/convenio_colectivo.dart';
import '../models/embargo_model.dart';
import 'contabilidad_service.dart';
import 'embargo_calculator.dart';
import 'nomina_pdf_service.dart';
import 'convenio_firestore_service.dart';
import 'vacaciones_service.dart';
import 'antiguedad_calculator.dart';

/// Servicio de gestión de nóminas con cálculo automático
/// según normativa española (Seguridad Social + IRPF 2026).
class NominasService {
  static final NominasService _i = NominasService._();
  factory NominasService() => _i;
  NominasService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  final ContabilidadService _contaSvc = ContabilidadService();
  final ConvenioFirestoreService _convSvc = ConvenioFirestoreService();

  static const String _convHosteleriaId = 'hosteleria-guadalajara';
  static const String _convComercioId   = 'comercio-guadalajara';
  static const String _convPeluqueriaId = 'peluqueria-estetica-gimnasios';
  static const String _convCarnicasId   = 'industrias-carnicas-guadalajara-2025';
  static const String _convVetId        = 'veterinarios-guadalajara-2026';
  static const String _convConstruccionId = 'construccion-obras-publicas-guadalajara';
  // Cuenca
  static const String _convConstruccionCuencaId = 'construccion-obras-publicas-cuenca';
  static const String _convHosteleriaCuencaId   = 'hosteleria-cuenca';
  static const String _convComercioCuencaId     = 'comercio-general-cuenca';

  // Referencia SMI 2026 (anual, 14 pagas). Se usa como umbral mínimo.
  static const double _smiAnual2026 = 15876.0;

  // Horas anuales de referencia por convenio (para valor hora y pluses % sobre hora)
  static const Map<String, int> _horasAnualesRef = {
    _convHosteleriaId: 1800,
    _convComercioId: 1782,
    _convPeluqueriaId: 1782, // sin dato oficial en seed, usamos 1782 como base estándar
    _convCarnicasId: 1748,   // BOE-A-2025-13965, desde 01/01/2025
    _convVetId: 1780,        // BOE-A-2023-21910, art. 38
    _convConstruccionId: 1736, // Convenio provincial Construcción Guadalajara 2025-2026
    // Cuenca
    _convConstruccionCuencaId: 1736,  // Jornada anual convenio construcción Cuenca
    _convHosteleriaCuencaId: 1800,    // Jornada anual convenio hostelería Cuenca
    _convComercioCuencaId: 1800,      // Jornada anual convenio comercio Cuenca
  };

  String _resolverConvenioPorSector(String? sector) {
    switch (sector?.toLowerCase().trim()) {
      case 'hosteleria':
        return _convHosteleriaId;
      case 'comercio':
        return _convComercioId;
      case 'peluqueria':
        return _convPeluqueriaId;
      case 'carniceria':
      case 'industrias_carnicas':
        return _convCarnicasId;
      case 'veterinarios':
      case 'veterinaria':
      case 'clinica_veterinaria':
        return _convVetId;
      case 'construccion':
      case 'obras_publicas':
      case 'construccion_obras_publicas':
        return _convConstruccionId;
      // ── Cuenca ────────────────────────────────────────────────────────────
      case 'construccion_cuenca':
      case 'construccion_obras_publicas_cuenca':
        return _convConstruccionCuencaId;
      case 'hosteleria_cuenca':
        return _convHosteleriaCuencaId;
      case 'comercio_cuenca':
      case 'comercio_general_cuenca':
        return _convComercioCuencaId;
      default:
        return _convHosteleriaId;
    }
  }

  double _minimoConvenioAnual(CategoriaConvenio? cat) {
    if (cat == null) return _smiAnual2026;
    return cat.salarioAnual;
  }

  bool _salarioCumpleMinimo(double salarioAnual, CategoriaConvenio? cat) {
    final minimo = _minimoConvenioAnual(cat);
    return salarioAnual >= minimo && salarioAnual >= _smiAnual2026;
  }

  Map<String, double> _extraerUnidadesPluses(Map<String, dynamic> data) {
    final Map<String, double> res = {};
    void merge(dynamic src) {
      if (src is Map) {
        for (final entry in src.entries) {
          final key = entry.key.toString();
          final val = entry.value;
          if (val is num) res[key] = val.toDouble();
        }
      }
    }

    merge(data['pluses_variables']);
    final dn = data['datos_nomina'];
    if (dn is Map) merge(dn['pluses_variables']);
    return res;
  }

  // ── REFS ──────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _nominas(String e) =>
      _db.collection('empresas').doc(e).collection('nominas');

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTANTES SS 2026 (España) — RDL 3/2026 + Orden PJC/178/2025
  // ═══════════════════════════════════════════════════════════════════════════

  static const double _ssCC         = 4.70;   // CC trabajador
  static const double _ssDesempl    = 1.55;   // Desempleo indefinido (trabajador)
  static const double _ssDesemplTemp= 1.60;   // Desempleo temporal/prácticas (trabajador)
  static const double _ssFP         = 0.10;   // Formación Profesional (trabajador)

  static const double _ssEmpCC      = 23.60;  // CC empresa
  static const double _ssEmpDesempl = 5.50;   // Desempleo indefinido (empresa)
  static const double _ssEmpDesemplT= 6.70;   // Desempleo temporal/prácticas (empresa)
  static const double _ssEmpFogasa  = 0.20;   // FOGASA (solo empresa)
  static const double _ssEmpFP      = 0.60;   // Formación Profesional (empresa)
  static const double _ssEmpAT      = 1.50;   // Accidentes trabajo (IT+IMS media)

  // ── MEI — Mecanismo de Equidad Intergeneracional 2026 ──────────────────
  // ⚠️ SUBIDA IMPORTANTE respecto a 2025 (era 0,60% total → ahora 0,90%)
  static const double _ssMeiTra     = 0.15;   // MEI trabajador (RDL 3/2026)
  static const double _ssMeiEmp     = 0.75;   // MEI empresa    (RDL 3/2026)
  // Total MEI 2026: 0,90%

  // ── Cotización adicional horas extraordinarias (art. 35 ET / RGC) ──────
  // Horas extra estructurales / no estructurales:
  static const double _ssHorasExtraEstTra = 4.70;   // trabajador (= tipo CC)
  static const double _ssHorasExtraEstEmp = 23.60;  // empresa    (= tipo CC)
  // Horas extra fuerza mayor (incendio, inundación, etc.) — tipo reducido:
  static const double _ssHorasExtraFMTra  = 2.00;   // trabajador
  static const double _ssHorasExtraFMEmp  = 12.00;  // empresa

  // ── Cotización solidaridad 2026 (salarios > base máxima) ───────────────
  // Tramo 1: base máxima hasta +10% → 0.92% (tra 0.10%, emp 0.82%)
  // Tramo 2: +10% hasta +50%        → 1.00% (tra 0.10%, emp 0.90%)
  // Tramo 3: > +50%                 → 1.17% (tra 0.12%, emp 1.05%)
  static const double _baseMaxAnual = 61214.40; // 5.101,20 × 12 (RDL 3/2026)

  static const double _baseMinMensual = 1381.20; // Provisional hasta publicación SMI 2026
  static const double _baseMaxMensual = 5101.20; // RDL 3/2026

  // ── CONTRATO FORMACIÓN EN ALTERNANCIA — Cuotas fijas mensuales 2026 ────
  // Orden PJC/178/2025. Base cotización formación: 1.381,20€/mes (cuotas únicas fijas)
  static const double _formCCTra         = 11.16;   // CC trabajador (fija)
  static const double _formCCEmp         = 55.97;   // CC empresa (fija)
  static const double _formATEmp         = 7.71;    // Contingencias profesionales empresa (fija)
  static const double _formFogasaEmp     = 4.25;    // FOGASA empresa (fija)
  static const double _formFPTra         = 0.27;    // FP trabajador (fija)
  static const double _formFPEmp         = 2.09;    // FP empresa (fija)

  // ═══════════════════════════════════════════════════════════════════════════
  // IRPF 2026 — Cálculo progresivo con tarifas autonómicas completas
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula el impuesto bruto sobre una base usando cualquier tabla de tramos.
  /// [tramos] es una lista de [limitesSuperior, tipoMarginal%] acumulados.
  static double _impuestoBrutoConLimites(double base, List<List<double>> tramos) {
    if (base <= 0) return 0;
    double imp = 0;
    double limAnterior = 0;
    for (final tramo in tramos) {
      final limSup = tramo[0];
      final tipo   = tramo[1];
      if (base <= limAnterior) break;
      final baseTramo = ((base < limSup ? base : limSup) - limAnterior).clamp(0.0, double.infinity);
      imp += baseTramo * tipo / 100;
      limAnterior = limSup;
      if (limSup == double.infinity) break;
    }
    return imp;
  }

  // ─── Reducción por rendimientos del trabajo (Art. 19/20 LIRPF) ────────────

  /// Gastos deducibles + reducción por obtención de rendimientos del trabajo.
  /// Se resta de la base imponible antes de aplicar los tramos.
  ///
  /// 2026: 2.000 € gastos deducibles (fijos para todo contribuyente)
  ///   + 2.000 € adicionales si [movilidadGeografica] = true (Art. 20 LIRPF)
  ///   + reducción escalonada según renta neta:
  ///     - Renta ≤ 14.852 €  → 7.302 €
  ///     - 14.852 < Renta ≤ 19.747 € → 7.302 − 1,75 × (renta − 14.852)
  ///     - Renta > 19.747 € → 0 €
  static double _reduccionRendimientosTrabajo(
    double baseAnual, {
    bool movilidadGeografica = false,
  }) {
    // Gastos deducibles: 2.000 base + 2.000 movilidad geográfica (art. 20)
    const gastosDeducibles = 2000.0;
    final gastosExtra = movilidadGeografica ? 2000.0 : 0.0;
    double reduccion;
    if (baseAnual <= 14852) {
      reduccion = 7302;
    } else if (baseAnual <= 19747) {
      reduccion = 7302 - 1.75 * (baseAnual - 14852);
      if (reduccion < 0) reduccion = 0;
    } else {
      reduccion = 0;
    }
    return gastosDeducibles + gastosExtra + reduccion;
  }

  // ─── Mínimo personal y familiar 2026 ──────────────────────────────────────

  /// Calcula el mínimo personal y familiar según situación del empleado.
  static double calcularMinimoPersonalFamiliar({
    required DatosNominaEmpleado config,
    int? edadEmpleado,
  }) {
    // Mínimo personal
    double minPersonal = 5550;
    if (edadEmpleado != null) {
      if (edadEmpleado >= 75) minPersonal += 1400;
      else if (edadEmpleado >= 65) minPersonal += 1150;
    }

    // Mínimo por descendientes
    double minDescendientes = 0;
    int hijos = config.numHijos;
    final tablaHijos = [2400.0, 2700.0, 4000.0, 4500.0];
    for (int i = 0; i < hijos; i++) {
      minDescendientes += i < tablaHijos.length ? tablaHijos[i] : 4500;
    }
    // Hijos menores de 3 años: +2800€ c/u
    minDescendientes += config.numHijosMenores3 * 2800;

    // Mínimo por discapacidad del trabajador
    double minDiscapacidad = 0;
    if (config.discapacidad) {
      if (config.porcentajeDiscapacidad >= 65) {
        minDiscapacidad = 9000;
      } else if (config.porcentajeDiscapacidad >= 33) {
        minDiscapacidad = 3000;
      }
    }

    return minPersonal + minDescendientes + minDiscapacidad;
  }

  // ─── Deducciones autonómicas CLM (Ley 8/2013, DL 1/2009) ────────────────

  /// Calcula las deducciones autonómicas de Castilla-La Mancha en EUROS anuales.
  /// Se restan de la cuota íntegra antes de calcular el tipo efectivo.
  ///
  /// Base legal: Ley 8/2013 CLM + Decreto Legislativo 1/2009, vigentes 2026.
  static double _deduccionesAutonomicasCLM(
    DatosNominaEmpleado datos,
    double baseImponible,
  ) {
    double total = 0;

    // ── Límite de renta general: ≤27.000€ individual / ≤36.000€ conjunta ──
    final limiteGeneral = datos.tributacionConjunta ? 36000.0 : 27000.0;
    final cumpleLimGeneral = baseImponible <= limiteGeneral;

    // ── 1. Nacimiento / adopción (art. 1) ─────────────────────────────────
    if (cumpleLimGeneral && datos.numHijosNacidosEsteAno > 0) {
      if (datos.numHijosNacidosEsteAno >= 3) {
        total += 900;
      } else if (datos.numHijosNacidosEsteAno == 2) {
        total += 500;
      } else {
        total += 100;
      }
    }

    // ── 2. Familia numerosa (art. 2) ──────────────────────────────────────
    if (cumpleLimGeneral && datos.familiaNumerosa != FamiliaNumerosa.no) {
      if (datos.discapacidadUnidadFamiliar65) {
        // Con discapacidad ≥65% en la unidad familiar
        total += datos.familiaNumerosa == FamiliaNumerosa.especial ? 900 : 300;
      } else {
        total += datos.familiaNumerosa == FamiliaNumerosa.especial ? 400 : 200;
      }
    }

    // ── 3. Familia monoparental ───────────────────────────────────────────
    if (cumpleLimGeneral && datos.familiaMonoparental) {
      total += 200;
    }

    // ── 4. Gastos guardería (art. 3) ──────────────────────────────────────
    // 15% de los gastos, máximo 250€ (125€ año en que cumple 3 años — se usa
    // el tope 250€ completo; el contribuyente ajusta en su declaración)
    if (cumpleLimGeneral && datos.gastosGuarderia > 0) {
      final deducGuard = (datos.gastosGuarderia * 0.15).clamp(0.0, 250.0);
      total += deducGuard;
    }

    // ── 5. Discapacidad contribuyente ≥65% (art. 4) ──────────────────────
    if (cumpleLimGeneral && datos.discapacidad && datos.porcentajeDiscapacidad >= 65) {
      total += 300;
    }

    // ── 6. Discapacidad ascendientes/descendientes ≥65% (art. 5) ─────────
    // INCOMPATIBLE con deducción nº5 respecto a la misma persona → se calcula
    // aparte. 300€ por persona.
    if (cumpleLimGeneral && datos.numFamiliaresDiscapacitados65 > 0) {
      total += 300.0 * datos.numFamiliaresDiscapacitados65;
    }

    // ── 7. Cuidado ascendiente >75 años (art. 6) ─────────────────────────
    // 150€ por persona. Condición: no resida en residencia pública >30 días.
    if (cumpleLimGeneral && datos.numAscendientes75 > 0) {
      total += 150.0 * datos.numAscendientes75;
    }

    // ── 8. Arrendamiento vivienda habitual <36 años (art. 9) ─────────────
    // Límite de renta más restrictivo: ≤12.500€ individual / ≤25.000€ conjunta
    final limiteAlquiler = datos.tributacionConjunta ? 25000.0 : 12500.0;
    if (baseImponible <= limiteAlquiler && datos.alquilerVivienda > 0) {
      if (datos.municipioPequeno) {
        // 20%, máximo 612€
        total += (datos.alquilerVivienda * 0.20).clamp(0.0, 612.0);
      } else {
        // 15%, máximo 450€
        total += (datos.alquilerVivienda * 0.15).clamp(0.0, 450.0);
      }
    }

    return total;
  }

  /// Tipo efectivo de IRPF sobre la base liquidable, descontando mínimo personal.
  /// Usa tarifas autonómicas COMPLETAS por tramo (no ajuste medio).
  static double calcularPorcentajeIrpf(
    double baseAnual, {
    DatosNominaEmpleado? config,
    int? edadEmpleado,
    ComunidadAutonoma comunidad = ComunidadAutonoma.estatal,
  }) {
    if (baseAnual <= 0) return 0;

    double minPF = 5550;
    bool movilidadGeo = false;
    if (config != null) {
      minPF = calcularMinimoPersonalFamiliar(
          config: config, edadEmpleado: edadEmpleado);
      comunidad      = config.comunidadAutonoma;
      movilidadGeo   = config.movilidadGeografica;
    }

    // ── Reducción por rendimientos del trabajo (art. 19/20 LIRPF) ─────────
    final reduccionRT = _reduccionRendimientosTrabajo(
      baseAnual,
      movilidadGeografica: movilidadGeo,
    );
    final baseLiquidable = (baseAnual - reduccionRT).clamp(0.0, double.infinity);

    // ── Cuota usando tarifa autonómica completa ────────────────────────────
    final tarifa = comunidad.tarifaIrpf;
    double cuota = (_impuestoBrutoConLimites(baseLiquidable, tarifa) -
                   _impuestoBrutoConLimites(minPF, tarifa))
        .clamp(0.0, double.infinity);

    // ── Deducciones autonómicas CLM (Ley 8/2013) ──────────────────────────
    // Se restan de la cuota ANTES de calcular el tipo efectivo.
    if (comunidad == ComunidadAutonoma.castillaMancha && config != null) {
      final deducciones = _deduccionesAutonomicasCLM(config, baseAnual);
      cuota = (cuota - deducciones).clamp(0.0, double.infinity);
    }

    double pct = (cuota / baseAnual * 100).clamp(0.0, 55.0);

    // ── Bonificación 50% Ceuta / Melilla ─────────────────────────────────
    if (comunidad.aplicaBonificacion50) pct *= 0.5;

    // ── Retención mínima art. 86 RIRPF ────────────────────────────────────
    // Contratos temporales con bruto > 14.000 €/año → mínimo 2%.
    // Todos los trabajadores con bruto > 14.000 €/año → mínimo 2%.
    if (baseAnual > 14000 && pct < 2.0) pct = 2.0;

    return pct.clamp(0.0, 55.0);
  }

  // ─── Recálculo IRPF YTD (ajuste al cambiar salario o a mitad de año) ──────

  /// Calcula el IRPF mensual ajustado usando el método AEAT:
  /// [impuesto_anual - irpf_ya_retenido] / meses_restantes
  ///
  /// Esto es lo que el sistema debe usar cuando el salario cambia,
  /// hay bonificaciones o simplemente al regularizar trimestralmente.
  static double calcularIrpfMensualAjustado({
    required double baseAnualEstimada,
    required double irpfYaRetenidoYtd,
    required int mesActual,         // 1–12
    required DatosNominaEmpleado config,
    int? edadEmpleado,
  }) {
    if (baseAnualEstimada <= 0) return 0;

    final minPF = calcularMinimoPersonalFamiliar(
        config: config, edadEmpleado: edadEmpleado);
    final reduccionRT = _reduccionRendimientosTrabajo(
      baseAnualEstimada,
      movilidadGeografica: config.movilidadGeografica,
    );
    final baseLiquidable = (baseAnualEstimada - reduccionRT).clamp(0.0, double.infinity);
    final tarifa = config.comunidadAutonoma.tarifaIrpf;
    double cuotaAnual = (_impuestoBrutoConLimites(baseLiquidable, tarifa) -
                         _impuestoBrutoConLimites(minPF, tarifa))
        .clamp(0.0, double.infinity);

    // Deducciones autonómicas CLM
    if (config.comunidadAutonoma == ComunidadAutonoma.castillaMancha) {
      cuotaAnual = (cuotaAnual - _deduccionesAutonomicasCLM(config, baseAnualEstimada))
          .clamp(0.0, double.infinity);
    }

    // Bonificación Ceuta/Melilla
    if (config.comunidadAutonoma.aplicaBonificacion50) cuotaAnual *= 0.5;

    final pendiente = (cuotaAnual - irpfYaRetenidoYtd).clamp(0.0, double.infinity);
    final mesesRestantes = (13 - mesActual).clamp(1, 12);
    return pendiente / mesesRestantes;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO DE NÓMINA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula una nómina completa a partir de los datos del empleado.
  Nomina calcularNomina({
    required String empresaId,
    required String empleadoId,
    required String empleadoNombre,
    String? empleadoNif,
    String? empleadoNss,
    required int mes,
    required int anio,
    required DatosNominaEmpleado config,
    double horasExtra = 0,
    double precioHoraExtra = 0,
    double importeHorasExtra = 0,
    double complementosVariables = 0,
    Map<String, double>? unidadesPlusesVariables, // key: plusId, unidades (días/horas) en el mes
    List<PlusConvenio>? plusesConvenio,           // pluses del convenio para calcular variables
    String? notas,
    double baseAcumuladaYtd = 0,
    double irpfAcumuladoYtd = 0,
    double descuentoAusencias = 0,
    List<Map<String, dynamic>> lineasAusencias = const [],
    List<Embargo> embargos = const [],
    TipoHoraExtra tipoHoraExtra = TipoHoraExtra.noEstructural,
  }) {
    // Calcular importe horas extra si solo se pasa precio por hora
    final double importeHorasExtraFinal = importeHorasExtra > 0
        ? importeHorasExtra
        : (precioHoraExtra > 0 ? horasExtra * precioHoraExtra : 0);
    final esPagaExtra14 = config.numPagas == 14 && !config.pagasProrrateadas;
    final esMesPagaExtra = mes == 6 || mes == 12; // junio y diciembre

    // ── Coeficiente de parcialidad ───────────────────────────────────────────
    // Si jornada < 40h, el salario bruto se entiende a jornada completa
    // y se prorratea por el coeficiente (horasSemanales / 40)
    final coefParcial = config.coeficienteParcial; // 1.0 si jornada completa
    final brutoAnualAjustado = config.salarioBrutoAnual * coefParcial;

    // ── Salario base del mes ─────────────────────────────────────────────────
    // Si 14 pagas no prorrateadas: 12 meses normales + 2 meses con paga extra
    // Si 12 pagas o 14 prorrateadas: salario mensual = bruto_anual / 12
    //   (en 14 prorrateadas la mensual es bruto/12, y el extra de 2 pagas
    //    queda diluido en cada mes → prorrata = (bruto/12 - bruto/14))
    final double salarioBase;
    final double pagaExtra;
    final double prorrata;

    // Soporte 15 pagas (hostelería Guadalajara provisionales 2026: jun, sep, dic)
    final esQuincePagas = config.numPagas == 15;
    final mesesExtra15 = const [6, 9, 12];

    if (config.pagasProrrateadas) {
      salarioBase = brutoAnualAjustado / 12;
      pagaExtra   = 0;
      prorrata    = config.numPagas > 12
          ? (brutoAnualAjustado / 12) - (brutoAnualAjustado / config.numPagas)
          : 0;
    } else if (config.numPagas == 14) {
      salarioBase = brutoAnualAjustado / 14;
      pagaExtra   = esMesPagaExtra ? brutoAnualAjustado / 14 : 0;
      prorrata    = 0;
    } else if (esQuincePagas) {
      final esMesExtra = mesesExtra15.contains(mes);
      salarioBase = brutoAnualAjustado / 15;
      pagaExtra   = esMesExtra ? brutoAnualAjustado / 15 : 0;
      prorrata    = 0;
    } else {
      // 12 pagas sin prorrata
      salarioBase = brutoAnualAjustado / 12;
      pagaExtra   = 0;
      prorrata    = 0;
    }

    double importePlusesVariables = 0;
    if (plusesConvenio != null && unidadesPlusesVariables != null) {
      for (final p in plusesConvenio) {
        final unidades = unidadesPlusesVariables[p.id] ?? 0;
        if (unidades == 0) continue;
        // Pluses variables aplicados por unidad de tiempo/día (los fijos/mes ya están en complementoFijo)
        if (p.tipo == 'fijo') {
          switch (p.baseCalculo) {
            case 'dia':
            case 'dia_festivo_trabajado':
            case 'dia_domingo':
            case 'por_dia':
              importePlusesVariables += p.importe * unidades;
              break;
            case 'hora':
            case 'por_hora':
              importePlusesVariables += p.importe * unidades;
              break;
            default:
              break;
          }
        }
      }
    }

    // ── Plus de antigüedad ──────────────────────────────────────────────────
    double plusAntiguedad = 0;
    int aniosAntiguedadCalc = 0;
    int trieniosBieniosCalc = 0;
    String? descripcionAntiguedadCalc;

    if (config.antiguedadManual) {
      // Antigüedad manual: usar importe fijo del empleado
      plusAntiguedad = config.antiguedadManualImporte;
    } else if (config.fechaInicioContrato != null) {
      final convenioNorm = AntiguedadCalculator.normalizarConvenio(config.sectorEmpresa);
      if (convenioNorm.isNotEmpty) {
        final fechaCalculo = DateTime(anio, mes + 1, 0); // último día del mes
        final resAnt = AntiguedadCalculator.calcular(
          fechaInicio: config.fechaInicioContrato!,
          fechaCalculo: fechaCalculo,
          convenio: convenioNorm,
          salarioBase: salarioBase,
          nivelCategoriaCarnicas: config.nivelCategoriaCarnicas,
        );
        plusAntiguedad = resAnt.importe;
        aniosAntiguedadCalc = resAnt.aniosCompletos;
        trieniosBieniosCalc = resAnt.tramosCumplidos;
        descripcionAntiguedadCalc = resAnt.descripcion;
      }
    }

    final complementoTotal = config.complementoFijo + complementosVariables + importePlusesVariables + plusAntiguedad;
    final totalDevengosCash = salarioBase + pagaExtra + importeHorasExtraFinal + complementoTotal + prorrata;

    // ── Retribuciones en especie mensuales (cotizan y tributan) ──────────────
    final retrEspecie = config.retribucionesEspecie; // €/mes
    final totalDevengos = totalDevengosCash + retrEspecie;

    // ── Base de cotización (con topes por grupo) ──────────────────────────────
    // Formación en alternancia: base fija 1.381,20€/mes (Orden PJC/178/2025)
    // Si tiene grupo de cotización, usar su base mínima específica
    final baseMinGrupo = config.grupoCotizacion?.baseMinMensual ?? _baseMinMensual;
    final baseCot = config.tipoContrato == TipoContrato.formacion
        ? _baseMinMensual  // 1.381,20€ fija para formación
        : totalDevengos.clamp(baseMinGrupo, _baseMaxMensual);

    // ── SS Trabajador ────────────────────────────────────────────────────────
    // Contrato de formación en alternancia: cuotas fijas mensuales (Orden PJC/178/2025)
    final esFormacion = config.tipoContrato == TipoContrato.formacion;

    final esTemporal = config.tipoContrato.esTemporal;
    final ssTraCC     = esFormacion ? _formCCTra  : baseCot * _ssCC / 100;
    final ssTraDesemp = esFormacion ? 0.0         : baseCot * (esTemporal ? _ssDesemplTemp : _ssDesempl) / 100;
    final ssTraFP     = esFormacion ? _formFPTra  : baseCot * _ssFP / 100;
    final ssMeiTra    = esFormacion ? 0.0         : baseCot * _ssMeiTra / 100;

    // ── Cotización solidaridad (exceso sobre base máxima) ────────────────────
    double ssSoliTra = 0;
    double ssSoliEmp = 0;
    if (totalDevengos > _baseMaxMensual) {
      final exceso = totalDevengos - _baseMaxMensual;
      final baseMaxAnualMes = _baseMaxAnual / 12;
      final t1Lim = baseMaxAnualMes * 0.10; // +10%
      final t2Lim = baseMaxAnualMes * 0.50; // +50%

      if (exceso <= t1Lim) {
        ssSoliTra = exceso * 0.10 / 100;
        ssSoliEmp = exceso * 0.82 / 100;
      } else if (exceso <= t2Lim) {
        ssSoliTra = t1Lim * 0.10 / 100 + (exceso - t1Lim) * 0.10 / 100;
        ssSoliEmp = t1Lim * 0.82 / 100 + (exceso - t1Lim) * 0.90 / 100;
      } else {
        ssSoliTra = t1Lim * 0.10 / 100 + (t2Lim - t1Lim) * 0.10 / 100 + (exceso - t2Lim) * 0.12 / 100;
        ssSoliEmp = t1Lim * 0.82 / 100 + (t2Lim - t1Lim) * 0.90 / 100 + (exceso - t2Lim) * 1.05 / 100;
      }
    }

    // ── IRPF ─────────────────────────────────────────────────────────────────
    double retencionIrpf;
    double pctIrpf;
    bool irpfAjustado = false;

    if (config.irpfPersonalizado != null) {
      pctIrpf       = config.irpfPersonalizado!;
      retencionIrpf = totalDevengos * pctIrpf / 100;
    } else {
      final mesesRestantes = (13 - mes).clamp(1, 12);
      // La base anual estimada incluye las retribuciones en especie
      final baseAnualEstimada = baseAcumuladaYtd + (totalDevengos * mesesRestantes)
          + config.otrasRentas;

      final edad = config.fechaNacimiento != null
          ? DateTime.now().year - config.fechaNacimiento!.year
          : null;

      if (baseAcumuladaYtd > 0 && config.anioUltimaActualizacion == anio) {
        retencionIrpf = calcularIrpfMensualAjustado(
          baseAnualEstimada: baseAnualEstimada,
          irpfYaRetenidoYtd: irpfAcumuladoYtd,
          mesActual: mes,
          config: config,
          edadEmpleado: edad,
        );
        pctIrpf = totalDevengos > 0 ? (retencionIrpf / totalDevengos * 100) : 0;
        irpfAjustado = true;
      } else {
        pctIrpf = calcularPorcentajeIrpf(
          baseAnualEstimada,
          config: config,
          edadEmpleado: edad,
          comunidad: config.comunidadAutonoma,
        );
        retencionIrpf = totalDevengos * pctIrpf / 100;
      }
    }

    // ── Cotización adicional horas extra (art. 35 ET) ────────────────────────
    // Se aplica sobre el importe de horas extra independientemente de baseCot.
    // FM: 2% tra + 12% emp  |  Resto: 4,70% tra + 23,60% emp
    double ssHorasExtraTra = 0;
    double ssHorasExtraEmp = 0;
    if (importeHorasExtraFinal > 0) {
      final pctTra = tipoHoraExtra == TipoHoraExtra.fuerzaMayor
          ? _ssHorasExtraFMTra
          : _ssHorasExtraEstTra;
      final pctEmp = tipoHoraExtra == TipoHoraExtra.fuerzaMayor
          ? _ssHorasExtraFMEmp
          : _ssHorasExtraEstEmp;
      ssHorasExtraTra = importeHorasExtraFinal * pctTra / 100;
      ssHorasExtraEmp = importeHorasExtraFinal * pctEmp / 100;
    }

    // ── SS Empresa ───────────────────────────────────────────────────────────
    // Formación en alternancia: cuotas fijas (Orden PJC/178/2025)
    final ssEmpCC     = esFormacion ? _formCCEmp     : baseCot * _ssEmpCC / 100;
    final ssEmpDesemp = esFormacion ? 0.0            : baseCot * (esTemporal ? _ssEmpDesemplT : _ssEmpDesempl) / 100;
    final ssEmpFog    = esFormacion ? _formFogasaEmp : baseCot * _ssEmpFogasa / 100;
    final ssEmpFP_    = esFormacion ? _formFPEmp     : baseCot * _ssEmpFP / 100;
    // AT/EP: usar personalizado > grupo > media (formación: cuota fija)
    final tipoAT      = config.porcentajeATPersonalizado
        ?? config.grupoCotizacion?.tipoATOrientativo
        ?? _ssEmpAT;
    final ssEmpAT_    = esFormacion ? _formATEmp : baseCot * tipoAT / 100;
    final ssMeiEmp    = esFormacion ? 0.0        : baseCot * _ssMeiEmp / 100;

    // ── Embargo judicial (art. 607 LEC) ──────────────────────────────────────
    // Se calcula sobre el salario NETO (tras SS e IRPF y descuento ausencias).
    // Los embargos activos de la fecha de la nómina se suman (pueden ser varios
    // juzgados); el total embargable está limitado por la tabla LEC.
    double embargoJudicial = 0;
    String? embargoDescripcion;

    final fechaNomina = DateTime(anio, mes, 1);
    final embargosActivos = embargos
        .where((e) => e.vigenteEn(fechaNomina))
        .toList();

    if (embargosActivos.isNotEmpty) {
      // Calcular salario neto provisional para aplicar la tabla LEC
      final ssTraTotal = ssTraCC + ssTraDesemp + ssTraFP + ssMeiTra + ssSoliTra + ssHorasExtraTra;
      final netoProvisional = totalDevengosCash - ssTraTotal - retencionIrpf - descuentoAusencias;

      // Aplicar cada embargo (se suman los importes si hay varios)
      double totalEmbargo = 0;
      final descripciones = <String>[];
      for (final emb in embargosActivos) {
        final importe = EmbargoCalculator.calcularEmbargoMes(
          netoProvisional,
          importeMensualMaximo: emb.importeMensualMaximo,
        );
        totalEmbargo += importe;
        if (importe > 0) {
          descripciones.add('${emb.organismo} (exp. ${emb.expediente})');
        }
      }
      // El total embargado no puede superar el máximo LEC sobre el neto
      final maxLec = EmbargoCalculator.calcularMaximoEmbargable(
        totalDevengosCash - ssTraCC - ssTraDesemp - ssTraFP - ssMeiTra - ssSoliTra
            - ssHorasExtraTra - retencionIrpf - descuentoAusencias,
      );
      embargoJudicial = totalEmbargo.clamp(0.0, maxLec);
      embargoJudicial = double.parse(embargoJudicial.toStringAsFixed(2));
      if (descripciones.isNotEmpty) {
        embargoDescripcion = descripciones.join('; ');
      }
    }

    return Nomina(
      id: '',
      empresaId: empresaId,
      empleadoId: empleadoId,
      empleadoNombre: empleadoNombre,
      empleadoNif: empleadoNif ?? config.nif,
      empleadoNss: empleadoNss ?? config.nss,
      mes: mes,
      anio: anio,
      periodo: '${Nomina.nombreMes(mes)} $anio',
      salarioBrutoMensual: salarioBase,
      pagaExtra: pagaExtra,
      horasExtra: horasExtra,
      precioHoraExtra: precioHoraExtra,
      importeHorasExtra: importeHorasExtraFinal,
      complementos: complementoTotal,
      pagaExtraProrrata: prorrata,
      retribucionesEspecie: retrEspecie,
      baseCotizacion: baseCot,
      ssTrabajadorCC: ssTraCC,
      ssTrabajadorDesempleo: ssTraDesemp,
      ssTrabajadorFP: ssTraFP,
      ssMeiTrabajador: ssMeiTra,
      ssSolidaridadTrabajador: ssSoliTra,
      baseIrpf: totalDevengos,
      porcentajeIrpf: pctIrpf,
      retencionIrpf: retencionIrpf,
      irpfAjustado: irpfAjustado,
      ssEmpresaCC: ssEmpCC,
      ssEmpresaDesempleo: ssEmpDesemp,
      ssEmpresaFogasa: ssEmpFog,
      ssEmpresaFP: ssEmpFP_,
      ssEmpresaAT: ssEmpAT_,
      ssMeiEmpresa: ssMeiEmp,
      ssSolidaridadEmpresa: ssSoliEmp,
      ssHorasExtraTrabajador: ssHorasExtraTra,
      ssHorasExtraEmpresa: ssHorasExtraEmp,
      tipoHoraExtra: tipoHoraExtra,
      descuentoAusencias: descuentoAusencias,
      lineasAusencias: lineasAusencias,
      plusAntiguedad: plusAntiguedad,
      aniosAntiguedad: aniosAntiguedadCalc,
      trieniosBienios: trieniosBieniosCalc,
      descripcionAntiguedad: descripcionAntiguedadCalc,
      embargoJudicial: embargoJudicial,
      embargoDescripcion: embargoDescripcion,
      estado: EstadoNomina.borrador,
      fechaCreacion: DateTime.now(),
      notas: notas,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Nomina> guardarNomina(String empresaId, Nomina nomina) async {
    final ref = nomina.id.isEmpty
        ? _nominas(empresaId).doc()
        : _nominas(empresaId).doc(nomina.id);
    final data = nomina.toMap();
    data['id'] = ref.id;
    await ref.set(data, SetOptions(merge: true));
    return Nomina.fromMap(data);
  }

  Stream<List<Nomina>> obtenerNominas(String empresaId) {
    return _nominas(empresaId)
        .orderBy('anio', descending: true)
        .orderBy('mes', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<List<Nomina>> obtenerNominasMes(String empresaId, int anio, int mes) {
    return _nominas(empresaId)
        .where('anio', isEqualTo: anio)
        .where('mes', isEqualTo: mes)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Stream<List<Nomina>> obtenerNominasEmpleado(String empresaId, String empleadoId) {
    return _nominas(empresaId)
        .where('empleado_id', isEqualTo: empleadoId)
        .orderBy('anio', descending: true)
        .orderBy('mes', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> aprobarNomina(String empresaId, String nominaId) async {
    await _nominas(empresaId).doc(nominaId).update({
      'estado': EstadoNomina.aprobada.name,
    });
  }

  Future<void> pagarNomina(String empresaId, String nominaId) async {
    final doc = await _nominas(empresaId).doc(nominaId).get();
    if (!doc.exists) return;
    final nomina = Nomina.fromMap({...doc.data()!, 'id': doc.id});

    final gasto = await _contaSvc.guardarGasto(
      empresaId,
      concepto: 'Nómina ${nomina.empleadoNombre} — ${nomina.periodo}',
      categoria: CategoriaGasto.personal,
      baseImponible: nomina.costeTotalEmpresa,
      porcentajeIva: 0,
      ivaDeducible: false,
      fechaGasto: DateTime.now(),
      notas: 'Generado automáticamente desde módulo de nóminas',
      creadoPor: 'sistema_nominas',
    );
    await _contaSvc.pagarGasto(empresaId, gasto.id, 'transferencia');

    await _nominas(empresaId).doc(nominaId).update({
      'estado': EstadoNomina.pagada.name,
      'fecha_pago': Timestamp.fromDate(DateTime.now()),
      'gasto_id_vinculado': gasto.id,
    });

    // Actualizar YTD del empleado tras el pago
    await _actualizarYtdEmpleado(nomina);
  }

  /// Actualiza los acumulados YTD del empleado en su documento de usuario.
  Future<void> _actualizarYtdEmpleado(Nomina nomina) async {
    final empDoc = await _db.collection('usuarios').doc(nomina.empleadoId).get();
    if (!empDoc.exists) return;
    final datosMap = empDoc.data()?['datos_nomina'] as Map<String, dynamic>?;
    if (datosMap == null) return;

    final config = DatosNominaEmpleado.fromMap(datosMap);
    // Si cambia de año, resetear YTD
    final mismoAnio = config.anioUltimaActualizacion == nomina.anio;
    final nuevaBase = mismoAnio
        ? config.baseAcumuladaYtd + nomina.totalDevengos
        : nomina.totalDevengos;
    final nuevoIrpf = mismoAnio
        ? config.irpfAcumuladoYtd + nomina.retencionIrpf
        : nomina.retencionIrpf;

    await _db.collection('usuarios').doc(nomina.empleadoId).update({
      'datos_nomina.base_acumulada_ytd': nuevaBase,
      'datos_nomina.irpf_acumulado_ytd': nuevoIrpf,
      'datos_nomina.mes_ultima_actualizacion': nomina.mes,
      'datos_nomina.anio_ultima_actualizacion': nomina.anio,
    });
  }

  Future<void> eliminarNomina(String empresaId, String nominaId) async {
    final doc = await _nominas(empresaId).doc(nominaId).get();
    if (doc.exists && doc.data()?['estado'] == 'borrador') {
      await doc.reference.delete();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERACIÓN MASIVA
  // ═══════════════════════════════════════════════════════════════════════════

  Future<int> generarNominasMasivas(String empresaId, int mes, int anio) async {
    final existentes = await _nominas(empresaId)
        .where('anio', isEqualTo: anio)
        .where('mes', isEqualTo: mes)
        .get();

    if (existentes.docs.isNotEmpty) {
      throw Exception(
          'Ya existen ${existentes.docs.length} nóminas para ${Nomina.nombreMes(mes)} $anio');
    }

    // Obtener el sector de la empresa para usarlo como fallback
    final empresaDoc = await _db.collection('empresas').doc(empresaId).get();
    final sectorEmpresa = (empresaDoc.data()?['sector'] as String?)?.toLowerCase().trim();

    final empleados = await _db
        .collection('usuarios')
        .where('empresa_id', isEqualTo: empresaId)
        .where('activo', isEqualTo: true)
        .get();

    final vacSvc = VacacionesService();
    int generadas = 0;

    for (final emp in empleados.docs) {
      final data = emp.data();
      final datosNomina = data['datos_nomina'] as Map<String, dynamic>?;
      if (datosNomina == null) continue;

      var configBase = DatosNominaEmpleado.fromMap(datosNomina);
      // Si el empleado no tiene sector_empresa, usar el de la empresa
      if ((configBase.sectorEmpresa == null || configBase.sectorEmpresa!.isEmpty) &&
          sectorEmpresa != null && sectorEmpresa.isNotEmpty) {
        configBase = configBase.copyWith(sectorEmpresa: sectorEmpresa);
      }
      final config = await _aplicarConvenioSiCorresponde(configBase);
      if (config.salarioBrutoAnual <= 0) continue;

      // Validación mínima (SMI / convenio). Si no cumple, se omite la nómina.
      CategoriaConvenio? cat;
      if (config.convenioCodigoCat != null) {
        final convenioId = _resolverConvenioPorSector(config.sectorEmpresa);
        cat = await _convSvc.obtenerCategoriaPorId(convenioId, config.convenioCodigoCat!);
      }
      if (!_salarioCumpleMinimo(config.salarioBrutoAnual, cat)) {
        debugPrint('⚠️ Nómina omitida por salario inferior a mínimo SMI/convenio para empleado ${data['nombre'] ?? emp.id}');
        continue;
      }

      // Resolver convenio para obtener pluses y unidades variables
      final convenioId = _resolverConvenioPorSector(config.sectorEmpresa);
      final pluses = await _convSvc.obtenerPluses(convenioId);
      final unidades = _extraerUnidadesPluses(data);

      // ── Calcular descuentos por ausencias injustificadas ──────────────
      final salarioMensual = config.salarioBrutoAnual * config.coeficienteParcial / 12;
      final descuentoAusencias = await vacSvc.calcularDescuentoMes(
        empresaId, emp.id, anio, mes, salarioMensual,
      );
      final lineasAusencias = await vacSvc.obtenerLineasNomina(
        empresaId, emp.id, anio, mes, salarioMensual,
      );

      // ── Cargar embargos judiciales activos ────────────────────────────
      final embargos = await obtenerEmbargos(emp.id);

      final nomina = calcularNomina(
        empresaId: empresaId,
        empleadoId: emp.id,
        empleadoNombre: data['nombre'] ?? 'Sin nombre',
        mes: mes,
        anio: anio,
        config: config,
        baseAcumuladaYtd: config.baseAcumuladaYtd,
        irpfAcumuladoYtd: config.irpfAcumuladoYtd,
        plusesConvenio: pluses,
        unidadesPlusesVariables: unidades.isEmpty ? null : unidades,
        descuentoAusencias: descuentoAusencias,
        lineasAusencias: lineasAusencias,
        embargos: embargos,
      );

      await guardarNomina(empresaId, nomina);
      generadas++;
    }

    return generadas;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RESUMEN MES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> resumenMes(String empresaId, int anio, int mes) async {
    final snap = await _nominas(empresaId)
        .where('anio', isEqualTo: anio)
        .where('mes', isEqualTo: mes)
        .get();
    final nominas = snap.docs
        .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
        .toList();

    return {
      'num_nominas':       nominas.length,
      'total_bruto':       nominas.fold(0.0, (s, n) => s + n.totalDevengos),
      'total_ss_trabajador': nominas.fold(0.0, (s, n) => s + n.totalSSTrabajador),
      'total_irpf':        nominas.fold(0.0, (s, n) => s + n.retencionIrpf),
      'total_neto':        nominas.fold(0.0, (s, n) => s + n.salarioNeto),
      'total_ss_empresa':  nominas.fold(0.0, (s, n) => s + n.totalSSEmpresa),
      'coste_total':       nominas.fold(0.0, (s, n) => s + n.costeTotalEmpresa),
      'pendientes':  nominas.where((n) => n.estado == EstadoNomina.borrador).length,
      'aprobadas':   nominas.where((n) => n.estado == EstadoNomina.aprobada).length,
      'pagadas':     nominas.where((n) => n.estado == EstadoNomina.pagada).length,
      'irpf_ajustados': nominas.where((n) => n.irpfAjustado).length,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COSTES ANUALES POR EMPLEADO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve el coste total empresa de cada empleado en el año dado.
  Future<List<Map<String, dynamic>>> costesAnualesPorEmpleado(
      String empresaId, int anio) async {
    final snap = await _nominas(empresaId)
        .where('anio', isEqualTo: anio)
        .get();
    final nominas = snap.docs
        .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
        .toList();

    final Map<String, Map<String, dynamic>> emp = {};
    for (final n in nominas) {
      emp.putIfAbsent(n.empleadoId, () => {
        'nombre':           n.empleadoNombre,
        'neto_total':       0.0,
        'bruto_total':      0.0,
        'ss_empresa_total': 0.0,
        'irpf_total':       0.0,
        'coste_total':      0.0,
        'num_nominas':      0,
      });
      emp[n.empleadoId]!['neto_total']       += n.salarioNeto;
      emp[n.empleadoId]!['bruto_total']      += n.totalDevengos;
      emp[n.empleadoId]!['ss_empresa_total'] += n.totalSSEmpresa;
      emp[n.empleadoId]!['irpf_total']       += n.retencionIrpf;
      emp[n.empleadoId]!['coste_total']      += n.costeTotalEmpresa;
      emp[n.empleadoId]!['num_nominas']      += 1;
    }
    return emp.values.toList()
      ..sort((a, b) => (b['coste_total'] as double)
          .compareTo(a['coste_total'] as double));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATOS NÓMINA EMPLEADO
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> guardarDatosNominaEmpleado(
      String empleadoId, DatosNominaEmpleado datos) async {
    await _db.collection('usuarios').doc(empleadoId).update({
      'datos_nomina': datos.toMap(),
    });
  }

  Future<DatosNominaEmpleado?> obtenerDatosNominaEmpleado(String empleadoId) async {
    final doc = await _db.collection('usuarios').doc(empleadoId).get();
    final datosNomina = doc.data()?['datos_nomina'] as Map<String, dynamic>?;
    if (datosNomina == null) return null;
    return DatosNominaEmpleado.fromMap(datosNomina);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ALERTAS DE CUMPLIMIENTO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve lista de alertas para el mes actual.
  Future<List<Map<String, String>>> alertasCumplimiento(
      String empresaId, int anio, int mes) async {
    final alertas = <Map<String, String>>[];

    // Empleados sin datos de nómina
    final empleados = await _db
        .collection('usuarios')
        .where('empresa_id', isEqualTo: empresaId)
        .where('activo', isEqualTo: true)
        .get();
    int sinDatos = 0;
    for (final e in empleados.docs) {
      final dn = e.data()['datos_nomina'];
      if (dn == null || (dn['salario_bruto_anual'] ?? 0) <= 0) sinDatos++;
    }
    if (sinDatos > 0) {
      alertas.add({
        'tipo': 'warning',
        'mensaje': '$sinDatos empleado(s) sin datos salariales configurados',
      });
    }

    // Nóminas con IRPF ajustado (para informar al administrador)
    final nominasMes = await _nominas(empresaId)
        .where('anio', isEqualTo: anio)
        .where('mes', isEqualTo: mes)
        .where('irpf_ajustado', isEqualTo: true)
        .get();
    if (nominasMes.docs.isNotEmpty) {
      alertas.add({
        'tipo': 'info',
        'mensaje':
            '${nominasMes.docs.length} nómina(s) con IRPF recalculado por regularización anual',
      });
    }

    // Contratos temporales a punto de vencer (próximos 30 días)
    final limite = DateTime.now().add(const Duration(days: 30));
    for (final e in empleados.docs) {
      final dn = e.data()['datos_nomina'] as Map<String, dynamic>?;
      if (dn == null) continue;
      final finRaw = dn['fecha_fin_contrato'];
      if (finRaw == null) continue;
      final fin = DatosNominaEmpleado.fromMap(dn).fechaFinContrato;
      if (fin != null && fin.isBefore(limite) && fin.isAfter(DateTime.now())) {
        alertas.add({
          'tipo': 'danger',
          'mensaje':
              'Contrato de "${e.data()['nombre'] ?? ''}" vence el ${fin.day}/${fin.month}/${fin.year}',
        });
      }
    }

    // Alertas de cambio de tramo de antigüedad (próximos 30 días)
    try {
      final alertasAntiguedad = await AntiguedadCalculator.generarAlertasAntiguedad(empresaId);
      for (final a in alertasAntiguedad) {
        alertas.add({
          'tipo': 'warning',
          'mensaje': a.mensaje,
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error generando alertas de antigüedad: $e');
    }

    return alertas;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EDICIÓN COMPLETA DE NÓMINA EN BORRADOR
  // ═══════════════════════════════════════════════════════════════════════════

  /// Permite editar cualquier campo de una nómina en borrador y recalcular.
  Future<Nomina> editarNominaBorrador({
    required String empresaId,
    required String nominaId,
    double? complementosOverride,
    double? horasExtra,
    double? precioHoraExtra,
    TipoHoraExtra? tipoHoraExtra,
    String? notas,
  }) async {
    final doc = await _nominas(empresaId).doc(nominaId).get();
    if (!doc.exists) throw Exception('Nómina no encontrada');
    final nomina = Nomina.fromMap({...doc.data()!, 'id': doc.id});
    if (nomina.estado != EstadoNomina.borrador) {
      throw Exception('Solo se pueden editar nóminas en borrador');
    }

    final config = await obtenerDatosNominaEmpleado(nomina.empleadoId);
    if (config == null) throw Exception('Empleado sin datos de nómina');
    final configAplicado = await _aplicarConvenioSiCorresponde(config);

    final nueva = calcularNomina(
      empresaId: empresaId,
      empleadoId: nomina.empleadoId,
      empleadoNombre: nomina.empleadoNombre,
      empleadoNif: nomina.empleadoNif,
      empleadoNss: nomina.empleadoNss,
      mes: nomina.mes,
      anio: nomina.anio,
      config: configAplicado,
      horasExtra: horasExtra ?? nomina.horasExtra,
      precioHoraExtra: precioHoraExtra ?? nomina.precioHoraExtra,
      complementosVariables: complementosOverride ?? 0,
      baseAcumuladaYtd: configAplicado.baseAcumuladaYtd,
      irpfAcumuladoYtd: configAplicado.irpfAcumuladoYtd,
      notas: notas ?? nomina.notas,
      tipoHoraExtra: tipoHoraExtra ?? nomina.tipoHoraExtra,
    );

    final data = nueva.toMap();
    data['id'] = nominaId;
    data['estado'] = nomina.estado.name;
    await _nominas(empresaId).doc(nominaId).set(data, SetOptions(merge: true));
    return Nomina.fromMap(data);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPORTAR CSV
  // ═══════════════════════════════════════════════════════════════════════════

  /// Genera un CSV con las nóminas proporcionadas.
  static String generarCsvNominas(List<Nomina> nominas) {
    final buf = StringBuffer();
    buf.writeln('Empleado,NIF,NSS,Periodo,Salario Base,Horas Extra,Complementos,'
        'Total Devengos,SS Trabajador,IRPF %,Retención IRPF,Salario Neto,'
        'SS Empresa,Coste Total Empresa,Estado');
    for (final n in nominas) {
      buf.writeln([
        _csvEsc(n.empleadoNombre),
        _csvEsc(n.empleadoNif ?? ''),
        _csvEsc(n.empleadoNss ?? ''),
        _csvEsc(n.periodo),
        n.salarioBrutoMensual.toStringAsFixed(2),
        n.importeHorasExtra.toStringAsFixed(2),
        n.complementos.toStringAsFixed(2),
        n.totalDevengos.toStringAsFixed(2),
        n.totalSSTrabajador.toStringAsFixed(2),
        n.porcentajeIrpf.toStringAsFixed(2),
        n.retencionIrpf.toStringAsFixed(2),
        n.salarioNeto.toStringAsFixed(2),
        n.totalSSEmpresa.toStringAsFixed(2),
        n.costeTotalEmpresa.toStringAsFixed(2),
        n.estado.etiqueta,
      ].join(','));
    }
    return buf.toString();
  }

  static String _csvEsc(String v) =>
      (v.contains(',') || v.contains('"') || v.contains('\n'))
          ? '"${v.replaceAll('"', '""')}"' : v;

  /// Exporta las nóminas del mes como CSV y lo comparte.
  Future<void> exportarCsvMes(BuildContext context, String empresaId, int anio, int mes) async {
    final snap = await _nominas(empresaId)
        .where('anio', isEqualTo: anio)
        .where('mes', isEqualTo: mes)
        .get();
    final nominas = snap.docs
        .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
        .toList();
    if (nominas.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay nóminas para exportar')),
        );
      }
      return;
    }

    final csv = generarCsvNominas(nominas);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/Nominas_${Nomina.nombreMes(mes)}_$anio.csv');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Nóminas ${Nomina.nombreMes(mes)} $anio',
    );
  }

  /// Comparte todas las nóminas del mes como PDFs individuales.
  Future<void> compartirNominasMesPdf(
    BuildContext context,
    String empresaId,
    int anio,
    int mes,
  ) async {
    final snap = await _nominas(empresaId)
        .where('anio', isEqualTo: anio)
        .where('mes', isEqualTo: mes)
        .get();
    final nominas = snap.docs
        .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
        .toList();
    if (nominas.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay nóminas para compartir')),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final files = <XFile>[];

    for (final n in nominas) {
      final file = await NominaPdfService.guardarPdfTemporal(n, empresaId);
      files.add(XFile(file.path, mimeType: 'application/pdf'));
    }

    await Share.shareXFiles(
      files,
      subject: 'Nóminas ${Nomina.nombreMes(mes)} $anio (${nominas.length} empleados)',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EMBARGOS JUDICIALES (art. 607 LEC)
  // Subcoleción: usuarios/{empleadoId}/embargos/{embargoId}
  // ═══════════════════════════════════════════════════════════════════════════

  CollectionReference<Map<String, dynamic>> _embargos(String empleadoId) =>
      _db.collection('usuarios').doc(empleadoId).collection('embargos');

  /// Devuelve todos los embargos (activos e inactivos) del empleado.
  Future<List<Embargo>> obtenerEmbargos(String empleadoId) async {
    final snap = await _embargos(empleadoId)
        .orderBy('fecha_inicio', descending: true)
        .get();
    return snap.docs
        .map((d) => Embargo.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }

  /// Stream en tiempo real de embargos del empleado.
  Stream<List<Embargo>> streamEmbargos(String empleadoId) {
    return _embargos(empleadoId)
        .orderBy('fecha_inicio', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => Embargo.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  /// Guarda (crea o actualiza) un embargo.
  Future<Embargo> guardarEmbargo(
      String empleadoId, Embargo embargo) async {
    final ref = embargo.id.isEmpty
        ? _embargos(empleadoId).doc()
        : _embargos(empleadoId).doc(embargo.id);
    final data = embargo.toMap();
    data['id'] = ref.id;
    await ref.set(data);
    return Embargo.fromMap(data);
  }

  /// Elimina un embargo por su ID.
  Future<void> eliminarEmbargo(
          String empleadoId, String embargoId) =>
      _embargos(empleadoId).doc(embargoId).delete();

  /// Devuelve solo los embargos activos vigentes en la fecha indicada.
  Future<List<Embargo>> obtenerEmbargosActivos(
      String empleadoId, DateTime fecha) async {
    final todos = await obtenerEmbargos(empleadoId);
    return todos.where((e) => e.vigenteEn(fecha)).toList();
  }

  // ── Ajusta salario/plus según convenio si existe una categoría asignada ──
  Future<DatosNominaEmpleado> _aplicarConvenioSiCorresponde(
      DatosNominaEmpleado config) async {
    if (config.convenioCodigoCat == null) return config;
    final sector = config.sectorEmpresa?.toLowerCase().trim();
    final posiblesConvenios = <String>[];
    if (sector == 'hosteleria') posiblesConvenios.add(_convHosteleriaId);
    if (sector == 'comercio') posiblesConvenios.add(_convComercioId);
    if (sector == 'peluqueria') posiblesConvenios.add(_convPeluqueriaId);
    if (sector == 'hosteleria_cuenca') posiblesConvenios.add(_convHosteleriaCuencaId);
    if (sector == 'comercio_cuenca' || sector == 'comercio_general_cuenca') posiblesConvenios.add(_convComercioCuencaId);
    if (sector == 'construccion_cuenca' || sector == 'construccion_obras_publicas_cuenca') posiblesConvenios.add(_convConstruccionCuencaId);
    if (sector == 'construccion' || sector == 'obras_publicas' || sector == 'construccion_obras_publicas') posiblesConvenios.add(_convConstruccionId);
    if (posiblesConvenios.isEmpty) {
      posiblesConvenios.addAll([
        _convHosteleriaId, _convComercioId, _convPeluqueriaId,
        _convHosteleriaCuencaId, _convComercioCuencaId, _convConstruccionCuencaId,
      ]);
    }

    CategoriaConvenio? cat;
    List<PlusConvenio> pluses = [];
    String? convenioUsado;

    for (final convenioId in posiblesConvenios) {
      cat = await _convSvc.obtenerCategoriaPorId(
          convenioId, config.convenioCodigoCat!);
      if (cat != null) {
        pluses = await _convSvc.obtenerPluses(convenioId);
        convenioUsado = convenioId;
        break;
      }
    }

    if (cat == null) return config;

    // Salario base mensual de convenio (antes de pluses)
    final salarioBaseMensual = cat.salarioAnual / cat.numPagas;

    // Valor hora estimado según horas anuales del convenio
    final horasAnuales = _horasAnualesRef[convenioUsado] ?? 1782;
    final horasMes = horasAnuales / 12;
    final valorHora = horasMes > 0 ? salarioBaseMensual / horasMes : 0;

    // Aplicar pluses
    double plusMensualFijo = 0;
    double plusMensualPorcentaje = 0;
    for (final p in pluses) {
      if (p.tipo == 'fijo') {
        if (p.baseCalculo == 'mes') plusMensualFijo += p.importe;
        // pluses por día/hora requieren unidades trabajadas; se dejan para variables
      } else if (p.tipo == 'porcentaje') {
        if (p.baseCalculo == 'salario_base_hora') {
          plusMensualPorcentaje += valorHora * horasMes * (p.importe / 100);
        } else if (p.baseCalculo == 'salario_base_mes') {
          plusMensualPorcentaje += salarioBaseMensual * (p.importe / 100);
        }
      }
    }
    final plusMensualTotal = plusMensualFijo + plusMensualPorcentaje;

    return config.copyWith(
      salarioBrutoAnual: cat.salarioAnual,
      numPagas: cat.numPagas,
      complementoFijo: config.complementoFijo + plusMensualTotal,
      convenioCodigoCat: cat.id,
      sectorEmpresa: sector ?? config.sectorEmpresa ?? convenioUsado,
    );
  }
}

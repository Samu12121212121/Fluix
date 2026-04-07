import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// NÓMINAS — Modelo completo para gestión de nóminas españolas
// ═══════════════════════════════════════════════════════════════════════════════

enum EstadoNomina { borrador, aprobada, pagada }
enum TipoContrato { indefinido, temporal, practicas, formacion, parcial }
enum EstadoCivil  { soltero, casado, viudoSinHijos, divorciado }

/// Tipo de hora extra a efectos de cotización SS (art. 35 ET).
///   - estructural  : habitual / necesaria → 4,70% tra + 23,60% emp
///   - fuerzaMayor  : incendio, inundación, etc. → 2% tra + 12% emp (tipo reducido)
///   - noEstructural: ocasional → mismos tipos que estructural
enum TipoHoraExtra { estructural, fuerzaMayor, noEstructural }

extension TipoHoraExtraExt on TipoHoraExtra {
  String get etiqueta {
    switch (this) {
      case TipoHoraExtra.estructural:   return 'Estructural';
      case TipoHoraExtra.fuerzaMayor:   return 'Fuerza mayor';
      case TipoHoraExtra.noEstructural: return 'No estructural';
    }
  }

  /// Descripción resumida para el PDF y la UI.
  String get descripcion {
    switch (this) {
      case TipoHoraExtra.estructural:
        return 'H.E. estructurales — cotización normal';
      case TipoHoraExtra.fuerzaMayor:
        return 'H.E. fuerza mayor (incendio, inundación…) — cotización reducida';
      case TipoHoraExtra.noEstructural:
        return 'H.E. no estructurales — cotización normal';
    }
  }

  /// Tipo SS trabajador (%) para la cotización adicional de horas extra.
  double get tipoTrabajador {
    return this == TipoHoraExtra.fuerzaMayor ? 2.00 : 4.70;
  }

  /// Tipo SS empresa (%) para la cotización adicional de horas extra.
  double get tipoEmpresa {
    return this == TipoHoraExtra.fuerzaMayor ? 12.00 : 23.60;
  }
}

/// Tipo de familia numerosa (art. 2 Ley 8/2013 CLM).
enum FamiliaNumerosa { no, general, especial }

/// Comunidades Autónomas de España (tramos autonómicos IRPF 2026).
enum ComunidadAutonoma {
  estatal,      // Sin ajuste autonómico (50%/50% estatal)
  andalucia,
  aragon,
  asturias,
  baleares,
  canarias,
  cantabria,
  castillaLeon,
  castillaMancha,
  cataluna,
  extremadura,
  galicia,
  madrid,
  murcia,
  navarra,
  paisVasco,
  rioja,
  valencia,
  ceuta,
  melilla,
}

extension ComunidadAutonomaExt on ComunidadAutonoma {
  String get etiqueta {
    switch (this) {
      case ComunidadAutonoma.estatal: return 'Estatal (media)';
      case ComunidadAutonoma.andalucia: return 'Andalucía';
      case ComunidadAutonoma.aragon: return 'Aragón';
      case ComunidadAutonoma.asturias: return 'Asturias';
      case ComunidadAutonoma.baleares: return 'Islas Baleares';
      case ComunidadAutonoma.canarias: return 'Canarias';
      case ComunidadAutonoma.cantabria: return 'Cantabria';
      case ComunidadAutonoma.castillaLeon: return 'Castilla y León';
      case ComunidadAutonoma.castillaMancha: return 'Castilla-La Mancha';
      case ComunidadAutonoma.cataluna: return 'Cataluña';
      case ComunidadAutonoma.extremadura: return 'Extremadura';
      case ComunidadAutonoma.galicia: return 'Galicia';
      case ComunidadAutonoma.madrid: return 'Madrid';
      case ComunidadAutonoma.murcia: return 'Murcia';
      case ComunidadAutonoma.navarra: return 'Navarra';
      case ComunidadAutonoma.paisVasco: return 'País Vasco';
      case ComunidadAutonoma.rioja: return 'La Rioja';
      case ComunidadAutonoma.valencia: return 'C. Valenciana';
      case ComunidadAutonoma.ceuta: return 'Ceuta';
      case ComunidadAutonoma.melilla: return 'Melilla';
    }
  }

  /// Tarifas IRPF COMPLETAS por tramo 2026 (estatal + autonómica combinadas).
  /// Formato: [[límite_superior, tipo_marginal_%], ...]
  /// Fuente: AEAT / Boletines Oficiales CCAA 2026.
  List<List<double>> get tarifaIrpf {
    switch (this) {
      // ── Estatal (media nacional) ─────────────────────────────────────────
      case ComunidadAutonoma.estatal:
        return [[12450,19],[20200,24],[35200,30],[60000,37],[300000,45],[double.infinity,47]];

      // ── Madrid (tipo más bajo de España) ────────────────────────────────
      case ComunidadAutonoma.madrid:
        return [[12450,18.5],[17707,23.2],[33007,28.3],[53407,37.2],[double.infinity,45.0]];

      // ── Cataluña (tipo más alto) ─────────────────────────────────────────
      case ComunidadAutonoma.cataluna:
        return [[12450,21.5],[17707,23.5],[33007,27.5],[53407,32.0],[90000,39.5],[120000,48.0],[175000,49.0],[double.infinity,50.0]];

      // ── Andalucía ────────────────────────────────────────────────────────
      case ComunidadAutonoma.andalucia:
        return [[12450,19.0],[20200,24.0],[35200,28.5],[60000,37.0],[double.infinity,47.0]];

      // ── Aragón ───────────────────────────────────────────────────────────
      case ComunidadAutonoma.aragon:
        return [[12450,20.0],[20200,25.0],[34000,31.0],[50000,39.5],[70000,49.5],[double.infinity,51.0]];

      // ── Asturias (tarifa alta) ───────────────────────────────────────────
      case ComunidadAutonoma.asturias:
        return [[12450,20.0],[21000,25.5],[36000,32.0],[60000,38.5],[80000,48.5],[double.infinity,51.5]];

      // ── Islas Baleares ───────────────────────────────────────────────────
      case ComunidadAutonoma.baleares:
        return [[12450,19.5],[20200,24.5],[35200,30.5],[60000,37.5],[double.infinity,47.5]];

      // ── Canarias (bonificaciones por territorialidad) ────────────────────
      case ComunidadAutonoma.canarias:
        return [[12450,19.0],[20200,23.5],[35200,29.0],[60000,36.5],[double.infinity,45.0]];

      // ── Cantabria ────────────────────────────────────────────────────────
      case ComunidadAutonoma.cantabria:
        return [[12450,19.5],[20200,24.5],[35200,30.0],[60000,38.0],[double.infinity,47.5]];

      // ── Castilla y León ──────────────────────────────────────────────────
      case ComunidadAutonoma.castillaLeon:
        return [[12450,18.5],[20200,24.0],[35200,30.0],[60000,37.0],[double.infinity,47.0]];

      // ── Castilla-La Mancha ───────────────────────────────────────────────
      // Autonómica 2026 (TaxDown 23/12/2025): 9,5%|12%|15%|18,5%|22,5%
      // Combinada (estatal + autonómica):
      case ComunidadAutonoma.castillaMancha:
        return [[12450,19.0],[20200,24.0],[35200,30.0],[60000,37.0],[300000,45.0],[double.infinity,47.0]];

      // ── Extremadura ──────────────────────────────────────────────────────
      case ComunidadAutonoma.extremadura:
        return [[12450,19.0],[20200,24.5],[35200,31.0],[60000,40.0],[double.infinity,48.5]];

      // ── Galicia ──────────────────────────────────────────────────────────
      case ComunidadAutonoma.galicia:
        return [[12450,19.0],[20200,24.0],[35200,30.0],[60000,37.0],[double.infinity,45.5]];

      // ── Murcia ───────────────────────────────────────────────────────────
      case ComunidadAutonoma.murcia:
        return [[12450,19.5],[20200,24.0],[35200,30.5],[60000,37.5],[double.infinity,47.0]];

      // ── Navarra (régimen foral especial) ─────────────────────────────────
      case ComunidadAutonoma.navarra:
        return [[4050,0.0],[10000,13.0],[15000,23.0],[28000,34.0],[50000,40.0],[75000,46.0],[double.infinity,52.0]];

      // ── País Vasco (régimen foral, base Gipuzkoa) ────────────────────────
      case ComunidadAutonoma.paisVasco:
        return [[15290,23.0],[30000,28.0],[60000,35.0],[100000,40.0],[double.infinity,45.0]];

      // ── La Rioja ─────────────────────────────────────────────────────────
      case ComunidadAutonoma.rioja:
        return [[12450,19.0],[20200,23.5],[35200,30.0],[60000,37.0],[double.infinity,45.5]];

      // ── C. Valenciana (tarifa muy alta, especialmente tramos altos) ───────
      case ComunidadAutonoma.valencia:
        return [[12450,20.0],[20200,25.0],[35200,30.8],[60000,38.5],[120000,46.0],[175000,49.0],[double.infinity,54.0]];

      // ── Ceuta y Melilla (tarifa estatal con bonificación del 50%) ─────────
      // Se aplica la tarifa estatal y se bonifica el 50% de la cuota al calcular.
      case ComunidadAutonoma.ceuta:
      case ComunidadAutonoma.melilla:
        return [[12450,19],[20200,24],[35200,30],[60000,37],[300000,45],[double.infinity,47]];
    }
  }

  /// true si la CCAA aplica bonificación del 50% sobre la cuota (Ceuta y Melilla).
  bool get aplicaBonificacion50 =>
      this == ComunidadAutonoma.ceuta || this == ComunidadAutonoma.melilla;

  /// [LEGACY] Ajuste porcentual simplificado (mantenido para compatibilidad).
  @Deprecated('Usar tarifaIrpf para cálculo preciso por tramos.')
  double get ajusteAutonomico {
    switch (this) {
      case ComunidadAutonoma.estatal: return 0;
      case ComunidadAutonoma.madrid: return -1.5;
      case ComunidadAutonoma.cataluna: return 1.0;
      case ComunidadAutonoma.andalucia: return -0.5;
      case ComunidadAutonoma.valencia: return 0.8;
      case ComunidadAutonoma.paisVasco: return -0.5;
      case ComunidadAutonoma.navarra: return -0.5;
      case ComunidadAutonoma.asturias: return 0.5;
      case ComunidadAutonoma.extremadura: return 0.5;
      case ComunidadAutonoma.aragon: return 0.3;
      case ComunidadAutonoma.baleares: return 0.3;
      case ComunidadAutonoma.canarias: return -0.3;
      case ComunidadAutonoma.cantabria: return 0.2;
      case ComunidadAutonoma.castillaLeon: return -0.2;
      case ComunidadAutonoma.castillaMancha: return 0.2;
      case ComunidadAutonoma.galicia: return 0;
      case ComunidadAutonoma.murcia: return 0.2;
      case ComunidadAutonoma.rioja: return -0.3;
      case ComunidadAutonoma.ceuta: return -3.0;
      case ComunidadAutonoma.melilla: return -3.0;
    }
  }
}
/// Cada grupo tiene una base mínima mensual y un tipo de AT/EP orientativo.
enum GrupoCotizacion {
  grupo1,   // Ingenieros y Licenciados
  grupo2,   // Ingenieros Técnicos, Peritos y Ayudantes
  grupo3,   // Jefes Administrativos y de Taller
  grupo4,   // Ayudantes no titulados
  grupo5,   // Oficiales Administrativos
  grupo6,   // Subalternos
  grupo7,   // Auxiliares Administrativos
  grupo8,   // Oficiales 1ª y 2ª
  grupo9,   // Oficiales 3ª y Especialistas
  grupo10,  // Peones
  grupo11,  // Menores de 18 años
}

extension GrupoCotizacionExt on GrupoCotizacion {
  String get codigo {
    switch (this) {
      case GrupoCotizacion.grupo1: return '1';
      case GrupoCotizacion.grupo2: return '2';
      case GrupoCotizacion.grupo3: return '3';
      case GrupoCotizacion.grupo4: return '4';
      case GrupoCotizacion.grupo5: return '5';
      case GrupoCotizacion.grupo6: return '6';
      case GrupoCotizacion.grupo7: return '7';
      case GrupoCotizacion.grupo8: return '8';
      case GrupoCotizacion.grupo9: return '9';
      case GrupoCotizacion.grupo10: return '10';
      case GrupoCotizacion.grupo11: return '11';
    }
  }

  String get etiqueta {
    switch (this) {
      case GrupoCotizacion.grupo1: return 'Grupo 1 — Ingenieros y Licenciados';
      case GrupoCotizacion.grupo2: return 'Grupo 2 — Ingenieros Técnicos y Peritos';
      case GrupoCotizacion.grupo3: return 'Grupo 3 — Jefes Administrativos y de Taller';
      case GrupoCotizacion.grupo4: return 'Grupo 4 — Ayudantes no titulados';
      case GrupoCotizacion.grupo5: return 'Grupo 5 — Oficiales Administrativos';
      case GrupoCotizacion.grupo6: return 'Grupo 6 — Subalternos';
      case GrupoCotizacion.grupo7: return 'Grupo 7 — Auxiliares Administrativos';
      case GrupoCotizacion.grupo8: return 'Grupo 8 — Oficiales 1ª y 2ª';
      case GrupoCotizacion.grupo9: return 'Grupo 9 — Oficiales 3ª y Especialistas';
      case GrupoCotizacion.grupo10: return 'Grupo 10 — Peones';
      case GrupoCotizacion.grupo11: return 'Grupo 11 — Menores de 18 años';
    }
  }

  String get etiquetaCorta {
    switch (this) {
      case GrupoCotizacion.grupo1: return 'G1 · Ingenieros/Licenciados';
      case GrupoCotizacion.grupo2: return 'G2 · Ingenieros Técnicos';
      case GrupoCotizacion.grupo3: return 'G3 · Jefes Admin/Taller';
      case GrupoCotizacion.grupo4: return 'G4 · Ayudantes no titulados';
      case GrupoCotizacion.grupo5: return 'G5 · Oficiales Admin';
      case GrupoCotizacion.grupo6: return 'G6 · Subalternos';
      case GrupoCotizacion.grupo7: return 'G7 · Auxiliares Admin';
      case GrupoCotizacion.grupo8: return 'G8 · Oficiales 1ª/2ª';
      case GrupoCotizacion.grupo9: return 'G9 · Oficiales 3ª/Espec.';
      case GrupoCotizacion.grupo10: return 'G10 · Peones';
      case GrupoCotizacion.grupo11: return 'G11 · Menores 18 años';
    }
  }

  /// Base mínima mensual de cotización por grupo (2026, €/mes)
  /// RDL 3/2026 + Orden PJC/178/2025
  double get baseMinMensual {
    switch (this) {
      case GrupoCotizacion.grupo1: return 1929.00;   // Ingenieros y Licenciados
      case GrupoCotizacion.grupo2: return 1599.60;   // Ingenieros Técnicos
      case GrupoCotizacion.grupo3: return 1391.70;   // Jefes Administrativos
      // ⚠️ Grupos 4-11: bases provisionales (se aplican las de 2025 transitoriamente
      //    hasta la publicación del SMI 2026 en el BOE)
      case GrupoCotizacion.grupo4: return 1381.20;   // Provisional — pendiente SMI 2026
      case GrupoCotizacion.grupo5: return 1381.20;   // Provisional — pendiente SMI 2026
      case GrupoCotizacion.grupo6: return 1381.20;   // Provisional — pendiente SMI 2026
      case GrupoCotizacion.grupo7: return 1381.20;   // Provisional — pendiente SMI 2026
      case GrupoCotizacion.grupo8: return 1381.20;   // Base diaria 46,04€ × 30 — Provisional
      case GrupoCotizacion.grupo9: return 1381.20;   // Base diaria 46,04€ × 30 — Provisional
      case GrupoCotizacion.grupo10: return 1381.20;  // Base diaria 46,04€ × 30 — Provisional
      case GrupoCotizacion.grupo11: return 1381.20;  // Base diaria 46,04€ × 30 — Provisional
    }
  }

  /// Tipo de AT/EP orientativo (IT + IMS) según actividad típica del grupo (%)
  double get tipoATOrientativo {
    switch (this) {
      case GrupoCotizacion.grupo1: return 1.00;   // Oficinas, bajo riesgo
      case GrupoCotizacion.grupo2: return 1.10;
      case GrupoCotizacion.grupo3: return 1.20;
      case GrupoCotizacion.grupo4: return 1.30;
      case GrupoCotizacion.grupo5: return 1.00;
      case GrupoCotizacion.grupo6: return 1.50;
      case GrupoCotizacion.grupo7: return 1.00;
      case GrupoCotizacion.grupo8: return 2.10;   // Trabajo manual
      case GrupoCotizacion.grupo9: return 2.30;
      case GrupoCotizacion.grupo10: return 3.00;  // Mayor riesgo
      case GrupoCotizacion.grupo11: return 1.50;
    }
  }
}

extension EstadoNominaExt on EstadoNomina {
  String get etiqueta {
    switch (this) {
      case EstadoNomina.borrador: return 'Borrador';
      case EstadoNomina.aprobada: return 'Aprobada';
      case EstadoNomina.pagada:   return 'Pagada';
    }
  }
}

extension TipoContratoExt on TipoContrato {
  String get etiqueta {
    switch (this) {
      case TipoContrato.indefinido: return 'Indefinido';
      case TipoContrato.temporal:   return 'Temporal';
      case TipoContrato.practicas:  return 'Prácticas';
      case TipoContrato.formacion:  return 'Formación dual';
      case TipoContrato.parcial:    return 'Parcial';
    }
  }
  bool get esTemporal => this == TipoContrato.temporal || this == TipoContrato.practicas;
}

extension EstadoCivilExt on EstadoCivil {
  String get etiqueta {
    switch (this) {
      case EstadoCivil.soltero:       return 'Soltero/a';
      case EstadoCivil.casado:        return 'Casado/a';
      case EstadoCivil.viudoSinHijos: return 'Viudo/a sin hijos';
      case EstadoCivil.divorciado:    return 'Divorciado/a';
    }
  }
}

// ── DATOS SALARIALES DEL EMPLEADO ─────────────────────────────────────────────

class DatosNominaEmpleado {
  // ── Identificación ──────────────────────────────────────────────────────────
  final String? nif;
  final String? nss;            // Nº Seguridad Social
  final String? cuentaBancaria;
  final GrupoCotizacion? grupoCotizacion;

  // ── Datos personales (para IRPF) ────────────────────────────────────────────
  final DateTime? fechaNacimiento;
  final EstadoCivil estadoCivil;
  final int numHijos;           // número de hijos a cargo
  final int numHijosMenores3;   // hijos menores de 3 años (deducción extra)
  final bool discapacidad;
  final double porcentajeDiscapacidad;  // 0, 33, 65, 75 (%)
  final double otrasRentas;     // otras rentas anuales (afecta IRPF)

  // ── Contrato ────────────────────────────────────────────────────────────────
  final TipoContrato tipoContrato;
  final DateTime?   fechaInicioContrato;
  final DateTime?   fechaFinContrato;
  final double      horasSemanales;     // 40 = jornada completa

  // ── Salario y pagas ─────────────────────────────────────────────────────────
  final double salarioBrutoAnual;
  final int    numPagas;          // 12 o 14
  final bool   pagasProrrateadas; // true = prorrateo mensual; false = pagas en jun/dic

  // ── Complementos fijos ──────────────────────────────────────────────────────
  final double complementoFijo;   // plus convenio, antigüedad, etc.

  // ── Antigüedad ────────────────────────────────────────────────────────────
  /// Importe calculado automáticamente del plus de antigüedad (€/mes).
  final double complementoAntiguedad;
  /// Si true, el cálculo automático NO sobreescribe el importe → se usa
  /// [antiguedadManualImporte].
  final bool antiguedadManual;
  /// Importe manual del plus de antigüedad (si [antiguedadManual] = true).
  final double antiguedadManualImporte;
  /// Nivel para industrias cárnicas (tabla trienios por nivel).
  final int nivelCategoriaCarnicas;

  // ── IRPF ────────────────────────────────────────────────────────────────────
  final double? irpfPersonalizado; // Si != null, se usa este % en vez del calculado
  final ComunidadAutonoma comunidadAutonoma; // Para tramos autonómicos IRPF
  // Acumulados YTD (se actualizan cada mes al generar nómina)
  final double baseAcumuladaYtd;
  final double irpfAcumuladoYtd;
  final int    mesUltimaActualizacion;
  final int    anioUltimaActualizacion;

  // ── AT/EP personalizado (por CNAE) ─────────────────────────────────────
  final double? porcentajeATPersonalizado; // Si != null, se usa en vez del grupo

  // ── NUEVAS MEJORAS 2026 ──────────────────────────────────────────────────
  /// Art. 20 LIRPF: Movilidad geográfica — reducción adicional 2.000€/año
  /// en gastos deducibles (año traslado + siguiente).
  final bool movilidadGeografica;

  /// Retribuciones en especie mensuales (€/mes).
  /// Ej: coche empresa, seguro médico, ticket restaurante, cheque guardería...
  /// Se suman a la base SS y a la base IRPF, pero NO son líquido en metálico.
  final double retribucionesEspecie;

  /// Sector de actividad (para buscar salarios mínimos de convenio).
  final String? sectorEmpresa;

  /// Código de categoría del convenio colectivo seleccionado.
  final String? convenioCodigoCat;

  /// Alias legacy: categoría en el convenio (compatibilidad con colecciones antiguas).
  final String? categoriaConvenio;

  // ── DEDUCCIONES AUTONÓMICAS CLM (Ley 8/2013, Decreto Legislativo 1/2009) ──
  /// Nº hijos nacidos/adoptados en el ejercicio fiscal en curso.
  final int numHijosNacidosEsteAno;
  /// Tipo de familia numerosa (general = 3 hijos, especial = 4+).
  final FamiliaNumerosa familiaNumerosa;
  /// Familia monoparental (art. 2 bis Ley 8/2013 CLM).
  final bool familiaMonoparental;
  /// Gastos de guardería anuales en euros (hijos <3 años).
  final double gastosGuarderia;
  /// Nº ascendientes/descendientes con discapacidad ≥65% a cargo (art. 5).
  final int numFamiliaresDiscapacitados65;
  /// Nº ascendientes >75 años a cargo no en residencia pública >30 días (art. 6).
  final int numAscendientes75;
  /// Alquiler de vivienda habitual anual en euros (contribuyente <36 años, art. 9).
  final double alquilerVivienda;
  /// Municipio de ≤2.500 hab. (o 2.500-10.000 a >30km de >50.000 hab.) para el 20% alquiler.
  final bool municipioPequeno;
  /// Tributación conjunta (afecta a los límites de renta para deducciones CLM).
  final bool tributacionConjunta;
  /// Discapacidad ≥65% en algún miembro de la unidad familiar (bonificación familia numerosa).
  final bool discapacidadUnidadFamiliar65;

  const DatosNominaEmpleado({
    this.nif,
    this.nss,
    this.cuentaBancaria,
    this.grupoCotizacion,
    this.fechaNacimiento,
    this.estadoCivil      = EstadoCivil.soltero,
    this.numHijos         = 0,
    this.numHijosMenores3 = 0,
    this.discapacidad     = false,
    this.porcentajeDiscapacidad = 0,
    this.otrasRentas      = 0,
    this.tipoContrato     = TipoContrato.indefinido,
    this.fechaInicioContrato,
    this.fechaFinContrato,
    this.horasSemanales   = 40,
    required this.salarioBrutoAnual,
    this.numPagas         = 12,
    this.pagasProrrateadas = true,
    this.complementoFijo  = 0,
    this.complementoAntiguedad = 0,
    this.antiguedadManual = false,
    this.antiguedadManualImporte = 0,
    this.nivelCategoriaCarnicas = 5,
    this.irpfPersonalizado,
    this.comunidadAutonoma = ComunidadAutonoma.estatal,
    this.baseAcumuladaYtd   = 0,
    this.irpfAcumuladoYtd   = 0,
    this.mesUltimaActualizacion = 0,
    this.anioUltimaActualizacion = 0,
    this.porcentajeATPersonalizado,
    this.movilidadGeografica = false,
    this.retribucionesEspecie = 0,
    this.sectorEmpresa,
    this.convenioCodigoCat,
    this.categoriaConvenio,
    this.numHijosNacidosEsteAno = 0,
    this.familiaNumerosa = FamiliaNumerosa.no,
    this.familiaMonoparental = false,
    this.gastosGuarderia = 0,
    this.numFamiliaresDiscapacitados65 = 0,
    this.numAscendientes75 = 0,
    this.alquilerVivienda = 0,
    this.municipioPequeno = false,
    this.tributacionConjunta = false,
    this.discapacidadUnidadFamiliar65 = false,
  });

  double get salarioBrutoMensualBase => salarioBrutoAnual / 12;

  /// Coeficiente de parcialidad (1.0 = jornada completa)
  double get coeficienteParcial => (horasSemanales / 40).clamp(0.0, 1.0);

  factory DatosNominaEmpleado.fromMap(Map<String, dynamic> m) {
    final rawCat = m['convenio_codigo_cat'] ?? m['categoria_convenio_id'] ?? m['categoria_convenio'];
    return DatosNominaEmpleado(
      nif: m['nif'] as String?,
      nss: m['nss'] as String?,
      cuentaBancaria: m['cuenta_bancaria'] as String?,
      grupoCotizacion: m['grupo_cotizacion'] != null
          ? GrupoCotizacion.values.firstWhere(
              (g) => g.name == m['grupo_cotizacion'],
              orElse: () => GrupoCotizacion.grupo7)
          : null,
      fechaNacimiento: m['fecha_nacimiento'] != null
          ? _parseDate(m['fecha_nacimiento']) : null,
      estadoCivil: EstadoCivil.values.firstWhere(
        (e) => e.name == (m['estado_civil'] as String?),
        orElse: () => EstadoCivil.soltero,
      ),
      numHijos: (m['num_hijos'] as num?)?.toInt() ?? 0,
      numHijosMenores3: (m['num_hijos_menores_3'] as num?)?.toInt() ?? 0,
      discapacidad: m['discapacidad'] as bool? ?? false,
      porcentajeDiscapacidad: (m['porcentaje_discapacidad'] as num?)?.toDouble() ?? 0,
      otrasRentas: (m['otras_rentas'] as num?)?.toDouble() ?? 0,
      tipoContrato: TipoContrato.values.firstWhere(
        (e) => e.name == (m['tipo_contrato'] as String?),
        orElse: () => TipoContrato.indefinido,
      ),
      fechaInicioContrato: m['fecha_inicio_contrato'] != null
          ? _parseDate(m['fecha_inicio_contrato']) : null,
      fechaFinContrato: m['fecha_fin_contrato'] != null
          ? _parseDate(m['fecha_fin_contrato']) : null,
      horasSemanales: (m['horas_semanales'] as num?)?.toDouble() ?? 40,
      salarioBrutoAnual: (m['salario_bruto_anual'] as num?)?.toDouble() ?? 0,
      numPagas: (m['num_pagas'] as num?)?.toInt() ?? 12,
      pagasProrrateadas: m['pagas_prorrateadas'] as bool? ?? true,
      complementoFijo: (m['complemento_fijo'] as num?)?.toDouble() ?? 0,
      complementoAntiguedad: (m['complemento_antiguedad'] as num?)?.toDouble() ?? 0,
      antiguedadManual: m['antiguedad_manual'] as bool? ?? false,
      antiguedadManualImporte: (m['antiguedad_manual_importe'] as num?)?.toDouble() ?? 0,
      nivelCategoriaCarnicas: (m['nivel_categoria_carnicas'] as num?)?.toInt() ?? 5,
      irpfPersonalizado: (m['irpf_personalizado'] as num?)?.toDouble(),
      comunidadAutonoma: ComunidadAutonoma.values.firstWhere(
        (e) => e.name == (m['comunidad_autonoma'] as String?),
        orElse: () => ComunidadAutonoma.estatal,
      ),
      baseAcumuladaYtd: (m['base_acumulada_ytd'] as num?)?.toDouble() ?? 0,
      irpfAcumuladoYtd: (m['irpf_acumulado_ytd'] as num?)?.toDouble() ?? 0,
      mesUltimaActualizacion: (m['mes_ultima_actualizacion'] as num?)?.toInt() ?? 0,
      anioUltimaActualizacion: (m['anio_ultima_actualizacion'] as num?)?.toInt() ?? 0,
      porcentajeATPersonalizado: (m['porcentaje_at_personalizado'] as num?)?.toDouble(),
      movilidadGeografica: m['movilidad_geografica'] as bool? ?? false,
      retribucionesEspecie: (m['retribuciones_especie'] as num?)?.toDouble() ?? 0,
      sectorEmpresa: m['sector_empresa'] as String?,
      convenioCodigoCat: rawCat as String?,
      categoriaConvenio: rawCat as String?,
      numHijosNacidosEsteAno: (m['num_hijos_nacidos_este_ano'] as num?)?.toInt() ?? 0,
      familiaNumerosa: FamiliaNumerosa.values.firstWhere(
        (e) => e.name == (m['familia_numerosa'] as String?),
        orElse: () => FamiliaNumerosa.no,
      ),
      familiaMonoparental: m['familia_monoparental'] as bool? ?? false,
      gastosGuarderia: (m['gastos_guarderia'] as num?)?.toDouble() ?? 0,
      numFamiliaresDiscapacitados65: (m['num_familiares_discapacitados_65'] as num?)?.toInt() ?? 0,
      numAscendientes75: (m['num_ascendientes_75'] as num?)?.toInt() ?? 0,
      alquilerVivienda: (m['alquiler_vivienda'] as num?)?.toDouble() ?? 0,
      municipioPequeno: m['municipio_pequeno'] as bool? ?? false,
      tributacionConjunta: m['tributacion_conjunta'] as bool? ?? false,
      discapacidadUnidadFamiliar65: m['discapacidad_unidad_familiar_65'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'nif': nif,
    'nss': nss,
    'cuenta_bancaria': cuentaBancaria,
    'grupo_cotizacion': grupoCotizacion?.name,
    if (fechaNacimiento != null)
      'fecha_nacimiento': Timestamp.fromDate(fechaNacimiento!),
    'estado_civil': estadoCivil.name,
    'num_hijos': numHijos,
    'num_hijos_menores_3': numHijosMenores3,
    'discapacidad': discapacidad,
    'porcentaje_discapacidad': porcentajeDiscapacidad,
    'otras_rentas': otrasRentas,
    'tipo_contrato': tipoContrato.name,
    if (fechaInicioContrato != null)
      'fecha_inicio_contrato': Timestamp.fromDate(fechaInicioContrato!),
    if (fechaFinContrato != null)
      'fecha_fin_contrato': Timestamp.fromDate(fechaFinContrato!),
    'horas_semanales': horasSemanales,
    'categoria_convenio': categoriaConvenio,
    'salario_bruto_anual': salarioBrutoAnual,
    'num_pagas': numPagas,
    'pagas_prorrateadas': pagasProrrateadas,
    'complemento_fijo': complementoFijo,
    'complemento_antiguedad': complementoAntiguedad,
    'antiguedad_manual': antiguedadManual,
    'antiguedad_manual_importe': antiguedadManualImporte,
    'nivel_categoria_carnicas': nivelCategoriaCarnicas,
    if (irpfPersonalizado != null) 'irpf_personalizado': irpfPersonalizado,
    'comunidad_autonoma': comunidadAutonoma.name,
    'base_acumulada_ytd': baseAcumuladaYtd,
    'irpf_acumulado_ytd': irpfAcumuladoYtd,
    'mes_ultima_actualizacion': mesUltimaActualizacion,
    'anio_ultima_actualizacion': anioUltimaActualizacion,
    if (porcentajeATPersonalizado != null) 'porcentaje_at_personalizado': porcentajeATPersonalizado,
    'movilidad_geografica': movilidadGeografica,
    'retribuciones_especie': retribucionesEspecie,
    if (sectorEmpresa != null) 'sector_empresa': sectorEmpresa,
    if (convenioCodigoCat != null) ...{
      'convenio_codigo_cat': convenioCodigoCat,
      'categoria_convenio_id': convenioCodigoCat, // compatibilidad UI actual
    },
    'num_hijos_nacidos_este_ano': numHijosNacidosEsteAno,
    'familia_numerosa': familiaNumerosa.name,
    'familia_monoparental': familiaMonoparental,
    'gastos_guarderia': gastosGuarderia,
    'num_familiares_discapacitados_65': numFamiliaresDiscapacitados65,
    'num_ascendientes_75': numAscendientes75,
    'alquiler_vivienda': alquilerVivienda,
    'municipio_pequeno': municipioPequeno,
    'tributacion_conjunta': tributacionConjunta,
    'discapacidad_unidad_familiar_65': discapacidadUnidadFamiliar65,
  };

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  DatosNominaEmpleado copyWith({
    double? salarioBrutoAnual,
    double? baseAcumuladaYtd,
    double? irpfAcumuladoYtd,
    int?    mesUltimaActualizacion,
    int?    anioUltimaActualizacion,
    double? irpfPersonalizado,
    int?    numPagas,
    bool?   pagasProrrateadas,
    double? complementoFijo,
    double? complementoAntiguedad,
    bool?   antiguedadManual,
    double? antiguedadManualImporte,
    int?    nivelCategoriaCarnicas,
    ComunidadAutonoma? comunidadAutonoma,
    double? porcentajeATPersonalizado,
    bool?   movilidadGeografica,
    double? retribucionesEspecie,
    String? sectorEmpresa,
    String? convenioCodigoCat,
    int?    numHijosNacidosEsteAno,
    FamiliaNumerosa? familiaNumerosa,
    bool?   familiaMonoparental,
    double? gastosGuarderia,
    int?    numFamiliaresDiscapacitados65,
    int?    numAscendientes75,
    double? alquilerVivienda,
    bool?   municipioPequeno,
    bool?   tributacionConjunta,
    bool?   discapacidadUnidadFamiliar65,
  }) => DatosNominaEmpleado(
    nif: nif, nss: nss, cuentaBancaria: cuentaBancaria,
    grupoCotizacion: grupoCotizacion, fechaNacimiento: fechaNacimiento,
    estadoCivil: estadoCivil, numHijos: numHijos,
    numHijosMenores3: numHijosMenores3, discapacidad: discapacidad,
    porcentajeDiscapacidad: porcentajeDiscapacidad, otrasRentas: otrasRentas,
    tipoContrato: tipoContrato, fechaInicioContrato: fechaInicioContrato,
    fechaFinContrato: fechaFinContrato, horasSemanales: horasSemanales,
    categoriaConvenio: categoriaConvenio,
    salarioBrutoAnual: salarioBrutoAnual ?? this.salarioBrutoAnual,
    numPagas: numPagas ?? this.numPagas,
    pagasProrrateadas: pagasProrrateadas ?? this.pagasProrrateadas,
    complementoFijo: complementoFijo ?? this.complementoFijo,
    complementoAntiguedad: complementoAntiguedad ?? this.complementoAntiguedad,
    antiguedadManual: antiguedadManual ?? this.antiguedadManual,
    antiguedadManualImporte: antiguedadManualImporte ?? this.antiguedadManualImporte,
    nivelCategoriaCarnicas: nivelCategoriaCarnicas ?? this.nivelCategoriaCarnicas,
    irpfPersonalizado: irpfPersonalizado ?? this.irpfPersonalizado,
    comunidadAutonoma: comunidadAutonoma ?? this.comunidadAutonoma,
    baseAcumuladaYtd: baseAcumuladaYtd ?? this.baseAcumuladaYtd,
    irpfAcumuladoYtd: irpfAcumuladoYtd ?? this.irpfAcumuladoYtd,
    mesUltimaActualizacion: mesUltimaActualizacion ?? this.mesUltimaActualizacion,
    anioUltimaActualizacion: anioUltimaActualizacion ?? this.anioUltimaActualizacion,
    porcentajeATPersonalizado: porcentajeATPersonalizado ?? this.porcentajeATPersonalizado,
    movilidadGeografica: movilidadGeografica ?? this.movilidadGeografica,
    retribucionesEspecie: retribucionesEspecie ?? this.retribucionesEspecie,
    sectorEmpresa: sectorEmpresa ?? this.sectorEmpresa,
    convenioCodigoCat: convenioCodigoCat ?? this.convenioCodigoCat,
    numHijosNacidosEsteAno: numHijosNacidosEsteAno ?? this.numHijosNacidosEsteAno,
    familiaNumerosa: familiaNumerosa ?? this.familiaNumerosa,
    familiaMonoparental: familiaMonoparental ?? this.familiaMonoparental,
    gastosGuarderia: gastosGuarderia ?? this.gastosGuarderia,
    numFamiliaresDiscapacitados65: numFamiliaresDiscapacitados65 ?? this.numFamiliaresDiscapacitados65,
    numAscendientes75: numAscendientes75 ?? this.numAscendientes75,
    alquilerVivienda: alquilerVivienda ?? this.alquilerVivienda,
    municipioPequeno: municipioPequeno ?? this.municipioPequeno,
    tributacionConjunta: tributacionConjunta ?? this.tributacionConjunta,
    discapacidadUnidadFamiliar65: discapacidadUnidadFamiliar65 ?? this.discapacidadUnidadFamiliar65,
  );
}

// ── NÓMINA ────────────────────────────────────────────────────────────────────

class Nomina {
  final String id;
  final String empresaId;
  final String empleadoId;
  final String empleadoNombre;
  final String? empleadoNif;
  final String? empleadoNss;
  final int mes;
  final int anio;
  final String periodo;

  // ── DEVENGOS ──────────────────────────────────────────────────────────────
  final double salarioBrutoMensual;   // salario base del mes (incl. prorrata si aplica)
  final double pagaExtra;             // importe paga extra si no es prorrateo (jun/dic)
  final double horasExtra;
  final double precioHoraExtra;    // precio unitario por hora extra (€/h)
  final double importeHorasExtra;
  final double complementos;
  final double pagaExtraProrrata;     // legacy / prorrateo incluido en salario
  /// Retribuciones en especie mensual (coche empresa, seguro, tickets...).
  /// Cotizan a la SS e intervienen en el IRPF, pero NO se cobran en metálico.
  final double retribucionesEspecie;

  // ── DESCUENTO AUSENCIAS ──────────────────────────────────────────────────
  /// Descuento por ausencias injustificadas (importe positivo que resta del neto).
  final double descuentoAusencias;
  /// Líneas informativas de ausencias/permisos para mostrar en la nómina.
  final List<Map<String, dynamic>> lineasAusencias;

  // ── PLUS ANTIGÜEDAD ────────────────────────────────────────────────────────
  /// Importe del plus de antigüedad aplicado en esta nómina (€/mes).
  final double plusAntiguedad;
  /// Años completos de antigüedad a fecha de la nómina.
  final int aniosAntiguedad;
  /// Número de trienios/bienios cumplidos.
  final int trieniosBienios;
  /// Descripción del concepto de antigüedad.
  final String? descripcionAntiguedad;

  /// Incluye prestación IT y descuenta el salario proporcional por baja.
  double get totalDevengosCash =>
      salarioBrutoMensual + pagaExtra + importeHorasExtra + complementos +
      pagaExtraProrrata + importeIT - descuentoSalarioPorIT;

  /// Devengos totales = cash + especie. Base para SS y IRPF.
  double get totalDevengos => totalDevengosCash + retribucionesEspecie;

  // ── DEDUCCIONES SS TRABAJADOR ─────────────────────────────────────────────
  final double baseCotizacion;
  final double ssTrabajadorCC;
  final double ssTrabajadorDesempleo;
  final double ssTrabajadorFP;
  final double ssMeiTrabajador;   // MEI — Mecanismo Equidad Intergeneracional
  /// Cotización adicional por horas extra (trabajador) — art. 35 ET / RGC.
  /// FM: 2% | Estructurales/no-estructurales: 4,70%
  final double ssHorasExtraTrabajador;
  double get totalSSTrabajador =>
      ssTrabajadorCC + ssTrabajadorDesempleo + ssTrabajadorFP +
      ssMeiTrabajador + ssSolidaridadTrabajador + ssHorasExtraTrabajador;

  // ── IRPF ─────────────────────────────────────────────────────────────────
  final double baseIrpf;
  final double porcentajeIrpf;
  final double retencionIrpf;
  final bool   irpfAjustado;     // true si se recalculó por cambio salarial o YTD

  double get totalDeducciones => totalSSTrabajador + retencionIrpf + regularizacionIrpf.clamp(0, double.infinity);
  /// Líquido a percibir en metálico (retribuciones en especie no son cash).
  /// Incluye descuento por ausencias injustificadas y regularización IRPF si aplica.
  double get salarioNeto => totalDevengosCash - totalDeducciones - descuentoAusencias;

  // ── EMBARGO JUDICIAL ──────────────────────────────────────────────────────
  /// Importe del embargo judicial aplicado en esta nómina (art. 607 LEC).
  final double embargoJudicial;

  /// Organismos/expedientes involucrados (solo informativo para el PDF).
  final String? embargoDescripcion;

  /// Líquido NETO FINAL a percibir = salarioNeto − embargoJudicial.
  /// Es el importe real que se ingresa en la cuenta del trabajador.
  double get liquidoFinal => salarioNeto - embargoJudicial;

  // ── SS EMPRESA ────────────────────────────────────────────────────────────
  final double ssEmpresaCC;
  final double ssEmpresaDesempleo;
  final double ssEmpresaFogasa;
  final double ssEmpresaFP;
  final double ssEmpresaAT;
  final double ssMeiEmpresa;      // MEI — Mecanismo Equidad Intergeneracional
  // ── COTIZACIÓN SOLIDARIDAD (salarios > base máxima) ────────────────────────
  final double ssSolidaridadTrabajador;
  final double ssSolidaridadEmpresa;
  /// Cotización adicional por horas extra (empresa) — art. 35 ET / RGC.
  /// FM: 12% | Estructurales/no-estructurales: 23,60%
  final double ssHorasExtraEmpresa;

  /// Tipo de hora extra a efectos de cotización SS.
  final TipoHoraExtra tipoHoraExtra;

  double get totalSSEmpresa =>
      ssEmpresaCC + ssEmpresaDesempleo + ssEmpresaFogasa + ssEmpresaFP +
      ssEmpresaAT + ssMeiEmpresa + ssSolidaridadEmpresa + ssHorasExtraEmpresa;

  /// Coste total empresa = salario bruto + cotizaciones empresa.
  double get costeTotalEmpresa => salarioNeto + totalSSEmpresa + embargoJudicial + totalDeducciones + descuentoAusencias;

  final EstadoNomina estado;
  final DateTime  fechaCreacion;
  final DateTime? fechaPago;
  final String?   notas;
  final String?   gastoIdVinculado;

  // ── IT (Incapacidad Temporal) ──────────────────────────────────────────────
  final int diasIT;
  final double importeIT;
  final double importeITEmpresa;
  final double importeITINSS;
  final double importeITMutua;
  final double descuentoSalarioPorIT;
  final String? tipoContingenciaIT;

  // ── Regularización IRPF ───────────────────────────────────────────────────
  final double regularizacionIrpf;

  // ── Complementos detallados ───────────────────────────────────────────────
  final List<Map<String, dynamic>> complementosDetallados;

  // ── Firma electrónica ─────────────────────────────────────────────────────
  final String? firmaUrl;
  final DateTime? firmaFecha;
  final String? firmaEmpleadoId;
  final String? estadoFirma;

  const Nomina({
    required this.id,
    required this.empresaId,
    required this.empleadoId,
    required this.empleadoNombre,
    this.empleadoNif,
    this.empleadoNss,
    required this.mes,
    required this.anio,
    required this.periodo,
    required this.salarioBrutoMensual,
    this.pagaExtra = 0,
    this.horasExtra = 0,
    this.precioHoraExtra = 0,
    this.importeHorasExtra = 0,
    this.complementos = 0,
    this.pagaExtraProrrata = 0,
    this.retribucionesEspecie = 0,
    required this.baseCotizacion,
    required this.ssTrabajadorCC,
    required this.ssTrabajadorDesempleo,
    required this.ssTrabajadorFP,
    this.ssMeiTrabajador = 0,
    required this.baseIrpf,
    required this.porcentajeIrpf,
    required this.retencionIrpf,
    this.irpfAjustado = false,
    required this.ssEmpresaCC,
    required this.ssEmpresaDesempleo,
    required this.ssEmpresaFogasa,
    required this.ssEmpresaFP,
    this.ssEmpresaAT = 0,
    this.ssMeiEmpresa = 0,
    this.ssSolidaridadTrabajador = 0,
    this.ssSolidaridadEmpresa = 0,
    this.ssHorasExtraTrabajador = 0,
    this.ssHorasExtraEmpresa = 0,
    this.tipoHoraExtra = TipoHoraExtra.noEstructural,
    this.descuentoAusencias = 0,
    this.lineasAusencias = const [],
    this.plusAntiguedad = 0,
    this.aniosAntiguedad = 0,
    this.trieniosBienios = 0,
    this.descripcionAntiguedad,
    this.embargoJudicial = 0,
    this.embargoDescripcion,
    this.diasIT = 0,
    this.importeIT = 0,
    this.importeITEmpresa = 0,
    this.importeITINSS = 0,
    this.importeITMutua = 0,
    this.descuentoSalarioPorIT = 0,
    this.tipoContingenciaIT,
    this.regularizacionIrpf = 0,
    this.complementosDetallados = const [],
    this.firmaUrl,
    this.firmaFecha,
    this.firmaEmpleadoId,
    this.estadoFirma,
    this.estado = EstadoNomina.borrador,
    required this.fechaCreacion,
    this.fechaPago,
    this.notas,
    this.gastoIdVinculado,
  });

  // ignore: lines_longer_than_80_chars
  factory Nomina.fromMap(Map<String, dynamic> m) => Nomina(
    id:                     m['id'] as String? ?? '',
    empresaId:              m['empresa_id'] as String? ?? '',
    empleadoId:             m['empleado_id'] as String? ?? '',
    empleadoNombre:         m['empleado_nombre'] as String? ?? '',
    empleadoNif:            m['empleado_nif'] as String?,
    empleadoNss:            m['empleado_nss'] as String?,
    mes:                    (m['mes'] as num?)?.toInt() ?? 1,
    anio:                   (m['anio'] as num?)?.toInt() ?? 2026,
    periodo:                m['periodo'] as String? ?? '',
    salarioBrutoMensual:    (m['salario_bruto_mensual'] as num?)?.toDouble() ?? 0,
    pagaExtra:              (m['paga_extra'] as num?)?.toDouble() ?? 0,
    horasExtra:             (m['horas_extra'] as num?)?.toDouble() ?? 0,
    precioHoraExtra:        (m['precio_hora_extra'] as num?)?.toDouble() ?? 0,
    importeHorasExtra:      (m['importe_horas_extra'] as num?)?.toDouble() ?? 0,
    complementos:           (m['complementos'] as num?)?.toDouble() ?? 0,
    pagaExtraProrrata:      (m['paga_extra_prorrateada'] as num?)?.toDouble() ?? 0,
    retribucionesEspecie:   (m['retribuciones_especie'] as num?)?.toDouble() ?? 0,
    baseCotizacion:         (m['base_cotizacion'] as num?)?.toDouble() ?? 0,
    ssTrabajadorCC:         (m['ss_trabajador_cc'] as num?)?.toDouble() ?? 0,
    ssTrabajadorDesempleo:  (m['ss_trabajador_desempleo'] as num?)?.toDouble() ?? 0,
    ssTrabajadorFP:         (m['ss_trabajador_fp'] as num?)?.toDouble() ?? 0,
    ssMeiTrabajador:        (m['ss_mei_trabajador'] as num?)?.toDouble() ?? 0,
    baseIrpf:               (m['base_irpf'] as num?)?.toDouble() ?? 0,
    porcentajeIrpf:         (m['porcentaje_irpf'] as num?)?.toDouble() ?? 0,
    retencionIrpf:          (m['retencion_irpf'] as num?)?.toDouble() ?? 0,
    irpfAjustado:           m['irpf_ajustado'] as bool? ?? false,
    ssEmpresaCC:            (m['ss_empresa_cc'] as num?)?.toDouble() ?? 0,
    ssEmpresaDesempleo:     (m['ss_empresa_desempleo'] as num?)?.toDouble() ?? 0,
    ssEmpresaFogasa:        (m['ss_empresa_fogasa'] as num?)?.toDouble() ?? 0,
    ssEmpresaFP:            (m['ss_empresa_fp'] as num?)?.toDouble() ?? 0,
    ssEmpresaAT:            (m['ss_empresa_at'] as num?)?.toDouble() ?? 0,
    ssMeiEmpresa:           (m['ss_mei_empresa'] as num?)?.toDouble() ?? 0,
    ssSolidaridadTrabajador: (m['ss_solidaridad_trabajador'] as num?)?.toDouble() ?? 0,
    ssSolidaridadEmpresa:    (m['ss_solidaridad_empresa'] as num?)?.toDouble() ?? 0,
    ssHorasExtraTrabajador:  (m['ss_horas_extra_trabajador'] as num?)?.toDouble() ?? 0,
    ssHorasExtraEmpresa:     (m['ss_horas_extra_empresa'] as num?)?.toDouble() ?? 0,
    tipoHoraExtra: TipoHoraExtra.values.firstWhere(
      (e) => e.name == (m['tipo_hora_extra'] as String?),
      orElse: () => TipoHoraExtra.noEstructural,
    ),
    descuentoAusencias:      (m['descuento_ausencias'] as num?)?.toDouble() ?? 0,
    lineasAusencias:         (m['lineas_ausencias'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? const [],
    plusAntiguedad:           (m['plus_antiguedad'] as num?)?.toDouble() ?? 0,
    aniosAntiguedad:         (m['anios_antiguedad'] as num?)?.toInt() ?? 0,
    trieniosBienios:         (m['trienios_bienios'] as num?)?.toInt() ?? 0,
    descripcionAntiguedad:   m['descripcion_antiguedad'] as String?,
    embargoJudicial:         (m['embargo_judicial'] as num?)?.toDouble() ?? 0,
    embargoDescripcion:      m['embargo_descripcion'] as String?,
    diasIT:                  (m['dias_it'] as num?)?.toInt() ?? 0,
    importeIT:               (m['importe_it'] as num?)?.toDouble() ?? 0,
    importeITEmpresa:        (m['importe_it_empresa'] as num?)?.toDouble() ?? 0,
    importeITINSS:           (m['importe_it_inss'] as num?)?.toDouble() ?? 0,
    importeITMutua:          (m['importe_it_mutua'] as num?)?.toDouble() ?? 0,
    descuentoSalarioPorIT:   (m['descuento_salario_por_it'] as num?)?.toDouble() ?? 0,
    tipoContingenciaIT:      m['tipo_contingencia_it'] as String?,
    regularizacionIrpf:      (m['regularizacion_irpf'] as num?)?.toDouble() ?? 0,
    complementosDetallados:  (m['complementos_detallados'] as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList() ?? const [],
    firmaUrl:                m['firma_url'] as String?,
    firmaFecha:              m['firma_fecha'] != null ? _parseDate(m['firma_fecha']) : null,
    firmaEmpleadoId:         m['firma_empleado_id'] as String?,
    estadoFirma:             m['estado_firma'] as String?,
    estado:                 EstadoNomina.values.firstWhere(
                              (e) => e.name == (m['estado'] as String?),
                              orElse: () => EstadoNomina.borrador),
    fechaCreacion:          _parseDate(m['fecha_creacion']),
    fechaPago:              m['fecha_pago'] != null ? _parseDate(m['fecha_pago']) : null,
    notas:                  m['notas'] as String?,
    gastoIdVinculado:       m['gasto_id_vinculado'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'empresa_id': empresaId, 'empleado_id': empleadoId,
    'empleado_nombre': empleadoNombre, 'empleado_nif': empleadoNif,
    'empleado_nss': empleadoNss, 'mes': mes, 'anio': anio, 'periodo': periodo,
    'salario_bruto_mensual': salarioBrutoMensual,
    'paga_extra': pagaExtra,
    'horas_extra': horasExtra, 'precio_hora_extra': precioHoraExtra,
    'importe_horas_extra': importeHorasExtra,
    'complementos': complementos, 'paga_extra_prorrateada': pagaExtraProrrata,
    'retribuciones_especie': retribucionesEspecie,
    // ── SS Trabajador ────────────────────────────────────────────────────────
    'base_cotizacion': baseCotizacion,
    'ss_trabajador_cc': ssTrabajadorCC,
    'ss_trabajador_desempleo': ssTrabajadorDesempleo,
    'ss_trabajador_fp': ssTrabajadorFP,
    'ss_mei_trabajador': ssMeiTrabajador,
    'ss_solidaridad_trabajador': ssSolidaridadTrabajador,
    'ss_horas_extra_trabajador': ssHorasExtraTrabajador,
    // ── IRPF ─────────────────────────────────────────────────────────────────
    'base_irpf': baseIrpf,
    'porcentaje_irpf': porcentajeIrpf,
    'retencion_irpf': retencionIrpf,
    'irpf_ajustado': irpfAjustado,
    // ── SS Empresa ───────────────────────────────────────────────────────────
    'ss_empresa_cc': ssEmpresaCC,
    'ss_empresa_desempleo': ssEmpresaDesempleo,
    'ss_empresa_fogasa': ssEmpresaFogasa,
    'ss_empresa_fp': ssEmpresaFP,
    'ss_empresa_at': ssEmpresaAT,
    'ss_mei_empresa': ssMeiEmpresa,
    'ss_solidaridad_empresa': ssSolidaridadEmpresa,
    'ss_horas_extra_empresa': ssHorasExtraEmpresa,
    'tipo_hora_extra': tipoHoraExtra.name,
    // ── Ausencias ────────────────────────────────────────────────────────────
    'descuento_ausencias': descuentoAusencias,
    'plus_antiguedad': plusAntiguedad,
    // ── Antigüedad ───────────────────────────────────────────────────────────
    'anios_antiguedad': aniosAntiguedad,
    'trienios_bienios': trieniosBienios,
    if (descripcionAntiguedad != null) 'descripcion_antiguedad': descripcionAntiguedad,
    'embargo_judicial': embargoJudicial,
    // ── Embargo ──────────────────────────────────────────────────────────────
    if (embargoDescripcion != null) 'embargo_descripcion': embargoDescripcion,
    'dias_it': diasIT,
    // ── IT ────────────────────────────────────────────────────────────────────
    'importe_it': importeIT,
    'importe_it_empresa': importeITEmpresa,
    'importe_it_inss': importeITINSS,
    'importe_it_mutua': importeITMutua,
    'descuento_salario_por_it': descuentoSalarioPorIT,
    if (tipoContingenciaIT != null) 'tipo_contingencia_it': tipoContingenciaIT,
    'regularizacion_irpf': regularizacionIrpf,
    // ── Regularización IRPF ──────────────────────────────────────────────────
    'complementos_detallados': complementosDetallados,
    // ── Complementos detallados ──────────────────────────────────────────────
    if (firmaUrl != null) 'firma_url': firmaUrl,
    // ── Firma electrónica ────────────────────────────────────────────────────
    if (firmaFecha != null) 'firma_fecha': Timestamp.fromDate(firmaFecha!),
    if (firmaEmpleadoId != null) 'firma_empleado_id': firmaEmpleadoId,
    if (estadoFirma != null) 'estado_firma': estadoFirma,
    'liquido_final': liquidoFinal,
    // ── Totales calculados (snapshot para queries Firestore) ─────────────────
    'total_ss_empresa': totalSSEmpresa,
    'estado': estado.name,
    'coste_total_empresa': costeTotalEmpresa,
    // ── Metadatos ────────────────────────────────────────────────────────────
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    if (fechaPago != null) 'fecha_pago': Timestamp.fromDate(fechaPago!),
    if (notas != null) 'notas': notas,
    if (gastoIdVinculado != null) 'gasto_id_vinculado': gastoIdVinculado,
  };

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  static const List<String> _meses = [
    '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];
  static String nombreMes(int mes) => _meses[mes.clamp(1, 12)];
}










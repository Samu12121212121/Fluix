// ════════════════════════════════════════════════════════════════════════════
// CONVENIOS COLECTIVOS — Tablas salariales España 2026
// Fuente: BOE / publicaciones sindicales (valores orientativos)
// ════════════════════════════════════════════════════════════════════════════

import '../domain/modelos/nomina.dart';

// ── Sectores con convenio colectivo ─────────────────────────────────────────

enum SectorEmpresa {
  hosteleria,
  construccion,
  comercioAlimentacion,
  comercioGeneral,
  oficinasDespachos,
  transporteCarretera,
  limpiezaEdificios,
  seguridadPrivada,
  metalurgiaSiderurgia,
  sanidadPrivada,
  educacionPrivada,
  agriculturaGanaderia,
  tecnologiaInformatica,
  bancaSeguros,
  industriaAlimentacion,
  peluqueriaEstetica,
  automocion,
  inmobiliaria,
  logisticaAlmacen,
  energiaYAgua,
  otros,
}

extension SectorEmpresaExt on SectorEmpresa {
  String get etiqueta {
    switch (this) {
      case SectorEmpresa.hosteleria:           return 'Hostelería y Turismo';
      case SectorEmpresa.construccion:         return 'Construcción y Obras Públicas';
      case SectorEmpresa.comercioAlimentacion: return 'Comercio de Alimentación';
      case SectorEmpresa.comercioGeneral:      return 'Comercio al por Menor (General)';
      case SectorEmpresa.oficinasDespachos:    return 'Oficinas y Despachos';
      case SectorEmpresa.transporteCarretera:  return 'Transporte de Mercancías por Carretera';
      case SectorEmpresa.limpiezaEdificios:    return 'Limpieza de Edificios y Locales';
      case SectorEmpresa.seguridadPrivada:     return 'Seguridad Privada';
      case SectorEmpresa.metalurgiaSiderurgia: return 'Metal / Siderurgia';
      case SectorEmpresa.sanidadPrivada:       return 'Sanidad Privada';
      case SectorEmpresa.educacionPrivada:     return 'Enseñanza Privada';
      case SectorEmpresa.agriculturaGanaderia: return 'Agricultura y Ganadería';
      case SectorEmpresa.tecnologiaInformatica:return 'Tecnología e Informática';
      case SectorEmpresa.bancaSeguros:         return 'Banca y Seguros';
      case SectorEmpresa.industriaAlimentacion:return 'Industria de Alimentación';
      case SectorEmpresa.peluqueriaEstetica:   return 'Peluquería y Estética';
      case SectorEmpresa.automocion:           return 'Automoción (Talleres y Concesionarios)';
      case SectorEmpresa.inmobiliaria:         return 'Inmobiliaria y Gestión de Patrimonios';
      case SectorEmpresa.logisticaAlmacen:     return 'Logística y Almacenaje';
      case SectorEmpresa.energiaYAgua:         return 'Energía, Agua y Medioambiente';
      case SectorEmpresa.otros:                return 'Otro sector';
    }
  }

  String get icono {
    switch (this) {
      case SectorEmpresa.hosteleria:           return '🍽️';
      case SectorEmpresa.construccion:         return '🏗️';
      case SectorEmpresa.comercioAlimentacion: return '🛒';
      case SectorEmpresa.comercioGeneral:      return '🏪';
      case SectorEmpresa.oficinasDespachos:    return '🏢';
      case SectorEmpresa.transporteCarretera:  return '🚛';
      case SectorEmpresa.limpiezaEdificios:    return '🧹';
      case SectorEmpresa.seguridadPrivada:     return '🛡️';
      case SectorEmpresa.metalurgiaSiderurgia: return '⚙️';
      case SectorEmpresa.sanidadPrivada:       return '🏥';
      case SectorEmpresa.educacionPrivada:     return '🎓';
      case SectorEmpresa.agriculturaGanaderia: return '🌾';
      case SectorEmpresa.tecnologiaInformatica:return '💻';
      case SectorEmpresa.bancaSeguros:         return '🏦';
      case SectorEmpresa.industriaAlimentacion:return '🏭';
      case SectorEmpresa.peluqueriaEstetica:   return '✂️';
      case SectorEmpresa.automocion:           return '🚗';
      case SectorEmpresa.inmobiliaria:         return '🏠';
      case SectorEmpresa.logisticaAlmacen:     return '📦';
      case SectorEmpresa.energiaYAgua:         return '⚡';
      case SectorEmpresa.otros:                return '📋';
    }
  }
}

// ── Categoría profesional del convenio ──────────────────────────────────────

class CategoriaConvenio {
  final String codigo;
  final String descripcion;
  /// Salario mínimo anual del convenio 2026 (€/año bruto)
  final double salarioMinimoAnual;
  final GrupoCotizacion grupoCotizacion;

  const CategoriaConvenio({
    required this.codigo,
    required this.descripcion,
    required this.salarioMinimoAnual,
    required this.grupoCotizacion,
  });

  double get salarioMinimoMensual => salarioMinimoAnual / 12;

  @override
  String toString() => descripcion;
}

// ════════════════════════════════════════════════════════════════════════════
// TABLAS SALARIALES POR SECTOR — España 2026
// Salarios mínimos de convenio (orientativos). Los convenios provinciales
// pueden ser superiores. Fuente: BOE y CCOO/UGT 2025-2026.
// ════════════════════════════════════════════════════════════════════════════

class ConvenioService {
  ConvenioService._();
  static final ConvenioService instance = ConvenioService._();

  // ── HOSTELERÍA Y TURISMO ─────────────────────────────────────────────────
  static const List<CategoriaConvenio> _hosteleria = [
    CategoriaConvenio(codigo: 'HOT-01', descripcion: 'Director/a de hotel ★★★★',              salarioMinimoAnual: 28_800, grupoCotizacion: GrupoCotizacion.grupo3),
    CategoriaConvenio(codigo: 'HOT-02', descripcion: 'Jefe/a de cocina / Maître',             salarioMinimoAnual: 20_400, grupoCotizacion: GrupoCotizacion.grupo4),
    CategoriaConvenio(codigo: 'HOT-03', descripcion: 'Encargado/a de sala/turno',             salarioMinimoAnual: 19_200, grupoCotizacion: GrupoCotizacion.grupo4),
    CategoriaConvenio(codigo: 'HOT-04', descripcion: 'Oficial 1ª (Camarero/a, Cocinero/a)',   salarioMinimoAnual: 18_120, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'HOT-05', descripcion: 'Oficial 2ª (Ayudante camarero/a)',      salarioMinimoAnual: 17_400, grupoCotizacion: GrupoCotizacion.grupo6),
    CategoriaConvenio(codigo: 'HOT-06', descripcion: 'Auxiliar / Ayudante cocina',            salarioMinimoAnual: 16_560, grupoCotizacion: GrupoCotizacion.grupo7),
    CategoriaConvenio(codigo: 'HOT-07', descripcion: 'Personal de limpieza / Camarero/a pisos', salarioMinimoAnual: 15_876, grupoCotizacion: GrupoCotizacion.grupo10),
  ];

  // ── CONSTRUCCIÓN ─────────────────────────────────────────────────────────
  static const List<CategoriaConvenio> _construccion = [
    CategoriaConvenio(codigo: 'CON-01', descripcion: 'Titulado superior (Arquitecto/Ing.)',   salarioMinimoAnual: 36_000, grupoCotizacion: GrupoCotizacion.grupo1),
    CategoriaConvenio(codigo: 'CON-02', descripcion: 'Titulado medio / Jefe de obra',         salarioMinimoAnual: 28_800, grupoCotizacion: GrupoCotizacion.grupo2),
    CategoriaConvenio(codigo: 'CON-03', descripcion: 'Encargado general / Jefe de equipo',    salarioMinimoAnual: 25_200, grupoCotizacion: GrupoCotizacion.grupo3),
    CategoriaConvenio(codigo: 'CON-04', descripcion: 'Oficial 1ª (albañil, fontanero...)',    salarioMinimoAnual: 23_400, grupoCotizacion: GrupoCotizacion.grupo8),
    CategoriaConvenio(codigo: 'CON-05', descripcion: 'Oficial 2ª',                           salarioMinimoAnual: 21_600, grupoCotizacion: GrupoCotizacion.grupo9),
    CategoriaConvenio(codigo: 'CON-06', descripcion: 'Especialista',                         salarioMinimoAnual: 20_400, grupoCotizacion: GrupoCotizacion.grupo9),
    CategoriaConvenio(codigo: 'CON-07', descripcion: 'Peón ordinario',                       salarioMinimoAnual: 19_200, grupoCotizacion: GrupoCotizacion.grupo10),
  ];

  // ── COMERCIO GENERAL ─────────────────────────────────────────────────────
  static const List<CategoriaConvenio> _comercioGeneral = [
    CategoriaConvenio(codigo: 'COM-01', descripcion: 'Director/a / Jefe/a de zona',          salarioMinimoAnual: 27_600, grupoCotizacion: GrupoCotizacion.grupo3),
    CategoriaConvenio(codigo: 'COM-02', descripcion: 'Jefe/a de sección',                    salarioMinimoAnual: 21_600, grupoCotizacion: GrupoCotizacion.grupo4),
    CategoriaConvenio(codigo: 'COM-03', descripcion: 'Comercial / Vendedor externo',         salarioMinimoAnual: 19_800, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'COM-04', descripcion: 'Dependiente/a oficial',                salarioMinimoAnual: 18_000, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'COM-05', descripcion: 'Auxiliar / Cajero/a',                  salarioMinimoAnual: 16_800, grupoCotizacion: GrupoCotizacion.grupo7),
    CategoriaConvenio(codigo: 'COM-06', descripcion: 'Mozo de almacén / Reponedor/a',        salarioMinimoAnual: 16_200, grupoCotizacion: GrupoCotizacion.grupo10),
  ];

  // ── COMERCIO DE ALIMENTACIÓN ─────────────────────────────────────────────
  static const List<CategoriaConvenio> _comercioAlimentacion = [
    CategoriaConvenio(codigo: 'ALI-01', descripcion: 'Director/a de supermercado',           salarioMinimoAnual: 28_800, grupoCotizacion: GrupoCotizacion.grupo3),
    CategoriaConvenio(codigo: 'ALI-02', descripcion: 'Jefe/a de sección alimentación',       salarioMinimoAnual: 21_000, grupoCotizacion: GrupoCotizacion.grupo4),
    CategoriaConvenio(codigo: 'ALI-03', descripcion: 'Oficial 1ª (carnicero, pescadero...)', salarioMinimoAnual: 18_600, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'ALI-04', descripcion: 'Cajero/a - Reponedor/a',               salarioMinimoAnual: 16_800, grupoCotizacion: GrupoCotizacion.grupo7),
    CategoriaConvenio(codigo: 'ALI-05', descripcion: 'Auxiliar de tienda',                   salarioMinimoAnual: 16_200, grupoCotizacion: GrupoCotizacion.grupo10),
  ];

  // ── OFICINAS Y DESPACHOS ─────────────────────────────────────────────────
  static const List<CategoriaConvenio> _oficinasDespachos = [
    CategoriaConvenio(codigo: 'OFI-01', descripcion: 'Director/a / Responsable de área',     salarioMinimoAnual: 31_200, grupoCotizacion: GrupoCotizacion.grupo3),
    CategoriaConvenio(codigo: 'OFI-02', descripcion: 'Técnico/a titulado',                   salarioMinimoAnual: 24_000, grupoCotizacion: GrupoCotizacion.grupo2),
    CategoriaConvenio(codigo: 'OFI-03', descripcion: 'Oficial 1ª administrativo',            salarioMinimoAnual: 19_200, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'OFI-04', descripcion: 'Oficial 2ª administrativo',            salarioMinimoAnual: 17_400, grupoCotizacion: GrupoCotizacion.grupo6),
    CategoriaConvenio(codigo: 'OFI-05', descripcion: 'Auxiliar administrativo',              salarioMinimoAnual: 16_200, grupoCotizacion: GrupoCotizacion.grupo7),
    CategoriaConvenio(codigo: 'OFI-06', descripcion: 'Recepcionista / Telefonista',          salarioMinimoAnual: 16_560, grupoCotizacion: GrupoCotizacion.grupo7),
  ];

  // ── TRANSPORTE DE MERCANCÍAS ─────────────────────────────────────────────
  static const List<CategoriaConvenio> _transporteCarretera = [
    CategoriaConvenio(codigo: 'TRN-01', descripcion: 'Jefe/a de tráfico',                    salarioMinimoAnual: 25_200, grupoCotizacion: GrupoCotizacion.grupo4),
    CategoriaConvenio(codigo: 'TRN-02', descripcion: 'Conductor/a de camión articulado (>16T)',salarioMinimoAnual: 24_000, grupoCotizacion: GrupoCotizacion.grupo8),
    CategoriaConvenio(codigo: 'TRN-03', descripcion: 'Conductor/a de camión rígido (7-16T)', salarioMinimoAnual: 22_200, grupoCotizacion: GrupoCotizacion.grupo8),
    CategoriaConvenio(codigo: 'TRN-04', descripcion: 'Conductor/a de furgoneta (<3,5T)',     salarioMinimoAnual: 20_400, grupoCotizacion: GrupoCotizacion.grupo9),
    CategoriaConvenio(codigo: 'TRN-05', descripcion: 'Mozo/a de almacén / Cargador/a',       salarioMinimoAnual: 18_600, grupoCotizacion: GrupoCotizacion.grupo10),
    CategoriaConvenio(codigo: 'TRN-06', descripcion: 'Auxiliar administrativo de tráfico',   salarioMinimoAnual: 17_400, grupoCotizacion: GrupoCotizacion.grupo7),
  ];

  // ── LIMPIEZA DE EDIFICIOS ─────────────────────────────────────────────────
  static const List<CategoriaConvenio> _limpiezaEdificios = [
    CategoriaConvenio(codigo: 'LIM-01', descripcion: 'Responsable de zona / Supervisor/a',   salarioMinimoAnual: 20_400, grupoCotizacion: GrupoCotizacion.grupo4),
    CategoriaConvenio(codigo: 'LIM-02', descripcion: 'Encargado/a de equipo',                salarioMinimoAnual: 18_000, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'LIM-03', descripcion: 'Oficial/a especialista',               salarioMinimoAnual: 16_800, grupoCotizacion: GrupoCotizacion.grupo9),
    CategoriaConvenio(codigo: 'LIM-04', descripcion: 'Limpiador/a',                          salarioMinimoAnual: 15_876, grupoCotizacion: GrupoCotizacion.grupo10),
    CategoriaConvenio(codigo: 'LIM-05', descripcion: 'Cristalero/a',                         salarioMinimoAnual: 17_400, grupoCotizacion: GrupoCotizacion.grupo9),
  ];

  // ── SEGURIDAD PRIVADA ────────────────────────────────────────────────────
  static const List<CategoriaConvenio> _seguridadPrivada = [
    CategoriaConvenio(codigo: 'SEG-01', descripcion: 'Director/a de seguridad',              salarioMinimoAnual: 30_000, grupoCotizacion: GrupoCotizacion.grupo3),
    CategoriaConvenio(codigo: 'SEG-02', descripcion: 'Jefe/a de seguridad',                  salarioMinimoAnual: 25_200, grupoCotizacion: GrupoCotizacion.grupo4),
    CategoriaConvenio(codigo: 'SEG-03', descripcion: 'Escolta privado',                      salarioMinimoAnual: 23_400, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'SEG-04', descripcion: 'Vigilante de seguridad (con arma)',     salarioMinimoAnual: 21_000, grupoCotizacion: GrupoCotizacion.grupo6),
    CategoriaConvenio(codigo: 'SEG-05', descripcion: 'Vigilante de seguridad (sin arma)',     salarioMinimoAnual: 19_200, grupoCotizacion: GrupoCotizacion.grupo6),
    CategoriaConvenio(codigo: 'SEG-06', descripcion: 'Auxiliar / Controlador de acceso',     salarioMinimoAnual: 17_400, grupoCotizacion: GrupoCotizacion.grupo7),
  ];

  // ── METAL / SIDERURGIA ───────────────────────────────────────────────────
  static const List<CategoriaConvenio> _metal = [
    CategoriaConvenio(codigo: 'MET-01', descripcion: 'Titulado superior (Ing. Industrial)',  salarioMinimoAnual: 34_800, grupoCotizacion: GrupoCotizacion.grupo1),
    CategoriaConvenio(codigo: 'MET-02', descripcion: 'Titulado medio / Técnico titulado',    salarioMinimoAnual: 27_600, grupoCotizacion: GrupoCotizacion.grupo2),
    CategoriaConvenio(codigo: 'MET-03', descripcion: 'Oficial de 1ª (tornero, fresador...)', salarioMinimoAnual: 23_400, grupoCotizacion: GrupoCotizacion.grupo8),
    CategoriaConvenio(codigo: 'MET-04', descripcion: 'Oficial de 2ª',                       salarioMinimoAnual: 21_600, grupoCotizacion: GrupoCotizacion.grupo9),
    CategoriaConvenio(codigo: 'MET-05', descripcion: 'Especialista',                         salarioMinimoAnual: 20_400, grupoCotizacion: GrupoCotizacion.grupo9),
    CategoriaConvenio(codigo: 'MET-06', descripcion: 'Peón',                                 salarioMinimoAnual: 18_600, grupoCotizacion: GrupoCotizacion.grupo10),
  ];

  // ── SANIDAD PRIVADA ──────────────────────────────────────────────────────
  static const List<CategoriaConvenio> _sanidad = [
    CategoriaConvenio(codigo: 'SAN-01', descripcion: 'Médico/a especialista',                salarioMinimoAnual: 42_000, grupoCotizacion: GrupoCotizacion.grupo1),
    CategoriaConvenio(codigo: 'SAN-02', descripcion: 'Médico/a general / Residente',         salarioMinimoAnual: 33_600, grupoCotizacion: GrupoCotizacion.grupo1),
    CategoriaConvenio(codigo: 'SAN-03', descripcion: 'Enfermero/a titulado/a',               salarioMinimoAnual: 27_600, grupoCotizacion: GrupoCotizacion.grupo2),
    CategoriaConvenio(codigo: 'SAN-04', descripcion: 'Fisioterapeuta',                       salarioMinimoAnual: 24_000, grupoCotizacion: GrupoCotizacion.grupo2),
    CategoriaConvenio(codigo: 'SAN-05', descripcion: 'Técnico/a en cuidados auxiliares',     salarioMinimoAnual: 19_200, grupoCotizacion: GrupoCotizacion.grupo7),
    CategoriaConvenio(codigo: 'SAN-06', descripcion: 'Celador/a',                            salarioMinimoAnual: 16_800, grupoCotizacion: GrupoCotizacion.grupo10),
    CategoriaConvenio(codigo: 'SAN-07', descripcion: 'Personal de limpieza hospitalaria',    salarioMinimoAnual: 15_876, grupoCotizacion: GrupoCotizacion.grupo10),
  ];

  // ── EDUCACIÓN PRIVADA ────────────────────────────────────────────────────
  static const List<CategoriaConvenio> _educacion = [
    CategoriaConvenio(codigo: 'EDU-01', descripcion: 'Director/a pedagógico',                salarioMinimoAnual: 33_600, grupoCotizacion: GrupoCotizacion.grupo1),
    CategoriaConvenio(codigo: 'EDU-02', descripcion: 'Profesor/a de secundaria / FP',        salarioMinimoAnual: 28_800, grupoCotizacion: GrupoCotizacion.grupo2),
    CategoriaConvenio(codigo: 'EDU-03', descripcion: 'Profesor/a de primaria / infantil',    salarioMinimoAnual: 24_000, grupoCotizacion: GrupoCotizacion.grupo2),
    CategoriaConvenio(codigo: 'EDU-04', descripcion: 'Monitor/a / Educador/a',               salarioMinimoAnual: 18_600, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'EDU-05', descripcion: 'Auxiliar técnico educativo',           salarioMinimoAnual: 16_800, grupoCotizacion: GrupoCotizacion.grupo7),
  ];

  // ── TECNOLOGÍA E INFORMÁTICA ─────────────────────────────────────────────
  static const List<CategoriaConvenio> _tecnologia = [
    CategoriaConvenio(codigo: 'TIC-01', descripcion: 'Director/a IT / CTO',                  salarioMinimoAnual: 48_000, grupoCotizacion: GrupoCotizacion.grupo1),
    CategoriaConvenio(codigo: 'TIC-02', descripcion: 'Jefe/a de proyecto',                   salarioMinimoAnual: 38_400, grupoCotizacion: GrupoCotizacion.grupo1),
    CategoriaConvenio(codigo: 'TIC-03', descripcion: 'Analista senior / Arquitecto software', salarioMinimoAnual: 33_600, grupoCotizacion: GrupoCotizacion.grupo2),
    CategoriaConvenio(codigo: 'TIC-04', descripcion: 'Analista-programador',                 salarioMinimoAnual: 28_800, grupoCotizacion: GrupoCotizacion.grupo2),
    CategoriaConvenio(codigo: 'TIC-05', descripcion: 'Programador/a (3+ años exp.)',          salarioMinimoAnual: 24_000, grupoCotizacion: GrupoCotizacion.grupo3),
    CategoriaConvenio(codigo: 'TIC-06', descripcion: 'Programador/a junior / Trainee',       salarioMinimoAnual: 18_600, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'TIC-07', descripcion: 'Técnico/a soporte / Helpdesk',         salarioMinimoAnual: 19_200, grupoCotizacion: GrupoCotizacion.grupo6),
  ];

  // ── BANCA Y SEGUROS ──────────────────────────────────────────────────────
  static const List<CategoriaConvenio> _banca = [
    CategoriaConvenio(codigo: 'BAN-01', descripcion: 'Director/a de oficina bancaria',       salarioMinimoAnual: 46_800, grupoCotizacion: GrupoCotizacion.grupo3),
    CategoriaConvenio(codigo: 'BAN-02', descripcion: 'Jefe/a de equipo / Gestor senior',     salarioMinimoAnual: 36_000, grupoCotizacion: GrupoCotizacion.grupo3),
    CategoriaConvenio(codigo: 'BAN-03', descripcion: 'Gestor/a de clientes / Comercial',     salarioMinimoAnual: 28_800, grupoCotizacion: GrupoCotizacion.grupo4),
    CategoriaConvenio(codigo: 'BAN-04', descripcion: 'Administrativo/a bancario',            salarioMinimoAnual: 24_000, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'BAN-05', descripcion: 'Auxiliar de caja',                     salarioMinimoAnual: 21_000, grupoCotizacion: GrupoCotizacion.grupo7),
  ];

  // ── AGRICULTURA Y GANADERÍA ──────────────────────────────────────────────
  static const List<CategoriaConvenio> _agricultura = [
    CategoriaConvenio(codigo: 'AGR-01', descripcion: 'Técnico/a agrícola (titulado)',         salarioMinimoAnual: 24_000, grupoCotizacion: GrupoCotizacion.grupo2),
    CategoriaConvenio(codigo: 'AGR-02', descripcion: 'Tractorista / Maquinista',              salarioMinimoAnual: 18_000, grupoCotizacion: GrupoCotizacion.grupo8),
    CategoriaConvenio(codigo: 'AGR-03', descripcion: 'Oficial/a especialista',               salarioMinimoAnual: 17_400, grupoCotizacion: GrupoCotizacion.grupo9),
    CategoriaConvenio(codigo: 'AGR-04', descripcion: 'Peón agrícola',                        salarioMinimoAnual: 15_876, grupoCotizacion: GrupoCotizacion.grupo10),
  ];

  // ── INDUSTRIA ALIMENTACIÓN ───────────────────────────────────────────────
  static const List<CategoriaConvenio> _industriaAlim = [
    CategoriaConvenio(codigo: 'IAL-01', descripcion: 'Técnico/a de calidad / Laboratorio',   salarioMinimoAnual: 25_200, grupoCotizacion: GrupoCotizacion.grupo2),
    CategoriaConvenio(codigo: 'IAL-02', descripcion: 'Oficial 1ª industrial alimentación',   salarioMinimoAnual: 20_400, grupoCotizacion: GrupoCotizacion.grupo8),
    CategoriaConvenio(codigo: 'IAL-03', descripcion: 'Oficial 2ª / Operario especialista',   salarioMinimoAnual: 18_600, grupoCotizacion: GrupoCotizacion.grupo9),
    CategoriaConvenio(codigo: 'IAL-04', descripcion: 'Operario/a de producción (peón)',       salarioMinimoAnual: 17_400, grupoCotizacion: GrupoCotizacion.grupo10),
  ];

  // ── PELUQUERÍA Y ESTÉTICA ────────────────────────────────────────────────
  static const List<CategoriaConvenio> _peluqueria = [
    CategoriaConvenio(codigo: 'PEL-01', descripcion: 'Director/a técnico / Gerente',         salarioMinimoAnual: 22_800, grupoCotizacion: GrupoCotizacion.grupo4),
    CategoriaConvenio(codigo: 'PEL-02', descripcion: 'Oficial 1ª peluquero/a-estilista',     salarioMinimoAnual: 18_000, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'PEL-03', descripcion: 'Oficial 2ª estética / depilación',     salarioMinimoAnual: 17_000, grupoCotizacion: GrupoCotizacion.grupo6),
    CategoriaConvenio(codigo: 'PEL-04', descripcion: 'Auxiliar / Aprendiz',                  salarioMinimoAnual: 15_876, grupoCotizacion: GrupoCotizacion.grupo7),
  ];

  // ── AUTOMOCIÓN ───────────────────────────────────────────────────────────
  static const List<CategoriaConvenio> _automocion = [
    CategoriaConvenio(codigo: 'AUT-01', descripcion: 'Jefe/a de taller / Servicio postventa', salarioMinimoAnual: 27_600, grupoCotizacion: GrupoCotizacion.grupo3),
    CategoriaConvenio(codigo: 'AUT-02', descripcion: 'Mecánico oficial 1ª',                  salarioMinimoAnual: 22_800, grupoCotizacion: GrupoCotizacion.grupo8),
    CategoriaConvenio(codigo: 'AUT-03', descripcion: 'Mecánico oficial 2ª',                  salarioMinimoAnual: 20_400, grupoCotizacion: GrupoCotizacion.grupo9),
    CategoriaConvenio(codigo: 'AUT-04', descripcion: 'Asesor/a de ventas de vehículos',      salarioMinimoAnual: 19_200, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'AUT-05', descripcion: 'Auxiliar de taller / Lavador',         salarioMinimoAnual: 16_800, grupoCotizacion: GrupoCotizacion.grupo10),
  ];

  // ── INMOBILIARIA ─────────────────────────────────────────────────────────
  static const List<CategoriaConvenio> _inmobiliaria = [
    CategoriaConvenio(codigo: 'INM-01', descripcion: 'Director/a de agencia',                salarioMinimoAnual: 27_600, grupoCotizacion: GrupoCotizacion.grupo3),
    CategoriaConvenio(codigo: 'INM-02', descripcion: 'Asesor/a inmobiliario senior',          salarioMinimoAnual: 21_000, grupoCotizacion: GrupoCotizacion.grupo4),
    CategoriaConvenio(codigo: 'INM-03', descripcion: 'Agente inmobiliario',                  salarioMinimoAnual: 18_000, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'INM-04', descripcion: 'Auxiliar administrativo',              salarioMinimoAnual: 16_200, grupoCotizacion: GrupoCotizacion.grupo7),
  ];

  // ── LOGÍSTICA Y ALMACÉN ──────────────────────────────────────────────────
  static const List<CategoriaConvenio> _logistica = [
    CategoriaConvenio(codigo: 'LOG-01', descripcion: 'Jefe/a de almacén',                    salarioMinimoAnual: 24_000, grupoCotizacion: GrupoCotizacion.grupo4),
    CategoriaConvenio(codigo: 'LOG-02', descripcion: 'Carretillero / Operador grúa',         salarioMinimoAnual: 19_200, grupoCotizacion: GrupoCotizacion.grupo8),
    CategoriaConvenio(codigo: 'LOG-03', descripcion: 'Mozo/a de almacén (especialista)',     salarioMinimoAnual: 18_000, grupoCotizacion: GrupoCotizacion.grupo9),
    CategoriaConvenio(codigo: 'LOG-04', descripcion: 'Mozo/a de almacén (peón)',             salarioMinimoAnual: 17_000, grupoCotizacion: GrupoCotizacion.grupo10),
    CategoriaConvenio(codigo: 'LOG-05', descripcion: 'Administrativo/a de logística',        salarioMinimoAnual: 18_600, grupoCotizacion: GrupoCotizacion.grupo5),
  ];

  // ── ENERGÍA Y AGUA ───────────────────────────────────────────────────────
  static const List<CategoriaConvenio> _energia = [
    CategoriaConvenio(codigo: 'ENE-01', descripcion: 'Ingeniero/a (titulado superior)',       salarioMinimoAnual: 38_400, grupoCotizacion: GrupoCotizacion.grupo1),
    CategoriaConvenio(codigo: 'ENE-02', descripcion: 'Técnico/a titulado medio',              salarioMinimoAnual: 28_800, grupoCotizacion: GrupoCotizacion.grupo2),
    CategoriaConvenio(codigo: 'ENE-03', descripcion: 'Operador/a de instalaciones',          salarioMinimoAnual: 22_800, grupoCotizacion: GrupoCotizacion.grupo5),
    CategoriaConvenio(codigo: 'ENE-04', descripcion: 'Oficial de mantenimiento',             salarioMinimoAnual: 20_400, grupoCotizacion: GrupoCotizacion.grupo8),
    CategoriaConvenio(codigo: 'ENE-05', descripcion: 'Auxiliar técnico',                     salarioMinimoAnual: 18_000, grupoCotizacion: GrupoCotizacion.grupo9),
  ];

  // ════════════════════════════════════════════════════════════════════════
  // MÉTODOS PÚBLICOS
  // ════════════════════════════════════════════════════════════════════════

  /// Devuelve las categorías para el sector dado.
  List<CategoriaConvenio> categoriasParaSector(SectorEmpresa sector) {
    switch (sector) {
      case SectorEmpresa.hosteleria:            return _hosteleria;
      case SectorEmpresa.construccion:          return _construccion;
      case SectorEmpresa.comercioGeneral:       return _comercioGeneral;
      case SectorEmpresa.comercioAlimentacion:  return _comercioAlimentacion;
      case SectorEmpresa.oficinasDespachos:     return _oficinasDespachos;
      case SectorEmpresa.transporteCarretera:   return _transporteCarretera;
      case SectorEmpresa.limpiezaEdificios:     return _limpiezaEdificios;
      case SectorEmpresa.seguridadPrivada:      return _seguridadPrivada;
      case SectorEmpresa.metalurgiaSiderurgia:  return _metal;
      case SectorEmpresa.sanidadPrivada:        return _sanidad;
      case SectorEmpresa.educacionPrivada:      return _educacion;
      case SectorEmpresa.agriculturaGanaderia:  return _agricultura;
      case SectorEmpresa.tecnologiaInformatica: return _tecnologia;
      case SectorEmpresa.bancaSeguros:          return _banca;
      case SectorEmpresa.industriaAlimentacion: return _industriaAlim;
      case SectorEmpresa.peluqueriaEstetica:    return _peluqueria;
      case SectorEmpresa.automocion:            return _automocion;
      case SectorEmpresa.inmobiliaria:          return _inmobiliaria;
      case SectorEmpresa.logisticaAlmacen:      return _logistica;
      case SectorEmpresa.energiaYAgua:          return _energia;
      case SectorEmpresa.otros:                 return [];
    }
  }

  /// Devuelve la categoría por su código, o null si no se encuentra.
  CategoriaConvenio? buscarCategoria(SectorEmpresa sector, String codigo) {
    return categoriasParaSector(sector)
        .cast<CategoriaConvenio?>()
        .firstWhere((c) => c?.codigo == codigo, orElse: () => null);
  }

  /// Devuelve el salario mínimo de convenio para un sector y categoría dados.
  double? salarioMinimoAnual(SectorEmpresa sector, String codigoCategoria) {
    return buscarCategoria(sector, codigoCategoria)?.salarioMinimoAnual;
  }

  /// Lista de todos los sectores con sus etiquetas.
  static List<SectorEmpresa> get todosSectores => SectorEmpresa.values;
}


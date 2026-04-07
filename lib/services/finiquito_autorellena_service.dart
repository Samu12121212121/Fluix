import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/nomina.dart';
import 'vacaciones_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO AUTO-RELLENO DE FINIQUITO
// Agrega datos de empleados, nóminas y vacaciones automáticamente.
// ═══════════════════════════════════════════════════════════════════════════════

/// Resultado de carga de datos para el finiquito.
class DatosAutoFiniquito {
  // ── Del módulo de empleados ────────────────────────────────────────────────
  final String empleadoId;
  final String nombre;
  final String? nif;
  final String? naf;         // Número Afiliación SS
  final DateTime? fechaAlta; // Fecha alta empresa
  final String? tipoContrato;
  final String? convenioId;
  final String? cargo;
  final String? departamento;
  final String? emailEmpleado;
  final String? domicilio;

  // ── Del módulo de nóminas ─────────────────────────────────────────────────
  final double salarioBrutoAnual;
  final double salarioBrutoMensual;
  final double salarioDiario;
  final bool pagasProrrateadas;
  final int numPagas;
  final double complementoFijo;
  final String? ultimaNominaId;
  final int? ultimaNominaMes;
  final int? ultimaNominaAnio;

  // ── Del módulo de vacaciones ──────────────────────────────────────────────
  final int diasVacacionesConvenio;
  final double diasVacacionesGenerados; // hasta fecha de cese
  final double diasVacacionesDisfrutados;
  final double diasVacacionesPendientes;
  final double diasCarryover;

  // ── Advertencias ─────────────────────────────────────────────────────────
  final List<String> advertencias;

  const DatosAutoFiniquito({
    required this.empleadoId,
    required this.nombre,
    this.nif,
    this.naf,
    this.fechaAlta,
    this.tipoContrato,
    this.convenioId,
    this.cargo,
    this.departamento,
    this.emailEmpleado,
    this.domicilio,
    required this.salarioBrutoAnual,
    required this.salarioBrutoMensual,
    required this.salarioDiario,
    this.pagasProrrateadas = false,
    this.numPagas = 14,
    this.complementoFijo = 0,
    this.ultimaNominaId,
    this.ultimaNominaMes,
    this.ultimaNominaAnio,
    this.diasVacacionesConvenio = 30,
    this.diasVacacionesGenerados = 0,
    this.diasVacacionesDisfrutados = 0,
    this.diasVacacionesPendientes = 0,
    this.diasCarryover = 0,
    this.advertencias = const [],
  });

  /// ¿Hay datos críticos faltantes?
  bool get hayAdvertencias => advertencias.isNotEmpty;
}

class FiniquitoAutoRellenaService {
  static final FiniquitoAutoRellenaService _i = FiniquitoAutoRellenaService._();
  factory FiniquitoAutoRellenaService() => _i;
  FiniquitoAutoRellenaService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final VacacionesService _vacSvc = VacacionesService();

  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTODO PRINCIPAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Carga todos los datos del empleado, nóminas y vacaciones para pre-rellenar
  /// el formulario de finiquito.
  Future<DatosAutoFiniquito> cargarDatosEmpleado(
    String empresaId,
    String empleadoId,
    DateTime fechaCese,
  ) async {
    final advertencias = <String>[];

    // ── 1. Datos del empleado ─────────────────────────────────────────────────
    final empDoc = await _db.collection('usuarios').doc(empleadoId).get();
    if (!empDoc.exists) {
      throw Exception('Empleado no encontrado');
    }
    final emp = empDoc.data()!;
    final datosNomina = emp['datos_nomina'] as Map<String, dynamic>? ?? {};
    final config = DatosNominaEmpleado.fromMap(datosNomina);

    final nombre = emp['nombre'] as String? ?? 'Empleado';
    final nif = emp['nif'] as String? ?? datosNomina['nif'] as String?;
    final naf = emp['naf'] as String? ?? datosNomina['naf'] as String?;
    final emailEmpleado = emp['email'] as String?;
    final cargo = emp['cargo'] as String? ?? datosNomina['cargo'] as String?;
    final departamento = emp['departamento'] as String?;
    final tipoContrato = datosNomina['tipo_contrato'] as String?;

    // Domicilio del empleado
    final domicilio = [
      emp['calle'] as String?,
      emp['ciudad'] as String?,
      emp['cp'] as String?,
    ].where((e) => e != null && e.isNotEmpty).join(', ');

    // Fecha de alta
    final fechaAlta = config.fechaInicioContrato;
    if (fechaAlta == null) {
      advertencias.add('⚠️ No se encontró la fecha de alta del empleado');
    }

    // Convenio
    final sector = datosNomina['sector_empresa'] as String?;
    final convenioId = _resolverConvenio(sector);

    // ── 2. Datos de nóminas ───────────────────────────────────────────────────
    double salarioBrutoAnual = config.salarioBrutoAnual;
    double complementoFijo = config.complementoFijo;
    bool pagasProrrateadas = config.pagasProrrateadas;
    int numPagas = config.numPagas;
    String? ultimaNominaId;
    int? ultimaNominaMes;
    int? ultimaNominaAnio;

    try {
      // Buscar la última nómina del empleado
      final nominasSnap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('nominas')
          .where('empleado_id', isEqualTo: empleadoId)
          .orderBy('anio', descending: true)
          .orderBy('mes', descending: true)
          .limit(1)
          .get();

      if (nominasSnap.docs.isNotEmpty) {
        final ultimaNomina = nominasSnap.docs.first.data();
        ultimaNominaId = nominasSnap.docs.first.id;
        ultimaNominaMes = (ultimaNomina['mes'] as num?)?.toInt();
        ultimaNominaAnio = (ultimaNomina['anio'] as num?)?.toInt();

        // Usar el salario bruto de la última nómina si está disponible
        final salarioUltimaNomina =
            (ultimaNomina['salario_bruto_anual'] as num?)?.toDouble();
        if (salarioUltimaNomina != null && salarioUltimaNomina > 0) {
          salarioBrutoAnual = salarioUltimaNomina;
        }

        // Pagas extra
        final numPagasNomina = (ultimaNomina['num_pagas'] as num?)?.toInt();
        if (numPagasNomina != null) numPagas = numPagasNomina;
        pagasProrrateadas =
            ultimaNomina['pagas_prorrateadas'] as bool? ?? pagasProrrateadas;
      } else {
        advertencias.add(
            '⚠️ No se encontraron nóminas registradas para este empleado. '
            'Los datos salariales provienen de la ficha del empleado.');
      }
    } catch (e) {
      advertencias.add('⚠️ Error al cargar nóminas: $e');
    }

    final salarioBrutoMensual = salarioBrutoAnual / 12;
    final salarioDiario = (salarioBrutoAnual + complementoFijo * 12) / 365;

    // ── 3. Datos de vacaciones ────────────────────────────────────────────────
    double diasVacGenerados = 0;
    double diasVacDisfrutados = 0;
    double diasVacPendientes = 0;
    double diasCarryover = 0;
    int diasVacConvenio = 30;

    try {
      // Días de vacaciones del convenio
      diasVacConvenio = _diasVacacionesPorConvenio(convenioId);

      // Días devengados hasta la fecha de cese (proporcional)
      final fechaInicioContrato =
          fechaAlta ?? DateTime(fechaCese.year, 1, 1);
      final diasTrabajados =
          fechaCese.difference(fechaInicioContrato).inDays + 1;
      diasVacGenerados =
          (diasTrabajados / 365.0 * diasVacConvenio);

      // Saldo de vacaciones del año actual
      final saldo = await _vacSvc.calcularSaldo(
        empresaId,
        empleadoId,
        fechaCese.year,
      );
      diasVacDisfrutados = saldo.diasDisfrutados;
      diasVacPendientes =
          (diasVacGenerados - diasVacDisfrutados).clamp(0, diasVacConvenio.toDouble());
      diasCarryover = saldo.diasArrastreRestantes;

      // Verificar actualización reciente del saldo
      final diasDesdeActualizacion = DateTime.now()
          .difference(saldo.ultimaActualizacion)
          .inDays;
      if (diasDesdeActualizacion > 30) {
        advertencias.add(
            'ℹ️ El saldo de vacaciones se actualizó hace $diasDesdeActualizacion días. '
            'Verifica que los días sean correctos.');
      }
    } catch (e) {
      advertencias.add('⚠️ No se pudo cargar el saldo de vacaciones: $e');
    }

    return DatosAutoFiniquito(
      empleadoId: empleadoId,
      nombre: nombre,
      nif: nif,
      naf: naf,
      fechaAlta: fechaAlta,
      tipoContrato: tipoContrato,
      convenioId: convenioId,
      cargo: cargo,
      departamento: departamento,
      emailEmpleado: emailEmpleado,
      domicilio: domicilio.isNotEmpty ? domicilio : null,
      salarioBrutoAnual: salarioBrutoAnual,
      salarioBrutoMensual: salarioBrutoMensual,
      salarioDiario: salarioDiario,
      pagasProrrateadas: pagasProrrateadas,
      numPagas: numPagas,
      complementoFijo: complementoFijo,
      ultimaNominaId: ultimaNominaId,
      ultimaNominaMes: ultimaNominaMes,
      ultimaNominaAnio: ultimaNominaAnio,
      diasVacacionesConvenio: diasVacConvenio,
      diasVacacionesGenerados: diasVacGenerados,
      diasVacacionesDisfrutados: diasVacDisfrutados,
      diasVacacionesPendientes: diasVacPendientes,
      diasCarryover: diasCarryover,
      advertencias: advertencias,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _resolverConvenio(String? sector) {
    switch (sector?.toLowerCase().trim()) {
      case 'hosteleria':
        return 'hosteleria-guadalajara';
      case 'comercio':
        return 'comercio-guadalajara';
      case 'peluqueria':
        return 'peluqueria-estetica-gimnasios';
      case 'carniceria':
      case 'industrias_carnicas':
        return 'industrias-carnicas-guadalajara-2025';
      case 'veterinarios':
      case 'veterinaria':
      case 'clinica_veterinaria':
        return 'veterinarios-guadalajara-2026';
      default:
        return 'hosteleria-guadalajara';
    }
  }

  int _diasVacacionesPorConvenio(String convenioId) {
    const mapa = {
      'hosteleria-guadalajara': 30,
      'comercio-guadalajara': 30,
      'peluqueria-estetica-gimnasios': 30,
      'industrias-carnicas-guadalajara-2025': 31,
      'veterinarios-guadalajara-2026': 30,
    };
    return mapa[convenioId] ?? 30;
  }
}



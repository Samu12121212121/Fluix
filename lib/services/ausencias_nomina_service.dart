import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vacacion_model.dart';
import 'vacaciones_service.dart';
import 'festivos_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE AUSENCIAS-NÓMINA
// Calcula descuentos automáticos por ausencias no retribuidas.
// ═══════════════════════════════════════════════════════════════════════════════

/// Configuración de retribución por tipo de ausencia.
class ConfigAusenciaNomina {
  final TipoAusencia tipo;
  final bool esRetribuida;
  final double porcentajeDescuento; // 0-100, 100 = descuento total

  const ConfigAusenciaNomina({
    required this.tipo,
    required this.esRetribuida,
    this.porcentajeDescuento = 100.0,
  });

  factory ConfigAusenciaNomina.fromMap(Map<String, dynamic> m) {
    return ConfigAusenciaNomina(
      tipo: TipoAusenciaExt.fromString(m['tipo'] as String?),
      esRetribuida: m['es_retribuida'] as bool? ?? true,
      porcentajeDescuento:
          (m['porcentaje_descuento'] as num?)?.toDouble() ?? 100.0,
    );
  }

  Map<String, dynamic> toMap() => {
        'tipo': tipo.valor,
        'es_retribuida': esRetribuida,
        'porcentaje_descuento': porcentajeDescuento,
      };
}

/// Resultado de un descuento por ausencia.
class DescuentoAusencia {
  final TipoAusencia tipo;
  final String concepto;
  final int diasAusencia;
  final double importeDescuento;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final bool pendienteJustificacion;

  const DescuentoAusencia({
    required this.tipo,
    required this.concepto,
    required this.diasAusencia,
    required this.importeDescuento,
    required this.fechaInicio,
    required this.fechaFin,
    this.pendienteJustificacion = false,
  });

  Map<String, dynamic> toLineaNomina() => {
        'concepto': concepto,
        'importe': -importeDescuento,
        'tipo': 'descuento_ausencia',
        'dias': diasAusencia,
        'fecha_inicio':
            '${fechaInicio.day.toString().padLeft(2, '0')}/${fechaInicio.month.toString().padLeft(2, '0')}',
        'fecha_fin':
            '${fechaFin.day.toString().padLeft(2, '0')}/${fechaFin.month.toString().padLeft(2, '0')}',
      };
}

/// Resumen de ausencias del mes para un empleado.
class ResumenAusenciasMes {
  final String empleadoId;
  final int anio;
  final int mes;
  final List<DescuentoAusencia> descuentos;
  final List<Map<String, dynamic>> lineasInformativas;
  final double totalDescuento;
  final bool hayPendientesJustificacion;

  const ResumenAusenciasMes({
    required this.empleadoId,
    required this.anio,
    required this.mes,
    required this.descuentos,
    this.lineasInformativas = const [],
    required this.totalDescuento,
    this.hayPendientesJustificacion = false,
  });
}

class AusenciasNominaService {
  static final AusenciasNominaService _i = AusenciasNominaService._();
  factory AusenciasNominaService() => _i;
  AusenciasNominaService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  final VacacionesService _vacSvc = VacacionesService();
  final FestivosService _festSvc = FestivosService();

  /// Configuración por defecto de retribución por tipo de ausencia.
  static const List<ConfigAusenciaNomina> _configPorDefecto = [
    ConfigAusenciaNomina(
        tipo: TipoAusencia.vacaciones, esRetribuida: true),
    ConfigAusenciaNomina(
        tipo: TipoAusencia.permisoRetribuido, esRetribuida: true),
    ConfigAusenciaNomina(
        tipo: TipoAusencia.bajaMedica, esRetribuida: true), // gestionada INSS
    ConfigAusenciaNomina(
        tipo: TipoAusencia.ausenciaJustificada,
        esRetribuida: true,
        porcentajeDescuento: 0),
    ConfigAusenciaNomina(
        tipo: TipoAusencia.ausenciaInjustificada,
        esRetribuida: false,
        porcentajeDescuento: 100),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtiene la configuración de retribución por tipo de ausencia.
  Future<List<ConfigAusenciaNomina>> obtenerConfiguracion(
      String empresaId) async {
    final doc = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('ausencias_nomina')
        .get();

    if (!doc.exists || doc.data()?['tipos'] == null) {
      return _configPorDefecto;
    }

    final tipos = doc.data()!['tipos'] as List<dynamic>;
    return tipos
        .map((t) => ConfigAusenciaNomina.fromMap(t as Map<String, dynamic>))
        .toList();
  }

  /// Guarda la configuración de retribución.
  Future<void> guardarConfiguracion(
    String empresaId,
    List<ConfigAusenciaNomina> config,
  ) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('configuracion')
        .doc('ausencias_nomina')
        .set({
      'tipos': config.map((c) => c.toMap()).toList(),
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO DE DESCUENTOS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula los descuentos por ausencias de un empleado en un mes.
  Future<ResumenAusenciasMes> calcularDescuentosMes(
    String empresaId,
    String empleadoId,
    int anio,
    int mes,
    double salarioBrutoMensual,
  ) async {
    // Obtener configuración de la empresa
    final config = await obtenerConfiguracion(empresaId);
    final configMap = {for (final c in config) c.tipo: c};

    // Obtener ausencias del mes (aprobadas)
    final ausencias = await _vacSvc.obtenerAusenciasMes(
      empresaId,
      anio,
      mes,
      empleadoId: empleadoId,
    );

    // Días hábiles del mes (para cálculo del salario diario)
    final inicioMes = DateTime(anio, mes, 1);
    final finMes = DateTime(anio, mes + 1, 0);
    final diasHabilesMes =
        await _festSvc.calcularDiasHabiles(empresaId, inicioMes, finMes);
    final salarioDiario =
        diasHabilesMes > 0 ? salarioBrutoMensual / diasHabilesMes : 0.0;

    final descuentos = <DescuentoAusencia>[];
    final lineasInfo = <Map<String, dynamic>>[];
    double totalDescuento = 0;
    bool hayPendientes = false;

    for (final ausencia in ausencias) {
      final diasEnMes =
          VacacionesService.diasEnMesDeSolicitud(ausencia, anio, mes);
      if (diasEnMes <= 0) continue;

      final cfg = configMap[ausencia.tipo];
      final esRetribuida = cfg?.esRetribuida ?? true;

      if (!esRetribuida) {
        // Calcular descuento
        final porcentaje = cfg?.porcentajeDescuento ?? 100.0;
        final descuento = salarioDiario * diasEnMes * (porcentaje / 100.0);

        final conceptoFechas =
            '${ausencia.fechaInicio.day}/${ausencia.fechaInicio.month} - '
            '${ausencia.fechaFin.day}/${ausencia.fechaFin.month}';

        descuentos.add(DescuentoAusencia(
          tipo: ausencia.tipo,
          concepto:
              'Desc. ${ausencia.tipo.etiqueta} ($diasEnMes d.) [$conceptoFechas]',
          diasAusencia: diasEnMes,
          importeDescuento: double.parse(descuento.toStringAsFixed(2)),
          fechaInicio: ausencia.fechaInicio,
          fechaFin: ausencia.fechaFin,
        ));
        totalDescuento += descuento;
      } else {
        // Línea informativa (no descuenta)
        lineasInfo.add({
          'concepto': '${ausencia.tipo.etiqueta} ($diasEnMes días)',
          'importe': 0.0,
          'tipo': 'informativo',
        });
      }
    }

    // Verificar si hay ausencias pendientes de justificar
    final pendientes = await _verificarPendientesJustificacion(
        empresaId, empleadoId, anio, mes);
    if (pendientes > 0) {
      hayPendientes = true;
    }

    return ResumenAusenciasMes(
      empleadoId: empleadoId,
      anio: anio,
      mes: mes,
      descuentos: descuentos,
      lineasInformativas: lineasInfo,
      totalDescuento: double.parse(totalDescuento.toStringAsFixed(2)),
      hayPendientesJustificacion: hayPendientes,
    );
  }

  /// Verifica si hay solicitudes pendientes de justificar.
  Future<int> _verificarPendientesJustificacion(
    String empresaId,
    String empleadoId,
    int anio,
    int mes,
  ) async {
    final inicioMes = DateTime(anio, mes, 1);
    final finMes = DateTime(anio, mes + 1, 0, 23, 59, 59);

    final snap = await _db
        .collection('vacaciones')
        .doc(empresaId)
        .collection('solicitudes')
        .where('empleado_id', isEqualTo: empleadoId)
        .where('estado', isEqualTo: EstadoSolicitud.solicitado.name)
        .get();

    int count = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final inicio = _parseDate(data['fecha_inicio']);
      final fin = _parseDate(data['fecha_fin']);
      if (inicio.isBefore(finMes) && fin.isAfter(inicioMes)) {
        count++;
      }
    }
    return count;
  }

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}



import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/nomina.dart';
import 'nominas_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// REGULARIZACIÓN ANUAL DE IRPF
// Se aplica en la nómina de diciembre (o cuando se detecte desviación).
// Art. 86-87 RIRPF — regularización tipo de retención.
// ═══════════════════════════════════════════════════════════════════════════════

class RegularizacionIRPFService {
  static final RegularizacionIRPFService _i = RegularizacionIRPFService._();
  factory RegularizacionIRPFService() => _i;
  RegularizacionIRPFService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Resultado de la regularización.
  /// [ajuste] > 0 → la empresa debe retener más en diciembre.
  /// [ajuste] < 0 → la empresa ha retenido de más, devuelve al trabajador.
  Future<ResultadoRegularizacion> calcularRegularizacion({
    required String empresaId,
    required String empleadoId,
    required int anio,
    DatosNominaEmpleado? config,
  }) async {
    // 1. Obtener todas las nóminas del año (enero a noviembre)
    final snap = await _db
        .collection('empresas').doc(empresaId).collection('nominas')
        .where('empleado_id', isEqualTo: empleadoId)
        .where('anio', isEqualTo: anio)
        .get();

    final nominasAnio = snap.docs
        .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
        .toList();

    // Separar enero-noviembre de diciembre (si ya existe)
    final nominasEneNov = nominasAnio.where((n) => n.mes < 12).toList();
    final nominaDicExistente = nominasAnio.where((n) => n.mes == 12).toList();

    // 2. Sumar retenciones practicadas (enero - noviembre)
    double irpfRetenidoEneNov = 0;
    double baseImponibleReal = 0;

    for (final n in nominasEneNov) {
      irpfRetenidoEneNov += n.retencionIrpf;
      baseImponibleReal += n.totalDevengos;
    }

    // Incluir diciembre si ya existe (para recálculo)
    for (final n in nominaDicExistente) {
      baseImponibleReal += n.totalDevengos;
    }

    // Si no hay nómina de diciembre todavía, estimar con la media
    if (nominaDicExistente.isEmpty && nominasEneNov.isNotEmpty) {
      final mediaMensual = baseImponibleReal / nominasEneNov.length;
      baseImponibleReal += mediaMensual;
    }

    // 3. Obtener datos del empleado para el cálculo correcto
    DatosNominaEmpleado? datosEmp = config;
    if (datosEmp == null) {
      datosEmp = await NominasService().obtenerDatosNominaEmpleado(empleadoId);
    }

    if (datosEmp == null) {
      return const ResultadoRegularizacion(
        irpfRetenidoEneNov: 0,
        irpfAnualCorrecto: 0,
        ajuste: 0,
        baseImponibleAnualReal: 0,
        porcentajeEfectivoReal: 0,
        porcentajeEfectivoAplicado: 0,
        alertaDesviacion: false,
        mensajeAlerta: null,
      );
    }

    // 4. Calcular el IRPF anual que debería haberse retenido
    final edad = datosEmp.fechaNacimiento != null
        ? anio - datosEmp.fechaNacimiento!.year
        : null;

    final pctAnualCorrecto = NominasService.calcularPorcentajeIrpf(
      baseImponibleReal,
      config: datosEmp,
      edadEmpleado: edad,
      comunidad: datosEmp.comunidadAutonoma,
    );

    final irpfAnualCorrecto = baseImponibleReal * pctAnualCorrecto / 100;

    // 5. Calcular el ajuste
    final totalRetenido = irpfRetenidoEneNov;
    final ajuste = irpfAnualCorrecto - totalRetenido;

    // 6. Verificar si hay alerta de desviación
    final salarioMensual = datosEmp.salarioBrutoAnual / 12;
    final umbralAlerta = salarioMensual * 0.20; // 20% del salario mensual
    final alertaDesviacion = ajuste.abs() > umbralAlerta;

    String? mensajeAlerta;
    if (alertaDesviacion) {
      if (ajuste > 0) {
        mensajeAlerta = 'Se ha retenido de menos durante el año. '
            'El ajuste de ${ajuste.toStringAsFixed(2)}€ supera el 20% del salario mensual '
            '(${umbralAlerta.toStringAsFixed(2)}€). Revise si ha habido cambios salariales '
            'no comunicados o variaciones en la situación familiar.';
      } else {
        mensajeAlerta = 'Se ha retenido de más durante el año. '
            'Se devolverán ${ajuste.abs().toStringAsFixed(2)}€ al trabajador. '
            'El importe supera el 20% del salario mensual.';
      }
    }

    final pctEfectivoAplicado = baseImponibleReal > 0
        ? (totalRetenido / baseImponibleReal * 100)
        : 0.0;

    return ResultadoRegularizacion(
      irpfRetenidoEneNov: double.parse(totalRetenido.toStringAsFixed(2)),
      irpfAnualCorrecto: double.parse(irpfAnualCorrecto.toStringAsFixed(2)),
      ajuste: double.parse(ajuste.toStringAsFixed(2)),
      baseImponibleAnualReal: double.parse(baseImponibleReal.toStringAsFixed(2)),
      porcentajeEfectivoReal: double.parse(pctAnualCorrecto.toStringAsFixed(2)),
      porcentajeEfectivoAplicado: double.parse(pctEfectivoAplicado.toStringAsFixed(2)),
      alertaDesviacion: alertaDesviacion,
      mensajeAlerta: mensajeAlerta,
    );
  }
}

/// Resultado de la regularización anual de IRPF.
class ResultadoRegularizacion {
  /// Total IRPF retenido de enero a noviembre.
  final double irpfRetenidoEneNov;
  /// IRPF anual correcto según ingresos reales y tarifa CLM 2026.
  final double irpfAnualCorrecto;
  /// Diferencia: positivo = hay que retener más; negativo = devolver.
  final double ajuste;
  /// Base imponible real del año completo.
  final double baseImponibleAnualReal;
  /// Porcentaje efectivo correcto para el año.
  final double porcentajeEfectivoReal;
  /// Porcentaje efectivo que se ha aplicado durante el año.
  final double porcentajeEfectivoAplicado;
  /// true si el ajuste supera el 20% del salario mensual.
  final bool alertaDesviacion;
  /// Mensaje descriptivo de la alerta (null si no hay alerta).
  final String? mensajeAlerta;

  const ResultadoRegularizacion({
    required this.irpfRetenidoEneNov,
    required this.irpfAnualCorrecto,
    required this.ajuste,
    required this.baseImponibleAnualReal,
    required this.porcentajeEfectivoReal,
    required this.porcentajeEfectivoAplicado,
    required this.alertaDesviacion,
    this.mensajeAlerta,
  });
}



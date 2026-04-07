 import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/baja_laboral.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE INCAPACIDAD TEMPORAL (IT)
// Cálculo de prestaciones por baja laboral según normativa española 2026.
// Art. 169-176 LGSS · RD 625/2014 · Orden TAS/399/2004
// ═══════════════════════════════════════════════════════════════════════════════

class ITService {
  static final ITService _i = ITService._();
  factory ITService() => _i;
  ITService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ── REFS ──────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _bajasRef(String empleadoId) =>
      _db.collection('usuarios').doc(empleadoId).collection('bajas_laborales');

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Registra una nueva baja laboral.
  Future<BajaLaboral> registrarBaja({
    required String empleadoId,
    required TipoContingencia tipo,
    required DateTime fechaInicio,
    required double baseCotizacionMesAnterior,
    String? numeroParteMedico,
    String? diagnostico,
    String? observaciones,
    bool mejoraConvenioDias1a3 = false,
    double porcentajeMejoraDias1a3 = 0,
  }) async {
    final baseReguladoraDiaria = baseCotizacionMesAnterior / 30;

    final ref = _bajasRef(empleadoId).doc();
    final baja = BajaLaboral(
      id: ref.id,
      empleadoId: empleadoId,
      tipo: tipo,
      fechaInicio: fechaInicio,
      baseReguladoraDiaria: baseReguladoraDiaria,
      numeroParteMedico: numeroParteMedico,
      diagnostico: diagnostico,
      observaciones: observaciones,
      mejoraConvenioDias1a3: mejoraConvenioDias1a3,
      porcentajeMejoraDias1a3: porcentajeMejoraDias1a3,
      fechaCreacion: DateTime.now(),
    );

    await ref.set(baja.toMap());
    return baja;
  }

  /// Registra el alta médica (cierra la baja).
  Future<void> registrarAlta(String empleadoId, String bajaId, DateTime fechaAlta) async {
    await _bajasRef(empleadoId).doc(bajaId).update({
      'fecha_fin': Timestamp.fromDate(fechaAlta),
    });
  }

  /// Obtiene todas las bajas del empleado.
  Future<List<BajaLaboral>> obtenerBajas(String empleadoId) async {
    final snap = await _bajasRef(empleadoId)
        .orderBy('fecha_inicio', descending: true)
        .get();
    return snap.docs
        .map((d) => BajaLaboral.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }

  /// Stream en tiempo real.
  Stream<List<BajaLaboral>> streamBajas(String empleadoId) {
    return _bajasRef(empleadoId)
        .orderBy('fecha_inicio', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => BajaLaboral.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  /// Obtiene las bajas activas o que intersecan un mes concreto.
  Future<List<BajaLaboral>> obtenerBajasEnMes(
      String empleadoId, int mes, int anio) async {
    final todas = await obtenerBajas(empleadoId);
    return todas.where((b) => b.diasEnMes(mes, anio) > 0).toList();
  }

  /// Elimina una baja (solo si está activa y sin nóminas generadas).
  Future<void> eliminarBaja(String empleadoId, String bajaId) async {
    await _bajasRef(empleadoId).doc(bajaId).delete();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CÁLCULO DE PRESTACIÓN IT
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula el impacto de la IT en la nómina de un mes concreto.
  ///
  /// [baja] — La baja laboral activa.
  /// [mes], [anio] — El mes de la nómina.
  /// [diasMes] — Total de días naturales del mes (28-31).
  /// [salarioMensual] — Salario bruto mensual del empleado (para calcular descuento).
  ResultadoIT calcularImpactoEnNomina({
    required BajaLaboral baja,
    required int mes,
    required int anio,
    required int diasMes,
    required double salarioMensual,
  }) {
    final diasBajaEnMes = baja.diasEnMes(mes, anio);
    if (diasBajaEnMes == 0) return ResultadoIT.vacio;

    final diasTrabajados = diasMes - diasBajaEnMes;
    final baseRD = baja.baseReguladoraDiaria;
    final tramos = <TramoIT>[];

    double importeTotal = 0;
    double cargoEmpresa = 0;
    double cargoINSS = 0;
    double cargoMutua = 0;

    // Día relativo al inicio de la baja en que empieza y termina este mes
    final diaRelInicio = baja.diaInicioRelativo(mes, anio);
    final diaRelFin = diaRelInicio + diasBajaEnMes - 1;

    if (baja.tipo.esMaternidadPaternidad) {
      // ── MATERNIDAD / PATERNIDAD ─────────────────────────────────────
      // 100% base reguladora, a cargo del INSS desde día 1.
      final importe = baseRD * diasBajaEnMes;
      importeTotal = importe;
      cargoINSS = importe;
      tramos.add(TramoIT(
        diaDesde: diaRelInicio, diaHasta: diaRelFin,
        porcentaje: 100, importeDiario: baseRD,
        dias: diasBajaEnMes, pagador: 'inss',
        descripcion: 'Maternidad/Paternidad — 100% BR (INSS)',
      ));
    } else if (baja.tipo.esProfesional) {
      // ── CONTINGENCIAS PROFESIONALES (AT / EP) ───────────────────────
      // 75% base reguladora desde el día siguiente al accidente.
      // A cargo de la Mutua.
      final importe = baseRD * 0.75 * diasBajaEnMes;
      importeTotal = importe;
      cargoMutua = importe;
      tramos.add(TramoIT(
        diaDesde: diaRelInicio, diaHasta: diaRelFin,
        porcentaje: 75, importeDiario: baseRD * 0.75,
        dias: diasBajaEnMes, pagador: 'mutua',
        descripcion: 'Contingencia profesional — 75% BR (Mutua)',
      ));
    } else {
      // ── CONTINGENCIAS COMUNES (EC / ANL) ────────────────────────────
      // Días 1-3: sin prestación (salvo mejora voluntaria del convenio)
      // Días 4-15: 60% BR — a cargo de la empresa
      // Días 16-20: 60% BR — a cargo del INSS (empresa anticipa)
      // Día 21+: 75% BR — a cargo del INSS

      for (int diaRel = diaRelInicio; diaRel <= diaRelFin; diaRel++) {
        double pct = 0;
        String pagador = 'trabajador';
        String desc = '';

        if (diaRel <= 3) {
          // Días 1-3: sin prestación
          if (baja.mejoraConvenioDias1a3) {
            pct = baja.porcentajeMejoraDias1a3;
            pagador = 'empresa';
            desc = 'Días 1-3 — Mejora convenio ${pct.toStringAsFixed(0)}% BR (Empresa)';
          } else {
            pct = 0;
            pagador = 'trabajador';
            desc = 'Días 1-3 — Sin prestación (a cargo del trabajador)';
          }
        } else if (diaRel <= 15) {
          pct = 60;
          pagador = 'empresa';
          desc = 'Días 4-15 — 60% BR (Empresa)';
        } else if (diaRel <= 20) {
          pct = 60;
          pagador = 'inss';
          desc = 'Días 16-20 — 60% BR (INSS, anticipa empresa)';
        } else {
          pct = 75;
          pagador = 'inss';
          desc = 'Día 21+ — 75% BR (INSS)';
        }

        final importeDia = baseRD * pct / 100;

        // Agrupar días consecutivos con mismo tramo
        if (tramos.isNotEmpty &&
            tramos.last.porcentaje == pct &&
            tramos.last.pagador == pagador &&
            tramos.last.diaHasta == diaRel - 1) {
          final prev = tramos.removeLast();
          tramos.add(TramoIT(
            diaDesde: prev.diaDesde, diaHasta: diaRel,
            porcentaje: pct, importeDiario: importeDia,
            dias: prev.dias + 1, pagador: pagador,
            descripcion: desc,
          ));
        } else {
          tramos.add(TramoIT(
            diaDesde: diaRel, diaHasta: diaRel,
            porcentaje: pct, importeDiario: importeDia,
            dias: 1, pagador: pagador,
            descripcion: desc,
          ));
        }

        importeTotal += importeDia;
        switch (pagador) {
          case 'empresa':    cargoEmpresa += importeDia; break;
          case 'inss':       cargoINSS += importeDia; break;
          case 'mutua':      cargoMutua += importeDia; break;
          default: break; // trabajador: sin coste
        }
      }
    }

    // Descuento proporcional del salario por los días de baja
    final descuentoSalario = salarioMensual * diasBajaEnMes / diasMes;

    return ResultadoIT(
      diasBaja: diasBajaEnMes,
      diasTrabajados: diasTrabajados,
      importeIT: double.parse(importeTotal.toStringAsFixed(2)),
      importeCargoEmpresa: double.parse(cargoEmpresa.toStringAsFixed(2)),
      importeCargoINSS: double.parse(cargoINSS.toStringAsFixed(2)),
      importeCargoMutua: double.parse(cargoMutua.toStringAsFixed(2)),
      descuentoSalario: double.parse(descuentoSalario.toStringAsFixed(2)),
      tipo: baja.tipo,
      tramos: tramos,
    );
  }

  /// Calcula el impacto total de TODAS las bajas activas en un mes.
  Future<ResultadoIT> calcularImpactoMes({
    required String empleadoId,
    required int mes,
    required int anio,
    required double salarioMensual,
  }) async {
    final bajas = await obtenerBajasEnMes(empleadoId, mes, anio);
    if (bajas.isEmpty) return ResultadoIT.vacio;

    final diasMes = DateTime(anio, mes + 1, 0).day;
    int totalDiasBaja = 0;
    double totalImporteIT = 0;
    double totalCargoEmpresa = 0;
    double totalCargoINSS = 0;
    double totalCargoMutua = 0;
    double totalDescuento = 0;
    final todosTramos = <TramoIT>[];

    for (final baja in bajas) {
      final res = calcularImpactoEnNomina(
        baja: baja, mes: mes, anio: anio,
        diasMes: diasMes, salarioMensual: salarioMensual,
      );
      totalDiasBaja += res.diasBaja;
      totalImporteIT += res.importeIT;
      totalCargoEmpresa += res.importeCargoEmpresa;
      totalCargoINSS += res.importeCargoINSS;
      totalCargoMutua += res.importeCargoMutua;
      totalDescuento += res.descuentoSalario;
      todosTramos.addAll(res.tramos);
    }

    return ResultadoIT(
      diasBaja: totalDiasBaja.clamp(0, diasMes),
      diasTrabajados: (diasMes - totalDiasBaja).clamp(0, diasMes),
      importeIT: double.parse(totalImporteIT.toStringAsFixed(2)),
      importeCargoEmpresa: double.parse(totalCargoEmpresa.toStringAsFixed(2)),
      importeCargoINSS: double.parse(totalCargoINSS.toStringAsFixed(2)),
      importeCargoMutua: double.parse(totalCargoMutua.toStringAsFixed(2)),
      descuentoSalario: double.parse(totalDescuento.toStringAsFixed(2)),
      tipo: bajas.first.tipo,
      tramos: todosTramos,
    );
  }
}



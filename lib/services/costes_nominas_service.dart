import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/modelos/nomina.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICIO DE COSTES DE NÓMINAS — Agregación y análisis
// ═══════════════════════════════════════════════════════════════════════════════

class CostesNominasService {
  static final CostesNominasService _i = CostesNominasService._();
  factory CostesNominasService() => _i;
  CostesNominasService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _nominas(String e) =>
      _db.collection('empresas').doc(e).collection('nominas');

  // ═══════════════════════════════════════════════════════════════════════════
  // RESUMEN GLOBAL DEL MES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<ResumenCostesMes> obtenerResumenMes(
      String empresaId, int anio, int mes) async {
    final snap = await _nominas(empresaId)
        .where('anio', isEqualTo: anio)
        .where('mes', isEqualTo: mes)
        .get();
    final nominas = snap.docs
        .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
        .toList();

    return _calcularResumen(nominas, anio, mes);
  }

  ResumenCostesMes _calcularResumen(List<Nomina> nominas, int anio, int mes) {
    double totalNetos = 0;
    double totalIRPF = 0;
    double totalSSTrabajador = 0;
    double totalSSEmpresa = 0;
    double totalBruto = 0;
    final desglose = <DesgloseCostesEmpleado>[];

    for (final n in nominas) {
      totalNetos += n.salarioNeto;
      totalIRPF += n.retencionIrpf;
      totalSSTrabajador += n.totalSSTrabajador;
      totalSSEmpresa += n.totalSSEmpresa;
      totalBruto += n.totalDevengos;

      desglose.add(DesgloseCostesEmpleado(
        empleadoId: n.empleadoId,
        nombre: n.empleadoNombre,
        salarioBruto: n.totalDevengos,
        ssTrabajador: n.totalSSTrabajador,
        irpfRetenido: n.retencionIrpf,
        neto: n.salarioNeto,
        ssEmpresa: n.totalSSEmpresa,
        costeTotalEmpresa: n.costeTotalEmpresa,
      ));
    }

    final costeTotalEmpresa = totalNetos + totalSSEmpresa + totalIRPF + totalSSTrabajador;

    return ResumenCostesMes(
      anio: anio,
      mes: mes,
      numEmpleados: nominas.length,
      totalNetos: _r(totalNetos),
      totalIRPF: _r(totalIRPF),
      totalSSTrabajador: _r(totalSSTrabajador),
      totalSSEmpresa: _r(totalSSEmpresa),
      totalBruto: _r(totalBruto),
      costeTotalEmpresa: _r(costeTotalEmpresa),
      desglose: desglose..sort((a, b) => b.costeTotalEmpresa.compareTo(a.costeTotalEmpresa)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPARATIVA MES ANTERIOR
  // ═══════════════════════════════════════════════════════════════════════════

  Future<double> variacionMesAnterior(
      String empresaId, int anio, int mes) async {
    final actual = await obtenerResumenMes(empresaId, anio, mes);
    final mesAnt = mes == 1 ? 12 : mes - 1;
    final anioAnt = mes == 1 ? anio - 1 : anio;
    final anterior = await obtenerResumenMes(empresaId, anioAnt, mesAnt);

    if (anterior.costeTotalEmpresa == 0) return 0;
    return ((actual.costeTotalEmpresa - anterior.costeTotalEmpresa) /
        anterior.costeTotalEmpresa * 100);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EVOLUCIÓN ÚLTIMOS 12 MESES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<CostesMensual>> evolucion12Meses(
      String empresaId, int anio, int mes) async {
    final resultados = <CostesMensual>[];

    for (int i = 11; i >= 0; i--) {
      int m = mes - i;
      int a = anio;
      while (m <= 0) { m += 12; a--; }

      final resumen = await obtenerResumenMes(empresaId, a, m);
      resultados.add(CostesMensual(
        anio: a, mes: m,
        costeTotalEmpresa: resumen.costeTotalEmpresa,
        totalNetos: resumen.totalNetos,
        totalSSEmpresa: resumen.totalSSEmpresa,
        totalIRPF: resumen.totalIRPF,
      ));
    }

    return resultados;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EXPORTAR CSV
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> exportarResumenCsv(
    BuildContext context,
    String empresaId,
    int anio,
    int mes,
  ) async {
    final resumen = await obtenerResumenMes(empresaId, anio, mes);
    final buf = StringBuffer();

    // Cabecera
    buf.writeln('Empleado,Salario Bruto,SS Trabajador,IRPF Retenido,'
        'Neto,SS Empresa,Coste Total Empresa');

    for (final d in resumen.desglose) {
      buf.writeln([
        _csvEsc(d.nombre),
        d.salarioBruto.toStringAsFixed(2),
        d.ssTrabajador.toStringAsFixed(2),
        d.irpfRetenido.toStringAsFixed(2),
        d.neto.toStringAsFixed(2),
        d.ssEmpresa.toStringAsFixed(2),
        d.costeTotalEmpresa.toStringAsFixed(2),
      ].join(','));
    }

    // Fila de totales
    buf.writeln([
      'TOTAL',
      resumen.totalBruto.toStringAsFixed(2),
      resumen.totalSSTrabajador.toStringAsFixed(2),
      resumen.totalIRPF.toStringAsFixed(2),
      resumen.totalNetos.toStringAsFixed(2),
      resumen.totalSSEmpresa.toStringAsFixed(2),
      resumen.costeTotalEmpresa.toStringAsFixed(2),
    ].join(','));

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/Costes_Nominas_${Nomina.nombreMes(mes)}_$anio.csv',
    );
    await file.writeAsString(buf.toString());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Costes nóminas ${Nomina.nombreMes(mes)} $anio',
    );
  }

  static String _csvEsc(String v) =>
      (v.contains(',') || v.contains('"') || v.contains('\n'))
          ? '"${v.replaceAll('"', '""')}"' : v;

  static double _r(double v) => double.parse(v.toStringAsFixed(2));
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODELOS DE DATOS
// ═══════════════════════════════════════════════════════════════════════════════

class ResumenCostesMes {
  final int anio;
  final int mes;
  final int numEmpleados;
  final double totalNetos;
  final double totalIRPF;
  final double totalSSTrabajador;
  final double totalSSEmpresa;
  final double totalBruto;
  final double costeTotalEmpresa;
  final List<DesgloseCostesEmpleado> desglose;

  const ResumenCostesMes({
    required this.anio, required this.mes, required this.numEmpleados,
    required this.totalNetos, required this.totalIRPF,
    required this.totalSSTrabajador, required this.totalSSEmpresa,
    required this.totalBruto, required this.costeTotalEmpresa,
    required this.desglose,
  });
}

class DesgloseCostesEmpleado {
  final String empleadoId;
  final String nombre;
  final double salarioBruto;
  final double ssTrabajador;
  final double irpfRetenido;
  final double neto;
  final double ssEmpresa;
  final double costeTotalEmpresa;

  const DesgloseCostesEmpleado({
    required this.empleadoId, required this.nombre,
    required this.salarioBruto, required this.ssTrabajador,
    required this.irpfRetenido, required this.neto,
    required this.ssEmpresa, required this.costeTotalEmpresa,
  });
}

class CostesMensual {
  final int anio;
  final int mes;
  final double costeTotalEmpresa;
  final double totalNetos;
  final double totalSSEmpresa;
  final double totalIRPF;

  const CostesMensual({
    required this.anio, required this.mes,
    required this.costeTotalEmpresa, required this.totalNetos,
    required this.totalSSEmpresa, required this.totalIRPF,
  });

  String get etiqueta => '${Nomina.nombreMes(mes).substring(0, 3)} $anio';
}


import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/modelos/nomina.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// GENERADOR TC2 / FICHERO AFILIACIÓN — Sistema RED (TGSS)
// Formato compatible con importación en Siltra / Sistema RED.
// Referencia: Instrucción de Servicio 4/2004 TGSS — Formato FAN/TC2.
// ═══════════════════════════════════════════════════════════════════════════════

class Tc2Generator {
  static final _db = FirebaseFirestore.instance;

  // ── Cabecera del fichero TC2 ──────────────────────────────────────────────
  // Registro tipo 1: datos de empresa/período
  static String _cabecera({
    required String ccc,
    required int mes,
    required int anio,
    required String razonSocial,
  }) {
    final periodo = '${anio}${mes.toString().padLeft(2, '0')}';
    final nombre  = razonSocial.padRight(50).substring(0, 50);
    return '1$ccc${nombre}$periodo\r\n';
  }

  // ── Registro de empleado (tipo 2) ─────────────────────────────────────────
  // Campos principales TC2 simplificado (Siltra-compatible):
  //   Tipo(1) | NAF(12) | Nombre(26) | BaseCotizacion(10) | BaseAT(10) |
  //   DiasHigh(2) | Contingencias(10) | AT(8) | Desempleo(8) | FP(6) | MEI(8)
  static String _registroEmpleado(Nomina n) {
    final naf   = (n.empleadoNss ?? '').replaceAll(RegExp(r'[^0-9]'), '')
                      .padLeft(12, '0').substring(0, 12);
    final nombre = _limpiar(n.empleadoNombre).padRight(26).substring(0, 26);
    final base   = _importe(n.baseCotizacion);
    final baseAt = _importe(n.baseCotizacion);
    final diasHigh = '30';
    final cc       = _importe(n.ssTrabajadorCC + n.ssEmpresaCC);
    final at       = _importe(n.ssEmpresaAT);
    final desemp   = _importe(n.ssTrabajadorDesempleo + n.ssEmpresaDesempleo);
    final fp_      = _importe(n.ssTrabajadorFP + n.ssEmpresaFP);
    final mei      = _importe(n.ssMeiTrabajador + n.ssMeiEmpresa);

    return '2$naf$nombre$base$baseAt$diasHigh$cc$at$desemp$fp_$mei\r\n';
  }

  // ── Pie del fichero (tipo 9) ──────────────────────────────────────────────
  static String _pie({required int numRegistros, required double totalBases}) {
    return '9${numRegistros.toString().padLeft(6, '0')}${_importe(totalBases)}\r\n';
  }

  static String _importe(double v) =>
      (v * 100).round().abs().toString().padLeft(10, '0');

  static String _limpiar(String s) =>
      s.replaceAll(RegExp(r'[^\w\s]'), '').trim();

  // ═══════════════════════════════════════════════════════════════════════════
  // GENERAR FICHERO TC2 PARA UN MES
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<String> generarContenido({
    required String empresaId,
    required int mes,
    required int anio,
  }) async {
    // Cargar datos de empresa
    final empresaDoc = await _db.collection('empresas').doc(empresaId).get();
    final data       = empresaDoc.data() ?? {};
    final perfil     = data['perfil'] as Map<String, dynamic>? ?? {};
    final nombre     = (perfil['nombre'] as String?)?.isNotEmpty == true
        ? perfil['nombre'] as String : (data['razon_social'] as String? ?? 'Empresa');
    final ccc        = (data['ccc_ss'] as String?)?.isNotEmpty == true
        ? data['ccc_ss'] as String
        : (perfil['ccc_ss'] as String? ?? '000000000000');
    final cccFmt     = ccc.replaceAll(RegExp(r'[^0-9]'), '')
                         .padLeft(12, '0').substring(0, 12);

    // Cargar nóminas del mes
    final nominasDocs = await _db
        .collection('empresas').doc(empresaId)
        .collection('nominas')
        .where('mes', isEqualTo: mes)
        .where('anio', isEqualTo: anio)
        .get();

    if (nominasDocs.docs.isEmpty) {
      throw Exception('No hay nóminas generadas para ${Nomina.nombreMes(mes)} $anio');
    }

    final nominas = nominasDocs.docs
        .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
        .toList();

    final buffer = StringBuffer();
    buffer.write(_cabecera(ccc: cccFmt, mes: mes, anio: anio, razonSocial: nombre));

    double totalBases = 0;
    for (final n in nominas) {
      buffer.write(_registroEmpleado(n));
      totalBases += n.baseCotizacion;
    }

    buffer.write(_pie(numRegistros: nominas.length, totalBases: totalBases));
    return buffer.toString();
  }

  // ── Generar, guardar y compartir ──────────────────────────────────────────

  static Future<void> exportarYCompartir({
    required BuildContext context,
    required String empresaId,
    required int mes,
    required int anio,
  }) async {
    final contenido = await generarContenido(
      empresaId: empresaId, mes: mes, anio: anio,
    );

    final dir  = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/TC2_${anio}_${mes.toString().padLeft(2, '0')}.txt',
    );
    await file.writeAsString(contenido);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'TC2 ${Nomina.nombreMes(mes)} $anio',
      text: 'Fichero TC2 para importar en Siltra / Sistema RED (TGSS)',
    );
  }
}

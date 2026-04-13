import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/modelos/factura.dart';
import '../domain/modelos/factura_recibida.dart';
import 'exportadores_aeat/mod_347_exporter.dart';

class Mod347Service {
  static final _db = FirebaseFirestore.instance;

  // ── CÁLCULO COMPLETO ───────────────────────────────────────────────────────

  Future<Resumen347> calcular(String empresaId, int anio) async {
    final inicio = DateTime(anio, 1, 1);
    final fin = DateTime(anio + 1, 1, 1);

    final emitidas = await _obtenerEmitidas(empresaId, inicio, fin);
    final recibidas = await _obtenerRecibidas(empresaId, inicio, fin);

    return Mod347Exporter.calcular(
      anio: anio,
      facturasEmitidas: emitidas,
      facturasRecibidas: recibidas,
    );
  }

  // ── DESCARGA ───────────────────────────────────────────────────────────────

  Future<void> descargarFichero({
    required String empresaId,
    required String nifDeclarante,
    required String nombreDeclarante,
    required int anio,
    required Function(String) onError,
    required Function() onSuccess,
  }) async {
    try {
      debugPrint('📋 347: iniciando generación — ejercicio $anio');
      final resumen = await calcular(empresaId, anio);
      debugPrint(
          '📋 347: operaciones declarables — ventas: ${resumen.operacionesVenta.length}, '
          'compras: ${resumen.operacionesCompra.length}');

      if (resumen.numDeclaraciones == 0) {
        debugPrint('📋 347: sin operaciones que superen el umbral 3.005,06€');
        onSuccess();
        return;
      }

      final contenido = Mod347Exporter.generarFichero(
        nifDeclarante: nifDeclarante,
        nombreDeclarante: nombreDeclarante,
        resumen: resumen,
      );
      debugPrint('📋 347: fichero generado — ${contenido.length} bytes');

      if (kIsWeb) {
        onError('Descarga de ficheros no disponible en web.');
        return;
      }

      // getDownloadsDirectory() devuelve null en iOS → usar getTemporaryDirectory()
      Directory? dir = await getDownloadsDirectory();
      dir ??= await getTemporaryDirectory();

      final archivo = File('${dir.path}/MOD347_$anio.txt');
      await archivo.writeAsBytes(contenido);
      debugPrint('📋 347: compartiendo fichero — ${archivo.path}');

      await Share.shareXFiles(
        [XFile(archivo.path)],
        subject: 'MOD 347 — Ejercicio $anio',
        text: 'Fichero MOD 347 para importar en Sede Electrónica AEAT',
      );

      onSuccess();
    } catch (e) {
      debugPrint('📋 347: ERROR — $e');
      onError(e.toString());
    }
  }

  // ── HELPERS FIRESTORE ──────────────────────────────────────────────────────

  Future<List<Factura>> _obtenerEmitidas(
    String empresaId,
    DateTime inicio,
    DateTime fin,
  ) async {
    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas')
        .where('fecha_emision',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_emision', isLessThan: Timestamp.fromDate(fin))
        .get();

    return snap.docs
        .map((d) => Factura.fromFirestore(d))
        .where((f) => f.estado != EstadoFactura.anulada)
        .toList();
  }

  Future<List<FacturaRecibida>> _obtenerRecibidas(
    String empresaId,
    DateTime inicio,
    DateTime fin,
  ) async {
    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('facturas_recibidas')
        .where('fecha_recepcion',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('fecha_recepcion', isLessThan: Timestamp.fromDate(fin))
        .get();

    return snap.docs
        .map((d) => FacturaRecibida.fromFirestore(d))
        .where((f) => f.estado != EstadoFacturaRecibida.rechazada)
        .toList();
  }
}


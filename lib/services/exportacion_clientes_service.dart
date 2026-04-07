import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Servicio de exportación de clientes a CSV y Excel (.xlsx).
/// Calcula totales de facturación en el momento de la exportación.
class ExportacionClientesService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final _fmtFecha = DateFormat('dd/MM/yyyy');
  static final _fmtFechaArchivo = DateFormat('yyyy-MM-dd');

  // ── EXPORTAR A CSV ────────────────────────────────────────────────────────

  Future<File> exportarCSV({
    required String empresaId,
    required String nombreEmpresa,
    required List<Map<String, dynamic>> clientes,
    void Function(int actual, int total)? onProgreso,
  }) async {
    final rows = <List<String>>[
      // Cabecera
      [
        'Nombre',
        'NIF/CIF',
        'Email',
        'Teléfono',
        'Dirección',
        'Localidad',
        'Etiquetas',
        'Estado',
        'Fecha de alta',
        'Total facturado',
        'Última actividad',
        'Nº facturas',
      ],
    ];

    for (int i = 0; i < clientes.length; i++) {
      final c = clientes[i];
      final datosFacturacion = await _obtenerDatosFacturacion(
        empresaId: empresaId,
        clienteNombre: c['nombre'] ?? '',
        clienteCorreo: c['correo']?.toString(),
      );

      rows.add([
        c['nombre'] ?? '',
        c['nif'] ?? '',
        c['correo'] ?? '',
        c['telefono'] ?? '',
        c['direccion'] ?? '',
        c['localidad'] ?? '',
        (c['etiquetas'] as List?)?.join(', ') ?? '',
        c['estado_cliente'] ?? 'contacto',
        c['fecha_registro'] != null
            ? _fmtFecha.format(DateTime.parse(c['fecha_registro']))
            : '',
        datosFacturacion['total'].toStringAsFixed(2),
        c['ultima_actividad'] != null
            ? _fmtFecha.format(DateTime.parse(c['ultima_actividad']))
            : (c['ultima_visita'] != null
                ? _fmtFecha.format(DateTime.parse(c['ultima_visita']))
                : 'Sin actividad'),
        datosFacturacion['count'].toString(),
      ]);

      onProgreso?.call(i + 1, clientes.length);
    }

    // BOM UTF-8 para que Excel reconozca tildes/ñ
    const bom = '\uFEFF';
    final csvString = bom + const ListToCsvConverter().convert(rows);

    final dir = await getTemporaryDirectory();
    final fileName =
        'clientes_${_limpiarNombre(nombreEmpresa)}_${_fmtFechaArchivo.format(DateTime.now())}.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csvString);
    return file;
  }

  // ── EXPORTAR A EXCEL ──────────────────────────────────────────────────────

  /// Genera un archivo .xlsx con los datos de clientes.
  /// Nota: Usa el formato CSV con extensión xls como alternativa ligera
  /// para no depender del package excel que puede dar problemas de tamaño.
  Future<File> exportarExcel({
    required String empresaId,
    required String nombreEmpresa,
    required List<Map<String, dynamic>> clientes,
    void Function(int actual, int total)? onProgreso,
  }) async {
    // Generamos un TSV (tab-separated) que Excel abre nativamente
    final rows = <List<String>>[
      [
        'Nombre',
        'NIF/CIF',
        'Email',
        'Teléfono',
        'Dirección',
        'Localidad',
        'Etiquetas',
        'Estado',
        'Fecha de alta',
        'Total facturado',
        'Última actividad',
        'Nº facturas',
      ],
    ];

    for (int i = 0; i < clientes.length; i++) {
      final c = clientes[i];
      final datosFacturacion = await _obtenerDatosFacturacion(
        empresaId: empresaId,
        clienteNombre: c['nombre'] ?? '',
        clienteCorreo: c['correo']?.toString(),
      );

      rows.add([
        c['nombre'] ?? '',
        c['nif'] ?? '',
        c['correo'] ?? '',
        c['telefono'] ?? '',
        c['direccion'] ?? '',
        c['localidad'] ?? '',
        (c['etiquetas'] as List?)?.join(', ') ?? '',
        c['estado_cliente'] ?? 'contacto',
        c['fecha_registro'] != null
            ? _fmtFecha.format(DateTime.parse(c['fecha_registro']))
            : '',
        datosFacturacion['total'].toStringAsFixed(2),
        c['ultima_actividad'] != null
            ? _fmtFecha.format(DateTime.parse(c['ultima_actividad']))
            : (c['ultima_visita'] != null
                ? _fmtFecha.format(DateTime.parse(c['ultima_visita']))
                : 'Sin actividad'),
        datosFacturacion['count'].toString(),
      ]);

      onProgreso?.call(i + 1, clientes.length);
    }

    const bom = '\uFEFF';
    final tsvString = bom +
        rows
            .map((row) => row.map(_escaparTSV).join('\t'))
            .join('\n');

    final dir = await getTemporaryDirectory();
    final fileName =
        'clientes_${_limpiarNombre(nombreEmpresa)}_${_fmtFechaArchivo.format(DateTime.now())}.xls';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(tsvString);
    return file;
  }

  // ── COMPARTIR ARCHIVO ─────────────────────────────────────────────────────

  Future<void> compartirArchivo(File file) async {
    await Share.shareXFiles([XFile(file.path)]);
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _obtenerDatosFacturacion({
    required String empresaId,
    required String clienteNombre,
    String? clienteCorreo,
  }) async {
    try {
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('facturas')
          .where('cliente_nombre', isEqualTo: clienteNombre)
          .get();

      double total = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final estado = d['estado'] ?? '';
        if (estado != 'anulada') {
          total += ((d['total'] ?? 0) as num).toDouble();
        }
      }
      return {'total': total, 'count': snap.docs.length};
    } catch (_) {
      return {'total': 0.0, 'count': 0};
    }
  }

  String _limpiarNombre(String nombre) =>
      nombre
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_')
          .replaceAll(RegExp(r'_+'), '_');

  String _escaparTSV(String value) =>
      value.contains('\t') || value.contains('\n')
          ? '"${value.replaceAll('"', '""')}"'
          : value;
}



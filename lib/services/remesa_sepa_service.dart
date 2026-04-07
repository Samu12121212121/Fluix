import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/modelos/nomina.dart';
import '../domain/modelos/remesa_sepa.dart';
import 'sepa_xml_generator.dart';
import 'empresa_config_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// REMESA SEPA SERVICE — CRUD Firestore + generación/compartición XML
// ═══════════════════════════════════════════════════════════════════════════════

class RemesaSepaService {
  static final RemesaSepaService _i = RemesaSepaService._();
  factory RemesaSepaService() => _i;
  RemesaSepaService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final EmpresaConfigService _configSvc = EmpresaConfigService();

  CollectionReference<Map<String, dynamic>> _col(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('remesas_sepa');

  CollectionReference<Map<String, dynamic>> _nominas(String empresaId) =>
      _db.collection('empresas').doc(empresaId).collection('nominas');

  // ═══════════════════════════════════════════════════════════════════════════
  // OBTENER DATOS EMPLEADOS (DatosNominaEmpleado con IBAN)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtiene DatosNominaEmpleado por cada empleadoId.
  Future<Map<String, DatosNominaEmpleado>> obtenerDatosEmpleados(
    List<String> empleadoIds,
  ) async {
    final result = <String, DatosNominaEmpleado>{};
    for (final id in empleadoIds.toSet()) {
      final doc = await _db.collection('usuarios').doc(id).get();
      if (doc.exists) {
        final datosMap = doc.data()?['datos_nomina'] as Map<String, dynamic>?;
        if (datosMap != null) {
          result[id] = DatosNominaEmpleado.fromMap(datosMap);
        }
      }
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OBTENER IBAN/BIC EMPRESA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Lee el IBAN de la empresa desde el doc de Firestore.
  Future<Map<String, String>> obtenerIbanBicEmpresa(String empresaId) async {
    final doc = await _db.collection('empresas').doc(empresaId).get();
    final data = doc.data() ?? {};
    return {
      'iban': (data['iban_empresa'] as String?) ?? '',
      'bic': (data['bic_empresa'] as String?) ?? '',
    };
  }

  /// Guarda el IBAN/BIC de la empresa.
  Future<void> guardarIbanBicEmpresa(
    String empresaId,
    String iban,
    String? bic,
  ) async {
    await _db.collection('empresas').doc(empresaId).set({
      'iban_empresa': SepaXmlGenerator.limpiarIBAN(iban),
      if (bic != null && bic.isNotEmpty) 'bic_empresa': bic.toUpperCase(),
    }, SetOptions(merge: true));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OBTENER NÓMINAS APROBADAS DEL MES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Nomina>> obtenerNominasAprobadas(
    String empresaId, int anio, int mes,
  ) async {
    final snap = await _nominas(empresaId)
        .where('anio', isEqualTo: anio)
        .where('mes', isEqualTo: mes)
        .where('estado', isEqualTo: EstadoNomina.aprobada.name)
        .get();
    return snap.docs
        .map((d) => Nomina.fromMap({...d.data(), 'id': d.id}))
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CREAR REMESA + GENERAR XML
  // ═══════════════════════════════════════════════════════════════════════════

  /// Crea una remesa SEPA, genera el XML y lo guarda en Firestore.
  /// Devuelve la RemesaSepa creada con el XML.
  Future<RemesaSepa> crearRemesa({
    required String empresaId,
    required List<Nomina> nominas,
    required DateTime fechaEjecucion,
  }) async {
    // 1. Obtener config empresa
    final config = await _configSvc.obtenerConfig(empresaId);
    final ibanBic = await obtenerIbanBicEmpresa(empresaId);
    final ibanEmpresa = ibanBic['iban'] ?? '';
    final bicEmpresa = ibanBic['bic'] ?? '';

    final ordenante = DatosOrdenante.fromConfig(
      config,
      ibanEmpresa: ibanEmpresa,
      bicEmpresa: bicEmpresa.isNotEmpty ? bicEmpresa : null,
    );

    // 2. Obtener datos empleados
    final empleadoIds = nominas.map((n) => n.empleadoId).toList();
    final datosEmpleados = await obtenerDatosEmpleados(empleadoIds);

    // 3. Validar
    final errores = SepaXmlGenerator.validarLote(
      nominas: nominas,
      ordenante: ordenante,
      datosEmpleados: datosEmpleados,
      fechaEjecucion: fechaEjecucion,
    );
    if (errores.isNotEmpty) {
      throw Exception(errores.join('\n'));
    }

    // 4. Generar MsgId
    final ahora = DateTime.now();
    final nif = config.nifNormalizado;
    final msgId = '$nif'
        '${ahora.year.toString().padLeft(4, '0')}'
        '${ahora.month.toString().padLeft(2, '0')}'
        '${ahora.day.toString().padLeft(2, '0')}'
        '${ahora.hour.toString().padLeft(2, '0')}'
        '${ahora.minute.toString().padLeft(2, '0')}'
        '${ahora.second.toString().padLeft(2, '0')}';

    // 5. Generar XML
    final xml = SepaXmlGenerator.generarXML(
      nominas: nominas,
      ordenante: ordenante,
      datosEmpleados: datosEmpleados,
      fechaEjecucion: fechaEjecucion,
      msgId: msgId.length > 35 ? msgId.substring(0, 35) : msgId,
    );

    // 6. Crear documento en Firestore
    final mes = nominas.first.mes;
    final anio = nominas.first.anio;
    final docRef = _col(empresaId).doc();
    final importeTotal = nominas.fold(0.0, (s, n) => s + n.salarioNeto);

    final remesa = RemesaSepa(
      id: docRef.id,
      empresaId: empresaId,
      mes: mes,
      anio: anio,
      fechaEjecucion: fechaEjecucion,
      nominasIds: nominas.map((n) => n.id).toList(),
      nTransferencias: nominas.length,
      importeTotal: importeTotal,
      estado: EstadoRemesa.generada,
      msgId: msgId.length > 35 ? msgId.substring(0, 35) : msgId,
      xmlGenerado: xml,
      fechaCreacion: ahora,
    );

    await docRef.set(remesa.toMap());
    return remesa;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONSULTAS
  // ═══════════════════════════════════════════════════════════════════════════

  Stream<List<RemesaSepa>> obtenerRemesas(String empresaId) {
    return _col(empresaId)
        .orderBy('fecha_creacion', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => RemesaSepa.fromMap({...d.data(), 'id': d.id}))
            .toList());
  }

  Future<RemesaSepa?> obtenerRemesaPorId(String empresaId, String remesaId) async {
    final doc = await _col(empresaId).doc(remesaId).get();
    if (!doc.exists) return null;
    return RemesaSepa.fromMap({...doc.data()!, 'id': doc.id});
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> marcarComoEnviada(String empresaId, String remesaId) async {
    await _col(empresaId).doc(remesaId).update({
      'estado': EstadoRemesa.enviada.name,
      'fecha_envio': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> marcarComoConfirmada(String empresaId, String remesaId) async {
    await _col(empresaId).doc(remesaId).update({
      'estado': EstadoRemesa.confirmada.name,
    });
  }

  Future<void> marcarComoRechazada(String empresaId, String remesaId) async {
    await _col(empresaId).doc(remesaId).update({
      'estado': EstadoRemesa.rechazada.name,
    });
  }

  /// Marca las nóminas incluidas como pagadas.
  Future<void> marcarNominasPagadas(
    String empresaId,
    List<String> nominasIds,
  ) async {
    final batch = _db.batch();
    for (final id in nominasIds) {
      batch.update(_nominas(empresaId).doc(id), {
        'estado': EstadoNomina.pagada.name,
        'fecha_pago': Timestamp.fromDate(DateTime.now()),
      });
    }
    await batch.commit();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPARTIR XML
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda el XML en un fichero temporal y lo comparte.
  Future<void> compartirXml(
    BuildContext context,
    RemesaSepa remesa,
  ) async {
    final xml = remesa.xmlGenerado;
    if (xml == null || xml.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay XML generado en esta remesa')),
        );
      }
      return;
    }

    final dir = await getTemporaryDirectory();
    final fileName = 'SEPA_${remesa.msgId}.xml';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(xml, flush: true);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Remesa SEPA — ${remesa.periodoTexto} — '
          '${remesa.nTransferencias} transferencias — '
          '${remesa.importeTotal.toStringAsFixed(2)}€',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESCARGA DIRECTA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Guarda el XML en Downloads (Android) o Documents (iOS).
  Future<void> descargarXml(BuildContext context, RemesaSepa remesa) async {
    final xml = remesa.xmlGenerado;
    if (xml == null || xml.isEmpty) return;

    final name = 'SEPA_NOMINAS_${_formatoFecha(remesa.fechaEjecucion)}.xml';

    try {
      String? path;

      if (Platform.isAndroid) {
        // En Android, intentar obtener directorio Downloads
        // Requiere: android.permission.WRITE_EXTERNAL_STORAGE (API < 29)
        // O usar MediaStore (API >= 29). Como simplificación usamos path_provider
        // y solicitamos permisos.
        if (await Permission.storage.request().isGranted ||
            await Permission.manageExternalStorage.request().isGranted) {

          // Opción 1: /storage/emulated/0/Download
          final dir = Directory('/storage/emulated/0/Download');
          if (dir.existsSync()) {
            path = '${dir.path}/$name';
          } else {
            // Opción 2: getExternalStorageDirectory (Android/data/...)
            final extDir = await getExternalStorageDirectory();
            path = '${extDir?.path}/$name';
          }
        } else {
          _snack(context, '⚠️ Permiso de almacenamiento denegado', Colors.orange);
          return;
        }
      } else if (Platform.isIOS) {
        // En iOS, guardar en Documents (accesible desde Files si UIFileSharingEnabled=YES)
        final dir = await getApplicationDocumentsDirectory();
        path = '${dir.path}/$name';
      }

      if (path != null) {
        final file = File(path);
        await file.writeAsString(xml, flush: true);
        _snack(context, '✅ Archivo guardado en: $path', Colors.green);
      }
    } catch (e) {
      _snack(context, '❌ Error guardando archivo: $e', Colors.red);
    }
  }

  String _formatoFecha(DateTime d) =>
      '${d.year}_${d.month.toString().padLeft(2, '0')}_${d.day.toString().padLeft(2, '0')}';

  void _snack(BuildContext context, String msg, Color color) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color),
      );
    }
  }
}





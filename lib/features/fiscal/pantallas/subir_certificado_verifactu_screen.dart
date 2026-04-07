import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA PARA SUBIR CERTIFICADO VERIFACTU
// El admin sube su .p12/.pfx y la contraseña, y se guarda en Firestore.
//
// USO: Desde la pantalla de configuración fiscal, añade un botón que abra
// esta pantalla. Solo visible para rol admin/propietario.
//
// DÓNDE SE GUARDA:
//   Firestore → empresas/{empresaId}/configuracion/certificado_verifactu
//   Campos: { p12Base64: "...", password: "...", fechaSubida: Timestamp }
//
//   Fallback global (para testing):
//   Firestore → config/verifactu_cert
//   Campos: { p12Base64: "...", password: "...", fechaSubida: Timestamp }
// ═══════════════════════════════════════════════════════════════════════════════

class SubirCertificadoVerifactuScreen extends StatefulWidget {
  final String empresaId;

  const SubirCertificadoVerifactuScreen({
    super.key,
    required this.empresaId,
  });

  @override
  State<SubirCertificadoVerifactuScreen> createState() =>
      _SubirCertificadoVerifactuScreenState();
}

class _SubirCertificadoVerifactuScreenState
    extends State<SubirCertificadoVerifactuScreen> {
  final _passwordController = TextEditingController();
  String? _nombreArchivo;
  String? _p12Base64;
  bool _subiendo = false;
  bool _tieneExistente = false;
  DateTime? _fechaSubida;

  @override
  void initState() {
    super.initState();
    _verificarExistente();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _verificarExistente() async {
    final doc = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('configuracion')
        .doc('certificado_verifactu')
        .get();

    if (doc.exists && mounted) {
      setState(() {
        _tieneExistente = true;
        final ts = doc.data()?['fecha_subida'];
        if (ts is Timestamp) _fechaSubida = ts.toDate();
      });
    }
  }

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['p12', 'pfx'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _nombreArchivo = result.files.single.name;
        _p12Base64 = base64Encode(result.files.single.bytes!);
      });
    }
  }

  Future<void> _subir() async {
    if (_p12Base64 == null || _p12Base64!.isEmpty) {
      _mostrarError('Selecciona un archivo .p12 o .pfx primero');
      return;
    }
    if (_passwordController.text.trim().isEmpty) {
      _mostrarError('Introduce la contraseña del certificado');
      return;
    }

    setState(() => _subiendo = true);

    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('configuracion')
          .doc('certificado_verifactu')
          .set({
        'p12Base64': _p12Base64,
        'password': _passwordController.text.trim(),
        'fecha_subida': FieldValue.serverTimestamp(),
        'nombre_archivo': _nombreArchivo,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Certificado subido correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _tieneExistente = true;
          _fechaSubida = DateTime.now();
          _p12Base64 = null;
          _nombreArchivo = null;
          _passwordController.clear();
        });
      }
    } catch (e) {
      _mostrarError('Error al subir: $e');
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificado Verifactu'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text('¿Qué es esto?',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Para firmar y enviar facturas a la AEAT (Verifactu) '
                  'necesitas tu certificado digital en formato .p12 o .pfx.\n\n'
                  'Puedes obtenerlo en:\n'
                  '• FNMT (www.cert.fnmt.es)\n'
                  '• AC Camerfirma\n'
                  '• Firmaprofesional',
                  style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Estado actual
          if (_tieneExistente) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Certificado configurado',
                            style: TextStyle(fontWeight: FontWeight.bold,
                                color: Colors.green.shade700)),
                        if (_fechaSubida != null)
                          Text(
                            'Subido el ${_fechaSubida!.day}/${_fechaSubida!.month}/${_fechaSubida!.year}',
                            style: TextStyle(fontSize: 12,
                                color: Colors.green.shade600),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Puedes reemplazar el certificado subiendo uno nuevo:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
          ],

          // Selector archivo
          OutlinedButton.icon(
            onPressed: _seleccionarArchivo,
            icon: const Icon(Icons.upload_file),
            label: Text(_nombreArchivo ?? 'Seleccionar archivo .p12 / .pfx'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_nombreArchivo != null) ...[
            const SizedBox(height: 6),
            Text('📎 $_nombreArchivo',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
          const SizedBox(height: 16),

          // Contraseña
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Contraseña del certificado',
              hintText: 'La que pusiste al exportar el .p12',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 24),

          // Botón subir
          ElevatedButton.icon(
            onPressed: _subiendo ? null : _subir,
            icon: _subiendo
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        color: Colors.white))
                : const Icon(Icons.cloud_upload),
            label: Text(_subiendo ? 'Subiendo...' : 'Subir certificado'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),

          // Advertencia seguridad
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El certificado se almacena cifrado en Firebase Firestore '
                    'y solo es accesible por las Cloud Functions de tu proyecto. '
                    'Nunca compartas tu archivo .p12 con terceros.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



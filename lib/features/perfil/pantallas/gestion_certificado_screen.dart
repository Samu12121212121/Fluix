import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/certificado_digital_service.dart';
import '../../../services/verifactu/firma_xades_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA GESTIÓN CERTIFICADO DIGITAL
//
// Acceso: Ajustes → Empresa → Certificado digital
// Rol requerido: admin / propietario
// ═══════════════════════════════════════════════════════════════════════════════

class GestionCertificadoScreen extends StatefulWidget {
  final String empresaId;

  const GestionCertificadoScreen({super.key, required this.empresaId});

  @override
  State<GestionCertificadoScreen> createState() =>
      _GestionCertificadoScreenState();
}

class _GestionCertificadoScreenState extends State<GestionCertificadoScreen> {
  late final CertificadoDigitalService _svc;
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _verPass = false;
  bool _procesando = false;
  String? _nombreArchivo;
  Uint8List? _p12Bytes;
  String? _errorSubida;

  @override
  void initState() {
    super.initState();
    _svc = CertificadoDigitalService(empresaId: widget.empresaId);
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  // ─── Acciones ──────────────────────────────────────────────────────────────

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['p12', 'pfx'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _nombreArchivo = result.files.single.name;
        _p12Bytes = result.files.single.bytes;
        _errorSubida = null;
      });
    }
  }

  Future<void> _subirCertificado() async {
    if (!_formKey.currentState!.validate()) return;
    if (_p12Bytes == null) {
      setState(() => _errorSubida = 'Selecciona un archivo .p12 o .pfx primero');
      return;
    }

    setState(() {
      _procesando = true;
      _errorSubida = null;
    });

    try {
      // Obtener NIF de la empresa para validar
      final empDoc = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .get();
      final nifEmpresa = empDoc.data()?['nif'] as String?;

      await _svc.cargarCertificado(
        bytes: _p12Bytes!,
        password: _passCtrl.text.trim(),
        nifEmpresa: nifEmpresa,
        nombreArchivo: _nombreArchivo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Certificado cargado correctamente'),
          backgroundColor: Colors.green,
        ));
        setState(() {
          _p12Bytes = null;
          _nombreArchivo = null;
          _passCtrl.clear();
        });
      }
    } on FirmaException catch (e) {
      setState(() => _errorSubida = e.mensaje);
    } catch (e) {
      setState(() => _errorSubida = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _eliminarCertificado() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar certificado'),
        content: const Text(
            '¿Seguro que deseas eliminar el certificado digital? '
                'Los modelos fiscales dejarán de poder firmarse automáticamente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              style:
              ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (confirmar != true) return;
    await _svc.eliminarCertificado();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Certificado eliminado'), backgroundColor: Colors.red));
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Certificado digital'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEstadoActual(),
          const SizedBox(height: 20),
          _buildFormSubida(),
          const SizedBox(height: 20),
          _buildHistorial(),
        ],
      ),
    );
  }

  // ─── Estado actual ─────────────────────────────────────────────────────────

  Widget _buildEstadoActual() {
    return StreamBuilder<CertificadoDigitalMeta?>(
      stream: _svc.metaStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final meta = snap.data;
        if (meta == null) {
          return _buildCardEstado(
            icon: '❌',
            titulo: 'Sin certificado digital',
            descripcion:
            'Sube tu certificado FNMT para firmar automáticamente los modelos fiscales.',
            color: Colors.orange.shade700,
            bgColor: Colors.orange.shade50,
            actions: [],
          );
        }

        final estado = meta.estado;
        return _buildCardEstado(
          icon: _iconForEstado(estado),
          titulo: _tituloForEstado(estado, meta),
          descripcion: _descForEstado(estado, meta),
          color: _colorForEstado(estado),
          bgColor: _bgColorForEstado(estado),
          actions: [
            TextButton.icon(
              onPressed: _eliminarCertificado,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
          extra: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 16),
              _infoRow('Titular', meta.titular),
              _infoRow('Emisor', meta.emisor),
              if (meta.nif != null) _infoRow('NIF', meta.nif!),
              _infoRow('N° serie', meta.numeroDeSerie),
              _infoRow('Válido desde', _fmtDate(meta.validoDesde)),
              _infoRow('Válido hasta', _fmtDate(meta.validoHasta)),
              _infoRow('Subido', _fmtDate(meta.fechaSubida)),
              if (meta.nombreArchivo != null)
                _infoRow('Archivo', meta.nombreArchivo!),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardEstado({
    required String icon,
    required String titulo,
    required String descripcion,
    required Color color,
    required Color bgColor,
    required List<Widget> actions,
    Widget? extra,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(icon, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(descripcion,
                          style: TextStyle(
                              fontSize: 11,
                              color: color.withOpacity(0.8))),
                    ],
                  ),
                ),
              ],
            ),
            if (extra != null) extra,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Formulario subida ─────────────────────────────────────────────────────

  Widget _buildFormSubida() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subir nuevo certificado',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey.shade800)),
              const SizedBox(height: 4),
              Text(
                  'Archivo PKCS#12 (.p12 / .pfx) con clave privada RSA.',
                  style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              const SizedBox(height: 14),

              // Selector de archivo
              OutlinedButton.icon(
                onPressed: _procesando ? null : _seleccionarArchivo,
                icon: const Icon(Icons.attach_file),
                label: Text(_nombreArchivo ?? 'Seleccionar archivo .p12 / .pfx'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),

              const SizedBox(height: 12),

              // Campo contraseña
              TextFormField(
                controller: _passCtrl,
                obscureText: !_verPass,
                decoration: InputDecoration(
                  labelText: 'Contraseña del certificado',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _verPass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _verPass = !_verPass),
                  ),
                ),
                validator: (v) =>
                (v == null || v.isEmpty) ? 'Introduce la contraseña' : null,
              ),

              // Error
              if (_errorSubida != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_errorSubida!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.red))),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              ElevatedButton.icon(
                onPressed: _procesando ? null : _subirCertificado,
                icon: _procesando
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.upload_outlined),
                label: Text(
                    _procesando ? 'Validando...' : 'Subir certificado'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Historial ─────────────────────────────────────────────────────────────

  Widget _buildHistorial() {
    return FutureBuilder<List<CertificadoDigitalMeta>>(
      future: _svc.obtenerHistorial(),
      builder: (context, snap) {
        final historial = snap.data ?? [];
        if (historial.isEmpty) return const SizedBox.shrink();

        return Card(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historial de certificados',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey.shade700)),
                const SizedBox(height: 8),
                ...historial.asMap().entries.map((e) {
                  final i = e.key;
                  final h = e.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: i == 0
                          ? Colors.teal.shade100
                          : Colors.grey.shade200,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 12,
                              color: i == 0
                                  ? Colors.teal.shade700
                                  : Colors.grey.shade600)),
                    ),
                    title: Text(
                      h.titular.length > 40
                          ? '${h.titular.substring(0, 40)}…'
                          : h.titular,
                      style: const TextStyle(fontSize: 12),
                    ),
                    subtitle: Text(
                        'Subido: ${_fmtDate(h.fechaSubida)} · '
                            'Expira: ${_fmtDate(h.validoHasta)}',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                    trailing: i == 0
                        ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Activo',
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.teal.shade700)),
                    )
                        : null,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  String _iconForEstado(EstadoCertDigital e) {
    switch (e) {
      case EstadoCertDigital.valido:
        return '✅';
      case EstadoCertDigital.proximoAExpirar:
        return '⚠️';
      case EstadoCertDigital.expirado:
        return '🔴';
      default:
        return '❌';
    }
  }

  String _tituloForEstado(EstadoCertDigital e, CertificadoDigitalMeta m) {
    switch (e) {
      case EstadoCertDigital.valido:
        return 'Certificado válido';
      case EstadoCertDigital.proximoAExpirar:
        return 'Expira en ${m.diasParaExpirar} días';
      case EstadoCertDigital.expirado:
        return 'Certificado expirado';
      default:
        return 'Sin certificado';
    }
  }

  String _descForEstado(EstadoCertDigital e, CertificadoDigitalMeta m) {
    switch (e) {
      case EstadoCertDigital.valido:
        return 'Expira el ${_fmtDate(m.validoHasta)}';
      case EstadoCertDigital.proximoAExpirar:
        return 'Renueve el certificado antes del ${_fmtDate(m.validoHasta)}';
      case EstadoCertDigital.expirado:
        return 'Expiró el ${_fmtDate(m.validoHasta)}. Suba uno nuevo.';
      default:
        return '';
    }
  }

  Color _colorForEstado(EstadoCertDigital e) {
    switch (e) {
      case EstadoCertDigital.valido:
        return Colors.green.shade700;
      case EstadoCertDigital.proximoAExpirar:
        return Colors.orange.shade700;
      case EstadoCertDigital.expirado:
        return Colors.red.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  Color _bgColorForEstado(EstadoCertDigital e) {
    switch (e) {
      case EstadoCertDigital.valido:
        return Colors.green.shade50;
      case EstadoCertDigital.proximoAExpirar:
        return Colors.orange.shade50;
      case EstadoCertDigital.expirado:
        return Colors.red.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  static String _fmtDate(DateTime d) =>
      DateFormat('dd/MM/yyyy').format(d);
}
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/fluix_app_bar.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA CONFIGURACIÓN VERIFACTU
// Gestiona certificado digital, entorno y parámetros del sistema de facturación.
//
// Datos guardados:
//  empresas/{id}/configuracion/certificado_verifactu
//    { p12Base64, password, fecha_subida, nombre_archivo }
//  config/verifactu
//    { entorno: "pruebas" | "produccion" }
//  empresas/{id}/configuracion/verifactu
//    { nif_emisor, nombre_emisor, nif_fabricante, id_software,
//      nombre_software, version_software, habilitado }
// ═══════════════════════════════════════════════════════════════════════════════

class SubirCertificadoVerifactuScreen extends StatefulWidget {
  final String empresaId;
  const SubirCertificadoVerifactuScreen({super.key, required this.empresaId});
  @override
  State<SubirCertificadoVerifactuScreen> createState() =>
      _SubirCertificadoVerifactuScreenState();
}

class _SubirCertificadoVerifactuScreenState
    extends State<SubirCertificadoVerifactuScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // ── Estado certificado ────────────────────────────────────────────────────
  bool _tieneExistente = false;
  DateTime? _fechaSubida;
  String? _nombreArchivoExistente;
  String? _nombreArchivoNuevo;
  String? _p12Base64Nuevo;
  bool _subiendo = false;
  bool _eliminando = false;
  final _passCtrl = TextEditingController();
  bool _passVisible = false;

  // ── Config Verifactu ──────────────────────────────────────────────────────
  bool _habilitado = false;
  final _nifEmisorCtrl    = TextEditingController();
  final _nombreEmisorCtrl = TextEditingController();
  final _nifFabCtrl       = TextEditingController();
  final _idSwCtrl         = TextEditingController(text: 'FLUIXCRM-001');
  final _nomSwCtrl        = TextEditingController(text: 'Fluix CRM');
  final _verSwCtrl        = TextEditingController(text: '1.0.0');
  bool _guardandoConfig = false;

  // ── Entorno ───────────────────────────────────────────────────────────────
  String _entorno = 'pruebas'; // 'pruebas' | 'produccion'
  bool _guardandoEntorno = false;

  static const _kBlue   = Color(0xFF3B82F6);
  static const _kGreen  = Color(0xFF10B981);
  static const _kOrange = Color(0xFFF59E0B);
  static const _kRed    = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tab.dispose();
    _passCtrl.dispose();
    _nifEmisorCtrl.dispose();
    _nombreEmisorCtrl.dispose();
    _nifFabCtrl.dispose();
    _idSwCtrl.dispose();
    _nomSwCtrl.dispose();
    _verSwCtrl.dispose();
    super.dispose();
  }

  // ── Carga inicial ──────────────────────────────────────────────────────────

  Future<void> _cargarTodo() async {
    await Future.wait([
      _cargarCertificado(),
      _cargarConfigVerifactu(),
      _cargarEntorno(),
    ]);
  }

  Future<void> _cargarCertificado() async {
    final doc = await FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('configuracion').doc('certificado_verifactu').get();
    if (!doc.exists || !mounted) return;
    final d = doc.data()!;
    setState(() {
      _tieneExistente = true;
      final ts = d['fecha_subida'];
      if (ts is Timestamp) _fechaSubida = ts.toDate();
      _nombreArchivoExistente = d['nombre_archivo'] as String?;
    });
  }

  Future<void> _cargarConfigVerifactu() async {
    final doc = await FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('configuracion').doc('verifactu').get();
    if (!doc.exists || !mounted) return;
    final d = doc.data()!;
    setState(() {
      _habilitado          = d['habilitado'] == true;
      _nifEmisorCtrl.text  = d['nif_emisor']    as String? ?? '';
      _nombreEmisorCtrl.text = d['nombre_emisor'] as String? ?? '';
      _nifFabCtrl.text     = d['nif_fabricante'] as String? ?? '';
      _idSwCtrl.text       = d['id_software']    as String? ?? 'FLUIXCRM-001';
      _nomSwCtrl.text      = d['nombre_software']  as String? ?? 'Fluix CRM';
      _verSwCtrl.text      = d['version_software'] as String? ?? '1.0.0';
    });
  }

  Future<void> _cargarEntorno() async {
    final doc = await FirebaseFirestore.instance
        .collection('config').doc('verifactu').get();
    if (!doc.exists || !mounted) return;
    final e = doc.data()?['entorno'] as String? ?? 'pruebas';
    setState(() => _entorno = e);
  }

  // ── Acciones certificado ───────────────────────────────────────────────────

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['p12', 'pfx'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    setState(() {
      _nombreArchivoNuevo = result.files.single.name;
      _p12Base64Nuevo     = base64Encode(result.files.single.bytes!);
    });
  }

  Future<void> _subirCertificado() async {
    if (_p12Base64Nuevo == null) {
      _snack('Selecciona un archivo .p12 o .pfx primero', error: true);
      return;
    }
    if (_passCtrl.text.trim().isEmpty) {
      _snack('Introduce la contraseña del certificado', error: true);
      return;
    }
    setState(() => _subiendo = true);
    try {
      await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('configuracion').doc('certificado_verifactu')
          .set({
        'p12Base64':    _p12Base64Nuevo,
        'password':     _passCtrl.text.trim(),
        'fecha_subida': FieldValue.serverTimestamp(),
        'nombre_archivo': _nombreArchivoNuevo,
      });
      if (mounted) {
        _snack('Certificado subido correctamente');
        setState(() {
          _tieneExistente         = true;
          _fechaSubida            = DateTime.now();
          _nombreArchivoExistente = _nombreArchivoNuevo;
          _p12Base64Nuevo         = null;
          _nombreArchivoNuevo     = null;
          _passCtrl.clear();
        });
      }
    } catch (e) {
      _snack('Error al subir: $e', error: true);
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  Future<void> _eliminarCertificado() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar certificado'),
        content: const Text(
            'Si eliminas el certificado no podrás firmar ni enviar facturas a la AEAT hasta subir uno nuevo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _eliminando = true);
    try {
      await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('configuracion').doc('certificado_verifactu')
          .delete();
      if (mounted) {
        _snack('Certificado eliminado');
        setState(() {
          _tieneExistente         = false;
          _fechaSubida            = null;
          _nombreArchivoExistente = null;
        });
      }
    } catch (e) {
      _snack('Error al eliminar: $e', error: true);
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  // ── Acciones config ────────────────────────────────────────────────────────

  Future<void> _guardarConfigVerifactu() async {
    if (_nifEmisorCtrl.text.trim().isEmpty || _nombreEmisorCtrl.text.trim().isEmpty) {
      _snack('NIF y nombre del emisor son obligatorios', error: true);
      return;
    }
    setState(() => _guardandoConfig = true);
    try {
      await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('configuracion').doc('verifactu')
          .set({
        'nif_emisor':     _nifEmisorCtrl.text.trim().toUpperCase(),
        'nombre_emisor':  _nombreEmisorCtrl.text.trim(),
        'nif_fabricante': _nifFabCtrl.text.trim().toUpperCase(),
        'id_software':    _idSwCtrl.text.trim(),
        'nombre_software':  _nomSwCtrl.text.trim(),
        'version_software': _verSwCtrl.text.trim(),
        'habilitado':     _habilitado,
      }, SetOptions(merge: true));
      if (mounted) _snack('Configuración guardada');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardandoConfig = false);
    }
  }

  // ── Acciones entorno ───────────────────────────────────────────────────────

  Future<void> _cambiarEntorno(String nuevo) async {
    if (nuevo == 'produccion') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Activar entorno de Producción'),
          content: const Text(
              'En producción las facturas se registran REALMENTE en la AEAT. '
              'Solo actívalo cuando tu sistema esté listo y hayas probado en el entorno de pruebas.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kOrange),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Entiendo, activar producción'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }
    setState(() { _guardandoEntorno = true; _entorno = nuevo; });
    try {
      await FirebaseFirestore.instance
          .collection('config').doc('verifactu')
          .set({'entorno': nuevo}, SetOptions(merge: true));
      if (mounted) _snack('Entorno cambiado a ${nuevo == 'produccion' ? 'Producción' : 'Pruebas'}');
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _guardandoEntorno = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? _kRed : _kGreen,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg      = dark ? const Color(0xFF0A0F1E) : const Color(0xFFF8FAFC);
    final surface = dark ? const Color(0xFF111827) : Colors.white;
    final border  = dark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final text     = dark ? Colors.white : const Color(0xFF111827);
    final sub      = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: bg,
      appBar: const FluixAppBar(titulo: 'Verifactu', showLeading: true),
      body: Column(children: [
        TabBar(
          controller: _tab,
          labelColor: _kBlue,
          unselectedLabelColor: sub,
          indicatorColor: _kBlue,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Certificado'),
            Tab(icon: Icon(Icons.settings_outlined, size: 18), text: 'Configuración'),
            Tab(icon: Icon(Icons.swap_horiz_rounded, size: 18), text: 'Entorno'),
          ],
        ),
        Expanded(child: TabBarView(
          controller: _tab,
          children: [
            _tabCertificado(surface, border, text, sub, dark),
            _tabConfiguracion(surface, border, text, sub, dark),
            _tabEntorno(surface, border, text, sub, dark),
          ],
        )),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TAB 1: Certificado
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _tabCertificado(Color surface, Color border, Color text, Color sub, bool dark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Estado actual
        _buildCertStatus(surface, border, text, sub, dark),
        const SizedBox(height: 16),

        // Info
        _card(
          surface: surface, border: border,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.info_outline_rounded, color: _kBlue, size: 16),
              const SizedBox(width: 8),
              Text('¿Qué necesitas?', style: TextStyle(fontWeight: FontWeight.w700, color: text, fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            Text(
              'Un certificado digital en formato .p12 o .pfx emitido por una CA reconocida por la AEAT.\n\n'
              '• FNMT — www.cert.fnmt.es (recomendado)\n'
              '• AC Camerfirma\n'
              '• Firmaprofesional\n'
              '• DNIe (con lector de tarjetas)',
              style: TextStyle(fontSize: 12.5, color: sub, height: 1.5),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Selector archivo
        GestureDetector(
          onTap: _seleccionarArchivo,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _p12Base64Nuevo != null
                  ? _kGreen.withValues(alpha: dark ? 0.1 : 0.06)
                  : surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _p12Base64Nuevo != null
                    ? _kGreen.withValues(alpha: 0.4)
                    : _kBlue.withValues(alpha: 0.3),
                width: 1.5,
                style: BorderStyle.solid,
              ),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: (_p12Base64Nuevo != null ? _kGreen : _kBlue).withValues(alpha: dark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _p12Base64Nuevo != null ? Icons.check_circle_outline : Icons.upload_file_rounded,
                  color: _p12Base64Nuevo != null ? _kGreen : _kBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _nombreArchivoNuevo ?? 'Seleccionar archivo .p12 / .pfx',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _nombreArchivoNuevo != null ? text : _kBlue,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _p12Base64Nuevo != null ? 'Listo para subir' : 'Toca para abrir el selector',
                  style: TextStyle(fontSize: 11.5, color: sub),
                ),
              ])),
              Icon(Icons.chevron_right_rounded, color: sub, size: 20),
            ]),
          ),
        ),
        const SizedBox(height: 12),

        // Contraseña
        TextField(
          controller: _passCtrl,
          obscureText: !_passVisible,
          style: TextStyle(color: text, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Contraseña del certificado',
            hintText: 'La contraseña que usaste al exportar',
            labelStyle: TextStyle(color: sub, fontSize: 13),
            hintStyle: TextStyle(color: sub, fontSize: 13),
            filled: true,
            fillColor: surface,
            prefixIcon: Icon(Icons.lock_outline_rounded, color: sub, size: 18),
            suffixIcon: IconButton(
              icon: Icon(_passVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: sub, size: 18),
              onPressed: () => setState(() => _passVisible = !_passVisible),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kBlue, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          ),
        ),
        const SizedBox(height: 16),

        // Botón subir
        FilledButton.icon(
          onPressed: (_subiendo || _p12Base64Nuevo == null) ? null : _subirCertificado,
          icon: _subiendo
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.cloud_upload_outlined, size: 18),
          label: Text(_subiendo ? 'Subiendo...' : 'Subir certificado',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            backgroundColor: _kBlue,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),

        // Aviso seguridad
        _card(
          surface: _kOrange.withValues(alpha: dark ? 0.08 : 0.05),
          border: _kOrange.withValues(alpha: 0.25),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.shield_outlined, color: _kOrange, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'El certificado se almacena en Firestore y solo las Cloud Functions '
              'de tu proyecto pueden leerlo. Nunca se envía al cliente. '
              'Protege tu archivo .p12 y su contraseña.',
              style: TextStyle(fontSize: 12, color: _kOrange.withValues(alpha: 0.9), height: 1.4),
            )),
          ]),
        ),
      ],
    );
  }

  Widget _buildCertStatus(Color surface, Color border, Color text, Color sub, bool dark) {
    if (_tieneExistente) {
      final fecha = _fechaSubida != null
          ? '${_fechaSubida!.day}/${_fechaSubida!.month}/${_fechaSubida!.year}'
          : 'Fecha desconocida';
      return _card(
        surface: _kGreen.withValues(alpha: dark ? 0.08 : 0.05),
        border: _kGreen.withValues(alpha: 0.3),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: dark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_rounded, color: _kGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Certificado activo', style: TextStyle(fontWeight: FontWeight.w700,
                color: _kGreen, fontSize: 13.5)),
            const SizedBox(height: 2),
            Text(
              '${_nombreArchivoExistente ?? 'archivo.p12'} · Subido el $fecha',
              style: TextStyle(fontSize: 11.5, color: _kGreen.withValues(alpha: 0.8)),
            ),
          ])),
          IconButton(
            icon: _eliminando
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                : const Icon(Icons.delete_outline_rounded, color: _kRed, size: 20),
            tooltip: 'Eliminar certificado',
            onPressed: _eliminando ? null : _eliminarCertificado,
          ),
        ]),
      );
    }
    return _card(
      surface: _kOrange.withValues(alpha: dark ? 0.08 : 0.05),
      border: _kOrange.withValues(alpha: 0.3),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: _kOrange.withValues(alpha: dark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.warning_amber_rounded, color: _kOrange, size: 22),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Sin certificado', style: TextStyle(fontWeight: FontWeight.w700,
              color: _kOrange, fontSize: 13.5)),
          Text('Sube tu .p12 para poder firmar facturas',
              style: TextStyle(fontSize: 11.5, color: _kOrange.withValues(alpha: 0.8))),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TAB 2: Configuración
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _tabConfiguracion(Color surface, Color border, Color text, Color sub, bool dark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Toggle habilitado
        _card(surface: surface, border: border, child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: (_habilitado ? _kGreen : sub).withValues(alpha: dark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.toggle_on_rounded,
                color: _habilitado ? _kGreen : sub, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Verifactu habilitado', style: TextStyle(fontWeight: FontWeight.w700,
                color: text, fontSize: 13.5)),
            Text(
              _habilitado
                  ? 'Las facturas se registrarán automáticamente'
                  : 'Activa para registrar facturas en la AEAT',
              style: TextStyle(fontSize: 11.5, color: sub),
            ),
          ])),
          Switch(value: _habilitado, onChanged: (v) => setState(() => _habilitado = v),
              activeColor: _kGreen),
        ])),
        const SizedBox(height: 16),

        // Datos emisor
        _sectionTitle('Datos del emisor', Icons.business_outlined, text),
        const SizedBox(height: 8),
        _field(_nifEmisorCtrl, 'NIF / CIF del emisor', 'B12345678',
            TextInputType.text, surface, border, text, sub,
            upperCase: true),
        const SizedBox(height: 10),
        _field(_nombreEmisorCtrl, 'Razón social / Nombre', 'Mi Empresa S.L.',
            TextInputType.text, surface, border, text, sub),
        const SizedBox(height: 20),

        // Datos software (obligatorios por ley)
        _sectionTitle('Identificación del software (HAC/1177/2024)', Icons.code_rounded, text),
        const SizedBox(height: 4),
        _infoText('Estos datos deben coincidir exactamente con los registrados en la AEAT.', sub),
        const SizedBox(height: 10),
        _field(_nifFabCtrl, 'NIF del fabricante del software', 'Tu NIF personal',
            TextInputType.text, surface, border, text, sub,
            upperCase: true),
        const SizedBox(height: 10),
        _field(_idSwCtrl, 'ID del sistema informático', 'FLUIXCRM-001',
            TextInputType.text, surface, border, text, sub),
        const SizedBox(height: 10),
        _field(_nomSwCtrl, 'Nombre del software', 'Fluix CRM',
            TextInputType.text, surface, border, text, sub),
        const SizedBox(height: 10),
        _field(_verSwCtrl, 'Versión', '1.0.0',
            TextInputType.text, surface, border, text, sub),
        const SizedBox(height: 20),

        // Botón guardar
        FilledButton.icon(
          onPressed: _guardandoConfig ? null : _guardarConfigVerifactu,
          icon: _guardandoConfig
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_guardandoConfig ? 'Guardando...' : 'Guardar configuración',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            backgroundColor: _kBlue,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TAB 3: Entorno
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _tabEntorno(Color surface, Color border, Color text, Color sub, bool dark) {
    final esProd = _entorno == 'produccion';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Estado actual
        _card(
          surface: (esProd ? _kRed : _kBlue).withValues(alpha: dark ? 0.08 : 0.05),
          border: (esProd ? _kRed : _kBlue).withValues(alpha: 0.3),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: (esProd ? _kRed : _kBlue).withValues(alpha: dark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                esProd ? Icons.public_rounded : Icons.science_outlined,
                color: esProd ? _kRed : _kBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                esProd ? 'Producción (REAL)' : 'Pruebas (Test)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                    color: esProd ? _kRed : _kBlue),
              ),
              Text(
                esProd
                    ? 'Las facturas se registran en la AEAT real'
                    : 'Usando el entorno de pre-producción de la AEAT',
                style: TextStyle(fontSize: 12, color: sub),
              ),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        _sectionTitle('Seleccionar entorno', Icons.swap_horiz_rounded, text),
        const SizedBox(height: 12),

        // Opción Pruebas
        _entornoCard(
          id: 'pruebas',
          title: 'Pruebas',
          subtitle: 'Pre-producción AEAT\nprewww2.aeat.es',
          icon: Icons.science_outlined,
          color: _kBlue,
          surface: surface, border: border, text: text, sub: sub, dark: dark,
        ),
        const SizedBox(height: 10),

        // Opción Producción
        _entornoCard(
          id: 'produccion',
          title: 'Producción',
          subtitle: 'AEAT real\nwww2.aeat.es',
          icon: Icons.public_rounded,
          color: _kRed,
          surface: surface, border: border, text: text, sub: sub, dark: dark,
        ),
        const SizedBox(height: 20),

        // Warning producción
        if (!esProd)
          _card(
            surface: _kOrange.withValues(alpha: dark ? 0.08 : 0.05),
            border: _kOrange.withValues(alpha: 0.25),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded, color: _kOrange, size: 18),
                const SizedBox(width: 8),
                Text('Antes de pasar a Producción',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: _kOrange, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              Text(
                '1. Comprueba que el hash encadenado funciona correctamente en pruebas.\n'
                '2. Verifica que la AEAT acepta tus facturas de prueba (estado "Correcto").\n'
                '3. Confirma con tu gestor fiscal que todo está configurado.\n'
                '4. Asegúrate de tener el NIF fabricante registrado en la AEAT.',
                style: TextStyle(fontSize: 12.5, color: _kOrange.withValues(alpha: 0.9), height: 1.5),
              ),
            ]),
          ),

        if (esProd)
          _card(
            surface: _kRed.withValues(alpha: dark ? 0.08 : 0.05),
            border: _kRed.withValues(alpha: 0.3),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded, color: _kRed, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Estás en producción. Cada factura enviada se registra '
                'oficialmente en la Agencia Tributaria.',
                style: const TextStyle(fontSize: 12.5, color: _kRed, height: 1.4),
              )),
            ]),
          ),
      ],
    );
  }

  Widget _entornoCard({
    required String id, required String title, required String subtitle,
    required IconData icon, required Color color,
    required Color surface, required Color border,
    required Color text, required Color sub, required bool dark,
  }) {
    final sel = _entorno == id;
    return GestureDetector(
      onTap: _guardandoEntorno ? null : () => _cambiarEntorno(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: dark ? 0.12 : 0.06) : surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel ? color.withValues(alpha: dark ? 0.5 : 0.4) : border,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: dark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: sel ? color : text, fontSize: 13.5)),
            Text(subtitle, style: TextStyle(fontSize: 11.5, color: sub, height: 1.4)),
          ])),
          if (_guardandoEntorno && sel)
            const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else if (sel)
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
            )
          else
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, border: Border.all(color: border, width: 1.5)),
            ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Helpers UI
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _card({required Widget child, required Color surface, required Color border}) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: child,
      );

  Widget _sectionTitle(String label, IconData icon, Color text) => Row(children: [
    Icon(icon, size: 15, color: text.withValues(alpha: 0.6)),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text.withValues(alpha: 0.7))),
  ]);

  Widget _infoText(String msg, Color sub) => Text(msg,
      style: TextStyle(fontSize: 12, color: sub, height: 1.4));

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint,
    TextInputType keyType,
    Color surface,
    Color border,
    Color text,
    Color sub, {
    bool upperCase = false,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyType,
        style: TextStyle(color: text, fontSize: 13.5),
        inputFormatters: upperCase
            ? [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
               _UpperCaseFormatter()]
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: sub, fontSize: 12.5),
          hintStyle: TextStyle(color: sub, fontSize: 12.5),
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kBlue, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          isDense: true,
        ),
      );
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) =>
      next.copyWith(text: next.text.toUpperCase(),
          selection: next.selection);
}

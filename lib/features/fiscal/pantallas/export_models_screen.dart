import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'modelo130_screen.dart';
import 'modelo349_screen.dart';
import 'modelo303_screen.dart';
import 'modelo111_screen.dart';
import 'modelo115_screen.dart';
import 'modelo202_screen.dart';
import 'modelo390_screen.dart';
import 'modelo190_screen.dart';
import 'modelo180_screen.dart';
import 'modelo347_screen.dart';
import 'subir_certificado_verifactu_screen.dart';
import 'calendario_fiscal_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// EXPORT MODELS SCREEN — Wizard unificado para los 8 modelos AEAT
// ═════════════════════════════════════════════════════════════════════════════

class ExportModelsScreen extends StatefulWidget {
  final String empresaId;

  const ExportModelsScreen({super.key, required this.empresaId});

  @override
  State<ExportModelsScreen> createState() => _ExportModelsScreenState();
}

class _ExportModelsScreenState extends State<ExportModelsScreen> {
  String _periodo = '';
  bool _tienePack = false;
  bool _cargando = true;
  // Cache de estados guardados en modelos_fiscales/
  Map<String, String> _estados = {};
  // Cache de URLs PDF oficiales AEAT
  Map<String, String> _pdfUrls = {};

  static const _modelosTrimestrales = [
    _ModeloInfo('303', 'IVA trimestral', Icons.receipt_long, Colors.blue),
    _ModeloInfo('111', 'Retenciones IRPF', Icons.people, Colors.purple),
    _ModeloInfo('115', 'Retenciones alquileres', Icons.home_work, Colors.teal),
    _ModeloInfo('130', 'Pago fraccionado IRPF (autónomos)', Icons.person_outline, Colors.orange),
    _ModeloInfo('202', 'Pagos fraccionados IS', Icons.business_center, Colors.indigo),
    _ModeloInfo('349', 'Operaciones intracomunitarias', Icons.public, Colors.green),
  ];

  static const _modelosAnuales = [
    _ModeloInfo('390', 'Resumen anual IVA', Icons.summarize, Colors.blue),
    _ModeloInfo('190', 'Resumen retenciones IRPF', Icons.group, Colors.purple),
    _ModeloInfo('180', 'Resumen retenciones alquileres', Icons.home, Colors.teal),
    _ModeloInfo('347', 'Operaciones con terceros', Icons.swap_horiz, Colors.orange),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final q = ((now.month - 1) ~/ 3) + 1;
    _periodo = '${now.year}-Q$q';
    _verificarPack();
  }

  Future<void> _verificarPack() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .get();
      final packs = (doc.data()?['active_packs'] as List? ?? []).cast<String>();
      setState(() {
        _tienePack = packs.contains('fiscal_ai');
        _cargando = false;
      });
      if (_tienePack) _cargarEstados();
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _cargarEstados() async {
    final snap = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('modelos_fiscales')
        .get();
    final map = <String, String>{};
    final pdfMap = <String, String>{};
    for (final doc in snap.docs) {
      final estado = doc.data()['estado'] as String? ?? 'calculado';
      map[doc.id] = estado;
      final url = doc.data()['pdf_justificante_url'] as String?;
      if (url != null && url.isNotEmpty) pdfMap[doc.id] = url;
    }
    if (mounted) setState(() { _estados = map; _pdfUrls = pdfMap; });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modelos AEAT'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.event_note_outlined),
            tooltip: 'Calendario Fiscal',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CalendarioFiscalScreen(empresaId: widget.empresaId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.verified_user_outlined),
            tooltip: 'Certificado VeriFactu',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SubirCertificadoVerifactuScreen(
                    empresaId: widget.empresaId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar estados',
            onPressed: _cargarEstados,
          ),
        ],
      ),
      body: !_tienePack
          ? _buildSinPack()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPeriodoSelector(),
                const SizedBox(height: 24),
                _buildSeccion('TRIMESTRALES', _modelosTrimestrales),
                const SizedBox(height: 24),
                _buildSeccion('ANUALES', _modelosAnuales),
                const SizedBox(height: 32),
                _buildPrevisionCalendario(),
              ],
            ),
    );
  }

  Widget _buildSinPack() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'Pack Fiscal IA no activo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Activa el Pack Fiscal para acceder al cálculo automático de modelos AEAT.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodoSelector() {
    final anio = DateTime.now().year;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Período activo',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int q = 1; q <= 4; q++)
                  _chipPeriodo('$anio-Q$q', '${q}T $anio'),
                _chipPeriodo('$anio', 'Anual $anio'),
                _chipPeriodo('${anio - 1}', 'Anual ${anio - 1}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipPeriodo(String value, String label) {
    final selected = _periodo == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _periodo = value),
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }

  Widget _buildSeccion(
      String titulo, List<_ModeloInfo> modelos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            titulo,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...modelos.map((m) => _buildModelCard(m)),
      ],
    );
  }

  Widget _buildModelCard(_ModeloInfo m) {
    final isAnual = !_periodo.contains('-Q');
    final modelIsAnual = ['390', '190', '180', '347'].contains(m.code);
    final activo = isAnual == modelIsAnual;

    // Buscar estado guardado para este modelo+período
    final periodoKey = _periodo.replaceAll('-Q', '_').replaceAll('-', '_');
    final docId = '${m.code}_$periodoKey';
    final estado = _estados[docId];
    final pdfUrl = _pdfUrls[docId];

    Color? estadoColor;
    IconData? estadoIcon;
    String? estadoLabel;
    if (estado == 'presentado') {
      estadoColor = Colors.green;
      estadoIcon = Icons.check_circle;
      estadoLabel = 'Presentado';
    } else if (estado == 'calculado') {
      estadoColor = Colors.orange;
      estadoIcon = Icons.pending_actions;
      estadoLabel = 'Calculado';
    }

    return Opacity(
      opacity: activo ? 1.0 : 0.45,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: m.color.withValues(alpha: 0.15),
                child: Text(
                  m.code,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: m.color),
                ),
              ),
              title: Text('Modelo ${m.code}',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(m.nombre),
              trailing: estadoLabel != null
                  ? _buildBadge(estadoLabel, estadoColor!, estadoIcon!)
                  : const Icon(Icons.chevron_right),
              onTap: activo ? () => _abrirModelo(m.code) : null,
            ),
            // ── Fila PDF justificante ────────────────────────────────────
            if (activo) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf,
                        size: 16,
                        color: pdfUrl != null ? Colors.red : Colors.grey[400]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        pdfUrl != null
                            ? 'Justificante AEAT adjunto'
                            : 'Sin justificante de presentación',
                        style: TextStyle(
                          fontSize: 11,
                          color: pdfUrl != null
                              ? Colors.red[700]
                              : Colors.grey[500],
                        ),
                      ),
                    ),
                    if (pdfUrl != null) ...[
                      TextButton.icon(
                        onPressed: () => _verPdf(pdfUrl),
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('Ver', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => _subirPdfOficial(docId),
                      icon: const Icon(Icons.upload_file, size: 14),
                      label: Text(
                        pdfUrl != null ? 'Reemplazar' : 'Subir PDF',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Future<void> _subirPdfOficial(String docId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      dialogTitle: 'Seleccionar justificante PDF de AEAT',
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    try {
      final ref = FirebaseStorage.instance
          .ref('empresas/${widget.empresaId}/modelos_fiscales/$docId.pdf');
      await ref.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('modelos_fiscales')
          .doc(docId)
          .set({
        'pdf_justificante_url': url,
        'pdf_subido_en': FieldValue.serverTimestamp(),
        'estado': 'presentado',
      }, SetOptions(merge: true));

      await _cargarEstados();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Justificante PDF subido y modelo marcado como presentado'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error subiendo PDF: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _verPdf(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _abrirModelo(String code) {
    final anio = int.tryParse(_periodo.split('-')[0]) ?? DateTime.now().year;

    Widget pantalla;
    switch (code) {
      case '130':
        pantalla = Modelo130Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '303':
        pantalla = Modelo303Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '111':
        pantalla = Modelo111Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '115':
        pantalla = Modelo115Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '202':
        pantalla = Modelo202Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '390':
        pantalla = Modelo390Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '190':
        pantalla = Modelo190Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '180':
        pantalla = Modelo180Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '347':
        pantalla = Modelo347Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      case '349':
        pantalla = Modelo349Screen(
            empresaId: widget.empresaId, anioInicial: anio);
      default:
        return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla))
        .then((_) => _cargarEstados()); // Recarga estados al volver
  }

  Widget _buildPrevisionCalendario() {
    final now = DateTime.now();
    final items = _plazos
        .where((p) => p.vencimiento.isAfter(now))
        .toList()
      ..sort((a, b) => a.vencimiento.compareTo(b.vencimiento));

    if (items.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'PRÓXIMOS PLAZOS',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.8,
            ),
          ),
        ),
        Card(
          child: Column(
            children: items.take(4).map((p) {
              final dias = p.vencimiento.difference(now).inDays;
              final urgente = dias <= 15;
              return ListTile(
                dense: true,
                leading: Icon(Icons.event,
                    color: urgente ? Colors.red : Colors.grey),
                title: Text(p.modelo),
                subtitle: Text(p.descripcion),
                trailing: Text(
                  DateFormat('dd/MM').format(p.vencimiento),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: urgente ? Colors.red : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static final List<_PlazoFiscal> _plazos = _generarPlazos();

  static List<_PlazoFiscal> _generarPlazos() {
    final anio = DateTime.now().year;
    return [
      _PlazoFiscal('303 / 111 / 115 · 1T', 'Presentación 1er trimestre',
          DateTime(anio, 4, 20)),
      _PlazoFiscal('303 / 111 / 115 · 2T', 'Presentación 2º trimestre',
          DateTime(anio, 7, 20)),
      _PlazoFiscal('303 / 111 / 115 · 3T', 'Presentación 3er trimestre',
          DateTime(anio, 10, 20)),
      _PlazoFiscal('303 / 111 / 115 · 4T', 'Presentación 4º trimestre',
          DateTime(anio, 1, 30).add(const Duration(days: 365))),
      _PlazoFiscal('390 / 190 / 180', 'Resumen anual $anio',
          DateTime(anio + 1, 1, 31)),
      _PlazoFiscal('347', 'Operaciones con terceros $anio',
          DateTime(anio + 1, 2, 28)),
    ];
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class _ModeloInfo {
  final String code;
  final String nombre;
  final IconData icon;
  final Color color;

  const _ModeloInfo(this.code, this.nombre, this.icon, this.color);
}

class _PlazoFiscal {
  final String modelo;
  final String descripcion;
  final DateTime vencimiento;

  const _PlazoFiscal(this.modelo, this.descripcion, this.vencimiento);
}




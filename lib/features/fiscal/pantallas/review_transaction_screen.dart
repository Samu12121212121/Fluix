import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// Pantalla de revisión humana de facturas en estado [needs_review].
/// Permite ver los datos extraídos por la IA, editarlos y confirmar/rechazar.
class ReviewTransactionScreen extends StatefulWidget {
  final String empresaId;
  final String transactionId;

  const ReviewTransactionScreen({
    super.key,
    required this.empresaId,
    required this.transactionId,
  });

  @override
  State<ReviewTransactionScreen> createState() =>
      _ReviewTransactionScreenState();
}

class _ReviewTransactionScreenState extends State<ReviewTransactionScreen> {
  Map<String, dynamic>? _tx;
  String? _documentUrl;
  bool _loading = true;
  bool _saving = false;

  // Controladores para campos editables
  late TextEditingController _invoiceNumberCtrl;
  late TextEditingController _supplierNameCtrl;
  late TextEditingController _supplierTaxIdCtrl;
  late TextEditingController _baseAmountCtrl;
  late TextEditingController _vatAmountCtrl;
  late TextEditingController _totalAmountCtrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('fiscal_transactions')
        .doc(widget.transactionId)
        .get();

    if (!doc.exists) {
      setState(() => _loading = false);
      return;
    }

    final tx = doc.data()!;

    _invoiceNumberCtrl =
        TextEditingController(text: tx['invoice_number'] ?? '');
    _supplierNameCtrl =
        TextEditingController(text: tx['counterparty']?['name'] ?? '');
    _supplierTaxIdCtrl =
        TextEditingController(text: tx['counterparty']?['tax_id'] ?? '');
    _baseAmountCtrl = TextEditingController(
        text: ((tx['base_amount_cents'] ?? 0) / 100).toStringAsFixed(2));
    _vatAmountCtrl = TextEditingController(
        text: ((tx['vat_amount_cents'] ?? 0) / 100).toStringAsFixed(2));
    _totalAmountCtrl = TextEditingController(
        text: ((tx['total_amount_cents'] ?? 0) / 100).toStringAsFixed(2));

    // Cargar URL del documento original
    final docId = tx['document_id'];
    if (docId != null) {
      try {
        final fiscalDoc = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('fiscal_documents')
            .doc(docId)
            .get();

        final storagePath = fiscalDoc.data()?['storage_path'];
        if (storagePath != null) {
          final url = await FirebaseStorage.instance
              .ref(storagePath)
              .getDownloadURL();
          setState(() => _documentUrl = url);
        }
      } catch (e) {
        debugPrint('Error cargando documento: $e');
      }
    }

    setState(() {
      _tx = tx;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_tx == null) {
      return const Scaffold(
        body: Center(child: Text('Factura no encontrada')),
      );
    }

    final tx = _tx!;
    final warnings =
        List<String>.from(tx['validation_warnings'] ?? []);
    final errors = List<String>.from(tx['validation_errors'] ?? []);
    final extractionWarnings =
        List<String>.from(tx['extraction_warnings'] ?? []);
    final vatScheme = tx['vat_scheme'] ?? 'standard';
    final tags = List<String>.from(tx['tax_tags'] ?? []);
    final convData =
        tx['original_currency_data'] as Map<String, dynamic>?;
    final withholdingCents = tx['withholding_amount_cents'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar factura'),
        actions: [
          if (!_saving)
            TextButton(
              onPressed: _onConfirm,
              child: const Text(
                'CONFIRMAR',
                style: TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── DOCUMENTO ORIGINAL ────────────────────────────
                if (_documentUrl != null) ...[
                  const Text('Documento original',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _verDocumentoCompleto,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _documentUrl!,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.picture_as_pdf, size: 60),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── ERRORES (rojo — bloquean) ─────────────────────
                if (errors.isNotEmpty)
                  _buildAlertCard(
                    '❌ Errores a corregir',
                    errors,
                    Colors.red.shade50,
                    Colors.red,
                  ),

                // ── WARNINGS (naranja — avisos) ───────────────────
                if (warnings.isNotEmpty || extractionWarnings.isNotEmpty)
                  _buildAlertCard(
                    '⚠️ Avisos',
                    [...warnings, ...extractionWarnings],
                    Colors.orange.shade50,
                    Colors.orange,
                  ),

                // ── CONVERSIÓN DE MONEDA ──────────────────────────
                if (convData != null) _buildCurrencyCard(convData),

                // ── PROVEEDOR ─────────────────────────────────────
                _buildSection('Proveedor', [
                  _buildEditableField('Nombre', _supplierNameCtrl),
                  _buildEditableField('NIF/CIF', _supplierTaxIdCtrl),
                  _buildReadonlyField(
                      'País', tx['counterparty']?['country'] ?? '—'),
                ]),

                // ── FACTURA ───────────────────────────────────────
                _buildSection('Factura', [
                  _buildEditableField('Nº Factura', _invoiceNumberCtrl),
                  _buildReadonlyField(
                      'Fecha', _formatDate(tx['invoice_date'])),
                  _buildReadonlyField(
                      'Período fiscal', tx['period'] ?? '—'),
                  _buildReadonlyField('Régimen IVA', vatScheme),
                ]),

                // ── IMPORTES ──────────────────────────────────────
                _buildSection('Importes', [
                  _buildEditableField('Base imponible (€)', _baseAmountCtrl,
                      isNumber: true),
                  _buildReadonlyField(
                      'Tipo IVA', '${tx['vat_rate'] ?? 0}%'),
                  _buildEditableField('Cuota IVA (€)', _vatAmountCtrl,
                      isNumber: true),
                  if (withholdingCents > 0)
                    _buildReadonlyField(
                      'Retención (${tx['withholding_rate']}%)',
                      '-${(withholdingCents / 100).toStringAsFixed(2)} €',
                    ),
                  _buildEditableField('TOTAL (€)', _totalAmountCtrl,
                      isNumber: true, bold: true),
                ]),

                // ── TAGS FISCALES ─────────────────────────────────
                if (tags.isNotEmpty) _buildTagsCard(tags),

                const SizedBox(height: 24),

                // ── BOTONES DE ACCIÓN ─────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _onReject,
                        icon:
                            const Icon(Icons.block, color: Colors.red),
                        label: const Text('Rechazar',
                            style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side:
                              const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _onSaveDraft,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _onConfirm,
                        icon: const Icon(Icons.check),
                        label: const Text('Confirmar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // ── WIDGETS HELPER ─────────────────────────────────────────────

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType:
            isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildReadonlyField(String label, String value,
      {bool warning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: warning ? Colors.orange : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(
      String title, List<String> items, Color bg, Color color) {
    return Card(
      color: bg,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            ...items.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber, size: 16, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(w,
                            style:
                                TextStyle(color: color, fontSize: 13)),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencyCard(Map<String, dynamic> conv) {
    return Card(
      color: Colors.blue.shade50,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('💱 Conversión de moneda',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                'Original: ${conv['original_total']} ${conv['original_currency']}'),
            Text(
                'Tipo BCE (${conv['rate_date']}): ${conv['exchange_rate']}'),
            Text('En EUR: ${conv['total_eur']} €',
                style:
                    const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsCard(List<String> tags) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏷️ Clasificación fiscal',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: tags
                  .map((tag) => Chip(
                        label: Text(tag,
                            style: const TextStyle(fontSize: 11)),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── ACCIONES ───────────────────────────────────────────────────

  Future<void> _onConfirm() async {
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final edits = _buildEdits();

      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('fiscal_transactions')
          .doc(widget.transactionId)
          .update({
        ...edits,
        'status': 'posted',
        'user_reviewed': true,
        'posted_at': FieldValue.serverTimestamp(),
        'posted_by': uid,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Factura confirmada y contabilizada'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, 'confirmed');
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _onSaveDraft() async {
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final edits = _buildEdits();

      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('fiscal_transactions')
          .doc(widget.transactionId)
          .update({
        ...edits,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': uid,
      });

      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Borrador guardado')),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _onReject() async {
    final motivo = await _pedirMotivo('Motivo del rechazo');
    if (motivo == null || motivo.isEmpty) return;

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('fiscal_transactions')
          .doc(widget.transactionId)
          .update({
        'status': 'voided',
        'voided_at': FieldValue.serverTimestamp(),
        'voided_by': uid,
        'void_reason': motivo,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Factura rechazada')),
        );
        Navigator.pop(context, 'rejected');
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Map<String, dynamic> _buildEdits() {
    final baseEur = double.tryParse(_baseAmountCtrl.text) ?? 0;
    final vatEur = double.tryParse(_vatAmountCtrl.text) ?? 0;
    final totalEur = double.tryParse(_totalAmountCtrl.text) ?? 0;

    return {
      'invoice_number': _invoiceNumberCtrl.text.trim(),
      'counterparty.name': _supplierNameCtrl.text.trim(),
      'counterparty.tax_id': _supplierTaxIdCtrl.text.trim(),
      'base_amount_cents': (baseEur * 100).round(),
      'vat_amount_cents': (vatEur * 100).round(),
      'total_amount_cents': (totalEur * 100).round(),
    };
  }

  Future<String?> _pedirMotivo(String titulo) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Describe el motivo...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(context, ctrl.text.trim());
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _verDocumentoCompleto() {
    if (_documentUrl == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Documento original')),
          body: InteractiveViewer(
            child: Image.network(_documentUrl!),
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic ts) {
    if (ts == null) return '—';
    try {
      final date = (ts as Timestamp).toDate();
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return '—';
    }
  }

  @override
  void dispose() {
    _invoiceNumberCtrl.dispose();
    _supplierNameCtrl.dispose();
    _supplierTaxIdCtrl.dispose();
    _baseAmountCtrl.dispose();
    _vatAmountCtrl.dispose();
    _totalAmountCtrl.dispose();
    super.dispose();
  }
}

/// Stream de facturas pendientes de revisión (para badge en menú).
Stream<int> watchNeedsReviewCount(String empresaId) {
  return FirebaseFirestore.instance
      .collection('empresas')
      .doc(empresaId)
      .collection('fiscal_transactions')
      .where('status', isEqualTo: 'needs_review')
      .snapshots()
      .map((snap) => snap.docs.length);
}


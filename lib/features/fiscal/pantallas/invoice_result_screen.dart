import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ═════════════════════════════════════════════════════════════════════════════
// INVOICE RESULT SCREEN
// Muestra el resultado completo del procesamiento IA de una factura.
// Permite detectar errores, ver campos extraídos, advertencias y
// en qué modelos AEAT contribuye cada dato.
// ═════════════════════════════════════════════════════════════════════════════

class InvoiceResultScreen extends StatefulWidget {
  final String empresaId;
  final String transactionId;

  /// Resultado directo devuelto por la CF (opcional: para acceso inmediato
  /// sin esperar a Firestore, se usa como fallback inicial).
  final Map<String, dynamic>? cfResult;

  const InvoiceResultScreen({
    super.key,
    required this.empresaId,
    required this.transactionId,
    this.cfResult,
  });

  @override
  State<InvoiceResultScreen> createState() => _InvoiceResultScreenState();
}

class _InvoiceResultScreenState extends State<InvoiceResultScreen> {
  final _db = FirebaseFirestore.instance;
  Map<String, dynamic>? _txData;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarTransaccion();
  }

  Future<void> _cargarTransaccion() async {
    try {
      final snap = await _db
          .doc('empresas/${widget.empresaId}/fiscal_transactions/${widget.transactionId}')
          .get();
      if (mounted) {
        setState(() {
          _txData = snap.data();
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado del procesamiento'),
        actions: [
          if (_txData != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recargar',
              onPressed: () {
                setState(() => _cargando = true);
                _cargarTransaccion();
              },
            ),
        ],
      ),
      body: _cargando
          ? _buildCargando()
          : _txData == null
              ? _buildError()
              : _buildContenido(_txData!),
    );
  }

  Widget _buildCargando() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Cargando resultado...'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          const Text('No se pudo cargar el resultado'),
          const SizedBox(height: 8),
          Text(widget.transactionId,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildContenido(Map<String, dynamic> tx) {
    final status = tx['status'] as String? ?? 'unknown';
    final warnings = List<String>.from(tx['validation_warnings'] ?? []);
    final errors = List<String>.from(tx['validation_errors'] ?? []);
    final extractionWarnings =
        List<String>.from(tx['extraction_warnings'] ?? []);
    final tags = List<String>.from(tx['tax_tags'] ?? []);
    final counterparty =
        tx['counterparty'] as Map<String, dynamic>? ?? {};
    final lines = List<Map<String, dynamic>>.from(
      (tx['lines'] ?? []).map((l) => Map<String, dynamic>.from(l as Map)),
    );
    final confidence = (tx['_ai_confidence'] as num?)?.toDouble() ??
        _estimarConfianza(tx);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Cabecera de estado ──────────────────────────────────────────
        _buildStatusCard(status, confidence, errors, warnings),
        const SizedBox(height: 12),

        // ── Alertas críticas ──────────────────────────────────────────
        if (errors.isNotEmpty) ...[
          _buildAlertasList(errors, esError: true),
          const SizedBox(height: 12),
        ],

        // ── Advertencias ──────────────────────────────────────────────
        if (warnings.isNotEmpty || extractionWarnings.isNotEmpty) ...[
          _buildAlertasList(
              [...warnings, ...extractionWarnings.where(
                  (w) => !warnings.contains(w))],
              esError: false),
          const SizedBox(height: 12),
        ],

        // ── Datos del proveedor ───────────────────────────────────────
        _buildSeccion(
          'Proveedor',
          Icons.store,
          Colors.blue,
          [
            _campo('Nombre', counterparty['name']),
            _campo('NIF / VAT', counterparty['tax_id']),
            _campo('País', counterparty['country']),
            _campo('Dirección', counterparty['address']),
          ],
        ),
        const SizedBox(height: 12),

        // ── Datos fiscales principales ────────────────────────────────
        _buildSeccion(
          'Datos fiscales',
          Icons.receipt,
          Colors.green,
          [
            _campo('Nº factura', tx['invoice_number']),
            _campo('Fecha', _formatearFecha(tx['invoice_date'])),
            _campo('Período AEAT', tx['period']),
            _campo('Base imponible',
                _formatearImporte(tx['base_amount_cents'])),
            _campo('IVA (${tx['vat_rate'] ?? '?'}%)',
                _formatearImporte(tx['vat_amount_cents'])),
            if ((tx['recargo_amount_cents'] ?? 0) > 0)
              _campo('Recargo equiv.',
                  _formatearImporte(tx['recargo_amount_cents'])),
            if ((tx['withholding_amount_cents'] ?? 0) > 0)
              _campo('Retención (${tx['withholding_rate'] ?? '?'}%)',
                  _formatearImporte(tx['withholding_amount_cents'],
                      negativo: true)),
            _campoTotal('TOTAL', _formatearImporte(tx['total_amount_cents'])),
            _campo('Moneda', tx['currency']),
          ],
        ),
        const SizedBox(height: 12),

        // ── Régimen IVA ───────────────────────────────────────────────
        _buildRegimenIva(tx['vat_scheme']),
        const SizedBox(height: 12),

        // ── Tax tags ──────────────────────────────────────────────────
        if (tags.isNotEmpty) ...[
          _buildTaxTags(tags),
          const SizedBox(height: 12),
        ],

        // ── Líneas de detalle ─────────────────────────────────────────
        if (lines.isNotEmpty) ...[
          _buildLineas(lines),
          const SizedBox(height: 12),
        ],

        // ── Modelos AEAT que se nutren de esta factura ────────────────
        _buildModelosContribucion(tx),
        const SizedBox(height: 12),

        // ── Metadatos técnicos ────────────────────────────────────────
        _buildMetadatos(tx),
        const SizedBox(height: 32),

        // ── Botones de acción ─────────────────────────────────────────
        _buildAcciones(tx),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Status card ──────────────────────────────────────────────────────────

  Widget _buildStatusCard(
    String status,
    double confidence,
    List<String> errors,
    List<String> warnings,
  ) {
    final Color color;
    final IconData icon;
    final String label;

    if (errors.isNotEmpty || status == 'needs_review') {
      color = Colors.orange;
      icon = Icons.warning_amber;
      label = 'Requiere revisión';
    } else if (status == 'posted') {
      color = Colors.green;
      icon = Icons.check_circle;
      label = 'Contabilizada correctamente';
    } else {
      color = Colors.grey;
      icon = Icons.hourglass_empty;
      label = 'Pendiente';
    }

    return Card(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Confianza IA: ',
                          style: TextStyle(fontSize: 13)),
                      Text(
                        '${(confidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _colorConfianza(confidence)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sección genérica ─────────────────────────────────────────────────────

  Widget _buildSeccion(
    String titulo,
    IconData icon,
    Color color,
    List<Widget> campos,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const Divider(height: 16),
            ...campos,
          ],
        ),
      ),
    );
  }

  Widget _campo(String label, dynamic valor) {
    if (valor == null || valor.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ),
          Expanded(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: valor.toString()));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('$label copiado'),
                        duration: const Duration(seconds: 1)),
                  );
                }
              },
              child: Text(valor.toString(),
                  style: const TextStyle(fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoTotal(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15)),
          Text(valor,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green)),
        ],
      ),
    );
  }

  // ─── Régimen IVA ──────────────────────────────────────────────────────────

  Widget _buildRegimenIva(String? scheme) {
    final info = _regimenInfo(scheme ?? 'standard');
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: info.color.withValues(alpha: 0.15),
          child: Icon(info.icon, color: info.color, size: 20),
        ),
        title: const Text('Régimen IVA',
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(info.label),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: info.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: info.color.withValues(alpha: 0.3)),
          ),
          child: Text(scheme ?? 'standard',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: info.color)),
        ),
      ),
    );
  }

  // ─── Tax tags ─────────────────────────────────────────────────────────────

  Widget _buildTaxTags(List<String> tags) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.label, size: 18, color: Colors.indigo),
                SizedBox(width: 8),
                Text('Clasificación IA',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((t) => _buildTag(t)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String tag) {
    final color = _colorTag(tag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(tag,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  // ─── Líneas ──────────────────────────────────────────────────────────────

  Widget _buildLineas(List<Map<String, dynamic>> lines) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.list, size: 18, color: Colors.teal),
                SizedBox(width: 8),
                Text('Líneas de factura',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const Divider(height: 16),
            ...lines.asMap().entries.map((e) {
              final l = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: Colors.teal[50],
                      child: Text('${e.key + 1}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.teal)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l['description']?.toString() ?? '',
                              style: const TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                          if (l['sku'] != null)
                            Text('SKU: ${l['sku']}',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${l['line_total'] ?? l['unit_price'] ?? '?'} €',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        if (l['vat_rate'] != null)
                          Text('IVA ${l['vat_rate']}%',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── Modelos AEAT afectados ───────────────────────────────────────────────

  Widget _buildModelosContribucion(Map<String, dynamic> tx) {
    final modelos = _determinarModelos(tx);
    if (modelos.isEmpty) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance, size: 18, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text('Esta factura contribuye a:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            ...modelos.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: m.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: m.color.withValues(alpha: 0.4)),
                        ),
                        child: Text(m.code,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: m.color)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.nombre,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            Text(m.casilla,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ─── Alertas ──────────────────────────────────────────────────────────────

  Widget _buildAlertasList(List<String> items, {required bool esError}) {
    final color = esError ? Colors.red : Colors.orange;
    final icon = esError ? Icons.error_outline : Icons.warning_amber;
    final titulo = esError ? 'Errores detectados' : 'Advertencias';

    return Card(
      color: color.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(titulo,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 15)),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(color: color, fontSize: 14)),
                    Expanded(
                      child: Text(w,
                          style: TextStyle(
                              color: color.withValues(alpha: 0.9),
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Metadatos técnicos ───────────────────────────────────────────────────

  Widget _buildMetadatos(Map<String, dynamic> tx) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.code, size: 20, color: Colors.grey),
        title: const Text('Detalles técnicos',
            style: TextStyle(fontSize: 14)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _campo('ID transacción', widget.transactionId),
          _campo('Estado', tx['status']),
          _campo('Modelo LLM', tx['_ai_llm_model'] ?? 'claude-sonnet-4-5'),
          _campo('Versión prompt', tx['_ai_prompt_version']),
          _campo('Motor OCR', tx['_ai_ocr_engine']),
          _campo('Tipo', tx['type']),
          _campo('Creado', _formatearTimestamp(tx['created_at'])),
        ],
      ),
    );
  }

  // ─── Acciones ─────────────────────────────────────────────────────────────

  Widget _buildAcciones(Map<String, dynamic> tx) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.arrow_back),
          label: const Text('Subir otra factura'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 8),
        if (tx['status'] == 'needs_review')
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Marcar como revisada'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _marcarRevisada(),
          ),
      ],
    );
  }

  Future<void> _marcarRevisada() async {
    try {
      await _db
          .doc('empresas/${widget.empresaId}/fiscal_transactions/${widget.transactionId}')
          .update({'status': 'posted'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Factura marcada como revisada y contabilizada'),
          backgroundColor: Colors.green,
        ));
        setState(() {
          if (_txData != null) _txData!['status'] = 'posted';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _formatearImporte(dynamic cents, {bool negativo = false}) {
    if (cents == null) return '—';
    final value = (cents as num).toDouble() / 100;
    final abs = value.abs();
    final fmt = NumberFormat('#,##0.00', 'es').format(abs);
    return negativo ? '-$fmt €' : '$fmt €';
  }

  String _formatearFecha(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      return DateFormat('dd/MM/yyyy', 'es').format(ts.toDate());
    }
    return ts.toString();
  }

  String _formatearTimestamp(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      return DateFormat('dd/MM/yyyy HH:mm', 'es').format(ts.toDate());
    }
    return ts.toString();
  }

  Color _colorConfianza(double c) {
    if (c >= 0.85) return Colors.green;
    if (c >= 0.60) return Colors.orange;
    return Colors.red;
  }

  double _estimarConfianza(Map<String, dynamic> tx) {
    double score = 1.0;
    if (tx['counterparty']?['tax_id'] == null) score -= 0.2;
    if (tx['invoice_number'] == null) score -= 0.15;
    if (tx['invoice_date'] == null) score -= 0.2;
    final errors = tx['validation_errors'] as List? ?? [];
    score -= errors.length * 0.3;
    return score.clamp(0.0, 1.0);
  }

  Color _colorTag(String tag) {
    if (tag.contains('ERROR') || tag.contains('NOT_DEDUCTIBLE')) return Colors.red;
    if (tag.contains('MARGIN') || tag.contains('SECOND_HAND')) return Colors.orange;
    if (tag.contains('WITHHOLDING') || tag.contains('RECARGO')) return Colors.purple;
    if (tag.contains('CROSS_BORDER') || tag.contains('REVERSE')) return Colors.blue;
    if (tag.contains('FIXED_ASSET')) return Colors.brown;
    if (tag.contains('TICKET') || tag.contains('SIMPLIFIED')) return Colors.grey;
    return Colors.teal;
  }

  _RegimenInfo _regimenInfo(String scheme) {
    switch (scheme) {
      case 'standard':
        return _RegimenInfo('IVA general (21% / 10% / 4%)',
            Icons.receipt, Colors.green);
      case 'margin_scheme':
        return _RegimenInfo('Régimen de margen (bienes usados)',
            Icons.recycling, Colors.orange);
      case 'reverse_charge_eu':
        return _RegimenInfo('Inversión sujeto pasivo UE (intracomunitaria)',
            Icons.public, Colors.blue);
      case 'reverse_charge_domestic':
        return _RegimenInfo('Inversión sujeto pasivo nacional (ISP)',
            Icons.swap_horiz, Colors.indigo);
      case 'exempt':
        return _RegimenInfo('Exenta de IVA (art. 20 LIVA)',
            Icons.not_interested, Colors.grey);
      case 'not_subject':
        return _RegimenInfo('No sujeta a IVA (art. 7 LIVA)',
            Icons.block, Colors.grey);
      case 'recargo_equivalencia':
        return _RegimenInfo('Con recargo de equivalencia',
            Icons.add_circle, Colors.purple);
      case 'import':
        return _RegimenInfo('Importación (proveedor fuera UE)',
            Icons.flight_land, Colors.red);
      case 'export':
        return _RegimenInfo('Exportación (cliente fuera UE)',
            Icons.flight_takeoff, Colors.teal);
      default:
        return _RegimenInfo(scheme, Icons.help_outline, Colors.grey);
    }
  }

  List<_ModeloContribucion> _determinarModelos(Map<String, dynamic> tx) {
    final modelos = <_ModeloContribucion>[];
    final scheme = tx['vat_scheme'] as String? ?? 'standard';
    final tags = List<String>.from(tx['tax_tags'] ?? []);
    final type = tx['type'] as String? ?? '';
    final hasWithholding = (tx['withholding_amount_cents'] ?? 0) > 0;
    final isAlquiler = tags.contains('ALQUILER_LOCAL');
    final isIntra = tags.contains('CROSS_BORDER_EU');

    // 303 — IVA trimestral (casi siempre)
    if (scheme != 'margin_scheme' && !tags.contains('VAT_NOT_DEDUCTIBLE')) {
      if (type == 'invoice_received') {
        modelos.add(_ModeloContribucion(
          '303',
          'IVA trimestral',
          'Casilla 28-29 (IVA soportado deducible)',
          Colors.blue,
        ));
      } else if (type.contains('issued') || type.contains('sent')) {
        modelos.add(_ModeloContribucion(
          '303', 'IVA trimestral', 'Casilla 01-08 (IVA repercutido)',
          Colors.blue,
        ));
      }
    }
    if (scheme == 'reverse_charge_eu') {
      modelos.add(_ModeloContribucion(
        '303', 'IVA trimestral',
        'Casillas 10-11 y 34-35 (adquisición intracomunitaria)',
        Colors.blue,
      ));
    }

    // 111 — Retenciones IRPF
    if (hasWithholding && !isAlquiler) {
      modelos.add(_ModeloContribucion(
        '111', 'Retenciones IRPF trimestral',
        'Casilla 05-06 (actividades económicas)',
        Colors.purple,
      ));
      modelos.add(_ModeloContribucion(
        '190', 'Resumen anual IRPF',
        'Desglose por perceptor (clave G)',
        Colors.purple,
      ));
    }

    // 115 — Retenciones alquileres
    if (hasWithholding && isAlquiler) {
      modelos.add(_ModeloContribucion(
        '115', 'Retenciones alquileres trimestral',
        'Casillas 01-03',
        Colors.teal,
      ));
      modelos.add(_ModeloContribucion(
        '180', 'Resumen anual alquileres',
        'Desglose por arrendador',
        Colors.teal,
      ));
    }

    // 347 — Operaciones con terceros
    if (!isIntra && !isAlquiler) {
      modelos.add(_ModeloContribucion(
        '347', 'Operaciones con terceros',
        'Si el acumulado anual supera 3.005,06 €',
        Colors.orange,
      ));
    }

    return modelos;
  }
}

// ─── Clases auxiliares ────────────────────────────────────────────────────────

class _RegimenInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _RegimenInfo(this.label, this.icon, this.color);
}

class _ModeloContribucion {
  final String code;
  final String nombre;
  final String casilla;
  final Color color;
  const _ModeloContribucion(this.code, this.nombre, this.casilla, this.color);
}





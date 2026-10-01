import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import 'package:planeag_flutter/core/widgets/fluix_app_bar.dart';

// ═════════════════════════════════════════════════════════════════════════════
// MIS NÓMINAS — Vista del empleado (rol staff)
// Solo puede ver sus propias nóminas, sin posibilidad de subir ni eliminar.
// ═════════════════════════════════════════════════════════════════════════════

const _kBlue   = Color(0xFF3B82F6);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kBorder = Color(0xFFE5E7EB);
const _kBg     = Color(0xFFF8F9FA);
const _kText   = Color(0xFF111827);
const _kSub    = Color(0xFF6B7280);

const _meses = [
  '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  'Paga extra 1', 'Paga extra 2',
];

class MisNominasScreen extends StatefulWidget {
  final String empresaId;

  const MisNominasScreen({super.key, required this.empresaId});

  @override
  State<MisNominasScreen> createState() => _MisNominasScreenState();
}

class _MisNominasScreenState extends State<MisNominasScreen> {
  final _db  = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  int _anioFiltro = DateTime.now().year;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('empresas').doc(widget.empresaId)
          .collection('nominas_empleados');

  Future<void> _abrir(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (mounted) FluxToast.error(context, 'No se pudo abrir el archivo');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: FluixAppBar(
        titulo: 'Mis Nóminas',
        extraActions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _anioFiltro,
              style: const TextStyle(fontSize: 13, color: _kText),
              icon: const Icon(Icons.arrow_drop_down, size: 16, color: _kSub),
              items: List.generate(5, (i) => DateTime.now().year - i)
                  .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                  .toList(),
              onChanged: (v) => setState(() => _anioFiltro = v!),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        // Lista
        Expanded(
          child: StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: _col
                .where('empleado_id', isEqualTo: _uid)
                .snapshots()
                .map((s) {
                  final docs = s.docs
                      .where((d) => d.data()['anio'] == _anioFiltro)
                      .toList();
                  docs.sort((a, b) {
                    final ma = a.data()['mes'] as int? ?? 0;
                    final mb = b.data()['mes'] as int? ?? 0;
                    return mb.compareTo(ma);
                  });
                  return docs;
                }),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: _kGreen));
              }
              final docs = snap.data ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text('No hay nóminas en $_anioFiltro',
                        style: TextStyle(
                            fontSize: 15, color: Colors.grey[500])),
                    const SizedBox(height: 6),
                    Text('Cuando tu empresa suba tus nóminas aparecerán aquí',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400])),
                  ]),
                );
              }

              // Resumen anual
              final totalNeto = docs.fold<double>(0, (sum, doc) {
                final importe = doc.data()['importe_neto'] as double?;
                return sum + (importe ?? 0);
              });

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // KPI resumen
                  if (totalNeto > 0) ...[
                    _buildResumen(docs.length, totalNeto),
                    const SizedBox(height: 12),
                  ],
                  ...docs.map((doc) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildItem(doc),
                      )),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildResumen(int count, double totalNeto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Expanded(child: _kpi('Nóminas en $_anioFiltro', '$count')),
        Container(width: 1, height: 40, color: _kGreen.withValues(alpha: 0.2)),
        Expanded(
            child: _kpi('Total neto recibido',
                '${totalNeto.toStringAsFixed(2)} €')),
      ]),
    );
  }

  Widget _kpi(String label, String valor) => Column(children: [
        Text(valor,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: _kText)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: _kSub),
            textAlign: TextAlign.center),
      ]);

  Widget _buildItem(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d          = doc.data();
    final mes        = (d['mes'] as int? ?? 1).clamp(1, 14);
    final anio       = d['anio'] as int? ?? 0;
    final url        = d['url'] as String? ?? '';
    final nombre     = d['nombre_archivo'] as String? ?? '';
    final importeNeto = d['importe_neto'] as double?;
    final ext        = d['extension'] as String? ?? 'pdf';
    final subidoEn   = (d['subido_en'] as Timestamp?)?.toDate();
    final fechaStr   = subidoEn != null
        ? '${subidoEn.day.toString().padLeft(2,'0')}/'
          '${subidoEn.month.toString().padLeft(2,'0')}/${subidoEn.year}'
        : '';
    final isPdf = ext == 'pdf';

    return GestureDetector(
      onTap: url.isNotEmpty ? () => _abrir(url) : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 2),
          )],
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: isPdf
                  ? _kRed.withValues(alpha: 0.08)
                  : _kBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
              color: isPdf ? _kRed : _kBlue, size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_meses[mes],
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700, color: _kText)),
              const SizedBox(height: 3),
              Row(children: [
                Text('$anio',
                    style: const TextStyle(fontSize: 12, color: _kSub)),
                if (importeNeto != null) ...[
                  const Text(' · ', style: TextStyle(fontSize: 12, color: _kSub)),
                  Text('${importeNeto.toStringAsFixed(2)} € neto',
                      style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700, color: _kGreen)),
                ],
              ]),
              if (fechaStr.isNotEmpty)
                Text('Disponible desde el $fechaStr',
                    style: const TextStyle(fontSize: 11, color: _kSub)),
              if (nombre.isNotEmpty)
                Text(nombre,
                    style: const TextStyle(fontSize: 10, color: _kSub),
                    overflow: TextOverflow.ellipsis),
            ],
          )),
          // Botón abrir
          Container(
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: url.isNotEmpty ? () => _abrir(url) : null,
              icon: const Icon(Icons.download_rounded,
                  size: 20, color: _kBlue),
              tooltip: 'Descargar / Ver',
              splashRadius: 20,
            ),
          ),
        ]),
      ),
    );
  }
}

// resenas_fluix_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ─── Paleta ──────────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF0A0F23);
const _kCard   = Color(0xFF1E2139);
const _kCard2  = Color(0xFF252A45);
const _kAccent = Color(0xFF00FFC8);
const _kRosa   = Color(0xFFFF3296);
const _kOro    = Color(0xFFFFB830);
const _kTexto  = Colors.white;
const _kMuted  = Color(0xFFB0B3C1);
const _kBorde  = Color(0xFF2A2E45);

class ResenasFluixScreen extends StatefulWidget {
  final String negocioId;
  final String empresaId;
  final String nombreNegocio;

  const ResenasFluixScreen({
    super.key,
    required this.negocioId,
    required this.empresaId,
    required this.nombreNegocio,
  });

  @override
  State<ResenasFluixScreen> createState() => _ResenasFluixScreenState();
}

class _ResenasFluixScreenState extends State<ResenasFluixScreen> {
  late final Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('valoraciones')
        .where('origen', isEqualTo: 'fluix')
        .orderBy('fecha', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<void> _responder(String resenaId, String texto) async {
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('valoraciones')
        .doc(resenaId)
        .update({
      'respuesta': texto,
      'fechaRespuesta': FieldValue.serverTimestamp(),
    });
  }

  void _mostrarDialogoRespuesta(BuildContext ctx, String resenaId, String? respuestaActual) {
    final ctrl = TextEditingController(text: respuestaActual ?? '');
    showDialog(
      context: ctx,
      builder: (dctx) => Dialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kOro.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.reply_rounded, color: _kOro, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Responder reseña',
                    style: TextStyle(color: _kTexto, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 4,
                style: const TextStyle(color: _kTexto, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Escribe tu respuesta pública…',
                  hintStyle: TextStyle(color: _kMuted.withValues(alpha: 0.6), fontSize: 13),
                  filled: true,
                  fillColor: _kCard2,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBorde),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kBorde),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _kOro, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dctx),
                    child: const Text('Cancelar', style: TextStyle(color: _kMuted)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final texto = ctrl.text.trim();
                      if (texto.isEmpty) return;
                      Navigator.pop(dctx);
                      try {
                        await _responder(resenaId, texto);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('✅ Respuesta publicada en Explorar'),
                            backgroundColor: _kAccent,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: _kRosa,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Publicar', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kOro,
                      foregroundColor: _kBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTarjetaResena(Map<String, dynamic> data, String docId) {
    // Compatibilidad con campos de valoraciones de clientes públicos
    final autorNombre   = data['autorNombre'] as String?
        ?? data['autor'] as String? ?? 'Anónimo';
    final avatarUrl     = data['autorAvatarUrl'] as String?
        ?? data['avatarUrl'] as String?;
    final estrellas     = (data['estrellas'] as num?)?.toDouble() ?? 0;
    final comentario    = data['comentario'] as String?
        ?? data['texto'] as String? ?? '';
    final servicioUsado = data['servicioUsado'] as String?
        ?? data['servicio'] as String?;
    final verificado    = data['verificado'] as bool? ?? false;
    final respuesta     = data['respuesta'] as String?;
    DateTime? fecha;
    try { fecha = (data['fecha'] as Timestamp?)?.toDate(); } catch (_) {}
    DateTime? fechaResp;
    try { fechaResp = (data['fechaRespuesta'] as Timestamp?)?.toDate(); } catch (_) {}

    final iniciales = autorNombre.isNotEmpty
        ? autorNombre.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: respuesta != null ? _kOro.withValues(alpha: 0.25) : _kBorde,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Fila: avatar + nombre + estrellas + fecha
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _kAccent.withValues(alpha: 0.15),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(iniciales, style: const TextStyle(color: _kAccent, fontWeight: FontWeight.bold, fontSize: 13))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(autorNombre,
                    style: const TextStyle(color: _kTexto, fontWeight: FontWeight.bold, fontSize: 14))),
                if (verificado)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.verified_rounded, color: _kAccent, size: 10),
                      SizedBox(width: 3),
                      Text('Verificado', style: TextStyle(color: _kAccent, fontSize: 9, fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                ...List.generate(5, (i) => Icon(
                  i < estrellas.round() ? Icons.star_rounded : Icons.star_border_rounded,
                  color: _kOro, size: 14,
                )),
                const SizedBox(width: 6),
                if (fecha != null)
                  Text(DateFormat('dd/MM/yyyy').format(fecha),
                      style: const TextStyle(color: _kMuted, fontSize: 11)),
              ]),
            ])),
          ]),
        ),

        // Comentario
        if (comentario.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(comentario, style: const TextStyle(color: _kMuted, fontSize: 13, height: 1.5)),
          ),

        // Servicio usado
        if (servicioUsado != null && servicioUsado.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kCard2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorde),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.content_cut_rounded, color: _kMuted, size: 11),
                const SizedBox(width: 4),
                Text(servicioUsado, style: const TextStyle(color: _kMuted, fontSize: 11)),
              ]),
            ),
          ),

        // Respuesta del negocio
        if (respuesta != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kOro.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kOro.withValues(alpha: 0.2)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.storefront_rounded, color: _kOro, size: 13),
                const SizedBox(width: 6),
                const Text('Respuesta del negocio',
                    style: TextStyle(color: _kOro, fontSize: 11, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (fechaResp != null)
                  Text(DateFormat('dd/MM/yyyy').format(fechaResp),
                      style: const TextStyle(color: _kMuted, fontSize: 10)),
              ]),
              const SizedBox(height: 6),
              Text(respuesta, style: const TextStyle(color: _kTexto, fontSize: 12, height: 1.4)),
            ]),
          ),

        // Divider + Botón Responder
        const Divider(color: _kBorde, height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: TextButton.icon(
            onPressed: () => _mostrarDialogoRespuesta(context, docId, respuesta),
            icon: Icon(
              respuesta != null ? Icons.edit_rounded : Icons.reply_rounded,
              size: 15,
              color: respuesta != null ? _kMuted : _kOro,
            ),
            label: Text(
              respuesta != null ? 'Editar respuesta' : 'Responder',
              style: TextStyle(
                color: respuesta != null ? _kMuted : _kOro,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) return const SizedBox.shrink();
    final total = docs.length;
    final media = docs
        .map((d) => ((d.data() as Map<String, dynamic>)['estrellas'] as num?)?.toDouble() ?? 0)
        .reduce((a, b) => a + b) / total;
    final respondidas = docs.where((d) =>
        (d.data() as Map<String, dynamic>)['respuesta'] != null).length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kOro.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Column(children: [
          Text(media.toStringAsFixed(1),
              style: const TextStyle(color: _kOro, fontSize: 40, fontWeight: FontWeight.bold, height: 1)),
          Row(children: List.generate(5, (i) => Icon(
            i < media.round() ? Icons.star_rounded : Icons.star_border_rounded,
            color: _kOro, size: 16,
          ))),
        ]),
        const SizedBox(width: 20),
        Container(width: 1, height: 50, color: _kBorde),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.chat_bubble_outline_rounded, color: _kMuted, size: 13),
            const SizedBox(width: 6),
            Text('$total reseñas en total', style: const TextStyle(color: _kMuted, fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.reply_rounded, color: _kMuted, size: 13),
            const SizedBox(width: 6),
            Text('$respondidas respondidas · ${total - respondidas} pendientes',
                style: const TextStyle(color: _kMuted, fontSize: 12)),
          ]),
        ])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF151932),
        foregroundColor: _kTexto,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Reseñas Flix',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text(widget.nombreNegocio,
              style: const TextStyle(color: _kMuted, fontSize: 12)),
        ]),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _kAccent));
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}',
                style: const TextStyle(color: _kRosa)));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: _kCard, borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: _kOro.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.star_border_rounded, color: _kOro, size: 38),
              ),
              const SizedBox(height: 16),
              const Text('Sin reseñas todavía',
                  style: TextStyle(color: _kTexto, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Cuando los clientes dejen reseñas\ndesde la app pública, aparecerán aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kMuted, fontSize: 13),
              ),
            ]));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(docs),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return _buildTarjetaResena(data, doc.id);
              }),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// CANAL DE COMUNICACIÓN INTERNO — Admin ↔ Empleado
// Colección: empresas/{id}/mensajes_internos/{empleadoUid}/mensajes/{msgId}
// Visible: empleado ve solo sus mensajes; admin puede ver cualquier empleado.
// ═════════════════════════════════════════════════════════════════════════════

class CanalComunicacionWidget extends StatefulWidget {
  final String empresaId;
  final String empleadoUid;
  final String empleadoNombre;
  final bool modoAdmin; // true = admin escribe en nombre de la empresa

  const CanalComunicacionWidget({
    super.key,
    required this.empresaId,
    required this.empleadoUid,
    required this.empleadoNombre,
    this.modoAdmin = false,
  });

  @override
  State<CanalComunicacionWidget> createState() => _CanalComunicacionWidgetState();
}

class _CanalComunicacionWidgetState extends State<CanalComunicacionWidget> {
  final _ctrl    = TextEditingController();
  final _scroll  = ScrollController();
  bool _enviando = false;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('mensajes_internos').doc(widget.empleadoUid)
          .collection('mensajes');

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty) return;
    setState(() => _enviando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _col.add({
        'texto':       texto,
        'remitente':   widget.modoAdmin ? 'admin' : 'empleado',
        'remitenteUid': uid,
        'ts':          FieldValue.serverTimestamp(),
        'leido':       false,
      });
      _ctrl.clear();
      // Marcar los no leídos del otro lado como leídos
      _marcarLeidos();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _marcarLeidos() {
    final otroLado = widget.modoAdmin ? 'empleado' : 'admin';
    _col
        .where('remitente', isEqualTo: otroLado)
        .where('leido', isEqualTo: false)
        .get()
        .then((snap) {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) batch.update(doc.reference, {'leido': true});
      if (snap.docs.isNotEmpty) batch.commit();
    });
  }

  @override
  void initState() {
    super.initState();
    _marcarLeidos();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // ── Cabecera ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: const BoxDecoration(
            color: Color(0xFFF0F7FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(bottom: BorderSide(color: Color(0xFFDBEAFE))),
          ),
          child: Row(children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                size: 16, color: Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              widget.modoAdmin
                  ? 'Mensajes con ${widget.empleadoNombre}'
                  : 'Mensajes de empresa',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: Color(0xFF1E40AF)),
            )),
            // Badge no leídos
            StreamBuilder<QuerySnapshot>(
              stream: _col
                  .where('remitente',
                      isEqualTo: widget.modoAdmin ? 'empleado' : 'admin')
                  .where('leido', isEqualTo: false)
                  .snapshots(),
              builder: (_, snap) {
                final n = snap.data?.docs.length ?? 0;
                if (n == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$n', style: const TextStyle(
                      fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                );
              },
            ),
          ]),
        ),

        // ── Lista de mensajes ────────────────────────────────────────────────
        SizedBox(
          height: 240,
          child: StreamBuilder<QuerySnapshot>(
            stream: _col.orderBy('ts').snapshots(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                return const Center(child: SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_outlined, size: 36,
                        color: Colors.grey[300]),
                    const SizedBox(height: 8),
                    Text(
                      widget.modoAdmin
                          ? 'Sin mensajes con este empleado'
                          : 'No hay mensajes todavía',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ));
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scroll.hasClients) {
                  _scroll.jumpTo(_scroll.position.maxScrollExtent);
                }
              });

              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final esAdmin = d['remitente'] == 'admin';
                  final esMio = widget.modoAdmin ? esAdmin : !esAdmin;
                  final ts = d['ts'] as Timestamp?;
                  final hora = ts != null
                      ? '${ts.toDate().hour.toString().padLeft(2,'0')}:'
                        '${ts.toDate().minute.toString().padLeft(2,'0')}'
                      : '';
                  return Align(
                    alignment: esMio
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Column(
                        crossAxisAlignment: esMio
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: esMio
                                  ? const Color(0xFF3B82F6)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: Radius.circular(esMio ? 12 : 4),
                                bottomRight: Radius.circular(esMio ? 4 : 12),
                              ),
                            ),
                            child: Text(
                              d['texto'] as String? ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: esMio ? Colors.white : const Color(0xFF111827),
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${esAdmin ? "Empresa" : widget.empleadoNombre.split(' ').first} · $hora',
                                style: const TextStyle(
                                    fontSize: 9.5, color: Color(0xFF9CA3AF)),
                              ),
                              if (esMio && (d['leido'] as bool? ?? false)) ...[
                                const SizedBox(width: 3),
                                const Icon(Icons.done_all_rounded,
                                    size: 11, color: Color(0xFF3B82F6)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // ── Input de texto ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(fontSize: 13),
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _enviar(),
                decoration: InputDecoration(
                  hintText: widget.modoAdmin
                      ? 'Escribe un mensaje a ${widget.empleadoNombre.split(' ').first}…'
                      : 'Escribe un mensaje a la empresa…',
                  hintStyle: const TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF3B82F6)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _enviando ? null : _enviar,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                minimumSize: const Size(42, 42),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _enviando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
            ),
          ]),
        ),
      ]),
    );
  }
}

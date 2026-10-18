import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/widgets/fluix_app_bar.dart';

class PantallaNotificacionesCliente extends StatelessWidget {
  const PantallaNotificacionesCliente({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: FluixAppBar(
        titulo: 'Notificaciones',
        showLeading: true,
        extraActions: [
          if (uid != null)
            TextButton(
              onPressed: () => _marcarTodasLeidas(uid),
              child: const Text('Marcar leídas',
                  style: TextStyle(color: Color(0xFF00BFA5), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: uid == null
          ? const Center(
              child: Text('Inicia sesión para ver notificaciones',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14)))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(uid)
                  .collection('notificaciones')
                  .orderBy('creado_en', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF00BFA5)));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00BFA5).withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_none_rounded,
                              size: 40, color: Color(0xFF00BFA5)),
                        ),
                        const SizedBox(height: 16),
                        const Text('Sin notificaciones',
                            style: TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text('Aquí aparecerán confirmaciones\nde reservas y avisos',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFF64748B), fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFE2E8F0), indent: 68),
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final leida = data['leida'] as bool? ?? false;
                    return _NotifItem(
                      docId: docs[i].id,
                      uid: uid,
                      data: data,
                      leida: leida,
                    );
                  },
                );
              },
            ),
    );
  }

  Future<void> _marcarTodasLeidas(String uid) async {
    final batch = FirebaseFirestore.instance.batch();
    final snap = await FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('notificaciones')
        .where('leida', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'leida': true});
    }
    await batch.commit();
  }
}

class _NotifItem extends StatelessWidget {
  final String docId;
  final String uid;
  final Map<String, dynamic> data;
  final bool leida;

  const _NotifItem({
    required this.docId,
    required this.uid,
    required this.data,
    required this.leida,
  });

  @override
  Widget build(BuildContext context) {
    final titulo = data['titulo'] as String? ?? 'Notificación';
    final cuerpo = data['cuerpo'] as String? ?? '';
    final tipo   = data['tipo']  as String? ?? 'info';
    final ts     = data['creado_en'] as Timestamp?;
    final fecha  = ts?.toDate();

    final (iconData, color) = _iconPorTipo(tipo);

    return InkWell(
      onTap: () {
        if (!leida) {
          FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .collection('notificaciones')
              .doc(docId)
              .update({'leida': true});
        }
      },
      child: Container(
        color: leida ? Colors.transparent : const Color(0xFF00BFA5).withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(titulo,
                          style: TextStyle(
                            color: const Color(0xFF1E293B),
                            fontSize: 14,
                            fontWeight: leida ? FontWeight.w500 : FontWeight.w700,
                          )),
                    ),
                    if (!leida)
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFF00BFA5), shape: BoxShape.circle),
                      ),
                  ]),
                  if (cuerpo.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(cuerpo,
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 12.5, height: 1.4),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                  if (fecha != null) ...[
                    const SizedBox(height: 5),
                    Text(_formatFecha(fecha),
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 11)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _iconPorTipo(String tipo) {
    switch (tipo) {
      case 'reservaConfirmada':
        return (Icons.check_circle_rounded, const Color(0xFF10B981));
      case 'reservaCancelada':
        return (Icons.cancel_rounded, const Color(0xFFEF4444));
      case 'reservaNueva':
      case 'reservaPendiente':
        return (Icons.calendar_today_rounded, const Color(0xFF00BFA5));
      case 'oferta':
      case 'flash':
        return (Icons.bolt_rounded, const Color(0xFFFFB830));
      case 'puntos':
      case 'monedas':
        return (Icons.stars_rounded, const Color(0xFFFFB830));
      default:
        return (Icons.notifications_rounded, const Color(0xFF64748B));
    }
  }

  String _formatFecha(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1)  return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1)    return 'Ayer';
    if (diff.inDays < 7)     return 'Hace ${diff.inDays} días';
    return '${d.day}/${d.month}/${d.year}';
  }
}

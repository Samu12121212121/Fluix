import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PantallaNotificacionesCliente extends StatelessWidget {
  const PantallaNotificacionesCliente({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151932),
        foregroundColor: Colors.white,
        title: const Text('Notificaciones',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        elevation: 0,
        actions: [
          if (uid != null)
            TextButton(
              onPressed: () => _marcarTodasLeidas(uid),
              child: const Text('Marcar leídas',
                  style: TextStyle(color: Color(0xFF00FFC8), fontSize: 12)),
            ),
        ],
      ),
      body: uid == null
          ? const Center(
              child: Text('Inicia sesión para ver notificaciones',
                  style: TextStyle(color: Color(0xFFB0B3C1))))
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
                      child: CircularProgressIndicator(color: Color(0xFF00FFC8)));
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 64,
                            color: const Color(0xFFB0B3C1).withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text('No tienes notificaciones',
                            style: TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text('Aquí aparecerán confirmaciones\nde reservas y avisos',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Color(0xFFB0B3C1), fontSize: 13)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFF2A2E45)),
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
    final tipo = data['tipo'] as String? ?? 'info';
    final ts = data['creado_en'] as Timestamp?;
    final fecha = ts?.toDate();

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
        color: leida ? Colors.transparent : const Color(0xFF00FFC8).withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: color, size: 20),
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
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: leida ? FontWeight.w400 : FontWeight.w700,
                          )),
                    ),
                    if (!leida)
                      Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(
                            color: Color(0xFF00FFC8), shape: BoxShape.circle),
                      ),
                  ]),
                  if (cuerpo.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(cuerpo,
                        style: const TextStyle(
                            color: Color(0xFFB0B3C1), fontSize: 12, height: 1.4),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  if (fecha != null) ...[
                    const SizedBox(height: 5),
                    Text(_formatFecha(fecha),
                        style: const TextStyle(
                            color: Color(0xFF6B6E82), fontSize: 11)),
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
      case 'reserva_confirmada':
        return (Icons.check_circle_outline_rounded, const Color(0xFF00FFC8));
      case 'reserva_cancelada':
        return (Icons.cancel_outlined, const Color(0xFFFF2850));
      case 'reserva_pendiente':
        return (Icons.schedule_rounded, const Color(0xFFFF4678));
      case 'promo':
        return (Icons.local_offer_outlined, const Color(0xFFFF3296));
      default:
        return (Icons.notifications_none_rounded, const Color(0xFFB0B3C1));
    }
  }

  String _formatFecha(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 2) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}


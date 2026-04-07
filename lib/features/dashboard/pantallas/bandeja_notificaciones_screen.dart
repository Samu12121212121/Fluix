import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../services/bandeja_notificaciones_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA — Bandeja de notificaciones in-app
// ─────────────────────────────────────────────────────────────────────────────

class BandejaNotificacionesScreen extends StatelessWidget {
  final String empresaId;
  const BandejaNotificacionesScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final svc = BandejaNotificacionesService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Notificaciones',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => svc.marcarTodasLeidas(empresaId),
            child: const Text('Marcar todas',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              await svc.eliminarAntiguas(empresaId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Notificaciones antiguas eliminadas'),
                  backgroundColor: Colors.green,
                ));
              }
            },
            tooltip: 'Eliminar >30 días',
          ),
        ],
      ),
      body: StreamBuilder<List<NotificacionInApp>>(
        stream: svc.notificacionesStream(empresaId),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Sin notificaciones',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ],
            ));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (_, i) => _NotificacionItem(
              notif: items[i],
              empresaId: empresaId,
              onTap: () async {
                await svc.marcarLeida(empresaId, items[i].id);
                // Aquí se podría navegar al módulo destino
              },
              onDismiss: () => svc.eliminar(empresaId, items[i].id),
            ),
          );
        },
      ),
    );
  }
}

class _NotificacionItem extends StatelessWidget {
  final NotificacionInApp notif;
  final String empresaId;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificacionItem({
    required this.notif,
    required this.empresaId,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: notif.leida ? Colors.grey[200]! : const Color(0xFF0D47A1).withValues(alpha: 0.3),
          ),
        ),
        color: notif.leida ? Colors.white : const Color(0xFF0D47A1).withValues(alpha: 0.03),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: notif.leida
                ? Colors.grey[100]
                : const Color(0xFF0D47A1).withValues(alpha: 0.1),
            child: Text(notif.tipo.emoji, style: const TextStyle(fontSize: 18)),
          ),
          title: Text(notif.titulo,
              style: TextStyle(
                fontWeight: notif.leida ? FontWeight.normal : FontWeight.w600,
                fontSize: 14,
              )),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notif.cuerpo.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(notif.cuerpo,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
              const SizedBox(height: 4),
              Text(
                timeago.format(notif.timestamp, locale: 'es'),
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
          trailing: notif.leida
              ? null
              : Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D47A1),
                    shape: BoxShape.circle,
                  ),
                ),
        ),
      ),
    );
  }
}


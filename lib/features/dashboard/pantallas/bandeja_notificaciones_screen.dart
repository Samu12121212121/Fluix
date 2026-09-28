import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/bandeja_notificaciones_service.dart';
import '../../tareas/pantallas/modulo_tareas_screen.dart';
import '../../reservas/pantallas/modulo_reservas_screen.dart';
import '../../reservas/pantallas/detalle_reserva_screen.dart';
import '../../facturacion/pantallas/modulo_facturacion_screen.dart';
import '../../clientes/pantallas/modulo_clientes_screen.dart';
import '../../pedidos/pantallas/modulo_pedidos_nuevo_screen.dart';
import '../../empleados/pantallas/modulo_empleados_screen.dart';
import '../../fichajes/pantallas/gestion_fichajes_screen.dart';
import '../../nominas/pantallas/modulo_nominas_screen.dart';
import '../../vacaciones/pantallas/vacaciones_screen.dart';
import '../../fiscal/pantallas/calendario_fiscal_screen.dart';
import 'pantalla_contenido_web.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA — Bandeja de notificaciones in-app
// ─────────────────────────────────────────────────────────────────────────────

class BandejaNotificacionesScreen extends StatelessWidget {
  final String empresaId;
  const BandejaNotificacionesScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final svc = BandejaNotificacionesService();
    final dark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0A0F23) : Colors.white;
    final surface = dark ? const Color(0xFF1E2139) : const Color(0xFFF5F7FA);
    final border = dark ? const Color(0xFF2A2E45) : const Color(0xFFE0E3EC);
    final texto = dark ? Colors.white : const Color(0xFF0A0F23);
    final muted = dark ? const Color(0xFFB0B3C1) : const Color(0xFF6B7280);
    const accent = Color(0xFF00FFC8);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: dark ? const Color(0xFF0A0F23) : Colors.white,
        foregroundColor: texto,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: border),
        ),
        title: Row(
          children: [
            Icon(Icons.notifications_outlined, size: 20, color: accent),
            const SizedBox(width: 8),
            Text('Notificaciones',
                style: TextStyle(fontWeight: FontWeight.w700, color: texto, fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => svc.marcarTodasLeidas(empresaId),
            child: Text('Marcar leídas',
                style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            icon: Icon(Icons.science_outlined, color: muted),
            tooltip: 'Cargar ejemplos',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Cargar notificaciones de ejemplo'),
                  content: const Text(
                      'Se crearán 11 notificaciones de ejemplo (una por cada tipo). '
                      '¿Continuar?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Cargar')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await svc.sembrarEjemplos(empresaId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('11 notificaciones de ejemplo cargadas'),
                    backgroundColor: Colors.green.shade700,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep_outlined, color: muted),
            onPressed: () async {
              await svc.eliminarAntiguas(empresaId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Notificaciones antiguas eliminadas'),
                  backgroundColor: Colors.green.shade700,
                  behavior: SnackBarBehavior.floating,
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
            return Center(child: CircularProgressIndicator(color: accent));
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.notifications_none_outlined, size: 72,
                    color: muted.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('Sin notificaciones',
                    style: TextStyle(color: muted, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Text('Todo al día', style: TextStyle(color: muted.withValues(alpha: 0.6), fontSize: 13)),
              ]),
            );
          }

          // Agrupar: no leídas primero
          final noLeidas = items.where((n) => !n.leida).toList();
          final leidas = items.where((n) => n.leida).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              if (noLeidas.isNotEmpty) ...[
                _Seccion(label: 'NUEVAS (${noLeidas.length})', muted: muted),
                ...noLeidas.map((n) => _NotificacionItem(
                  notif: n,
                  empresaId: empresaId,
                  dark: dark,
                  surface: surface,
                  border: border,
                  texto: texto,
                  muted: muted,
                  accent: accent,
                  onTap: () async {
                    await svc.marcarLeida(empresaId, n.id);
                    if (!ctx.mounted) return;
                    _navegarAModulo(ctx, n, empresaId);
                  },
                  onDismiss: () => svc.eliminar(empresaId, n.id),
                )),
                const SizedBox(height: 8),
              ],
              if (leidas.isNotEmpty) ...[
                _Seccion(label: 'ANTERIORES', muted: muted),
                ...leidas.map((n) => _NotificacionItem(
                  notif: n,
                  empresaId: empresaId,
                  dark: dark,
                  surface: surface,
                  border: border,
                  texto: texto,
                  muted: muted,
                  accent: accent,
                  onTap: () async {
                    if (!ctx.mounted) return;
                    _navegarAModulo(ctx, n, empresaId);
                  },
                  onDismiss: () => svc.eliminar(empresaId, n.id),
                )),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Encabezado de sección ──────────────────────────────────────────────────
class _Seccion extends StatelessWidget {
  final String label;
  final Color muted;
  const _Seccion({required this.label, required this.muted});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
    child: Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
            color: muted, letterSpacing: 1.2)),
  );
}

// ── Item de notificación ──────────────────────────────────────────────────
class _NotificacionItem extends StatelessWidget {
  final NotificacionInApp notif;
  final String empresaId;
  final bool dark;
  final Color surface, border, texto, muted, accent;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificacionItem({
    required this.notif,
    required this.empresaId,
    required this.dark,
    required this.surface,
    required this.border,
    required this.texto,
    required this.muted,
    required this.accent,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notif.leida;
    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: unread ? accent.withValues(alpha: 0.06) : surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: unread ? accent.withValues(alpha: 0.3) : border,
          ),
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: unread ? accent.withValues(alpha: 0.12) : border,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(notif.tipo.emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          title: Text(notif.titulo,
              style: TextStyle(
                fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
                color: texto,
              )),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notif.cuerpo.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(notif.cuerpo,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: muted)),
              ],
              if (notif.remitenteNombre != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.person_outline, size: 11, color: muted),
                  const SizedBox(width: 3),
                  Text(notif.remitenteNombre!,
                      style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w600)),
                  if (notif.remitenteTelefono != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.phone_outlined, size: 11, color: muted),
                    const SizedBox(width: 3),
                    Text(notif.remitenteTelefono!,
                        style: TextStyle(fontSize: 11, color: muted)),
                  ],
                ]),
              ],
              const SizedBox(height: 2),
              Text(timeago.format(notif.timestamp, locale: 'es'),
                  style: TextStyle(fontSize: 10, color: muted.withValues(alpha: 0.7))),
            ],
          ),
          trailing: unread
              ? Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle))
              : Icon(Icons.chevron_right, size: 16, color: muted.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}

// ── Navegación a módulo concreto ──────────────────────────────────────────
void _navegarAModulo(BuildContext context, NotificacionInApp notif, String empresaId) async {
  // Reservas/citas con entidad → ir al detalle
  if ((notif.moduloDestino == 'reservas' || notif.moduloDestino == 'citas') &&
      notif.entidadId != null && notif.entidadId!.isNotEmpty) {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('empresas').doc(empresaId)
          .collection('reservas').doc(notif.entidadId!).get();
      if (!doc.exists) {
        doc = await FirebaseFirestore.instance
            .collection('empresas').doc(empresaId)
            .collection('citas').doc(notif.entidadId!).get();
      }
      if (!context.mounted) return;
      if (doc.exists) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetalleReservaScreen(doc: doc, empresaId: empresaId),
        ));
        return;
      }
    } catch (_) {}
  }

  if (!context.mounted) return;

  switch (notif.moduloDestino) {
    case 'reservas':
    case 'citas':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ModuloReservasScreen(empresaId: empresaId),
      ));
    case 'tareas':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ModuloTareasScreen(empresaId: empresaId),
      ));
    case 'facturacion':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ModuloFacturacionScreen(empresaId: empresaId),
      ));
    case 'clientes':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ModuloClientesScreen(empresaId: empresaId),
      ));
    case 'pedidos':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ModuloPedidosNuevoScreen(empresaId: empresaId),
      ));
    case 'empleados':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ModuloEmpleadosScreen(empresaId: empresaId),
      ));
    case 'fichajes':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => GestionFichajesScreen(empresaId: empresaId),
      ));
    case 'nominas':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ModuloNominasScreen(empresaId: empresaId),
      ));
    case 'vacaciones':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => VacacionesScreen(empresaId: empresaId),
      ));
    case 'fiscal':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CalendarioFiscalScreen(empresaId: empresaId),
      ));
    case 'web':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PantallaContenidoWeb(empresaId: empresaId),
      ));
    default:
      break;
  }
}

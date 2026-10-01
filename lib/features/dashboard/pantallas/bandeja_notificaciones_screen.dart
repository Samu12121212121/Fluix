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
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../core/widgets/fluix_bottom_nav.dart';
import '../../../core/utils/app_settings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA — Bandeja de notificaciones in-app
// ─────────────────────────────────────────────────────────────────────────────

class BandejaNotificacionesScreen extends StatelessWidget {
  final String empresaId;
  final bool esPropietario;
  const BandejaNotificacionesScreen({
    super.key,
    required this.empresaId,
    this.esPropietario = false,
  });

  @override
  Widget build(BuildContext context) {
    final svc = BandejaNotificacionesService();
    return ValueListenableBuilder<bool>(
      valueListenable: AppSettings.darkMode,
      builder: (context, dark, _) {
        final bg      = dark ? const Color(0xFF0A0F23) : Colors.white;
        final surface = dark ? const Color(0xFF1E2139) : const Color(0xFFF5F7FA);
        final border  = dark ? const Color(0xFF2A2E45) : const Color(0xFFE0E3EC);
        final texto   = dark ? Colors.white : const Color(0xFF0F172A);
        final muted   = dark ? const Color(0xFFB0B3C1) : const Color(0xFF6B7280);
        const accent  = Color(0xFF00FFC8);
        return _buildScaffold(context, svc, dark, bg, surface, border, texto, muted, accent);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, BandejaNotificacionesService svc,
      bool dark, Color bg, Color surface, Color border, Color texto, Color muted, Color accent) {
    final size = MediaQuery.of(context).size;
    final isPortraitMobile = size.shortestSide < 600 && size.height > size.width;
    return Scaffold(
      backgroundColor: bg,
      bottomNavigationBar: isPortraitMobile
          ? FluixBottomNav(empresaId: empresaId)
          : null,
      appBar: FluixAppBar(
        titulo: 'Notificaciones',
        showLeading: true,
        extraActions: [
          TextButton(
            onPressed: () => svc.marcarTodasLeidas(empresaId),
            child: const Text('Marcar leídas',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          if (esPropietario) PopupMenuButton<String>(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Herramientas de prueba',
            onSelected: (v) async {
              if (v == 'ejemplos') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Cargar notificaciones de ejemplo'),
                    content: const Text(
                        'Se crearán 11 notificaciones de ejemplo (una por cada tipo básico). '
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
                      content: const Text('11 notificaciones cargadas'),
                      backgroundColor: Colors.green.shade700,
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                }
              } else if (v == 'todos') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('🧪 Test completo'),
                    content: const Text(
                        'Se crearán 23 notificaciones — una por cada tipo conocido, '
                        'incluyendo los que normalmente solo llegan como push (suscripción, '
                        'fiscal, WhatsApp, stock, cobertura, etc.).\n\n'
                        'Úsalo para verificar cuáles aparecen y cuáles necesitan ajuste.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Lanzar test')),
                    ],
                  ),
                );
                if (ok == true && context.mounted) {
                  await svc.sembrarTodosLosTipos(empresaId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('✅ 23 notificaciones creadas — revisa cuáles llegan'),
                      backgroundColor: Colors.indigo.shade700,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                    ));
                  }
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'todos', child: ListTile(
                leading: Icon(Icons.bug_report_outlined),
                title: Text('🧪 Test completo (23 tipos)'),
                subtitle: Text('Incluye push-only, WhatsApp, stock…', style: TextStyle(fontSize: 11)),
                contentPadding: EdgeInsets.zero,
              )),
              PopupMenuDivider(),
              PopupMenuItem(value: 'ejemplos', child: ListTile(
                leading: Icon(Icons.science_outlined),
                title: Text('Cargar 11 ejemplos básicos'),
                contentPadding: EdgeInsets.zero,
              )),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
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
          if (snap.hasError) {
            final err = snap.error.toString();
            final esPermisos = err.contains('permission') || err.contains('PERMISSION_DENIED');
            final esIndice = err.contains('index') || err.contains('requires an index');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(esPermisos ? Icons.lock_outline : Icons.error_outline,
                      size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(
                    esPermisos ? 'Sin permisos para leer notificaciones'
                      : esIndice ? 'Índice de Firestore requerido'
                      : 'Error cargando notificaciones',
                    style: TextStyle(color: texto, fontWeight: FontWeight.w700, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(err, style: TextStyle(color: muted, fontSize: 11), textAlign: TextAlign.center),
                ]),
              ),
            );
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
                  onTap: () {
                    svc.marcarLeida(empresaId, n.id);
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
                  onTap: () => _navegarAModulo(ctx, n, empresaId),
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/config/planes_config.dart';
import '../../reservas/pantallas/detalle_reserva_screen.dart';

// ────────────────────────────────────────────────────────────────────────────���
// Módulos que puede mostrar el widget según el paquete contratado
// ─────────────────────────────────────────────────────────────────────────────
enum ModuloWidget {
  reservas,    // Plan Base — siempre
  clientes,    // Plan Base — siempre
  pedidos,     // Pack Tienda Online
  tareas,      // Add-on Tareas
  facturacion, // Pack Gestión
  whatsapp,    // Add-on WhatsApp
}

/// Convierte la lista de IDs de módulos activos (de PlanesConfig) al enum interno.
List<ModuloWidget> _modulosFromIds(List<String> moduloIds) {
  final result = <ModuloWidget>[];
  // Base: reservas y clientes siempre
  result.add(ModuloWidget.reservas);
  result.add(ModuloWidget.clientes);
  if (moduloIds.contains('pedidos'))     result.add(ModuloWidget.pedidos);
  if (moduloIds.contains('tareas'))      result.add(ModuloWidget.tareas);
  if (moduloIds.contains('facturacion')) result.add(ModuloWidget.facturacion);
  if (moduloIds.contains('whatsapp'))    result.add(ModuloWidget.whatsapp);
  return result;
}

class WidgetProximosDias extends StatelessWidget {
  final String empresaId;

  const WidgetProximosDias({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              _ContenidoProximosDias(empresaId: empresaId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.calendar_view_week, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Próximos 3 Días',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.6), size: 14),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget stateful que carga todo en paralelo
// ─────────────────────────────────────────────────────────────────────────────
class _ContenidoProximosDias extends StatefulWidget {
  final String empresaId;
  const _ContenidoProximosDias({required this.empresaId});

  @override
  State<_ContenidoProximosDias> createState() => _ContenidoProximosDiasState();
}

class _ContenidoProximosDiasState extends State<_ContenidoProximosDias> {
  late Future<_DatosDashboard> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = _cargarTodo();
  }

  Future<_DatosDashboard> _cargarTodo() async {
    final db = FirebaseFirestore.instance;
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    // Solo 3 días en el widget del dashboard
    final dias = List.generate(3, (i) => hoy.add(Duration(days: i)));

    // ── Leer suscripción V2 (packs_activos + addons_activos) ─────────────────
    List<ModuloWidget> modulosActivos = [ModuloWidget.reservas, ModuloWidget.clientes];
    try {
      final suscDoc = await db
          .collection('empresas').doc(widget.empresaId)
          .collection('suscripcion').doc('actual').get();
      if (suscDoc.exists) {
        final data = suscDoc.data()!;
        List<String> packsActivos;
        List<String> addonsActivos;

        if (data.containsKey('packs_activos') || data.containsKey('plan_base')) {
          // Formato V2
          packsActivos  = (data['packs_activos']  as List<dynamic>? ?? []).map((e) => e.toString()).toList();
          addonsActivos = (data['addons_activos'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
        } else {
          // Formato legacy: inferir packs/addons desde modulos_activos
          final modLegacy = (data['modulos_activos'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
          packsActivos = [
            if (modLegacy.contains('facturacion') || modLegacy.contains('vacaciones')) 'gestion',
            if (modLegacy.contains('pedidos')) 'tienda',
          ];
          addonsActivos = [
            if (modLegacy.contains('whatsapp')) 'whatsapp',
            if (modLegacy.contains('tareas')) 'tareas',
            if (modLegacy.contains('nominas')) 'nominas',
          ];
        }

        final moduloIds = PlanesConfig.getModulosActivos(
          packsActivos: packsActivos,
          addonsActivos: addonsActivos,
        );
        modulosActivos = _modulosFromIds(moduloIds);
      }
    } catch (_) {}

    final resultados = await Future.wait(dias.map((fecha) => _cargarDia(fecha, modulosActivos)));

    return _DatosDashboard(
      dias: resultados,
      modulosActivos: modulosActivos,
      paquete: 'v2',
    );
  }

  Future<_DatoDia> _cargarDia(DateTime fecha, List<ModuloWidget> modulos) async {
    final db = FirebaseFirestore.instance;
    // Usar fechas locales normalizadas para los límites de consulta
    final inicioDt = fecha; // ya es medianoche local
    final finDt = fecha.add(const Duration(days: 1));
    final inicio = Timestamp.fromDate(inicioDt);
    final fin = Timestamp.fromDate(finDt);
    final col = db.collection('empresas').doc(widget.empresaId).collection;

    int reservasConfirmadas = 0, reservasPendientes = 0, reservasCanceladas = 0;
    int pedidosPendientes = 0, pedidosNuevos = 0;
    int tareasVencen = 0;
    int clientesNuevos = 0;
    double facturacionDia = 0;
    int pedidosWhatsapp = 0;
    List<Map<String, dynamic>> reservasDetalle = [];
    List<Map<String, dynamic>> pedidosDetalle = [];
    List<Map<String, dynamic>> whatsappDetalle = [];

    // ── RESERVAS (siempre) ──────────────────────────────────────────────────
    if (modulos.contains(ModuloWidget.reservas)) {
      try {
        final snap = await col('reservas')
            .where('fecha_hora', isGreaterThanOrEqualTo: inicio)
            .where('fecha_hora', isLessThan: fin)
            .get();
        for (final d in snap.docs) {
          final data = d.data();
          final estado = (data['estado'] as String? ?? '').toUpperCase();
          if (estado == 'CONFIRMADA') reservasConfirmadas++;
          else if (estado == 'PENDIENTE') reservasPendientes++;
          else if (estado == 'CANCELADA') reservasCanceladas++;
          if (estado != 'CANCELADA') {
            // Incluir el doc ID para navegar al detalle
            reservasDetalle.add({...data, '_doc_id': d.id});
          }
        }
      } catch (_) {}
    }

    // ── PEDIDOS — usa fecha_entrega si existe, si no fecha_creacion ─────────
    if (modulos.contains(ModuloWidget.pedidos)) {
      try {
        // Pedidos con fecha_entrega en este día
        final snapEntrega = await col('pedidos')
            .where('fecha_entrega', isGreaterThanOrEqualTo: inicio)
            .where('fecha_entrega', isLessThan: fin)
            .get();
        final idsYa = <String>{};
        for (final d in snapEntrega.docs) {
          final data = d.data();
          final estado = (data['estado'] as String? ?? '').toUpperCase();
          if (estado != 'CANCELADO') {
            if (estado == 'PENDIENTE' || estado == 'NUEVO') pedidosPendientes++;
            pedidosNuevos++;
            pedidosDetalle.add(data);
            idsYa.add(d.id);
          }
        }
        // Pedidos creados hoy sin fecha_entrega
        final snapCreados = await col('pedidos')
            .where('fecha_creacion', isGreaterThanOrEqualTo: inicio)
            .where('fecha_creacion', isLessThan: fin)
            .get();
        for (final d in snapCreados.docs) {
          if (idsYa.contains(d.id)) continue;
          final data = d.data();
          if (data['fecha_entrega'] != null) continue; // ya tiene entrega en otro día
          final estado = (data['estado'] as String? ?? '').toUpperCase();
          if (estado != 'CANCELADO') {
            if (estado == 'PENDIENTE' || estado == 'NUEVO') pedidosPendientes++;
            pedidosNuevos++;
            pedidosDetalle.add(data);
          }
        }
      } catch (_) {}
    }

    // ── PEDIDOS DE WHATSAPP ────────────────────────────────────────────────
    if (modulos.contains(ModuloWidget.whatsapp)) {
      try {
        final snapWA = await col('pedidos_whatsapp')
            .where('fecha', isGreaterThanOrEqualTo: inicio)
            .where('fecha', isLessThan: fin)
            .get();
        for (final d in snapWA.docs) {
          final data = d.data();
          final estado = (data['estado'] as String? ?? '').toLowerCase();
          if (estado != 'cancelado' && estado != 'completado') {
            pedidosWhatsapp++;
            whatsappDetalle.add({...data, '_doc_id': d.id});
          }
        }
      } catch (_) {}
    }

    // ── TAREAS ──────────────────────────────────────���───────────────────────
    if (modulos.contains(ModuloWidget.tareas)) {
      try {
        final snap = await col('tareas')
            .where('fecha_limite', isGreaterThanOrEqualTo: inicio)
            .where('fecha_limite', isLessThan: fin)
            .where('completada', isEqualTo: false)
            .get();
        tareasVencen = snap.docs.length;
      } catch (_) {}
    }

    // ── CLIENTES NUEVOS ─────────────────────────────────────────────────────
    if (modulos.contains(ModuloWidget.clientes)) {
      try {
        final snap = await col('clientes')
            .where('fecha_registro', isGreaterThanOrEqualTo: inicio.toDate().toIso8601String())
            .where('fecha_registro', isLessThan: fin.toDate().toIso8601String())
            .get();
        clientesNuevos = snap.docs.length;
      } catch (_) {}
    }

    // ── FACTURACIÓN ─────────────────────────────────────────────────────────
    if (modulos.contains(ModuloWidget.facturacion)) {
      try {
        final snap = await col('facturas')
            .where('fecha_emision', isGreaterThanOrEqualTo: inicio)
            .where('fecha_emision', isLessThan: fin)
            .where('estado', isEqualTo: 'PAGADA')
            .get();
        for (final d in snap.docs) {
          facturacionDia += (d.data()['total'] as num? ?? 0).toDouble();
        }
      } catch (_) {}
    }

    return _DatoDia(
      fecha: fecha,
      reservasConfirmadas: reservasConfirmadas,
      reservasPendientes: reservasPendientes,
      reservasCanceladas: reservasCanceladas,
      pedidosPendientes: pedidosPendientes,
      pedidosNuevos: pedidosNuevos,
      tareasVencen: tareasVencen,
      clientesNuevos: clientesNuevos,
      facturacionDia: facturacionDia,
      pedidosWhatsapp: pedidosWhatsapp,
      reservasDetalle: reservasDetalle,
      pedidosDetalle: pedidosDetalle,
      whatsappDetalle: whatsappDetalle,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DatosDashboard>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }
        if (!snap.hasData) {
          return const _MensajeVacio();
        }
        return _VistaResultado(datos: snap.data!, empresaId: widget.empresaId);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vista de resultado
// ─────────────────────────────────────────────────────────────────────────────
class _VistaResultado extends StatelessWidget {
  final _DatosDashboard datos;
  final String empresaId;
  const _VistaResultado({required this.datos, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final alertas = _generarAlertas();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── 3 tarjetas principales (hoy, mañana, pasado) ────────────────
        Row(
          children: datos.dias
              .map((d) => Expanded(child: _TarjetaDia(dia: d, modulos: datos.modulosActivos, empresaId: empresaId)))
              .toList(),
        ),

        const SizedBox(height: 14),

        // ── Resumen de módulos activos ───────────────────────────────────
        _ResumenModulos(datos: datos),

        if (alertas.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...alertas.map((a) => _TarjetaAlerta(alerta: a)),
        ],
      ],
    );
  }

  List<_Alerta> _generarAlertas() {
    final alertas = <_Alerta>[];
    final modulos = datos.modulosActivos;

    for (final dia in datos.dias.take(3)) {
      final nombre = _nombreDia(dia.fecha);

      // Sin reservas
      if (modulos.contains(ModuloWidget.reservas) && dia.reservasConfirmadas == 0) {
        alertas.add(_Alerta(
          icono: Icons.calendar_today,
          color: const Color(0xFFFF5722),
          prioridad: 'URGENTE',
          titulo: '$nombre — Día sin reservas',
          descripcion: 'Considera publicar una oferta para atraer clientes.',
        ));
      }

      // Reservas pendientes
      if (modulos.contains(ModuloWidget.reservas) && dia.reservasPendientes > 0) {
        alertas.add(_Alerta(
          icono: Icons.pending_actions,
          color: const Color(0xFFF57C00),
          prioridad: 'NORMAL',
          titulo: '$nombre — ${dia.reservasPendientes} reserva${dia.reservasPendientes > 1 ? 's' : ''} pendiente${dia.reservasPendientes > 1 ? 's' : ''}',
          descripcion: 'Confírmalas o cancélalas para evitar confusiones.',
        ));
      }

      // Pedidos pendientes
      if (modulos.contains(ModuloWidget.pedidos) && dia.pedidosPendientes > 0) {
        alertas.add(_Alerta(
          icono: Icons.shopping_bag,
          color: const Color(0xFF7B1FA2),
          prioridad: 'NORMAL',
          titulo: '$nombre — ${dia.pedidosPendientes} pedido${dia.pedidosPendientes > 1 ? 's' : ''} sin gestionar',
          descripcion: 'Atiéndelos a tiempo para mantener buenas valoraciones.',
        ));
      }

      // Tareas que vencen
      if (modulos.contains(ModuloWidget.tareas) && dia.tareasVencen > 0) {
        alertas.add(_Alerta(
          icono: Icons.task_alt,
          color: const Color(0xFF1976D2),
          prioridad: 'NORMAL',
          titulo: '$nombre — ${dia.tareasVencen} tarea${dia.tareasVencen > 1 ? 's' : ''} por vencer',
          descripcion: 'Revisa las tareas pendientes para este día.',
        ));
      }
    }

    // Si todo bien
    if (alertas.isEmpty) {
      alertas.add(_Alerta(
        icono: Icons.check_circle,
        color: const Color(0xFF4CAF50),
        prioridad: 'INFO',
        titulo: 'Todo bajo control 🎉',
        descripcion: 'No hay alertas urgentes para los próximos 3 días.',
      ));
    }

    return alertas.take(4).toList(); // máximo 4 alertas
  }

  String _nombreDia(DateTime fecha) {
    final hoy = DateTime.now();
    if (fecha.day == hoy.day) return 'Hoy';
    if (fecha.day == hoy.day + 1) return 'Mañana';
    return DateFormat('EEE', 'es').format(fecha);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta individual de día
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de día principal (hoy, mañana, pasado)
// ─────────────────────────────────────────────────────────────────────────────
class _TarjetaDia extends StatelessWidget {
  final _DatoDia dia;
  final List<ModuloWidget> modulos;
  final String empresaId;

  const _TarjetaDia({required this.dia, required this.modulos, required this.empresaId});

  int get _totalEventos =>
      dia.reservasConfirmadas + dia.reservasPendientes +
      dia.pedidosNuevos + dia.pedidosWhatsapp + dia.tareasVencen;

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final esHoy = dia.fecha.day == hoy.day && dia.fecha.month == hoy.month;
    final nombre = esHoy
        ? 'Hoy'
        : dia.fecha.day == hoy.day + 1 && dia.fecha.month == hoy.month
            ? 'Mañana'
            : DateFormat('EEE', 'es').format(dia.fecha);

    Color color;
    if (_totalEventos == 0) {
      color = const Color(0xFFD32F2F);
    } else if (_totalEventos <= 2) {
      color = const Color(0xFFF57C00);
    } else {
      color = const Color(0xFF43A047);
    }

    return GestureDetector(
      onTap: () => _mostrarDetalleDia(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: esHoy
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: esHoy
              ? Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(nombre, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            Text(DateFormat('dd/MM').format(dia.fecha), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10)),
            const SizedBox(height: 8),
            // Círculo principal — total eventos
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  '$_totalEventos',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('eventos', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9)),
            const SizedBox(height: 6),
            // Chips mini por tipo
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 3,
              runSpacing: 3,
              children: [
                if (dia.reservasConfirmadas > 0)
                  _MiniChip(valor: '${dia.reservasConfirmadas}📅', color: const Color(0xFF43A047)),
                if (dia.reservasPendientes > 0)
                  _MiniChip(valor: '${dia.reservasPendientes}⏳', color: const Color(0xFFF57C00)),
                if (modulos.contains(ModuloWidget.pedidos) && dia.pedidosNuevos > 0)
                  _MiniChip(valor: '${dia.pedidosNuevos}📦', color: const Color(0xFF7B1FA2)),
                if (modulos.contains(ModuloWidget.whatsapp) && dia.pedidosWhatsapp > 0)
                  _MiniChip(valor: '${dia.pedidosWhatsapp}💬', color: const Color(0xFF25D366)),
                if (modulos.contains(ModuloWidget.tareas) && dia.tareasVencen > 0)
                  _MiniChip(valor: '${dia.tareasVencen}✅', color: const Color(0xFF1976D2)),
                if (modulos.contains(ModuloWidget.facturacion) && dia.facturacionDia > 0)
                  _MiniChip(valor: '€${dia.facturacionDia.toStringAsFixed(0)}', color: const Color(0xFF388E3C)),
              ],
            ),
            const SizedBox(height: 4),
            // Indicador de que es clickable
            Icon(Icons.touch_app, size: 12, color: Colors.white.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  void _mostrarDetalleDia(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleDiaSheet(dia: dia, modulos: modulos, empresaId: empresaId),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resumen de módulos activos (fila de KPIs)
// ─────────────────────────────────────────────────────────────────────────────
class _ResumenModulos extends StatelessWidget {
  final _DatosDashboard datos;
  const _ResumenModulos({required this.datos});

  @override
  Widget build(BuildContext context) {
    final modulos = datos.modulosActivos;
    final totales = _calcularTotales();
    final items = <_KpiItem>[];

    if (modulos.contains(ModuloWidget.reservas)) {
      items.add(_KpiItem('Eventos', '${totales['reservas']}', Icons.calendar_today, const Color(0xFF42A5F5)));
    }
    if (modulos.contains(ModuloWidget.pedidos)) {
      items.add(_KpiItem('Pedidos', '${totales['pedidos']}', Icons.shopping_bag, const Color(0xFFAB47BC)));
    }
    if (modulos.contains(ModuloWidget.whatsapp)) {
      items.add(_KpiItem('WhatsApp', '${totales['whatsapp']}', Icons.chat_bubble, const Color(0xFF25D366)));
    }
    if (modulos.contains(ModuloWidget.tareas)) {
      items.add(_KpiItem('Tareas', '${totales['tareas']}', Icons.task_alt, const Color(0xFF42A5F5)));
    }
    if (modulos.contains(ModuloWidget.clientes)) {
      items.add(_KpiItem('Clientes nuevos', '${totales['clientes']}', Icons.person_add, const Color(0xFF66BB6A)));
    }
    if (modulos.contains(ModuloWidget.facturacion)) {
      items.add(_KpiItem('Facturado', '€${(totales['facturacion'] as double).toStringAsFixed(0)}', Icons.receipt, const Color(0xFF26A69A)));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) => _buildKpi(item)).toList(),
      ),
    );
  }

  Widget _buildKpi(_KpiItem item) {
    return Column(
      children: [
        Icon(item.icono, color: item.color, size: 16),
        const SizedBox(height: 4),
        Text(item.valor, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        Text(item.label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9), textAlign: TextAlign.center),
      ],
    );
  }

  Map<String, dynamic> _calcularTotales() {
    int reservas = 0, pedidos = 0, tareas = 0, clientes = 0, whatsapp = 0;
    double facturacion = 0;
    for (final d in datos.dias) {
      reservas += d.reservasConfirmadas + d.reservasPendientes;
      pedidos += d.pedidosNuevos;
      whatsapp += d.pedidosWhatsapp;
      tareas += d.tareasVencen;
      clientes += d.clientesNuevos;
      facturacion += d.facturacionDia;
    }
    return {
      'reservas': reservas,
      'pedidos': pedidos,
      'whatsapp': whatsapp,
      'tareas': tareas,
      'clientes': clientes,
      'facturacion': facturacion
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de alerta / recomendación
// ─────────────────────────────────────────────────────────────────────────────
class _TarjetaAlerta extends StatelessWidget {
  final _Alerta alerta;
  const _TarjetaAlerta({required this.alerta});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: alerta.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: alerta.color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: alerta.color, borderRadius: BorderRadius.circular(6)),
            child: Icon(alerta.icono, color: Colors.white, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alerta.titulo, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(alerta.descripcion, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: alerta.color, borderRadius: BorderRadius.circular(8)),
            child: Text(alerta.prioridad, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers UI
// ─────────────────────────────────────────────────────────────────────────────
class _MiniChip extends StatelessWidget {
  final String valor;
  final Color color;
  const _MiniChip({required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(6)),
      child: Text(valor, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
    );
  }
}

class _MensajeVacio extends StatelessWidget {
  const _MensajeVacio();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Column(
        children: [
          Icon(Icons.calendar_month, color: Colors.white60, size: 36),
          SizedBox(height: 8),
          Text('No se pudieron cargar los datos', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet de detalle del día
// ─────────────────────────────────────────────────────────────────────────────
class _DetalleDiaSheet extends StatelessWidget {
  final _DatoDia dia;
  final List<ModuloWidget> modulos;
  final String empresaId;

  const _DetalleDiaSheet({required this.dia, required this.modulos, required this.empresaId});

  String get _nombreDia {
    final hoy = DateTime.now();
    if (dia.fecha.day == hoy.day && dia.fecha.month == hoy.month) return 'Hoy';
    if (dia.fecha.day == hoy.day + 1 && dia.fecha.month == hoy.month) return 'Mañana';
    return DateFormat('EEEE d \'de\' MMMM', 'es').format(dia.fecha);
  }

  int get _totalEventos =>
      dia.reservasConfirmadas + dia.reservasPendientes +
      dia.pedidosNuevos + dia.pedidosWhatsapp + dia.tareasVencen;

  @override
  Widget build(BuildContext context) {
    // Combinar reservas + pedidos + whatsapp ordenados por hora
    final eventos = <_EventoDia>[
      ..._reservasComoEventos(),
      ..._pedidosComoEventos(),
      ..._whatsappComoEventos(),
    ];
    eventos.sort((a, b) => a.hora.compareTo(b.hora));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nombreDia.toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 1)),
                    Text('$_totalEventos evento${_totalEventos != 1 ? 's' : ''}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _totalEventos == 0 ? const Color(0xFFD32F2F)
                      : _totalEventos <= 2 ? const Color(0xFFF57C00)
                      : const Color(0xFF43A047),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text('$_totalEventos',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Lista de eventos reales
          if (eventos.isEmpty)
            _filaVacia()
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: eventos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _navegarAEvento(context, eventos[i]),
                  child: _tarjetaEvento(eventos[i]),
                ),
              ),
            ),

          const SizedBox(height: 12),
          // Resumen extras (tareas, clientes, facturación)
          if (modulos.contains(ModuloWidget.tareas) && dia.tareasVencen > 0)
            _filaResumen(Icons.task_alt, const Color(0xFF1976D2),
                '${dia.tareasVencen} tarea${dia.tareasVencen > 1 ? 's' : ''} con fecha límite hoy'),
          if (modulos.contains(ModuloWidget.clientes) && dia.clientesNuevos > 0)
            _filaResumen(Icons.person_add, const Color(0xFF66BB6A),
                '${dia.clientesNuevos} cliente${dia.clientesNuevos > 1 ? 's' : ''} nuevo${dia.clientesNuevos > 1 ? 's' : ''}'),
          if (modulos.contains(ModuloWidget.facturacion) && dia.facturacionDia > 0)
            _filaResumen(Icons.receipt_long, const Color(0xFF26A69A),
                'Facturación: €${dia.facturacionDia.toStringAsFixed(2)}'),

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              label: const Text('Cerrar'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_EventoDia> _reservasComoEventos() {
    return dia.reservasDetalle.map((data) {
      DateTime hora;
      try {
        final raw = data['fecha_hora'] ?? data['fecha'];
        hora = raw is Timestamp ? raw.toDate() : DateTime.parse(raw.toString());
      } catch (_) {
        hora = dia.fecha;
      }
      final cliente = data['nombre_cliente'] as String? ?? 'Sin nombre';
      final servicio = data['servicio'] as String? ?? '';
      final personasRaw = data['personas'] ?? data['num_personas'];
      final estado = (data['estado'] as String? ?? '').toUpperCase();
      final telefono = data['telefono_cliente'] as String? ?? '';
      final correo = data['correo_cliente'] as String? ?? '';
      final numero = data['numero'] as String?;

      // Convertir personas a int de forma segura
      int? personas;
      if (personasRaw != null) {
        if (personasRaw is num) {
          personas = personasRaw.toInt();
        } else if (personasRaw is String) {
          personas = int.tryParse(personasRaw);
        }
      }

      String descripcion = servicio.isNotEmpty ? servicio : 'Reserva';
      if (personas != null) descripcion += ' para $personas personas';

      Color color;
      if (estado == 'CONFIRMADA') color = const Color(0xFF43A047);
      else if (estado == 'PENDIENTE') color = const Color(0xFFF57C00);
      else color = Colors.grey;

      return _EventoDia(
        hora: hora,
        icono: Icons.event_available,
        color: color,
        titulo: cliente,
        subtitulo: descripcion,
        horaTexto: DateFormat('HH:mm').format(hora),
        badge: estado,
        badgeColor: color,
        telefono: telefono.isNotEmpty ? telefono : null,
        correo: correo.isNotEmpty ? correo : null,
        comensales: personas,
        numero: numero,
        docId: data['_doc_id'] as String?,
        esReserva: true,
      );
    }).toList();
  }

  List<_EventoDia> _pedidosComoEventos() {
    return dia.pedidosDetalle.map((data) {
      DateTime hora;
      try {
        final rawEntrega = data['fecha_entrega'];
        final rawCreacion = data['fecha_creacion'];
        if (rawEntrega != null) {
          hora = rawEntrega is Timestamp ? rawEntrega.toDate() : DateTime.parse(rawEntrega.toString());
        } else {
          hora = rawCreacion is Timestamp ? rawCreacion.toDate() : DateTime.parse(rawCreacion.toString());
        }
      } catch (_) {
        hora = dia.fecha;
      }

      final cliente = data['cliente_nombre'] as String? ?? 'Sin nombre';
      final lineas = data['lineas'] as List<dynamic>? ?? [];
      final estado = (data['estado'] as String? ?? '').toUpperCase();
      final origen = data['origen'] as String? ?? '';
      final tieneEntrega = data['fecha_entrega'] != null;

      // Descripción: primer producto (y cuántos más)
      String descripcion = '';
      if (lineas.isNotEmpty) {
        final primera = lineas.first as Map<String, dynamic>? ?? {};
        final nombre = primera['producto_nombre'] as String? ?? 'Producto';
        final cantidad = primera['cantidad'] ?? 1;
        descripcion = '${cantidad}x $nombre';
        if (lineas.length > 1) descripcion += ' (+${lineas.length - 1} más)';
      }
      if (origen == 'whatsapp') descripcion = '💬 $descripcion';
      if (tieneEntrega) descripcion += ' — a recoger';

      return _EventoDia(
        hora: hora,
        icono: Icons.shopping_bag,
        color: const Color(0xFF7B1FA2),
        titulo: cliente,
        subtitulo: descripcion,
        horaTexto: DateFormat('HH:mm').format(hora),
        badge: estado,
        badgeColor: estado == 'PENDIENTE' ? const Color(0xFFF57C00) : const Color(0xFF7B1FA2),
      );
    }).toList();
  }

  List<_EventoDia> _whatsappComoEventos() {
    return dia.whatsappDetalle.map((data) {
      DateTime hora;
      try {
        final raw = data['fecha'];
        hora = raw is Timestamp ? raw.toDate() : DateTime.parse(raw.toString());
      } catch (_) {
        hora = dia.fecha;
      }

      final clienteNombre = data['cliente_nombre'] as String? ?? 'Sin nombre';
      final clienteTelefono = data['cliente_telefono'] as String? ?? '';
      final resumen = data['pedido_resumen'] as String? ?? 'Pedido por WhatsApp';
      final estado = (data['estado'] as String? ?? '').toUpperCase();

      return _EventoDia(
        hora: hora,
        icono: Icons.chat_bubble,
        color: const Color(0xFF25D366),
        titulo: clienteNombre,
        subtitulo: '💬 $resumen',
        horaTexto: DateFormat('HH:mm').format(hora),
        badge: estado,
        badgeColor: estado == 'PENDIENTE' ? const Color(0xFFF57C00) : const Color(0xFF25D366),
        telefono: clienteTelefono.isNotEmpty ? clienteTelefono : null,
      );
    }).toList();
  }

  Widget _tarjetaEvento(_EventoDia e) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: e.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: e.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila principal: hora, icono, título y badge
          Row(
            children: [
              // Hora
              SizedBox(
                width: 42,
                child: Column(
                  children: [
                    Text(e.horaTexto,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: e.color)),
                  ],
                ),
              ),
              Container(width: 1, height: 36, color: e.color.withValues(alpha: 0.3),
                  margin: const EdgeInsets.symmetric(horizontal: 10)),
              // Icono
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: e.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(e.icono, color: e.color, size: 18),
              ),
              const SizedBox(width: 10),
              // Texto principal
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (e.subtitulo.isNotEmpty)
                      Text(e.subtitulo,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              // Badge estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: e.badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(e.badge,
                    style: TextStyle(color: e.badgeColor, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
              // Flecha si es navegable
              if (e.docId != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 12, color: e.color.withValues(alpha: 0.5)),
              ],
            ],
          ),
          // Información adicional (teléfono, correo, comensales) si está disponible
          if (e.telefono != null || e.correo != null || e.comensales != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if (e.comensales != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people, size: 13, color: Colors.grey[600]),
                        const SizedBox(width: 3),
                        Text('${e.comensales} personas',
                            style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      ],
                    ),
                  if (e.telefono != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone, size: 13, color: Colors.grey[600]),
                        const SizedBox(width: 3),
                        Text(e.telefono!,
                            style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      ],
                    ),
                  if (e.correo != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.email, size: 13, color: Colors.grey[600]),
                        const SizedBox(width: 3),
                        Text(e.correo!,
                            style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filaResumen(IconData icono, Color color, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 8),
          Text(texto, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ],
      ),
    );
  }

  void _navegarAEvento(BuildContext context, _EventoDia evento) async {
    // Si es una reserva/cita y tenemos docId, navegar a detalle
    if (evento.docId != null && evento.esReserva) {
      try {
        debugPrint('🔍 Navegando a evento: ${evento.docId}');
        debugPrint('   Título: ${evento.titulo}');
        debugPrint('   Es reserva: ${evento.esReserva}');
        
        // Verificar primero en 'reservas'
        var doc = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(empresaId)
            .collection('reservas')
            .doc(evento.docId!)
            .get();
        
        // Si no existe, intentar en 'citas'
        if (!doc.exists) {
          debugPrint('⚠️ No encontrado en reservas, intentando en citas...');
          doc = await FirebaseFirestore.instance
              .collection('empresas')
              .doc(empresaId)
              .collection('citas')
              .doc(evento.docId!)
              .get();
        }
        
        if (!context.mounted) return;
        if (doc.exists) {
          debugPrint('✅ Documento encontrado, navegando a DetalleReservaScreen');
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleReservaScreen(
                doc: doc,
                empresaId: empresaId,
              ),
            ),
          );
        } else {
          debugPrint('❌ Documento no encontrado en reservas ni citas');
        }
      } catch (e) {
        debugPrint('❌ Error navegando a evento: $e');
      }
    } else {
      debugPrint('⚠️ No se puede navegar: docId=${evento.docId}, esReserva=${evento.esReserva}');
    }
  }

  Widget _filaVacia() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.event_available, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Sin eventos programados',
              style: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Aprovecha para publicar una oferta o crear una reserva',
              style: TextStyle(color: Colors.grey[400], fontSize: 12), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelos de datos
// ─────────────────────────────────────────────────────────────────────────────
class _DatosDashboard {
  final List<_DatoDia> dias;
  final List<ModuloWidget> modulosActivos;
  final String paquete;
  _DatosDashboard({required this.dias, required this.modulosActivos, required this.paquete});
}

class _DatoDia {
  final DateTime fecha;
  final int reservasConfirmadas;
  final int reservasPendientes;
  final int reservasCanceladas;
  final int pedidosPendientes;
  final int pedidosNuevos;
  final int pedidosWhatsapp;
  final int tareasVencen;
  final int clientesNuevos;
  final double facturacionDia;
  final List<Map<String, dynamic>> reservasDetalle;
  final List<Map<String, dynamic>> pedidosDetalle;
  final List<Map<String, dynamic>> whatsappDetalle;

  _DatoDia({
    required this.fecha,
    required this.reservasConfirmadas,
    required this.reservasPendientes,
    required this.reservasCanceladas,
    required this.pedidosPendientes,
    required this.pedidosNuevos,
    required this.pedidosWhatsapp,
    required this.tareasVencen,
    required this.clientesNuevos,
    required this.facturacionDia,
    this.reservasDetalle = const [],
    this.pedidosDetalle = const [],
    this.whatsappDetalle = const [],
  });
}

class _Alerta {
  final IconData icono;
  final Color color;
  final String prioridad;
  final String titulo;
  final String descripcion;
  _Alerta({required this.icono, required this.color, required this.prioridad, required this.titulo, required this.descripcion});
}

class _KpiItem {
  final String label;
  final String valor;
  final IconData icono;
  final Color color;
  _KpiItem(this.label, this.valor, this.icono, this.color);
}

class _EventoDia {
  final DateTime hora;
  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final String horaTexto;
  final String badge;
  final Color badgeColor;
  final String? telefono;
  final String? correo;
  final int? comensales;
  final String? numero;
  final String? docId;
  final bool esReserva;

  _EventoDia({
    required this.hora,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.horaTexto,
    required this.badge,
    required this.badgeColor,
    this.telefono,
    this.correo,
    this.comensales,
    this.numero,
    this.docId,
    this.esReserva = false,
  });
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/flash_slot_model.dart';
import '../../../services/flash_slot_service.dart';
import 'pantalla_crear_flash_slot.dart';

class _P {
  static const fondo      = Color(0xFF0A0F23);
  static const superficie = Color(0xFF151932);
  static const tarjeta    = Color(0xFF1E2139);
  static const borde      = Color(0xFF2A2E45);
  static const flash      = Color(0xFFFFBB00);
  static const flashBg    = Color(0xFF3D2E00);
  static const accent     = Color(0xFF00FFC8);
  static const rosa       = Color(0xFFFF3296);
  static const rojo       = Color(0xFFFF2850);
  static const texto      = Color(0xFFFFFFFF);
  static const textoMuted = Color(0xFFB0B3C1);
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA GESTIÓN FLASH SLOTS (vista NEGOCIO)
// ─────────────────────────────────────────────────────────────────────────────
class PantallaGestionFlashSlots extends StatelessWidget {
  final String negocioId;
  final String negocioNombre;
  final String empresaId;
  final String? negocioFotoUrl;

  const PantallaGestionFlashSlots({
    super.key,
    required this.negocioId,
    required this.negocioNombre,
    required this.empresaId,
    this.negocioFotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _P.fondo,
        appBar: AppBar(
          backgroundColor: _P.superficie,
          foregroundColor: _P.texto,
          elevation: 0,
          title: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _P.flash, borderRadius: BorderRadius.circular(6),
              ),
              child: Text('⚡', style: TextStyle(fontSize: 14, color: _P.fondo)),
            ),
            const SizedBox(width: 10),
            const Text('Flash Slots', style: TextStyle(fontSize: 17)),
          ]),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              color: _P.flash,
              tooltip: 'Crear flash slot',
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => PantallaCrearFlashSlot(
                  negocioId:     negocioId,
                  negocioNombre: negocioNombre,
                  empresaId:     empresaId,
                  negocioFotoUrl: negocioFotoUrl,
                ),
              )),
            ),
          ],
          bottom: TabBar(
            labelColor: _P.flash,
            unselectedLabelColor: _P.textoMuted,
            indicatorColor: _P.flash,
            indicatorWeight: 2,
            tabs: const [
              Tab(text: 'Activos'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: TabBarView(children: [
          _TabActivos(negocioId: negocioId),
          _TabHistorial(negocioId: negocioId),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => PantallaCrearFlashSlot(
              negocioId:     negocioId,
              negocioNombre: negocioNombre,
              empresaId:     empresaId,
              negocioFotoUrl: negocioFotoUrl,
            ),
          )),
          backgroundColor: _P.flash,
          foregroundColor: _P.fondo,
          icon: const Text('⚡', style: TextStyle(fontSize: 16)),
          label: const Text('Nuevo flash slot',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB ACTIVOS
// ─────────────────────────────────────────────────────────────────────────────
class _TabActivos extends StatelessWidget {
  final String negocioId;
  const _TabActivos({required this.negocioId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FlashSlotModel>>(
      stream: FlashSlotService.escucharActivos(negocioId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _P.flash));
        }
        final slots = snap.data ?? [];
        if (slots.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('⚡', style: TextStyle(fontSize: 56,
                  color: _P.flash.withValues(alpha: 0.3))),
              const SizedBox(height: 16),
              const Text('Sin slots activos',
                  style: TextStyle(color: _P.texto, fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Crea un flash slot para llenar tus huecos',
                  style: TextStyle(color: _P.textoMuted, fontSize: 13)),
            ],
          ));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: slots.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (ctx, i) => _CardSlotActivo(
            slot: slots[i], negocioId: negocioId),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD SLOT ACTIVO (con countdown)
// ─────────────────────────────────────────────────────────────────────────────
class _CardSlotActivo extends StatefulWidget {
  final FlashSlotModel slot;
  final String negocioId;
  const _CardSlotActivo({required this.slot, required this.negocioId});

  @override
  State<_CardSlotActivo> createState() => _CardSlotActivoState();
}

class _CardSlotActivoState extends State<_CardSlotActivo> {
  late Timer _timer;
  late Duration _restante;

  @override
  void initState() {
    super.initState();
    _restante = widget.slot.tiempoRestante;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _restante = widget.slot.tiempoRestante);
    });
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _P.tarjeta,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _restante.inMinutes < 30
              ? _P.rojo.withValues(alpha: 0.5)
              : _P.flash.withValues(alpha: 0.35),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: _P.flashBg, borderRadius: BorderRadius.circular(6)),
            child: const Text('⚡ ACTIVO',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    color: _P.flash)),
          ),
          const Spacer(),
          _CountdownBadge(restante: _restante),
        ]),
        const SizedBox(height: 10),

        // Servicio y precio
        Text(slot.servicioNombre, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: _P.texto)),
        const SizedBox(height: 3),
        Row(children: [
          Text('€${slot.precioFinal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                  color: _P.flash)),
          const SizedBox(width: 8),
          Text('€${slot.precioOriginal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: _P.textoMuted,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: _P.textoMuted)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: _P.rosa.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4)),
            child: Text(slot.descuentoTexto,
                style: const TextStyle(fontSize: 10, color: _P.rosa,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),

        // Barra de ocupación
        _BarraOcupacion(slot: slot),
        const SizedBox(height: 12),

        // Fecha hueco
        Row(children: [
          const Icon(Icons.schedule_rounded, size: 13, color: _P.textoMuted),
          const SizedBox(width: 4),
          Text(_formatFecha(slot.fechaHoraInicio),
              style: const TextStyle(fontSize: 11, color: _P.textoMuted)),
        ]),
        const SizedBox(height: 10),

        // Botón cancelar
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _confirmarCancelar(context),
            icon: const Icon(Icons.cancel_outlined, size: 14, color: _P.rojo),
            label: const Text('Cancelar slot',
                style: TextStyle(fontSize: 12, color: _P.rojo)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
        ),
      ]),
    );
  }

  Future<void> _confirmarCancelar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _P.tarjeta,
        title: const Text('Cancelar flash slot', style: TextStyle(color: _P.texto)),
        content: const Text(
            '¿Seguro que quieres cancelar este slot? Los clientes que lo tenían reservado serán notificados.',
            style: TextStyle(color: _P.textoMuted, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: _P.textoMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: _P.rojo, elevation: 0),
            child: const Text('Cancelar slot', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await FlashSlotService.cancelarSlot(widget.negocioId, widget.slot.id);
    }
  }

  String _formatFecha(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB HISTORIAL
// ─────────────────────────────────────────────────────────────────────────────
class _TabHistorial extends StatelessWidget {
  final String negocioId;
  const _TabHistorial({required this.negocioId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FlashSlotModel>>(
      stream: FlashSlotService.escucharHistorial(negocioId),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _P.flash));
        }
        final todos = snap.data ?? [];
        // Excluir activos del historial (ya se ven en tab activos)
        final historial = todos
            .where((s) => s.estado != EstadoFlashSlot.activo)
            .toList();

        if (historial.isEmpty) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('📊', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('Sin historial aún', style: TextStyle(
                  color: _P.texto, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Aquí verás las métricas de tus slots pasados',
                  style: TextStyle(color: _P.textoMuted, fontSize: 13)),
            ]),
          );
        }

        // Métricas globales
        final totalSlots  = historial.length;
        final totalHuecos = historial.fold(0, (s, h) => s + h.huecosTotal);
        final totalReserv = historial.fold(0, (s, h) => s + h.huecosReservados);
        final totalIngresos = historial.fold(
            0.0, (s, h) => s + h.huecosReservados * h.precioFinal);
        final pctOcup = totalHuecos > 0
            ? (totalReserv / totalHuecos * 100).toStringAsFixed(1)
            : '0';

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // MÉTRICAS GLOBALES
            _ResumenMetricas(
              totalSlots:    totalSlots,
              totalHuecos:   totalHuecos,
              totalReservas: totalReserv,
              pctOcupacion:  pctOcup,
              ingresos:      totalIngresos,
            ),
            const SizedBox(height: 16),
            const Text('Detalle por slot',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: _P.textoMuted)),
            const SizedBox(height: 10),
            ...historial.map((s) => _CardHistorial(slot: s)),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESUMEN MÉTRICAS
// ─────────────────────────────────────────────────────────────────────────────
class _ResumenMetricas extends StatelessWidget {
  final int totalSlots, totalHuecos, totalReservas;
  final String pctOcupacion;
  final double ingresos;

  const _ResumenMetricas({
    required this.totalSlots, required this.totalHuecos,
    required this.totalReservas, required this.pctOcupacion,
    required this.ingresos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _P.flashBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.flash.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('⚡', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          const Text('Resumen global', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: _P.flash)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _MetricaBox(label: 'Slots publicados', valor: '$totalSlots'),
          const SizedBox(width: 8),
          _MetricaBox(label: 'Huecos ofrecidos', valor: '$totalHuecos'),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _MetricaBox(label: 'Reservas generadas', valor: '$totalReservas'),
          const SizedBox(width: 8),
          _MetricaBox(label: '% Ocupación', valor: '$pctOcupacion%',
              highlight: true),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _P.tarjeta, borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.euro_outlined, size: 16, color: _P.flash),
            const SizedBox(width: 6),
            Text('Ingresos estimados: €${ingresos.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                    color: _P.flash)),
          ]),
        ),
      ]),
    );
  }
}

class _MetricaBox extends StatelessWidget {
  final String label, valor;
  final bool highlight;
  const _MetricaBox({required this.label, required this.valor,
    this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? _P.flash.withValues(alpha: 0.12)
            : _P.tarjeta,
        borderRadius: BorderRadius.circular(10),
        border: highlight ? Border.all(color: _P.flash.withValues(alpha: 0.3)) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(
            fontSize: 10, color: highlight ? _P.flash : _P.textoMuted)),
        const SizedBox(height: 4),
        Text(valor, style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w800,
            color: highlight ? _P.flash : _P.texto)),
      ]),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD HISTORIAL
// ─────────────────────────────────────────────────────────────────────────────
class _CardHistorial extends StatelessWidget {
  final FlashSlotModel slot;
  const _CardHistorial({required this.slot});

  @override
  Widget build(BuildContext context) {
    final pct = (slot.porcentajeOcupacion * 100).toInt();
    final ingresos = slot.huecosReservados * slot.precioFinal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _P.tarjeta, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(slot.servicioNombre, style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: _P.texto)),
          ),
          _EstadoBadge(estado: slot.estado),
        ]),
        const SizedBox(height: 8),

        // Precios
        Row(children: [
          Text('€${slot.precioFinal.toStringAsFixed(2)} flash',
              style: const TextStyle(fontSize: 12, color: _P.flash,
                  fontWeight: FontWeight.w600)),
          const Text(' · ', style: TextStyle(color: _P.borde)),
          Text('€${slot.precioOriginal.toStringAsFixed(2)} original',
              style: const TextStyle(fontSize: 11, color: _P.textoMuted,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: _P.textoMuted)),
        ]),
        const SizedBox(height: 10),

        // Métricas
        Row(children: [
          _MiniMetrica(label: 'Huecos', val: '${slot.huecosReservados}/${slot.huecosTotal}'),
          const SizedBox(width: 12),
          _MiniMetrica(label: 'Ocupación', val: '$pct%',
              color: pct >= 80 ? _P.accent : pct >= 50 ? _P.flash : _P.rojo),
          const SizedBox(width: 12),
          _MiniMetrica(label: 'Ingresos', val: '€${ingresos.toStringAsFixed(2)}',
              color: _P.flash),
        ]),
        const SizedBox(height: 8),

        // Barra de ocupación
        _BarraOcupacion(slot: slot, compact: true),
        const SizedBox(height: 8),

        Text(_formatFecha(slot.creadoAt),
            style: const TextStyle(fontSize: 10, color: _P.textoMuted)),
      ]),
    );
  }

  String _formatFecha(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

class _MiniMetrica extends StatelessWidget {
  final String label, val;
  final Color? color;
  const _MiniMetrica({required this.label, required this.val, this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: _P.textoMuted)),
      Text(val, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: color ?? _P.texto)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS REUTILIZABLES
// ─────────────────────────────────────────────────────────────────────────────

class _CountdownBadge extends StatelessWidget {
  final Duration restante;
  const _CountdownBadge({required this.restante});

  @override
  Widget build(BuildContext context) {
    if (restante.isNegative) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: _P.rojo.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6)),
        child: const Text('Expirado',
            style: TextStyle(fontSize: 10, color: _P.rojo, fontWeight: FontWeight.w700)),
      );
    }
    final h = restante.inHours;
    final m = restante.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = restante.inSeconds.remainder(60).toString().padLeft(2, '0');
    final urgente = restante.inMinutes < 30;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: urgente ? _P.rojo.withValues(alpha: 0.15)
            : _P.flash.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer_outlined, size: 11,
            color: urgente ? _P.rojo : _P.flash),
        const SizedBox(width: 3),
        Text(h > 0 ? '${h}h ${m}m' : '${m}m ${s}s',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: urgente ? _P.rojo : _P.flash)),
      ]),
    );
  }
}

class _BarraOcupacion extends StatelessWidget {
  final FlashSlotModel slot;
  final bool compact;
  const _BarraOcupacion({required this.slot, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final pct = slot.porcentajeOcupacion;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!compact) ...[
        Row(children: [
          Icon(Icons.people_outline_rounded, size: 12, color: _P.textoMuted),
          const SizedBox(width: 4),
          Text('${slot.huecosReservados} de ${slot.huecosTotal} huecos ocupados',
              style: const TextStyle(fontSize: 11, color: _P.textoMuted)),
        ]),
        const SizedBox(height: 5),
      ],
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct, minHeight: compact ? 4 : 6,
          backgroundColor: _P.borde,
          valueColor: AlwaysStoppedAnimation<Color>(
            pct >= 0.8 ? _P.rojo : pct >= 0.5 ? _P.flash : _P.accent,
          ),
        ),
      ),
    ]);
  }
}

class _EstadoBadge extends StatelessWidget {
  final EstadoFlashSlot estado;
  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    Color color;
    String texto;
    switch (estado) {
      case EstadoFlashSlot.activo:
        color = _P.accent; texto = '● Activo'; break;
      case EstadoFlashSlot.completo:
        color = _P.flash; texto = '✓ Completo'; break;
      case EstadoFlashSlot.expirado:
        color = _P.textoMuted; texto = '⏱ Expirado'; break;
      case EstadoFlashSlot.cancelado:
        color = _P.rojo; texto = '✕ Cancelado'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(texto, style: TextStyle(
          fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}


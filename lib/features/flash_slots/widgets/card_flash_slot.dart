import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/flash_slot_model.dart';
import '../../../services/flash_slot_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETA
// ─────────────────────────────────────────────────────────────────────────────
class _K {
  static const fondo      = Color(0xFF0A0F23);
  static const superficie = Color(0xFF151932);
  static const tarjeta    = Color(0xFF1E2139);
  static const borde      = Color(0xFF2A2E45);
  static const flash      = Color(0xFFFFBB00); // Ámbar flash
  static const flashOscuro= Color(0xFF3D2E00);
  static const accentCian = Color(0xFF00FFC8);
  static const rosa       = Color(0xFFFF3296);
  static const texto      = Color(0xFFFFFFFF);
  static const textoMuted = Color(0xFFB0B3C1);
  static const rojo       = Color(0xFFFF2850);
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD FLASH SLOT — con countdown en tiempo real
// ─────────────────────────────────────────────────────────────────────────────
class CardFlashSlot extends StatefulWidget {
  final FlashSlotModel slot;
  /// Callback al reservar con éxito
  final VoidCallback? onReservado;

  const CardFlashSlot({super.key, required this.slot, this.onReservado});

  @override
  State<CardFlashSlot> createState() => _CardFlashSlotState();
}

class _CardFlashSlotState extends State<CardFlashSlot>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late Duration _restante;
  bool _reservando = false;

  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _restante = widget.slot.tiempoRestante;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _restante = widget.slot.tiempoRestante);
    });

    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_animCtrl);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _timer.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  bool get _disponible =>
      !widget.slot.estaLleno && !widget.slot.haExpirado &&
      widget.slot.estado == EstadoFlashSlot.activo;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: GestureDetector(
        onTap: _disponible ? _mostrarDetalleYReservar : null,
        child: Container(
          width: 280,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: _K.tarjeta,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _disponible ? _K.flash.withValues(alpha: 0.5) : _K.borde,
              width: _disponible ? 1.5 : 1,
            ),
            boxShadow: _disponible ? [
              BoxShadow(
                color: _K.flash.withValues(alpha: 0.12),
                blurRadius: 16, spreadRadius: 2,
              ),
            ] : [],
          ),
          child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildFotoHeader(),
              _buildInfo(),
            ]),
            if (!_disponible) _buildOverlayNoDisponible(),
          ]),
        ),
      ),
    );
  }

  // ── FOTO HEADER ──────────────────────────────────────────────────
  Widget _buildFotoHeader() {
    return Stack(children: [
      // Foto
      ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        child: SizedBox(
          height: 110, width: double.infinity,
          child: widget.slot.negocioFotoUrl != null
              ? Image.network(widget.slot.negocioFotoUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fotoPlaceholder())
              : _fotoPlaceholder(),
        ),
      ),
      // Gradiente de oscurecimiento
      Container(
        height: 110,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, _K.tarjeta.withValues(alpha: 0.85)],
          ),
        ),
      ),
      // Badge ⚡
      Positioned(top: 10, left: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _K.flash, borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('⚡', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text('FLASH',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                  color: _K.fondo, letterSpacing: 0.5)),
          ]),
        ),
      ),
      // Descuento badge
      Positioned(top: 10, right: 10,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _K.rosa, borderRadius: BorderRadius.circular(8),
          ),
          child: Text(widget.slot.descuentoTexto,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ),
      ),
      // Nombre negocio (bottom)
      Positioned(bottom: 8, left: 12, right: 12,
        child: Text(widget.slot.negocioNombre,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: Colors.white),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ]);
  }

  // ── INFO ─────────────────────────────────────────────────────────
  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Servicio
        Text(widget.slot.servicioNombre,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                color: _K.texto),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),

        // Precios
        Row(crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic, children: [
          Text('€${widget.slot.precioFinal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                  color: _K.flash)),
          const SizedBox(width: 8),
          Text('€${widget.slot.precioOriginal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: _K.textoMuted,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: _K.textoMuted)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: _K.rosa.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text('Ahorras €${widget.slot.ahorro.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 9, color: _K.rosa,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),

        // Countdown
        _buildCountdown(),
        const SizedBox(height: 8),

        // Barra huecos
        _buildBarraHuecos(),
        const SizedBox(height: 12),

        // Botón reservar
        _buildBotonReservar(),
      ]),
    );
  }

  // ── COUNTDOWN ───────────────────────────────────────────────────
  Widget _buildCountdown() {
    if (_restante.isNegative) {
      return Row(children: [
        Icon(Icons.timer_off_outlined, size: 13, color: _K.rojo),
        const SizedBox(width: 4),
        const Text('Expirado', style: TextStyle(fontSize: 12, color: _K.rojo,
            fontWeight: FontWeight.w600)),
      ]);
    }

    final h = _restante.inHours;
    final m = _restante.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _restante.inSeconds.remainder(60).toString().padLeft(2, '0');
    final texto = h > 0 ? '${h}h ${m}m ${s}s' : '${m}m ${s}s';
    final urgente = _restante.inMinutes < 30;

    return Row(children: [
      Icon(Icons.timer_outlined, size: 13,
          color: urgente ? _K.rojo : _K.flash),
      const SizedBox(width: 4),
      Text('Expira en ', style: TextStyle(
          fontSize: 11, color: _K.textoMuted)),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(texto, key: ValueKey(texto),
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: urgente ? _K.rojo : _K.flash,
            )),
      ),
    ]);
  }

  // ── BARRA HUECOS ─────────────────────────────────────────────────
  Widget _buildBarraHuecos() {
    final pct = widget.slot.porcentajeOcupacion;
    final disp = widget.slot.huecosDisponibles;
    final total = widget.slot.huecosTotal;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.people_outline_rounded, size: 12, color: _K.textoMuted),
        const SizedBox(width: 4),
        Text('$disp de $total disponibles',
            style: const TextStyle(fontSize: 11, color: _K.textoMuted)),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 5,
          backgroundColor: _K.borde,
          valueColor: AlwaysStoppedAnimation<Color>(
            pct >= 0.8 ? _K.rojo : pct >= 0.5 ? _K.flash : _K.accentCian,
          ),
        ),
      ),
    ]);
  }

  // ── BOTÓN RESERVAR ───────────────────────────────────────────────
  Widget _buildBotonReservar() {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton(
        onPressed: (_disponible && !_reservando) ? _mostrarDetalleYReservar : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _K.flash,
          foregroundColor: _K.fondo,
          disabledBackgroundColor: _K.borde,
          disabledForegroundColor: _K.textoMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _reservando
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: _K.fondo, strokeWidth: 2))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('⚡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                const Text('Reservar ahora',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ]),
      ),
    );
  }

  // ── OVERLAY NO DISPONIBLE ────────────────────────────────────────
  Widget _buildOverlayNoDisponible() {
    final texto = widget.slot.estaLleno ? 'COMPLETO'
        : widget.slot.haExpirado ? 'EXPIRADO'
        : 'NO DISPONIBLE';
    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: _K.fondo.withValues(alpha: 0.75),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _K.borde,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(texto,
                  style: const TextStyle(color: _K.textoMuted, fontSize: 14,
                      fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fotoPlaceholder() => Container(
    color: _K.flashOscuro,
    child: const Center(
      child: Text('⚡', style: TextStyle(fontSize: 40)),
    ),
  );

  // ── RESERVAR ─────────────────────────────────────────────────────
  Future<void> _mostrarDetalleYReservar() async {
    final confirmar = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _K.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ConfirmacionReservaSheet(slot: widget.slot),
    );
    if (confirmar != true) return;
    if (!mounted) return;

    setState(() => _reservando = true);
    try {
      await FlashSlotService.reservarSlot(
        negocioId: widget.slot.negocioId,
        slotId:    widget.slot.id,
        slot:      widget.slot,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Text('⚡ ', style: TextStyle(fontSize: 16)),
            Expanded(child: Text(
              '¡Reserva realizada! ${widget.slot.servicioNombre} en ${widget.slot.negocioNombre}',
              style: const TextStyle(fontSize: 13),
            )),
          ]),
          backgroundColor: const Color(0xFF1A2A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: _K.accentCian, width: 0.5),
          ),
        ),
      );
      widget.onReservado?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: _K.rojo),
      );
    } finally {
      if (mounted) setState(() => _reservando = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET DE CONFIRMACIÓN
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmacionReservaSheet extends StatelessWidget {
  final FlashSlotModel slot;
  const _ConfirmacionReservaSheet({required this.slot});

  @override
  Widget build(BuildContext context) {
    final inicio = slot.fechaHoraInicio;
    final f = '${inicio.day}/${inicio.month}/${inicio.year}';
    final t = '${inicio.hour}:${inicio.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20,
          20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: _K.borde,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),

        // Header con flash
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: _K.flashOscuro, borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: Text('⚡', style: TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(slot.servicioNombre, style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _K.texto)),
            Text(slot.negocioNombre, style: const TextStyle(
                fontSize: 12, color: _K.textoMuted)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('€${slot.precioFinal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                    color: _K.flash)),
            Text('antes €${slot.precioOriginal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 11, color: _K.textoMuted,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: _K.textoMuted)),
          ]),
        ]),
        const SizedBox(height: 16),
        const Divider(color: _K.borde),
        const SizedBox(height: 12),

        _row(Icons.calendar_today_outlined, 'Fecha y hora', '$f a las $t'),
        const SizedBox(height: 8),
        _row(Icons.people_outline, 'Hueco disponibles',
            '${slot.huecosDisponibles} de ${slot.huecosTotal}'),
        if (slot.profesionalNombre != null) ...[
          const SizedBox(height: 8),
          _row(Icons.person_outline, 'Profesional', slot.profesionalNombre!),
        ],
        const SizedBox(height: 20),

        // Botones
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              style: OutlinedButton.styleFrom(
                foregroundColor: _K.textoMuted,
                side: const BorderSide(color: _K.borde),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Cancelar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _K.flash,
                foregroundColor: _K.fondo,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('⚡ Confirmar reserva',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _row(IconData icon, String label, String val) => Row(children: [
    Icon(icon, size: 16, color: _K.textoMuted),
    const SizedBox(width: 8),
    Text('$label: ', style: const TextStyle(fontSize: 12, color: _K.textoMuted)),
    Expanded(child: Text(val, style: const TextStyle(
        fontSize: 13, color: _K.texto, fontWeight: FontWeight.w500),
        overflow: TextOverflow.ellipsis)),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// CARRUSEL DE FLASH SLOTS (para PantallaExplorar)
// ─────────────────────────────────────────────────────────────────────────────
class CarruselFlashSlots extends StatelessWidget {
  const CarruselFlashSlots({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FlashSlotModel>>(
      stream: FlashSlotService.escucharTodosActivos(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _Shimmer();
        }
        final slots = snap.data ?? [];
        if (slots.isEmpty) return const SizedBox.shrink();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _TituloCarrusel(),
          SizedBox(
            height: 320,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: slots.length,
              itemBuilder: (ctx, i) => CardFlashSlot(slot: slots[i]),
            ),
          ),
        ]);
      },
    );
  }
}

class _TituloCarrusel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFBB00),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Text('⚡', style: TextStyle(fontSize: 12)),
            SizedBox(width: 4),
            Text('FLASH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
                color: Color(0xFF0A0F23))),
          ]),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Disponible ahora', style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Huecos de última hora', style: TextStyle(
                fontSize: 11, color: Color(0xFFB0B3C1))),
          ]),
        ),
      ]),
    );
  }
}

class _Shimmer extends StatefulWidget {
  @override
  State<_Shimmer> createState() => _ShimmerState();
}
class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => SizedBox(
        height: 320,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 3,
          itemBuilder: (_, __) => Container(
            width: 280, margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment((_c.value * 2 - 1), 0),
                end: Alignment((_c.value * 2 + 1), 0),
                colors: const [
                  Color(0xFF1E2139), Color(0xFF2A2E45), Color(0xFF1E2139),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


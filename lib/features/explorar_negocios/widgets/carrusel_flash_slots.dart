import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/widgets/flux_toast.dart';

// ═══════════════════════════════════════════════════════════════════════════
// MODELO FlashSlot
// ═══════════════════════════════════════════════════════════════════════════
class FlashSlot {
  final String id, negocioId, negocioNombre, servicio;
  final String? negocioFotoUrl;
  final double precio, precioOriginal;
  final DateTime fechaFin;
  final int huecosTotales, huecosReservados;
  final String estado;

  FlashSlot({
    required this.id,
    required this.negocioId,
    required this.negocioNombre,
    required this.servicio,
    this.negocioFotoUrl,
    required this.precio,
    required this.precioOriginal,
    required this.fechaFin,
    required this.huecosTotales,
    required this.huecosReservados,
    required this.estado,
  });

  bool get disponible =>
      estado == 'activo' &&
      (huecosTotales - huecosReservados) > 0 &&
      fechaFin.isAfter(DateTime.now());

  factory FlashSlot.fromDoc(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    return FlashSlot(
      id: doc.id,
      negocioId: m['negocio_id'] as String? ?? '',
      negocioNombre: m['negocio_nombre'] as String? ?? '',
      servicio: m['servicio_nombre'] as String? ?? m['servicio'] as String? ?? '',
      negocioFotoUrl: m['negocio_foto_url'] as String? ?? m['foto_url'] as String?,
      precio: (m['precio_final'] as num?)?.toDouble() ?? (m['precio'] as num?)?.toDouble() ?? 0,
      precioOriginal: (m['precio_original'] as num?)?.toDouble() ?? 0,
      fechaFin: (m['fecha_hora_expiracion'] as Timestamp? ?? m['fecha_fin'] as Timestamp?)?.toDate()
          ?? DateTime.now().subtract(const Duration(seconds: 1)),
      huecosTotales: (m['huecos_totales'] as num?)?.toInt() ?? 1,
      huecosReservados: (m['huecos_reservados'] as num?)?.toInt() ?? 0,
      estado: m['estado'] as String? ?? 'activo',
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET: CarruselFlashSlots
// ═══════════════════════════════════════════════════════════════════════════
class CarruselFlashSlots extends StatelessWidget {
  const CarruselFlashSlots({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('flash_slots')
          .where('estado', isEqualTo: 'activo')
          .where('fecha_hora_expiracion', isGreaterThan: Timestamp.now())
          .limit(20)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError || snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        final docs = snap.data?.docs ?? [];
        final slots = <FlashSlot>[];
        for (final doc in docs) {
          try { slots.add(FlashSlot.fromDoc(doc)); } catch (_) {}
        }
        if (slots.isEmpty) return const SizedBox.shrink();

        // Countdown al slot que expira más pronto
        final primero = slots.reduce((a, b) =>
            a.fechaFin.isBefore(b.fechaFin) ? a : b);
        final restante = primero.fechaFin.difference(DateTime.now());

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B3E),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.flash_on, color: Colors.amber, size: 13),
                  SizedBox(width: 4),
                  Text('FLASH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 0.5)),
                ]),
              ),
              const SizedBox(width: 10),
              const Text('Ofertas especiales',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B))),
              const Spacer(),
              if (!restante.isNegative)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${restante.inHours}h ${restante.inMinutes.remainder(60)}m',
                    style: const TextStyle(fontSize: 10, color: Color(0xFFB45309),
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ]),
          ),
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: slots.length,
              itemBuilder: (ctx, i) => _TarjetaFlash(slot: slots[i]),
            ),
          ),
          const SizedBox(height: 8),
        ]);
      },
    );
  }
}

// ── Tarjeta Flash ─────────────────────────────────────────────────────────

class _TarjetaFlash extends StatefulWidget {
  final FlashSlot slot;
  const _TarjetaFlash({required this.slot});

  @override
  State<_TarjetaFlash> createState() => _TarjetaFlashState();
}

class _TarjetaFlashState extends State<_TarjetaFlash> {
  static const _accent = Color(0xFF0D47A1);

  late Timer _timer;
  late Duration _restante;

  @override
  void initState() {
    super.initState();
    _restante = widget.slot.fechaFin.difference(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _restante = widget.slot.fechaFin.difference(DateTime.now());
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _countdownText {
    if (_restante.isNegative) return 'Expirado';
    final h = _restante.inHours;
    final m = _restante.inMinutes.remainder(60);
    final s = _restante.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  void _onTap(BuildContext context) async {
    if (!widget.slot.disponible) {
      FluxToast.aviso(context, 'Este slot ya no está disponible');
      return;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FlashDetailSheet(slot: widget.slot),
    );

    if (ok != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (context.mounted) {
        FluxToast.aviso(context, 'Inicia sesión para reservar');
      }
      return;
    }

    try {
      final slotRef = FirebaseFirestore.instance
          .collection('negocios_publicos')
          .doc(widget.slot.negocioId)
          .collection('flash_slots')
          .doc(widget.slot.id);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(slotRef);
        if (!snap.exists) throw Exception('Slot no encontrado');
        final data       = snap.data()!;
        final reservados = (data['huecos_reservados'] as num?)?.toInt() ?? 0;
        final totales    = (data['huecos_totales']    as num?)?.toInt() ?? 0;
        final estado     = data['estado'] as String? ?? '';
        final reservasIds = List<dynamic>.from(data['reservas_ids'] as List? ?? []);
        if (reservasIds.contains(uid)) {
          throw Exception('Ya reservado');
        }
        if (estado != 'activo' || reservados >= totales) {
          throw Exception('Slot lleno o inactivo');
        }
        tx.update(slotRef, {
          'huecos_reservados': FieldValue.increment(1),
          'reservas_ids':      FieldValue.arrayUnion([uid]),
        });
      });

      if (context.mounted) FluxToast.exito(context, '¡Reserva confirmada!');
    } catch (e) {
      if (context.mounted) {
        final msg = e.toString().contains('lleno') ? 'Ya no quedan plazas'
            : e.toString().contains('reservado') ? 'Ya tienes una reserva en este slot'
            : 'Error al reservar';
        FluxToast.error(context, msg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.slot;
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF151932),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(fit: StackFit.expand, children: [
            // Foto de fondo
            if (s.negocioFotoUrl != null && s.negocioFotoUrl!.isNotEmpty)
              CachedNetworkImage(imageUrl: s.negocioFotoUrl!, fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: const Color(0xFF1E2139)),
                  errorWidget: (_, __, ___) => Container(color: const Color(0xFF1E2139))),
            // Gradiente
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xDD0A0F23)],
                  stops: [0.2, 1.0],
                ),
              ),
            ),
            // Badge FLASH
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('FLASH',
                    style: TextStyle(color: Colors.white, fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            // Countdown
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_countdownText,
                    style: const TextStyle(color: Colors.white, fontSize: 9)),
              ),
            ),
            // Info bottom
            Positioned(
              bottom: 8, left: 8, right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.servicio,
                      style: const TextStyle(color: Colors.white,
                          fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(s.negocioNombre,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('${s.precio.toStringAsFixed(2)} €',
                        style: const TextStyle(color: _accent, fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    if (s.precioOriginal > s.precio)
                      Text('${s.precioOriginal.toStringAsFixed(2)} €',
                          style: const TextStyle(color: Colors.grey, fontSize: 10,
                              decoration: TextDecoration.lineThrough)),
                  ]),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: s.huecosTotales == 0 ? 0
                        : s.huecosReservados / s.huecosTotales,
                    color: _accent,
                    backgroundColor: Colors.white24,
                    minHeight: 3,
                  ),
                  const SizedBox(height: 2),
                  Text('${s.huecosTotales - s.huecosReservados} disponibles',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 9)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET — Detalle de oferta flash
// ─────────────────────────────────────────────────────────────────────────────
class _FlashDetailSheet extends StatefulWidget {
  final FlashSlot slot;
  const _FlashDetailSheet({required this.slot});
  @override
  State<_FlashDetailSheet> createState() => _FlashDetailSheetState();
}

class _FlashDetailSheetState extends State<_FlashDetailSheet> {
  bool _reservando = false;

  int get _plazasLibres => widget.slot.huecosTotales - widget.slot.huecosReservados;

  double get _descuento {
    if (widget.slot.precioOriginal <= 0 || widget.slot.precio >= widget.slot.precioOriginal) return 0;
    return ((widget.slot.precioOriginal - widget.slot.precio) / widget.slot.precioOriginal * 100).roundToDouble();
  }

  Future<void> _confirmar() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) FluxToast.aviso(context, 'Inicia sesión para reservar');
      return;
    }
    setState(() => _reservando = true);
    try {
      final slotRef = FirebaseFirestore.instance
          .collection('negocios_publicos').doc(widget.slot.negocioId)
          .collection('flash_slots').doc(widget.slot.id);
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(slotRef);
        if (!snap.exists) throw Exception('Slot no encontrado');
        final data = snap.data()!;
        final reservados = (data['huecos_reservados'] as num?)?.toInt() ?? 0;
        final totales    = (data['huecos_totales']    as num?)?.toInt() ?? 0;
        final estado     = data['estado'] as String? ?? '';
        final reservasIds = List<dynamic>.from(data['reservas_ids'] as List? ?? []);
        if (reservasIds.contains(uid)) throw Exception('Ya reservado');
        if (estado != 'activo' || reservados >= totales) throw Exception('Slot lleno o inactivo');
        tx.update(slotRef, {
          'huecos_reservados': FieldValue.increment(1),
          'reservas_ids':      FieldValue.arrayUnion([uid]),
        });
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _reservando = false);
        final msg = e.toString().contains('lleno') ? 'Ya no quedan plazas'
            : e.toString().contains('reservado') ? 'Ya tienes una reserva en este slot'
            : 'Error al reservar';
        FluxToast.error(context, msg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.slot;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        color: const Color(0xFF0D1B3E),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Center(child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 36, height: 3,
            decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          )),

          // Foto de portada
          if (s.negocioFotoUrl != null && s.negocioFotoUrl!.isNotEmpty)
            SizedBox(
              height: 160, width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                CachedNetworkImage(
                  imageUrl: s.negocioFotoUrl!, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF151932)),
                ),
                Container(decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xEE0D1B3E)],
                    stops: [0.3, 1.0],
                  ),
                )),
                Positioned(bottom: 14, left: 16, right: 16, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('⚡ FLASH',
                            style: TextStyle(color: Colors.white, fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 8),
                      if (_plazasLibres <= 3)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.6)),
                          ),
                          child: Text('¡Solo $_plazasLibres plaza${_plazasLibres == 1 ? "" : "s"}!',
                              style: const TextStyle(color: Colors.orange, fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    Text(s.negocioNombre,
                        style: const TextStyle(color: Colors.white, fontSize: 18,
                            fontWeight: FontWeight.w800, height: 1.1)),
                  ],
                )),
              ]),
            ),

          // Contenido
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Servicio
              Text(s.servicio,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.3)),
              const SizedBox(height: 16),

              // Precio
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF151932),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Precio flash', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text('${s.precio.toStringAsFixed(2)} €',
                        style: const TextStyle(color: Colors.amber, fontSize: 26,
                            fontWeight: FontWeight.w900)),
                    if (s.precioOriginal > s.precio)
                      Text('antes ${s.precioOriginal.toStringAsFixed(2)} €',
                          style: const TextStyle(color: Colors.white38, fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Colors.white38)),
                  ]),
                  const Spacer(),
                  if (_descuento > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                      ),
                      child: Column(children: [
                        Text('-${_descuento.toInt()}%',
                            style: const TextStyle(color: Colors.amber, fontSize: 18,
                                fontWeight: FontWeight.w900)),
                        const Text('dto.', style: TextStyle(color: Colors.amber, fontSize: 10)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 12),

              // Plazas
              Row(children: [
                const Icon(Icons.people_outline_rounded, color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Text('$_plazasLibres de ${s.huecosTotales} plazas disponibles',
                    style: const TextStyle(color: Colors.white60, fontSize: 13)),
              ]),
              const SizedBox(height: 20),
            ]),
          ),

          // Botones
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20,
                MediaQuery.of(context).padding.bottom + 16),
            child: Column(children: [
              SizedBox(
                width: double.infinity, height: 52,
                child: FilledButton(
                  onPressed: _reservando ? null : _confirmar,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: const Color(0xFF0D1B3E),
                    disabledBackgroundColor: Colors.amber.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _reservando
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF0D1B3E)))
                      : const Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('⚡', style: TextStyle(fontSize: 18)),
                            SizedBox(width: 8),
                            Text('Reservar ahora',
                                style: TextStyle(fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                          ]),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                child: const Text('Cancelar'),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}


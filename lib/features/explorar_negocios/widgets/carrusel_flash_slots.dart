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
              const Icon(Icons.flash_on, color: Colors.amber, size: 16),
              const SizedBox(width: 6),
              const Text('Ofertas flash',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const Spacer(),
              if (restante.isNegative)
                const SizedBox.shrink()
              else
                Text(
                  'Quedan ${restante.inHours}h ${restante.inMinutes.remainder(60)}m',
                  style: const TextStyle(fontSize: 11, color: Colors.amber),
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
  static const _accent = Color(0xFF00FFC8);

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

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reservar'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.slot.negocioNombre,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(widget.slot.servicio),
          const SizedBox(height: 8),
          Row(children: [
            Text('${widget.slot.precio.toStringAsFixed(2)} €',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (widget.slot.precioOriginal > widget.slot.precio) ...[
              const SizedBox(width: 8),
              Text('${widget.slot.precioOriginal.toStringAsFixed(2)} €',
                  style: const TextStyle(fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey)),
            ],
          ]),
          const SizedBox(height: 8),
          Text('${widget.slot.huecosTotales - widget.slot.huecosReservados} plazas disponibles',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
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
      await FirebaseFirestore.instance
          .collection('negocios_publicos')
          .doc(widget.slot.negocioId)
          .collection('flash_slots')
          .doc(widget.slot.id)
          .update({
        'huecos_reservados': FieldValue.increment(1),
        'reservas_ids': FieldValue.arrayUnion([uid]),
      });
      if (context.mounted) {
        FluxToast.exito(context, '¡Reserva confirmada!');
      }
    } catch (e) {
      if (context.mounted) {
        FluxToast.error(context, 'Error: $e');
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




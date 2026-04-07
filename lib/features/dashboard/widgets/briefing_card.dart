import 'package:flutter/material.dart';
import '../../../services/briefing_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET — Briefing matutino (card destacada en el dashboard, 6h-12h)
// ─────────────────────────────────────────────────────────────────────────────

class BriefingCard extends StatefulWidget {
  final String empresaId;
  final String userId;

  const BriefingCard({
    super.key,
    required this.empresaId,
    required this.userId,
  });

  @override
  State<BriefingCard> createState() => _BriefingCardState();
}

class _BriefingCardState extends State<BriefingCard>
    with SingleTickerProviderStateMixin {
  final _svc = BriefingService();
  bool _visible = false;
  List<BriefingItem> _items = [];
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _cargar();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final debeMostrar = await _svc.debeMostrar();
    if (!debeMostrar) return;

    final items = await _svc.obtenerItems(
      empresaId: widget.empresaId,
      userId: widget.userId,
    );

    if (items.isEmpty) return;
    if (!mounted) return;
    setState(() { _items = items; _visible = true; });
    _anim.forward();
  }

  void _descartar() async {
    await _anim.reverse();
    await _svc.marcarVisto();
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible || _items.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _anim,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D47A1).withValues(alpha: 0.35),
              blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(children: [
          // Cabecera
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
            child: Row(children: [
              const Text('☀️',
                  style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Buenos días',
                    style: TextStyle(
                        color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                onPressed: _descartar,
              ),
            ]),
          ),
          // Items
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.icono, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item.texto,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13.5, height: 1.4)),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ),
        ]),
      ),
    );
  }
}


import 'package:flutter/material.dart';
import '../../../services/rating_historial_service.dart';

/// Widget de KPIs de rating calculado desde Firestore local.
/// Siempre visible con o sin historial.
class KPIsRatingWidget extends StatefulWidget {
  final String empresaId;
  final double ratingGoogle; // Rating real de Google (puede diferir)
  final int totalGoogle;

  const KPIsRatingWidget({
    super.key,
    required this.empresaId,
    this.ratingGoogle = 0,
    this.totalGoogle = 0,
  });

  @override
  State<KPIsRatingWidget> createState() => _KPIsRatingWidgetState();
}

class _KPIsRatingWidgetState extends State<KPIsRatingWidget> {
  final _svc = RatingHistorialService();
  KPIsRating? _kpis;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final k = await _svc.calcularKPIs(widget.empresaId);
    if (mounted) setState(() {
      _kpis = k;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const SizedBox(
          height: 72,
          child: Center(
              child: CircularProgressIndicator(strokeWidth: 2)));
    }

    final k = _kpis;
    if (k == null || k.totalResenas == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(
          children: [
            // Rating medio local
            Expanded(
              child: _KPICard(
                icono: Icons.star_rounded,
                iconoColor: const Color(0xFFF57C00),
                valor: k.ratingMedio.toStringAsFixed(1),
                etiqueta: 'Rating medio',
                cambio: k.cambioBrutoMensual,
              ),
            ),
            const SizedBox(width: 8),
            // Total reseñas acumuladas
            Expanded(
              child: _KPICard(
                icono: Icons.rate_review_outlined,
                iconoColor: const Color(0xFF1976D2),
                valor: '${k.totalResenas}',
                etiqueta: 'Reseñas guardadas',
              ),
            ),
            const SizedBox(width: 8),
            // Sin responder
            Expanded(
              child: _KPICard(
                icono: Icons.mark_chat_unread_outlined,
                iconoColor: k.sinResponder > 0
                    ? const Color(0xFFD32F2F)
                    : const Color(0xFF43A047),
                valor: '${k.sinResponder}',
                etiqueta: 'Sin responder',
                urgente: k.sinResponder > 0,
              ),
            ),
          ],
        ),

        // Nota informativa
        const SizedBox(height: 6),
        Text(
          'Rating calculado sobre las ${k.totalResenas} reseñas almacenadas'
          '${widget.totalGoogle > 0 ? ' de ${widget.totalGoogle} reales en Google' : ''}',
          style: TextStyle(
              fontSize: 9,
              color: Colors.grey[400],
              fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}

class _KPICard extends StatelessWidget {
  final IconData icono;
  final Color iconoColor;
  final String valor;
  final String etiqueta;
  final double? cambio;
  final bool urgente;

  const _KPICard({
    required this.icono,
    required this.iconoColor,
    required this.valor,
    required this.etiqueta,
    this.cambio,
    this.urgente = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: urgente
            ? const Color(0xFFD32F2F).withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: urgente
              ? const Color(0xFFD32F2F).withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: iconoColor, size: 18),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                valor,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: urgente ? const Color(0xFFD32F2F) : Colors.black87,
                ),
              ),
              if (cambio != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: _CambioBadge(cambio: cambio!),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: TextStyle(
                color: Colors.grey[500], fontSize: 10, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _CambioBadge extends StatelessWidget {
  final double cambio;

  const _CambioBadge({required this.cambio});

  @override
  Widget build(BuildContext context) {
    if (cambio == 0) return const SizedBox.shrink();
    final sube = cambio > 0;
    final color =
        sube ? const Color(0xFF43A047) : const Color(0xFFD32F2F);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(sube ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: color, size: 14),
        Text(
          '${sube ? '+' : ''}${cambio.toStringAsFixed(1)}',
          style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ── Distribución de estrellas ─────────────────────────────────────────────────

/// Widget de distribución de estrellas calculado sobre las reseñas en Firestore.
class DistribucionEstrellasWidget extends StatefulWidget {
  final String empresaId;

  const DistribucionEstrellasWidget({super.key, required this.empresaId});

  @override
  State<DistribucionEstrellasWidget> createState() =>
      _DistribucionEstrellasWidgetState();
}

class _DistribucionEstrellasWidgetState
    extends State<DistribucionEstrellasWidget> {
  final _svc = RatingHistorialService();
  Map<int, int> _distribucion = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final d = await _svc.calcularDistribucion(widget.empresaId);
    if (mounted) setState(() {
      _distribucion = d;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox(height: 60);

    final total = _distribucion.values.fold(0, (s, v) => s + v);
    if (total == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Distribución de estrellas',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.black87),
        ),
        const SizedBox(height: 10),
        ...List.generate(5, (i) {
          final stars = 5 - i;
          final count = _distribucion[stars] ?? 0;
          final pct = total > 0 ? count / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$stars',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const Icon(Icons.star, size: 11, color: Color(0xFFF57C00)),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(
                      stars <= 2
                          ? const Color(0xFFD32F2F)
                          : stars == 3
                              ? const Color(0xFFF57C00)
                              : const Color(0xFF43A047),
                    ),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  '$count',
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 11),
                ),
              ),
              SizedBox(
                width: 34,
                child: Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: Colors.grey[400], fontSize: 10),
                ),
              ),
            ]),
          );
        }),
      ],
    );
  }
}


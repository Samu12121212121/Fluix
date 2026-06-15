import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Número de WhatsApp de soporte — cambiar antes de producción
// ─────────────────────────────────────────────────────────────────────────────
const _kWhatsappNumero = '34684287980';

const _kHoraApertura = 9;
const _kHoraCierre   = 21;

class SoporteScreen extends StatelessWidget {
  const SoporteScreen({super.key});

  bool get _disponible {
    final h = DateTime.now().hour;
    return h >= _kHoraApertura && h < _kHoraCierre;
  }

  Future<void> _abrirWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/$_kWhatsappNumero');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final disponible = _disponible;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: const Text(
          'Soporte técnico',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF0D1117),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Tarjeta de estado ──────────────────────────────────────────
          _TarjetaEstado(disponible: disponible),
          const SizedBox(height: 24),

          // ── Botón WhatsApp ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _abrirWhatsApp(context),
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
              label: const Text(
                'Contactar por WhatsApp',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Tiempo de respuesta
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.schedule, size: 14, color: Colors.white.withValues(alpha: 0.45)),
              const SizedBox(width: 5),
              Text(
                'Tiempo de respuesta máximo: 4 horas',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),

          // ── FAQ ────────────────────────────────────────────────────────
          Text(
            'Preguntas frecuentes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          const _FaqList(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA DE ESTADO
// ─────────────────────────────────────────────────────────────────────────────

class _TarjetaEstado extends StatelessWidget {
  final bool disponible;
  const _TarjetaEstado({required this.disponible});

  @override
  Widget build(BuildContext context) {
    final color  = disponible ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final icono  = disponible ? '🟢' : '🔴';
    final titulo = disponible ? 'Soporte disponible' : 'Fuera de horario';
    final sub    = disponible
        ? 'Estamos disponibles ahora. Te respondemos en menos de 4 horas.'
        : 'Horario de soporte: L-D de 9:00 a 21:00. Deja tu mensaje y te respondemos en cuanto abramos.';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icono, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAQ
// ─────────────────────────────────────────────────────────────────────────────

class _FaqList extends StatelessWidget {
  const _FaqList();

  static const _items = [
    (
      '¿Cómo añado un producto al TPV?',
      'Ve a TPV → Productos → botón + para añadir.',
    ),
    (
      '¿Cómo creo una reserva?',
      'Ve a Reservas → Nueva reserva y selecciona fecha, hora y cliente.',
    ),
    (
      '¿Cómo genero una factura?',
      'Ve a Facturación → Nueva factura y completa los datos del cliente y los conceptos.',
    ),
    (
      '¿Cómo ficho como empleado?',
      'Ve a Fichajes → pulsa Entrada o Salida.',
    ),
    (
      'La app no carga datos',
      'Comprueba tu conexión a internet. Si el problema persiste contacta con soporte.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: List.generate(_items.length, (i) {
          final (pregunta, respuesta) = _items[i];
          final esUltimo = i == _items.length - 1;
          return Column(
            children: [
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: Colors.white.withValues(alpha: 0.04),
                  highlightColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 2),
                  childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  iconColor: const Color(0xFF0D47A1),
                  collapsedIconColor: Colors.white38,
                  title: Text(
                    pregunta,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    Text(
                      respuesta,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (!esUltimo)
                Divider(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.07),
                  indent: 18,
                  endIndent: 18,
                ),
            ],
          );
        }),
      ),
    );
  }
}

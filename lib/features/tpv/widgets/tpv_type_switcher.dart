// tpv_type_switcher.dart
// Chip en el AppBar que permite al propietario cambiar entre los distintos
// tipos de TPV (Bar, Peluquería, Tienda).
// Usa [onTipoChanged] callback para evitar dependencias circulares.

import 'package:flutter/material.dart';

class TpvTypeSwitcher extends StatelessWidget {
  final String tipoActual; // 'bar' | 'peluqueria' | 'tienda'
  final void Function(String tipo) onTipoChanged;

  const TpvTypeSwitcher({
    super.key,
    required this.tipoActual,
    required this.onTipoChanged,
  });

  static const List<Map<String, Object>> _tipos = [
    {'id': 'bar',        'label': '🍺 Bar/Rest.',  'icono': Icons.restaurant},
    {'id': 'peluqueria', 'label': '💇 Peluquería', 'icono': Icons.cut},
    {'id': 'tienda',     'label': '🛒 Tienda',      'icono': Icons.storefront},
  ];

  @override
  Widget build(BuildContext context) {
    final actual = _tipos.firstWhere((t) => t['id'] == tipoActual, orElse: () => _tipos[0]);

    return GestureDetector(
      onTapDown: (details) async {
        final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
        final button = context.findRenderObject() as RenderBox;
        final offset = button.localToGlobal(Offset.zero, ancestor: overlay);

        final seleccionado = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + button.size.height + 4,
            offset.dx + button.size.width + 160,
            offset.dy + button.size.height + 200,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          items: _tipos.map((t) {
            final esActual = t['id'] == tipoActual;
            return PopupMenuItem<String>(
              value: t['id'] as String,
              child: Row(
                children: [
                  Icon(t['icono'] as IconData, size: 18,
                      color: esActual ? const Color(0xFF1565C0) : null),
                  const SizedBox(width: 10),
                  Text(t['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: esActual ? FontWeight.w700 : FontWeight.normal,
                        color: esActual ? const Color(0xFF1565C0) : null,
                      )),
                  if (esActual) ...[
                    const Spacer(),
                    const Icon(Icons.check, size: 16, color: Color(0xFF1565C0)),
                  ],
                ],
              ),
            );
          }).toList(),
        );

        if (seleccionado == null || seleccionado == tipoActual) return;
        onTipoChanged(seleccionado);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white38, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(actual['icono'] as IconData, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(actual['label'] as String,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(width: 3),
            const Icon(Icons.expand_more, size: 14, color: Colors.white70),
          ],
        ),
      ),
    );
  }
}


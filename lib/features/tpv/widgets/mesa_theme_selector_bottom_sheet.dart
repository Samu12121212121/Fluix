import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mesa_color_theme.dart';
import '../providers/mesa_theme_provider.dart';

Future<void> mostrarMesaThemeSelector(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E2139),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _MesaThemeSelectorContent(),
  );
}

class _MesaThemeSelectorContent extends StatelessWidget {
  const _MesaThemeSelectorContent();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MesaThemeProvider>();
    final temaActualId = provider.temaActual.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Icon(Icons.palette_outlined, color: Color(0xFF00FFC8), size: 18),
              SizedBox(width: 8),
              Text(
                'Tema del plano de mesas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Color(0xFF2A2E45), height: 1),
        ...MesaColorTheme.todos.map((tema) {
          final activo = tema.id == temaActualId;
          return InkWell(
            onTap: () {
              context.read<MesaThemeProvider>().cambiarTema(tema.id);
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: activo
                    ? const Color(0xFF00FFC8).withValues(alpha: 0.07)
                    : Colors.transparent,
                border: const Border(
                  bottom: BorderSide(color: Color(0xFF2A2E45)),
                ),
              ),
              child: Row(
                children: [
                  // ── Muestra de colores libre / ocupada ──────────────
                  _ColorSwatch(color: tema.mesaLibre, label: 'Libre'),
                  const SizedBox(width: 10),
                  _ColorSwatch(color: tema.mesaOcupada, label: 'Ocup.'),
                  const SizedBox(width: 14),
                  // ── Nombre del tema ──────────────────────────────────
                  Expanded(
                    child: Text(
                      tema.nombre,
                      style: TextStyle(
                        color: activo ? const Color(0xFF00FFC8) : Colors.white,
                        fontSize: 14,
                        fontWeight:
                            activo ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  // ── Check activo ─────────────────────────────────────
                  if (activo)
                    const Icon(Icons.check_circle,
                        color: Color(0xFF00FFC8), size: 20)
                  else
                    const Icon(Icons.radio_button_unchecked,
                        color: Colors.white24, size: 20),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorSwatch({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

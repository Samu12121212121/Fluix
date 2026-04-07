import 'package:flutter/material.dart';

/// Barra inferior con acciones masivas para clientes seleccionados.
/// Se desliza desde abajo con animación.
class BulkActionsBar extends StatelessWidget {
  final int seleccionados;
  final VoidCallback onAsignarEtiqueta;
  final VoidCallback onEliminarEtiqueta;
  final VoidCallback onCambiarEstado;
  final VoidCallback onExportar;
  final VoidCallback onEliminar;
  final VoidCallback onCancelar;

  const BulkActionsBar({
    super.key,
    required this.seleccionados,
    required this.onAsignarEtiqueta,
    required this.onEliminarEtiqueta,
    required this.onCambiarEstado,
    required this.onExportar,
    required this.onEliminar,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: seleccionados > 0 ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: seleccionados > 0 ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00796B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$seleccionados seleccionado${seleccionados != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Color(0xFF00796B),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onCancelar,
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Acciones
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _AccionBtn(
                      icono: Icons.label,
                      label: 'Asignar\netiqueta',
                      color: const Color(0xFF00796B),
                      onTap: onAsignarEtiqueta,
                    ),
                    const SizedBox(width: 8),
                    _AccionBtn(
                      icono: Icons.label_off,
                      label: 'Quitar\netiqueta',
                      color: const Color(0xFFF57C00),
                      onTap: onEliminarEtiqueta,
                    ),
                    const SizedBox(width: 8),
                    _AccionBtn(
                      icono: Icons.swap_horiz,
                      label: 'Cambiar\nestado',
                      color: const Color(0xFF0D47A1),
                      onTap: onCambiarEstado,
                    ),
                    const SizedBox(width: 8),
                    _AccionBtn(
                      icono: Icons.download,
                      label: 'Exportar\nselección',
                      color: const Color(0xFF7B1FA2),
                      onTap: onExportar,
                    ),
                    const SizedBox(width: 8),
                    _AccionBtn(
                      icono: Icons.delete_outline,
                      label: 'Eliminar',
                      color: const Color(0xFFD32F2F),
                      onTap: onEliminar,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccionBtn extends StatelessWidget {
  final IconData icono;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AccionBtn({
    required this.icono,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


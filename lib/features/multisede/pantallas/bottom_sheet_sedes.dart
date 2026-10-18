import 'package:flutter/material.dart';
import '../servicios/multisede_service.dart';

/// BottomSheet para cambiar de sede desde el dashboard sin salir de la app.
class BottomSheetSedes extends StatelessWidget {
  final List<SedeInfo> sedes;
  final String empresaActual;

  const BottomSheetSedes({
    super.key,
    required this.sedes,
    required this.empresaActual,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Cambiar negocio',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          ...sedes.map((s) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: s.empresaId == empresaActual
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.12)
                  : Colors.grey[100],
              child: Text(
                s.nombre.isNotEmpty ? s.nombre[0].toUpperCase() : 'N',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: s.empresaId == empresaActual
                        ? const Color(0xFF7C3AED)
                        : Colors.grey[600]),
              ),
            ),
            title: Text(s.nombre,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: s.esPrincipal
                ? const Text('Principal',
                    style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED)))
                : null,
            trailing: s.empresaId == empresaActual
                ? const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF7C3AED), size: 20)
                : const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.grey),
            onTap: () => Navigator.pop(context, s),
          )),
        ],
      ),
    );
  }
}

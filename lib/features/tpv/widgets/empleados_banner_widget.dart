// Widget reutilizable: Franja horizontal de empleados activos para TPV
// Se puede añadir a cualquier TPV (bar, tienda, peluquería)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmpleadosBannerWidget extends StatelessWidget {
  final String empresaId;
  final String? empleadoSeleccionadoId;
  final ValueChanged<String?> onEmpleadoChanged;
  final Color colorPrimario;
  final Color colorFondo;

  const EmpleadosBannerWidget({
    super.key,
    required this.empresaId,
    required this.empleadoSeleccionadoId,
    required this.onEmpleadoChanged,
    this.colorPrimario = const Color(0xFF00FFC8),
    this.colorFondo = const Color(0xFF151932),
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('empleados')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final empleados = snapshot.data!.docs;

        return Container(
          height: 74,
          color: colorFondo,
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  itemCount: empleados.length + 1, // +1 para "Todos"
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Chip "Todos"
                      final seleccionado = empleadoSeleccionadoId == null;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => onEmpleadoChanged(null),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: seleccionado
                                  ? colorPrimario.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: seleccionado
                                    ? colorPrimario
                                    : Colors.white.withValues(alpha: 0.1),
                                width: seleccionado ? 2 : 1,
                              ),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.people, size: 14,
                                  color: seleccionado ? colorPrimario : Colors.white54),
                              const SizedBox(width: 6),
                              Text('Todos',
                                  style: TextStyle(
                                    color: seleccionado ? colorPrimario : Colors.white54,
                                    fontSize: 12,
                                    fontWeight: seleccionado
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  )),
                            ]),
                          ),
                        ),
                      );
                    }

                    final doc = empleados[index - 1];
                    final data = doc.data() as Map<String, dynamic>;
                    final nombre = (data['nombre'] ?? 'Empleado').toString();
                    final puesto = (data['puesto'] ?? data['especialidad'] ?? '').toString();
                    final fotoUrl = data['foto_url'] as String?;
                    final colorIdx = (data['color_index'] as int?) ?? (index - 1);
                    final kColors = [
                      const Color(0xFF00FFC8), const Color(0xFFFF3296),
                      const Color(0xFFFF4678), const Color(0xFF00D9FF),
                      const Color(0xFFFFB84D), const Color(0xFF4CAF50),
                      const Color(0xFF9C27B0), const Color(0xFF2196F3),
                    ];
                    final color = kColors[colorIdx % kColors.length];
                    final seleccionado = empleadoSeleccionadoId == doc.id;

                    // Iniciales
                    final partes = nombre.trim().split(' ');
                    final iniciales = partes.length >= 2
                        ? '${partes[0][0]}${partes[1][0]}'.toUpperCase()
                        : nombre.substring(0, nombre.length.clamp(0, 2)).toUpperCase();

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onEmpleadoChanged(seleccionado ? null : doc.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: seleccionado
                                ? color.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: seleccionado
                                  ? color
                                  : Colors.white.withValues(alpha: 0.1),
                              width: seleccionado ? 2 : 1,
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            CircleAvatar(
                              radius: 13,
                              backgroundColor: color.withValues(alpha: 0.3),
                              foregroundColor: color,
                              backgroundImage:
                                  fotoUrl != null ? NetworkImage(fotoUrl) : null,
                              child: fotoUrl == null
                                  ? Text(iniciales,
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: color))
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nombre.split(' ').first, // solo primer nombre
                                  style: TextStyle(
                                    color: seleccionado ? color : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: seleccionado
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (puesto.isNotEmpty)
                                  Text(
                                    puesto,
                                    style: TextStyle(
                                      color: seleccionado
                                          ? color.withValues(alpha: 0.7)
                                          : Colors.white38,
                                      fontSize: 9,
                                    ),
                                  ),
                              ],
                            ),
                            if (seleccionado) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.check_circle, color: color, size: 14),
                            ],
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Divider(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ],
          ),
        );
      },
    );
  }
}


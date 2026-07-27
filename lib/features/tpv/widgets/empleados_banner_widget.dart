// Widget reutilizable: Franja horizontal de empleados activos para TPV
// Se puede añadir a cualquier TPV (bar, tienda, peluquería)
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

                    final turnoInicio = data['turno_inicio'] as Timestamp?;
                    final turnoActivo = turnoInicio != null;
                    final turnoStr = turnoActivo
                        ? _duracionTurno(turnoInicio.toDate())
                        : null;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onEmpleadoChanged(seleccionado ? null : doc.id),
                        onLongPress: () => _mostrarDialogoTurno(
                          context,
                          empleadoId: doc.id,
                          nombre: nombre,
                          turnoActivo: turnoActivo,
                          turnoInicio: turnoInicio?.toDate(),
                          empresaId: empresaId,
                        ),
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
                                if (turnoStr != null)
                                  Text(
                                    turnoStr,
                                    style: TextStyle(
                                      color: turnoActivo
                                          ? color.withValues(alpha: 0.85)
                                          : Colors.white38,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else if (puesto.isNotEmpty)
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
                            if (turnoActivo) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.timer_rounded, color: color.withValues(alpha: 0.7), size: 12),
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

// ─── Utilidades de turno ─────────────────────────────────────────────────────

String _duracionTurno(DateTime inicio) {
  final elapsed = DateTime.now().difference(inicio);
  final h = elapsed.inHours;
  final m = elapsed.inMinutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m}m';
}

Future<void> _mostrarDialogoTurno(
  BuildContext context, {
  required String empleadoId,
  required String nombre,
  required bool turnoActivo,
  required DateTime? turnoInicio,
  required String empresaId,
}) async {
  final fmt = DateFormat('HH:mm');
  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1E2139),
      title: Row(children: [
        const Icon(Icons.timer_rounded, color: Color(0xFF00FFC8), size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text('Turno de $nombre',
            style: const TextStyle(color: Colors.white, fontSize: 15),
            overflow: TextOverflow.ellipsis)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if (turnoActivo && turnoInicio != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF00FFC8).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00FFC8).withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              const Text('TURNO ACTIVO', style: TextStyle(
                  color: Color(0xFF00FFC8), fontSize: 10,
                  fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(height: 6),
              Text('Entrada: ${fmt.format(turnoInicio)}',
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text('Duración: ${_duracionTurno(turnoInicio)}',
                  style: const TextStyle(color: Color(0xFF00FFC8), fontSize: 14)),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('¿Cerrar turno ahora?',
              style: TextStyle(color: Color(0xFFB0B3C1), fontSize: 13)),
        ] else
          const Text('¿Iniciar turno ahora?',
              style: TextStyle(color: Color(0xFFB0B3C1), fontSize: 13)),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar', style: TextStyle(color: Color(0xFFB0B3C1))),
        ),
        FilledButton.icon(
          onPressed: () async {
            Navigator.pop(ctx);
            final ref = FirebaseFirestore.instance
                .collection('empresas')
                .doc(empresaId)
                .collection('empleados')
                .doc(empleadoId);

            if (turnoActivo) {
              await ref.update({
                'turno_inicio': null,
                'ultimo_turno_fin': FieldValue.serverTimestamp(),
              });
            } else {
              await ref.update({
                'turno_inicio': FieldValue.serverTimestamp(),
              });
            }
          },
          icon: Icon(turnoActivo ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 16),
          label: Text(turnoActivo ? 'Cerrar turno' : 'Iniciar turno',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(
            backgroundColor: turnoActivo ? const Color(0xFFFF2850) : const Color(0xFF00FFC8),
            foregroundColor: turnoActivo ? Colors.white : Colors.black,
          ),
        ),
      ],
    ),
  );
}


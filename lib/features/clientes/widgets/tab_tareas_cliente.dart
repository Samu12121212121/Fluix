import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/modelos/tarea.dart';
import '../../../services/tareas_service.dart';
import '../../tareas/pantallas/formulario_tarea_screen.dart';
import '../../tareas/pantallas/detalle_tarea_screen.dart';

/// Tab que muestra las tareas vinculadas a un cliente específico.
/// Se incluye como pestaña en la pantalla de detalle de cliente.
class TabTareasCliente extends StatelessWidget {
  final String empresaId;
  final String clienteId;
  final String usuarioId;
  final String nombreCliente;

  const TabTareasCliente({
    super.key,
    required this.empresaId,
    required this.clienteId,
    required this.usuarioId,
    required this.nombreCliente,
  });

  @override
  Widget build(BuildContext context) {
    final svc = TareasService();

    return StreamBuilder<List<Tarea>>(
      stream: svc.tareasPorClienteStream(empresaId, clienteId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final todas = snap.data ?? [];
        final pendientes =
            todas.where((t) => t.estado != EstadoTarea.completada && t.estado != EstadoTarea.cancelada).toList();
        final completadas =
            todas.where((t) => t.estado == EstadoTarea.completada).toList();

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Sección pendientes
                  if (pendientes.isEmpty && completadas.isEmpty) ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.task_alt, size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Sin tareas para este cliente',
                              style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  ],
                  if (pendientes.isNotEmpty) ...[
                    _seccionHeader('Tareas activas', pendientes.length,
                        const Color(0xFF1976D2)),
                    const SizedBox(height: 8),
                    ...pendientes.map((t) => _TarjetaTarea(
                          tarea: t,
                          empresaId: empresaId,
                          usuarioId: usuarioId,
                        )),
                  ],
                  if (completadas.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _seccionHeader(
                        'Completadas', completadas.length, Colors.green),
                    const SizedBox(height: 8),
                    ...completadas.map((t) => _TarjetaTarea(
                          tarea: t,
                          empresaId: empresaId,
                          usuarioId: usuarioId,
                          opaca: true,
                        )),
                  ],
                ],
              ),
            ),
            // Botón "Nueva tarea"
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.add_task),
                    label: const Text('Nueva tarea para este cliente'),
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FormularioTareaScreen(
                            empresaId: empresaId,
                            usuarioId: usuarioId,
                            clienteIdPreseleccionado: clienteId,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _seccionHeader(String titulo, int cantidad, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          '$titulo ($cantidad)',
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14, color: color),
        ),
      ],
    );
  }
}

class _TarjetaTarea extends StatelessWidget {
  final Tarea tarea;
  final String empresaId;
  final String usuarioId;
  final bool opaca;

  const _TarjetaTarea({
    required this.tarea,
    required this.empresaId,
    required this.usuarioId,
    this.opaca = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorEstado(tarea.estado);
    return Opacity(
      opacity: opaca ? 0.6 : 1.0,
      child: Card(
        elevation: 1,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconoEstado(tarea.estado), color: color, size: 20),
          ),
          title: Text(
            tarea.titulo,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              decoration: opaca ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tarea.fechaLimite != null)
                Text(
                  'Vence: ${DateFormat('dd/MM/yyyy').format(tarea.fechaLimite!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: tarea.estaAtrasada ? Colors.red : Colors.grey[600],
                  ),
                ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _nombreEstado(tarea.estado),
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (tarea.configuracionRecurrencia != null) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.repeat, size: 12, color: Colors.grey),
                  ],
                ],
              ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetalleTareaScreen(
                  tarea: tarea,
                  empresaId: empresaId,
                  usuarioId: usuarioId,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Color _colorEstado(EstadoTarea e) => switch (e) {
        EstadoTarea.pendiente   => Colors.orange,
        EstadoTarea.enProgreso  => Colors.blue,
        EstadoTarea.enRevision  => Colors.purple,
        EstadoTarea.completada  => Colors.green,
        EstadoTarea.cancelada   => Colors.grey,
      };

  IconData _iconoEstado(EstadoTarea e) => switch (e) {
        EstadoTarea.pendiente   => Icons.radio_button_unchecked,
        EstadoTarea.enProgreso  => Icons.autorenew,
        EstadoTarea.enRevision  => Icons.visibility,
        EstadoTarea.completada  => Icons.check_circle,
        EstadoTarea.cancelada   => Icons.cancel,
      };

  String _nombreEstado(EstadoTarea e) => switch (e) {
        EstadoTarea.pendiente   => 'Pendiente',
        EstadoTarea.enProgreso  => 'En Progreso',
        EstadoTarea.enRevision  => 'En Revisión',
        EstadoTarea.completada  => 'Completada',
        EstadoTarea.cancelada   => 'Cancelada',
      };
}



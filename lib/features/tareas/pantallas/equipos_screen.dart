import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/tarea.dart';
import 'package:planeag_flutter/services/tareas_service.dart';

class EquiposScreen extends StatelessWidget {
  final String empresaId;
  const EquiposScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final svc = TareasService();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Equipos'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Equipo>>(
        stream: svc.equiposStream(empresaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final equipos = snapshot.data ?? [];
          if (equipos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No hay equipos', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _dialogCrearEquipo(context, svc),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear equipo'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: equipos.length,
            itemBuilder: (_, i) => _tarjetaEquipo(context, equipos[i], svc),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_equipos',
        onPressed: () => _dialogCrearEquipo(context, svc),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo equipo'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _tarjetaEquipo(BuildContext context, Equipo equipo, TareasService svc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1976D2).withValues(alpha: 0.15),
          radius: 24,
          child: Text(
            equipo.nombre.isNotEmpty ? equipo.nombre[0].toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2), fontSize: 20),
          ),
        ),
        title: Text(equipo.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (equipo.descripcion != null) ...[
              Text(equipo.descripcion!, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                const Icon(Icons.people, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${equipo.miembrosIds.length} miembros', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'eliminar') {
              _confirmarEliminar(context, equipo, svc);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'eliminar', child: ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red, size: 18),
              title: Text('Eliminar', style: TextStyle(color: Colors.red)),
              contentPadding: EdgeInsets.zero, dense: true,
            )),
          ],
        ),
      ),
    );
  }

  void _dialogCrearEquipo(BuildContext context, TareasService svc) {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo equipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre del equipo *', border: OutlineInputBorder()),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty) return;
              await svc.crearEquipo(
                empresaId: empresaId,
                nombre: nombreCtrl.text.trim(),
                responsableId: 'admin',
                descripcion: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, Equipo equipo, TareasService svc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar equipo'),
        content: Text('¿Eliminar el equipo "${equipo.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              await svc.eliminarEquipo(empresaId, equipo.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planeag_flutter/domain/modelos/tarea.dart';
import 'package:planeag_flutter/services/tareas_service.dart';
import 'package:planeag_flutter/core/widgets/fluix_app_bar.dart';

class EquiposScreen extends StatefulWidget {
  final String empresaId;
  const EquiposScreen({super.key, required this.empresaId});

  @override
  State<EquiposScreen> createState() => _EquiposScreenState();
}

class _EquiposScreenState extends State<EquiposScreen> {
  @override
  Widget build(BuildContext context) {
    final svc = TareasService();
    const bg     = Color(0xFFF1F5F9);
    const cardBg = Colors.white;
    const border = Color(0xFFE5E7EB);
    const textC  = Color(0xFF1F2937);
    const subC   = Color(0xFF6B7280);
    const accent = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: bg,
      appBar: FluixAppBar(
        titulo: 'Equipos',
        showLeading: true,
        extraActions: [
          IconButton(
            onPressed: () => _dialogCrearEquipo(context, svc),
            icon: const Icon(Icons.group_add_rounded),
            tooltip: 'Nuevo equipo',
          ),
        ],
      ),
      body: Column(children: [
        // Content
        Expanded(child: StreamBuilder<List<Equipo>>(
          stream: svc.equiposStream(widget.empresaId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: accent));
            }
            final equipos = snapshot.data ?? [];
            if (equipos.isEmpty) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group_outlined, size: 40, color: accent),
                ),
                const SizedBox(height: 16),
                const Text('Sin equipos creados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textC)),
                const SizedBox(height: 6),
                const Text('Crea equipos para organizar tu plantilla', style: TextStyle(fontSize: 13, color: subC)),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _dialogCrearEquipo(context, svc),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(8)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Crear primer equipo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ]),
                  ),
                ),
              ]));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: equipos.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _tarjetaEquipo(context, equipos[i], svc, textC, subC, border, accent),
            );
          },
        )),
      ]),
    );
  }

  Widget _tarjetaEquipo(BuildContext context, Equipo equipo, TareasService svc,
      Color textC, Color subC, Color border, Color accent) {
    final inicial = equipo.nombre.isNotEmpty ? equipo.nombre[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(inicial,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: accent))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(equipo.nombre, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textC)),
          if (equipo.descripcion != null && equipo.descripcion!.isNotEmpty)
            Text(equipo.descripcion!, style: TextStyle(fontSize: 12, color: subC),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.people_outlined, size: 12, color: subC),
            const SizedBox(width: 4),
            Text('${equipo.miembrosIds.length} miembros', style: TextStyle(fontSize: 11, color: subC)),
          ]),
        ])),
        PopupMenuButton<String>(
          onSelected: (val) {
            if (val == 'eliminar') _confirmarEliminar(context, equipo, svc);
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'eliminar', child: ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red, size: 17),
              title: Text('Eliminar', style: TextStyle(color: Colors.red, fontSize: 13)),
              contentPadding: EdgeInsets.zero, dense: true,
            )),
          ],
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(border: Border.all(color: border), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.more_horiz, size: 15, color: Color(0xFF6B7280)),
          ),
        ),
      ]),
    );
  }

  void _dialogCrearEquipo(BuildContext context, TareasService svc) {
    final nombreCtrl = TextEditingController();
    final descCtrl   = TextEditingController();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.group_add_outlined, color: Color(0xFF3B82F6)),
          SizedBox(width: 8),
          Text('Nuevo equipo', style: TextStyle(fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nombreCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nombre del equipo *',
              prefixIcon: const Icon(Icons.group_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Descripción (opcional)',
              prefixIcon: const Icon(Icons.notes_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty) return;
              await svc.crearEquipo(
                empresaId: widget.empresaId,
                nombre: nombreCtrl.text.trim(),
                responsableId: uid,
                descripcion: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Crear equipo'),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, Equipo equipo, TareasService svc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Eliminar equipo'),
        content: Text('¿Eliminar el equipo "${equipo.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              await svc.eliminarEquipo(widget.empresaId, equipo.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

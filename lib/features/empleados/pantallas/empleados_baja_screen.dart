import 'package:flutter/material.dart';
import 'package:planeag_flutter/services/baja_empleado_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA: EMPLEADOS DADOS DE BAJA
// ═══════════════════════════════════════════════════════════════════════════════

class EmpleadosBajaScreen extends StatelessWidget {
  final String empresaId;

  const EmpleadosBajaScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final svc = BajaEmpleadoService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Empleados dados de baja'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: svc.empleadosDadosDeBaja(empresaId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final empleados = snap.data ?? [];
          if (empleados.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_off_outlined, size: 64,
                      color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No hay empleados dados de baja',
                      style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: empleados.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final emp = empleados[i];
              return _TarjetaEmpleadoBaja(
                empleado: emp,
                empresaId: empresaId,
              );
            },
          );
        },
      ),
    );
  }
}

class _TarjetaEmpleadoBaja extends StatelessWidget {
  final Map<String, dynamic> empleado;
  final String empresaId;

  const _TarjetaEmpleadoBaja({
    required this.empleado,
    required this.empresaId,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = empleado['nombre'] as String? ?? 'Empleado';
    final causaBaja = empleado['causa_baja_etiqueta'] as String? ?? '—';
    final fechaBajaTs = empleado['fecha_baja'];
    final fechaBaja = fechaBajaTs != null
        ? (fechaBajaTs.toDate() as DateTime)
        : null;
    final fmtFecha = fechaBaja != null
        ? '${fechaBaja.day.toString().padLeft(2, '0')}/${fechaBaja.month.toString().padLeft(2, '0')}/${fechaBaja.year}'
        : '—';
    final bajaRevertida = empleado['baja_revertida'] as bool? ?? false;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.red.shade50,
          child: Text(
            nombre.isNotEmpty ? nombre[0] : '?',
            style: TextStyle(color: Colors.red.shade700),
          ),
        ),
        title: Row(children: [
          Expanded(child: Text(nombre,
              style: const TextStyle(fontWeight: FontWeight.w600))),
          if (bajaRevertida)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Revertida',
                  style: TextStyle(fontSize: 10, color: Colors.blue.shade700)),
            ),
        ]),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Baja: $fmtFecha · $causaBaja',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            if (empleado['finiquito_id'] != null)
              Text('Finiquito: ${empleado['finiquito_id']}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.undo, color: Colors.blue),
          tooltip: 'Revertir baja',
          onPressed: () => _confirmarReversion(context, empleado),
        ),
      ),
    );
  }

  Future<void> _confirmarReversion(
      BuildContext context, Map<String, dynamic> emp) async {
    final motivoCtrl = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Revertir baja?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Reactivar a ${emp['nombre']}?\n'
                'El empleado recuperará el acceso a la app.'),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo de la reversión',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          // Segunda confirmación
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx, false); // Cierra el primero
              final confirmado2 = await showDialog<bool>(
                context: context,
                builder: (ctx2) => AlertDialog(
                  title: const Text('Confirmación final'),
                  content: const Text('¿Está SEGURO? Esta acción reactivará '
                      'el empleado en todos los módulos.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx2, false),
                        child: const Text('No')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx2, true),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white),
                      child: const Text('Sí, revertir'),
                    ),
                  ],
                ),
              );
              if (confirmado2 == true) {
                await BajaEmpleadoService().revertirBaja(
                  empresaId: empresaId,
                  empleadoId: emp['id'] as String,
                  motivo: motivoCtrl.text.isNotEmpty
                      ? motivoCtrl.text
                      : 'Reversión manual',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('✅ Baja revertida correctamente'),
                        backgroundColor: Colors.green),
                  );
                }
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.blue,
                    foregroundColor: Colors.white),
            child: const Text('Revertir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await BajaEmpleadoService().revertirBaja(
        empresaId: empresaId,
        empleadoId: emp['id'] as String,
        motivo: motivoCtrl.text.isNotEmpty ? motivoCtrl.text : 'Reversión manual',
      );
    }

    motivoCtrl.dispose();
  }
}


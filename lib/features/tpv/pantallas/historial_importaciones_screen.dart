import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../domain/modelos/importacion_tpv.dart';
import '../../../services/pedidos_service.dart';

class HistorialImportacionesScreen extends StatelessWidget {
  final String empresaId;
  const HistorialImportacionesScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de importaciones', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas').doc(empresaId)
            .collection('importacionesTpv')
            .orderBy('fecha_importacion', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('No hay importaciones registradas',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          final items = snap.data!.docs
              .map((d) => ImportacionTpv.fromFirestore(d))
              .toList();
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _TarjetaImportacion(
              item: items[i],
              empresaId: empresaId,
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaImportacion extends StatelessWidget {
  final ImportacionTpv item;
  final String empresaId;
  const _TarjetaImportacion({required this.item, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upload_file, size: 18, color: Color(0xFF1565C0)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(item.nombreFichero,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text(fmt.format(item.fechaImportacion),
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Stat(Icons.check_circle, '${item.filasImportadas} importadas', Colors.green),
                const SizedBox(width: 16),
                if (item.filasError > 0)
                  _Stat(Icons.error, '${item.filasError} errores', Colors.red),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Deshacer', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _confirmarDeshacer(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarDeshacer(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deshacer importación'),
        content: Text(
            'Se eliminarán ${item.pedidosCreados.length} pedidos creados en esta importación. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deshacerImportacion(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar pedidos'),
          ),
        ],
      ),
    );
  }

  Future<void> _deshacerImportacion(BuildContext context) async {
    try {
      final svc = PedidosService();
      for (final id in item.pedidosCreados) {
        await svc.eliminarPedido(empresaId, id);
      }
      // Eliminar registro de historial
      await FirebaseFirestore.instance
          .collection('empresas').doc(empresaId)
          .collection('importacionesTpv').doc(item.id).delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Importación deshecha correctamente'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al deshacer: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Stat(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 14, color: color),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
  ]);
}


import 'package:flutter/material.dart';
import '../../../domain/modelos/remesa_sepa.dart';
import '../../../services/remesa_sepa_service.dart';
import 'package:planeag_flutter/features/nominas/pantallas/nueva_remesa_form.dart';

/// Pantalla de listado de remesas SEPA generadas.
class RemesaSepaScreen extends StatelessWidget {
  final String empresaId;
  const RemesaSepaScreen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final svc = RemesaSepaService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Remesas SEPA'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<RemesaSepa>>(
        stream: svc.obtenerRemesas(empresaId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final remesas = snap.data ?? [];
          if (remesas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_outlined, size: 72,
                      color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Sin remesas SEPA',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600],
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Genera una remesa desde el módulo de nóminas',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: remesas.length,
            itemBuilder: (_, i) => _TarjetaRemesa(
              remesa: remesas[i],
              empresaId: empresaId,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NuevaRemesaForm(empresaId: empresaId),
          ),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva remesa'),
      ),
    );
  }
}

class _TarjetaRemesa extends StatelessWidget {
  final RemesaSepa remesa;
  final String empresaId;
  const _TarjetaRemesa({required this.remesa, required this.empresaId});

  Color _colorEstado(EstadoRemesa e) {
    switch (e) {
      case EstadoRemesa.generada:   return const Color(0xFF1976D2);
      case EstadoRemesa.enviada:    return const Color(0xFFF57C00);
      case EstadoRemesa.confirmada: return const Color(0xFF2E7D32);
      case EstadoRemesa.rechazada:  return const Color(0xFFC62828);
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = RemesaSepaService();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _colorEstado(remesa.estado).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    remesa.estado.etiqueta,
                    style: TextStyle(
                      color: _colorEstado(remesa.estado),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  remesa.periodoTexto,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _dato(Icons.people, '${remesa.nTransferencias} transferencias'),
                const SizedBox(width: 16),
                _dato(Icons.euro, '${remesa.importeTotal.toStringAsFixed(2)} €'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _dato(Icons.calendar_today,
                    'Ejecución: ${remesa.fechaEjecucion.day}/${remesa.fechaEjecucion.month}/${remesa.fechaEjecucion.year}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (remesa.xmlGenerado != null) ...[
                  IconButton(
                    icon: const Icon(Icons.download, color: Color(0xFF00796B)),
                    tooltip: 'Guardar en dispositivo',
                    onPressed: () => svc.descargarXml(context, remesa),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Compartir XML'),
                    onPressed: () => svc.compartirXml(context, remesa),
                  ),
                ],
                if (remesa.estado == EstadoRemesa.generada) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Marcar enviada'),
                    onPressed: () => svc.marcarComoEnviada(empresaId, remesa.id),
                  ),
                ],
                if (remesa.estado == EstadoRemesa.enviada) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.check_circle, size: 18,
                        color: Color(0xFF2E7D32)),
                    label: const Text('Confirmar'),
                    onPressed: () async {
                      await svc.marcarComoConfirmada(empresaId, remesa.id);
                      await svc.marcarNominasPagadas(empresaId, remesa.nominasIds);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Remesa confirmada · Nóminas marcadas como pagadas'),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dato(IconData icon, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(texto, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}





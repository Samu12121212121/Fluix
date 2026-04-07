import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/finiquito.dart';
import 'package:planeag_flutter/services/finiquito_service.dart';
import 'package:planeag_flutter/features/finiquitos/pantallas/nuevo_finiquito_form.dart';
import 'package:planeag_flutter/features/finiquitos/pantallas/finiquito_detalle.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL DE FINIQUITOS
// ═════════════════════════════════════════════════════════════════════════════

class FiniquitosScreen extends StatelessWidget {
  final String empresaId;
  final String? empleadoIdFiltro;

  const FiniquitosScreen({
    super.key,
    required this.empresaId,
    this.empleadoIdFiltro,
  });

  @override
  Widget build(BuildContext context) {
    final svc = FiniquitoService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Finiquitos y Liquidaciones'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NuevoFiniquitoForm(empresaId: empresaId),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo finiquito'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<List<Finiquito>>(
        stream: empleadoIdFiltro != null
            ? svc.obtenerFiniquitosEmpleado(empresaId, empleadoIdFiltro!)
            : svc.obtenerFiniquitos(empresaId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final finiquitos = snap.data ?? [];
          if (finiquitos.isEmpty) return _buildVacio();
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: finiquitos.length,
            itemBuilder: (context, i) => _TarjetaFiniquito(
              finiquito: finiquitos[i],
              empresaId: empresaId,
            ),
          );
        },
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No hay finiquitos registrados',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Pulsa + para crear un nuevo finiquito',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TARJETA DE FINIQUITO
// ═════════════════════════════════════════════════════════════════════════════

class _TarjetaFiniquito extends StatelessWidget {
  final Finiquito finiquito;
  final String empresaId;

  const _TarjetaFiniquito({
    required this.finiquito,
    required this.empresaId,
  });

  Color get _colorEstado {
    switch (finiquito.estado) {
      case EstadoFiniquito.borrador: return Colors.orange;
      case EstadoFiniquito.firmado:  return Colors.blue;
      case EstadoFiniquito.pagado:   return Colors.green;
    }
  }

  IconData get _iconoCausa {
    switch (finiquito.causaBaja) {
      case CausaBaja.dimision:            return Icons.exit_to_app;
      case CausaBaja.despidoImprocedente: return Icons.gavel;
      case CausaBaja.despidoProcedente:   return Icons.work_off;
      case CausaBaja.finContrato:         return Icons.timer_off;
      case CausaBaja.mutuoAcuerdo:        return Icons.handshake;
      case CausaBaja.ere:                 return Icons.groups;
      case CausaBaja.jubilacion:          return Icons.elderly;
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = finiquito;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FiniquitoDetalle(
              finiquito: f,
              empresaId: empresaId,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono causa
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _colorEstado.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconoCausa, color: _colorEstado, size: 22),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.empleadoNombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${f.causaBaja.etiqueta} · ${_fmtDate(f.fechaBaja)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Antigüedad: ${f.antiguedadTexto}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              // Importe + estado
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${f.liquidoPercibir.toStringAsFixed(2)} €',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _colorEstado.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      f.estado.etiqueta,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _colorEstado,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}





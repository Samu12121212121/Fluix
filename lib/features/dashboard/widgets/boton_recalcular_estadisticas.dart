import 'package:flutter/material.dart';
import '../../../services/estadisticas_service.dart';

/// Widget para recalcular manualmente todas las estadísticas de la empresa
/// Útil cuando:
/// - Los datos de estadisticas/resumen están desactualizados
/// - Se importaron datos en masa desde admin
/// - Se corrigieron errores en facturas/reservas
class BotonRecalcularEstadisticas extends StatefulWidget {
  final String empresaId;
  
  const BotonRecalcularEstadisticas({
    super.key,
    required this.empresaId,
  });

  @override
  State<BotonRecalcularEstadisticas> createState() => _BotonRecalcularEstadisticasState();
}

class _BotonRecalcularEstadisticasState extends State<BotonRecalcularEstadisticas> {
  bool _recalculando = false;

  Future<void> _recalcular() async {
    setState(() => _recalculando = true);
    
    try {
      await EstadisticasService().calcularEstadisticasCompletas(widget.empresaId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Estadísticas actualizadas',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('Todos los KPIs se han recalculado correctamente',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al recalcular: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _recalculando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Color(0xFF9C27B0),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actualizar estadísticas',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Recalcula todos los KPIs del dashboard',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _itemRecalculado(Icons.calendar_month, 'Reservas y citas'),
                _itemRecalculado(Icons.people, 'Clientes nuevos'),
                _itemRecalculado(Icons.euro, 'Ingresos del mes'),
                _itemRecalculado(Icons.star, 'Valoraciones Google'),
                _itemRecalculado(Icons.receipt, 'Facturas emitidas'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _recalculando ? null : _recalcular,
              icon: _recalculando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh, size: 20),
              label: Text(_recalculando ? 'Recalculando...' : 'Recalcular ahora'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '💡 Usa esto si los números del dashboard no coinciden con los datos reales',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRecalculado(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icono, size: 14, color: const Color(0xFF9C27B0).withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Text(
            texto,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

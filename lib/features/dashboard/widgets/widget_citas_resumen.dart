import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Widget de resumen de citas para el dashboard
/// Muestra las próximas citas y estadísticas rápidas
class WidgetCitasResumen extends StatelessWidget {
  final String empresaId;

  const WidgetCitasResumen({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('citas')
          .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
          .orderBy('fecha')
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        final citas = snapshot.data?.docs ?? [];

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [const Color(0xFFE1F5FE), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00ACC1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.event_available,
                        color: Color(0xFF00ACC1),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Próximas Citas',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '${citas.length} citas programadas',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Lista de citas
                if (citas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 48,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sin citas próximas',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: citas.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final doc = entry.value;
                      final data = doc.data() as Map<String, dynamic>;

                      final fecha = data['fecha'] is Timestamp
                          ? (data['fecha'] as Timestamp).toDate()
                          : DateTime.tryParse(data['fecha']?.toString() ?? '');

                      final cliente = data['nombre_cliente'] ?? 'Sin nombre';
                      final hora = data['hora_inicio'] ?? '---';
                      final estado = (data['estado'] as String? ?? 'PENDIENTE').toUpperCase();

                      Color _colorEstado() {
                        switch (estado) {
                          case 'CONFIRMADA':
                            return const Color(0xFF4CAF50);
                          case 'CANCELADA':
                            return const Color(0xFFD32F2F);
                          case 'COMPLETADA':
                            return const Color(0xFF1976D2);
                          default:
                            return const Color(0xFFF57C00);
                        }
                      }

                      return Padding(
                        padding: EdgeInsets.only(bottom: idx < citas.length - 1 ? 12 : 0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _colorEstado(),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cliente,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${fecha != null ? DateFormat('dd/MM · HH:mm', 'es').format(fecha) : 'Sin fecha'} • $hora',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _colorEstado().withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  estado,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _colorEstado(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}


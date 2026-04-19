import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Widget de KPIs Rápidos ────────────────────────────────────────────────────

class WidgetKpisRapidos extends StatelessWidget {
  final String empresaId;

  const WidgetKpisRapidos({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KPIs Rápidos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            FutureBuilder<Map<String, dynamic>>(
              future: _obtenerKpisRapidos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final data = snapshot.data ?? _getDatosDemo();
                final ratingPromedio =
                    (data['rating_promedio'] ?? 0.0) as double;
                return Row(
                  children: [
                    Expanded(
                        child: _buildKpiItem(
                      'Hoy',
                      '${data['reservas_hoy'] ?? 0}',
                      Icons.calendar_today,
                      Colors.blue,
                    )),
                    Expanded(
                        child: _buildKpiItem(
                      'Semana',
                      '€${data['ingresos_semana'] ?? 0}',
                      Icons.euro,
                      Colors.green,
                    )),
                    Expanded(
                        child: _buildKpiItem(
                      'Rating',
                      ratingPromedio > 0
                          ? '${ratingPromedio.toStringAsFixed(1)} ⭐'
                          : '- ⭐',
                      Icons.star,
                      Colors.orange,
                    )),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiItem(
      String label, String valor, IconData icono, Color color) {
    return Column(
      children: [
        Icon(icono, color: color, size: 20),
        const SizedBox(height: 4),
        Text(valor,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Future<Map<String, dynamic>> _obtenerKpisRapidos() async {
    // Lógica para obtener KPIs desde cache o Firebase
    return _getDatosDemo();
  }

  Map<String, dynamic> _getDatosDemo() => {
        'reservas_hoy': 6,
        'ingresos_semana': 1250,
        'rating_promedio': 4.6,
      };
}

// ── Widget de Reservas de Hoy ─────────────────────────────────────────────────

class WidgetReservasHoy extends StatelessWidget {
  final String empresaId;

  const WidgetReservasHoy({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today,
                    color: const Color(0xFF1976D2), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Reservas de Hoy',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('empresas')
                    .doc(empresaId)
                    .collection('reservas')
                    .where('fecha',
                        isGreaterThanOrEqualTo:
                            Timestamp.fromDate(inicioHoy))
                    .where('fecha',
                        isLessThan: Timestamp.fromDate(finHoy))
                    .orderBy('fecha')
                    .limit(10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.free_cancellation,
                              color: Colors.grey[400], size: 40),
                          const SizedBox(height: 12),
                          Text('Sin reservas hoy',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  // Mostrar hasta 5 reservas con scroll si hay más
                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final fecha =
                          (data['fecha'] as Timestamp?)?.toDate();
                      final hora = fecha != null
                          ? '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}'
                          : '--:--';
                      final cliente =
                          data['cliente'] as String? ?? 'Cliente';
                      final servicio = data['servicio'] as String?;
                      final estado =
                          (data['estado'] as String? ?? 'PENDIENTE')
                              .toUpperCase();

                      Color estadoColor;
                      String estadoTexto;
                      switch (estado) {
                        case 'CONFIRMADA':
                          estadoColor = const Color(0xFF1976D2);
                          estadoTexto = 'Confirmada';
                          break;
                        case 'PENDIENTE':
                          estadoColor = const Color(0xFFF57C00);
                          estadoTexto = 'Pendiente';
                          break;
                        case 'CANCELADA':
                          estadoColor = Colors.red;
                          estadoTexto = 'Cancelada';
                          break;
                        default:
                          estadoColor = Colors.grey;
                          estadoTexto = estado;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1976D2)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.access_time,
                                  size: 18, color: Color(0xFF1976D2)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(hora,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                  Text(cliente,
                                      style: const TextStyle(
                                          fontSize: 13),
                                      overflow: TextOverflow.ellipsis),
                                  if (servicio != null)
                                    Text(servicio,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                        overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: estadoColor
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                estadoTexto,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: estadoColor,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _obtenerReservasHoy() async {
    // Lógica para obtener reservas de hoy
    return _getReservasDemo();
  }

  List<Map<String, dynamic>> _getReservasDemo() => [
        {'hora': '10:00', 'cliente': 'María García', 'servicio': 'Corte + Peinado'},
        {'hora': '11:30', 'cliente': 'Ana López', 'servicio': 'Tinte + Corte'},
        {'hora': '13:00', 'cliente': 'Carmen Ruiz', 'servicio': 'Tratamiento capilar'},
        {'hora': '15:00', 'cliente': 'Laura Martín', 'servicio': 'Peinado evento'},
        {'hora': '16:30', 'cliente': 'Sofia Jiménez', 'servicio': 'Corte'},
      ];
}

// ── Widget de Valoraciones Recientes ─────────────────────────────────────────

class WidgetValoracionesRecientes extends StatelessWidget {
  final String empresaId;

  const WidgetValoracionesRecientes({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.star, color: Color(0xFF4CAF50), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Valoraciones Recientes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _obtenerValoracionesRecientes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final valoraciones =
                      snapshot.data ?? _getValoracionesDemo();

                  if (valoraciones.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_border,
                              color: Colors.grey[400], size: 40),
                          const SizedBox(height: 12),
                          Text('Sin valoraciones',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: valoraciones.length,
                    itemBuilder: (context, index) {
                      final valoracion = valoraciones[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    valoracion['cliente'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: List.generate(
                                      5,
                                      (i) => Icon(
                                            Icons.star,
                                            size: 16,
                                            color: i <
                                                    _obtenerCalificacion(
                                                        valoracion)
                                                ? const Color(0xFFF57C00)
                                                : Colors.grey[300],
                                          )),
                                ),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              valoracion['comentario'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatearFechaValoracion(valoracion),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _obtenerValoracionesRecientes() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('valoraciones')
          .orderBy('fecha', descending: true)
          .limit(5)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'cliente': data['cliente'] as String? ?? 'Cliente',
          'calificacion':
              (data['calificacion'] ?? data['estrellas'] ?? 5) as int,
          'comentario': data['comentario'] as String? ?? 'Sin comentario',
          'fecha': data['fecha'],
        };
      }).toList();
    } catch (e) {
      return _getValoracionesDemo();
    }
  }

  List<Map<String, dynamic>> _getValoracionesDemo() => [
        {
          'cliente': 'Ana P.',
          'estrellas': 5,
          'comentario':
              'Increíble transformación, súper contenta con el resultado. Lo recomiendo totalmente.'
        },
        {
          'cliente': 'Miguel R.',
          'estrellas': 4,
          'comentario': 'Buen servicio y precio justo. El personal es muy amable.'
        },
        {
          'cliente': 'Laura M.',
          'estrellas': 5,
          'comentario':
              'Excelente servicio, muy profesional. El trato fue excepcional y el resultado superó mis expectativas.'
        },
        {
          'cliente': 'Carlos G.',
          'estrellas': 4,
          'comentario': 'Muy buena experiencia, volveré sin duda.'
        },
      ];

  // Helper method to get rating from different field names
  int _obtenerCalificacion(Map<String, dynamic> valoracion) {
    return (valoracion['estrellas'] ??
            valoracion['calificacion'] ??
            valoracion['rating'] ??
            valoracion['stars'] ??
            0) as int;
  }

  // Helper method to format date for valoraciones
  String _formatearFechaValoracion(Map<String, dynamic> valoracion) {
    try {
      if (valoracion['fecha'] != null) {
        final fecha = valoracion['fecha'];
        if (fecha is Timestamp) {
          final dateTime = fecha.toDate();
          final ahora = DateTime.now();
          final diferencia = ahora.difference(dateTime);
          if (diferencia.inDays < 1) {
            return 'Hoy';
          } else if (diferencia.inDays < 7) {
            return 'Hace ${diferencia.inDays} día${diferencia.inDays > 1 ? 's' : ''}';
          } else if (diferencia.inDays < 30) {
            final semanas = (diferencia.inDays / 7).floor();
            return 'Hace $semanas semana${semanas > 1 ? 's' : ''}';
          } else {
            final meses = (diferencia.inDays / 30).floor();
            return 'Hace $meses mes${meses > 1 ? 'es' : ''}';
          }
        }
      }
      return 'Reciente';
    } catch (e) {
      return 'Reciente';
    }
  }
}

// ── Placeholders para otros widgets ──────────────────────────────────────────

class WidgetIngresosMes extends StatelessWidget {
  final String empresaId;
  const WidgetIngresosMes({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) =>
      _WidgetPlaceholder('Ingresos del Mes', Icons.euro);
}

class WidgetClientesNuevos extends StatelessWidget {
  final String empresaId;
  const WidgetClientesNuevos({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) =>
      _WidgetPlaceholder('Clientes Nuevos', Icons.people);
}

class WidgetAlertasNegocio extends StatelessWidget {
  final String empresaId;
  const WidgetAlertasNegocio({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) =>
      _WidgetPlaceholder('Alertas del Negocio', Icons.notifications_active);
}

class WidgetOfertasSugeridas extends StatelessWidget {
  final String empresaId;
  const WidgetOfertasSugeridas({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) =>
      _WidgetPlaceholder('Ofertas Sugeridas', Icons.local_offer);
}

class WidgetHorariosOcupacion extends StatelessWidget {
  final String empresaId;
  const WidgetHorariosOcupacion({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) =>
      _WidgetPlaceholder('Horarios de Ocupación', Icons.schedule);
}

// ── Placeholder genérico ──────────────────────────────────────────────────────

class _WidgetPlaceholder extends StatelessWidget {
  final String titulo;
  final IconData icono;
  const _WidgetPlaceholder(this.titulo, this.icono);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, color: Colors.orange, size: 24),
              ),
              const SizedBox(height: 4),
              Text(
                titulo,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Próximamente',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

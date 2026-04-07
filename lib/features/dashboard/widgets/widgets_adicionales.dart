import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Widget de KPIs Rápidos
class WidgetKpisRapidos extends StatelessWidget {
  final String empresaId;

  const WidgetKpisRapidos({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14), // Reducido de 16 a 14
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: const Color(0xFF4CAF50), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'KPIs Rápidos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, dynamic>>(
              future: _obtenerKpisRapidos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 60, // Reducido de 80 a 60
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final data = snapshot.data ?? _getDatosDemo();
                return Row(
                  children: [
                    Expanded(child: _buildKpiItem(
                      'Hoy', '${data['reservas_hoy'] ?? 0}',
                      Icons.today, const Color(0xFF1976D2)
                    )),
                    Expanded(child: _buildKpiItem(
                      'Semana', '€${data['ingresos_semana'] ?? 0}',
                      Icons.euro, const Color(0xFF4CAF50)
                    )),
                    Expanded(child: _buildKpiItem(
                      'Rating', '${(data['rating_promedio'] ?? 0.0).toStringAsFixed(1)} ⭐',
                      Icons.star, const Color(0xFFF57C00)
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

  Widget _buildKpiItem(String titulo, String valor, IconData icono, Color color) {
    return Column(
      children: [
        Icon(icono, color: color, size: 24),
        const SizedBox(height: 8),
        Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        Text(titulo, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
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

// Widget de Reservas de Hoy
class WidgetReservasHoy extends StatelessWidget {
  final String empresaId;

  const WidgetReservasHoy({super.key, required this.empresaId});

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
                Icon(Icons.calendar_today, color: const Color(0xFF1976D2), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Reservas de Hoy',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded( // Cambiado para que use todo el espacio disponible
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _obtenerReservasHoy(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final reservas = snapshot.data ?? _getReservasDemo();
                  if (reservas.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.free_cancellation, color: Colors.grey[400], size: 40), // Icono más grande
                          const SizedBox(height: 12),
                          Text('Sin reservas hoy',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16)), // Texto más grande
                        ],
                      ),
                    );
                  }

                  // Mostrar hasta 5 reservas con scroll si hay más
                  return ListView.builder(
                    itemCount: reservas.length,
                    itemBuilder: (context, index) {
                      final reserva = reservas[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10), // Más espacio entre items
                        padding: const EdgeInsets.all(12), // Más padding
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1976D2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.access_time, size: 18, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reserva['hora'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 14, // Aumentado de 12 a 14
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1976D2),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    reserva['cliente'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 13, // Aumentado de 12 a 13
                                      color: Colors.black87,
                                    ),
                                  ),
                                  if (reserva['servicio'] != null)
                                    Text(
                                      reserva['servicio'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Confirmada',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
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

// Widget de Valoraciones Recientes
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
                Icon(Icons.star, color: const Color(0xFFF57C00), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Valoraciones Recientes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded( // Cambiado para que use todo el espacio disponible
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _obtenerValoracionesRecientes(),
                builder: (context, snapshot) {
                  final valoraciones = snapshot.data ?? _getValoracionesDemo();

                  if (valoraciones.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_border, color: Colors.grey[400], size: 40), // Icono más grande
                          const SizedBox(height: 12),
                          Text('Sin valoraciones aún',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16)), // Texto más grande
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: valoraciones.length,
                    itemBuilder: (context, index) {
                      final valoracion = valoraciones[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12), // Más espacio
                        padding: const EdgeInsets.all(12), // Más padding
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF57C00),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(Icons.person, size: 14, color: Colors.white),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  valoracion['cliente'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14, // Aumentado de 12 a 14
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Row(
                                  children: List.generate(5, (i) => Icon(
                                    Icons.star,
                                    size: 16, // Aumentado de 12 a 16
                                    color: i < _obtenerCalificacion(valoracion)
                                        ? const Color(0xFFF57C00)
                                        : Colors.grey[300],
                                  )),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8), // Más espacio
                            Text(
                              valoracion['comentario'] ?? '',
                              style: TextStyle(
                                fontSize: 12, // Mantenido en 12 para comentarios
                                color: Colors.grey[700], // Color más oscuro
                                height: 1.4, // Mejor line height
                              ),
                              maxLines: 3, // Permitir más líneas
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

      if (querySnapshot.docs.isEmpty) {
        return _getValoracionesDemo();
      }

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'cliente': data['cliente'] ?? 'Cliente',
          'estrellas': data['calificacion'] ?? data['estrellas'] ?? data['rating'] ?? 5,
          'comentario': data['comentario'] ?? data['descripcion'] ?? 'Sin comentario',
        };
      }).toList();
    } catch (e) {
      print('❌ Error obteniendo valoraciones: $e');
      return _getValoracionesDemo();
    }
  }

  List<Map<String, dynamic>> _getValoracionesDemo() => [
    {
      'cliente': 'Laura M.',
      'estrellas': 5,
      'comentario': 'Excelente servicio, muy profesional. El trato fue excepcional y el resultado superó mis expectativas.'
    },
    {
      'cliente': 'Carlos G.',
      'estrellas': 4,
      'comentario': 'Muy buena atención, repetiré sin duda. El ambiente es acogedor.'
    },
    {
      'cliente': 'Ana P.',
      'estrellas': 5,
      'comentario': 'Increíble transformación, súper contenta con el resultado. Lo recomiendo totalmente.'
    },
    {
      'cliente': 'Miguel R.',
      'estrellas': 4,
      'comentario': 'Buen servicio y precio justo. El personal es muy amable.'
    },
  ];

  // Helper method to get rating from different field names
  int _obtenerCalificacion(Map<String, dynamic> valoracion) {
    // Try different field names that might be used
    return (valoracion['estrellas'] ??
           valoracion['calificacion'] ??
           valoracion['rating'] ??
           valoracion['stars'] ?? 0) as int;
  }

  // Helper method to format date for valoraciones
  String _formatearFechaValoracion(Map<String, dynamic> valoracion) {
    try {
      if (valoracion['fecha'] != null) {
        // If it's a timestamp
        final fecha = valoracion['fecha'];
        if (fecha is Timestamp) {
          final dateTime = fecha.toDate();
          final ahora = DateTime.now();
          final diferencia = ahora.difference(dateTime);

          if (diferencia.inDays < 1) {
            return 'Hoy';
          } else if (diferencia.inDays < 7) {
            return 'Hace ${diferencia.inDays} días';
          } else {
            return 'Hace ${(diferencia.inDays / 7).floor()} semanas';
          }
        }
      }
      return 'Reciente';
    } catch (e) {
      return 'Reciente';
    }
  }
}

// Placeholders para otros widgets
class WidgetIngresosMes extends StatelessWidget {
  final String empresaId;
  const WidgetIngresosMes({super.key, required this.empresaId});
  @override
  Widget build(BuildContext context) => _WidgetPlaceholder('Ingresos del Mes', Icons.euro);
}

class WidgetClientesNuevos extends StatelessWidget {
  final String empresaId;
  const WidgetClientesNuevos({super.key, required this.empresaId});
  @override
  Widget build(BuildContext context) => _WidgetPlaceholder('Clientes Nuevos', Icons.people);
}

class WidgetAlertasNegocio extends StatelessWidget {
  final String empresaId;
  const WidgetAlertasNegocio({super.key, required this.empresaId});
  @override
  Widget build(BuildContext context) => _WidgetPlaceholder('Alertas del Negocio', Icons.notifications);
}

class WidgetOfertasSugeridas extends StatelessWidget {
  final String empresaId;
  const WidgetOfertasSugeridas({super.key, required this.empresaId});
  @override
  Widget build(BuildContext context) => _WidgetPlaceholder('Ofertas Sugeridas', Icons.local_offer);
}

class WidgetHorariosOcupacion extends StatelessWidget {
  final String empresaId;
  const WidgetHorariosOcupacion({super.key, required this.empresaId});
  @override
  Widget build(BuildContext context) => _WidgetPlaceholder('Horarios Ocupación', Icons.schedule);
}

// Widget placeholder genérico
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
        height: 100, // Reducido de 120 a 100
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 32, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                titulo,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Próximamente',
                  style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




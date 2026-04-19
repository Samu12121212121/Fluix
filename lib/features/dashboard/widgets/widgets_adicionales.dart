      if (valoracion['fecha'] != null) {
      'cliente': 'Ana P.',
      'estrellas': 5,
      'comentario': 'Increíble transformación, súper contenta con el resultado. Lo recomiendo totalmente.'
    },
    {
      'cliente': 'Miguel R.',
      'estrellas': 4,
      'comentario': 'Buen servicio y precio justo. El personal es muy amable.'
    },
              child: FutureBuilder<List<Map<String, dynamic>>>(

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
                  // Mostrar hasta 5 reservas con scroll si hay más

  Future<Map<String, dynamic>> _obtenerKpisRapidos() async {
    // Lógica para obtener KPIs desde cache o Firebase
    return _getDatosDemo();
  }

  Map<String, dynamic> _getDatosDemo() => {
    'reservas_hoy': 6,
    'ingresos_semana': 1250,
    'rating_promedio': 4.6,
  };
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Widget de KPIs Rápidos
  final String empresaId;

  const WidgetKpisRapidos({super.key, required this.empresaId});

  @override
                    height: 60,
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
                int reservasHoy = 0;
                double ingresosSemana = 0;
                double ratingPromedio = 0;

  Widget build(BuildContext context) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  if (data != null) {
        padding: const EdgeInsets.all(14), // Reducido de 16 a 14
                  'KPIs Rápidos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                      'Rating', ratingPromedio > 0 ? '${ratingPromedio.toStringAsFixed(1)} ⭐' : '- ⭐',
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: _obtenerKpisRapidos(),
                    height: 60, // Reducido de 80 a 60
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final data = snapshot.data ?? _getDatosDemo();
                return Row(
                  children: [
                    Expanded(child: _buildKpiItem(
                    height: 60, // Reducido de 80 a 60
            Row(
                    )),
                final data = snapshot.data ?? _getDatosDemo();
        Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                const Text(
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

              ],

  @override
  Widget build(BuildContext context) {
    return Card(
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    final finHoy = inicioHoy.add(const Duration(days: 1));

      elevation: 2,
                      'Hoy', '${data['reservas_hoy'] ?? 0}',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                      'Semana', '€${data['ingresos_semana'] ?? 0}',
              children: [
                Icon(Icons.calendar_today, color: const Color(0xFF1976D2), size: 20),
                      'Rating', '${(data['rating_promedio'] ?? 0.0).toStringAsFixed(1)} ⭐',
                const Text(
                  'Reservas de Hoy',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
                stream: FirebaseFirestore.instance
                    .collection('empresas')
                    .doc(empresaId)
                    .collection('reservas')
                    .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
                    .where('fecha', isLessThan: Timestamp.fromDate(finHoy))
                    .orderBy('fecha')
                    .limit(10)
                    .snapshots(),
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          Text('Sin reservas hoy',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16)), // Texto más grande
                        ],
                      ),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _obtenerReservasHoy(),
                builder: (context, snapshot) {
                    itemCount: snapshot.data!.docs.length,
                            Container(
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      final fecha = (data['fecha'] as Timestamp?)?.toDate();
                      final hora = fecha != null 
                          ? '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}'
                          : '--:--';
                      final cliente = data['cliente'] as String? ?? 'Cliente';
                          Icon(Icons.free_cancellation, color: Colors.grey[400], size: 40), // Icono más grande
                          const SizedBox(height: 12),
                      final estado = (data['estado'] as String? ?? 'PENDIENTE').toUpperCase();
                      
                    );
                      String estadoTexto;
                      switch (estado) {
                        case 'CONFIRMADA':
                  // Mostrar hasta 5 reservas con scroll si hay más
                          estadoTexto = 'Confirmada';
                          break;
                        case 'PENDIENTE':
                          estadoColor = const Color(0xFFF57C00);
                          estadoTexto = 'Pendiente';
                          children: [
                        case 'CANCELADA':
                              padding: const EdgeInsets.all(8),
                                ),
                              ),
                            ),
                                    hora,
                        ),
                                      fontSize: 14,
                    },
                  );
                },
              ),
            ),
          ],
                                    cliente,
      ),
                                      fontSize: 13,
  }

  Future<List<Map<String, dynamic>>> _obtenerReservasHoy() async {
                                  if (servicio != null)
    return _getReservasDemo();
                                      servicio,

  List<Map<String, dynamic>> _getReservasDemo() => [
    {'hora': '10:00', 'cliente': 'María García', 'servicio': 'Corte + Peinado'},
    {'hora': '11:30', 'cliente': 'Ana López', 'servicio': 'Tinte + Corte'},
    {'hora': '13:00', 'cliente': 'Carmen Ruiz', 'servicio': 'Tratamiento capilar'},
    {'hora': '15:00', 'cliente': 'Laura Martín', 'servicio': 'Peinado evento'},
    {'hora': '16:30', 'cliente': 'Sofia Jiménez', 'servicio': 'Corte'},
  ];
}

// Widget de Valoraciones Recientes
                                color: estadoColor,
  final String empresaId;

                              child: Text(
                                estadoTexto,
                                style: const TextStyle(
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
                                color: const Color(0xFF1976D2),
                                borderRadius: BorderRadius.circular(8),
                        padding: const EdgeInsets.all(12), // Más padding
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

                              child: Icon(Icons.access_time, size: 18, color: Colors.white),
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_border, color: Colors.grey[400], size: 40), // Icono más grande
                          const SizedBox(height: 12),
                                    reserva['hora'] ?? '',
                                      fontSize: 14, // Aumentado de 12 a 14
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: valoraciones.length,
                    itemBuilder: (context, index) {
                      final valoracion = valoraciones[index];
                                      fontWeight: FontWeight.w700,
                                    reserva['cliente'] ?? '',
                                      fontSize: 13, // Aumentado de 12 a 13
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                                  if (reserva['servicio'] != null)
                        ),
                          ],
                      );
                          children: [
                            Row(
                              children: [
                                Container(
        ),
                                  decoration: BoxDecoration(
    );
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
    // Lógica para obtener reservas de hoy
                    .collection('empresas')
                    .doc(empresaId)
  }
                    .orderBy('fecha', descending: true)
                    .limit(5)
                    .snapshots(),
                                ),
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                              child: const Text(
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                                style: TextStyle(
class WidgetValoracionesRecientes extends StatelessWidget {
  const WidgetValoracionesRecientes({super.key, required this.empresaId});

  @override
                                ),
                                const Spacer(),
                              style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                                  children: List.generate(5, (i) => Icon(
                                    Icons.star,
                                    size: 16, // Aumentado de 12 a 16
                                    color: i < _obtenerCalificacion(valoracion)
                                        ? const Color(0xFFF57C00)
                                        : Colors.grey[300],
                    itemCount: snapshot.data!.docs.length,
            Expanded( // Cambiado para que use todo el espacio disponible
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      final cliente = data['cliente'] as String? ?? 'Cliente';
                      final calificacion = (data['calificacion'] ?? data['estrellas'] ?? 5) as int;
                      final comentario = data['comentario'] as String? ?? 'Sin comentario';
                      final fecha = data['fecha'] as Timestamp?;

                future: _obtenerValoracionesRecientes(),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                              ),
                              maxLines: 3, // Permitir más líneas
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                color: const Color(0xFF4CAF50),
                          Icon(Icons.star_border, color: Colors.grey[400], size: 40), // Icono más grande
                        ),
                      );
                    },
                  );
                                const SizedBox(width: 8),
                                  child: Text(
                                    cliente,
                                    style: const TextStyle(
                                      fontSize: 14,
                                'Confirmada',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                    itemCount: valoraciones.length,
    try {
                                const SizedBox(width: 8),
          .collection('empresas')
                      final valoracion = valoraciones[index];
                                  ),
                                    size: 16,
                                    color: i < calificacion
                                Row(
      return _getValoracionesDemo();
    }
  }

  List<Map<String, dynamic>> _getValoracionesDemo() => [
                            const SizedBox(height: 8),
      'cliente': 'Laura M.',
                              comentario,
      'comentario': 'Excelente servicio, muy profesional. El trato fue excepcional y el resultado superó mis expectativas.'
                                fontSize: 12,
                                color: Colors.grey[700],
                                  )),
      'estrellas': 4,
                        margin: const EdgeInsets.only(bottom: 12), // Más espacio
                              maxLines: 3,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                              ),
                            ],
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
        final fecha = valoracion['fecha'];
        if (fecha is Timestamp) {
                                Text(
                                  valoracion['cliente'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14, // Aumentado de 12 a 14
                                    fontWeight: FontWeight.w600,
          }
        }
      }
      return 'Reciente';
      return 'Reciente';
    } catch (e) {
      return 'Reciente';
    }
  }
}

// Placeholders para otros widgets
class WidgetIngresosMes extends StatelessWidget {
  final String empresaId;
                                const Spacer(),
  @override
  Widget build(BuildContext context) => _WidgetPlaceholder('Ingresos del Mes', Icons.euro);
}

class WidgetClientesNuevos extends StatelessWidget {
                                    size: 16, // Aumentado de 12 a 16
                                    color: i < _obtenerCalificacion(valoracion)
  @override
  Widget build(BuildContext context) => _WidgetPlaceholder('Clientes Nuevos', Icons.people);
}

class WidgetAlertasNegocio extends StatelessWidget {
  final String empresaId;
                            const SizedBox(height: 8), // Más espacio
  @override
                              valoracion['comentario'] ?? '',
}

class WidgetOfertasSugeridas extends StatelessWidget {
  final String empresaId;
                                fontSize: 12, // Mantenido en 12 para comentarios
                                color: Colors.grey[700], // Color más oscuro
                              maxLines: 3, // Permitir más líneas
}

class WidgetHorariosOcupacion extends StatelessWidget {
  final String empresaId;
                            const SizedBox(height: 6),
                            Text(
                              _formatearFechaValoracion(valoracion),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
      child: Container(
        height: 100, // Reducido de 120 a 100
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
  Future<List<Map<String, dynamic>>> _obtenerValoracionesRecientes() async {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('empresas')
                                color: Colors.grey[700], // Color más oscuro
                                height: 1.4, // Mejor line height
      final dateTime = timestamp.toDate();
      final ahora = DateTime.now();
      final diferencia = ahora.difference(dateTime);
          .doc(empresaId)
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
        };
      }).toList();
    } catch (e) {
          .collection('valoraciones')
          if (diferencia.inDays < 1) {
            return 'Hoy';
          } else if (diferencia.inDays < 7) {
            return 'Hace ${diferencia.inDays} días';
          } else {
            return 'Hace ${(diferencia.inDays / 7).floor()} semanas';
          }
    // Try different field names that might be used
    return (valoracion['estrellas'] ??
           valoracion['calificacion'] ??
           valoracion['rating'] ??
           valoracion['stars'] ?? 0) as int;
  }

  // Helper method to format date for valoraciones
      final querySnapshot = await FirebaseFirestore.instance
    try {
      if (valoracion['fecha'] != null) {
        // If it's a timestamp
      }).toList();
    } catch (e) {
          final ahora = DateTime.now();
          final diferencia = ahora.difference(dateTime);
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Container(
    {
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
      'estrellas': 5,
                ),
                child: const Text(
                  'Próximamente',
    },
    {
      'cliente': 'Carlos G.',
      ),
    );
  }
}




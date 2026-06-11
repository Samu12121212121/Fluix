import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

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

                final data = snapshot.data ?? {};
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
    try {
      final hoy = DateTime.now();
      final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
      final finHoy = inicioHoy.add(const Duration(days: 1));
      final inicioSemana =
          inicioHoy.subtract(Duration(days: hoy.weekday - 1));

      final db = FirebaseFirestore.instance;
      final base = db.collection('empresas').doc(empresaId);

      // Reservas de hoy (colección reservas + citas)
      final reservasSnap = await base
          .collection('reservas')
          .where('fecha_hora',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
          .where('fecha_hora', isLessThan: Timestamp.fromDate(finHoy))
          .count()
          .get();
      final citasSnap = await base
          .collection('citas')
          .where('fecha_hora',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicioHoy))
          .where('fecha_hora', isLessThan: Timestamp.fromDate(finHoy))
          .count()
          .get();
      final reservasHoy =
          (reservasSnap.count ?? 0) + (citasSnap.count ?? 0);

      // Ingresos de la semana (facturas pagadas)
      final facturasSnap = await base
          .collection('facturas')
          .where('fecha_emision',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicioSemana))
          .where('estado', isEqualTo: 'pagada')
          .get();
      final ingresosSemana = facturasSnap.docs.fold<double>(
        0,
        (sum, d) => sum + ((d.data()['total'] as num?)?.toDouble() ?? 0),
      );

      // Rating promedio (últimas 50 valoraciones)
      final valoracionesSnap = await base
          .collection('valoraciones')
          .orderBy('fecha', descending: true)
          .limit(50)
          .get();
      double totalRating = 0;
      int countRating = 0;
      for (final doc in valoracionesSnap.docs) {
        final r = (doc.data()['rating'] as num?)?.toDouble();
        if (r != null) {
          totalRating += r;
          countRating++;
        }
      }
      final ratingPromedio =
          countRating > 0 ? totalRating / countRating : 0.0;

      return {
        'reservas_hoy': reservasHoy,
        'ingresos_semana': ingresosSemana.round(),
        'rating_promedio': ratingPromedio,
      };
    } catch (_) {
      return {
        'reservas_hoy': 0,
        'ingresos_semana': 0,
        'rating_promedio': 0.0,
      };
    }
  }
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
                    .where('fecha_hora',
                    isGreaterThanOrEqualTo:
                    Timestamp.fromDate(inicioHoy))
                    .where('fecha_hora',
                    isLessThan: Timestamp.fromDate(finHoy))
                    .where('estado', isEqualTo: 'CONFIRMADA') // Solo mostrar aceptadas
                    .orderBy('fecha_hora')
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
                      (data['fecha_hora'] as Timestamp?)?.toDate();
                      final hora = fecha != null
                          ? '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}'
                          : '--:--';
                      final cliente =
                          data['cliente'] as String? ?? data['nombre_cliente'] as String? ?? 'Cliente';
                      final servicio = data['servicio'] as String?;
                      
                      // Convertir comensales a int de forma segura
                      final comensalesRaw = data['numero_personas'];
                      int? comensales;
                      if (comensalesRaw != null) {
                        if (comensalesRaw is num) {
                          comensales = comensalesRaw.toInt();
                        } else if (comensalesRaw is String) {
                          comensales = int.tryParse(comensalesRaw);
                        }
                      }
                      
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
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(cliente,
                                            style: const TextStyle(
                                                fontSize: 13),
                                            overflow: TextOverflow.ellipsis),
                                      ),
                                      if (comensales != null && comensales > 0) ...[
                                        const SizedBox(width: 4),
                                        Icon(Icons.people, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 2),
                                        Text('$comensales',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ],
                                  ),
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

// ── Widget de Ingresos del Mes ────────────────────────────────────────────────

class WidgetIngresosMes extends StatefulWidget {
  final String empresaId;
  const WidgetIngresosMes({super.key, required this.empresaId});

  @override
  State<WidgetIngresosMes> createState() => _WidgetIngresosMesState();
}

class _WidgetIngresosMesState extends State<WidgetIngresosMes> {
  Map<String, dynamic>? _datos;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final d = await _obtenerDatos();
    if (mounted) setState(() { _datos = d; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _cargando
            ? const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()))
            : _buildContenido(),
      ),
    );
  }

  Widget _buildContenido() {
    final datos = _datos ?? {};
    final totalMes = (datos['total_mes'] as num?)?.toDouble() ?? 0.0;
    final totalAnterior = (datos['total_mes_anterior'] as num?)?.toDouble() ?? 0.0;
    final numFacturas = (datos['num_facturas'] as int?) ?? 0;
    final ingresosDia = (datos['ingresos_por_dia'] as Map<int, double>?) ?? {};

    double variacion = totalAnterior > 0
        ? ((totalMes - totalAnterior) / totalAnterior) * 100
        : 0;
    final subida = variacion >= 0;

    final hoy = DateTime.now();
    final diasHastaHoy = hoy.day;

    final barGroups = List.generate(diasHastaHoy, (i) {
      final dia = i + 1;
      final valor = ingresosDia[dia] ?? 0.0;
      return BarChartGroupData(
        x: dia,
        barRods: [
          BarChartRodData(
            toY: valor,
            gradient: const LinearGradient(
              colors: [Color(0xFF81C784), Color(0xFF2E7D32)],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            width: diasHastaHoy <= 15 ? 12.0 : 7.0,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
        ],
      );
    });

    final maxY = ingresosDia.isEmpty
        ? 100.0
        : ingresosDia.values.reduce((a, b) => a > b ? a : b) * 1.3;

    return LayoutBuilder(builder: (_, constraints) {
    // Altura disponible para el gráfico: total - cabecera fija (~80px)
    final chartH = (constraints.maxHeight - 80).clamp(40.0, 110.0);
    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up, color: Color(0xFF4CAF50), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Ingresos del Mes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
            if (totalAnterior > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (subida ? Colors.green : Colors.red)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      subida ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 11,
                      color: subida ? Colors.green : Colors.red,
                    ),
                    Text(
                      '${variacion.abs().toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: subida ? Colors.green : Colors.red),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${totalMes.toStringAsFixed(0)} €',
          style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32)),
        ),
        Text(
          '$numFacturas factura${numFacturas == 1 ? "" : "s"} este mes'
          '${totalAnterior > 0 ? " · mes ant. ${totalAnterior.toStringAsFixed(0)} €" : ""}',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: chartH,
          child: ingresosDia.isEmpty
              ? Center(
                  child: Text(
                    'Sin facturación este mes',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                )
              : BarChart(
                  BarChartData(
                    barGroups: barGroups,
                    maxY: maxY.clamp(1.0, double.infinity),
                    minY: 0,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 16,
                          getTitlesWidget: (value, _) {
                            final dia = value.toInt();
                            if (dia != 1 && dia % 5 != 0) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              '$dia',
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey[400]),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) =>
                            Colors.black.withValues(alpha: 0.75),
                        getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                          'Día ${group.x}\n${rod.toY.toStringAsFixed(0)} €',
                          const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    ));
    }); // LayoutBuilder
  }

  Future<Map<String, dynamic>> _obtenerDatos() async {
    try {
      final ahora = DateTime.now();
      final inicioMes = DateTime(ahora.year, ahora.month, 1);
      final inicioMesAnterior = DateTime(ahora.year, ahora.month - 1, 1);

      final base = FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId);

      final facturasMes = await base
          .collection('facturas')
          .where('fecha_emision',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMes))
          .where('estado', isEqualTo: 'pagada')
          .get();

      final Map<int, double> ingresosDia = {};
      double totalMes = 0;
      for (final doc in facturasMes.docs) {
        final d = doc.data();
        final fecha = (d['fecha_emision'] as Timestamp?)?.toDate();
        final total = (d['total'] as num?)?.toDouble() ?? 0;
        if (fecha != null) {
          ingresosDia[fecha.day] = (ingresosDia[fecha.day] ?? 0) + total;
        }
        totalMes += total;
      }

      final facturasMesAnterior = await base
          .collection('facturas')
          .where('fecha_emision',
              isGreaterThanOrEqualTo: Timestamp.fromDate(inicioMesAnterior))
          .where('fecha_emision',
              isLessThan: Timestamp.fromDate(inicioMes))
          .where('estado', isEqualTo: 'pagada')
          .get();
      final totalAnterior = facturasMesAnterior.docs.fold<double>(
          0,
          (sum, d) =>
              sum + ((d.data()['total'] as num?)?.toDouble() ?? 0));

      return {
        'total_mes': totalMes,
        'total_mes_anterior': totalAnterior,
        'num_facturas': facturasMes.docs.length,
        'ingresos_por_dia': ingresosDia,
      };
    } catch (_) {
      return {
        'total_mes': 0.0,
        'total_mes_anterior': 0.0,
        'num_facturas': 0,
        'ingresos_por_dia': <int, double>{},
      };
    }
  }
}

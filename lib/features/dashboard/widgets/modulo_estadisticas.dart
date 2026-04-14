}
  Widget _infoItemWeb(IconData icono, String label, String valor, Color color) {
    return Row(children: [
      Icon(icono, size: 16, color: color),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Text(valor, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ]),
    ]);
      SizedBox(width: 44, child: Text('${pct.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))),
      SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12))),
  Widget _barraDispositivo(IconData icono, String label, int count, double pct, Color color) {
  Widget _kpiVisita(String label, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ]),
      ),
    );
              // ── Páginas más vistas ────────────────────────────────────────
              if (m.paginasMasVistas.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Páginas más visitadas', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 12),
                      ...(() {
                        final sorted = m.paginasMasVistas.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));
                        final max = sorted.first.value;
                        return sorted.take(5).map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            const Icon(Icons.web, size: 14, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(e.key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              LinearProgressIndicator(
                                value: e.value / max,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation(Color(0xFF1976D2)),
                                minHeight: 5,
                              ),
                            ])),
                            const SizedBox(width: 8),
                            Text('${e.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ]),
                        ));
                      })(),
                    ]),
                  ),
                ),
              ],

              // ── Ubicaciones geográficas ────────────────────────────────────
              if (m.ubicaciones.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.location_on, size: 18, color: Color(0xFF1976D2)),
                        const SizedBox(width: 8),
                        const Text('Ubicación de visitantes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ]),
                      const SizedBox(height: 12),
                      ...(() {
                        final sorted = m.ubicaciones.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));
                        final total = sorted.fold(0, (s, e) => s + e.value);
                        return sorted.take(6).map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            const Icon(Icons.place_outlined, size: 13, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
                            Text('${e.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            Text(
                              '${(e.value / total * 100).toStringAsFixed(1)}%',
                              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                            ),
                          ]),
                        ));
                      })(),
                    ]),
                  ),
                ),
              ],
            ],
          ],
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
      },
              children: [
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 32),
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Calculando estadísticas reales...'),
                      SizedBox(height: 8),
                      Text('Esto solo ocurre la primera vez',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      SizedBox(height: 32),
                    ],
                  ),
                ),
                _SeccionTraficoWeb(empresaId: widget.empresaId),
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Dispositivos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 12),
                      _barraDispositivo(
                        Icons.smartphone, 'Móvil',
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildEstadoSinDatos(),
                const SizedBox(height: 20),
                _SeccionTraficoWeb(empresaId: widget.empresaId),
              ],
            ),
          );
                      ),
                      const SizedBox(height: 8),
                      _barraDispositivo(
                        Icons.computer, 'Desktop',
                        m.visitasDesktop, m.pctDesktop, const Color(0xFF7B1FA2),
                      ),
                      const SizedBox(height: 8),
                      _barraDispositivo(
                        Icons.tablet_mac, 'Tablet',
                        m.visitasTablet, m.pctTablet, const Color(0xFF2E7D32),
                      ),
                    ]),
                  ),
                ),
              // ── Gráfica tendencia 30 días ─────────────────────────────────
              FutureBuilder<List<Map<String, dynamic>>>(
                future: AnalyticsWebService().obtenerHistorialDiario(empresaId),
                builder: (ctx, hSnap) {
                  if (!hSnap.hasData || hSnap.data!.isEmpty) return const SizedBox.shrink();
                  final hist = hSnap.data!.reversed.toList(); // cronológico
                  final maxV = hist.map((h) => (h['visitas'] as num?)?.toDouble() ?? 0).fold(0.0, (a, b) => a > b ? a : b);
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Visitas — últimos 30 días',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: BarChart(
                            BarChartData(
                              maxY: maxV <= 0 ? 10 : maxV * 1.2,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => const FlLine(
                                  color: Color(0xFFE0E0E0), strokeWidth: 0.8,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, _) {
                                      final i = v.toInt();
                                      if (i % 5 != 0 || i >= hist.length) return const SizedBox.shrink();
                                      final fecha = hist[i]['fecha']?.toString() ?? '';
                                      final parts = fecha.split('-');
                                      if (parts.length < 3) return const SizedBox.shrink();
                                      return Text('${parts[2]}/${parts[1]}',
                                          style: const TextStyle(fontSize: 8, color: Colors.grey));
                                    },
                                    reservedSize: 20,
                                  ),
                                ),
                              ),
                              barGroups: hist.asMap().entries.map((e) {
                                final v = (e.value['visitas'] as num?)?.toDouble() ?? 0;
                                return BarChartGroupData(
                                  x: e.key,
                                  barRods: [BarChartRodData(
                                    toY: v,
                                    width: 5,
                                    color: const Color(0xFF1976D2),
                                    borderRadius: BorderRadius.circular(2),
                                  )],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera sección ───────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.language, color: Color(0xFF1565C0), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tráfico Web', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('fluixtech.com', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
              if (m.ultimaActualizacion != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.circle, size: 6, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 4),
                    const Text('En vivo', style: TextStyle(fontSize: 10, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
            const SizedBox(height: 12),

            if (!m.tieneDatos) ...[
              // ── Sin datos: instrucciones ──────────────────────────────────
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Icon(Icons.code, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    const Text(
                      'Esperando datos del script web',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'El script JavaScript del footer de fluixtech.com '
                      'enviará los datos automáticamente. Cada visita se registra en tiempo real.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
              ),
            ] else ...[
              // ── Visitantes ────────────────────────────────────────────────
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Visitantes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _kpiVisita('Hoy', '${m.visitasHoy}', Icons.today, const Color(0xFF1976D2)),
                      const SizedBox(width: 8),
                      _kpiVisita('Semana', '${m.visitasSemana}', Icons.date_range, const Color(0xFF7B1FA2)),
                      const SizedBox(width: 8),
                      _kpiVisita('Mes', '${m.visitasMes}', Icons.calendar_month, const Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      _kpiVisita('Total', '${m.visitasTotal}', Icons.all_inclusive, const Color(0xFFF57C00)),
                    ]),
                    if (m.duracionMediaSegundos > 0 || m.tasaRebote > 0) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _infoItemWeb(
                          Icons.timer_outlined, 'Duración media',
                          m.duracionFormateada, const Color(0xFF0288D1),
                        )),
                        Expanded(child: Builder(
                          builder: (ctx) => GestureDetector(
                            onTap: () => showDialog(
                              context: ctx,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Row(children: [
                                  Icon(Icons.exit_to_app, color: Color(0xFF1976D2), size: 20),
                                  SizedBox(width: 8),
                                  Text('Tasa de Rebote', style: TextStyle(fontSize: 16)),
                                ]),
                                content: const Text(
                                  '🔴 ¿Qué es la Tasa de Rebote?\n\n'
                                  'Es el porcentaje de visitas en las que el usuario entra a tu web '
                                  'y se va sin hacer nada más (sin navegar a otra página, sin hacer clic, sin rellenar formularios).\n\n'
                                  '📊 Cómo se interpreta:\n'
                                  '• < 40% → Excelente: los usuarios se quedan y exploran\n'
                                  '• 40–60% → Normal para webs de servicios\n'
                                  '• > 60% → Alta: puede indicar que el contenido no engancha o la web carga lenta\n\n'
                                  '💡 Origen: registrada por el script JS en el footer de tu web cuando un usuario visita una sola página y abandona.',
                                  style: TextStyle(fontSize: 13, height: 1.6),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('Entendido'),
                                  ),
                                ],
                              ),
                            ),
                            child: Row(children: [
                              _infoItemWeb(
                                Icons.exit_to_app, 'Tasa de rebote',
                                '${m.tasaRebote.toStringAsFixed(1)}%',
                                m.tasaRebote > 60 ? const Color(0xFFF44336) : const Color(0xFF4CAF50),
                              ),
                              const Icon(Icons.info_outline, size: 13, color: Colors.grey),
                            ]),
                          ),
                        )),
                      ]),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 12),
      stream: AnalyticsWebService().streamMetricas(empresaId),
class _SeccionTraficoWeb extends StatelessWidget {
// Sección de Tráfico Web — lee métricas guardadas por el script JS del footer
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.analytics, size: 64, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text(
              'Calculando estadísticas',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Por favor espera mientras procesamos los datos de tu negocio',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
          return _buildEstadoSinDatos();
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Calculando estadísticas reales...'),
                SizedBox(height: 8),
                Text('Esto solo ocurre la primera vez',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/estadisticas_cache_service.dart';
import '../../../services/analytics_web_service.dart';

class ModuloEstadisticas extends StatefulWidget {
  final String empresaId;
  const ModuloEstadisticas({super.key, required this.empresaId});

  @override
  State<ModuloEstadisticas> createState() => _ModuloEstadisticasState();
}

class _ModuloEstadisticasState extends State<ModuloEstadisticas> {
  final EstadisticasCacheService _cacheService = EstadisticasCacheService();
  bool _calculandoCache = false;
  bool _tieneFacturacion = false;

  @override
  void initState() {
    super.initState();
    _iniciarCacheAutomatico();
    _verificarFacturacion();
  }

  /// Comprueba si la empresa tiene el módulo de facturación (finanzas) activo
  Future<void> _verificarFacturacion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .get();
      if (!mounted) return;
      final data = doc.data();
      if (data == null) return;
      final config = data['configuracion'] as Map<String, dynamic>? ?? {};
      final modulos = config['modulos'] as Map<String, dynamic>? ?? {};
      setState(() => _tieneFacturacion = modulos['finanzas'] == true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _cacheService.detenerCacheAutomatico(widget.empresaId);
    super.dispose();
  }

  /// Iniciar sistema de cache automático
  void _iniciarCacheAutomatico() {
    _cacheService.iniciarCacheAutomatico(widget.empresaId);
  }

  /// Obtener estadísticas desde cache como Stream
  Stream<Map<String, dynamic>> _obtenerEstadisticasDesdeCache() {
    return FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('cache')
        .doc('estadisticas')
        .snapshots()
        .asyncMap((doc) async {
      if (doc.exists) {
        final data = doc.data()!;
        // Verificar si el cache es reciente (menos de 1 hora)
        final fechaCalculo = data['fecha_calculo'] as String?;
        if (fechaCalculo != null) {
          final ultimaAct = DateTime.parse(fechaCalculo);
          final diferencia = DateTime.now().difference(ultimaAct);
          if (diferencia.inHours < 1) {
            print('✅ Usando estadísticas desde cache (${diferencia.inMinutes} min)');
            return data;
          }
        }
        // Cache obsoleto — recalcular en background y devolver lo que hay
        print('⚠️ Cache obsoleto, recalculando en background...');
        _cacheService.recalcularEstadisticas(widget.empresaId);
        return data; // Devuelve datos aunque obsoletos mientras recalcula
      }

      // No hay cache — lanzar cálculo y devolver vacío (el stream emitirá de nuevo cuando acabe)
      print('📊 Sin cache, calculando estadísticas reales por primera vez...');
      _cacheService.recalcularEstadisticas(widget.empresaId);
      return <String, dynamic>{};
    });
  }

  Future<void> _recalcularManual() async {
    if (_calculandoCache) return;
    setState(() => _calculandoCache = true);
    await _cacheService.recalcularEstadisticas(widget.empresaId);
    if (mounted) {
      setState(() => _calculandoCache = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Estadísticas actualizadas'),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _obtenerEstadisticasDesdeCache(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            (snapshot.hasData && snapshot.data!.isEmpty)) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Calculando estadísticas reales...'),
                SizedBox(height: 8),
                Text('Esto solo ocurre la primera vez',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEstadoSinDatos();
        }

        final data = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () => _cacheService.recalcularEstadisticas(widget.empresaId),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderConControles(false),
                const SizedBox(height: 16),
                _buildIndicadorCache(data),
                const SizedBox(height: 16),
                _buildKpisPrincipales(context, data),
                const SizedBox(height: 20),
                _buildGraficoRendimiento(context, data),
                const SizedBox(height: 20),
                _buildGridMetricasNegocio(context, data),
                const SizedBox(height: 20),
                _buildEstadisticasServicios(context, data),
                const SizedBox(height: 20),
                _buildEstadisticasEmpleados(context, data),
                const SizedBox(height: 20),
                _buildValoracionesFeedback(context, data),
                const SizedBox(height: 20),
                _SeccionTraficoWeb(empresaId: widget.empresaId),
                const SizedBox(height: 20),
                _buildInfoAdicionalCompleta(context, data),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildHeaderConControles([bool modoOffline = false]) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: Color(0xFF1976D2),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard de Estadísticas',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      Text(
                        'Métricas completas de tu negocio',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (_calculandoCache)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _recalcularManual,
                    tooltip: 'Actualizar estadísticas',
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (modoOffline ? Colors.orange : const Color(0xFF21759B)).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    modoOffline ? Icons.offline_bolt : Icons.wordpress,
                    color: modoOffline ? Colors.orange : const Color(0xFF21759B),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  modoOffline ? 'Modo Demo (Sin Conexión)' : 'WordPress + Google Reviews',
                  style: TextStyle(fontSize: 11, color: modoOffline ? Colors.orange : Colors.grey),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (modoOffline ? Colors.orange : const Color(0xFF4CAF50)).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        modoOffline ? Icons.offline_bolt : Icons.sync,
                        color: modoOffline ? Colors.orange : const Color(0xFF4CAF50),
                        size: 12
                      ),
                      const SizedBox(width: 4),
                      Text(
                        modoOffline ? 'Demo' : 'Sincronizado',
                        style: TextStyle(
                          color: modoOffline ? Colors.orange : const Color(0xFF4CAF50),
                          fontSize: 10,
                          fontWeight: FontWeight.w600
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpisPrincipales(BuildContext context, Map<String, dynamic> data) {
    final ingresosMes = (data['ingresos_facturas_mes'] as num?)?.toDouble() ?? 0;
    final gastosMes = (data['gastos_pagados_mes'] as num?)?.toDouble() ?? 0;
    final beneficioNeto = (data['beneficio_neto_mes'] as num?)?.toDouble() ?? (ingresosMes - gastosMes);
    final esPositivo = beneficioNeto >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('KPIs Principales', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(width: 6),
            _infoBtn(
              context,
              'KPIs Principales',
              'Los KPIs (Indicadores Clave de Rendimiento) resumen el estado de tu negocio en tiempo real. '
              'Se calculan automáticamente cada 5 minutos a partir de los datos reales de tu cuenta.',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // ── Beneficio Neto: solo si tiene facturación contratada ───────
            if (_tieneFacturacion)
              Expanded(child: _kpiCardGrandeConInfo(
                context,
                'Beneficio Neto',
                '${esPositivo ? "" : "-"}€${beneficioNeto.abs().toStringAsFixed(0)}',
                esPositivo ? Icons.trending_up : Icons.trending_down,
                esPositivo ? const Color(0xFF2E7D32) : const Color(0xFFF44336),
                0.0,
                'Ingresos: €${ingresosMes.toStringAsFixed(0)} | Gastos: €${gastosMes.toStringAsFixed(0)}',
                '📊 Beneficio Neto = Ingresos por facturación PAGADA del mes − Gastos PAGADOS del mes.\n\n'
                '• Ingresos: €${ingresosMes.toStringAsFixed(2)} (facturas con estado PAGADA, colección: facturas)\n'
                '• Gastos: €${gastosMes.toStringAsFixed(2)} (gastos con estado pagado, colección: gastos)\n\n'
                'Si el resultado es positivo (verde), estás ganando dinero. '
                'Si es negativo (rojo), los gastos superan a los ingresos.',
              ))
            else
              Expanded(child: _kpiFacturacionBloqueada(context)),
            const SizedBox(width: 12),
            Expanded(child: _kpiCardGrandeConInfo(
              context,
              'Reservas Confirmadas',
              '${data['reservas_confirmadas'] ?? 0}',
              Icons.event_available,
              const Color(0xFF1976D2),
              _calcPct(data['reservas_mes'], data['reservas_mes_anterior']),
              'Total: ${data['reservas_mes'] ?? 0}',
              '📊 Origen: número de reservas con estado CONFIRMADA del mes actual '
              '(colección: reservas). El total incluye todos los estados.',
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _kpiCardGrandeConInfo(
              context,
              'Nuevos Clientes',
              '${data['nuevos_clientes_mes'] ?? 0}',
              Icons.person_add,
              const Color(0xFF7B1FA2),
              _calcPct(data['nuevos_clientes_mes'], data['nuevos_clientes_mes_anterior']),
              'Total: ${data['total_clientes'] ?? 0}',
              '📊 Origen: clientes cuya fecha_registro está dentro del mes actual '
              '(colección: clientes). El total muestra todos los clientes históricos.',
            )),
            const SizedBox(width: 12),
            Expanded(child: _kpiCardGrandeConInfo(
              context,
              'Valoración Media',
              '${(data['valoracion_promedio'] ?? 0.0).toStringAsFixed(1)} ⭐',
              Icons.star,
              const Color(0xFFF57C00),
              0.0,
              '${data['total_valoraciones'] ?? 0} reseñas',
              '📊 Origen: promedio de todas las valoraciones guardadas '
              '(colección: valoraciones). Incluye reseñas de Google y manuales.',
            )),
          ],
        ),
      ],
    );
  }

  /// KPI bloqueado cuando no se tiene el módulo de facturación contratado
  Widget _kpiFacturacionBloqueada(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.grey.withValues(alpha: 0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: Colors.grey[400], size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, color: Colors.orange, size: 12),
                      SizedBox(width: 4),
                      Text('No contratado', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('—', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey[400])),
            const SizedBox(height: 4),
            const Text('Ingresos del Mes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              'Activa el módulo Finanzas para ver los ingresos por facturación',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  /// KPI card con botón de info integrado
  Widget _kpiCardGrandeConInfo(
    BuildContext context,
    String titulo,
    String valor,
    IconData icono,
    Color color,
    double pct,
    String subtitulo,
    String infoTexto,
  ) {
    final esPositivo = pct >= 0;
    final colorPct = esPositivo ? const Color(0xFF4CAF50) : const Color(0xFFF44336);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: color, size: 24),
                const Spacer(),
                if (pct != 0.0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorPct.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(esPositivo ? Icons.trending_up : Icons.trending_down, color: colorPct, size: 12),
                        const SizedBox(width: 2),
                        Text('${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(1)}%',
                            style: TextStyle(color: colorPct, fontSize: 10, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _mostrarInfoDialog(context, titulo, infoTexto),
                  child: const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(valor, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  /// Botón de información reutilizable
  Widget _infoBtn(BuildContext context, String titulo, String texto) {
    return GestureDetector(
      onTap: () => _mostrarInfoDialog(context, titulo, texto),
      child: const Icon(Icons.info_outline, size: 16, color: Colors.grey),
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.analytics, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'Calculando estadísticas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            'Por favor espera mientras procesamos los datos de tu negocio',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Rendimiento del Negocio', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(width: 6),
                _infoBtn(context, 'Rendimiento',
                  'Métricas calculadas a partir de tus reservas confirmadas, canceladas y completadas.'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _metricaCardConInfo(
                  context,
                  'Tasa Conversión',
                  '${(data['tasa_conversion'] ?? 0).toStringAsFixed(1)}%',
                  Icons.trending_up,
                  const Color(0xFF4CAF50),
                  '✅ Reservas completadas ÷ Reservas totales × 100.\n\n'
                  'Indica qué porcentaje de las reservas acaban en servicio real. '
                  'Un valor alto (>70%) es positivo.',
                )),
                const SizedBox(width: 12),
                Expanded(child: _metricaCardConInfo(
                  context,
                  'Tasa Cancelación',
                  '${(data['tasa_cancelacion'] ?? 0).toStringAsFixed(1)}%',
                  Icons.cancel,
                  const Color(0xFFF44336),
                  '❌ Reservas canceladas ÷ Reservas totales × 100.\n\n'
                  'Indica el porcentaje de reservas que se cancelan antes de completarse. '
                  'Un valor bajo (<15%) es deseable.',
                )),
                const SizedBox(width: 12),
                Expanded(child: _metricaCardConInfo(
                  context,
                  'Ticket Medio',
                  '€${(data['valor_medio_reserva'] ?? 0).toStringAsFixed(0)}',
                  Icons.euro,
                  const Color(0xFF1976D2),
                  '💶 Ingresos totales del mes ÷ Número de transacciones.\n\n'
                  'Valor promedio que ingresa por cada operación. '
                  'Calculado desde la colección: transacciones.',
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridMetricasNegocio(BuildContext context, Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Métricas de Negocio', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _metricaCompactaCard(
              'Reservas Completadas',
              '${data['reservas_completadas'] ?? 0}',
              Icons.check_circle,
              const Color(0xFF4CAF50),
            )),
            const SizedBox(width: 8),
            Expanded(child: _metricaCompactaCard(
              'Reservas Pendientes',
              '${data['reservas_pendientes'] ?? 0}',
              Icons.pending,
              const Color(0xFFF57C00),
            )),
            const SizedBox(width: 8),
            Expanded(child: _metricaCompactaCard(
              'Clientes Activos',
              '${data['clientes_activos'] ?? 0}',
              Icons.people,
              const Color(0xFF1976D2),
            )),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _metricaCompactaCard(
              'Servicios Activos',
              '${data['total_servicios_activos'] ?? 0}',
              Icons.design_services,
              const Color(0xFF7B1FA2),
            )),
            const SizedBox(width: 8),
            Expanded(child: _metricaCompactaCard(
              'Empleados Activos',
              '${data['total_empleados_activos'] ?? 0}',
              Icons.badge,
              const Color(0xFF388E3C),
            )),
            const SizedBox(width: 8),
            Expanded(child: _metricaCompactaCard(
              'Transacciones',
              '${data['total_transacciones_mes'] ?? 0}',
              Icons.payment,
              const Color(0xFFF44336),
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildEstadisticasServicios(BuildContext context, Map<String, dynamic> data) {
    final reservasPorServicio = data['reservas_por_servicio'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.design_services, color: Color(0xFF7B1FA2), size: 20),
                const SizedBox(width: 8),
                const Text('Servicios Más Populares', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                Text('Total: ${data['total_servicios_activos'] ?? 0}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow(Icons.star, 'Más Popular', data['servicio_mas_popular'] ?? 'N/A'),
            _infoRow(Icons.attach_money, 'Más Rentable', data['servicio_mas_rentable'] ?? 'N/A'),
            const SizedBox(height: 12),
            if (reservasPorServicio.isNotEmpty) ...[
              const Text('Reservas por Servicio:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 8),
              ...reservasPorServicio.entries.take(4).map((entry) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFF7B1FA2),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12))),
                      Text('${entry.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticasEmpleados(BuildContext context, Map<String, dynamic> data) {
    final rendimientoEmpleados = data['rendimiento_empleados'] as Map<String, dynamic>? ?? {};

// Sección de Tráfico Web — lee métricas + dominio real de config
      elevation: 1,
class _SeccionTraficoWeb extends StatefulWidget {
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
  @override
  State<_SeccionTraficoWeb> createState() => _SeccionTraficoWebState();
}

class _SeccionTraficoWebState extends State<_SeccionTraficoWeb> {
  String _dominio = '';

  @override
  void initState() {
    super.initState();
    _cargarDominio();
  }

  Future<void> _cargarDominio() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('configuracion').doc('web_avanzada').get();
      if (!mounted) return;
      final raw = doc.data()?['dominio_propio_url'] as String? ?? '';
      if (raw.isNotEmpty) {
        setState(() => _dominio = raw
            .replaceAll('https://', '').replaceAll('http://', '')
            .replaceAll('www.', '').split('/').first);
      }
    } catch (_) {}
  }

          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
      stream: AnalyticsWebService().streamMetricas(widget.empresaId),
                const Icon(Icons.badge, color: Color(0xFF388E3C), size: 20),
        // ── Cabecera siempre visible ──────────────────────────────────
        final header = Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.language, color: Color(0xFF1565C0), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tráfico Web',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text(
              _dominio.isEmpty ? 'Configura el dominio en Web > Config' : _dominio,
              style: TextStyle(fontSize: 11,
                  color: _dominio.isEmpty ? Colors.orange : Colors.grey),
            ),
          ])),
          if (snap.hasData && snap.data!.tieneDatos)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 6, color: Color(0xFF4CAF50)),
                SizedBox(width: 4),
                Text('En vivo', style: TextStyle(fontSize: 10,
                    color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
              ]),
            ),
        ]);

        // ── Estado: cargando ──────────────────────────────────────────
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        // ── Estado: error de red / permisos ───────────────────────────
        if (snap.hasError) {
          return _buildSinDatos('Sin conexión con Firebase.\nRevisa la red.');
        }

                const SizedBox(width: 8),
                const Text('Rendimiento del Equipo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        // ── Sin datos todavía: el script aún no ha registrado visitas ─
        if (!m.tieneDatos) {
          return _buildSinDatos(
            'Aún no hay visitas registradas.\n'
            'Asegúrate de que el script de Fluix está activo en ${ _dominio.isEmpty ? "tu web" : _dominio }.',
          );
        }

        return _buildContenido(m, esDemo: false);
      },
    );
  }

  Widget _buildContenido(MetricasTraficoWeb m,
      {required bool esDemo, String mensajeDemo = ''}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Cabecera
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.language, color: Color(0xFF1565C0), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tráfico Web',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text(
            _dominio.isEmpty ? 'Configura el dominio en Web > Config' : _dominio,
            style: TextStyle(fontSize: 11,
                color: _dominio.isEmpty ? Colors.orange : Colors.grey),
          ),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: esDemo
                ? Colors.orange.withValues(alpha: 0.12)
                : const Color(0xFF4CAF50).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, size: 6,
                color: esDemo ? Colors.orange : const Color(0xFF4CAF50)),
            const SizedBox(width: 4),
            Text(
              esDemo ? 'Vista previa' : 'En vivo',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                  color: esDemo ? Colors.orange : const Color(0xFF4CAF50)),
            ),
          ]),
        ),
      ]),

      // Banner demo
      if (esDemo) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.orange, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(
              mensajeDemo.isEmpty ? 'Vista previa con datos de ejemplo' : mensajeDemo,
              style: const TextStyle(fontSize: 11, color: Colors.orange),
            )),
          ]),
        ),
      ],
      const SizedBox(height: 12),

      // 1. KPIs visitantes
      _cardSec('Visitantes', Icons.people_outline, const Color(0xFF1976D2),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _kpi('Hoy', m.visitasHoy, Icons.today, const Color(0xFF1976D2)),
            const SizedBox(width: 8),
            _kpi('Semana', m.visitasSemana, Icons.date_range, const Color(0xFF7B1FA2)),
            const SizedBox(width: 8),
            _kpi('Mes', m.visitasMes, Icons.calendar_month, const Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            _kpi('Total', m.visitasTotal, Icons.all_inclusive, const Color(0xFFF57C00)),
          ]),
        ]),
      ),
      const SizedBox(height: 8),
                children: [
      // 2. Gráfica 30 días
      FutureBuilder<List<Map<String, dynamic>>>(
        future: AnalyticsWebService().obtenerHistorialDiario(widget.empresaId),
        builder: (ctx, hSnap) {
          if (!hSnap.hasData || hSnap.data!.isEmpty) return const SizedBox.shrink();
          final hist = hSnap.data!.reversed.toList();
          final maxV = hist.map((h) => (h['visitas'] as num?)?.toDouble() ?? 0)
              .fold(0.0, (a, b) => a > b ? a : b);
          return Column(children: [
            _cardSec('Últimos 30 días', Icons.bar_chart, const Color(0xFF1565C0),
              SizedBox(
                height: 110,
                child: BarChart(BarChartData(
                  maxY: maxV <= 0 ? 5 : maxV * 1.3,
                  gridData: FlGridData(show: true, drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          const FlLine(color: Color(0xFFEEEEEE), strokeWidth: 0.8)),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(
                      showTitles: true, reservedSize: 18,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i % 7 != 0 || i >= hist.length) return const SizedBox.shrink();
                        final parts = (hist[i]['fecha']?.toString() ?? '').split('-');
                        if (parts.length < 3) return const SizedBox.shrink();
                        return Text('${parts[2]}/${parts[1]}',
                            style: const TextStyle(fontSize: 8, color: Colors.grey));
                      },
                    )),
                  ),
                  barGroups: hist.asMap().entries.map((e) {
                    final v = (e.value['visitas'] as num?)?.toDouble() ?? 0;
                    return BarChartGroupData(x: e.key, barRods: [
                      BarChartRodData(toY: v, width: 5,
                          color: const Color(0xFF1976D2),
                          borderRadius: BorderRadius.circular(2)),
                    ]);
                  }).toList(),
                )),
              ),
            ),
            const SizedBox(height: 8),
          ]);
        },
      ),
  Widget _buildIndicadorCache(Map<String, dynamic> data) {
      // 3. Dispositivos
      if (m.visitasMovil + m.visitasDesktop + m.visitasTablet > 0) ...[
        _cardSec('Dispositivos', Icons.devices, const Color(0xFF7B1FA2),
          Column(children: [
            _barra(Icons.smartphone, 'Móvil', m.visitasMovil, m.pctMovil,
                const Color(0xFF1976D2)),
            const SizedBox(height: 8),
            _barra(Icons.computer, 'Desktop', m.visitasDesktop, m.pctDesktop,
                const Color(0xFF7B1FA2)),
            const SizedBox(height: 8),
            _barra(Icons.tablet_mac, 'Tablet', m.visitasTablet, m.pctTablet,
                const Color(0xFF2E7D32)),
          ]),
        ),
        const SizedBox(height: 8),
      ],

      // 4. Origen del tráfico
      if (m.referrers.isNotEmpty) ...[
        _cardSec('Origen del tráfico', Icons.alt_route, const Color(0xFF00796B),
          _listaBarras(m.referrers, const Color(0xFF00796B), {
            'google': Icons.search, 'directo': Icons.home_outlined,
            'facebook': Icons.facebook, 'instagram': Icons.camera_alt_outlined,
            'twitter': Icons.tag, 'whatsapp': Icons.chat_outlined,
          }),
        ),
        const SizedBox(height: 8),
      ],
        borderRadius: BorderRadius.circular(20),
      // 5. Páginas más visitadas
      if (m.paginasMasVistas.isNotEmpty) ...[
        _cardSec('Páginas más visitadas', Icons.web_asset, const Color(0xFF0288D1),
          _listaBarras(m.paginasMasVistas, const Color(0xFF0288D1), {}),
        ),
        const SizedBox(height: 8),
      ],

      // 6. Acciones / eventos
      if (m.eventos.isNotEmpty) ...[
        _cardSec('Acciones de visitantes', Icons.touch_app, const Color(0xFFE65100),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: m.eventos.entries.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFE65100).withValues(alpha: 0.2)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(e.key.replaceAll('_', ' '),
                    style: const TextStyle(fontSize: 10, color: Colors.black54)),
                Text('${e.value}', style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100))),
              ]),
            )).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],

      if (!esDemo && m.ultimaActualizacion != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Última visita: ${_formatFecha(m.ultimaActualizacion!)}',
            style: TextStyle(fontSize: 10, color: Colors.grey[400]),
            textAlign: TextAlign.right,
          ),
        ),
    ]);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildSinDatos(String mensaje) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.language, color: Color(0xFF1565C0), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tráfico Web',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text(
            _dominio.isEmpty ? 'Configura el dominio en Web > Config' : _dominio,
            style: TextStyle(fontSize: 11,
                color: _dominio.isEmpty ? Colors.orange : Colors.grey),
          ),
        ])),
      ]),
      const SizedBox(height: 16),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(children: [
          Icon(Icons.bar_chart_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Las estadísticas aparecerán aquí automáticamente cuando haya visitas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ]),
      ),
    ]);
  }

  Widget _cardSec(String titulo, IconData icono, Color color, Widget cuerpo) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, color: color, size: 18),
          ),
          title: Text(titulo,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [cuerpo],
        ),
      ),
  Widget _rolEmpleadoChip(String rol, int cantidad, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  Widget _kpi(String label, int valor, IconData icono, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(height: 4),
        Text('$valor', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: color)),
      ]),
    ));
        Text('$cantidad', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
  Widget _barra(IconData icono, String label, int count, double pct, Color color) {
  }

  Widget _infoRow(IconData icono, String label, String valor) {
      SizedBox(width: 60, child: Text(label,
          style: const TextStyle(fontSize: 12))),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icono, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const Spacer(),
          Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
      SizedBox(width: 50, child: Text(
        '$count (${pct.toStringAsFixed(0)}%)',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        textAlign: TextAlign.right,
      )),

  double _calcPct(dynamic actual, dynamic anterior) {
    final a = (actual as num?)?.toDouble() ?? 0;
  Widget _listaBarras(Map<String, int> mapa, Color color,
      Map<String, IconData> iconos) {
    final sorted = mapa.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold(0, (s, e) => s + e.value);
    return Column(
      children: sorted.take(8).map((e) {
        final pct = total == 0 ? 0.0 : e.value / total;
        final icono = iconos[e.key.toLowerCase()] ?? Icons.link;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(icono, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: pct,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 5,
                ),
              ],
            )),
            const SizedBox(width: 8),
            Text('${e.value}', style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            Text('${(pct * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ]),
        );
      }).toList(),
    );
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
}
  String _formatFecha(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sección de Tráfico Web — lee métricas guardadas por el script JS del footer
// ─────────────────────────────────────────────────────────────────────────────
class _SeccionTraficoWeb extends StatelessWidget {
  final String empresaId;
  const _SeccionTraficoWeb({required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MetricasTraficoWeb>(
      stream: AnalyticsWebService().streamMetricas(empresaId),
      builder: (context, snap) {
        final m = snap.data ?? MetricasTraficoWeb.vacio();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cabecera sección ───────────────────────────────────────────
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.language, color: Color(0xFF1565C0), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tráfico Web', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('fluixtech.com', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ),
              if (m.ultimaActualizacion != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.circle, size: 6, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 4),
                    const Text('En vivo', style: TextStyle(fontSize: 10, color: Color(0xFF4CAF50), fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
            const SizedBox(height: 12),

            if (!m.tieneDatos) ...[
              // ── Sin datos: instrucciones ──────────────────────────────────
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Icon(Icons.code, size: 40, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    const Text(
                      'Esperando datos del script web',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'El script JavaScript del footer de fluixtech.com '
                      'enviará los datos automáticamente. Cada visita se registra en tiempo real.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
              ),
            ] else ...[
              // ── Visitantes ────────────────────────────────────────────────
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Visitantes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _kpiVisita('Hoy', '${m.visitasHoy}', Icons.today, const Color(0xFF1976D2)),
                      const SizedBox(width: 8),
                      _kpiVisita('Semana', '${m.visitasSemana}', Icons.date_range, const Color(0xFF7B1FA2)),
                      const SizedBox(width: 8),
                      _kpiVisita('Mes', '${m.visitasMes}', Icons.calendar_month, const Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      _kpiVisita('Total', '${m.visitasTotal}', Icons.all_inclusive, const Color(0xFFF57C00)),
                    ]),
                    if (m.duracionMediaSegundos > 0 || m.tasaRebote > 0) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _infoItemWeb(
                          Icons.timer_outlined, 'Duración media',
                          m.duracionFormateada, const Color(0xFF0288D1),
                        )),
                        Expanded(child: Builder(
                          builder: (ctx) => GestureDetector(
                            onTap: () => showDialog(
                              context: ctx,
                              builder: (_) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Row(children: [
                                  Icon(Icons.exit_to_app, color: Color(0xFF1976D2), size: 20),
                                  SizedBox(width: 8),
                                  Text('Tasa de Rebote', style: TextStyle(fontSize: 16)),
                                ]),
                                content: const Text(
                                  '🔴 ¿Qué es la Tasa de Rebote?\n\n'
                                  'Es el porcentaje de visitas en las que el usuario entra a tu web '
                                  'y se va sin hacer nada más (sin navegar a otra página, sin hacer clic, sin rellenar formularios).\n\n'
                                  '📊 Cómo se interpreta:\n'
                                  '• < 40% → Excelente: los usuarios se quedan y exploran\n'
                                  '• 40–60% → Normal para webs de servicios\n'
                                  '• > 60% → Alta: puede indicar que el contenido no engancha o la web carga lenta\n\n'
                                  '💡 Origen: registrada por el script JS en el footer de tu web cuando un usuario visita una sola página y abandona.',
                                  style: TextStyle(fontSize: 13, height: 1.6),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: const Text('Entendido'),
                                  ),
                                ],
                              ),
                            ),
                            child: Row(children: [
                              _infoItemWeb(
                                Icons.exit_to_app, 'Tasa de rebote',
                                '${m.tasaRebote.toStringAsFixed(1)}%',
                                m.tasaRebote > 60 ? const Color(0xFFF44336) : const Color(0xFF4CAF50),
                              ),
                              const Icon(Icons.info_outline, size: 13, color: Colors.grey),
                            ]),
                          ),
                        )),
                      ]),
                    ],
                  ]),
                ),
              ),
              const SizedBox(height: 12),

              // ── Gráfica tendencia 30 días ─────────────────────────────────
              FutureBuilder<List<Map<String, dynamic>>>(
                future: AnalyticsWebService().obtenerHistorialDiario(empresaId),
                builder: (ctx, hSnap) {
                  if (!hSnap.hasData || hSnap.data!.isEmpty) return const SizedBox.shrink();
                  final hist = hSnap.data!.reversed.toList(); // cronológico
                  final maxV = hist.map((h) => (h['visitas'] as num?)?.toDouble() ?? 0).fold(0.0, (a, b) => a > b ? a : b);
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Visitas — últimos 30 días',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: BarChart(
                            BarChartData(
                              maxY: maxV <= 0 ? 10 : maxV * 1.2,
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => const FlLine(
                                  color: Color(0xFFE0E0E0), strokeWidth: 0.8,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (v, _) {
                                      final i = v.toInt();
                                      if (i % 5 != 0 || i >= hist.length) return const SizedBox.shrink();
                                      final fecha = hist[i]['fecha']?.toString() ?? '';
                                      final parts = fecha.split('-');
                                      if (parts.length < 3) return const SizedBox.shrink();
                                      return Text('${parts[2]}/${parts[1]}',
                                          style: const TextStyle(fontSize: 8, color: Colors.grey));
                                    },
                                    reservedSize: 20,
                                  ),
                                ),
                              ),
                              barGroups: hist.asMap().entries.map((e) {
                                final v = (e.value['visitas'] as num?)?.toDouble() ?? 0;
                                return BarChartGroupData(
                                  x: e.key,
                                  barRods: [BarChartRodData(
                                    toY: v,
                                    width: 5,
                                    color: const Color(0xFF1976D2),
                                    borderRadius: BorderRadius.circular(2),
                                  )],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // ── Dispositivos ──────────────────────────────────────────────
              if (m.visitasMovil + m.visitasDesktop + m.visitasTablet > 0)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Dispositivos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 12),
                      _barraDispositivo(
                        Icons.smartphone, 'Móvil',
                        m.visitasMovil, m.pctMovil, const Color(0xFF1976D2),
                      ),
                      const SizedBox(height: 8),
                      _barraDispositivo(
                        Icons.computer, 'Desktop',
                        m.visitasDesktop, m.pctDesktop, const Color(0xFF7B1FA2),
                      ),
                      const SizedBox(height: 8),
                      _barraDispositivo(
                        Icons.tablet_mac, 'Tablet',
                        m.visitasTablet, m.pctTablet, const Color(0xFF2E7D32),
                      ),
                    ]),
                  ),
                ),

              // ── Páginas más vistas ────────────────────────────────────────
              if (m.paginasMasVistas.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Páginas más visitadas', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 12),
                      ...(() {
                        final sorted = m.paginasMasVistas.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));
                        final max = sorted.first.value;
                        return sorted.take(5).map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            const Icon(Icons.web, size: 14, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(e.key, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              LinearProgressIndicator(
                                value: e.value / max,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation(Color(0xFF1976D2)),
                                minHeight: 5,
                              ),
                            ])),
                            const SizedBox(width: 8),
                            Text('${e.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ]),
                        ));
                      })(),
                    ]),
                  ),
                ),
              ],

              // ── Ubicaciones geográficas ────────────────────────────────────
              if (m.ubicaciones.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.location_on, size: 18, color: Color(0xFF1976D2)),
                        const SizedBox(width: 8),
                        const Text('Ubicación de visitantes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ]),
                      const SizedBox(height: 12),
                      ...(() {
                        final sorted = m.ubicaciones.entries.toList()
                          ..sort((a, b) => b.value.compareTo(a.value));
                        final total = sorted.fold(0, (s, e) => s + e.value);
                        return sorted.take(6).map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            const Icon(Icons.place_outlined, size: 13, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
                            Text('${e.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            Text(
                              '${(e.value / total * 100).toStringAsFixed(1)}%',
                              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                            ),
                          ]),
                        ));
                      })(),
                    ]),
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }

  Widget _kpiVisita(String label, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ]),
      ),
    );
  }

  Widget _barraDispositivo(IconData icono, String label, int count, double pct, Color color) {
    return Row(children: [
      Icon(icono, size: 16, color: color),
      const SizedBox(width: 8),
      SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 12))),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct / 100,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 10,
        ),
      )),
      const SizedBox(width: 8),
      SizedBox(width: 44, child: Text('${pct.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600))),
    ]);
  }

  Widget _infoItemWeb(IconData icono, String label, String valor, Color color) {
    return Row(children: [
      Icon(icono, size: 16, color: color),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Text(valor, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ]),
    ]);
  }
}


import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/analytics_web_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB ANALYTICS WEB — Métricas detalladas de tráfico
// ═════════════════════════════════════════════════════════════════════════════

class TabAnalyticsWeb extends StatelessWidget {
  final String empresaId;

  const TabAnalyticsWeb({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    return StreamBuilder<MetricasTraficoWeb>(
      stream: AnalyticsWebService().streamMetricas(empresaId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final m = snap.data ?? MetricasTraficoWeb.vacio();

        if (!m.tieneDatos) {
          return _buildSinDatos(color);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── KPIs principales ──────────────────────────────────────────
            _buildKpis(m, color),
            const SizedBox(height: 14),

            // ── Gráfico visitas diarias ────────────────────────────────────
            _buildGraficoVisitas(context, color),
            const SizedBox(height: 14),

            // ── Páginas más vistas ─────────────────────────────────────────
            if (m.paginasMasVistas.isNotEmpty)
              _buildPaginasVistas(m, color),
            if (m.paginasMasVistas.isNotEmpty) const SizedBox(height: 14),

            // ── Dispositivos ───────────────────────────────────────────────
            _buildDispositivos(m, color),
            const SizedBox(height: 14),

            // ── Tiempo y rebote ────────────────────────────────────────────
            _buildComportamiento(m, color),
            const SizedBox(height: 14),

            // ── Ubicaciones ────────────────────────────────────────────────
            if (m.ubicaciones.isNotEmpty)
              _buildUbicaciones(m, color),

            const SizedBox(height: 14),
            _buildInfoScript(color),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildSinDatos(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Sin datos de analytics',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Añade el script de Fluix CRM a tu web para empezar a registrar visitas',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis(MetricasTraficoWeb m, Color color) {
    return Column(
      children: [
        Row(children: [
          _kpiCard('Hoy', m.visitasHoy.toString(), Icons.today, color),
          const SizedBox(width: 10),
          _kpiCard('Esta semana', m.visitasSemana.toString(),
              Icons.date_range, Colors.indigo),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _kpiCard('Este mes', m.visitasMes.toString(),
              Icons.calendar_month, Colors.teal),
          const SizedBox(width: 10),
          _kpiCard('Total', m.visitasTotal.toString(),
              Icons.show_chart, Colors.deepOrange),
        ]),
      ],
    );
  }

  Widget _kpiCard(String label, String valor, IconData icono, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(valor,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: color)),
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildGraficoVisitas(BuildContext context, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.bar_chart, color: color, size: 16),
            const SizedBox(width: 6),
            const Text('Visitas — últimos 30 días',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 130,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future:
                  AnalyticsWebService().obtenerHistorialDiario(empresaId),
              builder: (ctx, snap) {
                if (!snap.hasData || snap.data!.isEmpty) {
                  return Center(
                    child: Text('Sin historial diario',
                        style: TextStyle(color: Colors.grey[400])),
                  );
                }
                final hist = snap.data!.reversed.toList();
                final maxV = hist
                    .map((h) =>
                        (h['visitas'] as num?)?.toDouble() ?? 0)
                    .fold(0.0, (a, b) => a > b ? a : b);

                return BarChart(
                  BarChartData(
                    maxY: maxV <= 0 ? 10 : maxV * 1.25,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0xFFEEEEEE), strokeWidth: 0.8),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 18,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i % 7 != 0 || i >= hist.length) {
                              return const SizedBox.shrink();
                            }
                            final f =
                                hist[i]['fecha']?.toString() ?? '';
                            final p = f.split('-');
                            if (p.length < 3) {
                              return const SizedBox.shrink();
                            }
                            return Text('${p[2]}/${p[1]}',
                                style: const TextStyle(
                                    fontSize: 8, color: Colors.grey));
                          },
                        ),
                      ),
                    ),
                    barGroups: hist.asMap().entries.map((e) {
                      final v =
                          (e.value['visitas'] as num?)?.toDouble() ?? 0;
                      return BarChartGroupData(
                        x: e.key,
                        barRods: [
                          BarChartRodData(
                            toY: v,
                            width: 6,
                            color: color.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          )
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginasVistas(MetricasTraficoWeb m, Color color) {
    final sorted = m.paginasMasVistas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topMax = sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.web, color: color, size: 16),
            const SizedBox(width: 6),
            const Text('Páginas más visitadas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          ...sorted.take(8).map((e) {
            final pct = topMax > 0 ? e.value / topMax : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        e.key.isEmpty ? '/' : e.key,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${e.value} visitas',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: pct.toDouble(),
                    backgroundColor: Colors.grey[100],
                    color: color,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDispositivos(MetricasTraficoWeb m, Color color) {
    final total = m.visitasMovil + m.visitasDesktop + m.visitasTablet;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.devices, color: color, size: 16),
            const SizedBox(width: 6),
            const Text('Dispositivos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          _barraDispositivo(Icons.smartphone, 'Móvil', m.visitasMovil,
              m.pctMovil, Colors.blue),
          const SizedBox(height: 8),
          _barraDispositivo(Icons.computer, 'Escritorio',
              m.visitasDesktop, m.pctDesktop, Colors.purple),
          const SizedBox(height: 8),
          _barraDispositivo(Icons.tablet_mac, 'Tablet',
              m.visitasTablet, m.pctTablet, Colors.teal),
        ],
      ),
    );
  }

  Widget _barraDispositivo(IconData icono, String label, int visitas,
      double pct, Color color) {
    return Row(children: [
      Icon(icono, size: 16, color: color),
      const SizedBox(width: 8),
      SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(fontSize: 12))),
      Expanded(
        child: LinearProgressIndicator(
          value: pct / 100,
          backgroundColor: Colors.grey[100],
          color: color,
          minHeight: 6,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        width: 70,
        child: Text(
          '$visitas (${pct.toStringAsFixed(0)}%)',
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          textAlign: TextAlign.right,
        ),
      ),
    ]);
  }

  Widget _buildComportamiento(MetricasTraficoWeb m, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.speed, color: color, size: 16),
            const SizedBox(width: 6),
            const Text('Comportamiento de usuarios',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _metricaCard(
              '⏱ Duración media',
              m.duracionFormateada,
              m.duracionMediaSegundos > 60 ? Colors.green : Colors.orange,
              m.duracionMediaSegundos > 60
                  ? 'Buen engagement'
                  : 'Mejorar contenido',
            )),
            const SizedBox(width: 10),
            Expanded(
                child: _metricaCard(
              '↩ Tasa de rebote',
              '${m.tasaRebote.toStringAsFixed(0)}%',
              m.tasaRebote < 50 ? Colors.green : Colors.orange,
              m.tasaRebote < 50 ? 'Buen resultado' : 'Alta — revisar',
            )),
          ]),
        ],
      ),
    );
  }

  Widget _metricaCard(
      String titulo, String valor, Color color, String subtitulo) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(valor,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 2),
          Text(subtitulo,
              style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  Widget _buildUbicaciones(MetricasTraficoWeb m, Color color) {
    final sorted = m.ubicaciones.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.location_on_outlined, color: color, size: 16),
            const SizedBox(width: 6),
            const Text('Top ubicaciones',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          ...sorted.take(6).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Text('📍', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(e.key,
                          style: const TextStyle(fontSize: 13))),
                  Text('${e.value}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 13)),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _buildInfoScript(Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.blue, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Cómo funciona?',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 13)),
                SizedBox(height: 4),
                Text(
                  'El script JavaScript de Fluix CRM registra automáticamente las visitas, '
                  'páginas vistas, dispositivos y ubicaciones de los usuarios de tu web. '
                  'Instálalo desde la pestaña "Código" de tu gestor de contenidos.',
                  style:
                      TextStyle(color: Colors.blue, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
        ],
      );
}


// modulo_estadisticas.dart — ACTUALIZADO
// CAMBIOS:
//  - _SeccionTraficoWeb completamente rediseñada con visuales ricos
//  - Nuevas secciones: Duración media, Tasa de rebote, Gráfico 30 días,
//    Dispositivos (donut + barras), Fuentes de tráfico (barras horizontales
//    con iconos por red social), Ubicaciones (países + ciudades),
//    Páginas más visitadas con barras proporcionales.
//  - Todos los datos capturados por el script JS tienen su representación visual.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/estadisticas_cache_service.dart';
import '../../../services/analytics_web_service.dart';
import '../../../services/suscripcion_service.dart';
import '../../../core/utils/permisos_service.dart';
import 'package:flutter/foundation.dart';

class ModuloEstadisticas extends StatefulWidget {
  final String empresaId;
  final SesionUsuario? sesion;

  const ModuloEstadisticas({
    super.key,
    required this.empresaId,
    this.sesion,
  });

  @override
  State<ModuloEstadisticas> createState() => _ModuloEstadisticasState();
}

class _ModuloEstadisticasState extends State<ModuloEstadisticas> {
  final EstadisticasCacheService _cacheService = EstadisticasCacheService();
  bool _calculandoCache = false;
  bool _tieneFacturacion = false;
  bool _tieneTienda = false;

  @override
  void initState() {
    super.initState();
    _iniciarCacheAutomatico();
    _verificarPacks();
  }

  void _verificarPacks() {
    final svc = SuscripcionService();
    setState(() {
      _tieneFacturacion = svc.tieneModulo('facturacion') ||
          (widget.sesion?.esPropietarioPlatforma ?? false);
      _tieneTienda = svc.tieneModulo('pedidos') ||
          (widget.sesion?.esPropietarioPlatforma ?? false);
    });
  }

  @override
  void dispose() {
    _cacheService.detenerCacheAutomatico(widget.empresaId);
    super.dispose();
  }

  void _iniciarCacheAutomatico() {
    _cacheService.iniciarCacheAutomatico(widget.empresaId);
  }

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
        final fechaCalculo = data['fecha_calculo'] as String?;
        if (fechaCalculo != null) {
          final ultimaAct = DateTime.tryParse(fechaCalculo.length > 23
              ? fechaCalculo.substring(0, 23)
              : fechaCalculo) ??
              DateTime.now();
          if (DateTime.now().difference(ultimaAct).inHours < 1) return data;
        }
        _cacheService.recalcularEstadisticas(widget.empresaId);
        return data;
      }
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
                // ── Sección tráfico web COMPLETAMENTE REDISEÑADA ──────────
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

  // ─── Todos los widgets del módulo estadísticas (sin cambios) ────────────

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
                  child:
                  const Icon(Icons.analytics, color: Color(0xFF1976D2), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dashboard de Estadísticas',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15)),
                      Text('Métricas completas de tu negocio',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (_calculandoCache)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _recalcularManual,
                    iconSize: 20,
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
    final beneficioNeto =
        (data['beneficio_neto_mes'] as num?)?.toDouble() ?? (ingresosMes - gastosMes);
    final esPositivo = beneficioNeto >= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('KPIs Principales',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            if (_tieneFacturacion)
              Expanded(
                child: _kpiCardGrande(
                  context,
                  'Beneficio Neto',
                  '${esPositivo ? "" : "-"}€${beneficioNeto.abs().toStringAsFixed(0)}',
                  esPositivo ? Icons.trending_up : Icons.trending_down,
                  esPositivo ? const Color(0xFF2E7D32) : const Color(0xFFF44336),
                  0.0,
                  'Ingresos: €${ingresosMes.toStringAsFixed(0)} | Gastos: €${gastosMes.toStringAsFixed(0)}',
                ),
              )
            else
              Expanded(child: _kpiFacturacionBloqueada(context)),
            const SizedBox(width: 12),
            Expanded(
              child: _kpiCardGrande(
                context,
                'Reservas Confirmadas',
                '${data['reservas_confirmadas'] ?? 0}',
                Icons.event_available,
                const Color(0xFF1976D2),
                _calcPct(data['reservas_mes'], data['reservas_mes_anterior']),
                'Total: ${data['reservas_mes'] ?? 0}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _kpiCardGrande(
                context,
                'Nuevos Clientes',
                '${data['nuevos_clientes_mes'] ?? 0}',
                Icons.person_add,
                const Color(0xFF7B1FA2),
                _calcPct(
                    data['nuevos_clientes_mes'], data['nuevos_clientes_mes_anterior']),
                'Total: ${data['total_clientes'] ?? 0}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _kpiCardGrande(
                context,
                'Valoración Media',
                '${(data['valoracion_promedio'] ?? 0.0).toStringAsFixed(1)} ⭐',
                Icons.star,
                const Color(0xFFF57C00),
                0.0,
                '${data['total_valoraciones'] ?? 0} reseñas',
              ),
            ),
          ],
        ),
      ],
    );
  }

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
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.account_balance_wallet, color: Colors.grey[400], size: 24),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline, color: Colors.orange, size: 12),
                SizedBox(width: 4),
                Text('No contratado',
                    style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Text('—',
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey[400])),
          const SizedBox(height: 4),
          const Text('Ingresos del Mes',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Activa el módulo Finanzas para ver los ingresos',
              style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ]),
      ),
    );
  }

  Widget _kpiCardGrande(
      BuildContext context,
      String titulo,
      String valor,
      IconData icono,
      Color color,
      double pct,
      String subtitulo,
      ) {
    final esPositivo = pct >= 0;
    final colorPct =
    esPositivo ? const Color(0xFF4CAF50) : const Color(0xFFF44336);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.1), Colors.white],
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icono, color: color, size: 24),
            const Spacer(),
            if (pct != 0.0)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: colorPct.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    esPositivo ? Icons.trending_up : Icons.trending_down,
                    color: colorPct,
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${pct >= 0 ? "+" : ""}${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                        color: colorPct,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
          ]),
          const SizedBox(height: 12),
          Text(valor,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(titulo,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitulo,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ]),
      ),
    );
  }

  Widget _buildGraficoRendimiento(BuildContext context, Map<String, dynamic> data) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Rendimiento del Negocio',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _metricaCard(
              'Tasa Conversión',
              '${(data['tasa_conversion'] ?? 0).toStringAsFixed(1)}%',
              Icons.trending_up,
              const Color(0xFF4CAF50),
            )),
            const SizedBox(width: 12),
            Expanded(child: _metricaCard(
              'Tasa Cancelación',
              '${(data['tasa_cancelacion'] ?? 0).toStringAsFixed(1)}%',
              Icons.cancel,
              const Color(0xFFF44336),
            )),
            const SizedBox(width: 12),
            Expanded(child: _metricaCard(
              'Ticket Medio',
              '€${(data['valor_medio_reserva'] ?? 0).toStringAsFixed(0)}',
              Icons.euro,
              const Color(0xFF1976D2),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _buildGridMetricasNegocio(BuildContext context, Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Métricas de Negocio',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _metricaCompacta(
              'Reservas Completadas', '${data['reservas_completadas'] ?? 0}',
              Icons.check_circle, const Color(0xFF4CAF50))),
          const SizedBox(width: 8),
          Expanded(child: _metricaCompacta(
              'Reservas Pendientes', '${data['reservas_pendientes'] ?? 0}',
              Icons.pending, const Color(0xFFF57C00))),
          const SizedBox(width: 8),
          Expanded(child: _metricaCompacta(
              'Clientes Activos', '${data['clientes_activos'] ?? 0}',
              Icons.people, const Color(0xFF1976D2))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _metricaCompacta(
              'Servicios Activos', '${data['total_servicios_activos'] ?? 0}',
              Icons.design_services, const Color(0xFF7B1FA2))),
          const SizedBox(width: 8),
          Expanded(child: _metricaCompacta(
              'Empleados Activos', '${data['total_empleados_activos'] ?? 0}',
              Icons.badge, const Color(0xFF388E3C))),
          const SizedBox(width: 8),
          Expanded(
            child: !_tieneTienda
                ? _metricaBloqueada('Pedidos del Mes', 'Pack Tienda')
                : _metricaCompacta(
                'Pedidos del Mes', '${data['pedidos_mes'] ?? 0}',
                Icons.shopping_bag_outlined, const Color(0xFF1565C0)),
          ),
        ]),
      ],
    );
  }

  Widget _buildEstadisticasServicios(
      BuildContext context, Map<String, dynamic> data) {
    final rps = data['reservas_por_servicio'] as Map<String, dynamic>? ?? {};
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.design_services, color: Color(0xFF7B1FA2), size: 20),
            const SizedBox(width: 8),
            const Text('Servicios Más Populares',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            Text('Total: ${data['total_servicios_activos'] ?? 0}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ]),
          const SizedBox(height: 16),
          _infoRow(Icons.star, 'Más Popular',
              data['servicio_mas_popular'] ?? 'N/A'),
          _infoRow(Icons.attach_money, 'Más Rentable',
              data['servicio_mas_rentable'] ?? 'N/A'),
          if (rps.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Reservas por Servicio:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 8),
            ...rps.entries.take(4).map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                        color: Color(0xFF7B1FA2),
                        shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                    child:
                    Text(e.key, style: const TextStyle(fontSize: 12))),
                Text('${e.value}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            )),
          ],
        ]),
      ),
    );
  }

  Widget _buildEstadisticasEmpleados(
      BuildContext context, Map<String, dynamic> data) {
    final re = data['rendimiento_empleados'] as Map<String, dynamic>? ?? {};
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.badge, color: Color(0xFF388E3C), size: 20),
            const SizedBox(width: 8),
            const Text('Rendimiento del Equipo',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            Text('Total: ${data['total_empleados_activos'] ?? 0}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ]),
          const SizedBox(height: 16),
          _infoRow(Icons.star, 'Más Activo',
              data['empleado_mas_activo'] ?? 'N/A'),
          const SizedBox(height: 8),
          Row(children: [
            _rolChip('PROP', data['empleados_propietarios'] ?? 0,
                const Color(0xFFF44336)),
            const SizedBox(width: 8),
            _rolChip('ADMIN', data['empleados_admin'] ?? 0,
                const Color(0xFF1976D2)),
            const SizedBox(width: 8),
            _rolChip('STAFF', data['empleados_staff'] ?? 0,
                const Color(0xFF388E3C)),
          ]),
          if (re.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Reservas por Empleado:',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 8),
            ...re.entries.take(3).map((e) {
              final d = e.value as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                          color: Color(0xFF388E3C),
                          shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(e.key, style: const TextStyle(fontSize: 12))),
                  Text('${d['reservas'] ?? 0}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              );
            }),
          ],
        ]),
      ),
    );
  }

  Widget _buildValoracionesFeedback(
      BuildContext context, Map<String, dynamic> data) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.star, color: Color(0xFFF57C00), size: 20),
            const SizedBox(width: 8),
            const Text('Valoraciones de Clientes',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF57C00).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(data['valoracion_promedio'] ?? 0.0).toStringAsFixed(1)} ⭐',
                style: const TextStyle(
                    color: Color(0xFFF57C00),
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _valDistrib(
                '5⭐', data['valoraciones_5_estrellas'] ?? 0,
                const Color(0xFF4CAF50))),
            const SizedBox(width: 8),
            Expanded(child: _valDistrib(
                '4⭐', data['valoraciones_4_estrellas'] ?? 0,
                const Color(0xFF8BC34A))),
            const SizedBox(width: 8),
            Expanded(child: _valDistrib(
                '3⭐', data['valoraciones_3_estrellas'] ?? 0,
                const Color(0xFFFFC107))),
            const SizedBox(width: 8),
            Expanded(child: _valDistrib(
                '2⭐', data['valoraciones_2_estrellas'] ?? 0,
                const Color(0xFFFF9800))),
            const SizedBox(width: 8),
            Expanded(child: _valDistrib(
                '1⭐', data['valoraciones_1_estrella'] ?? 0,
                const Color(0xFFF44336))),
          ]),
          const SizedBox(height: 12),
          _infoRow(Icons.reviews, 'Total reseñas',
              '${data['total_valoraciones'] ?? 0}'),
          _infoRow(Icons.new_releases, 'Este mes',
              '${data['valoraciones_mes'] ?? 0}'),
        ]),
      ),
    );
  }

  Widget _buildInfoAdicionalCompleta(
      BuildContext context, Map<String, dynamic> data) {
    final horasPico =
        (data['horas_pico'] as List<dynamic>?)?.cast<String>() ?? [];
    final distribucionDias =
        data['distribucion_dias'] as Map<String, dynamic>? ?? {};

    return Column(children: [
      Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Información Adicional',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 14),
            _infoRow(Icons.schedule, 'Horas pico', horasPico.join(', ')),
            _infoRow(Icons.today, 'Día más activo',
                data['dia_mas_activo'] ?? 'N/A'),
            _infoRow(Icons.payment, 'Método preferido',
                data['metodo_pago_preferido'] ?? 'Efectivo'),
            _infoRow(Icons.people, 'Cliente más valioso',
                data['cliente_mas_valioso'] ?? 'N/A'),
            _infoRow(Icons.euro, 'Valor promedio cliente',
                '€${(data['valor_promedio_cliente'] ?? 0).toStringAsFixed(0)}'),
          ]),
        ),
      ),
      if (distribucionDias.isNotEmpty) ...[
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Actividad por Días',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 12),
              ...distribucionDias.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(
                    width: 80,
                    child: Text(entry.key.capitalize(),
                        style: const TextStyle(fontSize: 12)),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (entry.value as int) /
                          (distribucionDias.values
                              .fold<int>(0, (s, v) => s + (v as int))),
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF1976D2)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${entry.value}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              )),
            ]),
          ),
        ),
      ],
    ]);
  }

  Widget _buildEstadoSinDatos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration:
            BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
            child: Icon(Icons.analytics, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text('Calculando estadísticas',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700])),
          const SizedBox(height: 8),
          Text(
            'Por favor espera mientras procesamos los datos',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ]),
      ),
    );
  }

  Widget _buildIndicadorCache(Map<String, dynamic> data) {
    final fechaCalculo = data['fecha_calculo'] as String?;
    if (fechaCalculo == null) return const SizedBox.shrink();
    final ultima = DateTime.tryParse(fechaCalculo.length > 23
        ? fechaCalculo.substring(0, 23)
        : fechaCalculo) ??
        DateTime.now();
    final dif = DateTime.now().difference(ultima);

    Color color;
    IconData icono;
    String msg;
    if (dif.inMinutes < 5) {
      color = const Color(0xFF4CAF50);
      icono = Icons.check_circle;
      msg = 'Datos actualizados hace ${dif.inMinutes} min';
    } else if (dif.inMinutes < 30) {
      color = Colors.orange;
      icono = Icons.schedule;
      msg = 'Datos de hace ${dif.inMinutes} min';
    } else {
      color = Colors.red;
      icono = Icons.warning;
      msg = 'Datos de hace ${dif.inHours}h ${dif.inMinutes % 60}min';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 8),
        Text(msg,
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        if (dif.inMinutes > 30) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () =>
                _cacheService.recalcularEstadisticas(widget.empresaId),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
              child: const Text('Actualizar',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ]),
    );
  }

  // ── Helpers reutilizables ─────────────────────────────────────────────────

  Widget _metricaCard(
      String titulo, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(icono, color: color, size: 16),
        const SizedBox(height: 6),
        Text(valor,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(titulo,
            style: TextStyle(fontSize: 10, color: color),
            textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _metricaCompacta(
      String titulo, String valor, IconData icono, Color color) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(height: 6),
          Text(valor,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(titulo,
              style: TextStyle(fontSize: 10, color: color),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _metricaBloqueada(String titulo, String pack) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.grey.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_outline, color: Colors.grey[400], size: 14),
            const SizedBox(width: 4),
            Text(pack,
                style: TextStyle(color: Colors.orange[700], fontSize: 9)),
          ]),
          const SizedBox(height: 6),
          Text('—',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[400])),
          const SizedBox(height: 2),
          Text(titulo,
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _rolChip(String rol, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Text('$rol: $count',
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _valDistrib(String estrella, int count, Color color) {
    return Column(children: [
      Text(estrella,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text('$count',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  Widget _infoRow(IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icono, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const Spacer(),
        Text(valor,
            style:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  double _calcPct(dynamic actual, dynamic anterior) {
    final a = (actual as num?)?.toDouble() ?? 0;
    final b = (anterior as num?)?.toDouble() ?? 0;
    if (b == 0) return 0;
    return (a - b) / b * 100;
  }
}

extension StringCapitalize on String {
  String capitalize() =>
      '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
}

// ═════════════════════════════════════════════════════════════════════════════
// _SeccionTraficoWeb — COMPLETAMENTE REDISEÑADA
// Muestra TODOS los datos capturados por el script JS:
//   visitas_hoy/semana/mes/total, duracion_media, tasa_rebote,
//   dispositivos (movil/desktop/tablet), fuentes (referrers),
//   páginas más vistas, ubicaciones (países + ciudades),
//   gráfico histórico 30 días.
// ═════════════════════════════════════════════════════════════════════════════

class _SeccionTraficoWeb extends StatelessWidget {
  final String empresaId;
  const _SeccionTraficoWeb({required this.empresaId});

  // ── Helpers ──────────────────────────────────────────────────────────────

  IconData _iconoFuente(String f) {
    if (f.contains('google'))    return Icons.search;
    if (f.contains('facebook'))  return Icons.facebook;
    if (f.contains('instagram')) return Icons.camera_alt;
    if (f.contains('twitter'))   return Icons.alternate_email;
    if (f.contains('whatsapp'))  return Icons.chat;
    if (f == 'directo')          return Icons.link;
    return Icons.language;
  }

  Color _colorFuente(String f) {
    if (f.contains('google'))    return const Color(0xFF4285F4);
    if (f.contains('facebook'))  return const Color(0xFF1877F2);
    if (f.contains('instagram')) return const Color(0xFFE1306C);
    if (f.contains('twitter'))   return const Color(0xFF1DA1F2);
    if (f.contains('whatsapp'))  return const Color(0xFF25D366);
    if (f == 'directo')          return const Color(0xFF757575);
    return const Color(0xFF1976D2);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MetricasTraficoWeb>(
      stream: AnalyticsWebService().streamMetricas(empresaId),
      builder: (context, snap) {
        final m = snap.data ?? MetricasTraficoWeb.vacio();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Título de sección ────────────────────────────────────────
            _cabeceraTituloSeccion(m),
            const SizedBox(height: 14),

            if (!m.tieneDatos) ...[
              _tarjetaSinDatos(),
            ] else ...[

              // ── 1. Resumen de visitantes ─────────────────────────────
              _tarjetaVisitantes(m),
              const SizedBox(height: 12),

              // ── 2. Duración media + Tasa de rebote ───────────────────
              _tarjetaDuracionRebote(context, m),
              const SizedBox(height: 12),

              // ── 3. Gráfico histórico 30 días ─────────────────────────
              _tarjetaGrafico30Dias(),
              const SizedBox(height: 12),

              // ── 4. Dispositivos ──────────────────────────────────────
              if (m.visitasMovil + m.visitasDesktop + m.visitasTablet > 0) ...[
                _tarjetaDispositivos(m),
                const SizedBox(height: 12),
              ],

              // ── 5. Fuentes de tráfico ────────────────────────────────
              if (m.referrers.isNotEmpty) ...[
                _tarjetaFuentesTrafico(m),
                const SizedBox(height: 12),
              ],

              // ── 6. Páginas más visitadas ─────────────────────────────
              if (m.paginasMasVistas.isNotEmpty) ...[
                _tarjetaPaginasMasVistas(m),
                const SizedBox(height: 12),
              ],

              // ── 7. Ubicaciones (países + ciudades) ───────────────────
              if (m.ubicaciones.isNotEmpty) ...[
                _tarjetaUbicaciones(m),
              ],
            ],
          ],
        );
      },
    );
  }

  // ── 0. Cabecera de sección ────────────────────────────────────────────────

  Widget _cabeceraTituloSeccion(MetricasTraficoWeb m) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1565C0).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child:
        const Icon(Icons.language, color: Color(0xFF1565C0), size: 22),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tráfico Web',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text('Datos en tiempo real desde tu web',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
      if (m.ultimaActualizacion != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.circle, size: 6, color: Color(0xFF4CAF50)),
            SizedBox(width: 4),
            Text('En vivo',
                style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w600)),
          ]),
        ),
    ]);
  }

  // ── 0b. Sin datos ─────────────────────────────────────────────────────────

  Widget _tarjetaSinDatos() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.grey[100], shape: BoxShape.circle),
            child: Icon(Icons.code, size: 40, color: Colors.grey[300]),
          ),
          const SizedBox(height: 16),
          const Text('Esperando datos del script web',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 6),
          Text(
            'El script JavaScript instalado en tu web enviará los datos '
                'automáticamente. Cada visita se registra en tiempo real.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Checklist de qué se registrará
          ...[
            'Visitantes por día / semana / mes',
            'Dispositivos: móvil, desktop, tablet',
            'Fuentes de tráfico (Google, redes, directo…)',
            'Páginas más visitadas',
            'Países y ciudades de origen',
            'Duración media en página',
            'Tasa de rebote',
          ].map((txt) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Icon(Icons.check_circle_outline,
                  size: 15, color: Colors.grey[400]),
              const SizedBox(width: 8),
              Text(txt,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
          )),
        ]),
      ),
    );
  }

  // ── 1. Visitantes (4 KPIs) ────────────────────────────────────────────────

  Widget _tarjetaVisitantes(MetricasTraficoWeb m) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _tituloTarjeta(Icons.people_alt_outlined, 'Visitantes únicos'),
          const SizedBox(height: 14),
          Row(children: [
            _kpiVisitante('Hoy', '${m.visitasHoy}', Icons.today,
                const Color(0xFF1976D2)),
            const SizedBox(width: 8),
            _kpiVisitante('Semana', '${m.visitasSemana}', Icons.date_range,
                const Color(0xFF7B1FA2)),
            const SizedBox(width: 8),
            _kpiVisitante('Mes', '${m.visitasMes}', Icons.calendar_month,
                const Color(0xFF2E7D32)),
            const SizedBox(width: 8),
            _kpiVisitante('Total', '${m.visitasTotal}', Icons.all_inclusive,
                const Color(0xFFF57C00)),
          ]),
        ]),
      ),
    );
  }

  // ── 2. Duración media + Tasa de rebote ───────────────────────────────────

  Widget _tarjetaDuracionRebote(BuildContext context, MetricasTraficoWeb m) {
    final tieneDuracion = m.duracionMediaSegundos > 0;
    final tieneRebote   = m.tasaRebote > 0;

    final reboteBueno = m.tasaRebote <= 40;
    final reboteOk    = m.tasaRebote <= 60;
    final colorRebote = reboteBueno
        ? const Color(0xFF4CAF50)
        : reboteOk
        ? Colors.orange
        : const Color(0xFFF44336);
    final labelRebote = reboteBueno ? 'Excelente' : reboteOk ? 'Normal' : 'Alta';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _tituloTarjeta(Icons.timer_outlined, 'Comportamiento del visitante'),
          const SizedBox(height: 14),

          // ── Si ningún dato disponible aún, mostrar placeholder explicativo
          if (!tieneDuracion && !tieneRebote)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(children: [
                Icon(Icons.hourglass_empty, size: 28, color: Colors.grey[350]),
                const SizedBox(height: 8),
                Text(
                  'Acumulando datos de comportamiento…',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'El script registra la duración y los rebotes '
                      'al salir de cada página. Aparecerá aquí tras '
                      'las primeras visitas completas.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
              ]),
            )
          else
            Row(children: [
              // Duración media
              Expanded(
                child: tieneDuracion
                    ? _metricaEngagement(
                  icono:    Icons.av_timer,
                  label:    'Duración media',
                  valor:    m.duracionFormateada,
                  color:    const Color(0xFF0288D1),
                  subtitulo: 'por visita',
                )
                    : _metricaEngagementVacia(
                  icono:  Icons.av_timer,
                  label:  'Duración media',
                  color:  const Color(0xFF0288D1),
                ),
              ),
              const SizedBox(width: 12),
              // Tasa de rebote
              Expanded(
                child: tieneRebote
                    ? GestureDetector(
                  onTap: () => _mostrarInfoRebote(context),
                  child: _metricaEngagement(
                    icono:    Icons.exit_to_app,
                    label:    'Tasa de rebote',
                    valor:    '${m.tasaRebote.toStringAsFixed(1)}%',
                    color:    colorRebote,
                    subtitulo: labelRebote,
                    badge: const Icon(Icons.info_outline,
                        size: 12, color: Colors.grey),
                  ),
                )
                    : GestureDetector(
                  onTap: () => _mostrarInfoRebote(context),
                  child: _metricaEngagementVacia(
                    icono:  Icons.exit_to_app,
                    label:  'Tasa de rebote',
                    color:  Colors.grey,
                    badge: const Icon(Icons.info_outline,
                        size: 12, color: Colors.grey),
                  ),
                ),
              ),
            ]),
        ]),
      ),
    );
  }

  /// Versión vacía/placeholder de una métrica de engagement
  Widget _metricaEngagementVacia({
    required IconData icono,
    required String   label,
    required Color    color,
    Widget?           badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icono, size: 18, color: Colors.grey[350]),
          const Spacer(),
          if (badge != null) badge,
        ]),
        const SizedBox(height: 10),
        Text('—',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[350])),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text('Sin datos aún',
            style: TextStyle(fontSize: 11, color: Colors.grey[400])),
      ]),
    );
  }

  void _mostrarInfoRebote(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.exit_to_app, color: Color(0xFF1976D2), size: 20),
          SizedBox(width: 8),
          Text('Tasa de Rebote', style: TextStyle(fontSize: 16)),
        ]),
        content: const Text(
          '🔴 ¿Qué es la Tasa de Rebote?\n\n'
              'Es el porcentaje de visitas en las que el usuario entra a tu '
              'web y se va sin navegar a otra página.\n\n'
              '📊 Cómo se interpreta:\n'
              '• < 40% → Excelente\n'
              '• 40–60% → Normal para webs de servicios\n'
              '• > 60% → Alta: el contenido puede no enganchar',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ── 3. Gráfico histórico 30 días ──────────────────────────────────────────

  Widget _tarjetaGrafico30Dias() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: AnalyticsWebService().obtenerHistorialDiario(empresaId),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
        final hist = snap.data!.reversed.toList();
        final maxV = hist
            .map((h) => (h['visitas'] as num?)?.toDouble() ?? 0)
            .fold(0.0, (a, b) => a > b ? a : b);

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tituloTarjeta(Icons.bar_chart, 'Visitas — últimos 30 días'),
                const SizedBox(height: 14),
                SizedBox(
                  height: 130,
                  child: BarChart(BarChartData(
                    maxY: maxV <= 0 ? 10 : maxV * 1.2,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0xFFE0E0E0), strokeWidth: 0.8),
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
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i % 5 != 0 || i >= hist.length)
                              return const SizedBox.shrink();
                            final parts =
                            (hist[i]['fecha']?.toString() ?? '').split('-');
                            if (parts.length < 3)
                              return const SizedBox.shrink();
                            return Text('${parts[2]}/${parts[1]}',
                                style: const TextStyle(
                                    fontSize: 8, color: Colors.grey));
                          },
                          reservedSize: 20,
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
                            width: 5,
                            color: const Color(0xFF1976D2),
                            borderRadius: BorderRadius.circular(2),
                          )
                        ],
                      );
                    }).toList(),
                  )),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── 4. Dispositivos ───────────────────────────────────────────────────────

  Widget _tarjetaDispositivos(MetricasTraficoWeb m) {
    final total = m.visitasMovil + m.visitasDesktop + m.visitasTablet;
    if (total == 0) return const SizedBox.shrink();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloTarjeta(Icons.devices, 'Dispositivos'),
            const SizedBox(height: 14),

            // Mini gráfico de distribución (pills visuales)
            _pillsDispositivo(total, m),
            const SizedBox(height: 14),

            // Barras detalladas
            _barraDispositivo(Icons.smartphone, 'Móvil',
                m.visitasMovil, m.pctMovil, const Color(0xFF1976D2)),
            const SizedBox(height: 8),
            _barraDispositivo(Icons.computer, 'Desktop',
                m.visitasDesktop, m.pctDesktop, const Color(0xFF7B1FA2)),
            const SizedBox(height: 8),
            _barraDispositivo(Icons.tablet_mac, 'Tablet',
                m.visitasTablet, m.pctTablet, const Color(0xFF2E7D32)),
          ],
        ),
      ),
    );
  }

  Widget _pillsDispositivo(int total, MetricasTraficoWeb m) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 16,
        child: Row(
          children: [
            if (m.visitasMovil > 0)
              Flexible(
                flex: m.visitasMovil,
                child: Container(color: const Color(0xFF1976D2)),
              ),
            if (m.visitasDesktop > 0)
              Flexible(
                flex: m.visitasDesktop,
                child: Container(color: const Color(0xFF7B1FA2)),
              ),
            if (m.visitasTablet > 0)
              Flexible(
                flex: m.visitasTablet,
                child: Container(color: const Color(0xFF2E7D32)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _barraDispositivo(
      IconData icono, String label, int count, double pct, Color color) {
    return Row(children: [
      Icon(icono, size: 16, color: color),
      const SizedBox(width: 8),
      SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontSize: 12))),
      Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 10,
            ),
          )),
      const SizedBox(width: 8),
      SizedBox(
          width: 36,
          child: Text('${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right)),
      const SizedBox(width: 4),
      SizedBox(
          width: 30,
          child: Text('$count',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]))),
    ]);
  }

  // ── 5. Fuentes de tráfico ─────────────────────────────────────────────────

  Widget _tarjetaFuentesTrafico(MetricasTraficoWeb m) {
    final sorted = m.referrers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold(0, (s, e) => s + e.value);
    if (total == 0) return const SizedBox.shrink();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _tituloTarjeta(Icons.travel_explore, 'Fuentes de tráfico'),
              const Spacer(),
              Text('$total sesiones',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ]),
            const SizedBox(height: 14),
            ...sorted.take(7).map((entry) {
              final pct = entry.value / total;
              final color = _colorFuente(entry.key);
              final nombre = entry.key == 'directo'
                  ? 'Directo'
                  : entry.key[0].toUpperCase() + entry.key.substring(1);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_iconoFuente(entry.key), size: 16, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(nombre,
                                    style: const TextStyle(fontSize: 12))),
                            Text('${entry.value}',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 40,
                              child: Text(
                                '${(pct * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[500]),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation(color),
                              minHeight: 6,
                            ),
                          ),
                        ]),
                  ),
                ]),
              );
            }),
            if (sorted.length > 7) ...[
              const SizedBox(height: 6),
              Text('+ ${sorted.length - 7} fuentes más',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ],
        ),
      ),
    );
  }

  // ── 6. Páginas más visitadas ──────────────────────────────────────────────

  Widget _tarjetaPaginasMasVistas(MetricasTraficoWeb m) {
    final sorted = m.paginasMasVistas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.isEmpty) return const SizedBox.shrink();
    final maxV = sorted.first.value;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloTarjeta(Icons.web_outlined, 'Páginas más visitadas'),
            const SizedBox(height: 14),
            ...sorted.take(6).map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.insert_drive_file_outlined,
                      size: 14, color: Color(0xFF1565C0)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(
                                _labelPagina(e.key),
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              )),
                          Text('${e.value}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: e.value / maxV,
                            backgroundColor: Colors.grey[200],
                            valueColor: const AlwaysStoppedAnimation(
                                Color(0xFF1565C0)),
                            minHeight: 5,
                          ),
                        ),
                      ]),
                ),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  String _labelPagina(String key) {
    if (key == 'inicio' || key.isEmpty) return '/ (Inicio)';
    return '/${key.replaceAll('_', '/')}';
  }

  // ── 7. Ubicaciones ────────────────────────────────────────────────────────

  Widget _tarjetaUbicaciones(MetricasTraficoWeb m) {
    final sortedPaises = m.ubicaciones.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalPaises = sortedPaises.fold(0, (s, e) => s + e.value);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloTarjeta(Icons.public, 'Ubicación de visitantes'),
            const SizedBox(height: 14),

            // Países
            ...sortedPaises.take(6).map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                const Icon(Icons.flag_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(e.key.replaceAll('_', ' '),
                        style: const TextStyle(fontSize: 12))),
                Text('${e.value}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${(e.value / totalPaises * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey[500]),
                    textAlign: TextAlign.right,
                  ),
                ),
              ]),
            )),

            // Ciudades (si las hay)
            if (m.ubicacionesCiudad.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.apartment, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                const Text('Ciudades',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey)),
              ]),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: (() {
                  final sorted = m.ubicacionesCiudad.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));
                  return sorted.take(8).map((e) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.location_city,
                          size: 11, color: Color(0xFF1565C0)),
                      const SizedBox(width: 4),
                      Text(
                        '${e.key.replaceAll('_', ' ')} · ${e.value}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF1565C0)),
                      ),
                    ]),
                  ));
                })().toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  Widget _tituloTarjeta(IconData icono, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 18, color: const Color(0xFF1565C0)),
        const SizedBox(width: 8),
        Text(texto,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Widget _kpiVisitante(
      String label, String valor, IconData icono, Color color) {
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
          Text(valor,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ]),
      ),
    );
  }

  Widget _metricaEngagement({
    required IconData icono,
    required String label,
    required String valor,
    required Color color,
    required String subtitulo,
    Widget? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icono, size: 18, color: color),
          const Spacer(),
          if (badge != null) badge,
        ]),
        const SizedBox(height: 10),
        Text(valor,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text(subtitulo,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ]),
    );
  }
}
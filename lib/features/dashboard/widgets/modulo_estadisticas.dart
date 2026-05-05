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

  /// Verifica qué packs tiene activos la empresa
  void _verificarPacks() {
    final svc = SuscripcionService();

    setState(() {
      // Verificar Pack Gestión (para facturación)
      _tieneFacturacion = svc.tieneModulo('facturacion') ||
          (widget.sesion?.esPropietarioPlatforma ?? false);

      // Verificar Pack Tienda (para pedidos)
      _tieneTienda = svc.tieneModulo('pedidos') ||
          (widget.sesion?.esPropietarioPlatforma ?? false);
    });

    debugPrint('📊 Packs verificados - Facturación: $_tieneFacturacion, Tienda: $_tieneTienda');
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
          final ultimaAct = DateTime.tryParse(fechaCalculo.length > 23 ? fechaCalculo.substring(0, 23) : fechaCalculo) ?? DateTime.now();
          final diferencia = DateTime.now().difference(ultimaAct);
          if (diferencia.inHours < 1) {
            debugPrint('✅ Usando estadísticas desde cache (${diferencia.inMinutes} min)');
            return data;
          }
        }
        // Cache obsoleto — recalcular en background y devolver lo que hay
        debugPrint('⚠️ Cache obsoleto, recalculando en background...');
        _cacheService.recalcularEstadisticas(widget.empresaId);
        return data; // Devuelve datos aunque obsoletos mientras recalcula
      }

      // No hay cache — lanzar cálculo y devolver vacío (el stream emitirá de nuevo cuando acabe)
      debugPrint('📊 Sin cache, calculando estadísticas reales por primera vez...');
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
                _buildEstadisticasFichajes(context, data),
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
                  'Se calculan automáticamente cada hora a partir de los datos reales de tu cuenta.',
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

  /// KPI de pedidos bloqueado cuando no tiene Pack Tienda
  Widget _kpiPedidosBloqueado() {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.grey.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.grey[400], size: 18),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, color: Colors.orange, size: 10),
                      SizedBox(width: 2),
                      Text('Pack Tienda', style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('—', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[400])),
            const SizedBox(height: 2),
            Text('Pedidos del Mes', style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
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
    );
  }

  /// Muestra un dialog con la explicación de un indicador
  void _mostrarInfoDialog(BuildContext context, String titulo, String texto) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.info_outline, color: Color(0xFF1976D2), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16))),
        ]),
        content: Text(texto, style: const TextStyle(fontSize: 13, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildGraficoRendimiento(BuildContext context, Map<String, dynamic> data) {
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
                  '✅ Reservas completadas ÷ Reservas totales del mes × 100.\n\n'
                      'Indica qué porcentaje de las reservas acaban en servicio real. '
                      'Un valor alto (>70%) es positivo.\n\n'
                      'Estados contados: COMPLETADA, FINALIZADA.',
                )),
                const SizedBox(width: 12),
                Expanded(child: _metricaCardConInfo(
                  context,
                  'Tasa Cancelación',
                  '${(data['tasa_cancelacion'] ?? 0).toStringAsFixed(1)}%',
                  Icons.cancel,
                  const Color(0xFFF44336),
                  '❌ Reservas canceladas ÷ Reservas totales del mes × 100.\n\n'
                      'Indica el porcentaje de reservas que se cancelan antes de completarse. '
                      'Un valor bajo (<15%) es deseable.\n\n'
                      'Solo se cuentan reservas con estado CANCELADA.',
                )),
                const SizedBox(width: 12),
                Expanded(child: _metricaCardConInfo(
                  context,
                  'Ticket Medio',
                  '€${(data['valor_medio_reserva'] ?? 0).toStringAsFixed(0)}',
                  Icons.euro,
                  const Color(0xFF1976D2),
                  '💶 Precio total de las reservas del mes ÷ Número de reservas con precio.\n\n'
                      'Calculado directamente desde el campo precio/total/importe de cada reserva.\n\n'
                      'Si muestra €0, las reservas no tienen precio guardado.',
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
            // ── KPI Pedidos: bloqueado si no tiene Pack Tienda ──
            Expanded(
              child: !_tieneTienda
                  ? _kpiPedidosBloqueado()
                  : _metricaCompactaCard(
                'Pedidos del Mes',
                '${data['pedidos_mes'] ?? 0}',
                Icons.shopping_bag_outlined,
                const Color(0xFF1565C0),
              ),
            ),
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
                const Icon(Icons.badge, color: Color(0xFF388E3C), size: 20),
                const SizedBox(width: 8),
                const Text('Rendimiento del Equipo', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                Text('Total: ${data['total_empleados_activos'] ?? 0}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            _infoRow(Icons.star, 'Más Activo', data['empleado_mas_activo'] ?? 'N/A'),
            const SizedBox(height: 8),
            Row(
              children: [
                _rolEmpleadoChip('PROP', data['empleados_propietarios'] ?? 0, const Color(0xFFF44336)),
                const SizedBox(width: 8),
                _rolEmpleadoChip('ADMIN', data['empleados_admin'] ?? 0, const Color(0xFF1976D2)),
                const SizedBox(width: 8),
                _rolEmpleadoChip('STAFF', data['empleados_staff'] ?? 0, const Color(0xFF388E3C)),
              ],
            ),
            if (rendimientoEmpleados.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Reservas por Empleado:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 8),
              ...rendimientoEmpleados.entries.take(3).map((entry) {
                final empleadoData = entry.value as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFF388E3C),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12))),
                      Text('${empleadoData['reservas'] ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticasFichajes(BuildContext context, Map<String, dynamic> data) {
    final horasMes       = (data['horas_trabajadas_mes'] as num?)?.toDouble() ?? 0.0;
    final activos        = data['empleados_con_fichaje_activo'] as int? ?? 0;
    final fichadosHoy    = data['empleados_fichados_hoy'] as int? ?? 0;
    final empleadoTop    = data['empleado_mas_horas_mes'] as String? ?? 'N/A';
    final horasPromedio  = (data['horas_promedio_empleado_mes'] as num?)?.toDouble() ?? 0.0;
    final fichajesMes    = data['fichajes_mes'] as int? ?? 0;
    final conSalida      = data['fichajes_con_salida_mes'] as int? ?? 0;
    final sinSalida      = fichajesMes > 0 ? (fichajesMes ~/ 2) - conSalida : 0;

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
                const Icon(Icons.access_time_filled, color: Color(0xFF00796B), size: 20),
                const SizedBox(width: 8),
                const Text('Control Horario (Fichajes)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                _infoBtn(
                  context,
                  'Control Horario',
                  '⏱️ Estadísticas calculadas a partir de los registros de fichaje '
                  '(entradas y salidas) del mes actual.\n\n'
                  '• Horas trabajadas: suma de todos los pares entrada→salida\n'
                  '• Activos ahora: empleados con entrada activa sin salida hoy\n'
                  '• Fichados hoy: empleados únicos que han fichado hoy\n'
                  '• Promedio horas/empleado: total de horas ÷ empleados con fichaje',
                ),
              ],
            ),
            const SizedBox(height: 14),
            // KPIs fila 1
            Row(
              children: [
                Expanded(child: _fichajeKpiCard(
                  context,
                  '${horasMes.toStringAsFixed(1)}h',
                  'Horas trabajadas (mes)',
                  Icons.timelapse,
                  const Color(0xFF00796B),
                )),
                const SizedBox(width: 10),
                Expanded(child: _fichajeKpiCard(
                  context,
                  '$activos',
                  'Activos ahora',
                  Icons.person_pin_circle,
                  activos > 0 ? const Color(0xFF2E7D32) : const Color(0xFF9E9E9E),
                )),
                const SizedBox(width: 10),
                Expanded(child: _fichajeKpiCard(
                  context,
                  '$fichadosHoy',
                  'Fichados hoy',
                  Icons.how_to_reg,
                  const Color(0xFF0288D1),
                )),
              ],
            ),
            const SizedBox(height: 10),
            // KPIs fila 2
            Row(
              children: [
                Expanded(child: _fichajeKpiCard(
                  context,
                  '${horasPromedio.toStringAsFixed(1)}h',
                  'Promedio / empleado',
                  Icons.bar_chart,
                  const Color(0xFF7B1FA2),
                )),
                const SizedBox(width: 10),
                Expanded(child: _fichajeKpiCard(
                  context,
                  '$fichajesMes',
                  'Registros del mes',
                  Icons.fingerprint,
                  const Color(0xFF1565C0),
                )),
                const SizedBox(width: 10),
                Expanded(child: _fichajeKpiCard(
                  context,
                  sinSalida > 0 ? '$sinSalida ⚠️' : '0 ✅',
                  'Sin salida registrada',
                  Icons.warning_amber_rounded,
                  sinSalida > 0 ? const Color(0xFFF57C00) : const Color(0xFF4CAF50),
                )),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.emoji_events, 'Más horas este mes', empleadoTop),
          ],
        ),
      ),
    );
  }

  Widget _fichajeKpiCard(BuildContext context, String valor, String titulo,
      IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(height: 6),
          Text(valor,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(titulo,
              style: TextStyle(fontSize: 9, color: color),
              textAlign: TextAlign.center,
              maxLines: 2),
        ],
      ),
    );
  }

  Widget _buildValoracionesFeedback(BuildContext context, Map<String, dynamic> data) {
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
                const Icon(Icons.star, color: Color(0xFFF57C00), size: 20),
                const SizedBox(width: 8),
                const Text('Valoraciones de Clientes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF57C00).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(data['valoracion_promedio'] ?? 0.0).toStringAsFixed(1)} ⭐',
                    style: const TextStyle(color: Color(0xFFF57C00), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _valoracionDistribucion('5⭐', data['valoraciones_5_estrellas'] ?? 0, const Color(0xFF4CAF50))),
                const SizedBox(width: 8),
                Expanded(child: _valoracionDistribucion('4⭐', data['valoraciones_4_estrellas'] ?? 0, const Color(0xFF8BC34A))),
                const SizedBox(width: 8),
                Expanded(child: _valoracionDistribucion('3⭐', data['valoraciones_3_estrellas'] ?? 0, const Color(0xFFFFC107))),
                const SizedBox(width: 8),
                Expanded(child: _valoracionDistribucion('2⭐', data['valoraciones_2_estrellas'] ?? 0, const Color(0xFFFF9800))),
                const SizedBox(width: 8),
                Expanded(child: _valoracionDistribucion('1⭐', data['valoraciones_1_estrella'] ?? 0, const Color(0xFFF44336))),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.reviews, 'Total reseñas', '${data['total_valoraciones'] ?? 0}'),
            _infoRow(Icons.new_releases, 'Este mes', '${data['valoraciones_mes'] ?? 0}'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoAdicionalCompleta(BuildContext context, Map<String, dynamic> data) {
    final horasPico = (data['horas_pico'] as List<dynamic>?)?.cast<String>() ?? [];
    final diaMasActivo = data['dia_mas_activo'] ?? 'N/A';
    final distribucionDias = data['distribucion_dias'] as Map<String, dynamic>? ?? {};

    return Column(
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Información Adicional', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 14),
                _infoRow(Icons.schedule, 'Horas pico', horasPico.join(', ')),
                _infoRow(Icons.today, 'Día más activo', diaMasActivo),
                _infoRow(Icons.payment, 'Método preferido', data['metodo_pago_preferido'] ?? 'Efectivo'),
                _infoRow(Icons.people, 'Cliente más valioso', data['cliente_mas_valioso'] ?? 'N/A'),
                _infoRow(Icons.euro, 'Valor promedio cliente', '€${(data['valor_promedio_cliente'] ?? 0).toStringAsFixed(0)}'),
              ],
            ),
          ),
        ),
        if (distribucionDias.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Actividad por Días', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 12),
                  ...distribucionDias.entries.map((entry) =>
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(entry.key.capitalize(), style: const TextStyle(fontSize: 12)),
                            ),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: (entry.value as int) / (distribucionDias.values.fold<int>(0, (sum, v) => sum + (v as int))),
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${entry.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Widget para mostrar estado sin datos
  Widget _buildEstadoSinDatos() {
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
      ),
    );
  }

  /// Widget para mostrar indicador de cache
  Widget _buildIndicadorCache(Map<String, dynamic> data) {
    final fechaCalculo = data['fecha_calculo'] as String?;
    if (fechaCalculo == null) return const SizedBox.shrink();

    final ultimaActualizacion = DateTime.tryParse(fechaCalculo.length > 23 ? fechaCalculo.substring(0, 23) : fechaCalculo) ?? DateTime.now();
    final diferencia = DateTime.now().difference(ultimaActualizacion);

    Color color;
    IconData icono;
    String mensaje;

    if (diferencia.inMinutes < 5) {
      color = const Color(0xFF4CAF50);
      icono = Icons.check_circle;
      mensaje = 'Datos actualizados hace ${diferencia.inMinutes} min';
    } else if (diferencia.inMinutes < 30) {
      color = Colors.orange;
      icono = Icons.schedule;
      mensaje = 'Datos de hace ${diferencia.inMinutes} min';
    } else {
      color = Colors.red;
      icono = Icons.warning;
      mensaje = 'Datos de hace ${diferencia.inHours}h ${diferencia.inMinutes % 60}min';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            mensaje,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
          if (diferencia.inMinutes > 30) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _cacheService.recalcularEstadisticas(widget.empresaId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Actualizar',
                  style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Widgets auxiliares
  Widget _metricaCardConInfo(BuildContext context, String titulo, String valor, IconData icono, Color color, String infoTexto) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icono, color: color, size: 16),
              GestureDetector(
                onTap: () => _mostrarInfoDialog(context, titulo, infoTexto),
                child: const Icon(Icons.info_outline, size: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(valor, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(titulo, style: TextStyle(fontSize: 10, color: color), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _metricaCompactaCard(String titulo, String valor, IconData icono, Color color) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icono, color: color, size: 18),
            const SizedBox(height: 6),
            Text(valor, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(titulo, style: TextStyle(fontSize: 10, color: color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _rolEmpleadoChip(String rol, int cantidad, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$rol: $cantidad',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _valoracionDistribucion(String estrella, int cantidad, Color color) {
    return Column(
      children: [
        Text(estrella, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('$cantidad', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _infoRow(IconData icono, String label, String valor) {
    return Padding(
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
    );
  }

  double _calcPct(dynamic actual, dynamic anterior) {
    final a = (actual as num?)?.toDouble() ?? 0;
    final b = (anterior as num?)?.toDouble() ?? 0;
    if (b == 0) return 0;
    return ((a - b) / b * 100);
  }
}

// Extension para capitalizar texto
extension StringCapitalize on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
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
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tráfico Web', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('empresas')
                        .doc(empresaId)
                        .collection('configuracion')
                        .doc('web_avanzada')
                        .get(),
                    builder: (_, snap) {
                      final dominio = (snap.data?.data()
                      as Map<String, dynamic>?)?['dominio_propio_url'] as String?;
                      return Text(
                        dominio != null && dominio.isNotEmpty ? dominio : 'Sin dominio configurado',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      );
                    },
                  ),
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
                      'El script JavaScript del footer de tu web '
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
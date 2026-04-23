import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constantes/constantes_app.dart';
import '../../../services/datos_prueba_fluixtech_service.dart';

/// Módulo exclusivo para la cuenta propietaria (FluxTech).
/// Muestra estadísticas globales de toda la plataforma:
///  - Empresas registradas / activas / nuevas este mes
///  - Ingresos totales y de este mes (facturas de fluixtech)
///  - Actividad de la plataforma (pedidos, facturas, valoraciones)
///  - Estadísticas web de fluixtech.com
///  - Suscripciones activas vs vencidas
class ModuloPropietario extends StatefulWidget {
  const ModuloPropietario({super.key});

  @override
  State<ModuloPropietario> createState() => _ModuloPropietarioState();
}

class _ModuloPropietarioState extends State<ModuloPropietario> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _cargando = true;
  bool _generandoDatos = false;
  _DatosPropietario _datos = _DatosPropietario.vacio();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() => _cargando = true);

    try {
      final datos = await _DatosPropietario.cargar(_db);
      if (mounted) setState(() { _datos = datos; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargar,
      child: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cabecera(),
                  const SizedBox(height: 16),
                  _seccionEmpresas(),
                  const SizedBox(height: 16),
                  _seccionIngresos(),
                  const SizedBox(height: 16),
                  _seccionActividad(),
                  const SizedBox(height: 16),
                  _seccionWeb(),
                  const SizedBox(height: 16),
                  _seccionSuscripciones(),
                  const SizedBox(height: 16),
                  _seccionHerramientasDev(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ── CABECERA ────────────────────────────────────────────────────────────────

  Widget _cabecera() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.rocket_launch, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '${ConstantesApp.nombrePropietario} — Panel de Plataforma',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ConstantesApp.webPropietaria,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_datos.totalEmpresas}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'empresas',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SECCIÓN EMPRESAS ───────────────────────────────────────────────────────

  Widget _seccionEmpresas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion(Icons.business, 'Empresas registradas'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _tarjetaKPI(
            '${_datos.totalEmpresas}',
            'Total',
            Icons.store,
            const Color(0xFF1976D2),
          )),
          const SizedBox(width: 10),
          Expanded(child: _tarjetaKPI(
            '${_datos.empresasNuevasMes}',
            'Este mes',
            Icons.add_business,
            const Color(0xFF2E7D32),
          )),
          const SizedBox(width: 10),
          Expanded(child: _tarjetaKPI(
            '${_datos.suscripcionesActivas}',
            'Activas',
            Icons.check_circle_outline,
            const Color(0xFF00796B),
          )),
        ]),
      ],
    );
  }

  // ── SECCIÓN INGRESOS ───────────────────────────────────────────────────────

  Widget _seccionIngresos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion(Icons.euro, 'Ingresos (FluxTech)'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _tarjetaKPI(
            '€${_datos.ingresosTotal.toStringAsFixed(0)}',
            'Total histórico',
            Icons.account_balance_wallet,
            const Color(0xFF7B1FA2),
          )),
          const SizedBox(width: 10),
          Expanded(child: _tarjetaKPI(
            '€${_datos.ingresosMes.toStringAsFixed(0)}',
            'Este mes',
            Icons.trending_up,
            const Color(0xFFE65100),
          )),
          const SizedBox(width: 10),
          Expanded(child: _tarjetaKPI(
            '${_datos.facturasPendientes}',
            'Facturas pend.',
            Icons.receipt_long,
            const Color(0xFFF57F17),
          )),
        ]),
        if (_datos.ultimasVentas.isNotEmpty) ...[
          const SizedBox(height: 12),
          _tarjetaContenido(
            titulo: '💳 Últimas ventas (Stripe)',
            child: Column(
              children: _datos.ultimasVentas.map((v) => _filaVenta(v)).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _filaVenta(Map<String, dynamic> venta) {
    final empresa = venta['empresa_cliente_id'] as String? ?? 'Desconocido';
    final total = (venta['total'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final paquete = venta['notas_cliente'] as String? ?? '';
    final fecha = venta['fecha_pedido'];
    String fechaStr = '';
    if (fecha is Timestamp) {
      final d = fecha.toDate();
      fechaStr = '${d.day}/${d.month}/${d.year}';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_cart, size: 18, color: Color(0xFF1976D2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empresa,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  paquete.length > 60 ? paquete.substring(0, 60) : paquete,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '€$total',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF2E7D32),
                ),
              ),
              Text(fechaStr, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  // ── SECCIÓN ACTIVIDAD ──────────────────────────────────────────────────────

  Widget _seccionActividad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion(Icons.analytics, 'Actividad en la plataforma (todas las empresas)'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _tarjetaKPI(
            '${_datos.totalPedidos}',
            'Pedidos totales',
            Icons.shopping_bag_outlined,
            const Color(0xFF1565C0),
          )),
          const SizedBox(width: 10),
          Expanded(child: _tarjetaKPI(
            '${_datos.totalFacturas}',
            'Facturas emitidas',
            Icons.receipt,
            const Color(0xFF6A1B9A),
          )),
          const SizedBox(width: 10),
          Expanded(child: _tarjetaKPI(
            '${_datos.totalValoraciones}',
            'Valoraciones',
            Icons.star_half,
            const Color(0xFFE65100),
          )),
        ]),
      ],
    );
  }

  // ── SECCIÓN WEB ────────────────────────────────────────────────────────────

  Widget _seccionWeb() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leer dominio dinámicamente desde configuración web
        StreamBuilder<DocumentSnapshot>(
          stream: _db
              .collection('empresas')
              .doc(ConstantesApp.empresaPropietariaId)
              .collection('configuracion')
              .doc('web_avanzada')
              .snapshots(),
          builder: (context, cfgSnap) {
            final dominio = (cfgSnap.data?.data() as Map<String, dynamic>?)?['dominio_propio_url']
                as String?;
            return _tituloSeccion(
              Icons.language,
              dominio != null && dominio.isNotEmpty
                  ? '$dominio — Tráfico web'
                  : 'Tráfico web',
            );
          },
        ),
        const SizedBox(height: 10),
        StreamBuilder<DocumentSnapshot>(
          stream: _db
              .collection('empresas')
              .doc(ConstantesApp.empresaPropietariaId)
              .collection('estadisticas')
              .doc('web_resumen')
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || !snap.data!.exists) {
              return _tarjetaContenido(
                titulo: '📊 Sin datos de tráfico web aún',
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Instala el script de Fluix CRM en tu web para ver las estadísticas aquí.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
              );
            }
            final d = snap.data!.data() as Map<String, dynamic>;
            final visitasTotales = d['visitas_totales'] ?? 0;
            final visitasMes = d['visitas_mes'] ?? 0;
            final ultimaVisita = d['ultima_visita'] as Timestamp?;
            String ultimaStr = 'Sin datos';
            if (ultimaVisita != null) {
              final dt = ultimaVisita.toDate();
              ultimaStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
            }
            return Column(
              children: [
                Row(children: [
                  Expanded(child: _tarjetaKPI(
                    '$visitasTotales',
                    'Visitas totales',
                    Icons.remove_red_eye,
                    const Color(0xFF0288D1),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _tarjetaKPI(
                    '$visitasMes',
                    'Este mes',
                    Icons.calendar_month,
                    const Color(0xFF00838F),
                  )),
                ]),
                const SizedBox(height: 8),
                _tarjetaContenido(
                  titulo: '🕐 Última visita registrada',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      ultimaStr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0288D1),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── SECCIÓN SUSCRIPCIONES ──────────────────────────────────────────────────

  Widget _seccionSuscripciones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion(Icons.card_membership, 'Estado de suscripciones'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _tarjetaKPI(
            '${_datos.suscripcionesActivas}',
            'Activas',
            Icons.check_circle,
            const Color(0xFF2E7D32),
          )),
          const SizedBox(width: 10),
          Expanded(child: _tarjetaKPI(
            '${_datos.suscripcionesVencen7}',
            'Vencen en 7d',
            Icons.warning_amber_rounded,
            const Color(0xFFF57F17),
          )),
          const SizedBox(width: 10),
          Expanded(child: _tarjetaKPI(
            '${_datos.suscripcionesVencidas}',
            'Vencidas',
            Icons.cancel_outlined,
            const Color(0xFFC62828),
          )),
        ]),
      ],
    );
  }

  // ── HELPERS UI ─────────────────────────────────────────────────────────────

  Widget _tituloSeccion(IconData icono, String texto) {
    return Row(
      children: [
        Icon(icono, size: 18, color: const Color(0xFF1976D2)),
        const SizedBox(width: 8),
        Text(
          texto,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A237E),
          ),
        ),
      ],
    );
  }

  Widget _tarjetaKPI(String valor, String etiqueta, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Icon(icono, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _tarjetaContenido({required String titulo, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
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
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  // ── HERRAMIENTAS DE DESARROLLO ──────────────────────────────────────────────

  Widget _seccionHerramientasDev() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion(Icons.developer_mode, 'Herramientas de Desarrollo'),
        const SizedBox(height: 10),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Genera datos de prueba realistas: 10 clientes, 30 empleados '
                  'con nóminas (Ene-Mar), facturas, gastos, reservas, valoraciones y pedidos.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _generandoDatos ? null : _generarDatosDePrueba,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _generandoDatos
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(_generandoDatos ? 'Generando...' : 'Generar datos prueba',
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _generandoDatos ? null : _limpiarDatosDePrueba,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text('Limpiar datos', style: TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _generarDatosDePrueba() async {
    setState(() => _generandoDatos = true);
    try {
      await DatosPruebaFluixtechService().generarTodo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Datos de prueba generados (10 clientes, 30 empleados, nóminas, facturas...)'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 4),
          ),
        );
        _cargar(); // Refrescar datos
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generandoDatos = false);
    }
  }

  Future<void> _limpiarDatosDePrueba() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Limpiar todos los datos de prueba?'),
        content: const Text('Se eliminarán clientes, empleados, nóminas, facturas, gastos, reservas y valoraciones de prueba.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar todo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _generandoDatos = true);
    try {
      await DatosPruebaFluixtechService().limpiarTodo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Datos de prueba eliminados'), backgroundColor: Colors.orange),
        );
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generandoDatos = false);
    }
  }
}

// ── MODELO DE DATOS ────────────────────────────────────────────────────────────

class _DatosPropietario {
  final int totalEmpresas;
  final int empresasNuevasMes;
  final int suscripcionesActivas;
  final int suscripcionesVencen7;
  final int suscripcionesVencidas;
  final double ingresosTotal;
  final double ingresosMes;
  final int facturasPendientes;
  final int totalPedidos;
  final int totalFacturas;
  final int totalValoraciones;
  final List<Map<String, dynamic>> ultimasVentas;

  const _DatosPropietario({
    required this.totalEmpresas,
    required this.empresasNuevasMes,
    required this.suscripcionesActivas,
    required this.suscripcionesVencen7,
    required this.suscripcionesVencidas,
    required this.ingresosTotal,
    required this.ingresosMes,
    required this.facturasPendientes,
    required this.totalPedidos,
    required this.totalFacturas,
    required this.totalValoraciones,
    required this.ultimasVentas,
  });

  factory _DatosPropietario.vacio() => const _DatosPropietario(
    totalEmpresas: 0,
    empresasNuevasMes: 0,
    suscripcionesActivas: 0,
    suscripcionesVencen7: 0,
    suscripcionesVencidas: 0,
    ingresosTotal: 0,
    ingresosMes: 0,
    facturasPendientes: 0,
    totalPedidos: 0,
    totalFacturas: 0,
    totalValoraciones: 0,
    ultimasVentas: [],
  );

  static Future<_DatosPropietario> cargar(FirebaseFirestore db) async {
    final ahora = DateTime.now();
    final inicioMes = DateTime(ahora.year, ahora.month, 1);
    final en7Dias = ahora.add(const Duration(days: 7));

    // 1. Total empresas
    final empresasSnap = await db.collection('empresas').get();
    final totalEmpresas = empresasSnap.docs.length;

    // 2. Empresas nuevas este mes
    int empresasNuevasMes = 0;
    int suscripcionesActivas = 0;
    int suscripcionesVencen7 = 0;
    int suscripcionesVencidas = 0;
    int totalPedidosAll = 0;
    int totalFacturasAll = 0;
    int totalValoracionesAll = 0;

    for (final doc in empresasSnap.docs) {
      // Fecha creación empresa
      final data = doc.data();
      final fechaCreacion = data['fecha_creacion'];
      if (fechaCreacion is Timestamp) {
        if (fechaCreacion.toDate().isAfter(inicioMes)) empresasNuevasMes++;
      }

      // Suscripciones
      try {
        final suscDoc = await doc.reference
            .collection('suscripcion')
            .doc('actual')
            .get();
        if (suscDoc.exists) {
          final estado = suscDoc.data()?['estado'] as String? ?? '';
          final fechaFin = suscDoc.data()?['fecha_fin'] as Timestamp?;
          if (estado == 'ACTIVA') {
            suscripcionesActivas++;
            if (fechaFin != null && fechaFin.toDate().isBefore(en7Dias)) {
              suscripcionesVencen7++;
            }
          } else if (estado == 'VENCIDA') {
            suscripcionesVencidas++;
          }
        }
      } catch (_) {}

      // Conteo actividad (pedidos, facturas, valoraciones) — solo conteo estimado
      try {
        final pedidos = await doc.reference.collection('pedidos').count().get();
        totalPedidosAll += pedidos.count ?? 0;
      } catch (_) {}
      try {
        final facturas = await doc.reference.collection('facturas').count().get();
        totalFacturasAll += facturas.count ?? 0;
      } catch (_) {}
      try {
        final vals = await doc.reference.collection('valoraciones').count().get();
        totalValoracionesAll += vals.count ?? 0;
      } catch (_) {}
    }

    // 3. Ingresos de fluixtech (facturas pagadas y pendientes)
    double ingresosTotal = 0;
    double ingresosMes = 0;
    int facturasPendientes = 0;

    try {
      final facturasSnap = await db
          .collection('empresas')
          .doc(ConstantesApp.empresaPropietariaId)
          .collection('facturas')
          .get();

      for (final f in facturasSnap.docs) {
        final fd = f.data();
        final total = (fd['total'] as num?)?.toDouble() ?? 0;
        final estado = fd['estado'] as String? ?? '';
        final fecha = fd['fecha_emision'] as Timestamp?;

        if (estado == 'pendiente') facturasPendientes++;
        ingresosTotal += total;
        if (fecha != null && fecha.toDate().isAfter(inicioMes)) {
          ingresosMes += total;
        }
      }
    } catch (_) {}

    // 4. Últimas ventas (pedidos con stripe_session_id)
    List<Map<String, dynamic>> ultimasVentas = [];
    try {
      final pedidosSnap = await db
          .collection('empresas')
          .doc(ConstantesApp.empresaPropietariaId)
          .collection('pedidos')
          .where('stripe_session_id', isNull: false)
          .orderBy('fecha_pedido', descending: true)
          .limit(5)
          .get();

      ultimasVentas = pedidosSnap.docs.map((d) => d.data()).toList();
    } catch (_) {
      // Si no hay índice aún, cargamos sin filtro Stripe
      try {
        final pedidosSnap = await db
            .collection('empresas')
            .doc(ConstantesApp.empresaPropietariaId)
            .collection('pedidos')
            .orderBy('fecha_pedido', descending: true)
            .limit(5)
            .get();
        ultimasVentas = pedidosSnap.docs.map((d) => d.data()).toList();
      } catch (_) {}
    }

    return _DatosPropietario(
      totalEmpresas: totalEmpresas,
      empresasNuevasMes: empresasNuevasMes,
      suscripcionesActivas: suscripcionesActivas,
      suscripcionesVencen7: suscripcionesVencen7,
      suscripcionesVencidas: suscripcionesVencidas,
      ingresosTotal: ingresosTotal,
      ingresosMes: ingresosMes,
      facturasPendientes: facturasPendientes,
      totalPedidos: totalPedidosAll,
      totalFacturas: totalFacturasAll,
      totalValoraciones: totalValoracionesAll,
      ultimasVentas: ultimasVentas,
    );
  }
}


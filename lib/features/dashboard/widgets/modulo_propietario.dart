import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/constantes/constantes_app.dart';
import '../../../core/config/planes_config.dart';
import '../../../services/datos_prueba_fluixtech_service.dart';
import '../pantallas/gestion_negocios_screen.dart';
import '../pantallas/pantalla_dashboard.dart';
import '../../../services/demo_cuenta_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planeag_flutter/features/fichajes/servicios/fichaje_demo_data.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';

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
  bool _cargandoDemo = false;
  bool _migracionNazari = false;
  String? _resultadoNazari;
  String? _errorCarga;
  _DatosPropietario _datos = _DatosPropietario.vacio();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });

    try {
      final datos = await _DatosPropietario.cargar(_db);
      if (mounted) setState(() { _datos = datos; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _errorCarga = e.toString(); });
    }
  }

  Future<void> _crearDatosDemo() async {
    if (_generandoDatos) return;
    
    // Confirmar con el usuario
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear datos de demo'),
        content: const Text(
          '¿Deseas crear datos de demostración del sistema de fichajes?\n\n'
          'Esto creará:\n'
          '• 5 empleados con PINs (1234, 5678, 9012, 3456, 7890)\n'
          '• Fichajes de ejemplo con diferentes estados\n'
          '• Ejemplo de corrección con audit trail\n\n'
          'Perfecto para probar el sistema.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
            child: const Text('Crear datos demo', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _generandoDatos = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay usuario autenticado');

      await FichajeDemoData.crearTodosDatosDemo(
        empresaId: ConstantesApp.empresaPropietariaId,
        adminUid: user.uid,
      );

      if (mounted) {
        FluxToast.exito(context, 'Datos demo creados correctamente');
        
        // Mostrar diálogo con instrucciones
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('✅ Datos demo creados'),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('PINs de empleados:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• María García: 1234'),
                  Text('• Juan López: 5678'),
                  Text('• Ana Torres: 9012'),
                  Text('• Carlos Sánchez: 3456'),
                  Text('• Laura Fernández: 7890'),
                  SizedBox(height: 16),
                  Text('Ahora puedes:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('1. Pulsar el botón de Fichajes ⏰ en el AppBar'),
                  Text('2. Ver el dashboard de gestión'),
                  Text('3. Probar fichaje con cualquier PIN'),
                  Text('4. Exportar CSV'),
                  Text('5. Ver historial de correcciones'),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        FluxToast.error(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _generandoDatos = false);
    }
  }

  @override
  // ── Colores del dashboard (misma paleta) ──────────────────────────────────
  static const _bg     = Color(0xFFF1F5F9);
  static const _cardBg = Colors.white;
  static const _border = Color(0xFFE5E7EB);
  static const _text   = Color(0xFF1F2937);
  static const _sub    = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _bg,
      child: RefreshIndicator(
        onRefresh: _cargar,
        child: _cargando
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED)))
            : _errorCarga != null
                ? _buildError(_errorCarga!)
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // ── Cabecera estilo dashboard ──────────────────────────
                      Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Panel de Plataforma',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _text)),
                          const Text('Métricas globales de Fluix — ${ConstantesApp.webPropietaria}',
                              style: TextStyle(fontSize: 12, color: _sub)),
                        ])),
                        TextButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh_rounded, size: 15),
                          label: const Text('Actualizar', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFF7C3AED)),
                        ),
                      ]),
                      const SizedBox(height: 16),

                      // ── Strip KPI 1: Plataforma ────────────────────────────
                      _kpiStrip([
                        _kd(Icons.business_outlined,       const Color(0xFFDBEAFE), const Color(0xFF3B82F6), 'Empresas',          '${_datos.totalEmpresas}',          '${_datos.empresasNuevasMes} nuevas este mes'),
                        _kd(Icons.account_balance_wallet,  const Color(0xFFF3E8FF), const Color(0xFF7C3AED), 'MRR',               '€${_datos.mrr.toStringAsFixed(0)}','por mes recurrente'),
                        _kd(Icons.trending_up_rounded,     const Color(0xFFDCFCE7), const Color(0xFF22C55E), 'ARR',               '€${(_datos.mrr*12).toStringAsFixed(0)}','ingresos anuales'),
                        _kd(Icons.check_circle_outline,    const Color(0xFFDCFCE7), const Color(0xFF22C55E), 'Suscrip. activas',  '${_datos.suscripcionesActivas}',   'empresas pagando'),
                        _kd(Icons.warning_amber_rounded,   const Color(0xFFFEF3C7), const Color(0xFFF59E0B), 'Vencen en 7d',     '${_datos.suscripcionesVencen7}',   'renovar pronto'),
                        _kd(Icons.cancel_outlined,         const Color(0xFFFFE4E6), const Color(0xFFEF4444), 'Vencidas',         '${_datos.suscripcionesVencidas}',   'sin suscripción'),
                      ]),
                      const SizedBox(height: 12),

                      // ── Strip KPI 2: Actividad ─────────────────────────────
                      _kpiStrip([
                        _kd(Icons.shopping_bag_outlined,   const Color(0xFFDBEAFE), const Color(0xFF3B82F6), 'Pedidos totales',   '${_datos.totalPedidos}',           'todas las empresas'),
                        _kd(Icons.receipt_rounded,         const Color(0xFFF3E8FF), const Color(0xFF7C3AED), 'Facturas emitidas', '${_datos.totalFacturas}',           'historial total'),
                        _kd(Icons.star_half_rounded,       const Color(0xFFFEF3C7), const Color(0xFFF59E0B), 'Valoraciones',      '${_datos.totalValoraciones}',       'todas las reseñas'),
                        _kd(Icons.event_available_rounded, const Color(0xFFDCFCE7), const Color(0xFF22C55E), 'Reservas',          '${_datos.totalReservas}',           'historial total'),
                        _kd(Icons.badge_rounded,           const Color(0xFFDBEAFE), const Color(0xFF3B82F6), 'Empleados',         '${_datos.totalUsuarios}',           'en toda la plataforma'),
                        _kd(Icons.people_outlined,         const Color(0xFFDCFCE7), const Color(0xFF14B8A6), 'Usuarios B2C',      '${_datos.usuariosB2CTotal}',        '${_datos.usuariosB2CNuevosMes} nuevos este mes'),
                      ]),
                      const SizedBox(height: 16),

                      // ── Contenido 2 columnas ──────────────────────────────
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Izquierda
                        Expanded(flex: 3, child: Column(children: [
                          _ingresoCard(),
                          const SizedBox(height: 12),
                          _actividadCard(),
                          const SizedBox(height: 12),
                          _metricasB2CCard(),
                        ])),
                        const SizedBox(width: 14),
                        // Derecha
                        Expanded(flex: 2, child: Column(children: [
                          _suscripcionesCard(),
                          const SizedBox(height: 12),
                          _fichajesCard(),
                          const SizedBox(height: 12),
                          _webCard(),
                          const SizedBox(height: 12),
                          _negociosPublicosCard(context),
                          const SizedBox(height: 12),
                          _herramientasDevCard(context),
                          const SizedBox(height: 12),
                          _nazariCard(context),
                        ])),
                      ]),
                    ]),
                  ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS VISUALES — estilo dashboard
  // ══════════════════════════════════════════════════════════════════════════

  // Datos para un KPI tile
  ({IconData icon, Color bg, Color color, String label, String valor, String sub}) _kd(
      IconData icon, Color bg, Color color, String label, String valor, String sub) =>
      (icon: icon, bg: bg, color: color, label: label, valor: valor, sub: sub);

  // Fila de KPI tiles (hasta 6)
  Widget _kpiStrip(List<({IconData icon, Color bg, Color color, String label, String valor, String sub})> items) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items.expand((e) => [
            Expanded(child: _kpiTile(e.icon, e.bg, e.color, e.label, e.valor, e.sub)),
            if (e != items.last) const SizedBox(width: 10),
          ]).toList()),
    );
  }

  Widget _kpiTile(IconData icon, Color bgIcon, Color color, String label, String valor, String sub2) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 38, height: 38,
              decoration: BoxDecoration(color: bgIcon, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10, color: _sub), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _text)),
            Text(sub2, style: TextStyle(fontSize: 9.5, color: color), overflow: TextOverflow.ellipsis),
          ])),
        ]),
      );

  // Card contenedor estilo dashboard
  Widget _dashCard(String title, IconData icon, Color iconColor, List<Widget> children, {Widget? action}) =>
      Container(
        width: double.infinity,
        decoration: BoxDecoration(color: _cardBg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(width: 24, height: 24,
                  decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Icon(icon, size: 14, color: iconColor)),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 13,
                  fontWeight: FontWeight.w700, color: _text))),
              if (action != null) action,
            ]),
          ),
          const Divider(height: 1, color: _border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ]),
      );

  // Fila de stat dentro de una card
  Widget _statRow(IconData icon, Color color, String label, String valor) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Container(width: 30, height: 30,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 14, color: color)),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: _sub))),
      Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text)),
    ]),
  );

  // ── SECCIÓN INGRESOS ───────────────────────────────────────────────────────

  Widget _ingresoCard() => _dashCard(
    'Ingresos — FluxTech', Icons.euro_rounded, const Color(0xFF7C3AED),
    [
      _statRow(Icons.account_balance_wallet_outlined, const Color(0xFF7C3AED),
          'MRR (mensual recurrente)', '€${_datos.mrr.toStringAsFixed(0)}/mes'),
      _statRow(Icons.trending_up_rounded, const Color(0xFF22C55E),
          'ARR (anual estimado)', '€${(_datos.mrr * 12).toStringAsFixed(0)}'),
      _statRow(Icons.receipt_long_outlined, const Color(0xFFEF4444),
          'Facturas pendientes', '${_datos.facturasPendientes}'),
      if (_datos.ultimasVentas.isNotEmpty) ...[
        const SizedBox(height: 6),
        const Text('Últimas ventas', style: TextStyle(fontSize: 11,
            fontWeight: FontWeight.w700, color: _sub)),
        const SizedBox(height: 6),
        ..._datos.ultimasVentas.map(_ventaRow),
      ],
    ],
  );

  Widget _ventaRow(Map<String, dynamic> venta) {
    final empresa = venta['empresa_cliente_id'] as String? ?? 'Cliente';
    final total   = (venta['total'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final fecha   = venta['fecha_pedido'];
    String fechaStr = '';
    if (fecha is Timestamp) {
      final d = fecha.toDate();
      fechaStr = '${d.day}/${d.month}/${d.year}';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 28, height: 28,
            decoration: BoxDecoration(color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7)),
            child: const Icon(Icons.shopping_cart_outlined, size: 13, color: Color(0xFF3B82F6))),
        const SizedBox(width: 8),
        Expanded(child: Text(empresa, style: const TextStyle(fontSize: 12, color: _text),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('€$total', style: const TextStyle(fontSize: 12,
              fontWeight: FontWeight.w700, color: Color(0xFF22C55E))),
          Text(fechaStr, style: const TextStyle(fontSize: 9.5, color: _sub)),
        ]),
      ]),
    );
  }

  // ── ACTIVIDAD GLOBAL ───────────────────────────────────────────────────────

  Widget _actividadCard() => _dashCard(
    'Actividad en la plataforma', Icons.analytics_outlined, const Color(0xFF3B82F6),
    [
      _statRow(Icons.shopping_bag_outlined, const Color(0xFF3B82F6), 'Pedidos totales', '${_datos.totalPedidos}'),
      _statRow(Icons.receipt_outlined,      const Color(0xFF7C3AED), 'Facturas emitidas', '${_datos.totalFacturas}'),
      _statRow(Icons.star_half_rounded,     const Color(0xFFF59E0B), 'Valoraciones',    '${_datos.totalValoraciones}'),
      _statRow(Icons.event_available_rounded,const Color(0xFF22C55E),'Reservas totales','${_datos.totalReservas}'),
      _statRow(Icons.badge_rounded,         const Color(0xFF14B8A6), 'Empleados (total)','${_datos.totalUsuarios}'),
      if (_datos.totalEmpresas > 0)
        _statRow(Icons.bar_chart_rounded, const Color(0xFF6B7280), 'Reservas / empresa',
            '${(_datos.totalReservas / _datos.totalEmpresas).toStringAsFixed(1)}'),
    ],
  );

  // ── MÉTRICAS B2C ───────────────────────────────────────────────────────────

  Widget _metricasB2CCard() => _dashCard(
    'Métricas B2C — App Clientes', Icons.phone_android_outlined, const Color(0xFF0EA5E9),
    [
      _statRow(Icons.people_outline, const Color(0xFF0EA5E9), 'Usuarios totales', '${_datos.usuariosB2CTotal}'),
      _statRow(Icons.person_add_outlined, const Color(0xFF22C55E), 'Nuevos este mes', '${_datos.usuariosB2CNuevosMes}'),
      _statRow(Icons.person_add_outlined, const Color(0xFF14B8A6), 'Nuevos esta semana', '${_datos.usuariosB2CNuevosSemana}'),
      const Divider(height: 16, color: _border),
      _statRow(Icons.today_outlined,       const Color(0xFF0EA5E9), 'DAU (24h)',     '${_datos.usuariosActivosDia}'),
      _statRow(Icons.calendar_month_outlined, const Color(0xFF7C3AED), 'MAU (30d)',  '${_datos.usuariosActivosMes}'),
      const Divider(height: 16, color: _border),
      _statRow(Icons.event_available_outlined, const Color(0xFF22C55E), 'Reservas B2C hoy',    '${_datos.reservasB2CHoy}'),
      _statRow(Icons.date_range_outlined,      const Color(0xFF3B82F6), 'Reservas B2C semana', '${_datos.reservasB2CSemana}'),
      _statRow(Icons.calendar_today_outlined,  const Color(0xFF7C3AED), 'Reservas B2C mes',    '${_datos.reservasB2CMes}'),
      const Divider(height: 16, color: _border),
      _statRow(Icons.star_rounded,  const Color(0xFFF59E0B), 'Valoraciones total', '${_datos.valoracionesB2CTotal}'),
      _statRow(Icons.star_half_rounded, const Color(0xFFF59E0B), 'Media estrellas',
          _datos.valoracionesB2CTotal > 0 ? _datos.valoracionesB2CMedia.toStringAsFixed(1) : '—'),
      const Divider(height: 16, color: _border),
      _statRow(Icons.flash_on_rounded, const Color(0xFFEC4899), 'Flash slots creados', '${_datos.flashSlotsCreados}'),
      _statRow(Icons.check_rounded,    const Color(0xFF22C55E), 'Flash slots reservados', '${_datos.flashSlotsReservados}'),
    ],
  );

  // ── SUSCRIPCIONES ──────────────────────────────────────────────────────────

  Widget _suscripcionesCard() => _dashCard(
    'Estado de suscripciones', Icons.card_membership_outlined, const Color(0xFF22C55E),
    [
      _statRow(Icons.check_circle_outline, const Color(0xFF22C55E), 'Activas',       '${_datos.suscripcionesActivas}'),
      _statRow(Icons.warning_amber_rounded, const Color(0xFFF59E0B), 'Vencen en 7d', '${_datos.suscripcionesVencen7}'),
      _statRow(Icons.cancel_outlined, const Color(0xFFEF4444), 'Vencidas',           '${_datos.suscripcionesVencidas}'),
      const SizedBox(height: 6),
      if (_datos.suscripcionesActivas + _datos.suscripcionesVencidas > 0)
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _datos.suscripcionesActivas /
                (_datos.suscripcionesActivas + _datos.suscripcionesVencidas),
            minHeight: 6,
            backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
          ),
        ),
    ],
  );

  // ── FICHAJES GLOBALES ──────────────────────────────────────────────────────

  Widget _fichajesCard() => _dashCard(
    'Control horario global', Icons.access_time_filled_rounded, const Color(0xFF14B8A6),
    [
      StreamBuilder<QuerySnapshot>(
        stream: _db.collection('empresas').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return FutureBuilder<Map<String, int>>(
            future: _calcularFichajesGlobal(snap.data!.docs),
            builder: (_, fSnap) {
              final activos       = fSnap.data?['activos'] ?? 0;
              final fichadosHoy   = fSnap.data?['fichados_hoy'] ?? 0;
              final fichajesMes   = fSnap.data?['fichajes_mes'] ?? 0;
              return Column(children: [
                _statRow(Icons.person_pin_circle_outlined, const Color(0xFF22C55E), 'Activos ahora', '$activos'),
                _statRow(Icons.how_to_reg_outlined,       const Color(0xFF0EA5E9), 'Fichados hoy',   '$fichadosHoy'),
                _statRow(Icons.fingerprint_rounded,        const Color(0xFF14B8A6), 'Fichajes mes',   '$fichajesMes'),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _generandoDatos ? null : _crearDatosDemo,
                    icon: const Icon(Icons.add_circle_outline, size: 14),
                    label: Text(_generandoDatos ? 'Creando...' : 'Crear datos demo',
                        style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF14B8A6),
                      side: const BorderSide(color: Color(0xFF14B8A6)),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ]);
            },
          );
        },
      ),
    ],
  );

  // ── TRÁFICO WEB ────────────────────────────────────────────────────────────

  Widget _webCard() => _dashCard(
    'Tráfico web', Icons.language_outlined, const Color(0xFF0EA5E9),
    [
      StreamBuilder<DocumentSnapshot>(
        stream: _db
            .collection('empresas').doc(ConstantesApp.empresaPropietariaId)
            .collection('estadisticas').doc('web_resumen').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return Text('Sin datos de tráfico aún.\nInstala el script de Fluix en tu web.',
                style: const TextStyle(fontSize: 12, color: _sub));
          }
          final d = snap.data!.data() as Map<String, dynamic>;
          final visitasTotales = d['visitas_totales'] ?? 0;
          final visitasMes     = d['visitas_mes'] ?? 0;
          final ultimaVisita   = d['ultima_visita'] as Timestamp?;
          String ultimaStr = 'Sin datos';
          if (ultimaVisita != null) {
            final dt = ultimaVisita.toDate();
            ultimaStr = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2,'0')}';
          }
          return Column(children: [
            _statRow(Icons.remove_red_eye_outlined, const Color(0xFF0EA5E9), 'Visitas totales', '$visitasTotales'),
            _statRow(Icons.calendar_month_outlined, const Color(0xFF14B8A6), 'Este mes',        '$visitasMes'),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.schedule_outlined, size: 12, color: _sub),
              const SizedBox(width: 6),
              Expanded(child: Text('Última visita: $ultimaStr',
                  style: const TextStyle(fontSize: 10.5, color: _sub))),
            ]),
          ]);
        },
      ),
    ],
  );

  // ── NEGOCIOS PÚBLICOS ──────────────────────────────────────────────────────

  Widget _negociosPublicosCard(BuildContext context) => _dashCard(
    'Negocios Públicos — B2C', Icons.store_outlined, const Color(0xFF22C55E),
    [
      StreamBuilder<QuerySnapshot>(
        stream: _db.collection('negocios_publicos').snapshots(),
        builder: (context, snapshot) {
          final total   = snapshot.data?.docs.length ?? 0;
          final activos = snapshot.data?.docs
              .where((d) => (d.data() as Map)['activo'] == true).length ?? 0;
          final sinFoto = snapshot.data?.docs.where((d) {
            final foto = (d.data() as Map)['fotoUrl'] as String?;
            return foto == null || foto.isEmpty;
          }).length ?? 0;
          return Column(children: [
            _statRow(Icons.store_rounded, const Color(0xFF3B82F6), 'Total negocios', '$total'),
            _statRow(Icons.check_circle_outline, const Color(0xFF22C55E), 'Activos', '$activos'),
            if (sinFoto > 0)
              _statRow(Icons.image_not_supported_outlined, const Color(0xFFF59E0B), 'Sin foto', '$sinFoto'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const GestionNegociosScreen())),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Gestionar', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const GestionNegociosScreen(abrirCreacion: true))),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Nuevo', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF22C55E),
                  side: const BorderSide(color: Color(0xFF22C55E)),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _cargandoDemo ? null : _iniciarSesionDemo,
                icon: _cargandoDemo
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C3AED)))
                    : const Icon(Icons.play_circle_outline, size: 14),
                label: Text(_cargandoDemo ? 'Cargando...' : 'Probar cuenta demo',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF7C3AED),
                  side: const BorderSide(color: Color(0xFF7C3AED)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]);
        },
      ),
    ],
  );

  // ── HERRAMIENTAS DEV ───────────────────────────────────────────────────────

  Widget _herramientasDevCard(BuildContext context) => _dashCard(
    'Herramientas de Desarrollo', Icons.developer_mode_rounded, const Color(0xFFEF4444),
    [
      const Text(
        'Genera datos de prueba realistas: 10 clientes, 30 empleados con nóminas, '
        'facturas, gastos, reservas, valoraciones y pedidos.',
        style: TextStyle(fontSize: 11.5, color: _sub, height: 1.4),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: FilledButton.icon(
          onPressed: _generandoDatos ? null : _generarDatosDePrueba,
          icon: _generandoDatos
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.auto_awesome_rounded, size: 14),
          label: Text(_generandoDatos ? 'Generando...' : 'Generar datos',
              style: const TextStyle(fontSize: 12)),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            padding: const EdgeInsets.symmetric(vertical: 9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        )),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _generandoDatos ? null : _limpiarDatosDePrueba,
          icon: const Icon(Icons.delete_sweep_outlined, size: 14),
          label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFEF4444),
            side: const BorderSide(color: Color(0xFFEF4444)),
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    ],
  );

  // ── MIGRACIÓN NAZARÍ ──────────────────────────────────────────────────────

  Future<void> _migrarNazari(String tipo) async {
    if (_migracionNazari) return;
    setState(() { _migracionNazari = true; _resultadoNazari = null; });
    try {
      final res = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('migrarDatosNazariDesdeWeb')
          .call({'tipo': tipo});
      final data = res.data as Map;
      final libros       = data['libros']       as int? ?? 0;
      final entrevistas  = data['entrevistas']  as int? ?? 0;
      final errores      = data['errores']      as int? ?? 0;
      setState(() {
        _resultadoNazari = tipo == 'libros'
            ? '✅ $libros libros migrados a catálogo web'
            : tipo == 'entrevistas'
                ? '✅ $entrevistas entrevistas importadas'
                : '✅ $libros libros + $entrevistas entrevistas'
                    '${errores > 0 ? ' · $errores errores' : ''}';
      });
    } catch (e) {
      setState(() => _resultadoNazari = '❌ Error: $e');
    } finally {
      if (mounted) setState(() => _migracionNazari = false);
    }
  }

  Widget _nazariCard(BuildContext context) {
    const nazariColor = Color(0xFF6B1E2A);
    return _dashCard(
      'Editorial Nazarí — Datos web', Icons.import_contacts_rounded, nazariColor,
      [
        const Text(
          'Sincroniza el catálogo de libros y las entrevistas de prensa '
          'desde la web al módulo de la app.',
          style: TextStyle(fontSize: 11.5, color: _sub, height: 1.4),
        ),
        if (_resultadoNazari != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: _resultadoNazari!.startsWith('✅')
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_resultadoNazari!,
                style: TextStyle(
                    fontSize: 11.5,
                    color: _resultadoNazari!.startsWith('✅')
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB91C1C),
                    fontWeight: FontWeight.w600)),
          ),
        ],
        const SizedBox(height: 10),
        if (_migracionNazari)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(strokeWidth: 2)),
          ))
        else ...[
          Row(children: [
            Expanded(child: FilledButton.icon(
              onPressed: () => _migrarNazari('libros'),
              icon: const Icon(Icons.library_books_rounded, size: 13),
              label: const Text('Libros', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: nazariColor,
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )),
            const SizedBox(width: 6),
            Expanded(child: FilledButton.icon(
              onPressed: () => _migrarNazari('entrevistas'),
              icon: const Icon(Icons.mic_rounded, size: 13),
              label: const Text('Entrevistas', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF374151),
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )),
          ]),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _migrarNazari('todo'),
              icon: const Icon(Icons.sync_rounded, size: 14),
              label: const Text('Sincronizar todo', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: nazariColor,
                side: const BorderSide(color: Color(0xFF6B1E2A)),
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── CABECERA (mantenida solo para _buildError) ─────────────────────────────

  Widget _buildError(String error) {
    final esPermisos = error.contains('permission') ||
        error.contains('PERMISSION_DENIED') ||
        error.contains('Missing or insufficient');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              esPermisos ? Icons.lock_outline : Icons.error_outline,
              size: 48,
              color: esPermisos ? const Color(0xFFF57F17) : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              esPermisos
                  ? 'Sin permisos para leer datos globales'
                  : 'Error al cargar datos',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (esPermisos)
              const Text(
                'Asegúrate de que tu usuario tiene el campo "es_plataforma_admin: true" en Firestore (colección usuarios).',
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              )
            else
              Text(
                error,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _cargar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _cabeceraObsolete() {
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
            '€${_datos.mrr.toStringAsFixed(0)}/mes',
            'MRR (recurrente)',
            Icons.account_balance_wallet,
            const Color(0xFF7B1FA2),
          )),
          const SizedBox(width: 10),
          Expanded(child: _tarjetaKPI(
            '€${(_datos.mrr * 12).toStringAsFixed(0)}',
            'ARR (anual)',
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
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _tarjetaKPI(
            '${_datos.totalReservas}',
            'Reservas totales',
            Icons.event_available,
            const Color(0xFF00838F),
          )),
          const SizedBox(width: 10),
          Expanded(child: _tarjetaKPI(
            '${_datos.totalUsuarios}',
            'Empleados totales',
            Icons.badge,
            const Color(0xFF388E3C),
          )),
          const SizedBox(width: 10),
          Expanded(child: _tarjetaKPI(
            _datos.totalEmpresas > 0
                ? '${(_datos.totalReservas / _datos.totalEmpresas).toStringAsFixed(0)}'
                : '0',
            'Reservas / empresa',
            Icons.bar_chart,
            const Color(0xFF7B1FA2),
          )),
        ]),
      ],
    );
  }

  // ── SECCIÓN FICHAJES ───────────────────────────────────────────────────────

  Widget _seccionFichajes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion(Icons.access_time_filled, 'Control horario (global plataforma)'),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: _db.collection('empresas').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return FutureBuilder<Map<String, int>>(
              future: _calcularFichajesGlobal(snap.data!.docs),
              builder: (ctx, fSnap) {
                final activos = fSnap.data?['activos'] ?? 0;
                final fichadosHoy = fSnap.data?['fichados_hoy'] ?? 0;
                final totalFichajesMes = fSnap.data?['fichajes_mes'] ?? 0;
                return Column(
                  children: [
                    Row(children: [
                      Expanded(child: _tarjetaKPI(
                        '$activos',
                        'Activos ahora',
                        Icons.person_pin_circle,
                        activos > 0 ? const Color(0xFF2E7D32) : const Color(0xFF9E9E9E),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _tarjetaKPI(
                        '$fichadosHoy',
                        'Fichados hoy',
                        Icons.how_to_reg,
                        const Color(0xFF0288D1),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _tarjetaKPI(
                        '$totalFichajesMes',
                        'Fichajes del mes',
                        Icons.fingerprint,
                        const Color(0xFF1565C0),
                      )),
                    ]),
                    const SizedBox(height: 12),
                    // Botón para crear datos de demo
                    ElevatedButton.icon(
                      onPressed: _generandoDatos ? null : _crearDatosDemo,
                      icon: _generandoDatos
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_circle),
                      label: Text(_generandoDatos ? 'Creando...' : 'Crear datos demo de fichajes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<Map<String, int>> _calcularFichajesGlobal(
      List<QueryDocumentSnapshot> empresas) async {
    int activos = 0;
    int fichadosHoy = 0;
    int fichajesMes = 0;

    final futures = empresas.map((doc) async {
      try {
        final cacheDoc = await doc.reference
            .collection('cache')
            .doc('estadisticas')
            .get();
        if (cacheDoc.exists) {
          final d = cacheDoc.data()!;
          activos += (d['empleados_con_fichaje_activo'] as int? ?? 0);
          fichadosHoy += (d['empleados_fichados_hoy'] as int? ?? 0);
          fichajesMes += (d['fichajes_mes'] as int? ?? 0);
        }
      } catch (_) {}
    });
    await Future.wait(futures);

    return {
      'activos': activos,
      'fichados_hoy': fichadosHoy,
      'fichajes_mes': fichajesMes,
    };
  }

  // ── SECCIÓN WEB ────────────────────────────────────────────────────────────

  Widget _seccionWeb() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<DocumentSnapshot>(
          stream: _db
              .collection('empresas')
              .doc(ConstantesApp.empresaPropietariaId)
              .collection('configuracion')
              .doc('web_avanzada')
              .snapshots(),
          builder: (context, cfgSnap) {
            final dominio =
            (cfgSnap.data?.data() as Map<String, dynamic>?)?['dominio_propio_url']
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
              ultimaStr =
              '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
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

  // ── SECCIÓN NEGOCIOS PÚBLICOS ──────────────────────────────────────────────

  Widget _seccionNegociosPublicos(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion(Icons.store, 'Negocios Públicos (B2C)'),
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
                  'Gestiona los negocios visibles en la app de clientes finales. '
                      'Puedes subir fotos, editar información y activar/desactivar negocios.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('negocios_publicos').snapshots(),
                  builder: (context, snapshot) {
                    final total = snapshot.data?.docs.length ?? 0;
                    final activos = snapshot.data?.docs
                        .where((d) => (d.data() as Map)['activo'] == true)
                        .length ??
                        0;
                    final sinFoto = snapshot.data?.docs.where((d) {
                      final data = d.data() as Map;
                      final foto = data['fotoUrl'] as String?;
                      return foto == null || foto.isEmpty;
                    }).length ??
                        0;

                    return Row(
                      children: [
                        Expanded(
                          child: _miniKPI('$total', 'Total', Icons.store,
                              const Color(0xFF1976D2)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _miniKPI('$activos', 'Activos',
                              Icons.check_circle, const Color(0xFF2E7D32)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _miniKPI(
                            '$sinFoto',
                            'Sin foto',
                            Icons.image_not_supported,
                            sinFoto > 0
                                ? const Color(0xFFF57F17)
                                : const Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const GestionNegociosScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Gestionar Negocios',
                            style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GestionNegociosScreen(
                              abrirCreacion: true,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add_business, size: 18),
                      label: const Text('Nuevo'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _cargandoDemo ? null : _iniciarSesionDemo,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00FFC8)),
                      foregroundColor: const Color(0xFF00FFC8),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _cargandoDemo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF00FFC8)))
                        : const Icon(Icons.play_circle_outline, size: 18),
                    label: Text(
                      _cargandoDemo ? 'Cargando demo...' : 'Probar cuenta demo',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _iniciarSesionDemo() async {
    if (!mounted) return;
    setState(() => _cargandoDemo = true);
    try {
      await DemoCuentaService().loginComoDemo();
      if (!mounted) return;
      // rootNavigator: true para reemplazar toda la pila, incluyendo el StreamBuilder raíz
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PantallaDashboard()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      FluxToast.error(context, 'Error al iniciar demo: $e');
    } finally {
      if (mounted) setState(() => _cargandoDemo = false);
    }
  }

  Widget _miniKPI(String valor, String etiqueta, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), // CORREGIDO: withOpacity → withValues
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(height: 4),
          Text(valor,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(etiqueta, style: TextStyle(fontSize: 10, color: color)),
        ],
      ),
    );
  }

  // ── SECCIÓN MÉTRICAS B2C ───────────────────────────────────────────────

  Widget _seccionMetricasB2C() {
    // Ratio de conversión: necesitamos las visitas web del mes
    // Se calculará con StreamBuilder en el widget
    
    final dauMauRatio = _datos.usuariosActivosMes > 0
        ? (_datos.usuariosActivosDia / _datos.usuariosActivosMes * 100).toStringAsFixed(1)
        : '0.0';
    
    final flashOcupacion = _datos.flashSlotsCreados > 0
        ? (_datos.flashSlotsReservados / _datos.flashSlotsCreados * 100).toStringAsFixed(1)
        : '0.0';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion(Icons.people, 'Métricas B2C (Clientes Finales)'),
        const SizedBox(height: 10),
        
        // Usuarios registrados
        _tarjetaContenido(
          titulo: '👥 Usuarios Registrados en App Explorar',
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _tarjetaKPI(
                  '${_datos.usuariosB2CTotal}',
                  'Total usuarios',
                  Icons.people_outline,
                  const Color(0xFF1976D2),
                )),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKPI(
                  '${_datos.usuariosB2CNuevosMes}',
                  'Nuevos este mes',
                  Icons.person_add,
                  const Color(0xFF2E7D32),
                )),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKPI(
                  '${_datos.usuariosB2CNuevosSemana}',
                  'Nuevos esta semana',
                  Icons.trending_up,
                  const Color(0xFF00796B),
                )),
              ]),
            ],
          ),
        ),
        
        const SizedBox(height: 10),
        
        // Usuarios activos (DAU/MAU)
        _tarjetaContenido(
          titulo: '📊 Usuarios Activos (DAU/MAU)',
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _tarjetaKPI(
                  '${_datos.usuariosActivosDia}',
                  'DAU (últimas 24h)',
                  Icons.today,
                  const Color(0xFF0288D1),
                )),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKPI(
                  '${_datos.usuariosActivosMes}',
                  'MAU (últimos 30d)',
                  Icons.calendar_month,
                  const Color(0xFF0097A7),
                )),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKPI(
                  '$dauMauRatio%',
                  'Ratio DAU/MAU',
                  Icons.percent,
                  double.parse(dauMauRatio) > 20 
                      ? const Color(0xFF2E7D32) 
                      : const Color(0xFFF57F17),
                )),
              ]),
              const SizedBox(height: 8),
              Text(
                dauMauRatio.isNotEmpty && double.parse(dauMauRatio) > 20
                    ? '✅ Excelente engagement (>20%)'
                    : '⚠️ Engagement bajo. Objetivo: >20%',
                style: TextStyle(
                  fontSize: 11,
                  color: double.parse(dauMauRatio) > 20 
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFF57F17),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 10),
        
        // Reservas B2C
        _tarjetaContenido(
          titulo: '📅 Reservas B2C (desde App Cliente)',
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _tarjetaKPI(
                  '${_datos.reservasB2CHoy}',
                  'Hoy',
                  Icons.event_available,
                  const Color(0xFF388E3C),
                )),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKPI(
                  '${_datos.reservasB2CSemana}',
                  'Esta semana',
                  Icons.date_range,
                  const Color(0xFF7B1FA2),
                )),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKPI(
                  '${_datos.reservasB2CMes}',
                  'Este mes',
                  Icons.calendar_today,
                  const Color(0xFF6A1B9A),
                )),
              ]),
              const SizedBox(height: 8),
              StreamBuilder<DocumentSnapshot>(
                stream: _db
                    .collection('empresas')
                    .doc(ConstantesApp.empresaPropietariaId)
                    .collection('estadisticas')
                    .doc('web_resumen')
                    .snapshots(),
                builder: (context, snap) {
                  String conversionRate = '0.0';
                  if (snap.hasData && snap.data!.exists) {
                    final visitasMes = (snap.data!.data() as Map)['visitas_mes'] ?? 0;
                    if (visitasMes > 0 && _datos.reservasB2CMes > 0) {
                      conversionRate = (_datos.reservasB2CMes / visitasMes * 100).toStringAsFixed(2);
                    }
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.trending_up, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Ratio conversión (visita→reserva): $conversionRate%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 10),
        
        // Valoraciones
        _tarjetaContenido(
          titulo: '⭐ Valoraciones de Clientes',
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _tarjetaKPI(
                  '${_datos.valoracionesB2CTotal}',
                  'Total valoraciones',
                  Icons.rate_review,
                  const Color(0xFFE65100),
                )),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKPI(
                  _datos.valoracionesB2CMedia.toStringAsFixed(1),
                  'Media estrellas',
                  Icons.star,
                  _datos.valoracionesB2CMedia >= 4.0
                      ? const Color(0xFFF57F17)
                      : const Color(0xFF9E9E9E),
                )),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKPI(
                  '${_datos.valoracionesB2CSemana}',
                  'Esta semana',
                  Icons.new_releases,
                  const Color(0xFFFF6F00),
                )),
              ]),
            ],
          ),
        ),
        
        const SizedBox(height: 10),
        
        // Flash Slots
        _tarjetaContenido(
          titulo: '⚡ Flash Slots (Ofertas Rápidas)',
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _tarjetaKPI(
                  '${_datos.flashSlotsCreados}',
                  'Creados este mes',
                  Icons.flash_on,
                  const Color(0xFFE91E63),
                )),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKPI(
                  '${_datos.flashSlotsReservados}',
                  'Reservados',
                  Icons.check_circle,
                  const Color(0xFF4CAF50),
                )),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKPI(
                  '$flashOcupacion%',
                  'Tasa ocupación',
                  Icons.pie_chart,
                  double.parse(flashOcupacion) > 50
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFF57F17),
                )),
              ]),
            ],
          ),
        ),
        
        const SizedBox(height: 10),
        
        // Negocios con reservas online
        _tarjetaContenido(
          titulo: '🏪 Negocios con Reservas Online',
          child: Column(
            children: [
              Row(children: [
                Expanded(child: _tarjetaKPI(
                  '${_datos.negociosConReservasOnline}',
                  'Con reservas activas',
                  Icons.store_mall_directory,
                  const Color(0xFF2E7D32),
                )),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKPI(
                  '${_datos.negociosSinReservasOnline}',
                  'Sin reservas',
                  Icons.store,
                  _datos.negociosSinReservasOnline > 0
                      ? const Color(0xFFF57F17)
                      : const Color(0xFF9E9E9E),
                )),
                const SizedBox(width: 10),
                Expanded(child: _tarjetaKPI(
                  _datos.negociosConReservasOnline + _datos.negociosSinReservasOnline > 0
                      ? '${(_datos.negociosConReservasOnline / (_datos.negociosConReservasOnline + _datos.negociosSinReservasOnline) * 100).toStringAsFixed(0)}%'
                      : '0%',
                  'Tasa activación',
                  Icons.show_chart,
                  const Color(0xFF1976D2),
                )),
              ]),
              if (_datos.negociosSinReservasOnline > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '⚠️ ${_datos.negociosSinReservasOnline} negocio(s) no están aprovechando la plataforma',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFF57F17),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
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
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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

  // ── HERRAMIENTAS DE DESARROLLO ─────────────────────────────────────────────

  Widget _seccionHerramientasDev() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _tituloSeccion(Icons.developer_mode, 'Herramientas de Desarrollo'),
        const SizedBox(height: 10),
        Card(
          elevation: 1,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        onPressed:
                        _generandoDatos ? null : _generarDatosDePrueba,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _generandoDatos
                            ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          _generandoDatos
                              ? 'Generando...'
                              : 'Generar datos prueba',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                        _generandoDatos ? null : _limpiarDatosDePrueba,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.delete_sweep, size: 18),
                        label: const Text('Limpiar datos',
                            style: TextStyle(fontSize: 13)),
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
        FluxToast.exito(context, 'Datos de prueba generados (10 clientes, 30 empleados, nóminas, facturas...)');
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        FluxToast.error(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _generandoDatos = false);
    }
  }

  Future<void> _limpiarDatosDePrueba() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('¿Limpiar todos los datos de prueba?'),
        content: const Text(
            'Se eliminarán clientes, empleados, nóminas, facturas, gastos, reservas y valoraciones de prueba.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar todo',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _generandoDatos = true);
    try {
      await DatosPruebaFluixtechService().limpiarTodo();
      if (mounted) {
        FluxToast.aviso(context, 'Datos de prueba eliminados');
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        FluxToast.error(context, 'Error: $e');
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
  final double mrr;
  final double ingresosTotal;
  final double ingresosMes;
  final int facturasPendientes;
  final int totalPedidos;
  final int totalFacturas;
  final int totalValoraciones;
  final int totalReservas;
  final int totalUsuarios;
  final List<Map<String, dynamic>> ultimasVentas;
  
  // Métricas B2C
  final int usuariosB2CTotal;
  final int usuariosB2CNuevosMes;
  final int usuariosB2CNuevosSemana;
  final int usuariosActivosDia; // DAU
  final int usuariosActivosMes; // MAU
  final int reservasB2CHoy;
  final int reservasB2CSemana;
  final int reservasB2CMes;
  final int valoracionesB2CTotal;
  final double valoracionesB2CMedia;
  final int valoracionesB2CSemana;
  final int flashSlotsCreados;
  final int flashSlotsReservados;
  final int negociosConReservasOnline;
  final int negociosSinReservasOnline;

  const _DatosPropietario({
    required this.totalEmpresas,
    required this.empresasNuevasMes,
    required this.suscripcionesActivas,
    required this.suscripcionesVencen7,
    required this.suscripcionesVencidas,
    required this.mrr,
    required this.ingresosTotal,
    required this.ingresosMes,
    required this.facturasPendientes,
    required this.totalPedidos,
    required this.totalFacturas,
    required this.totalValoraciones,
    required this.totalReservas,
    required this.totalUsuarios,
    required this.ultimasVentas,
    required this.usuariosB2CTotal,
    required this.usuariosB2CNuevosMes,
    required this.usuariosB2CNuevosSemana,
    required this.usuariosActivosDia,
    required this.usuariosActivosMes,
    required this.reservasB2CHoy,
    required this.reservasB2CSemana,
    required this.reservasB2CMes,
    required this.valoracionesB2CTotal,
    required this.valoracionesB2CMedia,
    required this.valoracionesB2CSemana,
    required this.flashSlotsCreados,
    required this.flashSlotsReservados,
    required this.negociosConReservasOnline,
    required this.negociosSinReservasOnline,
  });

  factory _DatosPropietario.vacio() => const _DatosPropietario(
    totalEmpresas: 0,
    empresasNuevasMes: 0,
    suscripcionesActivas: 0,
    suscripcionesVencen7: 0,
    suscripcionesVencidas: 0,
    mrr: 0,
    ingresosTotal: 0,
    ingresosMes: 0,
    facturasPendientes: 0,
    totalPedidos: 0,
    totalFacturas: 0,
    totalValoraciones: 0,
    totalReservas: 0,
    totalUsuarios: 0,
    ultimasVentas: [],
    usuariosB2CTotal: 0,
    usuariosB2CNuevosMes: 0,
    usuariosB2CNuevosSemana: 0,
    usuariosActivosDia: 0,
    usuariosActivosMes: 0,
    reservasB2CHoy: 0,
    reservasB2CSemana: 0,
    reservasB2CMes: 0,
    valoracionesB2CTotal: 0,
    valoracionesB2CMedia: 0,
    valoracionesB2CSemana: 0,
    flashSlotsCreados: 0,
    flashSlotsReservados: 0,
    negociosConReservasOnline: 0,
    negociosSinReservasOnline: 0,
  );

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String && value.isNotEmpty) return [value];
    return [];
  }

  static Future<_DatosPropietario> cargar(FirebaseFirestore db) async {
    final ahora = DateTime.now();
    final inicioMes = DateTime(ahora.year, ahora.month, 1);
    final en7Dias = ahora.add(const Duration(days: 7));

    final topLevel = await Future.wait([
      db.collection('empresas').get(),
      db
          .collection('empresas')
          .doc(ConstantesApp.empresaPropietariaId)
          .collection('facturas')
          .get(),
    ]);

    final empresasSnap = topLevel[0] as QuerySnapshot<Map<String, dynamic>>;
    final facturasSnap = topLevel[1] as QuerySnapshot<Map<String, dynamic>>;
    final totalEmpresas = empresasSnap.docs.length;

    int empresasNuevasMes = 0;
    int suscripcionesActivas = 0;
    int suscripcionesVencen7 = 0;
    int suscripcionesVencidas = 0;
    int totalPedidosAll = 0;
    int totalFacturasAll = 0;
    int totalValoracionesAll = 0;
    int totalReservasAll = 0;
    int totalUsuariosAll = 0;
    double mrrCalc = 0;

    await Future.wait(empresasSnap.docs.map((doc) async {
      final data = doc.data();

      final fechaCreacion = data['fecha_creacion'];
      if (fechaCreacion is Timestamp &&
          fechaCreacion.toDate().isAfter(inicioMes)) {
        empresasNuevasMes++;
      }

      try {
        final subResults = await Future.wait([
          doc.reference.collection('suscripcion').doc('actual').get(),
          doc.reference.collection('pedidos').count().get(),
          doc.reference.collection('facturas').count().get(),
          doc.reference.collection('valoraciones').count().get(),
          doc.reference.collection('reservas').count().get(),
          doc.reference.collection('empleados').count().get(),
        ]);

        final suscSnap =
        subResults[0] as DocumentSnapshot<Map<String, dynamic>>;
        if (suscSnap.exists) {
          final sd = suscSnap.data()!;
          final estado = (sd['estado'] as String? ?? '').toUpperCase();
          final fechaFinRaw = sd['fecha_fin'];
          DateTime? fechaFinDt;
          if (fechaFinRaw is Timestamp) {
            fechaFinDt = fechaFinRaw.toDate();
          } else if (fechaFinRaw is String) {
            fechaFinDt = DateTime.tryParse(fechaFinRaw);
          }

          if (estado == 'ACTIVA') {
            suscripcionesActivas++;
            if (fechaFinDt != null && fechaFinDt.isBefore(en7Dias)) {
              suscripcionesVencen7++;
            }
            final packsActivos = _parseStringList(sd['packs_activos']);
            final addonsActivos = _parseStringList(sd['addons_activos']);
            final precioAnual = PlanesConfig.calcularPrecioTotal(
              packsActivos: packsActivos,
              addonsActivos: addonsActivos,
            );
            mrrCalc += precioAnual / 12;
          } else if (estado == 'VENCIDA') {
            suscripcionesVencidas++;
          }
        }

        totalPedidosAll +=
            (subResults[1] as AggregateQuerySnapshot).count ?? 0;
        totalFacturasAll +=
            (subResults[2] as AggregateQuerySnapshot).count ?? 0;
        totalValoracionesAll +=
            (subResults[3] as AggregateQuerySnapshot).count ?? 0;
        totalReservasAll +=
            (subResults[4] as AggregateQuerySnapshot).count ?? 0;
        totalUsuariosAll +=
            (subResults[5] as AggregateQuerySnapshot).count ?? 0;
      } catch (_) {}
    }));

    double ingresosTotal = 0;
    double ingresosMes = 0;
    int facturasPendientes = 0;

    for (final f in facturasSnap.docs) {
      final fd = f.data();
      final total = (fd['total'] as num?)?.toDouble() ?? 0;
      final estado = (fd['estado'] as String? ?? '').toLowerCase();
      final fecha = fd['fecha_emision'] as Timestamp?;
      final esPagada = estado == 'pagada' || estado == 'cobrada';

      if (estado == 'pendiente') facturasPendientes++;
      if (esPagada) {
        ingresosTotal += total;
        if (fecha != null && fecha.toDate().isAfter(inicioMes)) {
          ingresosMes += total;
        }
      }
    }

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

    // ── MÉTRICAS B2C ──────────────────────────────────────────────────────
    
    // 1. Usuarios B2C (clientes finales)
    int usuariosB2CTotal = 0;
    int usuariosB2CNuevosMes = 0;
    int usuariosB2CNuevosSemana = 0;
    int usuariosActivosDia = 0;
    int usuariosActivosMes = 0;
    
    try {
      final usuariosB2CSnap = await db
          .collection('usuarios')
          .where('rol', isEqualTo: 'clienteFinal')
          .get();
      
      usuariosB2CTotal = usuariosB2CSnap.docs.length;
      
      final ahora = DateTime.now();
      final inicioSemana = ahora.subtract(const Duration(days: 7));
      final hace1Dia = ahora.subtract(const Duration(days: 1));
      final hace30Dias = ahora.subtract(const Duration(days: 30));
      
      for (final doc in usuariosB2CSnap.docs) {
        final data = doc.data();
        
        // Usuarios nuevos
        final fechaCreacion = data['fecha_creacion'];
        if (fechaCreacion is Timestamp) {
          final dt = fechaCreacion.toDate();
          if (dt.isAfter(inicioMes)) usuariosB2CNuevosMes++;
          if (dt.isAfter(inicioSemana)) usuariosB2CNuevosSemana++;
        }
        
        // Usuarios activos (DAU/MAU)
        final ultimoAcceso = data['ultimo_acceso'];
        if (ultimoAcceso is Timestamp) {
          final dt = ultimoAcceso.toDate();
          if (dt.isAfter(hace1Dia)) usuariosActivosDia++;
          if (dt.isAfter(hace30Dias)) usuariosActivosMes++;
        }
      }
    } catch (_) {}
    
    // 2. Reservas B2C
    int reservasB2CHoy = 0;
    int reservasB2CSemana = 0;
    int reservasB2CMes = 0;
    
    try {
      final ahora = DateTime.now();
      final inicioHoy = DateTime(ahora.year, ahora.month, ahora.day);
      final inicioSemana = ahora.subtract(const Duration(days: 7));
      
      final reservasB2CSnap = await db
          .collectionGroup('reservas')
          .where('origen', isEqualTo: 'app_cliente')
          .get();
      
      for (final doc in reservasB2CSnap.docs) {
        final data = doc.data();
        final fecha = data['fecha_creacion'] ?? data['fecha_reserva'];
        if (fecha is Timestamp) {
          final dt = fecha.toDate();
          if (dt.isAfter(inicioMes)) reservasB2CMes++;
          if (dt.isAfter(inicioSemana)) reservasB2CSemana++;
          if (dt.isAfter(inicioHoy)) reservasB2CHoy++;
        }
      }
    } catch (_) {}
    
    // 3. Valoraciones B2C (negocios_publicos)
    int valoracionesB2CTotal = 0;
    double valoracionesB2CMedia = 0;
    int valoracionesB2CSemana = 0;
    
    try {
      final inicioSemana = ahora.subtract(const Duration(days: 7));
      final valoracionesSnap = await db.collectionGroup('valoraciones').get();
      
      double sumaEstrellas = 0;
      for (final doc in valoracionesSnap.docs) {
        final data = doc.data();
        final estrellas = data['rating'] ?? data['estrellas'] ?? 0;
        sumaEstrellas += (estrellas as num).toDouble();
        valoracionesB2CTotal++;
        
        final fecha = data['fecha'] ?? data['fecha_creacion'];
        if (fecha is Timestamp && fecha.toDate().isAfter(inicioSemana)) {
          valoracionesB2CSemana++;
        }
      }
      
      if (valoracionesB2CTotal > 0) {
        valoracionesB2CMedia = sumaEstrellas / valoracionesB2CTotal;
      }
    } catch (_) {}
    
    // 4. Flash Slots
    int flashSlotsCreados = 0;
    int flashSlotsReservados = 0;
    
    try {
      final flashSlotsSnap = await db.collectionGroup('flash_slots').get();
      
      for (final doc in flashSlotsSnap.docs) {
        final data = doc.data();
        final fecha = data['fecha_creacion'];
        if (fecha is Timestamp && fecha.toDate().isAfter(inicioMes)) {
          flashSlotsCreados++;
          
          final reservado = data['reservado'] ?? data['ocupado'] ?? false;
          if (reservado) flashSlotsReservados++;
        }
      }
    } catch (_) {}
    
    // 5. Negocios con/sin reservas online
    int negociosConReservasOnline = 0;
    int negociosSinReservasOnline = 0;
    
    try {
      final negociosSnap = await db.collection('negocios_publicos').get();
      
      for (final doc in negociosSnap.docs) {
        final data = doc.data();
        final reservasOnline = data['reservas_online'] ?? data['permite_reservas'] ?? false;
        
        if (reservasOnline) {
          negociosConReservasOnline++;
        } else {
          negociosSinReservasOnline++;
        }
      }
    } catch (_) {}

    return _DatosPropietario(
      totalEmpresas: totalEmpresas,
      empresasNuevasMes: empresasNuevasMes,
      suscripcionesActivas: suscripcionesActivas,
      suscripcionesVencen7: suscripcionesVencen7,
      suscripcionesVencidas: suscripcionesVencidas,
      mrr: mrrCalc,
      ingresosTotal: ingresosTotal,
      ingresosMes: ingresosMes,
      facturasPendientes: facturasPendientes,
      totalPedidos: totalPedidosAll,
      totalFacturas: totalFacturasAll,
      totalValoraciones: totalValoracionesAll,
      totalReservas: totalReservasAll,
      totalUsuarios: totalUsuariosAll,
      ultimasVentas: ultimasVentas,
      usuariosB2CTotal: usuariosB2CTotal,
      usuariosB2CNuevosMes: usuariosB2CNuevosMes,
      usuariosB2CNuevosSemana: usuariosB2CNuevosSemana,
      usuariosActivosDia: usuariosActivosDia,
      usuariosActivosMes: usuariosActivosMes,
      reservasB2CHoy: reservasB2CHoy,
      reservasB2CSemana: reservasB2CSemana,
      reservasB2CMes: reservasB2CMes,
      valoracionesB2CTotal: valoracionesB2CTotal,
      valoracionesB2CMedia: valoracionesB2CMedia,
      valoracionesB2CSemana: valoracionesB2CSemana,
      flashSlotsCreados: flashSlotsCreados,
      flashSlotsReservados: flashSlotsReservados,
      negociosConReservasOnline: negociosConReservasOnline,
      negociosSinReservasOnline: negociosSinReservasOnline,
    );
  }
}
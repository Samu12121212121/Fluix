import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../core/widgets/flux_toast.dart';
import '../modelos/vehiculo_cad.dart';
import '../servicios/osrm_service.dart';
import '../servicios/vehiculos_service.dart';
import '../servicios/cad_simulation.dart';
//
// CAD OPERACIONES — Centro de Despacho Inteligente
//
// Colecciones Firestore:
//   empresas/{id}/vehiculos_cad/{vehiculoId}  — GPS en tiempo real
//   empresas/{id}/alertas_despacho/{alertaId} — emergencias
//
const _kNavy  = Color(0xFF0A0F23);
const _kTeal  = Color(0xFF00FFC8);
const _kPink  = Color(0xFFFF3296);
const _kBg    = Color(0xFFF0F4F8);
const _kSurf  = Colors.white;
const _kBorder = Color(0xFFE2E8F0);
const _kText  = Color(0xFF0F172A);
const _kSub   = Color(0xFF64748B);
const _kGreen = Color(0xFF16A34A);
const _kAmber = Color(0xFFF59E0B);
const _kRed   = Color(0xFFEF4444);
const _kBlue  = Color(0xFF3B82F6);
const _kGuadalajaraCenter = LatLng(40.6333, -3.1667);
class CADOperacionesScreen extends StatefulWidget {
  final String empresaId;
  const CADOperacionesScreen({super.key, required this.empresaId});
  @override
  State<CADOperacionesScreen> createState() => _CADOperacionesScreenState();
}
// Entrada del historial de actividad
class _HistEntry {
  final DateTime ts;
  final String msg;
  final String cat; // 'emergency' | 'dispatch' | 'arrival' | 'resolved' | 'system'
  _HistEntry(this.ts, this.msg, this.cat);
}
class _CADOperacionesScreenState extends State<CADOperacionesScreen> {
  late final VehiculosCADService _svc;
  final _mapController = MapController();
  // Firestore state
  List<VehiculoCAD> _vehiculos = [];
  List<Map<String, dynamic>> _alertas = [];
  StreamSubscription? _vehSub;
  StreamSubscription? _alertSub;
  // Simulation state
  List<SimVehiculo> _sims = [];
  Timer? _simTimer;
  bool _simRunning = true;
  final Map<String, List<LatLng>> _dispatchRoutes = {};
  final List<_HistEntry> _history = [];
  String? _selVehiculoId;
  String? _selAlertaId;
  bool _pickingCoords = false;
  LatLng? _pickedCoords;
  bool _calculandoRutas = false;
  final Map<String, DateTime> _estimatedArrival = {};
  final Map<String, DateTime> _dispatchTime = {};
  bool _osrmRoutesLoaded = false;
  bool _disposed = false;
  @override
  void initState() {
    super.initState();
    _svc = VehiculosCADService(widget.empresaId);
    _svc.seedVehiculosDemoSiVacio().then((_) => _startSim());
    _suscribir();
    _addHistory('Sistema CAD iniciado — Sysday Emergencias Guadalajara', 'system');
  }
  void _startSim() {
    _sims = initSimulacion();
    setState(() {});
    _simTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) => _tickSim());
    _expandPatrolRoutesAsync();
  }
  Future<void> _expandPatrolRoutesAsync() async {
    await Future.wait(_sims.map(_expandVehiclePatrol));
    if (!_disposed && mounted) setState(() => _osrmRoutesLoaded = true);
  }
  Future<void> _expandVehiclePatrol(SimVehiculo sim) async {
    final route = kPatrolRoutes[sim.id];
    if (route == null || route.length < 2) return;
    final expanded = <LatLng>[];
    for (int i = 0; i < route.length; i++) {
      final from = route[i];
      final to   = route[(i + 1) % route.length];
      try {
        final r = await OsrmService.calcularRuta(from, to);
        if (expanded.isEmpty) expanded.add(from);
        if (!r.isFallback) {
          expanded.addAll(r.waypoints.skip(1));
        } else {
          expanded.add(to);
        }
      } catch (_) {
        if (expanded.isEmpty) expanded.add(from);
        expanded.add(to);
      }
    }
    if (_disposed || !mounted || expanded.length < 4) return;
    setState(() {
      sim.baseRoute = expanded;
      if (sim.estado == EstadoVehiculo.disponible) {
        double minD = double.infinity;
        int closest = 0;
        for (int i = 0; i < expanded.length; i++) {
          final dx = expanded[i].latitude  - sim.lat;
          final dy = expanded[i].longitude - sim.lng;
          final d = dx * dx + dy * dy;
          if (d < minD) { minD = d; closest = i; }
        }
        sim.route = expanded;
        sim.routeIndex = closest;
      }
    });
  }
  Future<void> _fetchReturnRoute(SimVehiculo v) async {
    final pos  = LatLng(v.lat, v.lng);
    final base = v.baseRoute;
    if (base.isEmpty) return;
    final result = await OsrmService.calcularRuta(pos, base[0]);
    if (mounted && v.estado == EstadoVehiculo.regresando) {
      setState(() {
        v.route = result.waypoints;
        v.routeIndex = 0;
      });
    }
  }
  void _tickSim() {
    if (!_simRunning || !mounted) return;
    final needReturnRoute = <SimVehiculo>[];
    setState(() {
      for (final v in _sims) {
        if (v.estado == EstadoVehiculo.atendiendo) {
          v.attendingTicks++;
          if (v.attendingTicks >= 4) {
            final base = v.baseRoute;
            v.route = [v.posicion, base.isNotEmpty ? base[0] : v.posicion];
            v.routeIndex = 0;
            v.estado = EstadoVehiculo.regresando;
            v.attendingTicks = 0;
            needReturnRoute.add(v);
            _updateAlertaEstado(v.alertaId, 'atendida');
            _addHistory('${v.id} concluye servicio — Regresando a base', 'resolved');
          }
          continue;
        }
        final arrived = tickVehiculo(v, 2.5);
        if (arrived) {
          if (v.estado == EstadoVehiculo.enRoute) {
            v.estado = EstadoVehiculo.atendiendo;
            v.speed = 0;
            _addHistory('${v.id} llega al incidente — Atendiendo emergencia', 'arrival');
            _updateAlertaEstado(v.alertaId, 'activa');
          } else if (v.estado == EstadoVehiculo.regresando) {
            v.estado = EstadoVehiculo.disponible;
            v.route = List.from(v.baseRoute);
            v.routeIndex = 0;
            v.alertaId = null;
            _dispatchRoutes.remove(v.id);
            _estimatedArrival.remove(v.id);
            _dispatchTime.remove(v.id);
            _addHistory('${v.id} regresa a base — Disponible', 'system');
          }
        }
      }
    });
    for (final v in needReturnRoute) {
      _fetchReturnRoute(v);
    }
  }
  void _updateAlertaEstado(String? alertaId, String estado) {
    if (alertaId == null) return;
    FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('alertas_despacho').doc(alertaId)
        .update({'estado': estado}).catchError((_) {});
  }
  void _addHistory(String msg, String cat) {
    setState(() {
      _history.insert(0, _HistEntry(DateTime.now(), msg, cat));
      if (_history.length > 40) _history.removeLast();
    });
  }

  Future<void> _enviarAlertaPrueba() async {
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('enviarAlertaPruebaDespacho');
      await fn.call({'empresa_id': widget.empresaId});
      if (mounted) {
        FluxToast.exito(context, 'Alerta de prueba enviada a todos los dispositivos');
        _addHistory('Alerta de prueba FCM enviada', 'system');
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error enviando prueba: $e');
    }
  }
  void _suscribir() {
    _vehSub = _svc.vehiculosStream().listen((v) {
      if (mounted) setState(() => _vehiculos = v);
    });
    _alertSub = FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('alertas_despacho')
        .orderBy('fecha_hora', descending: true)
        .limit(30)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() => _alertas = snap.docs.map((d) => {...d.data(), 'id': d.id}).toList());
      }
    });
  }
  @override
  void dispose() {
    _disposed = true;
    _vehSub?.cancel();
    _alertSub?.cancel();
    _simTimer?.cancel();
    super.dispose();
  }
  int get _disponibles    => _vehiculos.where((v) => v.estado == EstadoVehiculo.disponible).length;
  int get _ocupados       => _vehiculos.where((v) => v.estado != EstadoVehiculo.disponible && v.estado != EstadoVehiculo.offline).length;
  int get _alertasActivas => _alertas.where((a) => a['estado'] != 'atendida' && a['estado'] != 'completada').length;
  int get _sinGPS         => _vehiculos.where((v) => v.estado == EstadoVehiculo.offline).length;
  void _centrarEnVehiculo(VehiculoCAD v) {
    _mapController.move(v.posicion, 15.5);
    setState(() => _selVehiculoId = v.id);
  }
  void _centrarEnAlerta(Map<String, dynamic> a) {
    final lat = (a['lat'] as num?)?.toDouble() ?? 40.6333;
    final lng = (a['lng'] as num?)?.toDouble() ?? -3.1667;
    _mapController.move(LatLng(lat, lng), 16);
    setState(() => _selAlertaId = a['id'] as String?);
  }
  Future<void> _abrirDespacho(Map<String, dynamic> alerta) async {
    setState(() => _calculandoRutas = true);
    final lat  = (alerta['lat'] as num?)?.toDouble() ?? 40.6333;
    final lng  = (alerta['lng'] as num?)?.toDouble() ?? -3.1667;
    final pos  = LatLng(lat, lng);
    final tipo = alerta['tipo_codigo'] as String? ?? 'GENERAL';
    final recs = await AlgoritmoDespacho.calcular(
      vehiculos: _vehiculos,
      posicionEmergencia: pos,
      tipoEmergencia: tipo,
    );
    if (!mounted) return;
    setState(() => _calculandoRutas = false);
    _mostrarModalDespacho(alerta, recs);
  }
  void _mostrarModalDespacho(Map<String, dynamic> alerta, List<RecomendacionDespacho> recs) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DispatchModal(
        alerta: alerta,
        recomendaciones: recs,
        onDespachar: (rec) async {
          Navigator.pop(context);
          await _despachar(alerta, rec);
        },
      ),
    );
  }
  Future<void> _despachar(Map<String, dynamic> alerta, RecomendacionDespacho rec) async {
    final alertaId = alerta['id'] as String;
    final v = rec.vehiculo;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(
      FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId)
          .collection('vehiculos_cad').doc(v.id),
      {'estado': 'en_route', 'alerta_asignada_id': alertaId},
    );
    batch.update(
      FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId)
          .collection('alertas_despacho').doc(alertaId),
      {
        'estado': 'aceptada',
        'ambulancia_asignada': v.nombre,
        'operador_uid': 'cad_admin',
        'fecha_respuesta': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
    if (mounted) {
      if (_sims.isEmpty) return;
      final sim = _sims.firstWhere((s) => s.id == v.id, orElse: () => _sims.first);
      final simLat = (alerta['lat'] as num?)?.toDouble() ?? 40.6333;
      final simLng = (alerta['lng'] as num?)?.toDouble() ?? -3.1667;
      setState(() {
        sim.estado = EstadoVehiculo.enRoute;
        sim.route = rec.ruta.waypoints.isNotEmpty
            ? rec.ruta.waypoints
            : [sim.posicion, LatLng(simLat, simLng)];
        sim.routeIndex = 0;
        sim.alertaId = alertaId;
        _dispatchRoutes[v.id] = sim.route;
      });
      final etaSecs = (rec.ruta.etaMinutes * 60).round();
      _estimatedArrival[v.id] = DateTime.now().add(Duration(seconds: etaSecs));
      _dispatchTime[v.id] = DateTime.now();
      _addHistory('${v.nombre} despachada — ETA ${rec.ruta.etaMinutes.toStringAsFixed(0)} min', 'dispatch');
      FluxToast.exito(context, '${v.nombre} en ruta — ETA ${rec.ruta.etaMinutes.toStringAsFixed(0)} min');
    }
  }
  // ── Map marker builders ────────────────────────────────────────────────────
  List<Marker> _buildVehiculoMarkers() {
    // Use simulation positions (real-time movement)
    final source = _sims.isNotEmpty ? _sims : _vehiculos.map((v) => SimVehiculo(
      id: v.id, lat: v.lat, lng: v.lng, heading: v.rumbo, speed: v.velocidad,
      route: [LatLng(v.lat, v.lng)], baseRoute: [LatLng(v.lat, v.lng)], estado: v.estado,
    )).toList();
    return source.map((s) {
      final color = _colorEstadoSim(s.estado);
      final isSel = s.id == _selVehiculoId;
      return Marker(
        point: s.posicion,
        width: 60, height: 62,
        child: GestureDetector(
          onTap: () {
            setState(() => _selVehiculoId = s.id);
            _mapController.move(s.posicion, 15.5);
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: isSel ? 36 : 30,
              height: isSel ? 36 : 30,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(isSel ? 10 : 8),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.65), blurRadius: isSel ? 12 : 7, spreadRadius: isSel ? 3 : 1),
                ],
              ),
              child: Stack(children: [
                Center(child: Icon(Icons.local_hospital_rounded, color: Colors.white, size: isSel ? 20 : 16)),
                Positioned(
                  top: 2, right: 2,
                  child: Transform.rotate(
                    angle: s.heading * math.pi / 180,
                    child: Icon(Icons.arrow_upward_rounded, color: Colors.white.withValues(alpha: 0.85), size: 7),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
              ),
              child: Text(s.id, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
            ),
          ]),
        ),
      );
    }).toList();
  }
  static Color _colorEstadoSim(EstadoVehiculo e) => switch (e) {
    EstadoVehiculo.disponible  => _kGreen,
    EstadoVehiculo.enRoute     => _kBlue,
    EstadoVehiculo.atendiendo  => _kAmber,
    EstadoVehiculo.regresando  => const Color(0xFF8B5CF6),
    EstadoVehiculo.offline     => _kSub,
  };
  // Marcadores de destino: pin con cruz médica en el punto al que se dirige cada ambulancia despachada
  List<Marker> _buildDestinoMarkers() {
    final markers = <Marker>[];
    for (final sim in _sims) {
      if ((sim.estado != EstadoVehiculo.enRoute && sim.estado != EstadoVehiculo.regresando) || sim.route.isEmpty) continue;
      final dest = sim.route.last;
      final color = sim.estado == EstadoVehiculo.enRoute ? _kBlue : const Color(0xFF8B5CF6);
      markers.add(Marker(
        point: dest,
        width: 36, height: 36,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10, spreadRadius: 2)],
          ),
          child: const Center(child: Icon(Icons.flag_rounded, color: Colors.white, size: 18)),
        ),
      ));
    }
    return markers;
  }

  List<Marker> _buildAlertaMarkers() {
    return _alertas.where((a) => a['lat'] != null && a['estado'] != 'atendida').map((a) {
      final lat = (a['lat'] as num).toDouble();
      final lng = (a['lng'] as num).toDouble();
      final prio = a['prioridad'] as String? ?? 'alta';
      final color = prio == 'critica' ? _kRed : prio == 'alta' ? const Color(0xFFF97316) : _kAmber;
      final isSel = a['id'] == _selAlertaId;
      return Marker(
        point: LatLng(lat, lng),
        width: 32, height: 32,
        child: GestureDetector(
          onTap: () => _centrarEnAlerta(a),
          child: Container(
            width: isSel ? 32 : 24, height: isSel ? 32 : 24,
            decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: isSel ? 12 : 6, spreadRadius: isSel ? 3 : 0)],
            ),
            child: const Center(child: Text('!', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))),
          ),
        ),
      );
    }).toList();
  }
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: FluixAppBar(
        titulo: 'Centro de Operaciones',
        showLeading: true,
        extraActions: [
          _kpiChip('${_disponibles}', 'disponibles', _kTeal),
          _kpiChip('${_ocupados}', 'ocupados', _kAmber),
          _kpiChip('${_alertasActivas}', 'activas', _kRed),
          if (_sinGPS > 0) _kpiChip('${_sinGPS}', 'sin GPS', _kSub),
          const SizedBox(width: 8),
          if (_calculandoRutas)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            ),
          // Botón de prueba FCM — envía alerta de test a todos los dispositivos
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Tooltip(
              message: 'Enviar alerta de prueba a todos los dispositivos',
              child: GestureDetector(
                onTap: _enviarAlertaPrueba,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kAmber.withValues(alpha: 0.5)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.send_to_mobile_rounded, size: 14, color: _kAmber),
                    SizedBox(width: 5),
                    Text('TEST', style: TextStyle(fontSize: 10, color: _kAmber, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
      body: isWide
          ? _buildDesktopLayout()
          : _buildMobileLayout(),
    );
  }
  Widget _buildDesktopLayout() {
    return Row(children: [
      // Panel izquierdo — vehículos
      SizedBox(
        width: 272,
        child: _PanelVehiculos(
          sims: _sims.isNotEmpty ? _sims : [],
          vehiculos: _vehiculos,
          selectedId: _selVehiculoId,
          selectedAlerta: _selAlertaId != null
              ? _alertas.firstWhere((a) => a['id'] == _selAlertaId, orElse: () => {})
              : null,
          simRunning: _simRunning,
          estimatedArrival: _estimatedArrival,
          dispatchTime: _dispatchTime,
          onSelect: (id) { setState(() => _selVehiculoId = id); },
          onNuevoVehiculo: _mostrarNuevoVehiculo,
          onToggleSim: () => setState(() => _simRunning = !_simRunning),
        ),
      ),
      // Mapa
      Expanded(child: _buildMapa()),
      // Panel derecho — emergencias + historial
      SizedBox(
        width: 288,
        child: _PanelDerecho(
          alertas: _alertas,
          history: _history,
          selectedId: _selAlertaId,
          onSelect: _centrarEnAlerta,
          onDespachar: _abrirDespacho,
          empresaId: widget.empresaId,
          onNuevaEmergencia: () => _mostrarNuevaEmergencia(),
        ),
      ),
    ]);
  }
  Widget _buildMobileLayout() {
    return Column(children: [
      // Mapa compacto en mobile
      SizedBox(height: 280, child: _buildMapa()),
      Expanded(
        child: DefaultTabController(
          length: 2,
          child: Column(children: [
            TabBar(
              labelColor: _kNavy, unselectedLabelColor: _kSub,
              indicatorColor: _kTeal,
              tabs: const [Tab(text: 'Vehículos'), Tab(text: 'Emergencias')],
            ),
            Expanded(
              child: TabBarView(children: [
                _PanelVehiculos(
                  sims: _sims,
                  vehiculos: _vehiculos,
                  selectedId: _selVehiculoId,
                  selectedAlerta: _selAlertaId != null
                      ? _alertas.firstWhere((a) => a['id'] == _selAlertaId, orElse: () => {})
                      : null,
                  simRunning: _simRunning,
                  estimatedArrival: _estimatedArrival,
                  dispatchTime: _dispatchTime,
                  onSelect: (id) {
                    final v = _vehiculos.where((v) => v.id == id).firstOrNull;
                    if (v != null) _centrarEnVehiculo(v);
                  },
                  onToggleSim: () => setState(() => _simRunning = !_simRunning),
                ),
                _PanelDerecho(
                  alertas: _alertas,
                  history: _history,
                  selectedId: _selAlertaId,
                  onSelect: _centrarEnAlerta,
                  onDespachar: _abrirDespacho,
                  empresaId: widget.empresaId,
                  onNuevaEmergencia: () => _mostrarNuevaEmergencia(),
                ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
  Widget _buildMapa() {
    return Stack(children: [
      FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _kGuadalajaraCenter,
          initialZoom: 13.5,
          minZoom: 10,
          maxZoom: 19,
          // Scroll wheel deshabilitado en web: flutter_map 7.x tiene drift
          // hacia la derecha cuando el mapa no está en la esquina 0,0 del viewport.
          // Se usan los botones +/- superpuestos en su lugar.
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onTap: (_, latlng) {
            if (_pickingCoords) {
              setState(() { _pickedCoords = latlng; _pickingCoords = false; });
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.fluixcrm.app',
            maxZoom: 19,
            minZoom: 10,
          ),
          // Rutas activas — sombra (halo) + línea principal
          if (_sims.any((s) => s.estado == EstadoVehiculo.enRoute || s.estado == EstadoVehiculo.regresando)) ...[
            PolylineLayer(
              polylines: _sims
                  .where((s) => (s.estado == EstadoVehiculo.enRoute || s.estado == EstadoVehiculo.regresando) && s.route.length > 1)
                  .map((s) => Polyline(
                        points: s.route,
                        color: (s.estado == EstadoVehiculo.enRoute ? _kTeal : const Color(0xFF8B5CF6)).withValues(alpha: 0.28),
                        strokeWidth: 10.0,
                      ))
                  .toList(),
            ),
            PolylineLayer(
              polylines: _sims
                  .where((s) => (s.estado == EstadoVehiculo.enRoute || s.estado == EstadoVehiculo.regresando) && s.route.length > 1)
                  .map((s) => Polyline(
                        points: s.route,
                        color: s.estado == EstadoVehiculo.enRoute ? _kTeal : const Color(0xFF8B5CF6),
                        strokeWidth: 4.5,
                        pattern: StrokePattern.dashed(segments: const [14, 5]),
                      ))
                  .toList(),
            ),
          ],
          // Marcadores vehículos, alertas y destinos activos
          MarkerLayer(markers: [
            ..._buildAlertaMarkers(),
            ..._buildDestinoMarkers(),
            ..._buildVehiculoMarkers(),
          ]),
        ],
      ),
      // Badge estado routing OSRM
      Positioned(
        top: 12, left: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kNavy.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: (_osrmRoutesLoaded ? _kTeal : _kAmber).withValues(alpha: 0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _osrmRoutesLoaded ? _kTeal : _kAmber,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _osrmRoutesLoaded ? 'RUTAS EN VIVO' : 'CARGANDO RUTAS...',
              style: TextStyle(
                color: _osrmRoutesLoaded ? const Color(0xFF00FFC8) : _kAmber,
                fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5,
              ),
            ),
          ]),
        ),
      ),
      // Hint de picking
      if (_pickingCoords)
        Positioned(
          top: 12, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _kNavy, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kTeal),
              ),
              child: const Text('Toca el mapa para seleccionar ubicación',
                  style: TextStyle(color: Color(0xFF00FFC8), fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ),
      // Botones zoom +/-
      Positioned(
        top: 12, right: 12,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _zoomBtn(Icons.add_rounded, () {
            final z = _mapController.camera.zoom;
            _mapController.move(_mapController.camera.center, (z + 1).clamp(10, 19));
          }),
          const SizedBox(height: 4),
          _zoomBtn(Icons.remove_rounded, () {
            final z = _mapController.camera.zoom;
            _mapController.move(_mapController.camera.center, (z - 1).clamp(10, 19));
          }),
        ]),
      ),
      // Botón nueva emergencia flotante en mobile/tablet
      Positioned(
        bottom: 16, right: 16,
        child: FloatingActionButton.extended(
          heroTag: 'fab_cad',
          onPressed: _mostrarNuevaEmergencia,
          backgroundColor: _kPink,
          icon: const Icon(Icons.add_alert_rounded, color: Colors.white),
          label: const Text('NUEVA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }
  Widget _zoomBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
      ),
      child: Icon(icon, size: 20, color: _kNavy),
    ),
  );
  void _mostrarNuevoVehiculo() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          child: _FormNuevoVehiculo(
            empresaId: widget.empresaId,
            numActuales: _vehiculos.length,
            onCreado: (nombre) => FluxToast.exito(context, '$nombre añadido a la flota'),
          ),
        ),
      ),
    );
  }
  void _mostrarNuevaEmergencia() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 740),
          child: _FormNuevaEmergencia(
            empresaId: widget.empresaId,
            pickedCoords: _pickedCoords,
            onPickCoords: () {
              Navigator.pop(context);
              setState(() => _pickingCoords = true);
            },
            onCreada: (alertaId) async {
              FluxToast.exito(context, 'Emergencia creada — Calculando despacho...');
              try {
                final doc = await FirebaseFirestore.instance
                    .collection('empresas').doc(widget.empresaId)
                    .collection('alertas_despacho').doc(alertaId).get();
                if (!_disposed && mounted && doc.exists) {
                  _abrirDespacho({...doc.data()!, 'id': alertaId});
                }
              } catch (_) {}
            },
          ),
        ),
      ),
    );
  }
  Widget _kpiChip(String valor, String label, Color color) => Container(
    margin: const EdgeInsets.only(right: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(valor, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: TextStyle(fontSize: 8, color: color.withValues(alpha: 0.8))),
    ]),
  );
}
// ── Panel de vehículos (idéntico a la web demo) ─────────────────────────────
class _PanelVehiculos extends StatelessWidget {
  final List<SimVehiculo> sims;
  final List<VehiculoCAD> vehiculos;
  final String? selectedId;
  final Map<String, dynamic>? selectedAlerta;
  final bool simRunning;
  final Map<String, DateTime> estimatedArrival;
  final Map<String, DateTime> dispatchTime;
  final void Function(String id) onSelect;
  final VoidCallback? onNuevoVehiculo;
  final VoidCallback onToggleSim;
  const _PanelVehiculos({
    required this.sims, required this.vehiculos, required this.selectedId,
    required this.selectedAlerta, required this.simRunning,
    required this.estimatedArrival, required this.dispatchTime,
    required this.onSelect, required this.onToggleSim, this.onNuevoVehiculo,
  });
  @override
  Widget build(BuildContext context) {
    // Merge sim state with vehicle metadata from Firestore
    final metaMap = { for (final v in vehiculos) v.id: v };
    final alerta = selectedAlerta;
    final alertaLat = alerta != null ? (alerta['lat'] as num?)?.toDouble() : null;
    final alertaLng = alerta != null ? (alerta['lng'] as num?)?.toDouble() : null;
    return Container(
      color: _kSurf,
      foregroundDecoration: const BoxDecoration(
        border: Border(right: BorderSide(color: _kBorder)),
      ),
      child: Column(children: [
        // Header — estilo web demo
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          color: const Color(0xFFF8FAFC),
          child: Row(children: [
            const Text('VEHÍCULOS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.8)),
            const Spacer(),
            Text('${sims.isNotEmpty ? sims.length : vehiculos.length}', style: const TextStyle(fontSize: 10, color: _kSub)),
            const SizedBox(width: 8),
            // Control simulación
            GestureDetector(
              onTap: onToggleSim,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: simRunning ? _kGreen.withValues(alpha: 0.12) : _kAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: simRunning ? _kGreen.withValues(alpha: 0.4) : _kAmber.withValues(alpha: 0.4)),
                ),
                child: Icon(simRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 14, color: simRunning ? _kGreen : _kAmber),
              ),
            ),
            if (onNuevoVehiculo != null) ...[
              const SizedBox(width: 5),
              GestureDetector(
                onTap: onNuevoVehiculo,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: _kTeal.withValues(alpha: 0.35)),
                  ),
                  child: const Text('+ Añadir', style: TextStyle(fontSize: 10, color: _kTeal, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: sims.isNotEmpty ? sims.length : vehiculos.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final sim = sims.isNotEmpty ? sims[i] : null;
              final meta = sim != null ? metaMap[sim.id] : vehiculos[i];
              final id = sim?.id ?? vehiculos[i].id;
              final nombre = meta?.nombre ?? id;
              final tipo = meta?.tipo ?? 'SVB';
              final zona = meta?.zona ?? '-';
              final estado = sim?.estado ?? meta?.estado ?? EstadoVehiculo.disponible;
              final speed = sim?.speed ?? meta?.velocidad ?? 0;
              final heading = sim?.heading ?? meta?.rumbo ?? 0;
              final tripulacion = meta?.tripulacion ?? [];
              final isSel = id == selectedId;
              final color = _stateColor(estado);
              final isPulsing = estado == EstadoVehiculo.enRoute || estado == EstadoVehiculo.atendiendo;
              // ETA to selected emergency
              double? distKm;
              double? etaMin;
              if (alertaLat != null && alertaLng != null && estado == EstadoVehiculo.disponible) {
                final simPos = sim?.posicion ?? LatLng(meta?.lat ?? 40.6333, meta?.lng ?? -3.1667);
                final dLatKm = (alertaLat - simPos.latitude) * 111.32;
                final dLngKm = (alertaLng - simPos.longitude) * 111.32 *
                    math.cos(simPos.latitude * math.pi / 180);
                distKm = math.sqrt(dLatKm * dLatKm + dLngKm * dLngKm) * 1.35;
                etaMin = (distKm / 50) * 60;
              }
              return InkWell(
                onTap: () => onSelect(id),
                child: Container(
                  padding: EdgeInsets.fromLTRB(isSel ? 9 : 12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: isSel ? _kTeal.withValues(alpha: 0.07) : null,
                    border: isSel ? const Border(left: BorderSide(color: _kTeal, width: 3)) : null,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Row 1: dot + id + type badge + state badge
                    Row(children: [
                      _Dot(color: color, pulse: isPulsing),
                      const SizedBox(width: 8),
                      Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(4)),
                        child: Text(tipo, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text(estado.label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    // Row 2: speed + zone + GPS age
                    Row(children: [
                      Icon(Icons.speed, size: 11, color: _kSub),
                      const SizedBox(width: 4),
                      Text('${speed.toStringAsFixed(0)} km/h · $zona',
                          style: const TextStyle(fontSize: 11, color: _kSub)),
                      const Spacer(),
                      Icon(Icons.gps_fixed, size: 10, color: _kGreen),
                      const SizedBox(width: 3),
                      Text('GPS', style: const TextStyle(fontSize: 10, color: _kGreen)),
                    ]),
                    // Row 3: heading
                    if (estado != EstadoVehiculo.offline) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.navigation, size: 11, color: _kSub),
                        const SizedBox(width: 4),
                        Text('${heading.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 10, color: _kSub)),
                        if (sim != null) ...[
                          Text(' · ${sim.lat.toStringAsFixed(4)}, ${sim.lng.toStringAsFixed(4)}',
                              style: const TextStyle(fontSize: 9, color: _kSub, fontFamily: 'monospace')),
                        ],
                      ]),
                    ],
                    // ETA countdown para vehículos en ruta
                    if (estado == EstadoVehiculo.enRoute) ...[
                      const SizedBox(height: 6),
                      Builder(builder: (_) {
                        final eta      = estimatedArrival[id];
                        final dispatch = dispatchTime[id];
                        if (eta == null || dispatch == null) return const SizedBox.shrink();
                        final remaining = eta.difference(DateTime.now());
                        final totalSecs = eta.difference(dispatch).inSeconds;
                        final secsLeft  = remaining.inSeconds.clamp(0, 3600);
                        final m = secsLeft ~/ 60;
                        final s = secsLeft % 60;
                        final timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
                        final progress = totalSecs > 0
                            ? (1.0 - secsLeft / totalSecs).clamp(0.0, 1.0)
                            : 1.0;
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.timer_outlined, size: 11, color: _kBlue),
                            const SizedBox(width: 4),
                            const Text('ETA  ', style: TextStyle(fontSize: 10, color: _kSub)),
                            Text(timeStr,
                                style: const TextStyle(fontSize: 11, color: _kBlue,
                                    fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                            const Spacer(),
                            Text('${(progress * 100).toStringAsFixed(0)}%',
                                style: TextStyle(fontSize: 9, color: _kBlue.withValues(alpha: 0.7))),
                          ]),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: _kBorder,
                              color: _kBlue,
                              minHeight: 3,
                            ),
                          ),
                        ]);
                      }),
                    ],
                    // ETA metrics — igual a web demo
                    if (distKm != null && etaMin != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        _MetricBox(val: '${distKm.toStringAsFixed(1)} km', lbl: 'Distancia'),
                        const SizedBox(width: 6),
                        _MetricBox(val: '${etaMin.toStringAsFixed(0)} min', lbl: 'ETA estimado',
                            valColor: etaMin < 5 ? _kGreen : etaMin < 10 ? _kAmber : _kRed),
                      ]),
                    ],
                    // Crew chips
                    if (isSel && tripulacion.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 4, runSpacing: 3,
                        children: tripulacion.map((c) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _kBorder),
                          ),
                          child: Text(c, style: const TextStyle(fontSize: 9, color: _kSub)),
                        )).toList(),
                      ),
                    ],
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
  static Color _stateColor(EstadoVehiculo e) => switch (e) {
    EstadoVehiculo.disponible  => _kGreen,
    EstadoVehiculo.enRoute     => _kBlue,
    EstadoVehiculo.atendiendo  => _kAmber,
    EstadoVehiculo.regresando  => const Color(0xFF8B5CF6),
    EstadoVehiculo.offline     => _kSub,
  };
}
// ── Panel derecho: emergencias + historial (idéntico a web demo) ─────────────
class _PanelDerecho extends StatelessWidget {
  final List<Map<String, dynamic>> alertas;
  final List<_HistEntry> history;
  final String? selectedId;
  final void Function(Map<String, dynamic>) onSelect;
  final void Function(Map<String, dynamic>) onDespachar;
  final void Function() onNuevaEmergencia;
  final String empresaId;
  const _PanelDerecho({
    required this.alertas, required this.history, required this.selectedId,
    required this.onSelect, required this.onDespachar,
    required this.onNuevaEmergencia, required this.empresaId,
  });
  @override
  Widget build(BuildContext context) {
    final activas   = alertas.where((a) => a['estado'] != 'atendida' && a['estado'] != 'completada').toList();
    final resueltas = alertas.where((a) => a['estado'] == 'atendida' || a['estado'] == 'completada').toList();
    return Container(
      color: _kSurf,
      foregroundDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _kBorder)),
      ),
      child: Column(children: [
        // ── Emergencias (60% del panel) ────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          color: const Color(0xFFF8FAFC),
          child: Row(children: [
            const Text('EMERGENCIAS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.8)),
            const Spacer(),
            Text('${activas.length} activas', style: const TextStyle(fontSize: 10, color: _kSub)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onNuevaEmergencia,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _kPink, borderRadius: BorderRadius.circular(7)),
                child: const Text('+ NUEVA', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        Flexible(
          flex: 6,
          child: ListView(children: [
            if (activas.isEmpty)
              const Padding(padding: EdgeInsets.all(20),
                child: Text('Sin emergencias activas', textAlign: TextAlign.center, style: TextStyle(color: _kSub, fontSize: 12))),
            ...activas.map((a) => _AlertaCard(
              alerta: a, isSel: a['id'] == selectedId,
              onTap: () => onSelect(a), onDespachar: () => onDespachar(a),
            )),
            if (resueltas.isNotEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                child: Text('RESUELTAS (${resueltas.length})', style: const TextStyle(fontSize: 9, color: _kSub, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
              ...resueltas.take(3).map((a) => _AlertaCard(
                alerta: a, isSel: false, onTap: () => onSelect(a), onDespachar: null, dimmed: true,
              )),
            ],
          ]),
        ),
        // ── Historial (40% del panel) — igual que web demo ─────────────────
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
          color: const Color(0xFFF8FAFC),
          child: const Text('ACTIVIDAD RECIENTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.8)),
        ),
        const Divider(height: 1),
        Flexible(
          flex: 4,
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (_, i) {
              final e = history[i];
              final icon = switch (e.cat) {
                'emergency' => '●',
                'dispatch'  => '→',
                'arrival'   => '◎',
                'resolved'  => '✓',
                _           => '·',
              };
              final color = switch (e.cat) {
                'emergency' => _kRed,
                'dispatch'  => _kBlue,
                'arrival'   => _kAmber,
                'resolved'  => _kGreen,
                _           => _kSub,
              };
              final timeStr = '${e.ts.hour.toString().padLeft(2,'0')}:${e.ts.minute.toString().padLeft(2,'0')}:${e.ts.second.toString().padLeft(2,'0')}';
              return Container(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(timeStr, style: const TextStyle(fontSize: 9, color: _kSub, fontFamily: 'monospace')),
                  const SizedBox(width: 6),
                  Text(icon, style: const TextStyle(fontSize: 11)),
                  const SizedBox(width: 5),
                  Expanded(child: Text(e.msg, style: TextStyle(fontSize: 11, color: color, height: 1.3))),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
class _AlertaCard extends StatelessWidget {
  final Map<String, dynamic> alerta;
  final bool isSel;
  final bool dimmed;
  final VoidCallback onTap;
  final VoidCallback? onDespachar;
  const _AlertaCard({required this.alerta, required this.isSel, required this.onTap, required this.onDespachar, this.dimmed = false});
  @override
  Widget build(BuildContext context) {
    final tipo    = alerta['tipo_codigo'] as String? ?? '-';
    final prio    = alerta['prioridad']  as String? ?? 'alta';
    final dir     = alerta['direccion']  as String? ?? '-';
    final amb     = alerta['ambulancia_asignada'] as String?;
    final estado  = alerta['estado'] as String? ?? 'pendiente';
    final ts      = (alerta['fecha_hora'] as Timestamp?)?.toDate();
    final elapsed = ts != null ? DateTime.now().difference(ts) : Duration.zero;
    final elStr   = elapsed.inMinutes > 0 ? '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s' : '${elapsed.inSeconds}s';
    final prioColor   = prio == 'critica' ? _kRed : prio == 'alta' ? const Color(0xFFF97316) : _kAmber;
    final estadoColor = estado == 'pendiente' ? _kAmber : estado == 'aceptada' || estado == 'activa' ? _kBlue : _kGreen;
    return Opacity(
      opacity: dimmed ? 0.5 : 1.0,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(isSel ? 9 : 12, 10, 12, 10),
          decoration: BoxDecoration(
            color: isSel ? _kRed.withValues(alpha: 0.04) : null,
            border: isSel ? const Border(left: BorderSide(color: _kRed, width: 3)) : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _Dot(color: prioColor, pulse: prio == 'critica' && !dimmed, size: 10),
              const SizedBox(width: 6),
              Flexible(child: Text(tipo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: prioColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Text(prio.toUpperCase(), style: TextStyle(fontSize: 8, color: prioColor, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined, size: 10, color: _kSub),
                const SizedBox(width: 2),
                Text(elStr, style: const TextStyle(fontSize: 10, color: _kSub)),
              ]),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 11, color: _kSub),
              const SizedBox(width: 3),
              Expanded(child: Text(dir, style: const TextStyle(fontSize: 11, color: _kText, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              if (amb != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: _kBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(amb, style: const TextStyle(fontSize: 10, color: _kBlue, fontWeight: FontWeight.w600)),
                )
              else if (onDespachar != null)
                GestureDetector(
                  onTap: onDespachar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _kPink, borderRadius: BorderRadius.circular(7)),
                    child: const Text('DESPACHAR →', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: estadoColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(estado.toUpperCase(), style: TextStyle(fontSize: 9, color: estadoColor, fontWeight: FontWeight.w700)),
              ),
            ]),
            if (estado == 'activa') ...[
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: _kAmber)), const SizedBox(width: 5), const Text('Atendiendo emergencia', style: TextStyle(fontSize: 10, color: _kAmber, fontWeight: FontWeight.w600))]),
            ],
          ]),
        ),
      ),
    );
  }
}
// ── Shared widgets ─────────────────────────────────────────────────────────

class _Dot extends StatefulWidget {
  final Color color;
  final bool pulse;
  final double size;
  const _Dot({required this.color, required this.pulse, this.size = 8});
  @override
  State<_Dot> createState() => _DotState();
}
class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.6, end: 1.4).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) return Container(width: widget.size, height: widget.size, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color));
    return ScaleTransition(
      scale: _anim,
      child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
    );
  }
}
class _MetricBox extends StatelessWidget {
  final String val;
  final String lbl;
  final Color? valColor;
  const _MetricBox({required this.val, required this.lbl, this.valColor});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: [
        Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: valColor ?? _kNavy)),
        Text(lbl, style: const TextStyle(fontSize: 8, color: _kSub)),
      ]),
    ),
  );
}
// ── Modal de despacho con recomendaciones OSRM ─────────────────────────────
class _DispatchModal extends StatefulWidget {
  final Map<String, dynamic> alerta;
  final List<RecomendacionDespacho> recomendaciones;
  final void Function(RecomendacionDespacho) onDespachar;
  const _DispatchModal({required this.alerta, required this.recomendaciones, required this.onDespachar});
  @override
  State<_DispatchModal> createState() => _DispatchModalState();
}
class _DispatchModalState extends State<_DispatchModal> {
  int _selIdx = 0;
  @override
  void initState() {
    super.initState();
    // Seleccionar primera opci?n disponible
    _selIdx = widget.recomendaciones.indexWhere((r) => r.disponible);
    if (_selIdx < 0) _selIdx = 0;
  }
  @override
  Widget build(BuildContext context) {
    final tipo = widget.alerta['tipo_codigo'] as String? ?? '-';
    final dir  = widget.alerta['direccion']  as String? ?? '-';
    final prio = widget.alerta['prioridad']  as String? ?? 'alta';
    final prioColor = prio == 'critica' ? _kRed : prio == 'alta' ? const Color(0xFFF97316) : _kAmber;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            decoration: BoxDecoration(
              color: _kNavy,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.local_hospital_rounded, size: 24, color: _kTeal),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Asignación de ambulancia',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Algoritmo inteligente · ${widget.recomendaciones.where((r) => r.disponible).length} unidades disponibles',
                      style: const TextStyle(color: Color(0xFF00FFC8), fontSize: 10)),
                ]),
              ),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          // Emergencia resumen
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: prioColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: prioColor.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: prioColor)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$tipo - ${prio.toUpperCase()}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: prioColor)),
                Text(dir, style: const TextStyle(fontSize: 11, color: _kSub)),
              ])),
            ]),
          ),
          // Lista recomendaciones
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              itemCount: widget.recomendaciones.length,
              itemBuilder: (_, i) {
                final rec = widget.recomendaciones[i];
                final isSel = i == _selIdx && rec.disponible;
                final isFirst = i == 0 && rec.disponible;
                return GestureDetector(
                  onTap: rec.disponible ? () => setState(() => _selIdx = i) : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? _kTeal : _kBorder,
                        width: isSel ? 2 : 1,
                      ),
                      color: isSel ? _kTeal.withValues(alpha: 0.08)
                          : !rec.disponible ? const Color(0xFFF8FAFC)
                          : _kSurf,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        if (isFirst) Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(4)),
                          child: const Text('★ RECOMENDADA', style: TextStyle(fontSize: 8, color: Color(0xFF00FFC8), fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        ),
                        Text(rec.vehiculo.nombre, style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800,
                          color: rec.disponible ? _kText : _kSub,
                        )),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: _kNavy, borderRadius: BorderRadius.circular(4)),
                          child: Text(rec.vehiculo.tipo, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                        const Spacer(),
                        Text(rec.disponible ? '- Disponible' : '- ${rec.razonNoDisponible}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                color: rec.disponible ? _kGreen : _kSub)),
                      ]),
                      if (rec.disponible) ...[
                        if (!rec.compatibleTipo) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.warning_amber_rounded, size: 11, color: _kAmber),
                            const Text('SVB para PCR/IAM', style: TextStyle(fontSize: 10, color: _kAmber, fontWeight: FontWeight.w600)),
                          ]),
                        ],
                        const SizedBox(height: 8),
                        Row(children: [
                          _metricBox(_fmtDist(rec.ruta.distanceKm), 'DISTANCIA'),
                          const SizedBox(width: 6),
                          _metricBox(_fmtEta(rec.ruta.etaMinutes), 'ETA ESTIMADO*',
                              color: rec.ruta.etaMinutes < 2 ? _kGreen : rec.ruta.etaMinutes < 6 ? _kAmber : _kRed),
                          const SizedBox(width: 6),
                          _metricBox(_fmtDist(_haversineModal(
                            rec.vehiculo.lat, rec.vehiculo.lng,
                            (widget.alerta['lat'] as num?)?.toDouble() ?? 40.6333,
                            (widget.alerta['lng'] as num?)?.toDouble() ?? -3.1667,
                          )), 'DISTANCIA DIRECTA', color: _kSub),
                        ]),
                        const SizedBox(height: 4),
                        Text(rec.vehiculo.tripulacion.join(' - '),
                            style: const TextStyle(fontSize: 10, color: _kSub)),
                      ],
                    ]),
                  ),
                );
              },
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  '* ETA calculado con factor de ruta urbana ×1.35 - 50-60 km/h con prioridad',
                  style: TextStyle(fontSize: 9, color: _kSub, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                )),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selIdx >= 0 && widget.recomendaciones[_selIdx].disponible
                        ? () => widget.onDespachar(widget.recomendaciones[_selIdx])
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPink, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('ASIGNAR EMERGENCIA', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
  static double _haversineModal(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
  static String _fmtDist(double km) =>
      km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';
  static String _fmtEta(double min) =>
      min < 1 ? '< 1 min' : '${min.round()} min';
  Widget _metricBox(String val, String label, {Color? color}) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kBorder),
      ),
      child: Column(children: [
        Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color ?? _kNavy)),
        Text(label, style: const TextStyle(fontSize: 9, color: _kSub)),
      ]),
    ),
  );
}
// ── Formulario nueva emergencia ─────────────────────────────────────────────
class _FormNuevaEmergencia extends StatefulWidget {
  final String empresaId;
  final LatLng? pickedCoords;
  final VoidCallback onPickCoords;
  final void Function(String alertaId) onCreada;
  const _FormNuevaEmergencia({
    required this.empresaId, required this.pickedCoords,
    required this.onPickCoords, required this.onCreada,
  });
  @override
  State<_FormNuevaEmergencia> createState() => _FormNuevaEmergenciaState();
}
class _FormNuevaEmergenciaState extends State<_FormNuevaEmergencia> {
  String _tipo = 'GENERAL';
  String _prioridad = 'alta';
  final _dirCtrl  = TextEditingController();
  final _descCtrl = TextEditingController();
  int _pacientes = 1;
  bool _guardando = false;
  final Set<String> _recursos = {};
  static const _tipos = ['PCR', 'IAM', 'TCE', 'ACCIDENT', 'RESPIRATORY', 'GENERAL'];
  static const _tiposLabel = {
    'PCR': 'PCR - Parada cardiorrespiratoria',
    'IAM': 'IAM - Infarto agudo de miocardio',
    'TCE': 'TCE — Traumatismo craneoencefálico',
    'ACCIDENT': 'Accidente de tr-fico',
    'RESPIRATORY': 'Urgencia respiratoria',
    'GENERAL': 'Urgencia m-dica general',
  };
  static const _tiposChipDesc = {
    'PCR': 'PCR',
    'IAM': 'IAM',
    'TCE': 'TCE',
    'ACCIDENT': 'Accidente de Tr-fico',
    'RESPIRATORY': 'Urgencia Respiratoria',
    'GENERAL': 'Urgencia M-dica General',
  };
  static const _recursosDisponibles = [
    'DEA', 'O2', 'Monitor ECG', 'Monitor card-aco', 'Collar-n',
    'Tabla espinal', 'F-rulas', 'Nitratos', 'Acceso venoso',
    'Incubadora', 'Bomba perfusi-n',
  ];
  @override
  void initState() {
    super.initState();
    _descCtrl.text = _tiposLabel['GENERAL'] ?? '';
  }
  @override
  void dispose() { _dirCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }
  Widget _tipoChipGrid(String t) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() {
        _tipo = t;
        _descCtrl.text = _tiposLabel[t] ?? '';
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _tipo == t ? _kRed : _kBorder, width: _tipo == t ? 1.5 : 1),
          color: _tipo == t ? _kRed.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
              color: _tipo == t ? _kRed : _kText)),
          Text(_tiposChipDesc[t] ?? t, style: const TextStyle(fontSize: 10, color: _kSub)),
        ]),
      ),
    ),
  );
  Future<void> _crear() async {
    if (_dirCtrl.text.trim().isEmpty && widget.pickedCoords == null) {
      FluxToast.error(context, 'Introduce la direcci-n o selecciona en el mapa');
      return;
    }
    setState(() => _guardando = true);
    try {
      final lat = widget.pickedCoords?.latitude  ?? 40.6333;
      final lng = widget.pickedCoords?.longitude ?? -3.1667;
      final ref = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('alertas_despacho').add({
        'tipo_codigo':  _tipo,
        'descripcion':  _descCtrl.text.trim().isEmpty ? (_tiposLabel[_tipo] ?? '') : _descCtrl.text.trim(),
        'recursos':     _recursos.toList(),
        'direccion':    _dirCtrl.text.trim().isEmpty ? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}' : _dirCtrl.text.trim(),
        'localidad':    'Guadalajara',
        'prioridad':    _prioridad,
        'num_pacientes': _pacientes,
        'lat':          lat,
        'lng':          lng,
        'ambulancia_asignada': null,
        'estado':       'pendiente',
        'fecha_hora':   FieldValue.serverTimestamp(),
        'operador_uid': 'cad_admin',
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onCreada(ref.id);
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kSurf,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 16),
          const Text('Nueva Emergencia', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy)),
          const SizedBox(height: 16),
          // ── Tipo - grid 2 columnas con descripci?n
          const Text('TIPO DE EMERGENCIA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Column(
            children: [
              for (int i = 0; i < _tipos.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    _tipoChipGrid(_tipos[i]),
                    const SizedBox(width: 8),
                    if (i + 1 < _tipos.length)
                      _tipoChipGrid(_tipos[i + 1])
                    else
                      const Expanded(child: SizedBox()),
                  ]),
                ),
            ],
          ),
          // ── Prioridad ? botones con dot de color
          const SizedBox(height: 6),
          const Text('PRIORIDAD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(children: [
            for (final p in ['critica', 'alta', 'media']) ...[
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _prioridad = p),
                child: Builder(builder: (_) {
                  final c = p == 'critica' ? _kRed : p == 'alta' ? const Color(0xFFF97316) : _kAmber;
                  final sel = _prioridad == p;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? c : _kBorder),
                      color: sel ? c.withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
                      const SizedBox(width: 6),
                      Text(
                        p == 'critica' ? 'Cr-tica' : p == 'alta' ? 'Alta' : 'Media',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? c : _kSub),
                      ),
                    ]),
                  );
                }),
              )),
              if (p != 'media') const SizedBox(width: 8),
            ],
          ]),
          // ── Ubicaci?n
          const SizedBox(height: 14),
          const Text('UBICACI-N', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          TextField(
            controller: _dirCtrl,
            decoration: const InputDecoration(
              hintText: 'Ej: Av. del Ejército, 15 · Guadalajara',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: widget.onPickCoords,
            child: Row(children: [
              const Text('⬡ ', style: TextStyle(fontSize: 13, color: _kSub)),
              const Text('Haz clic aqu- y luego en el mapa para seleccionar coordenadas',
                  style: TextStyle(fontSize: 11, color: _kSub, decoration: TextDecoration.underline)),
            ]),
          ),
          if (widget.pickedCoords != null) ...[
            const SizedBox(height: 4),
            Text('- ${widget.pickedCoords!.latitude.toStringAsFixed(5)}, ${widget.pickedCoords!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontSize: 11, color: _kGreen, fontFamily: 'monospace')),
          ],
          // ── Pacientes + Recursos en dos columnas
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Pacientes
            SizedBox(
              width: 110,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('N- PACIENTES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Row(children: [
                  SizedBox(
                    width: 32, height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () { if (_pacientes > 1) setState(() => _pacientes--); },
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                    ),
                  ),
                  Text('$_pacientes', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  SizedBox(
                    width: 32, height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => setState(() => _pacientes++),
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                    ),
                  ),
                ]),
              ]),
            ),
            const SizedBox(width: 12),
            // Recursos
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('RECURSOS NECESARIOS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6,
                  children: _recursosDisponibles.map((r) {
                    final sel = _recursos.contains(r);
                    return GestureDetector(
                      onTap: () => setState(() { if (sel) _recursos.remove(r); else _recursos.add(r); }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: sel ? _kRed : _kBorder),
                          color: sel ? _kRed.withValues(alpha: 0.07) : const Color(0xFFF8FAFC),
                        ),
                        child: Text(r, style: TextStyle(
                          fontSize: 11,
                          color: sel ? _kRed : _kSub,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        )),
                      ),
                    );
                  }).toList(),
                ),
              ]),
            ),
          ]),
          // ── Descripci?n
          const SizedBox(height: 14),
          const Text('DESCRIPCI-N', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Descripci-n del incidente...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _guardando ? null : _crear,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _guardando ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
              label: Text(_guardando ? 'Creando...' : 'CREAR EMERGENCIA', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}
// ── Formulario nuevo vehículo ? igual al panel izquierdo de la demo web ───────
class _FormNuevoVehiculo extends StatefulWidget {
  final String empresaId;
  final int numActuales;
  final void Function(String nombre) onCreado;
  const _FormNuevoVehiculo({required this.empresaId, required this.numActuales, required this.onCreado});
  @override
  State<_FormNuevoVehiculo> createState() => _FormNuevoVehiculoState();
}
class _FormNuevoVehiculoState extends State<_FormNuevoVehiculo> {
  String _tipo = 'SVB';
  String _zona = 'Centro';
  final _nombreCtrl = TextEditingController();
  final _matriculaCtrl = TextEditingController();
  final _tripCtrl = TextEditingController();
  bool _guardando = false;
  static const _zonas = ['Hospital', 'Centro', 'Zona Norte', 'Zona Sur', 'Zona Este', 'Av. Castilla', 'Pol-gono', 'Estaci-n'];
  @override
  void initState() {
    super.initState();
    final n = widget.numActuales + 1;
    _nombreCtrl.text = 'AMB-${n.toString().padLeft(2, '0')}';
    _matriculaCtrl.text = '${n.toString().padLeft(4, '0')}-GUA';
  }
  @override
  void dispose() { _nombreCtrl.dispose(); _matriculaCtrl.dispose(); _tripCtrl.dispose(); super.dispose(); }
  Future<void> _crear() async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    try {
      final tripulacion = _tripCtrl.text
          .split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      // Posici-n inicial: centro de Guadalajara con peque?o offset
      final r = (widget.numActuales * 0.003);
      final lat = _kGuadalajaraCenter.latitude  + (r * (widget.numActuales.isOdd ? 1 : -1));
      final lng = _kGuadalajaraCenter.longitude + (r * (widget.numActuales % 3 == 0 ? 1 : -1));
      await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('vehiculos_cad').doc(_nombreCtrl.text.trim()).set({
        'nombre':     _nombreCtrl.text.trim(),
        'tipo':       _tipo,
        'matricula':  _matriculaCtrl.text.trim(),
        'tripulacion': tripulacion,
        'estado':     'disponible',
        'lat':        lat,
        'lng':        lng,
        'velocidad':  0.0,
        'rumbo':      0.0,
        'ultima_gps': FieldValue.serverTimestamp(),
        'zona':       _zona,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onCreado(_nombreCtrl.text.trim());
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 16),
          Row(children: [
            const Text(' Añadir vehículo a la flota', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kNavy)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: _kSub, size: 22),
            ),
          ]),
          const SizedBox(height: 16),
          // Tipo SVB / SVA ? igual que web demo
          const Text('TIPO DE UNIDAD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _tipoChip('SVB', 'Soporte Vital B-sico')),
            const SizedBox(width: 10),
            Expanded(child: _tipoChip('SVA', 'Soporte Vital Avanzado')),
          ]),
          const SizedBox(height: 14),
          // Nombre y matr?cula
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('IDENTIFICADOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              TextField(controller: _nombreCtrl, decoration: const InputDecoration(hintText: 'AMB-06', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10))),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('MATR-CULA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              TextField(controller: _matriculaCtrl, decoration: const InputDecoration(hintText: '0006-GUA', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10))),
            ])),
          ]),
          const SizedBox(height: 14),
          // Zona
          const Text('ZONA DE PATRULLA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6,
            children: _zonas.map((z) => GestureDetector(
              onTap: () => setState(() => _zona = z),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _zona == z ? _kTeal : _kBorder),
                  color: _zona == z ? _kTeal.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
                ),
                child: Text(z, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: _zona == z ? _kNavy : _kSub)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 14),
          // Tripulaci?n
          const Text('TRIPULACIÓN (una por línea)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kSub, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          TextField(
            controller: _tripCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Carlos P-rez (TES)\nAna Molina (TES)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          const Text('La posición GPS inicial se asignará al centro de Guadalajara. El TES actualizará la posición real desde su dispositivo.', style: TextStyle(fontSize: 10, color: _kSub, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: _guardando ? null : _crear,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _guardando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.add_circle_rounded),
              label: Text(_guardando ? 'A-adiendo...' : 'A-ADIR A LA FLOTA',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
  Widget _tipoChip(String tipo, String desc) => GestureDetector(
    onTap: () => setState(() => _tipo = tipo),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _tipo == tipo ? _kNavy : _kBorder, width: _tipo == tipo ? 2 : 1),
        color: _tipo == tipo ? _kNavy.withValues(alpha: 0.06) : const Color(0xFFF8FAFC),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(tipo, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _tipo == tipo ? _kNavy : _kSub)),
          if (_tipo == tipo) ...[const Spacer(), const Icon(Icons.check_circle, color: _kNavy, size: 16)],
        ]),
        Text(desc, style: const TextStyle(fontSize: 10, color: _kSub)),
      ]),
    ),
  );
}

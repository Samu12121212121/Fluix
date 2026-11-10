import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:planeag_flutter/core/config/planes_config.dart';
import 'package:planeag_flutter/services/contenido_web_service.dart';
import 'package:planeag_flutter/core/utils/permisos_service.dart';
import 'package:planeag_flutter/core/widgets/fluix_app_bar.dart';
import 'package:planeag_flutter/features/dashboard/pantallas/web_modulos_config_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO LOCAL
// ─────────────────────────────────────────────────────────────────────────────

class _CuentaCliente {
  final String empresaId;
  final String nombre;
  final String email;
  final String tipoNegocio;
  final String planId;
  final String planNombre;
  final String estado;
  final DateTime? fechaFin;
  final bool activa;
  // ── Campos V2 ──
  final List<String> packsActivos;
  final List<String> addonsActivos;
  final int empleadosNomina;
  final double precioTotal;
  /// Precio mensual pactado manualmente (sobreescribe precioTotal en los cálculos).
  final double? precioManual;

  /// Precio efectivo para cálculos: usa el manual si está fijado, si no el calculado.
  double get precioEfectivo => (precioManual != null && precioManual! > 0) ? precioManual! : precioTotal;
  bool get tienePrecioManual => precioManual != null && precioManual! > 0;

  const _CuentaCliente({
    required this.empresaId,
    required this.nombre,
    required this.email,
    required this.tipoNegocio,
    required this.planId,
    required this.planNombre,
    required this.estado,
    required this.fechaFin,
    required this.activa,
    this.packsActivos = const [],
    this.addonsActivos = const [],
    this.empleadosNomina = 0,
    this.precioTotal = 0,
    this.precioManual,
  });

  factory _CuentaCliente.fromMap(Map<String, dynamic> m) {
    return _CuentaCliente(
      empresaId: m['empresaId'] as String? ?? '',
      nombre: m['nombre'] as String? ?? '—',
      email: m['email'] as String? ?? '',
      tipoNegocio: m['tipoNegocio'] as String? ?? '',
      planId: m['planId'] as String? ?? 'sin_plan',
      planNombre: m['planNombre'] as String? ?? 'Sin plan',
      estado: m['estado'] as String? ?? 'DESCONOCIDO',
      fechaFin: m['fechaFin'] != null
          ? DateTime.tryParse(m['fechaFin'].toString())
          : null,
      activa: m['activa'] as bool? ?? false,
      packsActivos: _parseStringList(m['packsActivos']),
      addonsActivos: _parseStringList(m['addonsActivos']),
      empleadosNomina: (m['empleadosNomina'] as num?)?.toInt() ?? 0,
      precioTotal: (m['precioTotal'] as num?)?.toDouble() ?? 0,
      precioManual: (m['precioManual'] as num?)?.toDouble(),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String && value.isNotEmpty) return [value];
    return [];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLANES — Ahora se leen desde PlanesConfig (core/config/planes_config.dart)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class GestionarCuentasScreen extends StatefulWidget {
  final SesionUsuario? sesion;
  final bool embedded;
  const GestionarCuentasScreen({super.key, this.sesion, this.embedded = false});

  @override
  State<GestionarCuentasScreen> createState() => _GestionarCuentasScreenState();
}

class _GestionarCuentasScreenState extends State<GestionarCuentasScreen> {
  List<_CuentaCliente> _cuentas = [];
  bool _cargando = true;
  String? _error;
  StreamSubscription<QuerySnapshot>? _sub;

  @override
  void initState() {
    super.initState();
    _iniciarStream();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Stream en tiempo real ──────────────────────────────────────────────────

  void _iniciarStream() {
    setState(() { _cargando = true; _error = null; });
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('empresas')
        .snapshots()
        .listen(_onEmpresasSnap, onError: _onStreamError);
  }

  Future<void> _onEmpresasSnap(QuerySnapshot snap) async {
    if (!mounted) return;
    try {
      // Leer todas las suscripciones en paralelo (no secuencial)
      final futures = snap.docs.map(_cargarDatosEmpresa).toList();
      final resultados = await Future.wait(futures);
      final cuentas = resultados.whereType<_CuentaCliente>().toList();
      if (mounted) setState(() { _cuentas = cuentas; _cargando = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Error procesando datos: $e'; _cargando = false; });
    }
  }

  void _onStreamError(dynamic e) {
    debugPrint('⚠️ Error stream empresas: $e');
    if (mounted) setState(() { _error = 'Error de conexión: $e'; _cargando = false; });
  }

  Future<_CuentaCliente?> _cargarDatosEmpresa(QueryDocumentSnapshot doc) async {
    try {
      final empresaData = doc.data() as Map<String, dynamic>;
      final empresaId = doc.id;

      final suscripcionDoc = await FirebaseFirestore.instance
          .collection('empresas').doc(empresaId)
          .collection('suscripcion').doc('actual').get();

      DateTime? fechaFin;
      String planId = 'free';
      String planNombre = 'Plan Gratuito';
      String estado = 'activa';
      bool activa = true;
      List<String> packsActivos = [];
      List<String> addonsActivos = [];
      double precioTotal = 0;
      double? precioManual;

      if (suscripcionDoc.exists) {
        final subData = suscripcionDoc.data()!;
        planId = subData['plan'] as String? ?? subData['plan_id'] as String? ?? 'free';
        planNombre = subData['plan_nombre'] as String? ?? 'Plan Gratuito';
        estado = subData['estado'] as String? ?? 'activa';
        activa = estado.toUpperCase() == 'ACTIVA';
        final fechaFinTs = subData['fecha_fin'] as Timestamp?;
        fechaFin = fechaFinTs?.toDate();
        packsActivos = (subData['packs_activos'] as List?)?.cast<String>() ?? [];
        addonsActivos = (subData['addons_activos'] as List?)?.cast<String>() ?? [];
        precioTotal = (subData['precio_total'] as num?)?.toDouble() ?? 0;
        precioManual = (subData['precio_manual'] as num?)?.toDouble();
      }

      int empleadosNomina = 0;
      if (addonsActivos.contains('addon_nominas') || addonsActivos.contains('nominas')) {
        final empSnap = await FirebaseFirestore.instance
            .collection('empresas').doc(empresaId)
            .collection('empleados').get();
        empleadosNomina = empSnap.docs.length;
      }

      return _CuentaCliente(
        empresaId: empresaId,
        nombre: empresaData['nombre'] as String? ?? 'Sin nombre',
        email: empresaData['email'] as String? ?? '',
        tipoNegocio: empresaData['tipo_negocio'] as String? ?? '',
        planId: planId,
        planNombre: planNombre,
        estado: estado,
        fechaFin: fechaFin,
        activa: activa,
        packsActivos: packsActivos,
        addonsActivos: addonsActivos,
        empleadosNomina: empleadosNomina,
        precioTotal: precioTotal,
        precioManual: precioManual,
      );
    } catch (e) {
      debugPrint('⚠️ Error empresa ${doc.id}: $e');
      return null;
    }
  }

  // ── Recarga manual ─────────────────────────────────────────────────────────

  Future<void> _cargarCuentas() async => _iniciarStream();

  // ── Abrir formulario nueva cuenta ──────────────────────────────────────────

  Future<void> _abrirFormNuevaCuenta() async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FormNuevaCuenta(),
    );
    if (resultado == true) _cargarCuentas();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final bg    = dark ? const Color(0xFF0A0F23) : const Color(0xFFF5F7FA);
    final barBg = dark ? const Color(0xFF0A0F23) : Colors.white;
    final textC = dark ? Colors.white : const Color(0xFF0F172A);
    final border= dark ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0);
    final accent = const Color(0xFF7C3AED);

    Widget body = DefaultTabController(
      length: 2,
      child: Stack(
        children: [
          Column(
            children: [
              // ── Tabs ──────────────────────────────────────────────────────
              Container(
                color: barBg,
                child: TabBar(
                  labelColor: accent,
                  unselectedLabelColor: dark ? const Color(0xFF7B8099) : Colors.grey,
                  indicatorColor: accent,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Estadísticas'),
                    Tab(icon: Icon(Icons.business, size: 18), text: 'Cuentas'),
                  ],
                ),
              ),
              // ── Contenido ────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  children: [
                    _PanelEstadisticas(cuentas: _cuentas, cargando: _cargando),
                    _buildBody(),
                  ],
                ),
              ),
            ],
          ),
          // ── FAB (solo en tab Cuentas) ─────────────────────────────────────
          Builder(
            builder: (ctx) {
              final tabController = DefaultTabController.of(ctx);
              return AnimatedBuilder(
                animation: tabController,
                builder: (_, __) => tabController.index == 1
                    ? Positioned(
                        bottom: 16,
                        right: 16,
                        child: FloatingActionButton.extended(
                          heroTag: 'fab_nueva_cuenta',
                          onPressed: _abrirFormNuevaCuenta,
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Nueva cuenta'),
                        ),
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      backgroundColor: bg,
      appBar: FluixAppBar(
        titulo: 'Gestión de cuentas',
        extraActions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _cargarCuentas,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarCuentas,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (_cuentas.isEmpty) {
      return const Center(
        child: Text('No hay cuentas de clientes aún',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _cuentas.length,
      itemBuilder: (_, i) => _TarjetaCuenta(cuenta: _cuentas[i]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Banner info pago web
// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Tarjeta de cuenta
// ─────────────────────────────────────────────────────────────────────────────

class _TarjetaCuenta extends StatelessWidget {
  final _CuentaCliente cuenta;

  const _TarjetaCuenta({required this.cuenta});

  Color get _colorPlan {
    if (cuenta.packsActivos.isNotEmpty || cuenta.addonsActivos.isNotEmpty) {
      return const Color(0xFF7B1FA2);
    }
    return const Color(0xFF1976D2);
  }

  String get _planLabel {
    final partes = <String>['Base'];
    for (final p in cuenta.packsActivos) {
      final pack = PlanesConfig.todosPacks.where((pk) => pk.id == p).firstOrNull;
      if (pack != null) partes.add(pack.nombre.replaceAll('Pack ', ''));
    }
    for (final a in cuenta.addonsActivos) {
      final addon = PlanesConfig.todosAddons.where((ad) => ad.id == a).firstOrNull;
      if (addon != null) partes.add(addon.nombre);
    }
    return partes.join(' + ');
  }

  Color get _colorEstado {
    switch (cuenta.estado) {
      case 'ACTIVA': return Colors.green;
      case 'VENCIDA': return Colors.red;
      case 'POR_VENCER': return Colors.orange;
      default: return Colors.grey;
    }
  }

  String get _diasRestantes {
    if (cuenta.fechaFin == null) return '—';
    final diff = cuenta.fechaFin!.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Vencida';
    if (diff == 0) return 'Vence hoy';
    return '$diff días restantes';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fila principal
            Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _colorPlan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      cuenta.nombre.isNotEmpty ? cuenta.nombre[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _colorPlan,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cuenta.nombre,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cuenta.email,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Badge plan
                Flexible(
                  fit: FlexFit.loose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _colorPlan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _colorPlan.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _planLabel,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _colorPlan),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Botón Google Reviews
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _abrirGoogleReviews(context),
                icon: const Icon(Icons.star_rate_rounded, size: 16, color: Color(0xFFF57F17)),
                label: const Text('Google Reseñas'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF57F17),
                  side: const BorderSide(color: Color(0xFFF57F17)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Botón Script Web (Hostinger Integrations)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _copiarScriptHostinger(context),
                icon: const Icon(Icons.integration_instructions, size: 16, color: Color(0xFF455A64)),
                label: const Text('Script Hostinger'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF455A64),
                  side: const BorderSide(color: Color(0xFF455A64)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Botón precio mensual manual
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _editarPrecio(context),
                icon: Icon(
                  cuenta.tienePrecioManual ? Icons.euro_rounded : Icons.euro_outlined,
                  size: 16,
                  color: cuenta.tienePrecioManual ? const Color(0xFF2E7D32) : const Color(0xFF455A64),
                ),
                label: Text(
                  cuenta.tienePrecioManual
                      ? 'Precio: ${cuenta.precioManual!.toStringAsFixed(0)} €/mes'
                      : 'Fijar precio mensual',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: cuenta.tienePrecioManual ? const Color(0xFF2E7D32) : const Color(0xFF455A64),
                  side: BorderSide(color: cuenta.tienePrecioManual ? const Color(0xFF2E7D32) : const Color(0xFF455A64)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Botón selector de módulos
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _abrirSelectorModulos(context),
                icon: const Icon(Icons.extension_outlined, size: 16, color: Color(0xFF1565C0)),
                label: const Text('Módulos activos'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Botón configuración módulos web
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WebModulosConfigScreen(
                      empresaId: cuenta.empresaId,
                      nombreEmpresa: cuenta.nombre,
                    ),
                  ),
                ),
                icon: const Icon(Icons.web_rounded, size: 16, color: Color(0xFF059669)),
                label: const Text('Módulos web'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF059669),
                  side: const BorderSide(color: Color(0xFF059669)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            // Fila info
            Row(
              children: [
                _chip(Icons.circle, cuenta.estado, _colorEstado),
                const SizedBox(width: 8),
                _chip(
                  Icons.calendar_today,
                  cuenta.fechaFin != null ? fmt.format(cuenta.fechaFin!) : '—',
                  Colors.grey[600]!,
                ),
                const Spacer(),
                Text(
                  _diasRestantes,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cuenta.estado == 'VENCIDA' ? Colors.red : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _abrirGoogleReviews(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _DialogGoogleReviews(
          empresaId: cuenta.empresaId, nombreEmpresa: cuenta.nombre),
    );
  }

  void _editarPrecio(BuildContext context) {
    final ctrl = TextEditingController(
      text: cuenta.tienePrecioManual ? cuenta.precioManual!.toStringAsFixed(2) : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Precio mensual — ${cuenta.nombre}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'Precio calculado por packs: ${cuenta.precioTotal.toStringAsFixed(0)} €/mes\n'
            'Deja vacío para usar el calculado automáticamente.',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio real (€/mes)',
              suffixText: '€',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
        ]),
        actions: [
          if (cuenta.tienePrecioManual)
            TextButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('empresas').doc(cuenta.empresaId)
                    .collection('suscripcion').doc('actual')
                    .update({'precio_manual': FieldValue.delete()});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Quitar manual', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (val != null && val > 0) {
                await FirebaseFirestore.instance
                    .collection('empresas').doc(cuenta.empresaId)
                    .collection('suscripcion').doc('actual')
                    .update({'precio_manual': val});
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _abrirSelectorModulos(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormSelectorModulos(cuenta: cuenta),
    );
  }

  void _copiarScriptHostinger(BuildContext context) {
    final svc = ContenidoWebService();
    final script = svc.generarScriptHostinger(cuenta.empresaId);
    Clipboard.setData(ClipboardData(text: script));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(children: [
        Icon(Icons.check_circle, color: Colors.white, size: 18),
        SizedBox(width: 8),
        Expanded(child: Text('Script Hostinger copiado — pegar en Integrations')),
      ]),
      backgroundColor: Color(0xFF455A64),
      duration: Duration(seconds: 3),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET: Formulario nueva cuenta
// ─────────────────────────────────────────────────────────────────────────────

class _FormNuevaCuenta extends StatefulWidget {
  const _FormNuevaCuenta();

  @override
  State<_FormNuevaCuenta> createState() => _FormNuevaCuentaState();
}

class _FormNuevaCuentaState extends State<_FormNuevaCuenta> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _propietarioCtrl = TextEditingController();
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  final Set<String> _modulosSeleccionados = {
    'dashboard', 'reservas', 'clientes', 'servicios',
    'empleados', 'valoraciones', 'estadisticas', 'contenido_web', 'app',
  };

  String _tipoNegocio = 'Peluquería / Estética';
  bool _creando = false;
  bool _passwordVisible = false;

  final _tiposNegocio = [
    'Peluquería / Estética',
    'Restaurante / Bar',
    'Clínica / Salud',
    'Spa / Masajes',
    'Gimnasio / Fitness',
    'Taller / Reparaciones',
    'Tienda / Comercio',
    'Construcción / Obra',
    'Otro',
  ];

  /// Si no hay email, genera uno técnico único para Firebase Auth.
  String _resolverEmail(String nombre) {
    final raw = _emailCtrl.text.trim().toLowerCase();
    if (raw.isNotEmpty) return raw;
    final sanitized = nombre
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .substring(0, nombre.length.clamp(0, 12));
    final ts = DateTime.now().millisecondsSinceEpoch % 100000;
    return '${sanitized.isEmpty ? 'cuenta' : sanitized}$ts@fluixcrm.app';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nombreCtrl.dispose();
    _propietarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _creando = true);

    try {
      final nombre = _nombreCtrl.text.trim();
      String email = _resolverEmail(nombre);
      final password = _passwordCtrl.text.trim();
      final propietario = _propietarioCtrl.text.trim();
      final emailEsAutoGenerado = _emailCtrl.text.trim().isEmpty;

      // Cloud Functions no funciona en Windows — crear directamente con Firebase SDK
      String uid;
      try {
        uid = await _crearCuentaDirecta(
            email: email, password: password, nombre: nombre,
            tipoNegocio: _tipoNegocio, propietario: propietario);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use' && emailEsAutoGenerado) {
          // Reintento con email diferente si era auto-generado
          email = _resolverEmail('$nombre${DateTime.now().millisecondsSinceEpoch % 9999}');
          uid = await _crearCuentaDirecta(
              email: email, password: password, nombre: nombre,
              tipoNegocio: _tipoNegocio, propietario: propietario);
        } else {
          rethrow;
        }
      }

      // Guardar módulos
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(uid)
          .collection('suscripcion')
          .doc('actual')
          .set({'modulos_override': _modulosSeleccionados.toList()},
              SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _DialogCredenciales(
            email: email,
            tempPassword: password,
            planNombre: 'Plan Base',
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _mostrarError(_mensajeAuth(e.code));
    } catch (e) {
      _mostrarError('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _creando = false);
    }
  }

  /// Crea el usuario en Firebase Auth (app secundaria para no cerrar sesión actual)
  /// y los documentos en Firestore.
  Future<String> _crearCuentaDirecta({
    required String email,
    required String password,
    required String nombre,
    required String tipoNegocio,
    required String propietario,
  }) async {
    // App secundaria → no cierra la sesión del propietario actual
    final appName = 'crear_${DateTime.now().millisecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: Firebase.app().options,
    );

    late final String uid;
    try {
      final auth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      uid = cred.user!.uid;
      await auth.signOut();
    } finally {
      await secondaryApp.delete();
    }

    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    // Documento empresa — incluye módulos activos para filtrado eficiente en selectores
    batch.set(db.collection('empresas').doc(uid), {
      'nombre': nombre,
      'email': email,
      'tipo_negocio': tipoNegocio,
      'propietario_nombre': propietario,
      'tipo_tpv': 'bar',
      'creado': FieldValue.serverTimestamp(),
      'activo': true,
      'modulos_activos': _modulosSeleccionados.toList(),
    });

    // Suscripción
    batch.set(
      db.collection('empresas').doc(uid).collection('suscripcion').doc('actual'),
      {
        'plan': 'basico',
        'plan_nombre': 'Plan Base',
        'estado': 'ACTIVA',
        'fecha_inicio': FieldValue.serverTimestamp(),
        'fecha_fin': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 365))),
        'packs_activos': <String>[],
        'addons_activos': <String>[],
      },
    );

    // Documento usuario
    batch.set(db.collection('usuarios').doc(uid), {
      'uid': uid,
      'email': email,
      'empresa_id': uid,
      'rol': 'admin',
      'nombre': propietario.isNotEmpty ? propietario : nombre,
      'creado': FieldValue.serverTimestamp(),
      'activo': true,
    });

    await batch.commit();

    // Inicializar configuracion/modulos con los módulos seleccionados
    // (fuente de verdad para el dashboard) — separado del batch porque
    // es una subcolección diferente
    final modulosList = _modulosSeleccionados.map((id) => {
      'id': id,
      'activo': true,
    }).toList();
    await db
        .collection('empresas')
        .doc(uid)
        .collection('configuracion')
        .doc('modulos')
        .set({
      'modulos': modulosList,
      'ultima_actualizacion': FieldValue.serverTimestamp(),
    });

    return uid;
  }

  String _mensajeAuth(String code) {
    switch (code) {
      case 'email-already-in-use': return 'Este email ya está registrado';
      case 'invalid-email':        return 'El email no es válido';
      case 'weak-password':        return 'La contraseña es demasiado débil (mín. 6 caracteres)';
      case 'operation-not-allowed': return 'Operación no permitida';
      default:                     return 'Error de autenticación: $code';
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red),
    );
  }

  void _seleccionarTodos() =>
      setState(() => _modulosSeleccionados.addAll(_todosModulos.map((m) => m.id)));

  void _deseleccionarTodos() =>
      setState(() => _modulosSeleccionados.clear());

  List<Widget> _buildSelectorModulos() {
    final grupos = <String>[];
    for (final m in _todosModulos) {
      if (!grupos.contains(m.grupo)) grupos.add(m.grupo);
    }
    final widgets = <Widget>[];
    for (final grupo in grupos) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Text(grupo,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: Color(0xFF455A64), letterSpacing: 0.5)),
      ));
      for (final mod in _todosModulos.where((m) => m.grupo == grupo)) {
        final activo = _modulosSeleccionados.contains(mod.id);
        widgets.add(GestureDetector(
          onTap: () => setState(() {
            if (activo) _modulosSeleccionados.remove(mod.id);
            else _modulosSeleccionados.add(mod.id);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: activo ? mod.color.withValues(alpha: 0.08) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: activo ? mod.color : Colors.grey[200]!,
                width: activo ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              Icon(
                activo ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: activo ? mod.color : Colors.grey[400],
              ),
              const SizedBox(width: 10),
              Icon(mod.icono, size: 16,
                  color: activo ? mod.color : Colors.grey[500]),
              const SizedBox(width: 8),
              Text(mod.nombre,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: activo ? mod.color : Colors.black87)),
            ]),
          ),
        ));
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Cabecera con botón cerrar
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Crear nueva cuenta',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'El cliente podrá iniciar sesión con el email y contraseña que indiques.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Cabecera módulos
              Row(children: [
                const Icon(Icons.extension_outlined, color: Color(0xFF0D47A1), size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Módulos activos',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: Color(0xFF0D47A1))),
                ),
                TextButton(
                  onPressed: _seleccionarTodos,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Todos', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _deseleccionarTodos,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: Colors.grey),
                  child: const Text('Ninguno', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Text('${_modulosSeleccionados.length}/${_todosModulos.length}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 8),
              ..._buildSelectorModulos(),
              const SizedBox(height: 16),

              // Email (opcional)
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _deco('Email de inicio de sesión (opcional)', Icons.email_outlined),
                validator: (v) {
                  if (v != null && v.isNotEmpty &&
                      !RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v)) {
                    return 'Email no válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Contraseña de inicio de sesión
              TextFormField(
                controller: _passwordCtrl,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: 'Contraseña de inicio de sesión *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_passwordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Color(0xFF0D47A1), width: 2),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Obligatorio';
                  if (v.trim().length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Nombre empresa
              TextFormField(
                controller: _nombreCtrl,
                decoration: _deco('Nombre del negocio *', Icons.store_outlined),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),

              // Nombre propietario (opcional)
              TextFormField(
                controller: _propietarioCtrl,
                decoration: _deco('Nombre del propietario (opcional)', Icons.person_outline),
              ),
              const SizedBox(height: 12),

              // Tipo negocio
              DropdownButtonFormField<String>(
                value: _tipoNegocio,
                decoration: _deco('Tipo de negocio', Icons.category_outlined),
                items: _tiposNegocio
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _tipoNegocio = v ?? 'Otro'),
              ),
              const SizedBox(height: 20),

              // Botón crear
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _creando ? null : _crear,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _creando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.person_add),
                  label: Text(
                    _creando ? 'Creando cuenta...' : 'Crear cuenta',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Info sobre cuentas de staff con mismo email
// ─────────────────────────────────────────────────────────────────────────────

class _InfoStaffEmail extends StatefulWidget {
  @override
  State<_InfoStaffEmail> createState() => _InfoStaffEmailState();
}

class _InfoStaffEmailState extends State<_InfoStaffEmail> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expandido = !_expandido),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: Color(0xFFF57F17), size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '¿Mis empleados pueden usar el mismo email?',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6D4C41)),
                    ),
                  ),
                  Icon(
                    _expandido ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFFF57F17),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_expandido)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Color(0xFFFFE082)),
                  const SizedBox(height: 8),
                  const Text(
                    'Firebase no permite dos cuentas con exactamente el mismo email. Sin embargo, tienes dos opciones para el staff:',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF5D4037)),
                  ),
                  const SizedBox(height: 8),
                  _opcionEmail(
                    '📧 Opción A — Email único por empleado',
                    'Cada empleado usa su propio email personal (recomendado).',
                    true,
                  ),
                  const SizedBox(height: 6),
                  _opcionEmail(
                    '➕ Opción B — Email+sufijo',
                    'Si todos quieren usar info@empresa.com, usa variaciones:\n'
                    'info+maria@empresa.com\n'
                    'info+jose@empresa.com\n'
                    '→ Gmail y la mayoría de proveedores entregan todos los mensajes al buzón principal info@empresa.com',
                    false,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _opcionEmail(String titulo, String cuerpo, bool esRecomendada) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: esRecomendada
              ? const Color(0xFF4CAF50).withValues(alpha: 0.4)
              : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                titulo,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
              if (esRecomendada) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Recomendada',
                    style: TextStyle(
                        fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(cuerpo,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6D4C41))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET: Formulario upgrade de plan V2 (packs + addons)
// ─────────────────────────────────────────────────────────────────────────────

class _FormUpgradePlan extends StatefulWidget {
  final _CuentaCliente cuenta;
  const _FormUpgradePlan({required this.cuenta});

  @override
  State<_FormUpgradePlan> createState() => _FormUpgradePlanState();
}

class _FormUpgradePlanState extends State<_FormUpgradePlan> {
  late Set<String> _packsSeleccionados;
  late Set<String> _addonsSeleccionados;
  late TextEditingController _empleadosCtrl;
  bool _extender = true;
  bool _actualizando = false;
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  @override
  void initState() {
    super.initState();
    _packsSeleccionados = Set.from(widget.cuenta.packsActivos);
    _addonsSeleccionados = Set.from(widget.cuenta.addonsActivos);
    _empleadosCtrl = TextEditingController(
      text: widget.cuenta.empleadosNomina.toString(),
    );
  }

  @override
  void dispose() {
    _empleadosCtrl.dispose();
    super.dispose();
  }

  double get _precioTotal => PlanesConfig.calcularPrecioTotal(
        packsActivos: _packsSeleccionados.toList(),
        addonsActivos: _addonsSeleccionados.toList(),
        empleadosNomina: int.tryParse(_empleadosCtrl.text) ?? 0,
      );

  Future<void> _aplicar() async {
    setState(() => _actualizando = true);
    try {
      await _functions.httpsCallable('actualizarPlanEmpresaV2').call({
        'empresaId': widget.cuenta.empresaId,
        'packsActivos': _packsSeleccionados.toList(),
        'addonsActivos': _addonsSeleccionados.toList(),
        'empleadosNomina': int.tryParse(_empleadosCtrl.text) ?? 0,
        'extenderDias': _extender ? 365 : 0,
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Plan actualizado con packs y add-ons'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      _mostrarError(e.message ?? e.code);
    } catch (e) {
      _mostrarError('Error: $e');
    } finally {
      if (mounted) setState(() => _actualizando = false);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $msg'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              'Configurar plan · ${widget.cuenta.nombre}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(widget.cuenta.email,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),

            // ── Plan Base (siempre incluido) ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PlanesConfig.planBase.color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PlanesConfig.planBase.color.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(PlanesConfig.planBase.icono, color: PlanesConfig.planBase.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(PlanesConfig.planBase.nombre,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: PlanesConfig.planBase.color,
                              fontSize: 14)),
                      Text(PlanesConfig.planBase.descripcion,
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Text('${PlanesConfig.planBase.precioAnual.toStringAsFixed(0)}€/año',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: PlanesConfig.planBase.color,
                        fontSize: 13)),
              ]),
            ),

            const SizedBox(height: 16),

            // ── PACKS ─────────────────────────────────────────────────────
            const Text('Packs',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1))),
            const SizedBox(height: 8),
            ...PlanesConfig.todosPacks.map((pack) => _CheckboxItem(
              titulo: pack.nombre,
              subtitulo: pack.descripcion,
              precio: '+${pack.precioAnual.toStringAsFixed(0)}€/año',
              color: pack.color,
              icono: pack.icono,
              seleccionado: _packsSeleccionados.contains(pack.id),
              onChanged: (v) => setState(() {
                if (v) {
                  _packsSeleccionados.add(pack.id);
                } else {
                  _packsSeleccionados.remove(pack.id);
                }
              }),
            )),

            const SizedBox(height: 12),

            // ── ADD-ONS ───────────────────────────────────────────────────
            const Text('Add-ons',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1))),
            const SizedBox(height: 8),
            ...PlanesConfig.todosAddons.map((addon) => _CheckboxItem(
              titulo: addon.nombre,
              subtitulo: addon.descripcion,
              precio: addon.precioLabel,
              color: addon.color,
              icono: addon.icono,
              seleccionado: _addonsSeleccionados.contains(addon.id),
              onChanged: (v) => setState(() {
                if (v) {
                  _addonsSeleccionados.add(addon.id);
                } else {
                  _addonsSeleccionados.remove(addon.id);
                }
              }),
            )),

            // ── Empleados con nómina (si addon nóminas activo) ────────────
            if (_addonsSeleccionados.contains('nominas')) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _empleadosCtrl,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onEditingComplete: () => FocusScope.of(context).unfocus(),
                decoration: _deco('Nº empleados con nómina', Icons.badge),
                onChanged: (_) => setState(() {}),
              ),
            ],

            const SizedBox(height: 16),

            // ── Precio total en tiempo real ───────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFE3F2FD), Color(0xFFF3E5F5)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.euro, color: Color(0xFF0D47A1), size: 24),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Precio total anual',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                Text(
                  '${_precioTotal.toStringAsFixed(0)}€/año',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D47A1)),
                ),
              ]),
            ),

            const SizedBox(height: 12),
            SwitchListTile(
              value: _extender,
              onChanged: (v) => setState(() => _extender = v),
              title: const Text('Extender 365 días desde hoy',
                  style: TextStyle(fontSize: 14)),
              subtitle: Text(
                _extender
                    ? 'La suscripción vencerá el ${DateFormat('dd/MM/yyyy').format(DateTime.now().add(const Duration(days: 365)))}'
                    : 'Se mantiene la fecha de fin actual',
                style: const TextStyle(fontSize: 12),
              ),
              activeThumbColor: const Color(0xFF0D47A1),
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _actualizando ? null : _aplicar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _actualizando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.upgrade),
                label: Text(
                  _actualizando ? 'Aplicando...' : 'Aplicar cambios',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Checkbox item reutilizable para packs y addons
// ─────────────────────────────────────────────────────────────────────────────

class _CheckboxItem extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String precio;
  final Color color;
  final IconData icono;
  final bool seleccionado;
  final ValueChanged<bool> onChanged;

  const _CheckboxItem({
    required this.titulo,
    required this.subtitulo,
    required this.precio,
    required this.color,
    required this.icono,
    required this.seleccionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!seleccionado),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: seleccionado ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: seleccionado ? color : Colors.grey[200]!,
            width: seleccionado ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Icon(
            seleccionado ? Icons.check_box : Icons.check_box_outline_blank,
            color: seleccionado ? color : Colors.grey[400],
            size: 20,
          ),
          const SizedBox(width: 8),
          Icon(icono, size: 16, color: seleccionado ? color : Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: seleccionado ? color : Colors.black87)),
                Text(subtitulo,
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
              ],
            ),
          ),
          Text(precio,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: seleccionado ? color : Colors.grey)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG: Credenciales de la nueva cuenta
// ─────────────────────────────────────────────────────────────────────────────

class _DialogCredenciales extends StatelessWidget {
  final String email;
  final String tempPassword;
  final String planNombre;

  const _DialogCredenciales({
    required this.email,
    required this.tempPassword,
    required this.planNombre,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 56),
            const SizedBox(height: 12),
            const Text(
              '✅ Cuenta creada',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Se ha enviado un email de bienvenida a:',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _credBox('📧 Email', email),
            const SizedBox(height: 8),
            _credBox('🔑 Contraseña temporal', tempPassword, copiable: true),
            const SizedBox(height: 8),
            _credBox('📦 Plan', planNombre),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ Guarda esta contraseña temporal. El cliente deberá cambiarla en su primera sesión.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFFE65100)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Copiar al portapapeles antes de cerrar
                  Clipboard.setData(ClipboardData(
                      text: 'Email: $email\nContraseña: $tempPassword'));
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Copiar y cerrar',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _credBox(String label, String value, {bool copiable = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey)),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: copiable ? 18 : 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: copiable ? 'monospace' : null,
                    letterSpacing: copiable ? 2 : 0,
                  ),
                ),
              ),
              if (copiable)
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: value)),
                  tooltip: 'Copiar contraseña',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIÁLOGO: Configurar Google Reseñas
// ─────────────────────────────────────────────────────────────────────────────

class _DialogGoogleReviews extends StatefulWidget {
  final String empresaId;
  final String nombreEmpresa;

  const _DialogGoogleReviews({
    required this.empresaId,
    required this.nombreEmpresa,
  });

  @override
  State<_DialogGoogleReviews> createState() => _DialogGoogleReviewsState();
}

class _DialogGoogleReviewsState extends State<_DialogGoogleReviews> {
  final _apiKeyCtrl = TextEditingController();
  final _placeIdCtrl = TextEditingController();
  bool _cargando = true;
  bool _guardando = false;
  bool _configurado = false;

  @override
  void initState() {
    super.initState();
    _cargarConfig();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _placeIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('configuracion')
          .doc('google_reviews')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _apiKeyCtrl.text = data['api_key'] as String? ?? '';
        _placeIdCtrl.text = data['place_id'] as String? ?? '';
        _configurado = _apiKeyCtrl.text.isNotEmpty && _placeIdCtrl.text.isNotEmpty;
      }
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    final apiKey = _apiKeyCtrl.text.trim();
    final placeId = _placeIdCtrl.text.trim();

    if (apiKey.isEmpty || placeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rellena todos los campos'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('configuracion')
          .doc('google_reviews')
          .set({
        'api_key': apiKey,
        'place_id': placeId,
        'actualizado': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Google Reseñas vinculado a ${widget.nombreEmpresa}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.star_rate_rounded, color: Color(0xFFF57F17)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Google Reseñas\n${widget.nombreEmpresa}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: _cargando
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_configurado)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('Ya vinculado', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  // API KEY
                  TextField(
                    controller: _apiKeyCtrl,
                    decoration: InputDecoration(
                      labelText: 'Google API Key',
                      hintText: 'AIzaSy...',
                      prefixIcon: const Icon(Icons.vpn_key_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFF57F17), width: 2),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  // PLACE ID
                  TextField(
                    controller: _placeIdCtrl,
                    decoration: InputDecoration(
                      labelText: 'Place ID de Google',
                      hintText: 'ChIJ...',
                      prefixIcon: const Icon(Icons.place_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF5F7FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFF57F17), width: 2),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  // Ayuda
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¿Cómo obtener el Place ID?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('1. Busca el negocio en Google Maps\n2. Clic derecho → "¿Qué hay aquí?"\n3. Aparece el Place ID al fondo\nO busca en: maps.google.com → comparte → enlace', style: TextStyle(fontSize: 11, color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded, size: 16),
          label: const Text('Guardar'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFF57F17),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _deco(String label, IconData icono) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icono),
    filled: true,
    fillColor: const Color(0xFFF5F7FA),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.grey[300]!),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PANEL DE ESTADÍSTICAS
// ─────────────────────────────────────────────────────────────────────────────

class _PanelEstadisticas extends StatefulWidget {
  final List<_CuentaCliente> cuentas;
  final bool cargando;

  const _PanelEstadisticas({required this.cuentas, required this.cargando});

  @override
  State<_PanelEstadisticas> createState() => _PanelEstadisticasState();
}

class _PanelEstadisticasState extends State<_PanelEstadisticas> {
  double _gastoFirebaseMes = 0;
  final _gastoCtrl = TextEditingController();
  bool _guardandoGasto = false;

  @override
  void initState() {
    super.initState();
    _cargarGasto();
  }

  @override
  void dispose() {
    _gastoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarGasto() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('platform').doc('gastos').get();
      final val = (doc.data()?['firebase_mes'] as num?)?.toDouble() ?? 0;
      if (mounted) {
        setState(() => _gastoFirebaseMes = val);
        _gastoCtrl.text = val > 0 ? val.toStringAsFixed(2) : '';
      }
    } catch (_) {}
  }

  void _mostrarListaVencidas(BuildContext context, List<_CuentaCliente> vencidas) {
    final fmt = DateFormat('dd/MM/yyyy');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 8),
          Text(
            '${vencidas.length} cuenta${vencidas.length > 1 ? 's' : ''} vencida${vencidas.length > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: vencidas.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.red[100],
                  child: Text(
                    c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
                    style: TextStyle(color: Colors.red[700], fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    if (c.fechaFin != null)
                      Text('Venció el ${fmt.format(c.fechaFin!)}',
                          style: TextStyle(fontSize: 11, color: Colors.red[600])),
                  ],
                )),
              ]),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Future<void> _guardarGasto() async {
    final val = double.tryParse(_gastoCtrl.text.replaceAll(',', '.')) ?? 0;
    setState(() => _guardandoGasto = true);
    try {
      await FirebaseFirestore.instance
          .collection('platform').doc('gastos')
          .set({'firebase_mes': val}, SetOptions(merge: true));
      if (mounted) setState(() { _gastoFirebaseMes = val; _guardandoGasto = false; });
    } catch (_) {
      if (mounted) setState(() => _guardandoGasto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final cuentas = widget.cuentas;
    final cs = _DashStats.compute(cuentas, _gastoFirebaseMes);

    return RefreshIndicator(
      onRefresh: _cargarGasto,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // ── 1. ALERTAS CRÍTICAS ──────────────────────────────────────────
          _AlertasBanner(
            vencidas: cs.cuentasVencidas,
            porVencer: cs.cuentasPorVencer,
            onTapVencidas: () => _mostrarListaVencidas(context, cs.cuentasVencidas),
          ),

          // ── 2. RESUMEN EJECUTIVO ─────────────────────────────────────────
          _DashSectionHeader(titulo: 'Resumen ejecutivo'),
          const SizedBox(height: 10),
          _EjecutivoGrid(stats: cs),
          const SizedBox(height: 20),

          // ── 3. SALUD DEL PORTFOLIO ───────────────────────────────────────
          _DashSectionHeader(titulo: 'Salud del portfolio'),
          const SizedBox(height: 10),
          _SaludPortfolio(stats: cs),
          const SizedBox(height: 20),

          // ── 4. TOP CUENTAS ───────────────────────────────────────────────
          if (cs.topEmpresas.isNotEmpty) ...[
            _DashSectionHeader(titulo: 'Top cuentas por facturación'),
            const SizedBox(height: 10),
            _TopCuentasCard(topEmpresas: cs.topEmpresas),
            const SizedBox(height: 20),
          ],

          // ── 5. RENTABILIDAD FIREBASE ─────────────────────────────────────
          _DashSectionHeader(titulo: 'Rentabilidad Firebase'),
          const SizedBox(height: 10),
          _RentabilidadFirebase(
            stats: cs,
            gastoCtrl: _gastoCtrl,
            guardandoGasto: _guardandoGasto,
            onGuardar: _guardarGasto,
          ),
          const SizedBox(height: 20),

          // ── 6. ADOPCIÓN PACKS/ADD-ONS ────────────────────────────────────
          _DashSectionHeader(titulo: 'Adopción de packs / add-ons'),
          const SizedBox(height: 10),
          _AdopcionPacks(cuentas: cuentas),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELO DE CÁLCULOS CENTRALIZADO
// ─────────────────────────────────────────────────────────────────────────────

class _DashStats {
  final int total;
  final int activas;
  final int vencidas;
  final double mrr;
  final double arr;
  final double margenPct;
  final double margenMes;
  final double gastoReferencia;
  final double beneficioMes;
  final double beneficioAnio;
  final double costoEstimado;
  final List<_CuentaCliente> cuentasVencidas;
  final List<_CuentaCliente> cuentasPorVencer;
  final List<_CuentaCliente> topEmpresas;

  const _DashStats({
    required this.total,
    required this.activas,
    required this.vencidas,
    required this.mrr,
    required this.arr,
    required this.margenPct,
    required this.margenMes,
    required this.gastoReferencia,
    required this.beneficioMes,
    required this.beneficioAnio,
    required this.costoEstimado,
    required this.cuentasVencidas,
    required this.cuentasPorVencer,
    required this.topEmpresas,
  });

  factory _DashStats.compute(List<_CuentaCliente> cuentas, double gastoFirebaseMes) {
    final total   = cuentas.length;
    final activas = cuentas.where((c) => c.activa).length;
    final cuentasVencidas = cuentas.where((c) => c.estado == 'VENCIDA').toList();
    final now = DateTime.now();
    final cuentasPorVencer = cuentas.where((c) {
      if (c.fechaFin == null || !c.activa) return false;
      final dias = c.fechaFin!.difference(now).inDays;
      return dias >= 0 && dias <= 30;
    }).toList();

    final mrr = cuentas.where((c) => c.activa).fold(0.0, (d, c) => d + c.precioEfectivo);
    final arr = mrr * 12;
    final costoEstimado = activas * 3.0;
    final gastoReferencia = gastoFirebaseMes > 0 ? gastoFirebaseMes : costoEstimado;
    final margenMes = mrr - gastoReferencia;
    final margenPct = mrr > 0 ? (margenMes / mrr * 100) : 0.0;
    final beneficioMes = margenMes;
    final beneficioAnio = arr - gastoReferencia * 12;

    final top5 = [...cuentas.where((c) => c.activa)]
      ..sort((a, b) => b.precioEfectivo.compareTo(a.precioEfectivo));

    return _DashStats(
      total: total,
      activas: activas,
      vencidas: cuentasVencidas.length,
      mrr: mrr,
      arr: arr,
      margenPct: margenPct,
      margenMes: margenMes,
      gastoReferencia: gastoReferencia,
      beneficioMes: beneficioMes,
      beneficioAnio: beneficioAnio,
      costoEstimado: costoEstimado,
      cuentasVencidas: cuentasVencidas,
      cuentasPorVencer: cuentasPorVencer,
      topEmpresas: top5.take(5).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS DE APOYO — NUEVO DISEÑO
// ─────────────────────────────────────────────────────────────────────────────

/// Cabecera de sección con línea decorativa
class _DashSectionHeader extends StatelessWidget {
  final String titulo;
  const _DashSectionHeader({required this.titulo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(width: 3, height: 16,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          )),
      const SizedBox(width: 8),
      Text(titulo,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            letterSpacing: 0.3,
          )),
    ]);
  }
}

/// Banners de alerta crítica (solo si hay vencidas o por vencer)
class _AlertasBanner extends StatelessWidget {
  final List<_CuentaCliente> vencidas;
  final List<_CuentaCliente> porVencer;
  final VoidCallback onTapVencidas;

  const _AlertasBanner({
    required this.vencidas,
    required this.porVencer,
    required this.onTapVencidas,
  });

  @override
  Widget build(BuildContext context) {
    if (vencidas.isEmpty && porVencer.isEmpty) return const SizedBox.shrink();

    return Column(children: [
      if (vencidas.isNotEmpty)
        _BannerAlerta(
          color: Colors.red[700]!,
          bgColor: Colors.red[50]!,
          borderColor: Colors.red[300]!,
          icono: Icons.error_outline_rounded,
          texto: '${vencidas.length} cuenta${vencidas.length > 1 ? 's' : ''} '
              'vencida${vencidas.length > 1 ? 's' : ''} — requiere atención inmediata',
          botonTexto: 'Ver cuentas',
          onTap: onTapVencidas,
        ),
      if (porVencer.isNotEmpty)
        _BannerAlerta(
          color: const Color(0xFFE65100),
          bgColor: const Color(0xFFFFF3E0),
          borderColor: const Color(0xFFFFCC80),
          icono: Icons.schedule_rounded,
          texto: '${porVencer.length} cuenta${porVencer.length > 1 ? 's' : ''} '
              'vence${porVencer.length > 1 ? 'n' : ''} en los próximos 30 días',
          botonTexto: null,
          onTap: null,
        ),
      if (vencidas.isNotEmpty || porVencer.isNotEmpty)
        const SizedBox(height: 16),
    ]);
  }
}

class _BannerAlerta extends StatelessWidget {
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final IconData icono;
  final String texto;
  final String? botonTexto;
  final VoidCallback? onTap;

  const _BannerAlerta({
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.icono,
    required this.texto,
    required this.botonTexto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(texto,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color))),
          if (botonTexto != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(botonTexto!,
                  style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Grid 2x2 de KPIs ejecutivos
class _EjecutivoGrid extends StatelessWidget {
  final _DashStats stats;
  const _EjecutivoGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'es_ES');
    final margenColor = stats.margenPct >= 70
        ? const Color(0xFF1B5E20)
        : stats.margenPct >= 40
            ? const Color(0xFFE65100)
            : Colors.red[700]!;

    return Column(children: [
      Row(children: [
        Expanded(child: _KpiEjecutivo(
          titulo: 'MRR',
          valor: '${fmt.format(stats.mrr)} €',
          subtitulo: 'ingresos / mes',
          icono: Icons.euro_rounded,
          colorIcono: const Color(0xFF1B5E20),
          colorFondo: const Color(0xFFE8F5E9),
        )),
        const SizedBox(width: 10),
        Expanded(child: _KpiEjecutivo(
          titulo: 'ARR',
          valor: '${fmt.format(stats.arr)} €',
          subtitulo: 'ingresos / año',
          icono: Icons.trending_up_rounded,
          colorIcono: const Color(0xFF2E7D32),
          colorFondo: const Color(0xFFF1F8E9),
        )),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _KpiEjecutivo(
          titulo: 'Cuentas',
          valor: '${stats.activas} / ${stats.total}',
          subtitulo: 'activas / total',
          icono: Icons.business_rounded,
          colorIcono: const Color(0xFF1565C0),
          colorFondo: const Color(0xFFE3F2FD),
        )),
        const SizedBox(width: 10),
        Expanded(child: _KpiEjecutivo(
          titulo: 'Margen',
          valor: '${stats.margenPct.toStringAsFixed(1)}%',
          subtitulo: '${fmt.format(stats.margenMes)} € neto',
          icono: Icons.show_chart_rounded,
          colorIcono: margenColor,
          colorFondo: margenColor.withValues(alpha: 0.1),
        )),
      ]),
    ]);
  }
}

class _KpiEjecutivo extends StatelessWidget {
  final String titulo;
  final String valor;
  final String subtitulo;
  final IconData icono;
  final Color colorIcono;
  final Color colorFondo;

  const _KpiEjecutivo({
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.icono,
    required this.colorIcono,
    required this.colorFondo,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : colorFondo;
    final borderColor = isDark
        ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)
        : colorIcono.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorIcono.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, color: colorIcono, size: 16),
          ),
          const Spacer(),
          Text(titulo,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              )),
        ]),
        const SizedBox(height: 10),
        Text(valor,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            )),
        const SizedBox(height: 2),
        Text(subtitulo,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            )),
      ]),
    );
  }
}

/// Barra de salud del portfolio (activas / vencidas / por_vencer)
class _SaludPortfolio extends StatelessWidget {
  final _DashStats stats;
  const _SaludPortfolio({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.total;
    if (total == 0) return const SizedBox.shrink();

    final porVencer = stats.cuentasPorVencer.length;
    final inactivas = total - stats.activas;
    final sano = stats.vencidas == 0 && porVencer == 0;

    final pctActivas   = stats.activas / total;
    final pctVencidas  = stats.vencidas / total;
    final pctPorVencer = porVencer / total;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.white;
    final borderColor = isDark
        ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)
        : Colors.grey[200]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Estado del portfolio',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: sano ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                sano ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                size: 13,
                color: sano ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
              ),
              const SizedBox(width: 4),
              Text(
                sano ? 'Portfolio sano' : 'Atención requerida',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: sano ? const Color(0xFF2E7D32) : const Color(0xFFE65100),
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        // Barra segmentada
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(children: [
              if (pctActivas > 0)
                Expanded(
                  flex: (pctActivas * 1000).round(),
                  child: Container(color: const Color(0xFF4CAF50)),
                ),
              if (pctPorVencer > 0)
                Expanded(
                  flex: (pctPorVencer * 1000).round(),
                  child: Container(color: const Color(0xFFFFB300)),
                ),
              if (pctVencidas > 0)
                Expanded(
                  flex: (pctVencidas * 1000).round(),
                  child: Container(color: const Color(0xFFE53935)),
                ),
              if (inactivas - stats.vencidas - porVencer > 0)
                Expanded(
                  flex: ((inactivas - stats.vencidas - porVencer) / total * 1000).round(),
                  child: Container(color: Colors.grey[300]),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        // Leyenda
        Wrap(spacing: 16, runSpacing: 6, children: [
          _LegendaDot(color: const Color(0xFF4CAF50),
              label: 'Activas (${stats.activas})'),
          if (porVencer > 0)
            _LegendaDot(color: const Color(0xFFFFB300),
                label: 'Por vencer ($porVencer)'),
          if (stats.vencidas > 0)
            _LegendaDot(color: const Color(0xFFE53935),
                label: 'Vencidas (${stats.vencidas})'),
          if (inactivas - stats.vencidas - porVencer > 0)
            _LegendaDot(color: Colors.grey[400]!,
                label: 'Otras (${inactivas - stats.vencidas - porVencer})'),
        ]),
      ]),
    );
  }
}

class _LegendaDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendaDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
          )),
    ]);
  }
}

/// Lista compacta de top 5 cuentas
class _TopCuentasCard extends StatelessWidget {
  final List<_CuentaCliente> topEmpresas;
  const _TopCuentasCard({required this.topEmpresas});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.white;
    final borderColor = isDark
        ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)
        : Colors.grey[200]!;
    final fmt = NumberFormat('#,##0.00', 'es_ES');

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: topEmpresas.asMap().entries.map((entry) {
          final idx    = entry.key;
          final cuenta = entry.value;
          final isLast = idx == topEmpresas.length - 1;

          Color estadoColor;
          switch (cuenta.estado) {
            case 'VENCIDA':     estadoColor = Colors.red[700]!; break;
            case 'POR_VENCER':  estadoColor = const Color(0xFFE65100); break;
            default:            estadoColor = const Color(0xFF2E7D32);
          }

          final avatarColors = [
            const Color(0xFF1565C0), const Color(0xFF7B1FA2),
            const Color(0xFF00838F), const Color(0xFF558B2F),
            const Color(0xFFBF360C),
          ];
          final avatarColor = avatarColors[idx % avatarColors.length];

          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(children: [
                // Rank + Avatar
                Stack(alignment: Alignment.bottomRight, children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: avatarColor.withValues(alpha: 0.15),
                    child: Text(
                      cuenta.nombre.isNotEmpty ? cuenta.nombre[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: avatarColor, fontSize: 15, fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (idx < 3)
                    Text(idx == 0 ? '🥇' : idx == 1 ? '🥈' : '🥉',
                        style: const TextStyle(fontSize: 10)),
                ]),
                const SizedBox(width: 10),
                // Nombre + plan
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cuenta.nombre,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis),
                    Text(cuenta.planNombre,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        )),
                  ],
                )),
                const SizedBox(width: 8),
                // Estado badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: estadoColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: estadoColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    cuenta.estado == 'ACTIVA' ? 'Activa'
                        : cuenta.estado == 'VENCIDA' ? 'Vencida'
                        : 'Por vencer',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: estadoColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Precio
                Text('${fmt.format(cuenta.precioEfectivo)} €',
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1B5E20),
                    )),
              ]),
            ),
            if (!isLast)
              Divider(height: 1, indent: 14, endIndent: 14,
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
          ]);
        }).toList(),
      ),
    );
  }
}

/// Card de rentabilidad Firebase con input inline
class _RentabilidadFirebase extends StatelessWidget {
  final _DashStats stats;
  final TextEditingController gastoCtrl;
  final bool guardandoGasto;
  final VoidCallback onGuardar;

  const _RentabilidadFirebase({
    required this.stats,
    required this.gastoCtrl,
    required this.guardandoGasto,
    required this.onGuardar,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.white;
    final borderColor = isDark
        ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)
        : Colors.grey[200]!;
    final fmt = NumberFormat('#,##0.00', 'es_ES');
    final beneficioPositivo = stats.beneficioMes >= 0;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: [
        // Input gasto
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.local_fire_department_rounded,
                  color: const Color(0xFFBF360C), size: 16),
              const SizedBox(width: 6),
              Text('Coste Firebase real del mes',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
            ]),
            const SizedBox(height: 4),
            Text('Firebase Console → Uso y facturación',
                style: TextStyle(fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: gastoCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ej: ${stats.costoEstimado.toStringAsFixed(0)}',
                    suffixText: '€/mes',
                    filled: true,
                    fillColor: isDark
                        ? Theme.of(context).colorScheme.surface
                        : const Color(0xFFF5F7FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: guardandoGasto ? null : onGuardar,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: guardandoGasto
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Guardar',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ),
        Divider(height: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
        // 3 métricas
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: _MetricaFirebase(
              label: 'Ingresos',
              valor: '${fmt.format(stats.mrr)} €',
              color: const Color(0xFF2E7D32),
              icono: Icons.arrow_upward_rounded,
            )),
            Container(width: 1, height: 36,
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
            Expanded(child: _MetricaFirebase(
              label: 'Coste Firebase',
              valor: '${fmt.format(stats.gastoReferencia)} €',
              color: const Color(0xFFBF360C),
              icono: Icons.arrow_downward_rounded,
            )),
            Container(width: 1, height: 36,
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
            Expanded(child: _MetricaFirebase(
              label: 'Beneficio neto',
              valor: '${fmt.format(stats.beneficioMes)} €',
              color: beneficioPositivo ? const Color(0xFF1B5E20) : Colors.red[700]!,
              icono: beneficioPositivo ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              destacado: true,
            )),
          ]),
        ),
      ]),
    );
  }
}

class _MetricaFirebase extends StatelessWidget {
  final String label;
  final String valor;
  final Color color;
  final IconData icono;
  final bool destacado;

  const _MetricaFirebase({
    required this.label,
    required this.valor,
    required this.color,
    required this.icono,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Icon(icono, color: color, size: 14),
      const SizedBox(height: 4),
      Text(valor,
          style: TextStyle(
            fontSize: destacado ? 14 : 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
          textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          textAlign: TextAlign.center),
    ]);
  }
}

/// Barras de adopción de packs/add-ons
class _AdopcionPacks extends StatelessWidget {
  final List<_CuentaCliente> cuentas;
  const _AdopcionPacks({required this.cuentas});

  @override
  Widget build(BuildContext context) {
    final total = cuentas.length;
    if (total == 0) return const SizedBox.shrink();

    final adopcion = <String, int>{};
    for (final c in cuentas) {
      for (final p in c.packsActivos)  adopcion[p] = (adopcion[p] ?? 0) + 1;
      for (final a in c.addonsActivos) adopcion[a] = (adopcion[a] ?? 0) + 1;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.white;
    final borderColor = isDark
        ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)
        : Colors.grey[200]!;

    if (adopcion.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Text('Ninguna empresa tiene packs o add-ons activados.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            )),
      );
    }

    final entries = adopcion.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    const barColors = [
      Color(0xFF1565C0), Color(0xFF7B1FA2), Color(0xFF00838F),
      Color(0xFF558B2F), Color(0xFFBF360C), Color(0xFF37474F),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: entries.asMap().entries.map((entry) {
          final idx  = entry.key;
          final e    = entry.value;
          final pct  = e.value / total;
          final barC = barColors[idx % barColors.length];

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: barC, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Expanded(child: Text(e.key,
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ))),
                Text('${e.value}/$total',
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: barC,
                    )),
                const SizedBox(width: 6),
                Text('(${(pct * 100).toStringAsFixed(0)}%)',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                    )),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 7,
                  backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(barC),
                ),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET: Selector de módulos activos por empresa
// ─────────────────────────────────────────────────────────────────────────────

class _ModInfo {
  final String id;
  final String nombre;
  final String grupo;
  final IconData icono;
  final Color color;
  const _ModInfo(this.id, this.nombre, this.grupo, this.icono, this.color);
}

const _todosModulos = [
  _ModInfo('dashboard',      'Dashboard',          'Base',          Icons.dashboard_outlined,       Color(0xFF1976D2)),
  _ModInfo('reservas',       'Reservas / Citas',   'Base',          Icons.calendar_today_outlined,  Color(0xFF1976D2)),
  _ModInfo('clientes',       'Clientes',           'Base',          Icons.people_outline,           Color(0xFF1976D2)),
  _ModInfo('servicios',      'Servicios',          'Base',          Icons.spa_outlined,             Color(0xFF1976D2)),
  _ModInfo('empleados',      'Empleados',          'Base',          Icons.badge_outlined,           Color(0xFF1976D2)),
  _ModInfo('valoraciones',   'Valoraciones',       'Base',          Icons.star_outline,             Color(0xFF1976D2)),
  _ModInfo('estadisticas',   'Estadísticas',       'Base',          Icons.bar_chart,                Color(0xFF1976D2)),
  _ModInfo('contenido_web',  'Contenido Web',      'Base',          Icons.web_outlined,             Color(0xFF1976D2)),
  _ModInfo('app',            'Mi App',             'Base',          Icons.store_outlined,           Color(0xFF1976D2)),
  _ModInfo('facturacion',    'Facturación',        'Gestión',       Icons.receipt_long_outlined,    Color(0xFF7B1FA2)),
  _ModInfo('vacaciones',     'Vacaciones',         'Gestión',       Icons.beach_access_outlined,    Color(0xFF7B1FA2)),
  _ModInfo('tpv',            'TPV / Cobros',       'Gestión',       Icons.point_of_sale_outlined,   Color(0xFF7B1FA2)),
  _ModInfo('fichaje',        'Fichaje',            'Gestión',       Icons.fingerprint,              Color(0xFF7B1FA2)),
  _ModInfo('operaciones',    'Operaciones',        'Gestión',       Icons.local_shipping_outlined,  Color(0xFF7B1FA2)),
  _ModInfo('fiscal',         'Fiscal AI',          'Fiscal',        Icons.account_balance_outlined, Color(0xFF0288D1)),
  _ModInfo('contabilidad',   'Contabilidad',       'Fiscal',        Icons.calculate_outlined,       Color(0xFF0288D1)),
  _ModInfo('verifactu',      'VeriFactu',          'Fiscal',        Icons.verified_outlined,        Color(0xFF0288D1)),
  _ModInfo('pedidos',        'Pedidos / Tienda',   'Tienda',        Icons.storefront_outlined,      Color(0xFFE65100)),
  _ModInfo('whatsapp',       'WhatsApp',           'Add-ons',       Icons.chat_bubble_outline,      Color(0xFF25D366)),
  _ModInfo('tareas',         'Tareas',             'Add-ons',       Icons.task_alt_outlined,        Color(0xFF00ACC1)),
  _ModInfo('nominas',        'Nóminas',            'Add-ons',       Icons.payments_outlined,        Color(0xFFFF7043)),
  _ModInfo('plantillas_pdf', 'Plantillas PDF',     'Add-ons',       Icons.picture_as_pdf_outlined,  Color(0xFFFF7043)),
];

class _FormSelectorModulos extends StatefulWidget {
  final _CuentaCliente cuenta;
  const _FormSelectorModulos({required this.cuenta});

  @override
  State<_FormSelectorModulos> createState() => _FormSelectorModulosState();
}

class _FormSelectorModulosState extends State<_FormSelectorModulos> {
  final _db = FirebaseFirestore.instance;
  Set<String> _seleccionados = {};
  bool _cargando = true;
  bool _guardando = false;
  bool _usandoOverride = false;

  @override
  void initState() {
    super.initState();
    _cargarEstadoActual();
  }

  Future<void> _cargarEstadoActual() async {
    try {
      final doc = await _db
          .collection('empresas')
          .doc(widget.cuenta.empresaId)
          .collection('suscripcion')
          .doc('actual')
          .get();

      final data = doc.data() ?? {};
      final override = (data['modulos_override'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();

      if (override.isNotEmpty) {
        setState(() {
          _seleccionados = Set.from(override);
          _usandoOverride = true;
          _cargando = false;
        });
      } else {
        // Calcular desde packs/addons actuales
        final packs = (data['packs_activos'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
        final addons = (data['addons_activos'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
        final modulos = PlanesConfig.getModulosActivos(packsActivos: packs, addonsActivos: addons);
        setState(() {
          _seleccionados = Set.from(modulos);
          _usandoOverride = false;
          _cargando = false;
        });
      }
    } catch (e) {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await _db
          .collection('empresas')
          .doc(widget.cuenta.empresaId)
          .collection('suscripcion')
          .doc('actual')
          .update({'modulos_override': _seleccionados.toList()});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Módulos actualizados'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _resetearAPlan() async {
    setState(() => _guardando = true);
    try {
      await _db
          .collection('empresas')
          .doc(widget.cuenta.empresaId)
          .collection('suscripcion')
          .doc('actual')
          .update({'modulos_override': FieldValue.delete()});

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Módulos restablecidos al plan contratado'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _seleccionarTodos() => setState(
      () => _seleccionados = _todosModulos.map((m) => m.id).toSet());

  void _deseleccionarTodos() => setState(() => _seleccionados = {});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Cabecera
          Row(children: [
            const Icon(Icons.extension_outlined, color: Color(0xFF1565C0), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Módulos activos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(widget.cuenta.nombre,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
          const SizedBox(height: 8),

          // Banner override activo
          if (_usandoOverride && !_cargando)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF8F00)),
              ),
              child: Row(children: [
                const Icon(Icons.edit_note, color: Color(0xFFFF8F00), size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Módulos personalizados activos (overriding el plan)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6D4C41),
                          fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: _guardando ? null : _resetearAPlan,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero, minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('Resetear al plan',
                      style: TextStyle(fontSize: 11, color: Color(0xFFFF8F00))),
                ),
              ]),
            ),

          // Botones seleccionar / deseleccionar todos
          Row(children: [
            TextButton(
              onPressed: _seleccionarTodos,
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Seleccionar todos', style: TextStyle(fontSize: 12)),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: _deseleccionarTodos,
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero, minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Colors.grey),
              child: const Text('Ninguno', style: TextStyle(fontSize: 12)),
            ),
            const Spacer(),
            Text('${_seleccionados.length}/${_todosModulos.length}',
                style: const TextStyle(fontSize: 12, color: Colors.grey,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),

          // Lista de módulos
          Flexible(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    shrinkWrap: true,
                    children: _buildGrupos(),
                  ),
          ),
          const SizedBox(height: 12),

          // Botón guardar
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _guardando
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(
                _guardando ? 'Guardando...' : 'Guardar cambios',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGrupos() {
    final grupos = <String>[];
    for (final m in _todosModulos) {
      if (!grupos.contains(m.grupo)) grupos.add(m.grupo);
    }

    final widgets = <Widget>[];
    for (final grupo in grupos) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(grupo,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: Color(0xFF455A64), letterSpacing: 0.5)),
      ));
      for (final mod in _todosModulos.where((m) => m.grupo == grupo)) {
        final activo = _seleccionados.contains(mod.id);
        widgets.add(GestureDetector(
          onTap: () => setState(() {
            if (activo) _seleccionados.remove(mod.id);
            else _seleccionados.add(mod.id);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: activo ? mod.color.withValues(alpha: 0.08) : const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: activo ? mod.color : Colors.grey[200]!,
                width: activo ? 1.5 : 1,
              ),
            ),
            child: Row(children: [
              Icon(
                activo ? Icons.check_box : Icons.check_box_outline_blank,
                size: 20,
                color: activo ? mod.color : Colors.grey[400],
              ),
              const SizedBox(width: 10),
              Icon(mod.icono, size: 16,
                  color: activo ? mod.color : Colors.grey[500]),
              const SizedBox(width: 8),
              Text(mod.nombre,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: activo ? mod.color : Colors.black87)),
            ]),
          ),
        ));
      }
    }
    return widgets;
  }
}

class _ErrorChip extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;
  const _ErrorChip({required this.mensaje, required this.onReintentar});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber, color: Colors.red, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Text('Error cargando stats de plataforma',
            style: const TextStyle(fontSize: 11, color: Colors.red))),
        TextButton(onPressed: onReintentar,
            child: const Text('Reintentar', style: TextStyle(fontSize: 11))),
      ]),
    );
  }
}


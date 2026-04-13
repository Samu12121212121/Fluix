import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:planeag_flutter/core/config/planes_config.dart';

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
          ? DateTime.tryParse(m['fechaFin'] as String)
          : null,
      activa: m['activa'] as bool? ?? false,
      packsActivos: (m['packsActivos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      addonsActivos: (m['addonsActivos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      empleadosNomina: (m['empleadosNomina'] as num?)?.toInt() ?? 0,
      precioTotal: (m['precioTotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLANES — Ahora se leen desde PlanesConfig (core/config/planes_config.dart)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class GestionarCuentasScreen extends StatefulWidget {
  const GestionarCuentasScreen({super.key});

  @override
  State<GestionarCuentasScreen> createState() => _GestionarCuentasScreenState();
}

class _GestionarCuentasScreenState extends State<GestionarCuentasScreen> {
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  List<_CuentaCliente> _cuentas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarCuentas();
  }

  // ── Cargar lista ───────────────────────────────────────────────────────────

  Future<void> _cargarCuentas() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final result = await _functions
          .httpsCallable('listarCuentasClientes')
          .call<Map<String, dynamic>>();

      final data = result.data;
      final raw = (data['cuentas'] as List<dynamic>? ?? []);
      setState(() {
        _cuentas =
            raw.map((e) => _CuentaCliente.fromMap(Map<String, dynamic>.from(e as Map))).toList();
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar cuentas: $e';
        _cargando = false;
      });
    }
  }

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

  // ── Abrir diálogo upgrade ──────────────────────────────────────────────────

  Future<void> _abrirUpgrade(_CuentaCliente cuenta) async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FormUpgradePlan(cuenta: cuenta),
    );
    if (resultado == true) _cargarCuentas();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            // ── Banner informativo ──────────────────────────────────────────
            _BannerInfoPago(),
            // ── Barra de acciones ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.manage_accounts,
                      color: Color(0xFF0D47A1), size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    'Gestión de Cuentas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xFF0D47A1)),
                    onPressed: _cargarCuentas,
                    tooltip: 'Recargar',
                  ),
                ],
              ),
            ),
            // ── Lista de cuentas ────────────────────────────────────────────
            Expanded(child: _buildBody()),
          ],
        ),
        // ── FAB ─────────────────────────────────────────────────────────────
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: _abrirFormNuevaCuenta,
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add),
            label: const Text('Nueva cuenta'),
          ),
        ),
      ],
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
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _cargarCuentas, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_cuentas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'Aún no hay cuentas de clientes',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pulsa + para crear la primera',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarCuentas,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _cuentas.length,
        itemBuilder: (ctx, i) => _TarjetaCuenta(
          cuenta: _cuentas[i],
          onUpgrade: () => _abrirUpgrade(_cuentas[i]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Banner info pago web
// ─────────────────────────────────────────────────────────────────────────────

class _BannerInfoPago extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE3F2FD), Color(0xFFF3E5F5)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF1565C0), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 12.5, color: Color(0xFF1a1a2e)),
                children: [
                  TextSpan(
                    text: 'Las suscripciones se pagan en tu web ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text:
                        '(evitando el 30% de Apple). Cuando alguien compra, recibes una notificación push y puedes crear la cuenta aquí.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: Tarjeta de cuenta
// ─────────────────────────────────────────────────────────────────────────────

class _TarjetaCuenta extends StatelessWidget {
  final _CuentaCliente cuenta;
  final VoidCallback onUpgrade;

  const _TarjetaCuenta({required this.cuenta, required this.onUpgrade});

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _colorPlan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _colorPlan.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _planLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _colorPlan),
                  ),
                ),
              ],
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
            const SizedBox(height: 10),
            // Botón upgrade
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onUpgrade,
                icon: const Icon(Icons.upgrade, size: 16),
                label: const Text('Cambiar plan / Renovar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D47A1),
                  side: const BorderSide(color: Color(0xFF0D47A1)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
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
  final _nombreCtrl = TextEditingController();
  final _propietarioCtrl = TextEditingController();
  final _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  // V2: packs y addons
  final Set<String> _packsSeleccionados = {};
  final Set<String> _addonsSeleccionados = {};

  String _tipoNegocio = 'Peluquería / Estética';
  bool _creando = false;

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

  double get _precioTotal => PlanesConfig.calcularPrecioTotal(
        packsActivos: _packsSeleccionados.toList(),
        addonsActivos: _addonsSeleccionados.toList(),
      );

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nombreCtrl.dispose();
    _propietarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _crear() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _creando = true);

    try {
      final result = await _functions
          .httpsCallable('crearCuentaConPlan')
          .call<Map<String, dynamic>>({
        'email': _emailCtrl.text.trim().toLowerCase(),
        'planId': 'basico',
        'nombreEmpresa': _nombreCtrl.text.trim(),
        'tipoNegocio': _tipoNegocio,
        'nombrePropietario': _propietarioCtrl.text.trim(),
        'packsActivos': _packsSeleccionados.toList(),
        'addonsActivos': _addonsSeleccionados.toList(),
      });

      final data = result.data;
      final tempPassword = data['tempPassword'] as String? ?? '';
      final planNombre = data['planNombre'] as String? ?? 'Plan Base';

      if (mounted) {
        Navigator.pop(context);
        // Mostrar contraseña temporal
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _DialogCredenciales(
            email: _emailCtrl.text.trim(),
            tempPassword: tempPassword,
            planNombre: planNombre,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      _mostrarError(e.message ?? e.code);
    } catch (e) {
      _mostrarError('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _creando = false);
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
              const Text(
                'Crear nueva cuenta',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Se enviará un email con las credenciales al cliente.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Plan base (siempre incluido)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PlanesConfig.planBase.color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: PlanesConfig.planBase.color.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.check_circle, color: PlanesConfig.planBase.color, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${PlanesConfig.planBase.nombre} — ${PlanesConfig.planBase.precioAnual.toStringAsFixed(0)}€/año',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: PlanesConfig.planBase.color)),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              // Packs
              const Text('Packs opcionales',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
              const SizedBox(height: 6),
              ...PlanesConfig.todosPacks.map((pack) => _CheckboxItem(
                titulo: pack.nombre,
                subtitulo: pack.descripcion,
                precio: '+${pack.precioAnual.toStringAsFixed(0)}€/año',
                color: pack.color,
                icono: pack.icono,
                seleccionado: _packsSeleccionados.contains(pack.id),
                onChanged: (v) => setState(() {
                  if (v) _packsSeleccionados.add(pack.id);
                  else _packsSeleccionados.remove(pack.id);
                }),
              )),

              // Add-ons
              const Text('Add-ons opcionales',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1))),
              const SizedBox(height: 6),
              ...PlanesConfig.todosAddons.map((addon) => _CheckboxItem(
                titulo: addon.nombre,
                subtitulo: addon.descripcion,
                precio: addon.precioLabel,
                color: addon.color,
                icono: addon.icono,
                seleccionado: _addonsSeleccionados.contains(addon.id),
                onChanged: (v) => setState(() {
                  if (v) _addonsSeleccionados.add(addon.id);
                  else _addonsSeleccionados.remove(addon.id);
                }),
              )),

              // Precio total
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE3F2FD), Color(0xFFF3E5F5)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.euro, color: Color(0xFF0D47A1), size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Precio total', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  Text('${_precioTotal.toStringAsFixed(0)}€/año',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0D47A1))),
                ]),
              ),

              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _deco('Email del cliente *', Icons.email_outlined),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Obligatorio';
                  if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v)) {
                    return 'Email no válido';
                  }
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
              const SizedBox(height: 8),

              // Info staff email
              _InfoStaffEmail(),

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
                    _creando ? 'Creando cuenta...' : 'Crear cuenta y enviar email',
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






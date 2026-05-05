import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/widget_manager_service.dart';
import '../../../services/suscripcion_service.dart';
import '../../../domain/modelos/widget_config.dart';
import 'configuracion_widgets_screen.dart' show ConfiguracionWidgetsScreen;
import 'pantallas_configuracion_extras.dart';

class ConfiguracionDashboardScreen extends StatefulWidget {
  final String empresaId;

  const ConfiguracionDashboardScreen({super.key, required this.empresaId});

  @override
  State<ConfiguracionDashboardScreen> createState() =>
      _ConfiguracionDashboardScreenState();
}

class _ConfiguracionDashboardScreenState
    extends State<ConfiguracionDashboardScreen> {
  final WidgetManagerService _widgetService = WidgetManagerService();
  bool _cargando = false;

  PlanModulo _planPrincipal = PlanModulo.basico;
  Set<PlanModulo> _packsContratados  = {};
  Set<PlanModulo> _addOnsContratados = {};

  // Número de usuarios y empleados activos para calcular precio dinámico de nóminas
  int _numUsuarios  = 1;
  int _numEmpleados = 0;

  @override
  void initState() {
    super.initState();
    _cargarPlan();
    _cargarPersonas();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS LOCALES
  // ═══════════════════════════════════════════════════════════════════════════

  Color _planColor(PlanModulo? plan) {
    switch (plan) {
      case PlanModulo.fiscal:  return const Color(0xFF388E3C);
      case PlanModulo.gestion: return const Color(0xFF7B1FA2);
      case PlanModulo.tienda:  return const Color(0xFFE65100);
      case PlanModulo.nominas: return const Color(0xFF00897B);
      default:                 return const Color(0xFF1976D2);
    }
  }

  String _planNombre(PlanModulo? plan) {
    switch (plan) {
      case PlanModulo.fiscal:  return 'Pack Fiscal AI';
      case PlanModulo.gestion: return 'Pack Gestión';
      case PlanModulo.tienda:  return 'Pack Tienda Online';
      case PlanModulo.nominas: return 'Add-on Nóminas';
      default:                 return 'Plan Base';
    }
  }

  /// Precio para cabeceras de sección y diálogo de info.
  /// Nóminas usa precio dinámico: 5 € × (usuarios + empleados) / mes.
  String _planPrecio(PlanModulo? plan) {
    switch (plan) {
      case PlanModulo.fiscal:  return '430 €/año';
      case PlanModulo.gestion: return '370 €/año';
      case PlanModulo.tienda:  return '490 €/año';
      case PlanModulo.nominas:
        final total     = _numUsuarios + _numEmpleados;
        final precioMes = total * 5;
        return '5 € · persona · mes  ($precioMes €/mes)';
      default:                 return '310 €/año';
    }
  }

  IconData _planIcono(PlanModulo? plan) {
    switch (plan) {
      case PlanModulo.fiscal:  return Icons.account_balance;
      case PlanModulo.gestion: return Icons.workspace_premium;
      case PlanModulo.tienda:  return Icons.storefront;
      case PlanModulo.nominas: return Icons.payments;
      default:                 return Icons.star_outline;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CARGA DE PERSONAS (para precio dinámico de nóminas)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _cargarPersonas() async {
    try {
      final usuariosSnap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .where('activo', isEqualTo: true)
          .get();

      final empleadosSnap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('empleados')
          .where('activo', isEqualTo: true)
          .get();

      if (mounted) {
        setState(() {
          _numUsuarios  = usuariosSnap.docs.length.clamp(1, 9999);
          _numEmpleados = empleadosSnap.docs.length;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar personas para nóminas: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CARGA DEL PLAN DESDE FIRESTORE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _cargarPlan() async {
    try {
      final svc   = SuscripcionService();
      final datos = await svc.cargarSuscripcion(widget.empresaId);

      Set<PlanModulo> packs  = {};
      Set<PlanModulo> addons = {};

      if (datos != null) {
        final packsActivos = datos.packsActivos ?? [];
        if (packsActivos.contains('tienda'))  packs.add(PlanModulo.tienda);
        if (packsActivos.contains('gestion')) packs.add(PlanModulo.gestion);
        if (packsActivos.contains('fiscal'))  packs.add(PlanModulo.fiscal);
        if (packsActivos.contains('nominas')) addons.add(PlanModulo.nominas);
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('suscripcion')
            .doc('actual')
            .get();

        final data     = doc.data() ?? {};
        final packsRaw = data['packs_activos'];
        final List<String> packsList = packsRaw is List
            ? packsRaw.map((e) => e.toString()).toList()
            : [data['plan'] as String? ?? 'basico'];

        if (packsList.contains('tienda'))  packs.add(PlanModulo.tienda);
        if (packsList.contains('gestion')) packs.add(PlanModulo.gestion);
        if (packsList.contains('fiscal'))  packs.add(PlanModulo.fiscal);

        final addonsRaw = data['addons'];
        final List<String> addonsList = addonsRaw is List
            ? addonsRaw.map((e) => e.toString()).toList()
            : [];
        if (addonsList.contains('nominas')) addons.add(PlanModulo.nominas);
        if (addonsList.contains('tareas'))  addons.add(PlanModulo.nominas);
      }

      if (mounted) {
        setState(() {
          _planPrincipal     = PlanModulo.basico;
          _packsContratados  = packs;
          _addOnsContratados = addons;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar el plan: $e');
      if (mounted) {
        setState(() {
          _planPrincipal     = PlanModulo.basico;
          _packsContratados  = {};
          _addOnsContratados = {};
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LÓGICA DE PERMISOS
  // ═══════════════════════════════════════════════════════════════════════════

  bool _moduloPermitido(ModuloConfig modulo) {
    if (!modulo.incluidoEnPlan) {
      return _addOnsContratados.contains(modulo.plan);
    }
    if (modulo.plan == PlanModulo.basico) return true;
    return _packsContratados.contains(modulo.plan);
  }

  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFilaModulo(ModuloConfig modulo, PlanModulo plan) {
    final permitido  = _moduloPermitido(modulo);
    final planColor  = _planColor(plan);
    final planNombre = _planNombre(plan);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: modulo.activo && permitido
              ? planColor.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(
            modulo.icono,
            color: modulo.activo && permitido ? planColor : Colors.grey[400],
          ),
          title: Text(
            modulo.nombre,
            style: TextStyle(
              color: permitido ? Colors.black87 : Colors.grey[500],
            ),
          ),
          subtitle: permitido
              ? Text(
            modulo.descripcion,
            style: TextStyle(
              color: planColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          )
              : Row(
            children: [
              Icon(Icons.lock_outline, size: 11, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                'Requiere $planNombre',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          trailing: permitido
              ? Checkbox(
            value: modulo.activo,
            onChanged: (bool? value) {
              if (value != null) {
                _toggleModulo(modulo.id, value, modulo.nombre);
              }
            },
            activeColor: planColor,
          )
              : Tooltip(
            message: 'No incluido en tu plan actual',
            child: Icon(Icons.lock, color: Colors.grey[400], size: 22),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<ModuloConfig>>(
        stream: _widgetService.obtenerTodosModulos(widget.empresaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final modulos         = snapshot.data ?? [];
          // IDs que nunca deben aparecer en la configuración de módulos
          const _modulosOcultos = {
            'propietario',
            'citas_del_dia',
          };
          final modulosVisibles =
          modulos.where((m) => !_modulosOcultos.contains(m.id)).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildSeccionWidgetsDashboard(),
              const SizedBox(height: 20),
              _buildSeccionPlan(
                plan:    PlanModulo.basico,
                modulos: modulosVisibles
                    .where((m) =>
                m.plan == PlanModulo.basico && m.incluidoEnPlan)
                    .toList(),
              ),
              const SizedBox(height: 16),
              // Pack Fiscal AI — oculto temporalmente
              // _buildSeccionPlan(plan: PlanModulo.fiscal, ...),
              _buildSeccionPlan(
                plan:    PlanModulo.gestion,
                modulos: modulosVisibles
                    .where((m) =>
                m.plan == PlanModulo.gestion && m.incluidoEnPlan)
                    .toList(),
              ),
              const SizedBox(height: 16),
              _buildSeccionPlan(
                plan:    PlanModulo.tienda,
                modulos: modulosVisibles
                    .where((m) =>
                m.plan == PlanModulo.tienda && m.incluidoEnPlan)
                    .toList(),
              ),
              const SizedBox(height: 16),
              _buildSeccionAddOns(
                modulosVisibles
                    .where((m) => !m.incluidoEnPlan && m.id != 'nominas')
                    .toList(),
              ),
              const SizedBox(height: 16),
              _buildSeccionOtras(),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:  const Color(0xFF0D47A1).withValues(alpha: 0.3),
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
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tune, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Módulos y Configuración',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Activa o desactiva módulos según tu plan',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionWidgetsDashboard() {
    return _buildCard(
      icono:       Icons.widgets,
      iconColor:   const Color(0xFF4CAF50),
      titulo:      'Widgets del Dashboard',
      descripcion: 'Personaliza qué elementos aparecen en tu pantalla principal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<List<WidgetConfig>>(
            stream: _widgetService.obtenerWidgetsActivos(widget.empresaId),
            builder: (context, snapshot) {
              final activos = snapshot.data?.length ?? 0;
              return _buildEstadoBadge(
                  '$activos widgets activos', const Color(0xFF4CAF50));
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConfiguracionWidgetsScreen(
                      empresaId: widget.empresaId),
                ),
              ),
              icon:  const Icon(Icons.tune, size: 18),
              label: const Text('Personalizar Widgets'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionPlan({
    required PlanModulo       plan,
    required List<ModuloConfig> modulos,
  }) {
    final activosCount = modulos.where((m) => m.activo).length;
    final planColor    = _planColor(plan);
    final planNombre   = _planNombre(plan);
    final planPrecio   = _planPrecio(plan);
    final planIcono    = _planIcono(plan);
    final contratado   =
        plan == PlanModulo.basico || _packsContratados.contains(plan);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color:  Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: planColor.withValues(alpha: 0.08),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(
                      color: planColor.withValues(alpha: 0.2), width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: planColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(planIcono, color: planColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(planNombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(planPrecio,
                          style: TextStyle(
                              color: planColor.withValues(alpha: 0.8),
                              fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: contratado
                        ? planColor.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    contratado
                        ? '$activosCount/${modulos.length} activos'
                        : 'No contratado',
                    style: TextStyle(
                      color: contratado ? planColor : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...modulos.map((m) => _buildFilaModulo(m, plan)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSeccionAddOns(List<ModuloConfig> modulos) {
    if (modulos.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color:  Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withValues(alpha: 0.08),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(
                      color: const Color(0xFF00897B).withValues(alpha: 0.2),
                      width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_circle_outline,
                      color: Color(0xFF00897B), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add-ons',
                          style: TextStyle(
                              color: Color(0xFF00897B),
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text(
                          'Módulos adicionales contratables por separado',
                          style:
                          TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...modulos.map(_buildFilaModuloAddOn),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildFilaModuloAddOn(ModuloConfig modulo) {
    final permitido = _moduloPermitido(modulo);

    // Precio dinámico para nóminas
    String? precio = modulo.precioAdicional;
    if (modulo.plan == PlanModulo.nominas || modulo.id == 'nominas') {
      final total     = _numUsuarios + _numEmpleados;
      final precioMes = total * 5;
      precio = '5 € · persona · mes  —  $precioMes €/mes ahora '
          '($_numUsuarios usuarios + $_numEmpleados empleados)';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: permitido && modulo.activo
                  ? const Color(0xFF00897B).withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              modulo.icono,
              color: permitido && modulo.activo
                  ? const Color(0xFF00897B)
                  : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(modulo.nombre,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: permitido ? Colors.black87 : Colors.grey)),
                Text(modulo.descripcion,
                    style:
                    TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (precio != null)
                  Text('💰 $precio',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          permitido
              ? Switch(
            value: modulo.activo,
            onChanged: (v) =>
                _toggleModulo(modulo.id, v, modulo.nombre),
            activeThumbColor: const Color(0xFF00897B),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )
              : Tooltip(
            message: 'Add-on no contratado',
            child: Icon(Icons.lock, color: Colors.grey[400], size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionOtras() {
    return _buildCard(
      icono:       Icons.settings,
      iconColor:   const Color(0xFF9C27B0),
      titulo:      'Otras Configuraciones',
      descripcion: 'Ajustes adicionales de la aplicación',
      child: Column(
        children: [
          _buildItemOpciones(
            icono:       Icons.notifications,
            titulo:      'Notificaciones',
            descripcion: 'Activa o desactiva alertas y avisos push',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PantallaNotificaciones())),
          ),
          const Divider(height: 1),
          _buildItemOpciones(
            icono:       Icons.color_lens,
            titulo:      'Tema y Colores',
            descripcion: 'Modo oscuro y color principal de la app',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PantallaTemayColores())),
          ),
          const Divider(height: 1),
          _buildItemOpciones(
            icono:       Icons.backup,
            titulo:      'Copia de Seguridad',
            descripcion: 'Respalda tus datos en la nube',
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        PantallaBackup(empresaId: widget.empresaId))),
          ),
          const Divider(height: 1),
          _buildItemOpciones(
            icono:       Icons.info_outline,
            titulo:      'Acerca de los Planes',
            descripcion: 'Ver detalles y precios',
            onTap:       _mostrarInfoPlanes,
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icono,
    required Color    iconColor,
    required String   titulo,
    required String   descripcion,
    required Widget   child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color:  Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icono, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(descripcion,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoBadge(String texto, Color color) {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: color, size: 16),
          const SizedBox(width: 6),
          Text(texto,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildItemOpciones({
    required IconData     icono,
    required String       titulo,
    required String       descripcion,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icono, color: const Color(0xFF9C27B0), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(descripcion,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleModulo(
      String moduloId, bool activo, String nombre) async {
    try {
      await _widgetService.toggleModulo(
          widget.empresaId, moduloId, activo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${activo ? '✅' : '🔕'} Módulo "$nombre" '
                  '${activo ? 'activado' : 'desactivado'}'),
          backgroundColor:
          activo ? const Color(0xFF4CAF50) : Colors.orange,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIÁLOGO INFO PLANES — nóminas con precio dinámico
  // ═══════════════════════════════════════════════════════════════════════════

  void _mostrarInfoPlanes() {
    final totalPersonas    = _numUsuarios + _numEmpleados;
    final precioNominasMes = totalPersonas * 5;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFF0D47A1)),
            SizedBox(width: 8),
            Text('Planes disponibles'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoPlan(PlanModulo.basico, [
                'Dashboard con widgets personalizables',
                'Valoraciones y reseñas de clientes',
                'Estadísticas y KPIs en tiempo real',
                'Gestión de reservas y citas',
                'Contenido dinámico de tu web',
                'Gestión de clientes y CRM',
                'Gestión de equipo y roles',
                'Catálogo de servicios y precios',
              ]),
              const SizedBox(height: 12),
              // Pack Fiscal AI — oculto temporalmente de los planes visibles
              // _buildInfoPlan(PlanModulo.fiscal, [...]),
              const SizedBox(height: 0),
              _buildInfoPlan(PlanModulo.gestion, [
                'WhatsApp Business integrado',
                'Facturación completa con IVA',
                'TPV para cobros presenciales',
                'Control de vacaciones y ausencias',
              ]),
              const SizedBox(height: 12),
              _buildInfoPlan(PlanModulo.tienda, [
                'Gestión de pedidos online y presenciales',
                'Control de stock e inventario',
                'Sincronización app ↔ web en tiempo real',
              ]),
              const SizedBox(height: 16),
              // ── Add-ons con precio dinámico de nóminas ───────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                  const Color(0xFF00897B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF00897B)
                          .withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.add_circle_outline,
                          color: Color(0xFF00897B), size: 18),
                      SizedBox(width: 6),
                      Text('Add-ons',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00897B),
                              fontSize: 14)),
                    ]),
                    const SizedBox(height: 8),
                    // Nóminas — oculto temporalmente
                    const SizedBox(height: 0),
                    const SizedBox(height: 6),
                    const Text(
                      '• Tareas: sistema de productividad por usuario/mes\n'
                          '• Módulos personalizados bajo consulta',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido')),
        ],
      ),
    );
  }

  Widget _buildInfoPlan(PlanModulo plan, List<String> caracteristicas) {
    final planColor  = _planColor(plan);
    final planNombre = _planNombre(plan);
    final planPrecio = _planPrecio(plan);
    final planIcono  = _planIcono(plan);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: planColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: planColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(planIcono, color: planColor, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(planNombre,
                  style: TextStyle(
                      color: planColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
            Text(planPrecio,
                style: TextStyle(
                    color: planColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          ...caracteristicas.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [
              Icon(Icons.check, color: planColor, size: 14),
              const SizedBox(width: 6),
              Expanded(
                  child: Text(c,
                      style: const TextStyle(fontSize: 12))),
            ]),
          )),
        ],
      ),
    );
  }
}
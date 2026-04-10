import 'package:flutter/material.dart';
import '../../../services/contenido_web_service.dart';
import '../../../services/widget_manager_service.dart';
import '../../../domain/modelos/widget_config.dart';
import 'configuracion_widgets_screen.dart';
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
  // ignore: unused_field
  final ContenidoWebService _contenidoWebService = ContenidoWebService();
  final WidgetManagerService _widgetService = WidgetManagerService();
  bool _cargando = false;

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
          final modulos = snapshot.data ?? ModulosDisponibles.todos.map((m) => m.copyWith(
            activo: ModulosDisponibles.activosPorDefecto.contains(m.id),
          )).toList();
          // Ocultar módulo propietario de la lista configurable
          final modulosVisibles = modulos.where((m) => m.id != 'propietario').toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildSeccionWidgetsDashboard(),
              const SizedBox(height: 20),
              _buildSeccionPlan(
                plan: PlanModulo.basico,
                modulos: modulosVisibles.where((m) => m.plan == PlanModulo.basico && m.incluidoEnPlan).toList(),
              ),
              const SizedBox(height: 16),
              _buildSeccionPlan(
                plan: PlanModulo.gestion,
                modulos: modulosVisibles.where((m) => m.plan == PlanModulo.gestion && m.incluidoEnPlan).toList(),
              ),
              const SizedBox(height: 16),
              _buildSeccionPlan(
                plan: PlanModulo.tienda,
                modulos: modulosVisibles.where((m) => m.plan == PlanModulo.tienda && m.incluidoEnPlan).toList(),
              ),
              const SizedBox(height: 16),
              _buildSeccionAddOns(
                modulosVisibles.where((m) => !m.incluidoEnPlan).toList(),
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

  // ── HEADER ────────────────────────────────────────────────────────────────

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
                    fontWeight: FontWeight.bold,
                  ),
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

  // ── WIDGETS DEL DASHBOARD ─────────────────────────────────────────────────

  Widget _buildSeccionWidgetsDashboard() {
    return _buildCard(
      icono: Icons.widgets,
      iconColor: const Color(0xFF4CAF50),
      titulo: 'Widgets del Dashboard',
      descripcion: 'Personaliza qué elementos aparecen en tu pantalla principal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<List<WidgetConfig>>(
            stream: _widgetService.obtenerWidgetsActivos(widget.empresaId),
            builder: (context, snapshot) {
              final activos = snapshot.data?.length ?? 0;
              return _buildEstadoBadge(
                '$activos widgets activos',
                const Color(0xFF4CAF50),
              );
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
              icon: const Icon(Icons.tune, size: 18),
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

  // ── SECCIÓN DE PLAN ───────────────────────────────────────────────────────

  Widget _buildSeccionPlan({
    required PlanModulo plan,
    required List<ModuloConfig> modulos,
  }) {
    final activosCount = modulos.where((m) => m.activo).length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabecera del plan
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: plan.color.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(
                      color: plan.color.withValues(alpha: 0.2), width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: plan.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(plan.icono, color: plan.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.nombre,
                        style: TextStyle(
                          color: plan.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        plan.precio,
                        style: TextStyle(
                          color: plan.color.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: plan.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$activosCount/${modulos.length} activos',
                    style: TextStyle(
                      color: plan.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de módulos del plan
          ...modulos.map((m) => _buildFilaModulo(m, plan)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── ADD-ONS ───────────────────────────────────────────────────────────────

  Widget _buildSeccionAddOns(List<ModuloConfig> modulos) {
    if (modulos.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
                        style: TextStyle(
                            color: Color(0xFF00897B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...modulos.map((m) => _buildFilaModuloAddOn(m)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── FILA DE MÓDULO ────────────────────────────────────────────────────────

  static final _modulosFijos = ModulosDisponibles.siempreActivos;

  Widget _buildFilaModulo(ModuloConfig modulo, PlanModulo plan) {
    final esFijo = _modulosFijos.contains(modulo.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: modulo.activo
                  ? plan.color.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              modulo.icono,
              color: modulo.activo ? plan.color : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      modulo.nombre,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: modulo.activo ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    if (esFijo) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: plan.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Siempre activo',
                          style: TextStyle(
                              color: plan.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  modulo.descripcion,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          esFijo
              ? Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.lock_outline,
                      size: 18,
                      color: plan.color.withValues(alpha: 0.5)),
                )
              : Switch(
                  value: modulo.activo,
                  onChanged: (v) =>
                      _toggleModulo(modulo.id, v, modulo.nombre),
                  activeThumbColor: plan.color,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
        ],
      ),
    );
  }

  Widget _buildFilaModuloAddOn(ModuloConfig modulo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: modulo.activo
                  ? const Color(0xFF00897B).withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              modulo.icono,
              color: modulo.activo ? const Color(0xFF00897B) : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modulo.nombre,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: modulo.activo ? Colors.black87 : Colors.grey,
                  ),
                ),
                Text(
                  modulo.descripcion,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (modulo.precioAdicional != null)
                  Text(
                    '💰 ${modulo.precioAdicional}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF00897B),
                        fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          Switch(
            value: modulo.activo,
            onChanged: (v) => _toggleModulo(modulo.id, v, modulo.nombre),
            activeThumbColor: const Color(0xFF00897B),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  // ── OTRAS CONFIGURACIONES ─────────────────────────────────────────────────

  Widget _buildSeccionOtras() {
    return _buildCard(
      icono: Icons.settings,
      iconColor: const Color(0xFF9C27B0),
      titulo: 'Otras Configuraciones',
      descripcion: 'Ajustes adicionales de la aplicación',
      child: Column(
        children: [
          _buildItemOpciones(
            icono: Icons.notifications,
            titulo: 'Notificaciones',
            descripcion: 'Activa o desactiva alertas y avisos push',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PantallaNotificaciones(),
              ),
            ),
          ),
          const Divider(height: 1),
          _buildItemOpciones(
            icono: Icons.color_lens,
            titulo: 'Tema y Colores',
            descripcion: 'Modo oscuro y color principal de la app',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PantallaTemayColores(),
              ),
            ),
          ),
          const Divider(height: 1),
          _buildItemOpciones(
            icono: Icons.backup,
            titulo: 'Copia de Seguridad',
            descripcion: 'Respalda tus datos en la nube',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PantallaBackup(empresaId: widget.empresaId),
              ),
            ),
          ),
          const Divider(height: 1),
          _buildItemOpciones(
            icono: Icons.info_outline,
            titulo: 'Acerca de los Planes',
            descripcion: 'Ver detalles y precios',
            onTap: _mostrarInfoPlanes,
          ),
        ],
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Widget _buildCard({
    required IconData icono,
    required Color iconColor,
    required String titulo,
    required String descripcion,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              style:
                  TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildItemOpciones({
    required IconData icono,
    required String titulo,
    required String descripcion,
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
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ── ACCIONES ──────────────────────────────────────────────────────────────

  Future<void> _toggleModulo(
      String moduloId, bool activo, String nombre) async {
    try {
      await _widgetService.toggleModulo(widget.empresaId, moduloId, activo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${activo ? '✅' : '🔕'} Módulo "$nombre" ${activo ? 'activado' : 'desactivado'}'),
            backgroundColor:
                activo ? const Color(0xFF4CAF50) : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }


  void _mostrarInfoPlanes() {
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
                'Dashboard personalizable',
                'Valoraciones de clientes',
                'Estadísticas en tiempo real',
                'Gestión de reservas',
                'Módulo de citas opcional',
                'Contenido web (opcional)',
              ]),
              const SizedBox(height: 12),
              _buildInfoPlan(PlanModulo.gestion, [
                'Todo el Plan Base',
                'Módulo WhatsApp incluido',
                'Facturación completa con IVA',
                'Resumen fiscal mensual',
              ]),
              const SizedBox(height: 12),
              _buildInfoPlan(PlanModulo.tienda, [
                'Todo el Pack Gestión',
                'Catálogo de productos',
                'Pedidos online y presenciales',
                'Sincronización app ↔ web en tiempo real',
              ]),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('➕ Add-ons',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00897B))),
                    SizedBox(height: 6),
                    Text(
                      '• WhatsApp suelto: +50€/año (sobre cualquier plan)\n'
                      '• Tareas: precio por usuario/mes (disponible en todos los planes)',
                      style: TextStyle(fontSize: 12),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: plan.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: plan.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(plan.icono, color: plan.color, size: 18),
              const SizedBox(width: 6),
              Text(plan.nombre,
                  style: TextStyle(
                      color: plan.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const Spacer(),
              Text(plan.precio,
                  style: TextStyle(
                      color: plan.color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ...caracteristicas.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(Icons.check, color: plan.color, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                        child:
                            Text(c, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}



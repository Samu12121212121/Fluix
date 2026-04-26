import 'package:flutter/material.dart';
import 'package:planeag_flutter/domain/modelos/widget_config.dart' show WidgetConfig;
import '../../../services/widget_manager_service.dart';
import '../../../services/suscripcion_service.dart';

/// Mapa de widget ID → pack requerido ('gestion', 'tienda', o null = siempre disponible)
const Map<String, String?> _packRequeridoPorWidget = {
  'resumen_facturacion': 'gestion',
  'resumen_pedidos': 'tienda',
};

class ConfiguracionWidgetsScreen extends StatefulWidget {
  final String empresaId;

  const ConfiguracionWidgetsScreen({super.key, required this.empresaId});

  @override
  State<ConfiguracionWidgetsScreen> createState() => _ConfiguracionWidgetsScreenState();
}

class _ConfiguracionWidgetsScreenState extends State<ConfiguracionWidgetsScreen> {
  final WidgetManagerService _widgetService = WidgetManagerService();
  bool _guardandoCambios = false;
  List<String> _packsActivos = [];

  @override
  void initState() {
    super.initState();
    _cargarPacks();
  }

  Future<void> _cargarPacks() async {
    try {
      final svc = SuscripcionService();
      final datos = await svc.cargarSuscripcion(widget.empresaId);
      if (datos != null && mounted) {
        setState(() => _packsActivos = datos.packsActivos);
      }
    } catch (_) {}
  }

  bool _widgetPermitido(String widgetId) {
    final packRequerido = _packRequeridoPorWidget[widgetId];
    if (packRequerido == null) return true;
    return _packsActivos.contains(packRequerido);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar Dashboard'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _mostrarAyuda,
            icon: const Icon(Icons.help_outline),
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reset',
                child: const Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Resetear por defecto'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'stats',
                child: const Row(
                  children: [
                    Icon(Icons.analytics, color: Color(0xFF1976D2)),
                    SizedBox(width: 8),
                    Text('Ver estadísticas'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'reset':
                  _resetearWidgets();
                  break;
                case 'stats':
                  _mostrarEstadisticas();
                  break;
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<List<WidgetConfig>>(
              stream: _widgetService.obtenerConfiguracionWidgets(widget.empresaId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEstadoVacio();
                }
                final widgets = snapshot.data!;
                return _buildListaWidgets(widgets);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.widgets, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Personaliza tu Dashboard',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Elige qué widgets quieres ver y en qué orden',
                          style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white70, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Activa los widgets que te sean útiles. Puedes reordenarlos manteniendo presionado y arrastrando.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaWidgets(List<WidgetConfig> widgets) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widgets.length,
      itemBuilder: (context, index) {
        final widget = widgets[index];
        return _buildWidgetCard(widget);
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = widgets.removeAt(oldIndex);
          widgets.insert(newIndex, item);
        });
        _widgetService.reordenarWidgets(this.widget.empresaId, widgets);
      },
    );
  }

  Widget _buildWidgetCard(WidgetConfig widgetConfig) {
    final implementado = WidgetConfig.implementados.contains(widgetConfig.id);
    final packPermitido = _widgetPermitido(widgetConfig.id);
    final disponible = implementado && packPermitido;
    const colorActivo = Color(0xFF4CAF50);
    final colorBorde = widgetConfig.activo && disponible ? colorActivo : Colors.transparent;

    return Card(
      key: ValueKey(widgetConfig.id),
      margin: const EdgeInsets.only(bottom: 12),
      elevation: widgetConfig.activo && disponible ? 3 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorBorde, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widgetConfig.activo && disponible
                      ? colorActivo.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widgetConfig.icono,
                  color: widgetConfig.activo && disponible ? colorActivo : Colors.grey[500],
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widgetConfig.nombre,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: disponible ? Colors.black87 : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(widgetConfig.descripcion,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 6),
                    // ── Badges — envueltos en Flexible para evitar overflow ──
                    Row(
                      children: [
                        Flexible(
                          child: !packPermitido
                              ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, size: 10, color: Colors.red[700]),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    'Requiere Pack ${_packRequeridoPorWidget[widgetConfig.id] == 'gestion' ? 'Gestión' : 'Tienda'}',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red[700]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                              : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: implementado
                                  ? const Color(0xFF1976D2).withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              implementado ? '✅ Disponible' : '🚧 Próximamente',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: implementado ? const Color(0xFF1976D2) : Colors.orange[800],
                              ),
                            ),
                          ),
                        ),
                        if (widgetConfig.activo && disponible) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorActivo.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Activo',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4CAF50))),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Switch(
                    value: widgetConfig.activo && disponible,
                    onChanged: (!disponible || _guardandoCambios)
                        ? null
                        : (v) => _toggleWidget(widgetConfig, v),
                    activeThumbColor: colorActivo,
                  ),
                  Icon(Icons.drag_handle,
                      color: disponible ? Colors.grey[400] : Colors.grey[300], size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
              child: Icon(Icons.widgets, size: 64, color: Colors.grey[400]),
            ),
            const SizedBox(height: 24),
            Text('No hay widgets configurados',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text('Los widgets se configurarán automáticamente',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _widgetService.resetearWidgets(widget.empresaId),
              icon: const Icon(Icons.refresh),
              label: const Text('Inicializar Widgets'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleWidget(WidgetConfig widgetConfig, bool value) async {
    setState(() => _guardandoCambios = true);
    try {
      await _widgetService.toggleWidget(widget.empresaId, widgetConfig.id, value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Widget ${widgetConfig.nombre} ${value ? 'activado' : 'desactivado'}'),
          backgroundColor: const Color(0xFF4CAF50),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFF44336),
        ));
      }
    } finally {
      if (mounted) setState(() => _guardandoCambios = false);
    }
  }

  void _resetearWidgets() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.refresh, color: Colors.orange),
          SizedBox(width: 8),
          Text('Resetear Configuración'),
        ]),
        content: const Text(
            '¿Estás seguro de que quieres resetear la configuración de widgets a los valores por defecto?\n\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _widgetService.resetearWidgets(widget.empresaId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Configuración reseteada a valores por defecto'),
                  backgroundColor: Color(0xFF4CAF50),
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Resetear'),
          ),
        ],
      ),
    );
  }

  void _mostrarEstadisticas() async {
    final stats = await _widgetService.obtenerEstadisticasUso(widget.empresaId);
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.analytics, color: Color(0xFF1976D2)),
            SizedBox(width: 8),
            Text('Estadísticas de Widgets'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow('Total widgets', '${stats['total_widgets'] ?? 0}'),
              _buildStatRow('Widgets activos', '${stats['widgets_activos'] ?? 0}'),
              _buildStatRow('Widgets inactivos', '${stats['widgets_inactivos'] ?? 0}'),
              _buildStatRow('Porcentaje de uso', '${(stats['porcentaje_uso'] ?? 0).toStringAsFixed(1)}%'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
          ],
        ),
      );
    }
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _mostrarAyuda() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.help, color: Color(0xFF1976D2)),
          SizedBox(width: 8),
          Text('Cómo Funciona'),
        ]),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Personalización del Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(
                '• Activa los widgets que te sean útiles con el switch\n'
                    '• Solo puedes activar los marcados como ✅ Disponible\n'
                    '• Los marcados 🚧 Próximamente estarán disponibles pronto\n'
                    '• Arrastra para reordenar (mantén presionado el ícono ≡)\n'
                    '• Los widgets activos aparecerán en tu dashboard principal',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
        ],
      ),
    );
  }
}
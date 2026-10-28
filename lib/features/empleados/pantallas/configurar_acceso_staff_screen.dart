import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../services/widget_manager_service.dart';
import '../../../services/suscripcion_service.dart';

/// Pantalla para que el admin configure qué ven TODOS los usuarios con rol staff.
/// Guarda en empresas/{id}/configuracion/staff_config:
///   - modulos_sidebar: módulos del sidebar que ve el staff
///   - web_modulos_fijos: módulos de la sección 2 del hub web que ve el staff
class ConfigurarAccesoStaffScreen extends StatefulWidget {
  final String empresaId;

  const ConfigurarAccesoStaffScreen({super.key, required this.empresaId});

  @override
  State<ConfigurarAccesoStaffScreen> createState() =>
      _ConfigurarAccesoStaffScreenState();
}

class _ConfigurarAccesoStaffScreenState
    extends State<ConfigurarAccesoStaffScreen> {
  final _db = FirebaseFirestore.instance;
  bool _cargando = true;
  bool _guardando = false;

  // Sidebar modules disponibles en la empresa
  List<String> _modulosEmpresa = [];

  // Selección actual
  List<String> _sidebarSel = ['web'];
  List<String> _webFijosSel = ['campanas'];

  static const _sidebarInfo = <String, ({IconData icono, String nombre})>{
    'dashboard':    (icono: Icons.dashboard_rounded,       nombre: 'Dashboard'),
    'reservas':     (icono: Icons.calendar_today_rounded,  nombre: 'Reservas'),
    'citas':        (icono: Icons.event_rounded,           nombre: 'Citas'),
    'clientes':     (icono: Icons.people_rounded,          nombre: 'Clientes'),
    'valoraciones': (icono: Icons.star_rounded,            nombre: 'Valoraciones'),
    'tareas':       (icono: Icons.task_alt_rounded,        nombre: 'Tareas'),
    'empleados':    (icono: Icons.badge_rounded,           nombre: 'Personal'),
    'fichaje':      (icono: Icons.access_time_rounded,     nombre: 'Fichaje'),
    'web':          (icono: Icons.language_rounded,        nombre: 'Contenido Web'),
    'tpv':          (icono: Icons.point_of_sale_rounded,   nombre: 'TPV'),
  };

  static const _webFijosInfo = <String, ({IconData icono, String nombre})>{
    'mensajes':  (icono: Icons.chat_bubble_rounded,  nombre: 'Mensajes de contacto'),
    'analytics': (icono: Icons.bar_chart_rounded,    nombre: 'Analytics'),
    'campanas':  (icono: Icons.campaign_rounded,     nombre: 'Email (campañas)'),
    'config':    (icono: Icons.settings_rounded,     nombre: 'Configuración web'),
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final modulosEmpresaSnap = await WidgetManagerService()
          .obtenerModulosActivos(widget.empresaId)
          .first;
      final modulosEnPlan = SuscripcionService().getModulosActivos();
      const activosPorDefecto = {
        'dashboard', 'reservas', 'citas', 'clientes', 'valoraciones', 'fichaje', 'empleados',
      };
      final activos = modulosEmpresaSnap
          .where((m) => m.activo)
          .map((m) => m.id)
          .where((id) => !const {'propietario', 'explorar', 'citas_del_dia'}.contains(id))
          .where((id) =>
              activosPorDefecto.contains(id) ||
              modulosEnPlan.contains(id) ||
              (id == 'web' && modulosEnPlan.contains('contenido_web')))
          .toList();

      final cfgDoc = await _db
          .collection('empresas').doc(widget.empresaId)
          .collection('configuracion').doc('staff_config')
          .get();

      List<String> sidebar = ['web'];
      List<String> webFijos = ['campanas'];
      if (cfgDoc.exists) {
        final data = cfgDoc.data()!;
        final s = (data['modulos_sidebar'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList();
        final w = (data['web_modulos_fijos'] as List<dynamic>?)
            ?.map((e) => e.toString()).toList();
        if (s != null && s.isNotEmpty) sidebar = s;
        if (w != null) webFijos = w;
      }

      setState(() {
        _modulosEmpresa = activos;
        _sidebarSel = sidebar.where((id) => activos.contains(id)).toList();
        _webFijosSel = webFijos;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await _db
          .collection('empresas').doc(widget.empresaId)
          .collection('configuracion').doc('staff_config')
          .set({
        'modulos_sidebar':    _sidebarSel,
        'web_modulos_fijos':  _webFijosSel,
        'actualizado_en':     FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Acceso de Staff actualizado'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FluixAppBar(titulo: 'Acceso del equipo (Staff)', showLeading: true),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _infoCard(),
                const SizedBox(height: 20),
                _seccion(
                  titulo: 'Módulos del sidebar',
                  subtitulo: 'Qué secciones aparecen en el menú izquierdo',
                  icono: Icons.menu_rounded,
                  children: _sidebarInfo.entries
                      .where((e) => _modulosEmpresa.contains(e.key))
                      .map((e) => _check(
                            id: e.key,
                            icono: e.value.icono,
                            nombre: e.value.nombre,
                            selected: _sidebarSel.contains(e.key),
                            onChanged: (v) => setState(() {
                              if (v) {
                                _sidebarSel.add(e.key);
                              } else {
                                _sidebarSel.remove(e.key);
                              }
                            }),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 20),
                _seccion(
                  titulo: 'Hub Web — sección 2',
                  subtitulo: 'Módulos visibles en la segunda página del hub web',
                  icono: Icons.language_rounded,
                  children: _webFijosInfo.entries
                      .map((e) => _check(
                            id: e.key,
                            icono: e.value.icono,
                            nombre: e.value.nombre,
                            selected: _webFijosSel.contains(e.key),
                            onChanged: (v) => setState(() {
                              if (v) {
                                _webFijosSel.add(e.key);
                              } else {
                                _webFijosSel.remove(e.key);
                              }
                            }),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_rounded),
                    label: const Text('Guardar cambios'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Esta configuración afecta a todos los usuarios con rol "Staff" '
            'que no tengan módulos configurados individualmente.',
            style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8)),
          ),
        ),
      ]),
    );
  }

  Widget _seccion({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            Icon(icono, size: 18, color: const Color(0xFF3B82F6)),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(subtitulo,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ])),
          ]),
        ),
        const Divider(height: 1),
        ...children,
      ]),
    );
  }

  Widget _check({
    required String id,
    required IconData icono,
    required String nombre,
    required bool selected,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      value: selected,
      onChanged: (v) => onChanged(v ?? false),
      secondary: Icon(icono, color: const Color(0xFF64748B), size: 20),
      title: Text(nombre, style: const TextStyle(fontSize: 13)),
      dense: true,
      activeColor: const Color(0xFF3B82F6),
      shape: const RoundedRectangleBorder(),
    );
  }
}

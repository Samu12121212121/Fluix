import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/utils/permisos_service.dart';

/// Pantalla para que el admin/propietario configure qué módulos
/// puede ver cada empleado.
class ConfigurarModulosEmpleadoScreen extends StatefulWidget {
  final String empresaId;
  final String empleadoUid;
  final String empleadoNombre;

  const ConfigurarModulosEmpleadoScreen({
    super.key,
    required this.empresaId,
    required this.empleadoUid,
    required this.empleadoNombre,
  });

  @override
  State<ConfigurarModulosEmpleadoScreen> createState() =>
      _ConfigurarModulosEmpleadoScreenState();
}

class _ConfigurarModulosEmpleadoScreenState
    extends State<ConfigurarModulosEmpleadoScreen> {
  final _db = FirebaseFirestore.instance;

  bool _cargando = true;
  bool _guardando = false;
  String _rol = 'staff';
  List<String> _modulosSeleccionados = [];
  bool _usarPersonalizados = false;

  // Mapa de módulos con icono y nombre legible
  static const _modulosInfo = <String, ({IconData icono, String nombre})>{
    'dashboard':    (icono: Icons.dashboard,           nombre: 'Dashboard'),
    'reservas':     (icono: Icons.calendar_today,      nombre: 'Reservas'),
    'citas':        (icono: Icons.event,               nombre: 'Citas'),
    'clientes':     (icono: Icons.people,              nombre: 'Clientes'),
    'valoraciones': (icono: Icons.star,                nombre: 'Valoraciones'),
    'estadisticas': (icono: Icons.bar_chart,           nombre: 'Estadísticas'),
    'servicios':    (icono: Icons.spa,                 nombre: 'Servicios'),
    'pedidos':      (icono: Icons.shopping_cart,        nombre: 'Pedidos'),
    'whatsapp':     (icono: Icons.chat,                nombre: 'WhatsApp Bot'),
    'tareas':       (icono: Icons.task_alt,            nombre: 'Tareas'),
    'empleados':    (icono: Icons.badge,               nombre: 'Empleados'),
    'facturacion':  (icono: Icons.receipt_long,        nombre: 'Facturación'),
    'nominas':      (icono: Icons.payments,            nombre: 'Nóminas'),
    'web':          (icono: Icons.web,                 nombre: 'Contenido Web'),
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final doc = await _db.collection('usuarios').doc(widget.empleadoUid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _rol = data['rol'] as String? ?? 'staff';
        final modulosGuardados = (data['modulos_permitidos'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList();

        if (modulosGuardados != null && modulosGuardados.isNotEmpty) {
          _usarPersonalizados = true;
          _modulosSeleccionados = modulosGuardados;
        } else {
          // Usar los por defecto del rol
          _usarPersonalizados = false;
          _modulosSeleccionados = _modulosPorDefectoRol(_rol);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _cargando = false);
  }

  List<String> _modulosPorDefectoRol(String rol) {
    switch (rol) {
      case 'propietario':
        return SesionUsuario.todosLosModulos.toList();
      case 'admin':
        return [
          'dashboard', 'reservas', 'citas', 'clientes', 'valoraciones',
          'estadisticas', 'servicios', 'pedidos', 'whatsapp', 'tareas', 'nominas',
        ];
      case 'staff':
        return ['reservas', 'citas', 'clientes', 'valoraciones'];
      default:
        return ['reservas', 'citas'];
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      if (_usarPersonalizados) {
        await _db.collection('usuarios').doc(widget.empleadoUid).update({
          'modulos_permitidos': _modulosSeleccionados,
        });
      } else {
        // Eliminar personalización → usar defaults del rol
        await _db.collection('usuarios').doc(widget.empleadoUid).update({
          'modulos_permitidos': FieldValue.delete(),
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Módulos actualizados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Módulos del empleado'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Info empleado ─────────────────────────
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF0D47A1),
                          child: Text(
                            widget.empleadoNombre.isNotEmpty
                                ? widget.empleadoNombre[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.empleadoNombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text('Rol: $_rol',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Toggle personalizado ──────────────────
                SwitchListTile(
                  title: const Text('Módulos personalizados',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _usarPersonalizados
                        ? 'Módulos configurados manualmente'
                        : 'Usando módulos por defecto del rol ($_rol)',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  value: _usarPersonalizados,
                  activeTrackColor: const Color(0xFF0D47A1).withValues(alpha: 0.5),
                  thumbColor: WidgetStatePropertyAll(
                    _usarPersonalizados ? const Color(0xFF0D47A1) : Colors.grey,
                  ),
                  onChanged: (v) {
                    setState(() {
                      _usarPersonalizados = v;
                      if (!v) {
                        _modulosSeleccionados = _modulosPorDefectoRol(_rol);
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),

                if (!_usarPersonalizados)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'El empleado verá los módulos por defecto de su rol ($_rol). '
                            'Activa "Módulos personalizados" para elegir manualmente.',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.blueGrey),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_usarPersonalizados) ...[
                  // ── Botones rápidos ─────────────────────
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _modulosSeleccionados =
                              SesionUsuario.todosLosModulos.toList();
                        }),
                        icon: const Icon(Icons.select_all, size: 16),
                        label: const Text('Todos',
                            style: TextStyle(fontSize: 12)),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _modulosSeleccionados = [];
                        }),
                        icon: const Icon(Icons.deselect, size: 16),
                        label: const Text('Ninguno',
                            style: TextStyle(fontSize: 12)),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _modulosSeleccionados = _modulosPorDefectoRol(_rol);
                        }),
                        icon: const Icon(Icons.restart_alt, size: 16),
                        label: const Text('Reset a rol',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ── Lista de módulos ────────────────────
                  ...SesionUsuario.todosLosModulos.map((modId) {
                    final info = _modulosInfo[modId];
                    final activo = _modulosSeleccionados.contains(modId);
                    return CheckboxListTile(
                      value: activo,
                      activeColor: const Color(0xFF0D47A1),
                      title: Row(
                        children: [
                          Icon(info?.icono ?? Icons.extension,
                              size: 20,
                              color: activo
                                  ? const Color(0xFF0D47A1)
                                  : Colors.grey),
                          const SizedBox(width: 10),
                          Text(info?.nombre ?? modId,
                              style: TextStyle(
                                fontWeight: activo
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              )),
                        ],
                      ),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _modulosSeleccionados.add(modId);
                          } else {
                            _modulosSeleccionados.remove(modId);
                          }
                        });
                      },
                    );
                  }),
                ],

                const SizedBox(height: 24),

                // ── Botón guardar ────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(
                      _guardando ? 'Guardando...' : 'Guardar módulos',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}



import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/config/planes_config.dart';
import '../../../services/suscripcion_service.dart';
import '../../../core/widgets/fluix_app_bar.dart';

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

  /// Módulos activos de la empresa (cargados de Firestore)
  List<String> _modulosEmpresa = [];

  // Mapa completo de módulos con icono y nombre legible
  static const _modulosInfo = <String, ({IconData icono, String nombre})>{
    // ── Gestión interna ───────────────────────────────────────────────────────
    'dashboard':      (icono: Icons.dashboard_rounded,         nombre: 'Dashboard'),
    'empleados':      (icono: Icons.badge_rounded,             nombre: 'Empleados'),
    'tareas':         (icono: Icons.task_alt_rounded,          nombre: 'Tareas'),
    'estadisticas':   (icono: Icons.bar_chart_rounded,         nombre: 'Estadísticas'),
    // ── Atención al cliente ───────────────────────────────────────────────────
    'reservas':       (icono: Icons.calendar_today_rounded,    nombre: 'Reservas'),
    'citas':          (icono: Icons.event_rounded,             nombre: 'Citas'),
    'clientes':       (icono: Icons.people_rounded,            nombre: 'Clientes'),
    'valoraciones':   (icono: Icons.star_rounded,              nombre: 'Valoraciones'),
    'servicios':      (icono: Icons.spa_rounded,               nombre: 'Servicios'),
    // ── Ventas y operaciones ──────────────────────────────────────────────────
    'pedidos':        (icono: Icons.shopping_cart_rounded,     nombre: 'Pedidos'),
    'operaciones':    (icono: Icons.local_shipping_rounded,    nombre: 'Operaciones'),
    'almacen':        (icono: Icons.inventory_2_rounded,       nombre: 'Almacén'),
    'tpv':            (icono: Icons.point_of_sale_rounded,     nombre: 'TPV / Cobros'),
    'whatsapp':       (icono: Icons.chat_rounded,              nombre: 'WhatsApp Bot'),
    // ── Finanzas ──────────────────────────────────────────────────────────────
    'facturacion':    (icono: Icons.receipt_long_rounded,      nombre: 'Facturación'),
    'contabilidad':   (icono: Icons.calculate_rounded,         nombre: 'Contabilidad'),
    'nominas':        (icono: Icons.payments_rounded,          nombre: 'Nóminas'),
    'fiscal':         (icono: Icons.account_balance_rounded,   nombre: 'Fiscal AI'),
    // ── RRHH ─────────────────────────────────────────────────────────────────
    'fichaje':        (icono: Icons.access_time_rounded,       nombre: 'Fichaje'),
    'vacaciones':     (icono: Icons.beach_access_rounded,      nombre: 'Vacaciones'),
    // ── Presencia digital ─────────────────────────────────────────────────────
    'web':            (icono: Icons.web_rounded,               nombre: 'Contenido Web'),
    'app':            (icono: Icons.phone_android_rounded,     nombre: 'Mi App'),
    // ── Otros ────────────────────────────────────────────────────────────────
    'agenda':         (icono: Icons.calendar_month_rounded,    nombre: 'Agenda'),
    'informes':       (icono: Icons.summarize_rounded,         nombre: 'Informes'),
    'documentos':     (icono: Icons.folder_rounded,            nombre: 'Documentos'),
  };

  /// Módulos que se activan automáticamente junto con facturación
  static const _modulosAutoConFacturacion = [
    'contabilidad', 'plantillas_pdf', 'verifactu',
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      // Lee suscripcion/actual para esta empresa — mismo doc que usa gestionar_cuentas_screen.
      // Si tiene modulos_override (configurado por el propietario), lo usa directamente.
      // Si no, calcula desde packs_activos + addons_activos.
      final suscripcionDoc = await _db
          .collection('empresas').doc(widget.empresaId)
          .collection('suscripcion').doc('actual')
          .get();

      List<String> activos;
      if (suscripcionDoc.exists) {
        final datos = DatosSuscripcion.fromMap(suscripcionDoc.data()!);
        activos = datos.modulosActivos
            .where((id) => !const {'propietario', 'explorar', 'citas_del_dia'}.contains(id))
            .toList();
      } else {
        activos = List.from(PlanesConfig.planBase.modulosIncluidos);
      }

      // Cargar configuración del empleado
      final doc = await _db.collection('usuarios').doc(widget.empleadoUid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _rol = data['rol'] as String? ?? 'staff';
        final modulosGuardados = (data['modulos_permitidos'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((id) => activos.contains(id))
            .toList();

        // Si hay módulos guardados, usarlos; si no, usar defaults del rol
        _modulosSeleccionados = (modulosGuardados != null && modulosGuardados.isNotEmpty)
            ? modulosGuardados
            : _modulosPorDefectoRol(_rol).where((id) => activos.contains(id)).toList();
      }

      setState(() => _modulosEmpresa = activos);
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
        return List.from(_modulosEmpresa);
      case 'admin':
        return [
          'dashboard', 'reservas', 'citas', 'clientes', 'valoraciones',
          'estadisticas', 'servicios', 'pedidos', 'whatsapp', 'tareas', 'nominas',
        ];
      case 'staff':
        return ['reservas', 'citas', 'clientes', 'valoraciones', 'fichaje', 'vacaciones'];
      default:
        return ['reservas', 'citas'];
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      // Auto-incluir módulos ligados a facturación si está activa
      final modulos = List<String>.from(_modulosSeleccionados);
      if (modulos.contains('facturacion')) {
        for (final auto in _modulosAutoConFacturacion) {
          if (!modulos.contains(auto)) modulos.add(auto);
        }
      }
      await _db.collection('usuarios').doc(widget.empleadoUid).update({
        'modulos_permitidos': modulos,
      });
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
      appBar: const FluixAppBar(titulo: 'Módulos del empleado', showLeading: true),
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

                // ── Botones rápidos ─────────────────────
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _modulosSeleccionados = List.from(_modulosEmpresa);
                      }),
                      icon: const Icon(Icons.select_all, size: 16),
                      label: const Text('Todos', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _modulosSeleccionados = [];
                      }),
                      icon: const Icon(Icons.deselect, size: 16),
                      label: const Text('Ninguno', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _modulosSeleccionados = _modulosPorDefectoRol(_rol)
                            .where((id) => _modulosEmpresa.contains(id))
                            .toList();
                      }),
                      icon: const Icon(Icons.restart_alt, size: 16),
                      label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // ── Lista completa de módulos activos de la empresa ──
                ..._modulosEmpresa.map((modId) {
                  final info = _modulosInfo[modId];
                  final activo = _modulosSeleccionados.contains(modId);
                  return CheckboxListTile(
                    value: activo,
                    activeColor: const Color(0xFF0D47A1),
                    title: Row(
                      children: [
                        Icon(info?.icono ?? Icons.extension,
                            size: 20,
                            color: activo ? const Color(0xFF0D47A1) : Colors.grey),
                        const SizedBox(width: 10),
                        Text(info?.nombre ?? modId,
                            style: TextStyle(
                              fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
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



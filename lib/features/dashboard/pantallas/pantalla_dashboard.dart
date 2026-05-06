import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/modulo_valoraciones_fixed.dart';
import '../widgets/modulo_estadisticas.dart';
import '../widgets/modulo_propietario.dart';
import '../widgets/widget_factory.dart';
import '../widgets/badge_icon.dart';
import '../widgets/offline_banner.dart';
import '../../../core/constantes/constantes_app.dart';
import '../../../services/widget_manager_service.dart';
import '../../../services/notificaciones_service.dart';
import '../../../services/debug_fcm_widget.dart';
import '../../../services/bandeja_notificaciones_service.dart';
import '../../../services/demo_cuenta_service.dart';
import '../../../services/suscripcion_service.dart';
import '../../../domain/modelos/widget_config.dart';
import 'configuracion_dashboard_screen.dart';
import 'bandeja_notificaciones_screen.dart';
import '../../tareas/pantallas/modulo_tareas_screen.dart';
import '../../tareas/pantallas/detalle_tarea_screen.dart';
import '../../../domain/modelos/tarea.dart';
import '../../pedidos/pantallas/modulo_pedidos_nuevo_screen.dart';
import '../../pedidos/pantallas/modulo_whatsapp_screen.dart';
import '../../empleados/pantallas/modulo_empleados_screen.dart';
import '../../facturacion/pantallas/modulo_facturacion_screen.dart';
import '../../reservas/pantallas/modulo_reservas_screen.dart';
import '../../reservas/pantallas/detalle_reserva_screen.dart';
import '../../clientes/pantallas/modulo_clientes_screen.dart';
import '../../servicios/pantallas/modulo_servicios_screen.dart';
import '../../nominas/pantallas/modulo_nominas_screen.dart';
import '../../vacaciones/pantallas/vacaciones_screen.dart';
import '../../tpv/pantallas/modulo_tpv_screen.dart';
import '../../fichaje/pantalla_fichaje/pantalla_fichaje.dart';
import '../../../core/utils/permisos_service.dart';
import '../../suscripcion/widgets/banner_suscripcion.dart';
import '../../perfil/pantallas/pantalla_perfil.dart';
import 'pantalla_contenido_web.dart';
import '../../../services/auth/token_refresh_service.dart';

class PantallaDashboard extends StatefulWidget {
  const PantallaDashboard({super.key});

  @override
  State<PantallaDashboard> createState() => _PantallaDashboardState();
}

class _PantallaDashboardState extends State<PantallaDashboard>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final WidgetManagerService _widgetService = WidgetManagerService();
  final DemoCuentaService _demoService = DemoCuentaService();
  final SuscripcionService _suscripcionService = SuscripcionService();
  String? _empresaId;
  String _nombreUsuario = '';
  bool _cargando = true;
  bool _generandoDemo = false;
  List<String> _modulosActivos = [];
  SesionUsuario? _sesion;
  StreamSubscription? _notifSubscription;
  int _mensajesSinLeer = 0; // Contador de mensajes sin leer en módulo web

  // ── Modo edición dashboard (reordenar widgets) ────────────────────────────
  bool _editandoDashboard = false;

  // ── Vista simulada (solo Propietario) ─────────────────────────────────────
  /// Rol que el Propietario está simulando. null = vista real de Propietario.
  RolApp? _rolVistaActual;

  /// Sesión efectiva: la real del propietario, o una sesión simulada con el
  /// rol elegido para ver exactamente lo que vería ese rol.
  SesionUsuario? get _sesionEfectiva {
    if (_sesion == null || _rolVistaActual == null) return _sesion;
    return SesionUsuario(
      uid: _sesion!.uid,
      nombre: _sesion!.nombre,
      correo: _sesion!.correo,
      empresaId: _sesion!.empresaId,
      rol: _rolVistaActual!,
      activo: _sesion!.activo,
    );
  }

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();

    // ── Inicializar el servicio completo de notificaciones ───────────────
    // Se llama aquí (post-login) para que el permiso de notificaciones
    // se pida cuando el usuario ya está dentro de la app y entiende por qué.
    NotificacionesService().inicializar();
    
    // Escuchar notificaciones
    _notifSubscription = NotificacionesService().onTap.listen((data) {
      if (!mounted) return;
      _manejarNavegacionNotificacion(data);
    });
    
    // Check initial message (app opened from terminated state)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
            _manejarNavegacionNotificacion(message.data);
        }
    });
  }

  /// Escuchar cambios en mensajes de contacto web sin leer
  void _escucharMensajesSinLeer() {
    if (_empresaId == null) return;
    
    FirebaseFirestore.instance
        .collection('empresas')
        .doc(_empresaId)
        .collection('contacto_web')
        .where('leido', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _mensajesSinLeer = snapshot.docs.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _notifSubscription?.cancel(); // Cancel subscription
    super.dispose();
  }

  Future<void> _manejarNavegacionNotificacion(Map<String, dynamic> data) async {
      final tipo = data['tipo'];
      final empresaId = data['empresa_id'];

      if (empresaId == null || _empresaId == null) return;

      // ── Guardia: ignorar notificaciones de otras empresas ──────────────
      // Evita que al tener múltiples cuentas las notificaciones de empresa A
      // naveguen en la sesión activa de empresa B.
      if (empresaId != _empresaId) {
        debugPrint('⚠️ Notificación de empresa $empresaId ignorada — sesión activa: $_empresaId');
        return;
      }

      if (tipo == 'tarea_asignada') {
          final tareaId = data['tarea_id'];
          if (tareaId == null) return;
          try {
              final doc = await FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(empresaId)
                  .collection('tareas')
                  .doc(tareaId)
                  .get();
              if (doc.exists && mounted) {
                  final tarea = Tarea.fromFirestore(doc);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => DetalleTareaScreen(
                          tarea: tarea,
                          empresaId: empresaId,
                          usuarioId: FirebaseAuth.instance.currentUser?.uid ?? '',
                      ),
                  ));
              }
          } catch (e) {
              debugPrint('❌ Error navegando a tarea: $e');
          }

      } else if (tipo == 'nueva_reserva' || tipo == 'reserva_confirmada' || tipo == 'reserva_cancelada') {
          // Intentar múltiples nombres de campo para el ID de reserva
          final reservaId = data['reserva_id'] ?? data['id'] ?? data['reservaId'] ?? data['docId'];
          
          debugPrint('🔔 Notificación de reserva recibida');
          debugPrint('   tipo: $tipo');
          debugPrint('   reserva_id: $reservaId');
          debugPrint('   data completo: $data');
          
          if (reservaId != null && mounted) {
              try {
                  debugPrint('🔍 Buscando reserva en Firestore: $reservaId');
                  final doc = await FirebaseFirestore.instance
                      .collection('empresas')
                      .doc(empresaId)
                      .collection('reservas')
                      .doc(reservaId)
                      .get();
                  
                  if (doc.exists && mounted) {
                      debugPrint('✅ Reserva encontrada, navegando a detalle');
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => DetalleReservaScreen(
                              doc: doc,
                              empresaId: empresaId,
                          ),
                      ));
                      return;
                  } else {
                      debugPrint('❌ Reserva no existe o widget no montado');
                  }
              } catch (e) {
                  debugPrint('❌ Error navegando a reserva: $e');
              }
          } else {
              debugPrint('⚠️ No hay reserva_id en el payload o widget no montado');
          }
          
          // Fallback: navegar al módulo de reservas
          debugPrint('🔙 Fallback: abriendo módulo de reservas');
          if (!mounted) return;
          final idx = _modulosActivos.indexOf('reservas');
          if (idx >= 0 && _tabController != null) {
              _tabController!.animateTo(idx);
          } else {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ModuloReservasScreen(
                      empresaId: empresaId,
                      sesion: _sesion,
                  ),
              ));
          }


      } else if (tipo == 'nuevo_pedido' || tipo == 'pedido_actualizado') {
          if (!mounted) return;
          final idx = _modulosActivos.indexOf('pedidos');
          if (idx >= 0 && _tabController != null) {
              _tabController!.animateTo(idx);
          } else {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ModuloPedidosNuevoScreen(
                      empresaId: empresaId,
                  ),
              ));
          }
      }
  }

  /// Actualiza el TabController de forma segura FUERA del build
  void _sincronizarTabs(List<String> nuevosIds) {
    if (_modulosActivos.length == nuevosIds.length &&
        _modulosActivos.join(',') == nuevosIds.join(',')) return;

    final prevIndex = _tabController?.index ?? 0;
    final controller = _tabController;

    setState(() {
      _modulosActivos = List.from(nuevosIds);
      _tabController = TabController(
        length: nuevosIds.isEmpty ? 1 : nuevosIds.length,
        vsync: this,
        initialIndex: prevIndex.clamp(0, (nuevosIds.length - 1).clamp(0, 99)),
      );
    });

    // Dispose del viejo DESPUÉS de setState para que Flutter no use un ref roto
    Future.microtask(() => controller?.dispose());
  }

  Future<void> _cargarDatosUsuario() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      debugPrint(' Cargando datos para UID: $uid');

      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        debugPrint('✅ Documento usuario encontrado: $data');
        final empresaId = data['empresa_id'] as String?;

        // Asegurar que el dueño de fluixtech siempre sea propietario
        if (empresaId == ConstantesApp.empresaPropietariaId &&
            data['rol'] != 'propietario' &&
            !uid.startsWith('emp_fluix_')) {
          await FirebaseFirestore.instance
              .collection('usuarios').doc(uid)
              .update({'rol': 'propietario'});
           debugPrint(' Rol forzado a propietario en _cargarDatosUsuario');
        }

        // Si no hay admin/propietario en la empresa, promover al usuario actual.
        // IMPORTANTE: 'propietario' es EXCLUSIVO de la empresa FluixTech.
        // Para cualquier otra empresa el rol de fallback es 'admin'.
        // Las cuentas demo NUNCA se promueven.
        final esDemoAccount = (data['correo'] as String? ?? '')
            .toLowerCase()
            .contains('demo');
        if (data['rol'] != 'propietario' && data['rol'] != 'admin' &&
            empresaId != null && !esDemoAccount) {
          try {
            final adminSnap = await FirebaseFirestore.instance
                .collection('usuarios')
                .where('empresa_id', isEqualTo: empresaId)
                .where('rol', whereIn: ['propietario', 'admin'])
                .limit(1)
                .get();
            if (adminSnap.docs.isEmpty) {
              // Solo FluixTech puede tener rol 'propietario'
              final rolFallback = empresaId == ConstantesApp.empresaPropietariaId
                  ? 'propietario'
                  : 'admin';
              await FirebaseFirestore.instance
                  .collection('usuarios').doc(uid)
                  .update({'rol': rolFallback});
              debugPrint(' Promovido a $rolFallback (empresa sin dueño) uid=$uid');
            }
          } catch (e) {
            debugPrint('ℹ️ Check admin/propietario omitido (permisos): $e');
          }
        }

        // Cargar sesión con permisos
        final sesion = await PermisosService().cargarSesion();
        debugPrint(' ROL ACTUAL: ${sesion?.rol} | empresaId: $empresaId | esPropietario: ${sesion?.esPropietario}');
        setState(() {
          _empresaId = empresaId;
          _sesion = sesion;
          _nombreUsuario = data['nombre'] ??
              FirebaseAuth.instance.currentUser?.displayName ??
              '';
          _cargando = false;
        });
        // Suscribir a notificaciones de la empresa
        if (empresaId != null) {
          NotificacionesService().suscribirseATopic(empresaId);
          NotificacionesService().guardarTokenConEmpresa(empresaId);
          // Cargar suscripción (packs/addons) para gating de widgets y módulos
          await _suscripcionService.cargarSuscripcion(empresaId);
          // Escuchar mensajes sin leer del módulo web
          _escucharMensajesSinLeer();
        }
        debugPrint('✅ EmpresaId cargado: $_empresaId');
      } else {
        debugPrint('❌ No existe documento de usuario, buscando empresas...');

        // Fallback: buscar empresa donde el correo del usuario coincida
        final email = FirebaseAuth.instance.currentUser?.email;
        if (email != null) {
          final empresasQuery = await FirebaseFirestore.instance
              .collection('empresas')
              .where('perfil.correo', isEqualTo: email)
              .limit(1)
              .get();

          if (empresasQuery.docs.isNotEmpty) {
            final empresaDoc = empresasQuery.docs.first;
            final fallbackEmpresaId = empresaDoc.id;
            debugPrint('✅ Empresa encontrada como fallback: $fallbackEmpresaId');

            // Crear documento de usuario que faltaba
            // NOTA: 'propietario' es exclusivo de FluixTech
            await FirebaseFirestore.instance
                .collection('usuarios')
                .doc(uid)
                .set({
              'nombre': FirebaseAuth.instance.currentUser?.displayName ??
                  'Administrador',
              'correo': email,
              'telefono': '+34 900 123 456',
              'empresa_id': fallbackEmpresaId,
              'rol': fallbackEmpresaId == ConstantesApp.empresaPropietariaId
                  ? 'propietario'
                  : 'admin',
              'activo': true,
              'fecha_creacion': DateTime.now().toIso8601String(),
              'permisos': [],
              'token_dispositivo': null,
            });

            setState(() {
              _empresaId = fallbackEmpresaId;
              _nombreUsuario = FirebaseAuth.instance.currentUser?.displayName ??
                  'Administrador';
              _cargando = false;
            });
            debugPrint('✅ Usuario y empresa creados automáticamente');
            return;
          }
        }

        setState(() {
          _nombreUsuario =
              FirebaseAuth.instance.currentUser?.displayName ??
                  FirebaseAuth.instance.currentUser?.email
                      ?.split('@')
                      .first ??
                  'Usuario';
          _cargando = false;
        });
        debugPrint('❌ No se encontró empresa asociada');
      }
    } catch (e) {
      debugPrint('❌ Error cargando datos usuario: $e');
      // Manejo de permission-denied: renovar token y reintentar UNA vez
      final esPermissionDenied = e.toString().contains('permission-denied') ||
          e.toString().contains('PERMISSION_DENIED');
      if (esPermissionDenied) {
        debugPrint('⚠️ permission-denied — renovando token y reintentando...');
        final renovado = await TokenRefreshService().manejarPermissionDenied();
        if (renovado && mounted) {
          // Reintento tras renovación del token
          return _cargarDatosUsuario();
        }
      }
      if (mounted) {
        setState(() {
          _nombreUsuario =
              FirebaseAuth.instance.currentUser?.displayName ?? 'Usuario';
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final scaffoldContent = GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Fluix CRM',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar sesión',
            onPressed: () async {
              setState(() => _cargando = true);
              // Forzar renovación del token Firebase Auth para evitar
              // errores de permiso en Firestore tras inactividad prolongada
              try {
                await FirebaseAuth.instance.currentUser?.getIdToken(true);
                debugPrint('🔑 Token renovado manualmente desde botón refresh');
                // Re-guardar token FCM por si se quedó desactualizado
                await NotificacionesService().guardarTokenTrasLogin();
              } catch (e) {
                debugPrint('⚠️ Error renovando token: $e');
              }
              _cargarDatosUsuario();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _manejarMenu,
            itemBuilder: (context) =>
            const [
              PopupMenuItem(
                value: 'perfil',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Mi Perfil'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'cerrar_sesion',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Cerrar Sesión',
                      style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _empresaId != null
          ? StreamBuilder<List<ModuloConfig>>(
              stream: _widgetService.obtenerModulosActivos(_empresaId!),
              builder: (context, snapshot) {
                final esPropietario = _sesion?.esPropietario == true ||
                    _empresaId == ConstantesApp.empresaPropietariaId;

                debugPrint(' Mostrando módulo propietario: $esPropietario | rol=${_sesion?.rol} | empresaId=$_empresaId');
                final modulosActivos = snapshot.data ??
                    ModulosDisponibles.todos
                        .where((m) => ModulosDisponibles.activosPorDefecto.contains(m.id))
                        .toList();

                // El módulo 'propietario' solo es visible para fluixtech
                // Las demás empresas nunca lo ven
                // Asegurar que el módulo propietario siempre esté presente para fluixtech
                final esDemo = _demoService.esDemo(
                    FirebaseAuth.instance.currentUser?.email);
                var modulosFiltrados = modulosActivos.where((m) {
                  if (m.id == 'propietario') return esPropietario;
                  // Ocultar nóminas — no disponible de momento
                  if (m.id == 'nominas') return false;
                  return true;
                }).toList();
                if (esPropietario && !modulosFiltrados.any((m) => m.id == 'propietario')) {
                  final propMod = ModulosDisponibles.todos.where((m) => m.id == 'propietario').firstOrNull;
                  if (propMod != null) {
                    modulosFiltrados.insert(0, propMod.copyWith(activo: true));
                  }
                }

                // Asegurar que el módulo 'dashboard' esté siempre presente en el catálogo
                // para que el usuario pueda acceder al resumen incluso si la config
                // en Firestore no lo tiene activado o los permisos lo ocultan.
                final dashMod = ModulosDisponibles.todos.where((m) => m.id == 'dashboard').firstOrNull;
                if (dashMod != null && !modulosFiltrados.any((m) => m.id == 'dashboard')) {
                  debugPrint('ℹ️ Insertando módulo "dashboard" por defecto en modulosFiltrados');
                  // Insertarlo al inicio, después del propietario si existe
                  final idxProp = modulosFiltrados.indexWhere((m) => m.id == 'propietario');
                  if (idxProp >= 0) {
                    modulosFiltrados.insert(idxProp + 1, dashMod.copyWith(activo: true));
                  } else {
                    modulosFiltrados.insert(0, dashMod.copyWith(activo: true));
                  }
                }

                // Filtrar por permisos del rol efectivo (real o simulado)
                final sesionActiva = _sesionEfectiva;
                final modulosVisibles = sesionActiva != null
                    ? modulosFiltrados.where((m) =>
                        m.id == 'propietario' || sesionActiva.modulosVisibles.contains(m.id)).toList()
                    : modulosFiltrados;

                // Forzar visibilidad del módulo 'dashboard' en la vista final
                if (!modulosVisibles.any((m) => m.id == 'dashboard') && dashMod != null) {
                  debugPrint('ℹ️ Forzando visibilidad del módulo "dashboard" en modulosVisibles');
                  modulosVisibles.insert(0, dashMod.copyWith(activo: true));
                }

                // Sincronizar tabs DESPUÉS del frame para evitar dispose durante build
                final ids = modulosVisibles.map((m) => m.id).toList();
                if (_modulosActivos.join(',') != ids.join(',')) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _sincronizarTabs(ids);
                  });
                }

                // Inicialización en el primer frame (sin controller todavía)
                if (_tabController == null) {
                  _tabController = TabController(
                    length: ids.isEmpty ? 1 : ids.length,
                    vsync: this,
                  );
                  _modulosActivos = List.from(ids);
                }

                // Guardia: si lengths no coinciden aún, mostrar loader
                if (_tabController!.length != modulosVisibles.length) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: [
                    _buildTarjetaBienvenida(),
                    // Banner de aviso si la suscripción vence pronto
                    if (_empresaId != null)
                      BannerSuscripcion(
                        empresaId: _empresaId!,
                        esPropietario: _sesion?.esPropietario ?? false,
                      ),
                    // Botones de cambio de vista: solo visibles para el Propietario (FluixTech)
                    if (_sesion?.esPropietario == true)
                      _buildBotonesVistaPropietario(),
                    Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController!,
                        labelColor: const Color(0xFF0D47A1),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF0D47A1),
                        indicatorWeight: 3,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        padding: EdgeInsets.zero,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        tabs: modulosVisibles.map((m) {
                          // Badge rojo para módulo web con mensajes sin leer
                          if (m.id == 'web' && _mensajesSinLeer > 0) {
                            return Tab(
                              child: Badge(
                                label: Text(_mensajesSinLeer.toString()),
                                backgroundColor: Colors.red,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(m.icono, size: 20),
                                    const SizedBox(height: 4),
                                    Text(m.nombre),
                                  ],
                                ),
                              ),
                            );
                          }
                          // Tabs normales para el resto de módulos
                          return Tab(icon: Icon(m.icono, size: 20), text: m.nombre);
                        }).toList(),
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController!,
                                children: modulosVisibles
                                            .map((m) => _safeBuildContenidoModulo(m.id))
                                            .toList(),
                      ),
                    ),
                  ],
                );
              },
            )
          : Column(
              children: [
                _buildTarjetaBienvenida(),
                Expanded(child: _buildSinEmpresa()),
              ],
            ),
      floatingActionButton: _buildDemoFab(),
    ),
    );

    // En modo debug, superponer widget de debug FCM
    return kDebugMode
        ? Stack(
            children: [
              scaffoldContent,
              const DebugFCMWidget(),
            ],
          )
        : scaffoldContent;
  }

  /// Devuelve el widget correspondiente a cada módulo por su ID
  Widget _buildContenidoModulo(String moduloId) {
    final id = _empresaId!;
    final sesionActiva = _sesionEfectiva;
    // Módulo exclusivo de la cuenta propietaria
    final esPropietario = _sesion?.esPropietario == true ||
        id == ConstantesApp.empresaPropietariaId;
    switch (moduloId) {
      case 'propietario':     return esPropietario ? const ModuloPropietario() : const Center(child: Text('Sin acceso'));
      case 'dashboard':       return _buildDashboardModular();
      case 'valoraciones':    return ModuloValoraciones(empresaId: id);
      case 'reservas':        return ModuloReservasScreen(empresaId: id, sesion: sesionActiva);
      case 'citas':           return ModuloReservasScreen(empresaId: id, sesion: sesionActiva);
      case 'estadisticas':    return ModuloEstadisticas(empresaId: id);
      case 'tareas':          return ModuloTareasScreen(empresaId: id);
      case 'pedidos':         return ModuloPedidosNuevoScreen(empresaId: id);
      case 'tpv':             return ModuloTpvScreen(empresaId: id, esAdmin: sesionActiva?.esAdmin ?? false);
      case 'whatsapp':        return ModuloWhatsAppScreen(empresaId: id);
      case 'facturacion':     return ModuloFacturacionScreen(empresaId: id);
      case 'empleados':       return ModuloEmpleadosScreen(empresaId: id, sesion: sesionActiva);
      case 'clientes':        return ModuloClientesScreen(empresaId: id, sesion: sesionActiva);
      case 'servicios':       return ModuloServiciosScreen(empresaId: id, sesion: sesionActiva);
      case 'nominas':         return const Center(child: Text('Módulo no disponible'));
      case 'fichaje':         return PantallaFichaje();
      case 'vacaciones':      return VacacionesScreen(empresaId: id, sesion: sesionActiva);
      case 'web':             return _buildVistaWeb();
      default:                return Center(child: Text('Módulo "$moduloId" no disponible', style: TextStyle(color: Colors.red)));
    }
  }

  /// Envoltorio seguro para evitar que un módulo mal formado provoque
  /// un crash de la UI. Captura excepciones y muestra un placeholder.
  Widget _safeBuildContenidoModulo(String? moduloId) {
    try {
      if (moduloId == null || moduloId.isEmpty) {
        debugPrint('⚠️ _safeBuildContenidoModulo recibió moduloId inválido: $moduloId');
        return const Center(child: Text('Módulo no disponible'));
      }
      return _buildContenidoModulo(moduloId);
    } catch (e, st) {
      debugPrint('❌ Error building módulo "$moduloId": $e\n$st');
      return Center(child: Text('Error cargando módulo "$moduloId"', style: const TextStyle(color: Colors.red)));
    }
  }

  /// Barra de selección de vista para el Propietario.
  /// Solo visible cuando el usuario real tiene rol Propietario.
  Widget _buildBotonesVistaPropietario() {
    // Si está simulando, mostramos un banner de aviso
    final simulando = _rolVistaActual != null;

    return Column(
      children: [
        if (simulando)
          Container(
            width: double.infinity,
            color: Colors.amber[700],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.preview, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Vista de ${_rolVistaActual == RolApp.admin ? 'Administrador' : 'Usuario/Staff'}  —  no ves lo que ven los propietarios',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Vista:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              _chipVista(
                label: ' Propietario',
                activo: _rolVistaActual == null,
                color: const Color(0xFF0D47A1),
                onTap: () => setState(() => _rolVistaActual = null),
              ),
              const SizedBox(width: 6),
              _chipVista(
                label: '️ Admin',
                activo: _rolVistaActual == RolApp.admin,
                color: const Color(0xFF7B1FA2),
                onTap: () => setState(() => _rolVistaActual = RolApp.admin),
              ),
              const SizedBox(width: 6),
              _chipVista(
                label: ' Usuario',
                activo: _rolVistaActual == RolApp.staff,
                color: const Color(0xFF388E3C),
                onTap: () => setState(() => _rolVistaActual = RolApp.staff),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chipVista({
    required String label,
    required bool activo,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? color : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo ? color : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: activo ? FontWeight.w700 : FontWeight.normal,
            color: activo ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildTarjetaBienvenida() {
    final primerNombre = _obtenerPrimerNombre(_nombreUsuario);

    final user = FirebaseAuth.instance.currentUser;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                _obtenerIniciales(_nombreUsuario),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenido, $primerNombre',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                  if (_sesion != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _rolVistaActual == null
                          ? '${_sesion!.rolEmoji} ${_sesion!.rolNombre}'
                          : '${_sesionEfectiva!.rolEmoji} ${_sesionEfectiva!.rolNombre} (simulado)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
              ],
            ),
          ),

          // Badge estado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF69F0AE).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: const Color(0xFF69F0AE).withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: Color(0xFF69F0AE)),
                SizedBox(width: 4),
                Text('Online',
                    style: TextStyle(
                        color: Color(0xFF69F0AE),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinEmpresa() {
    final user = FirebaseAuth.instance.currentUser;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.business, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No se encontró empresa asociada',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Usuario: ${user?.email}\nUID: ${user?.uid}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),
            Text(
              'Intentando crear empresa automáticamente...',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _cargando = true);
                _cargarDatosUsuario();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar Sesión'),
            ),
          ],
        ),
      ),
    );
  }

  /// Dashboard modular con widgets personalizables.
  /// Si el módulo "facturacion" o "pedidos" está activo,
  /// sus widgets de resumen se inyectan automáticamente en el dashboard.
  Widget _buildDashboardModular() {
    return StreamBuilder<List<ModuloConfig>>(
      stream: _widgetService.obtenerModulosActivos(_empresaId!),
      builder: (context, moduloSnap) {
        final modulos = moduloSnap.data ?? [];
        final facturacionActiva =
            modulos.any((m) => m.id == 'facturacion' && m.activo);
        final pedidosActivos =
            modulos.any((m) => m.id == 'pedidos' && m.activo);
        final fiscalActivo =
            modulos.any((m) => m.id == 'fiscal' && m.activo);

        return StreamBuilder<List<WidgetConfig>>(
          stream: _widgetService.obtenerWidgetsActivos(_empresaId!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildDashboardVacio();
            }

            // Widgets activados manualmente por el usuario
            var widgets = snapshot.data!;

            // Filtrar alertas_fiscales si el pack fiscal no está activo
            if (!fiscalActivo) {
              widgets = widgets.where((w) => w.id != 'alertas_fiscales').toList();
            }

            // Inyectar resumen_facturacion si módulo activo y widget no está ya
            if (facturacionActiva &&
                !widgets.any((w) => w.id == 'resumen_facturacion')) {
              widgets = [
                ...widgets,
                WidgetConfig(
                  id: 'resumen_facturacion',
                  nombre: 'Resumen Facturación',
                  descripcion: 'Total facturado hoy y del mes',
                  icono: Icons.receipt_long,
                  activo: true,
                  orden: 98,
                ),
              ];
            }

            // Inyectar resumen_pedidos si módulo activo y widget no está ya
            if (pedidosActivos &&
                !widgets.any((w) => w.id == 'resumen_pedidos')) {
              widgets = [
                ...widgets,
                WidgetConfig(
                  id: 'resumen_pedidos',
                  nombre: 'Resumen Pedidos',
                  descripcion: 'Pedidos del día y pendientes',
                  icono: Icons.shopping_bag_outlined,
                  activo: true,
                  orden: 99,
                ),
              ];
            }

            // Ocultar resumen_facturacion si el módulo no está activo
            if (!facturacionActiva) {
              widgets = widgets.where((w) => w.id != 'resumen_facturacion').toList();
            }

            // Ocultar resumen_pedidos si el módulo no está activo
            if (!pedidosActivos) {
              widgets = widgets.where((w) => w.id != 'resumen_pedidos').toList();
            }

            // Ordenar por orden
            widgets.sort((a, b) => a.orden.compareTo(b.orden));

            // Modo edición: header fijo + lista reordenable
            if (_editandoDashboard) {
              return Column(
                children: [
                  const OfflineBanner(),
                  _buildHeaderDashboard(),
                  Expanded(child: _buildReorderableList(widgets)),
                ],
              );
            }

            // Modo normal: todo en scroll (banner + header + widgets)
            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: OfflineBanner()),
                SliverToBoxAdapter(child: _buildHeaderDashboard()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildWidgetItem(widgets[index], index),
                      childCount: widgets.length,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReorderableList(List<WidgetConfig> widgets) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: widgets.length,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (ctx, ch) => Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            shadowColor: const Color(0xFF0D47A1).withValues(alpha: 0.3),
            child: ch,
          ),
          child: child,
        );
      },
      onReorderStart: (_) => HapticFeedback.mediumImpact(),
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = widgets.removeAt(oldIndex);
          widgets.insert(newIndex, item);
        });
        _widgetService.reordenarWidgets(_empresaId!, widgets);
      },
      itemBuilder: (context, index) {
        final config = widgets[index];
        return Container(
          key: ValueKey(config.id),
          child: Stack(
            children: [
              _buildWidgetItem(config, index),
              // Handle visual en modo edición
              Positioned(
                left: 4, top: 4,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.drag_handle,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWidgetItem(WidgetConfig widgetConfig, int index) {
    // Widgets con altura dinámica (sin restricción de height)
    if (widgetConfig.id == 'briefing_matutino' ||
        widgetConfig.id == 'alertas_fiscales' ||
        widgetConfig.id == 'proximos_dias') {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: _safeBuildWidget(widgetConfig),
        );
    }
    if (widgetConfig.id == 'reservas_hoy' ||
        widgetConfig.id == 'valoraciones_recientes') {
        return Container(
          height: 280,
          margin: const EdgeInsets.only(bottom: 16),
          child: _safeBuildWidget(widgetConfig),
        );
    }
    if (widgetConfig.id == 'resumen_facturacion' ||
        widgetConfig.id == 'resumen_pedidos') {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _safeBuildWidget(widgetConfig),
        );
    }
    return Container(
      height: 160,
      margin: const EdgeInsets.only(bottom: 16),
      child: _safeBuildWidget(widgetConfig),
    );
  }

  Widget _safeBuildWidget(WidgetConfig widgetConfig) {
    // Widget eliminado: citas_del_dia (no aplica en esta versión)
    if (widgetConfig.id == 'citas_del_dia') return const SizedBox.shrink();

    // ── Pack gating — usa SuscripcionService como fuente autoritativa ──────
    final esPropietario = _sesionEfectiva?.esPropietarioPlatforma ?? false;
    if (!esPropietario) {
      if (widgetConfig.id == 'alertas_fiscales' &&
          !_suscripcionService.tieneModulo('fiscal')) {
        return _buildWidgetBloqueado(widgetConfig, 'Pack Fiscal AI');
      }
      if (widgetConfig.id == 'resumen_facturacion' &&
          !_suscripcionService.tieneModulo('facturacion')) {
        return _buildWidgetBloqueado(widgetConfig, 'Pack Gestión');
      }
      if (widgetConfig.id == 'resumen_pedidos' &&
          !_suscripcionService.tieneModulo('pedidos')) {
        return _buildWidgetBloqueado(widgetConfig, 'Pack Tienda Online');
      }
    }

    try {
      return WidgetFactory.buildWidget(widgetConfig, _empresaId!);
    } catch (e, st) {
      debugPrint('❌ Error construyendo widget "${widgetConfig.id}": $e\n$st');
      return Card(
        color: Colors.white,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(height: 8),
              Text('Error al cargar widget ${widgetConfig.id}', style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildWidgetBloqueado(WidgetConfig config, String nombrePack) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(config.icono, color: Colors.grey[400], size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(config.nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('Requiere $nombrePack',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline, color: Colors.orange, size: 12),
                SizedBox(width: 4),
                Text('Bloqueado', style: TextStyle(
                    color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  /// Header del dashboard con botón de configuración
  Widget _buildHeaderDashboard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.dashboard, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard Personalizado',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tu resumen de negocio personalizado',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Botón de configuración del dashboard
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ConfiguracionDashboardScreen(empresaId: _empresaId!),
                ),
              );
            },
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Configuración del Dashboard',
          ),

          // ── Campana de notificaciones con badge ─────────────────────
          if (_empresaId != null)
            StreamBuilder<int>(
              stream: BandejaNotificacionesService().noLeidasCount(_empresaId!),
              builder: (ctx, snap) {
                final count = snap.data ?? 0;
                return IconButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BandejaNotificacionesScreen(empresaId: _empresaId!),
                  )),
                  icon: BadgeIcon(
                    icon: Icons.notifications_outlined,
                    count: count,
                    iconColor: Colors.white,
                    iconSize: 22,
                  ),
                  tooltip: 'Notificaciones',
                );
              },
            ),

          // ── Botón editar/reordenar dashboard ────────────────────────
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _editandoDashboard = !_editandoDashboard);
            },
            icon: Icon(
              _editandoDashboard ? Icons.check : Icons.swap_vert,
              color: _editandoDashboard ? Colors.greenAccent : Colors.white,
            ),
            tooltip: _editandoDashboard ? 'Guardar orden' : 'Reordenar widgets',
          ),
        ],
      ),
    );
  }

  /// Dashboard vacío (sin widgets configurados)
  Widget _buildDashboardVacio() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.widgets, size: 64, color: Colors.grey[400]),
          ),
          const SizedBox(height: 24),
          Text(
            'Dashboard Vacío',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No tienes widgets activos en tu dashboard',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ConfiguracionDashboardScreen(empresaId: _empresaId!),
                  ),
                );
              },
              icon: const Icon(Icons.settings),
              label: const Text('Configurar Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _widgetService.resetearWidgets(_empresaId!),
            child: const Text('Usar configuración por defecto'),
          ),
        ],
      ),
    );
  }

  // ── DEMO FAB ─────────────────────────────────────────────────────────────
  Widget? _buildDemoFab() {
    final email = FirebaseAuth.instance.currentUser?.email;
    // Visible para la cuenta demo tanto en debug como en release
    if (!_demoService.esDemo(email) || _empresaId == null) return null;

    return FloatingActionButton.extended(
      onPressed: _generandoDemo ? null : _generarDatosDemo,
      backgroundColor: const Color(0xFF7C4DFF),
      icon: _generandoDemo
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            )
          : const Icon(Icons.auto_fix_high, color: Colors.white),
      label: const Text(
        'Generar datos demo',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _generarDatosDemo() async {
    if (_empresaId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.auto_fix_high, color: Color(0xFF7C4DFF)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Generar datos de prueba', overflow: TextOverflow.ellipsis)),
        ]),
        content: const Text(
          'Se crearán datos de ejemplo completos y realistas:\n\n'
          '✅ BORRA datos demo anteriores automáticamente\n\n'
          '• 3 empleados con IBANs válidos\n'
          '• 15 nóminas conectadas (5 meses)\n'
          '• Convenios de hostelería (grupos 5, 7, 8)\n'
          '• 3 clientes con historial\n'
          '• 3 servicios de restaurante\n'
          '• 5 reservas futuras\n\n'
          '¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C4DFF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Generar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _generandoDemo = true);
    try {
      await _demoService.generarDatosCompletosDemo(_empresaId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Datos demo completos generados correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ Error generando datos: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _generandoDemo = false);
    }
  }

  void _manejarMenu(String accion) {
    switch (accion) {
      case 'perfil':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaPerfil(sesion: _sesion),
          ),
        );
        break;
      case 'cerrar_sesion':
        showDialog(
          context: context,
          builder: (ctx) =>
              AlertDialog(
                title: const Text('Cerrar Sesión'),
                content: const Text('¿Estás seguro?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar')),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      // Limpiar token FCM de la empresa activa para no recibir
                      // notificaciones de esta empresa en futuras sesiones de otra cuenta
                      if (_empresaId != null) {
                        await NotificacionesService().eliminarTokenDeEmpresa(_empresaId!);
                      }
                      PermisosService().limpiarSesion();
                      await FirebaseAuth.instance.signOut();
                    },
                    style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Cerrar Sesión',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
        );
        break;
    }
  }

  String _obtenerIniciales(String nombre) {
    if (nombre.contains('@')) nombre = nombre
        .split('@')
        .first;
    final partes =
    nombre.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (partes.length >= 2) {
      return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    }
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U';
  }

  String _obtenerPrimerNombre(String nombre) {
    if (nombre.contains('@')) {
      return nombre
          .split('@')
          .first
          .split('.')
          .first;
    }
    return nombre
        .trim()
        .split(' ')
        .first;
  }


  // ignore: unused_element
  Widget _buildVistaWebDesactivada() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.web_outlined, size: 64, color: Color(0xFF1976D2)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Gestión Web Desactivada',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Activa la gestión de contenido web para administrar\nlas secciones de tu página desde la app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Funcionalidades disponibles:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  _buildFuncionalidadItem(Icons.edit, 'Editar secciones dinámicas'),
                  _buildFuncionalidadItem(Icons.local_offer, 'Gestionar ofertas y carta'),
                  _buildFuncionalidadItem(Icons.language, 'Ver estado de la web'),
                  _buildFuncionalidadItem(Icons.code, 'Generar código JavaScript'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _toggleContenidoWeb,
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Activar Gestión Web'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFuncionalidadItem(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icono, size: 16, color: const Color(0xFF1976D2)),
          const SizedBox(width: 8),
          Text(texto, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        ],
      ),
    );
  }

  /// Vista completa para gestión de contenido web — usa la pantalla real
  Widget _buildVistaWeb() {
    return PantallaContenidoWeb(empresaId: _empresaId!);
  }

  /// Activa/desactiva el módulo web desde el dashboard
  void _toggleContenidoWeb() async {
    if (_empresaId == null) return;
    try {
      final modulos = await _widgetService.obtenerTodosModulos(_empresaId!).first;
      final webActivo = modulos.any((m) => m.id == 'web' && m.activo);
      await _widgetService.toggleModulo(_empresaId!, 'web', !webActivo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(!webActivo
              ? ' Contenido web activado'
              : ' Contenido web desactivado'),
          backgroundColor:
              !webActivo ? const Color(0xFF4CAF50) : const Color(0xFFFF9800),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}









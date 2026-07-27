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
import '../../../core/utils/platform_helper.dart';
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
import '../../tpv/pantallas/tpv_root_screen.dart';
import '../../tpv/pantallas/tpv_peluqueria_screen.dart';
import '../../tpv/pantallas/tpv_tienda_screen.dart';
import '../../tpv/pantallas/tpv_selector_negocio_screen.dart';
import '../../fichajes/pantallas/gestion_fichajes_screen.dart';
import '../../../core/navigation/app_navigator.dart';
import '../../../core/utils/permisos_service.dart';
import '../../suscripcion/widgets/banner_suscripcion.dart';
import '../../perfil/pantallas/pantalla_perfil.dart';
import 'pantalla_contenido_web.dart';
import '../../negocio_publico/pantallas/modulo_app_screen.dart';
import '../../../services/stock_service.dart';
import '../../../services/auth/token_refresh_service.dart';
import '../../explorar_negocios/pantallas/pantalla_explorar.dart';
import '../../pdf_templates/presentation/screens/pdf_templates_list_screen.dart';
import '../../../core/enums/enums.dart';
import 'package:flutter/foundation.dart';

class PantallaDashboard extends StatefulWidget {
  final VistaActiva vistaInicial;
  const PantallaDashboard({super.key, this.vistaInicial = VistaActiva.empresa});

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
  int _indiceSeleccionado = 0; // Para NavigationRail en desktop
  int _paginaHome = 0; // 0=inicio, 1=módulos (mobile bottom nav)
  String? _moduloDesktopActivo; // null=home, 'personal'=sección personal, o id de módulo

  // ── Modo edición dashboard (reordenar widgets) ────────────────────────────
  bool _editandoDashboard = false;

  // ── Tema oscuro/claro del launcher ───────────────────────────────────────
  bool _darkMode = false;

  // ── Vista dual empresa/usuario ────────────────────────────────────────────
  late VistaActiva _vistaActual;

  // ── Vista simulada (solo Propietario) ─────────────────────────────────────
  RolApp? _rolVistaActual;

  // ── Tiles del launcher (3×3 + tecla "0") ─────────────────────────────────
  static const _kAllTiles = [
    _AppTile('dashboard',   Icons.grid_view_rounded,           'Dashboard',    Color(0xFF3B82F6)),
    _AppTile('facturacion', Icons.receipt_long_rounded,        'Facturación',  Color(0xFF10B981)),
    _AppTile('clientes',    Icons.people_alt_rounded,          'Clientes',     Color(0xFF3B82F6)),
    _AppTile('web',         Icons.language_rounded,            'Web',          Color(0xFF22D3EE)),
    _AppTile('tpv',         Icons.point_of_sale_rounded,       'TPV',          Color(0xFFF59E0B)),
    _AppTile('empleados',   Icons.badge_rounded,               'Personal',     Color(0xFF8B5CF6)),
    _AppTile('pedidos',     Icons.inventory_2_rounded,         'Pedidos',      Color(0xFFEC4899)),
    _AppTile('tareas',      Icons.task_alt_rounded,            'Tareas',       Color(0xFF14B8A6)),
    _AppTile('perfil',      Icons.account_circle_rounded,      'Mi Perfil',    Color(0xFF6366F1)),
    _AppTile('carpeta',     Icons.folder_special_rounded,      'Más',          Color(0xFF6366F1)),
  ];

  // Descripciones para list/card view responsive
  static const _kDesc = <String, String>{
    'dashboard':     'Resumen y estadísticas de tu negocio',
    'facturacion':   'Crea y gestiona facturas, presupuestos y rectificativas',
    'clientes':      'Gestiona tus clientes y su información',
    'web':           'Gestiona el contenido de tu sitio web',
    'tpv':           'Gestiona ventas, productos y caja',
    'empleados':     'Empleados, nóminas y gestión laboral',
    'pedidos':       'Controla tus pedidos y su estado',
    'tareas':        'Organiza tareas y mejora la productividad',
    'perfil':        'Tu perfil y configuración personal',
    'carpeta':       'Descubre más herramientas para tu negocio',
    'reservas':      'Gestiona citas y reservas de clientes',
    'valoraciones':  'Opiniones y valoraciones de clientes',
    'fichaje':       'Control de jornadas y horas trabajadas',
    'vacaciones':    'Gestiona vacaciones y ausencias del personal',
    'servicios':     'Catálogo de servicios ofrecidos',
    'plantillas_pdf':'Personaliza el diseño de tus documentos PDF',
    'propietario':   'Configuración avanzada del sistema',
  };

  // Texto de acción / stat para list/card view (color accent)
  static const _kAction = <String, String>{
    'dashboard':     'Ver resumen',
    'facturacion':   'Acceder a Facturación',
    'clientes':      'Ver Clientes',
    'web':           'Ver sitio web',
    'tpv':           'Abrir TPV',
    'empleados':     'Ver Personal',
    'pedidos':       'Ver Pedidos activos',
    'tareas':        'Ver pendientes',
    'perfil':        'Ver Perfil',
    'carpeta':       'Explorar módulos',
    'reservas':      'Ver Reservas',
    'valoraciones':  'Ver Valoraciones',
    'fichaje':       'Gestionar fichajes',
    'vacaciones':    'Ver Vacaciones',
    'servicios':     'Ver Servicios',
    'plantillas_pdf':'Ver Plantillas',
    'propietario':   'Panel de Administración',
  };

  static const _kFolderTiles = [
    _AppTile('reservas',       Icons.calendar_month_rounded,      'Reservas',     Color(0xFF8B5CF6)),
    _AppTile('valoraciones',   Icons.star_rounded,                'Valoraciones', Color(0xFFEAB308)),
    _AppTile('fichaje',        Icons.schedule_rounded,            'Fichaje',      Color(0xFF14B8A6)),
    _AppTile('vacaciones',     Icons.beach_access_rounded,        'Vacaciones',   Color(0xFF0EA5E9)),
    _AppTile('servicios',      Icons.build_rounded,               'Servicios',    Color(0xFFF97316)),
    _AppTile('plantillas_pdf', Icons.picture_as_pdf_rounded,      'Plantillas',   Color(0xFFEF4444)),
    _AppTile('propietario',    Icons.admin_panel_settings_rounded, 'Admin',       Color(0xFFDC2626)),
  ];

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
    _vistaActual = widget.vistaInicial;
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
    if (defaultTargetPlatform != TargetPlatform.windows) {
    FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
            _manejarNavegacionNotificacion(message.data);
        }
    });
  }
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
    // _notifSubscription cancelado automáticamente por SafeStreamMixin
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
      final nuevoIndice = prevIndex.clamp(0, (nuevosIds.length - 1).clamp(0, 99));
      _indiceSeleccionado = nuevoIndice;
      _tabController = TabController(
        length: nuevosIds.isEmpty ? 1 : nuevosIds.length,
        vsync: this,
        initialIndex: nuevoIndice,
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
      return Scaffold(
        backgroundColor: _darkMode ? const Color(0xFF0A0F23) : const Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator(
          color: _darkMode ? const Color(0xFF3B82F6) : const Color(0xFF0D47A1),
        )),
      );
    }
    if (_rolVistaActual == RolApp.clienteFinal) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: _buildVistaClienteFinalCompleta(),
      );
    }
    final screen = _buildMobileLauncher();
    return kDebugMode ? Stack(children: [screen, const DebugFCMWidget()]) : screen;
  }

  // ── LAUNCHER METHODS (dead-code placeholder to keep compiler happy) ────────
  // ignore: unused_element
  Widget _buildOldScaffold(BuildContext context) {
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
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'perfil',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Mi Perfil'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'vista_usuario',
                child: ListTile(
                  leading: Icon(Icons.storefront_rounded, color: Color(0xFF00ACC1)),
                  title: Text('Explorar como usuario',
                      style: TextStyle(color: Color(0xFF00ACC1))),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
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
      body: _rolVistaActual == RolApp.clienteFinal
          ? _buildVistaClienteFinalCompleta()
          : _empresaId != null
          ? StreamBuilder<List<ModuloConfig>>(
              stream: _widgetService.obtenerModulosActivos(_empresaId!),
              builder: (context, snapshot) {
                final esPropietario = _sesion?.esPropietario == true ||
                    _empresaId == ConstantesApp.empresaPropietariaId;

                final modulosActivos = snapshot.data ??
                    ModulosDisponibles.todos
                        .where((m) => ModulosDisponibles.activosPorDefecto.contains(m.id))
                        .toList();

                // El módulo 'propietario' solo es visible para fluixtech
                // Las demás empresas nunca lo ven
                // Asegurar que el módulo propietario siempre esté presente para fluixtech
                var modulosFiltrados = modulosActivos.where((m) {
                  if (m.id == 'propietario') return esPropietario;
                  // Ocultar nóminas — no disponible de momento
                  if (m.id == 'nominas') return false;
                  // Ocultar explorar — es solo para clienteFinal, no para empresarios
                  if (m.id == 'explorar') return false;
                  return true;
                }).toList();

                // ── PROPIETARIO: mostrar SIEMPRE todos los módulos ────────────
                // El propietario de la plataforma debe ver todos los módulos en el tab bar,
                // independientemente de lo que esté guardado en Firestore.
                if (esPropietario && _rolVistaActual == null) {
                  modulosFiltrados = ModulosDisponibles.todos
                      .where((m) => m.id != 'nominas' && m.id != 'explorar') // nóminas y explorar ocultos
                      .map((m) => m.copyWith(activo: true))
                      .toList();
                }
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
                // El propietario en su vista real ve todos los módulos sin restricción.
                final sesionActiva = _sesionEfectiva;
                final List<ModuloConfig> modulosVisibles;
                if (esPropietario && _rolVistaActual == null) {
                  // Propietario real: usa modulosFiltrados directamente (ya son todos)
                  modulosVisibles = modulosFiltrados.toList();
                } else {
                  modulosVisibles = sesionActiva != null
                      ? modulosFiltrados.where((m) =>
                          sesionActiva.modulosVisibles.contains(m.id)).toList()
                      : modulosFiltrados.toList();
                }

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

                // Detectar si debemos usar NavigationRail (desktop) o TabBar (móvil)
                final useNavigationRail = PlatformHelper.shouldUseNavigationRail(context);

                if (useNavigationRail) {
                  // DESKTOP LAYOUT - NavigationRail
                  return Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: MediaQuery.of(context).size.height,
                            ),
                            child: IntrinsicHeight(
                              child: NavigationRail(
                                selectedIndex: _indiceSeleccionado.clamp(0, modulosVisibles.length - 1),
                                onDestinationSelected: (index) {
                                  setState(() {
                                    _indiceSeleccionado = index;
                                    _tabController?.animateTo(index);
                                  });
                                },
                                labelType: NavigationRailLabelType.all,
                                backgroundColor: Colors.white,
                                minWidth: 120,
                                selectedIconTheme: const IconThemeData(
                                  color: Color(0xFF0D47A1),
                                  size: 28,
                                ),
                                unselectedIconTheme: IconThemeData(
                                  color: Colors.grey[600],
                                  size: 24,
                                ),
                                selectedLabelTextStyle: const TextStyle(
                                  color: Color(0xFF0D47A1),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                unselectedLabelTextStyle: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                                destinations: modulosVisibles.map((m) {
                                  if (m.id == 'web' && _mensajesSinLeer > 0) {
                                    return NavigationRailDestination(
                                      icon: Badge(
                                        label: Text(_mensajesSinLeer.toString()),
                                        backgroundColor: Colors.red,
                                        child: Icon(m.icono),
                                      ),
                                      label: Text(m.nombre),
                                    );
                                  }
                                  return NavigationRailDestination(
                                    icon: Icon(m.icono),
                                    label: Text(m.nombre),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const VerticalDivider(thickness: 1, width: 1),
                      // Contenido principal
                      Expanded(
                        child: Column(
                          children: [
                            if (_esBienvenidaVisible(modulosVisibles)) _buildTarjetaBienvenida(),
                            if (_empresaId != null)
                              BannerSuscripcion(
                                empresaId: _empresaId!,
                                esPropietario: _sesion?.esPropietario ?? false,
                              ),
                            if (_sesion?.esPropietario == true)
                              _buildBotonesVistaPropietario(),
                            Expanded(
                              child: _safeBuildContenidoModulo(
                                  modulosVisibles[_indiceSeleccionado.clamp(0, modulosVisibles.length - 1)].id
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  // MOBILE LAYOUT - TabBar
                  return Column(
                    children: [
                      AnimatedBuilder(
                        animation: _tabController!,
                        builder: (context, _) {
                          final idx = _tabController!.index.clamp(0, modulosVisibles.length - 1);
                          final modId = modulosVisibles[idx].id;
                          if (modId != 'dashboard' && modId != 'propietario') return const SizedBox.shrink();
                          return _buildTarjetaBienvenida();
                        },
                      ),
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
                }
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

  // ═══════════════════════════════════════════════════════════════════════════
  // LAUNCHER iOS-style
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLauncher() {
    final dark = _darkMode;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1100;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        body: _buildDesktopLayout(dark),
      );
    }

    final isPortraitMobile = size.shortestSide < 600 && size.height > size.width;
    final bg = dark ? const Color(0xFF0A0F23) : const Color(0xFFF4F6FB);

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildTopBar(),
      body: SafeArea(
        child: Column(
          children: [
            if (_empresaId != null)
              BannerSuscripcion(
                empresaId: _empresaId!,
                esPropietario: _sesion?.esPropietario ?? false,
              ),
            Expanded(
              child: isPortraitMobile
                  ? IndexedStack(
                      index: _paginaHome,
                      children: [
                        _buildHomeScreen(dark),
                        _buildModuleList(_kAllTiles, dark),
                      ],
                    )
                  : _buildLauncherPanel(dark),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildDemoFab(),
      bottomNavigationBar: isPortraitMobile ? _buildBottomNav(dark) : null,
    );
  }

  PreferredSizeWidget _buildTopBar() {
    final dark = _darkMode;
    return AppBar(
      backgroundColor: dark ? const Color(0xFF0A0F23).withValues(alpha: 0.9) : Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text('Fluix', style: TextStyle(
        fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.3,
        color: dark ? Colors.white : const Color(0xFF0F172A),
      )),
      actions: [
        if (_sesion?.esPropietario == true)
          PopupMenuButton<String>(
            tooltip: 'Cambiar vista',
            icon: Stack(clipBehavior: Clip.none, children: [
              Icon(Icons.manage_accounts_rounded,
                  color: dark ? Colors.white70 : Colors.black87, size: 22),
              if (_rolVistaActual != null)
                Positioned(top: -2, right: -2, child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Color(0xFF00FFC8), shape: BoxShape.circle),
                )),
            ]),
            onSelected: (v) => setState(() {
              switch (v) {
                case 'propietario': _rolVistaActual = null; break;
                case 'admin':       _rolVistaActual = RolApp.admin; break;
                case 'staff':       _rolVistaActual = RolApp.staff; break;
                case 'clienteFinal':_rolVistaActual = RolApp.clienteFinal; break;
              }
            }),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'propietario', child: Row(children: [
                Icon(Icons.circle, size: 8, color: _rolVistaActual == null ? const Color(0xFF10B981) : Colors.transparent),
                const SizedBox(width: 8), const Text('👑 Propietario'),
              ])),
              PopupMenuItem(value: 'admin', child: Row(children: [
                Icon(Icons.circle, size: 8, color: _rolVistaActual == RolApp.admin ? const Color(0xFF10B981) : Colors.transparent),
                const SizedBox(width: 8), const Text('🛡️ Admin'),
              ])),
              PopupMenuItem(value: 'staff', child: Row(children: [
                Icon(Icons.circle, size: 8, color: _rolVistaActual == RolApp.staff ? const Color(0xFF10B981) : Colors.transparent),
                const SizedBox(width: 8), const Text('👤 Staff'),
              ])),
              PopupMenuItem(value: 'clienteFinal', child: Row(children: [
                Icon(Icons.circle, size: 8, color: _rolVistaActual == RolApp.clienteFinal ? const Color(0xFF10B981) : Colors.transparent),
                const SizedBox(width: 8), const Text('📱 Usuario'),
              ])),
            ],
          ),
        // Toggle dark/light
        GestureDetector(
          onTap: () => setState(() => _darkMode = !_darkMode),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 46, height: 26,
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: dark
                    ? const Color(0xFF00FFC8).withValues(alpha: 0.4)
                    : const Color(0xFFCBD5E1)),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                alignment: dark ? Alignment.centerLeft : Alignment.centerRight,
                child: Container(
                  width: 20, height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: dark
                        ? [const Color(0xFF00FFC8), const Color(0xFF0099A0)]
                        : [const Color(0xFFF59E0B), const Color(0xFFD97706)]),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    dark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded,
                    size: 12, color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_empresaId != null)
          StreamBuilder<int>(
            stream: BandejaNotificacionesService().noLeidasCount(_empresaId!),
            builder: (_, snap) => IconButton(
              icon: BadgeIcon(
                icon: Icons.notifications_outlined,
                count: snap.data ?? 0,
                iconColor: dark ? Colors.white70 : Colors.black87,
                iconSize: 22,
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => BandejaNotificacionesScreen(empresaId: _empresaId!),
              )),
            ),
          ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: dark ? Colors.white70 : Colors.black87),
          onSelected: _manejarMenu,
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'perfil', child: ListTile(leading: Icon(Icons.person), title: Text('Mi Perfil'), contentPadding: EdgeInsets.zero)),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'vista_usuario', child: ListTile(leading: Icon(Icons.storefront_rounded, color: Color(0xFF00ACC1)), title: Text('Explorar', style: TextStyle(color: Color(0xFF00ACC1))), contentPadding: EdgeInsets.zero)),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'cerrar_sesion', child: ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('Cerrar Sesión', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
          ],
        ),
      ],
    );
  }

  // ── Launcher panel — responsive ───────────────────────────────────────────
  Widget _buildLauncherPanel(bool dark) {
    final size = MediaQuery.of(context).size;
    final isPortraitMobile = size.shortestSide < 600 && size.height > size.width;
    return isPortraitMobile
        ? _buildModuleList(_kAllTiles, dark)
        : _buildModuleCards(_kAllTiles, dark, size.width);
  }

  // Lista vertical — móvil portrait
  Widget _buildModuleList(List<_AppTile> tiles, bool dark) {
    final bg   = dark ? const Color(0xFF0B0E18) : Colors.white;
    final text = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub  = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final div  = dark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100;
    return Container(
      color: bg,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: div, indent: 74, endIndent: 16),
        itemBuilder: (_, i) {
          final t = tiles[i];
          final action = _kAction[t.id] ?? '';
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => t.id == 'carpeta' ? _mostrarCarpeta(dark) : _abrirModulo(t.id),
              splashColor: t.accent.withValues(alpha: 0.06),
              highlightColor: t.accent.withValues(alpha: 0.04),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: t.accent.withValues(alpha: dark ? 0.14 : 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(t.icon, color: t.accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: text,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _kDesc[t.id] ?? '',
                            style: TextStyle(fontSize: 12, color: sub, height: 1.3),
                            maxLines: 2,
                          ),
                          if (action.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              action,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: t.accent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: t.accent.withValues(alpha: 0.7), size: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Grid de cards — landscape / tablet / desktop
  Widget _buildModuleCards(List<_AppTile> tiles, bool dark, double w) {
    final bg     = dark ? const Color(0xFF0B0E18) : const Color(0xFFF1F5F9);
    final cardBg = dark ? const Color(0xFF1E2139) : Colors.white;
    final border = dark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;
    final text   = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub    = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cols   = w > 1400 ? 5 : w > 1000 ? 4 : w > 700 ? 3 : 2;
    return Container(
      color: bg,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          childAspectRatio: 1.45,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: tiles.length,
        itemBuilder: (_, i) {
          final t = tiles[i];
          final action = _kAction[t.id] ?? '';
          return GestureDetector(
            onTap: () => t.id == 'carpeta' ? _mostrarCarpeta(dark) : _abrirModulo(t.id),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
                boxShadow: dark
                    ? []
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: dark ? 0.14 : 0.10),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(t.icon, color: t.accent, size: 20),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: t.accent.withValues(alpha: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t.label,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _kDesc[t.id] ?? '',
                    style: TextStyle(fontSize: 11, color: sub, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (action.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Text(
                            action,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: t.accent,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_forward_rounded, size: 11, color: t.accent),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOME SCREEN — saludo + KPI + accesos rápidos a módulos
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHomeScreen(bool dark) {
    final outerBg = dark ? const Color(0xFF0A0F23) : const Color(0xFFF4F6FB);
    return ColoredBox(
      color: outerBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreetingSection(dark),
            const SizedBox(height: 16),
            _buildKpiGrid(dark),
            const SizedBox(height: 20),
            _buildModuleShortcutSection(dark),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingSection(bool dark) {
    final text = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub  = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final hour = DateTime.now().hour;
    final saludo = hour < 12 ? 'Buenos días' : hour < 19 ? 'Buenas tardes' : 'Buenas noches';
    final emoji  = hour < 12 ? '👋' : hour < 19 ? '☀️' : '🌙';
    final primerNombre = _obtenerPrimerNombre(_nombreUsuario);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('¡$saludo, $primerNombre! $emoji',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: text)),
        const SizedBox(height: 4),
        Text('Aquí tienes un resumen de tu negocio.',
            style: TextStyle(fontSize: 13, color: sub)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: dark ? Colors.white12 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(20),
            color: dark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_today_outlined, size: 14,
                color: dark ? Colors.white54 : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(_formatearFechaHoy(),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: dark ? Colors.white70 : Colors.grey.shade700)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded, size: 16,
                color: dark ? Colors.white54 : Colors.grey.shade600),
          ]),
        ),
      ]),
    );
  }

  String _formatearFechaHoy() {
    final now = DateTime.now();
    const meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    return 'Hoy, ${now.day} ${meses[now.month - 1]} ${now.year}';
  }

  Widget _buildKpiGrid(bool dark) {
    if (_empresaId == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.55,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildKpiCardStream(dark: dark, titulo: 'Facturas pendientes',
              stream: _streamFacturasPendientes(),
              subtituloFn: (n) => n == 0 ? 'Al día' : 'por cobrar',
              icono: Icons.receipt_long_rounded, color: const Color(0xFF3B82F6)),
          _buildKpiCardStream(dark: dark, titulo: 'Clientes',
              stream: _streamTotalClientes(),
              subtituloFn: (_) => 'activos',
              icono: Icons.people_alt_rounded, color: const Color(0xFF10B981)),
          _buildKpiCardStream(dark: dark, titulo: 'Pedidos activos',
              stream: _streamPedidosActivos(),
              subtituloFn: (_) => 'en proceso',
              icono: Icons.inventory_2_rounded, color: const Color(0xFFF59E0B)),
          _buildKpiCardStream(dark: dark, titulo: 'Tareas pendientes',
              stream: _streamTareasPendientes(),
              subtituloFn: (n) => n == 1 ? 'pendiente' : 'pendientes',
              icono: Icons.task_alt_rounded, color: const Color(0xFF8B5CF6)),
        ],
      ),
    );
  }

  Widget _buildKpiRow(bool dark) {
    if (_empresaId == null) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: _buildKpiCardStream(dark: dark, titulo: 'Facturas pendientes',
            stream: _streamFacturasPendientes(), subtituloFn: (n) => n == 0 ? 'Al día' : 'por cobrar',
            icono: Icons.receipt_long_rounded, color: const Color(0xFF3B82F6))),
        const SizedBox(width: 12),
        Expanded(child: _buildKpiCardStream(dark: dark, titulo: 'Clientes',
            stream: _streamTotalClientes(), subtituloFn: (_) => 'activos',
            icono: Icons.people_alt_rounded, color: const Color(0xFF10B981))),
        const SizedBox(width: 12),
        Expanded(child: _buildKpiCardStream(dark: dark, titulo: 'Pedidos activos',
            stream: _streamPedidosActivos(), subtituloFn: (_) => 'en proceso',
            icono: Icons.inventory_2_rounded, color: const Color(0xFFF59E0B))),
        const SizedBox(width: 12),
        Expanded(child: _buildKpiCardStream(dark: dark, titulo: 'Tareas pendientes',
            stream: _streamTareasPendientes(), subtituloFn: (n) => n == 1 ? 'pendiente' : 'pendientes',
            icono: Icons.task_alt_rounded, color: const Color(0xFF8B5CF6))),
      ]),
    );
  }

  Widget _buildKpiCardStream({
    required bool dark,
    required String titulo,
    required Stream<int> stream,
    required String Function(int) subtituloFn,
    required IconData icono,
    required Color color,
  }) {
    final cardBg   = dark ? const Color(0xFF1E2139) : Colors.white;
    final numColor = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final subColor = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return StreamBuilder<int>(
      stream: stream,
      builder: (ctx, snap) {
        final n = snap.data ?? 0;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: dark ? [] : [BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(width: 34, height: 34,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: dark ? 0.14 : 0.10),
                        borderRadius: BorderRadius.circular(9)),
                    child: Icon(icono, color: color, size: 17)),
              ]),
              const SizedBox(height: 12),
              Text('$n', style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: numColor, height: 1)),
              const SizedBox(height: 3),
              Text(titulo, style: TextStyle(fontSize: 11, color: subColor, height: 1.3),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(subtituloFn(n),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  maxLines: 1),
            ],
          ),
        );
      },
    );
  }

  Stream<int> _streamFacturasPendientes() {
    if (_empresaId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('empresas').doc(_empresaId).collection('facturas')
        .where('estado', whereIn: ['pendiente', 'enviada', 'borrador'])
        .snapshots().map((s) => s.size);
  }

  Stream<int> _streamTotalClientes() {
    if (_empresaId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('empresas').doc(_empresaId).collection('clientes')
        .snapshots().map((s) => s.size);
  }

  Stream<int> _streamPedidosActivos() {
    if (_empresaId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('empresas').doc(_empresaId).collection('pedidos')
        .where('estado', whereIn: ['pendiente', 'en_proceso', 'confirmado'])
        .snapshots().map((s) => s.size);
  }

  Stream<int> _streamTareasPendientes() {
    if (_empresaId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('empresas').doc(_empresaId).collection('tareas')
        .where('completada', isEqualTo: false)
        .snapshots().map((s) => s.size);
  }

  Widget _buildModuleShortcutSection(bool dark) {
    final text = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final mainTiles = _kAllTiles.take(8).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Text('Módulos', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: text)),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _paginaHome = 1),
            child: const Text('Ver todos',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 86,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemCount: mainTiles.length,
          itemBuilder: (ctx, i) {
            final t = mainTiles[i];
            return GestureDetector(
              onTap: () => t.id == 'carpeta' ? _mostrarCarpeta(dark) : _abrirModulo(t.id),
              child: Column(children: [
                Container(width: 52, height: 52,
                    decoration: BoxDecoration(
                        color: t.accent.withValues(alpha: dark ? 0.14 : 0.10),
                        borderRadius: BorderRadius.circular(14)),
                    child: Icon(t.icon, color: t.accent, size: 24)),
                const SizedBox(height: 6),
                Text(t.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500,
                    color: dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOTTOM NAVIGATION BAR — móvil
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomNav(bool dark) {
    final bg        = dark ? const Color(0xFF1E2139) : Colors.white;
    final selected  = const Color(0xFF3B82F6);
    final unselected = dark ? const Color(0xFF6B7280) : Colors.grey.shade500;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: dark ? Colors.white12 : Colors.grey.shade200)),
        boxShadow: dark ? [] : [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _bottomNavItem(Icons.home_rounded, 'Inicio', 0, selected, unselected, dark),
            _bottomNavItem(Icons.grid_view_rounded, 'Módulos', 1, selected, unselected, dark),
            GestureDetector(
              onTap: _mostrarAccionesRapidasModal,
              child: Container(
                width: 50, height: 50,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x663B82F6), blurRadius: 12, offset: Offset(0, 4))],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
              ),
            ),
            _buildNotifNavItem(selected, unselected, dark),
            _bottomNavItem(Icons.person_outline_rounded, 'Mi perfil', 4, selected, unselected, dark),
          ]),
        ),
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, int index, Color selected, Color unselected, bool dark) {
    final isSelected = _paginaHome == index;
    return GestureDetector(
      onTap: () {
        if (index == 0 || index == 1) {
          setState(() => _paginaHome = index);
        } else if (index == 4) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaPerfil(sesion: _sesion)));
        }
      },
      child: SizedBox(width: 56, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 22, color: isSelected ? selected : unselected),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(fontSize: 9.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? selected : unselected), maxLines: 1),
      ])),
    );
  }

  Widget _buildNotifNavItem(Color selected, Color unselected, bool dark) {
    if (_empresaId == null) {
      return _bottomNavItem(Icons.notifications_outlined, 'Avisos', 3, selected, unselected, dark);
    }
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => BandejaNotificacionesScreen(empresaId: _empresaId!))),
      child: SizedBox(width: 56, child: Column(mainAxisSize: MainAxisSize.min, children: [
        StreamBuilder<int>(
          stream: BandejaNotificacionesService().noLeidasCount(_empresaId!),
          builder: (ctx, snap) => Badge(
            isLabelVisible: (snap.data ?? 0) > 0,
            label: Text('${snap.data ?? 0}', style: const TextStyle(fontSize: 9)),
            backgroundColor: Colors.red,
            child: Icon(Icons.notifications_outlined, size: 22, color: unselected),
          ),
        ),
        const SizedBox(height: 3),
        Text('Avisos', style: TextStyle(fontSize: 9.5, color: unselected), maxLines: 1),
      ])),
    );
  }

  void _mostrarAccionesRapidasModal() {
    final dark = _darkMode;
    final bg = dark ? const Color(0xFF1E2139) : Colors.white;
    final text = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: dark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Acciones rápidas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: text)),
          const SizedBox(height: 16),
          ...[
            _QuickActionData(Icons.receipt_long_rounded, const Color(0xFF3B82F6), 'Nueva factura', 'facturacion'),
            _QuickActionData(Icons.people_alt_rounded, const Color(0xFF10B981), 'Nuevo cliente', 'clientes'),
            _QuickActionData(Icons.inventory_2_rounded, const Color(0xFFF59E0B), 'Nuevo pedido', 'pedidos'),
            _QuickActionData(Icons.task_alt_rounded, const Color(0xFF8B5CF6), 'Nueva tarea', 'tareas'),
            _QuickActionData(Icons.badge_rounded, const Color(0xFF6366F1), 'Nuevo empleado', 'empleados'),
          ].map((qa) => ListTile(
            leading: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: qa.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(qa.icon, color: qa.color, size: 18)),
            title: Text(qa.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: text)),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: qa.color),
            contentPadding: EdgeInsets.zero,
            onTap: () {
              Navigator.pop(ctx);
              _abrirModulo(qa.moduloId);
            },
          )),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DESKTOP LAYOUT — sidebar + content + right panel
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout(bool dark) {
    final size = MediaQuery.of(context).size;
    // Panel derecho solo en inicio (sin módulo activo)
    final showRightPanel = size.width >= 1380 && _moduloDesktopActivo == null;
    return Row(children: [
      _buildDesktopSidebar(dark),
      Expanded(
        child: Column(children: [
          if (_empresaId != null)
            BannerSuscripcion(
                empresaId: _empresaId!, esPropietario: _sesion?.esPropietario ?? false),
          if (_sesion?.esPropietario == true && _rolVistaActual != null) _buildSimulacionBanner(),
          Expanded(child: Row(children: [
            Expanded(child: _buildDesktopContent(dark)),
            if (showRightPanel)
              SizedBox(width: 300, child: _buildDesktopRightPanel(dark)),
          ])),
        ]),
      ),
    ]);
  }

  Widget _buildDesktopSidebar(bool dark) {
    final bg     = dark ? const Color(0xFF111827) : Colors.white;
    final border = dark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200;
    final text   = dark ? const Color(0xFFE2E8F0) : const Color(0xFF374151);
    final sub    = dark ? const Color(0xFF6B7280) : Colors.grey.shade500;
    final navItems = [
      _SidebarItem(Icons.home_rounded, 'Inicio', null),
      _SidebarItem(Icons.dashboard_rounded, 'Dashboard', 'dashboard'),
      _SidebarItem(Icons.receipt_long_rounded, 'Facturación', 'facturacion'),
      _SidebarItem(Icons.people_alt_rounded, 'Clientes', 'clientes'),
      _SidebarItem(Icons.inventory_2_rounded, 'Pedidos', 'pedidos'),
      _SidebarItem(Icons.point_of_sale_rounded, 'TPV', 'tpv'),
      _SidebarItem(Icons.task_alt_rounded, 'Tareas', 'tareas'),
      _SidebarItem(Icons.badge_rounded, 'Personal', 'personal'),
      _SidebarItem(Icons.language_rounded, 'Web', 'web'),
      _SidebarItem(Icons.apps_rounded, 'Más módulos', 'carpeta'),
    ];
    final bottomItems = [
      _SidebarItem(Icons.support_agent_rounded, 'Soporte', null),
      _SidebarItem(Icons.settings_rounded, 'Configuración', null),
    ];
    return Container(
      width: 240,
      decoration: BoxDecoration(
          color: bg, border: Border(right: BorderSide(color: border))),
      child: Column(children: [
        // Logo
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(children: [
            Container(width: 32, height: 32,
                decoration: BoxDecoration(color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18)),
            const SizedBox(width: 10),
            Text('Fluix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                color: text, letterSpacing: -0.3)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: navItems.map((item) {
              final isSelected = (item.label == 'Inicio' && _moduloDesktopActivo == null) ||
                  (item.moduloId != null && _moduloDesktopActivo == item.moduloId);
              return _buildSidebarNavItem(item, isSelected, dark, text, sub);
            }).toList(),
          ),
        ),
        // ── Selector de rol (solo propietario) ─────────────────────────
        if (_sesion?.esPropietario == true)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Vista activa', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
                  color: sub, letterSpacing: 0.6)),
              const SizedBox(height: 8),
              Row(children: [
                _sidebarRolChip(null,               '👑', 'Prop.',  dark, border),
                const SizedBox(width: 4),
                _sidebarRolChip(RolApp.admin,       '🛡️', 'Admin',  dark, border),
                const SizedBox(width: 4),
                _sidebarRolChip(RolApp.staff,       '👤', 'Staff',  dark, border),
                const SizedBox(width: 4),
                _sidebarRolChip(RolApp.clienteFinal,'📱', 'User',   dark, border),
              ]),
              if (_rolVistaActual != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: dark ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Simulando ${_rolVistaActual == RolApp.admin ? 'Admin' : _rolVistaActual == RolApp.staff ? 'Staff' : 'Usuario'}',
                    style: const TextStyle(fontSize: 9.5, color: Colors.amber, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ]),
          ),
        // ── Soporte y Configuración ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
          child: Column(children: bottomItems.map((item) =>
              _buildSidebarNavItem(item, false, dark, text, sub)).toList()),
        ),
      ]),
    );
  }

  Widget _sidebarRolChip(RolApp? rol, String emoji, String label, bool dark, Color border) {
    final isActive = _rolVistaActual == rol;
    final accent   = const Color(0xFF3B82F6);
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _rolVistaActual = rol),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: isActive ? accent.withValues(alpha: dark ? 0.2 : 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: isActive ? accent : border,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 1),
            Text(label, style: TextStyle(
              fontSize: 8, fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
              color: isActive ? accent : (dark ? Colors.white54 : Colors.grey.shade500),
            )),
          ]),
        ),
      ),
    );
  }

  Widget _buildSidebarNavItem(_SidebarItem item, bool isSelected, bool dark, Color text, Color sub) {
    final selBg   = const Color(0xFF3B82F6).withValues(alpha: dark ? 0.15 : 0.08);
    final selText = const Color(0xFF3B82F6);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (item.moduloId == null) {
            // Inicio
            setState(() => _moduloDesktopActivo = null);
          } else if (item.moduloId == 'carpeta') {
            _mostrarCarpeta(dark);
          } else {
            _abrirModulo(item.moduloId!);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
              color: isSelected ? selBg : Colors.transparent,
              borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(item.icon, size: 18, color: isSelected ? selText : sub),
            const SizedBox(width: 10),
            Text(item.label, style: TextStyle(fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? selText : text)),
          ]),
        ),
      ),
    );
  }

  Widget _buildDesktopContent(bool dark) {
    final bg = dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    if (_moduloDesktopActivo != null) {
      return Column(children: [
        _buildDesktopModuloHeader(_moduloDesktopActivo!, dark),
        Divider(height: 1, color: dark ? Colors.white12 : Colors.grey.shade200),
        Expanded(
          child: _moduloDesktopActivo == 'personal'
              ? _buildPersonalSection(dark)
              : (_empresaId != null
                  ? _buildContenidoModulo(_moduloDesktopActivo!)
                  : const Center(child: Text('Sin empresa'))),
        ),
      ]);
    }
    return ColoredBox(
      color: bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildGreetingSection(dark),
          const SizedBox(height: 24),
          _buildKpiRow(dark),
          const SizedBox(height: 28),
          _buildModulesGridDesktop(dark),
        ]),
      ),
    );
  }

  Widget _buildDesktopModuloHeader(String moduloId, bool dark) {
    final bg   = dark ? const Color(0xFF111827) : Colors.white;
    final text = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub  = dark ? Colors.white54 : Colors.grey.shade500;
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _moduloDesktopActivo = null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.arrow_back_rounded, size: 16, color: sub),
              const SizedBox(width: 5),
              Text('Inicio', style: TextStyle(fontSize: 13, color: sub)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.chevron_right_rounded, size: 14, color: sub),
        ),
        Text(_nombreModulo(moduloId),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: text)),
      ]),
    );
  }

  String _nombreModulo(String id) {
    const nombres = {
      'personal': 'Personal', 'empleados': 'Empleados', 'facturacion': 'Facturación',
      'clientes': 'Clientes', 'web': 'Web', 'tpv': 'TPV', 'pedidos': 'Pedidos',
      'tareas': 'Tareas', 'reservas': 'Reservas', 'fichaje': 'Fichajes',
      'vacaciones': 'Vacaciones', 'servicios': 'Servicios',
      'plantillas_pdf': 'Plantillas PDF', 'valoraciones': 'Valoraciones',
      'dashboard': 'Dashboard', 'propietario': 'Admin',
    };
    return nombres[id] ?? id;
  }

  Widget _buildPersonalSection(bool dark) {
    final bg     = dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardBg = dark ? const Color(0xFF1E2139) : Colors.white;
    final border = dark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;
    final text   = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub    = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    const tiles  = [
      _AppTile('empleados',  Icons.badge_rounded,          'Empleados',  Color(0xFF8B5CF6)),
      _AppTile('fichaje',    Icons.schedule_rounded,        'Fichajes',   Color(0xFF14B8A6)),
      _AppTile('vacaciones', Icons.beach_access_rounded,    'Vacaciones', Color(0xFF0EA5E9)),
      _AppTile('reservas',   Icons.calendar_month_rounded,  'Reservas',   Color(0xFF6366F1)),
    ];
    return ColoredBox(
      color: bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Personal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: text)),
          const SizedBox(height: 4),
          Text('Empleados, fichajes, vacaciones y más', style: TextStyle(fontSize: 14, color: sub)),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, childAspectRatio: 1.6,
                crossAxisSpacing: 14, mainAxisSpacing: 14),
            itemCount: tiles.length,
            itemBuilder: (_, i) {
              final t = tiles[i];
              return GestureDetector(
                onTap: () => setState(() => _moduloDesktopActivo = t.id),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                    boxShadow: dark ? [] : [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 38, height: 38,
                          decoration: BoxDecoration(
                              color: t.accent.withValues(alpha: dark ? 0.14 : 0.10),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(t.icon, color: t.accent, size: 19)),
                      const Spacer(),
                      Icon(Icons.arrow_forward_rounded, size: 13, color: t.accent.withValues(alpha: 0.5)),
                    ]),
                    const SizedBox(height: 10),
                    Text(t.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: text),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(_kDesc[t.id] ?? '',
                        style: TextStyle(fontSize: 11, color: sub, height: 1.4),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(_kAction[t.id] ?? '',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.accent)),
                  ]),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildModulesGridDesktop(bool dark) {
    final text   = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final cardBg = dark ? const Color(0xFF1E2139) : Colors.white;
    final border = dark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;
    final sub    = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Módulos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: text)),
      const SizedBox(height: 16),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, childAspectRatio: 1.6,
            crossAxisSpacing: 14, mainAxisSpacing: 14),
        itemCount: _kAllTiles.length,
        itemBuilder: (_, i) {
          final t = _kAllTiles[i];
          final action = _kAction[t.id] ?? '';
          return GestureDetector(
            onTap: () => t.id == 'carpeta' ? _mostrarCarpeta(dark) : _abrirModulo(t.id),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
                boxShadow: dark ? [] : [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 38, height: 38,
                      decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: dark ? 0.14 : 0.10),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(t.icon, color: t.accent, size: 19)),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, size: 13, color: t.accent.withValues(alpha: 0.5)),
                ]),
                const SizedBox(height: 10),
                Text(t.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: text),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(_kDesc[t.id] ?? '',
                    style: TextStyle(fontSize: 11, color: sub, height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                if (action.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(action,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.accent),
                        maxLines: 1),
                  ),
              ]),
            ),
          );
        },
      ),
    ]);
  }

  Widget _buildDesktopRightPanel(bool dark) {
    final bg     = dark ? const Color(0xFF111827) : Colors.white;
    final border = dark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200;
    final text   = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub    = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return Container(
      decoration: BoxDecoration(
          color: bg, border: Border(left: BorderSide(color: border))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('Actividad reciente',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text)),
          const SizedBox(height: 14),
          _buildActivityItem(Icons.receipt_long_rounded, const Color(0xFF3B82F6),
              'Factura creada', 'Hace unos minutos', text, sub),
          _buildActivityItem(Icons.people_alt_rounded, const Color(0xFF10B981),
              'Cliente añadido', 'Hace 1 hora', text, sub),
          _buildActivityItem(Icons.inventory_2_rounded, const Color(0xFFF59E0B),
              'Pedido confirmado', 'Hace 2 horas', text, sub),
          _buildActivityItem(Icons.task_alt_rounded, const Color(0xFF8B5CF6),
              'Tarea completada', 'Hace 3 horas', text, sub),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {},
            child: const Text('Ver toda la actividad →',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Color(0xFF3B82F6))),
          ),
          const SizedBox(height: 24),
          Text('Acciones rápidas',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text)),
          const SizedBox(height: 10),
          ...[
            _QuickActionData(Icons.receipt_long_rounded, const Color(0xFF3B82F6), 'Nueva factura', 'facturacion'),
            _QuickActionData(Icons.people_alt_rounded, const Color(0xFF10B981), 'Nuevo cliente', 'clientes'),
            _QuickActionData(Icons.inventory_2_rounded, const Color(0xFFF59E0B), 'Nuevo pedido', 'pedidos'),
            _QuickActionData(Icons.task_alt_rounded, const Color(0xFF8B5CF6), 'Nueva tarea', 'tareas'),
            _QuickActionData(Icons.badge_rounded, const Color(0xFF6366F1), 'Nuevo empleado', 'empleados'),
          ].map((qa) => InkWell(
            onTap: () => _abrirModulo(qa.moduloId),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(children: [
                Icon(qa.icon, color: qa.color, size: 16),
                const SizedBox(width: 10),
                Text('+ ${qa.label}',
                    style: TextStyle(fontSize: 13, color: qa.color, fontWeight: FontWeight.w500)),
              ]),
            ),
          )),
        ]),
      ),
    );
  }

  Widget _buildActivityItem(IconData icon, Color color, String title, String time, Color text, Color sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Container(width: 32, height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.10), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: text)),
          Text(time, style: TextStyle(fontSize: 11, color: sub)),
        ])),
      ]),
    );
  }

  Widget _buildAppTile(_AppTile t, bool dark, {double iconSize = 90}) {
    final fontSize = (iconSize * 0.15).clamp(10.0, 13.0);
    final br = iconSize * 0.27;
    final isCarpeta = t.id == 'carpeta';

    Widget iconWidget() {
      if (isCarpeta) {
        return Container(
          width: iconSize, height: iconSize,
          decoration: BoxDecoration(
            color: dark ? t.accent.withValues(alpha: 0.07) : t.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(br),
            border: Border.all(color: t.accent.withValues(alpha: 0.3)),
          ),
          child: GridView.count(
            crossAxisCount: 2,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(iconSize * 0.12),
            mainAxisSpacing: iconSize * 0.06,
            crossAxisSpacing: iconSize * 0.06,
            children: [
              _miniCell(const Color(0xFF6366F1), Icons.person_rounded, dark),
              _miniCell(const Color(0xFF0EA5E9), Icons.calendar_month_rounded, dark),
              _miniCell(const Color(0xFF14B8A6), Icons.schedule_rounded, dark),
              _miniCell(Colors.white.withValues(alpha: dark ? 0.1 : 0.4), null, dark),
            ],
          ),
        );
      }
      return Container(
        width: iconSize, height: iconSize,
        decoration: BoxDecoration(
          color: dark ? t.accent.withValues(alpha: 0.07) : t.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(br),
          border: Border.all(color: t.accent.withValues(alpha: 0.25)),
        ),
        child: Icon(t.icon, color: t.accent, size: iconSize * 0.42),
      );
    }

    // Ficha = solo el icono (tamaño iconSize), label debajo fuera de la ficha
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Center(child: _NeonButton(
        accent: t.accent,
        onTap: () => isCarpeta ? _mostrarCarpeta(dark) : _abrirModulo(t.id),
        child: iconWidget(),
      )),
      SizedBox(height: iconSize * 0.1),
      Text(t.label,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500,
            color: dark ? const Color(0xFFB0B3C1) : const Color(0xFF475569)),
        textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);
  }

  Widget _miniCell(Color color, IconData? icon, bool dark) => Container(
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
    child: icon != null ? Icon(icon, size: 10, color: Colors.white) : null,
  );

  void _mostrarCarpeta(bool dark) {
    final folderBg = dark ? const Color(0xFF0B0E18) : Colors.white;
    final folderBorder = dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06);
    final textColor = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final esPropietario = _sesion?.esPropietario == true;
    final tiles = _kFolderTiles.where((t) => t.id != 'propietario' || esPropietario).toList();

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: folderBg, borderRadius: BorderRadius.circular(28),
            border: Border.all(color: folderBorder),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.6 : 0.12),
                blurRadius: 60, offset: const Offset(0, 20))],
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Más módulos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 20, runSpacing: 22, alignment: WrapAlignment.center,
              children: tiles.map((t) => SizedBox(
                width: 68,
                child: _buildAppTileCompact(t, dark, onTap: () {
                  Navigator.pop(context);
                  _abrirModulo(t.id);
                }),
              )).toList(),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: dark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close_rounded, size: 16,
                    color: dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildAppTileCompact(_AppTile t, bool dark, {required VoidCallback onTap}) {
    return _NeonButton(
      accent: t.accent, onTap: onTap,
      child: Column(children: [
        Container(
          width: 62, height: 62,
          decoration: BoxDecoration(
            color: dark ? t.accent.withValues(alpha: 0.06) : t.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: t.accent.withValues(alpha: 0.25)),
          ),
          child: Icon(t.icon, color: t.accent, size: 26),
        ),
        const SizedBox(height: 7),
        Text(t.label,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500,
                color: dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildGlow(double size, Color color, {
    double? top, double? left, double? bottom, double? right, double opacity = 0.28,
  }) => Positioned(
    top: top, left: left, bottom: bottom, right: right,
    child: IgnorePointer(
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: opacity)),
        child: Container(decoration: BoxDecoration(shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: opacity), blurRadius: 110, spreadRadius: 20)])),
      ),
    ),
  );

  void _abrirModulo(String id) {
    // En desktop: renderizar en el área de contenido (sidebar fija)
    final isDesktop = MediaQuery.of(context).size.width >= 1100;
    if (isDesktop) {
      if (id == 'perfil') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaPerfil(sesion: _sesion)));
        return;
      }
      if (_empresaId == null) return;
      // 'empleados' desde accesos rápidos → sección personal
      setState(() => _moduloDesktopActivo = id == 'empleados' ? 'personal' : id);
      return;
    }

    if (_empresaId == null && id != 'perfil') return;
    final eid = _empresaId ?? '';
    final ses = _sesionEfectiva;
    Widget? screen;
    switch (id) {
      case 'dashboard':
        screen = Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: AppBar(title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
              backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, elevation: 0),
          body: _buildDashboardModular(),
        );
        break;
      case 'facturacion':    screen = ModuloFacturacionScreen(empresaId: eid); break;
      case 'clientes':       screen = ModuloClientesScreen(empresaId: eid, sesion: ses); break;
      case 'web':            screen = PantallaContenidoWeb(empresaId: eid); break;
      case 'tpv':            screen = _LanzadorTpv(
                               empresaId: eid,
                               esAdmin: ses?.esAdmin ?? false,
                               esPropietario: ses?.esPropietario ?? false,
                               esPropietarioPlatforma: ses?.esPropietarioPlatforma ?? false,
                               propietarioUid: _sesion?.uid ?? '',
                             ); break;
      case 'empleados':      screen = ModuloEmpleadosScreen(empresaId: eid, sesion: ses); break;
      case 'pedidos':        screen = ModuloPedidosNuevoScreen(empresaId: eid); break;
      case 'tareas':         screen = ModuloTareasScreen(empresaId: eid); break;
      case 'perfil':         screen = PantallaPerfil(sesion: _sesion); break;
      case 'reservas':       screen = ModuloReservasScreen(empresaId: eid, sesion: ses); break;
      case 'valoraciones':   screen = ModuloValoraciones(empresaId: eid); break;
      case 'fichaje':        screen = GestionFichajesScreen(empresaId: eid, esAdmin: ses?.esAdmin ?? false); break;
      case 'vacaciones':     screen = VacacionesScreen(empresaId: eid, sesion: ses); break;
      case 'servicios':      screen = ModuloServiciosScreen(empresaId: eid, sesion: ses); break;
      case 'plantillas_pdf': screen = PdfTemplatesListScreen(empresaId: eid); break;
      case 'propietario':    screen = _sesion?.esPropietario == true ? const ModuloPropietario() : null; break;
      default: return;
    }
    if (screen == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
  }

  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve el widget correspondiente a cada módulo por su ID
  Widget _buildContenidoModulo(String moduloId) {
    final id = _empresaId!;
    final sesionActiva = _sesionEfectiva;
    // Módulo exclusivo del rol propietario (estrictamente)
    final esPropietario = _sesion?.esPropietario == true;
    switch (moduloId) {
      case 'propietario':     return esPropietario ? const ModuloPropietario() : const Center(child: Text('Sin acceso'));
      case 'dashboard':       return _buildDashboardModular();
      case 'valoraciones':    return ModuloValoraciones(empresaId: id);
      case 'reservas':        return ModuloReservasScreen(empresaId: id, sesion: sesionActiva);
      case 'citas':           return ModuloReservasScreen(empresaId: id, sesion: sesionActiva);
      case 'estadisticas':    return ModuloEstadisticas(empresaId: id);
      case 'tareas':          return ModuloTareasScreen(empresaId: id);
      case 'pedidos':         return ModuloPedidosNuevoScreen(empresaId: id);
      case 'tpv':             return _LanzadorTpv(
                                empresaId: id,
                                esAdmin: sesionActiva?.esAdmin ?? false,
                                esPropietario: sesionActiva?.esPropietario ?? false,
                                esPropietarioPlatforma: sesionActiva?.esPropietarioPlatforma ?? false,
                                propietarioUid: _sesion?.uid ?? '',
                              );
      case 'whatsapp':        return ModuloWhatsAppScreen(empresaId: id);
      case 'facturacion':     return ModuloFacturacionScreen(empresaId: id);
      case 'empleados':       return ModuloEmpleadosScreen(empresaId: id, sesion: sesionActiva);
      case 'clientes':        return ModuloClientesScreen(empresaId: id, sesion: sesionActiva);
      case 'servicios':       return ModuloServiciosScreen(empresaId: id, sesion: sesionActiva);
      case 'nominas':         return const Center(child: Text('Módulo no disponible'));
      case 'fichaje':         return _construirPantallaFichaje();
      case 'vacaciones':      return VacacionesScreen(empresaId: id, sesion: sesionActiva);
      case 'web':             return _buildVistaWeb();
      case 'app':             return ModuloAppScreen(empresaId: id);
      case 'plantillas_pdf':  return PdfTemplatesListScreen(empresaId: id);
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
  // Banner compacto solo en área de contenido (botones de rol están en sidebar)
  Widget _buildSimulacionBanner() => Container(
    width: double.infinity,
    color: _rolVistaActual == RolApp.clienteFinal ? Colors.green[700] : Colors.amber[700],
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Row(children: [
      Icon(_rolVistaActual == RolApp.clienteFinal ? Icons.phone_android : Icons.preview,
          color: Colors.white, size: 14),
      const SizedBox(width: 6),
      Expanded(child: Text(
        _rolVistaActual == RolApp.clienteFinal
            ? 'Vista de Cliente Final — viendo como un usuario B2C'
            : 'Vista de ${_rolVistaActual == RolApp.admin ? 'Administrador' : 'Staff'} — simulando permisos',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      )),
      GestureDetector(
        onTap: () => setState(() => _rolVistaActual = null),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.close, color: Colors.white, size: 14),
        ),
      ),
    ]),
  );

  Widget _buildBotonesVistaPropietario() {
    // Si está simulando, mostramos un banner de aviso
    final simulando = _rolVistaActual != null;

    return Column(
      children: [
        if (simulando)
          Container(
            width: double.infinity,
            color: _rolVistaActual == RolApp.clienteFinal 
                ? Colors.green[700] 
                : Colors.amber[700],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(
                  _rolVistaActual == RolApp.clienteFinal 
                      ? Icons.phone_android 
                      : Icons.preview, 
                  color: Colors.white, 
                  size: 16
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _rolVistaActual == RolApp.clienteFinal
                        ? 'Vista de Cliente Final — viendo como un usuario B2C'
                        : 'Vista de ${_rolVistaActual == RolApp.admin ? 'Administrador' : 'Usuario/Staff'}  —  no ves lo que ven los propietarios',
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
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
                  label: '👑 Propietario',
                  activo: _rolVistaActual == null,
                  color: const Color(0xFF0D47A1),
                  onTap: () => setState(() => _rolVistaActual = null),
                ),
                const SizedBox(width: 6),
                _chipVista(
                  label: '🛡️ Admin',
                  activo: _rolVistaActual == RolApp.admin,
                  color: const Color(0xFF7B1FA2),
                  onTap: () => setState(() => _rolVistaActual = RolApp.admin),
                ),
                const SizedBox(width: 6),
                _chipVista(
                  label: '👤 Staff',
                  activo: _rolVistaActual == RolApp.staff,
                  color: const Color(0xFF388E3C),
                  onTap: () => setState(() => _rolVistaActual = RolApp.staff),
                ),
                const SizedBox(width: 6),
                _chipVista(
                  label: '📱 Usuario',
                  activo: _rolVistaActual == RolApp.clienteFinal,
                  color: const Color(0xFF00ACC1),
                  onTap: () => setState(() => _rolVistaActual = RolApp.clienteFinal),
                ),
              ],
            ),
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

  /// Vista completa del cliente final (B2C) — se muestra cuando el propietario
  /// simula la vista 📱 Usuario desde el panel de control.
  Widget _buildVistaClienteFinalCompleta() {
    return Column(
      children: [
        // Banner "Vista de Cliente Final" + botones de rol
        _buildBotonesVistaPropietario(),
        // Pantalla explorar ocupa el resto del espacio
        Expanded(child: PantallaExplorar(soloContenido: true)),
      ],
    );
  }

  bool _esBienvenidaVisible(List<ModuloConfig> modulosVisibles) {
    final idx = _indiceSeleccionado.clamp(0, modulosVisibles.length - 1);
    final id = modulosVisibles[idx].id;
    return id == 'dashboard' || id == 'propietario';
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
                SliverToBoxAdapter(child: _buildAlertaStockBajo()),
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

  /// Construye la pantalla de fichaje según el rol del usuario
  Widget _construirPantallaFichaje() {
    return GestionFichajesScreen(
      empresaId: _empresaId ?? '',
      esAdmin: _sesion?.esAdmin == true,
    );
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
      case 'vista_usuario':
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PantallaExplorar()),
          (route) => false,
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
                      debugPrint('🔴 SIGNOUT: iniciando cierre de sesión');
                      Navigator.pop(ctx);
                      debugPrint('🔴 SIGNOUT: dialog cerrado, empresaId=$_empresaId');
                      if (_empresaId != null) {
                        try {
                          await NotificacionesService().eliminarTokenDeEmpresa(_empresaId!);
                          debugPrint('🔴 SIGNOUT: token FCM eliminado');
                        } catch (e) {
                          debugPrint('🔴 SIGNOUT: error eliminando token: $e');
                        }
                      }
                      PermisosService().limpiarSesion();
                      debugPrint('🔴 SIGNOUT: permisos limpiados');
                      try {
                        await FirebaseAuth.instance.signOut();
                        debugPrint('🔴 SIGNOUT: Firebase signOut OK');
                      } catch (e) {
                        debugPrint('🔴 SIGNOUT: Firebase signOut error: $e');
                      }
                      debugPrint('🔴 SIGNOUT: llamando AppNavigator.irALogin(), key.currentState=${AppNavigator.key.currentState}');
                      AppNavigator.irALogin();
                      debugPrint('🔴 SIGNOUT: irALogin() completado');
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

  /// Banner de alerta de stock bajo
  Widget _buildAlertaStockBajo() {
    if (_empresaId == null) return const SizedBox.shrink();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: StockService().productosConStockBajo(_empresaId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final productos = snapshot.data!;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: MaterialBanner(
            backgroundColor: Colors.orange.shade50,
            leading: Icon(Icons.inventory_2_outlined,
                color: Colors.orange.shade700, size: 28),
            content: Text(
              '⚠️ ${productos.length} producto(s) con stock bajo: '
              '${productos.take(3).map((p) => p['nombre']).join(', ')}'
              '${productos.length > 3 ? '...' : ''}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.orange.shade900),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // TODO: Navegar al catálogo filtrado por stock bajo
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        productos
                            .map((p) =>
                                '${p['nombre']}: ${p['stock']} uds (mín: ${p['stock_minimo']})')
                            .join('\n'),
                      ),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                },
                child: const Text('Ver detalles'),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  // Ocultar el banner temporalmente (la próxima vez que
                  // se recargue el dashboard volverá a aparecer)
                  setState(() {});
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LanzadorTpv
// Widget que sirve de placeholder para el módulo TPV en el TabBarView.
// En cuanto se monta, lanza TpvRootScreen como ruta completa (con apaisado).
// Si el usuario es Propietario, lanza primero el selector de negocio.
// ─────────────────────────────────────────────────────────────────────────────
class _LanzadorTpv extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  final bool esPropietario;
  final bool esPropietarioPlatforma;
  final String propietarioUid;

  const _LanzadorTpv({
    required this.empresaId,
    this.esAdmin = false,
    this.esPropietario = false,
    this.esPropietarioPlatforma = false,
    this.propietarioUid = '',
  });

  @override
  State<_LanzadorTpv> createState() => _LanzadorTpvState();
}

class _LanzadorTpvState extends State<_LanzadorTpv> {
  bool _haLanzado = false;

  @override
  void initState() {
    super.initState();
    // Esperar a que el frame esté listo antes de hacer push
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrirTpv());
  }

  Future<void> _abrirTpv() async {
    if (!mounted || _haLanzado) return;
    _haLanzado = true;

    // Si el usuario es propietario, abrir primero el selector de negocio
    if (widget.esPropietario || widget.esPropietarioPlatforma) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TpvSelectorNegocioScreen(
            propietarioUid: widget.propietarioUid.isNotEmpty
                ? widget.propietarioUid
                : FirebaseAuth.instance.currentUser?.uid ?? '',
            empresaIdPropia: widget.empresaId,
            esPropietarioPlatforma: widget.esPropietarioPlatforma,
          ),
        ),
      );
      return;
    }

    // Para admin/staff: Leer tipoTpv desde Firestore para enrutar al TPV correcto
    String tipoTpv = 'bar';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .get();
      tipoTpv = snap.data()?['tipo_tpv'] as String? ?? 'bar';
    } catch (_) {}

    if (!mounted) return;

    Widget tpvScreen;
    switch (tipoTpv) {
      case 'peluqueria_estetica':
        tpvScreen = TpvPeluqueriaScreen(
            empresaId: widget.empresaId,
            esAdmin: widget.esAdmin,
            esPropietario: widget.esPropietario);
        break;
      case 'tienda':
        tpvScreen = TpvTiendaScreen(
            empresaId: widget.empresaId, esAdmin: widget.esAdmin);
        break;
      default:
        tpvScreen = TpvRootScreen(
            empresaId: widget.empresaId,
            esAdmin: widget.esAdmin,
            esPropietario: widget.esPropietario || widget.esPropietarioPlatforma,
        );
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => tpvScreen,
      ),
    );
    // Al volver del TPV restaurar orientación vertical
    if (mounted) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Placeholder minimalista - el TPV se empuja sobre este tab inmediatamente
    return const SizedBox.expand(
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

// ── Dato inmutable para un item del sidebar de desktop ────────────────────────
class _SidebarItem {
  final IconData icon;
  final String label;
  final String? moduloId;
  const _SidebarItem(this.icon, this.label, this.moduloId);
}

// ── Dato inmutable para una acción rápida ─────────────────────────────────────
class _QuickActionData {
  final IconData icon;
  final Color color;
  final String label;
  final String moduloId;
  const _QuickActionData(this.icon, this.color, this.label, this.moduloId);
}

// ── Dato inmutable para un tile del launcher ──────────────────────────────────
class _AppTile {
  final String id;
  final IconData icon;
  final String label;
  final Color accent;
  const _AppTile(this.id, this.icon, this.label, this.accent);
}

// ── Botón shimmer sweep (hover dispara una franja diagonal que cruza el tile) ─
class _NeonButton extends StatefulWidget {
  final Color accent;
  final VoidCallback onTap;
  final Widget child;
  const _NeonButton({required this.accent, required this.onTap, required this.child});

  @override
  State<_NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<_NeonButton> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late AnimationController _ctrl;
  late Animation<double> _sweep;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _sweep = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _fire() => _ctrl.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _fire(),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) { setState(() => _pressed = true); _fire(); },
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedBuilder(
          animation: _sweep,
          builder: (_, child) {
            final v = _sweep.value;
            final bgAlpha = (v < 0.5 ? v * 2 : (1 - v) * 2) * 0.09;
            final shimX = v * 3.6 - 1.8;
            return AnimatedScale(
              scale: _pressed ? 0.91 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: widget.accent.withValues(alpha: bgAlpha),
                ),
                child: Stack(clipBehavior: Clip.none, children: [
                  child!,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Align(
                          alignment: Alignment(shimX, 0),
                          child: Transform.rotate(
                            angle: 0.45,
                            child: Container(
                              width: 42, height: 220,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.32),
                                    widget.accent.withValues(alpha: 0.18),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}








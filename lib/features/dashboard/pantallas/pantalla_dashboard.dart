import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/layout/fluix_module_actions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/modulo_valoraciones_fixed.dart';
import '../widgets/modulo_estadisticas.dart';
import '../widgets/modulo_propietario.dart';
import '../widgets/briefing_card.dart';
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
import '../../tareas/pantallas/formulario_tarea_screen.dart';
import '../../../domain/modelos/tarea.dart';
import '../../pedidos/pantallas/modulo_pedidos_nuevo_screen.dart';
import '../../pedidos/pantallas/modulo_whatsapp_screen.dart';
import '../../empleados/pantallas/modulo_empleados_screen.dart';
import '../../facturacion/pantallas/modulo_facturacion_screen.dart';
import '../../facturacion/pantallas/pantalla_contabilidad.dart';
import '../../reservas/pantallas/modulo_reservas_screen.dart';
import '../../reservas/pantallas/detalle_reserva_screen.dart';
import '../../clientes/pantallas/modulo_clientes_screen.dart';
import '../../servicios/pantallas/modulo_servicios_screen.dart';
import '../../nominas/pantallas/modulo_nominas_screen.dart';
import '../../nominas/pantallas/mis_nominas_screen.dart';
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
import '../../perfil/pantallas/gestionar_cuentas_screen.dart';
import 'pantalla_contenido_web.dart';
import 'pantalla_grafo_app.dart';
import '../../soporte/pantallas/modulo_soporte_screen.dart';
import '../../negocio_publico/pantallas/modulo_app_screen.dart';
import '../../../services/stock_service.dart';
import '../../../core/widgets/flux_toast.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../core/widgets/fluix_bottom_nav.dart';
import '../../../core/utils/app_settings.dart';
import '../../../services/auth/token_refresh_service.dart';
import '../../../services/ia_service.dart';
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
  String? _empresaIdPropia; // ID original del propietario de plataforma
  String _nombreUsuario = '';
  String _nombreEmpresa = '';
  bool _cargando = true;
  bool _generandoDemo = false;
  List<String> _modulosActivos = [];
  SesionUsuario? _sesion;
  StreamSubscription? _notifSubscription;
  StreamSubscription? _mensajesWebSub;      // listener contacto_web (cancelado en dispose)
  StreamSubscription? _pedidosPendientesSub; // listener pedidos pendientes (cancelado en dispose)
  StreamSubscription? _noLeidasSub;          // listener bandeja no-leídas (cancelado en dispose)
  int _mensajesSinLeer = 0; // Contador de mensajes sin leer en módulo web
  int _indiceSeleccionado = 0; // Para NavigationRail en desktop
  int _paginaHome = 0; // 0=inicio, 1=módulos (mobile bottom nav)
  String? _moduloDesktopActivo; // null=home, 'personal', 'perfil', 'mas', o id de módulo
  DateTime _fechaFiltro = DateTime.now(); // filtro de día en actividad reciente
  final TextEditingController _searchCtrl = TextEditingController();

  // ── Acciones extra del módulo activo en el AppBar ─────────────────────────
  // Los módulos llaman a _setModuleActions([...]) para añadir botones propios.
  final ValueNotifier<List<Widget>> _moduleActionsNotifier = ValueNotifier([]);

  // ── Toast de notificación estilo WhatsApp ─────────────────────────────────
  ({String titulo, String cuerpo, IconData icono, Color color})? _notifToast;
  Timer? _toastTimer;
  int? _prevNoLeidas;
  int? _prevMensajes;
  int? _prevPedidos;

  // ── Modo edición dashboard (reordenar widgets) ────────────────────────────
  bool _editandoDashboard = false;

  // ── Acciones del TPV embebido (registradas por TpvTiendaScreen) ───────────
  TpvEmbedActions? _tpvActions;

  // ── Sidebar colapsado (solo activo en modo TPV) ────────────────────────────
  bool _sidebarCollapsado = false;
  /// True solo cuando estamos en TPV Y el usuario lo ha colapsado
  bool get _sidebarEfectivoCollapsado => _moduloDesktopActivo == 'tpv' && _sidebarCollapsado;

  // ── Facturación: mes seleccionado + ventana de 6 meses del gráfico ─────────
  late DateTime _facturacionMes;
  late DateTime _facturacionVentana; // primer mes visible en el gráfico

  // ── Tema oscuro/claro del launcher ───────────────────────────────────────
  bool _darkMode = false;

  // ── Pestaña del panel derecho desktop ────────────────────────────────────
  String _rightPanelTab = 'inicio'; // 'inicio' | 'fiscal'

  // ── Navegación calendario home ────────────────────────────────────────────
  int _calendarWeekOffset = 0;

  // ── Sub-módulo activo dentro de Web (null = hub) ──────────────────────────
  String? _webSubModulo;
  final _webVolverAlHub = ValueNotifier<int>(0); // incrementar para señal de volver

  // ── Vista dual empresa/usuario ────────────────────────────────────────────
  late VistaActiva _vistaActual;

  // ── Vista simulada (solo Propietario) ─────────────────────────────────────
  RolApp? _rolVistaActual;

  // ID fijo de Editorial Nazarí — controla qué módulos se muestran
  static const _kNazariId = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

  // Módulos que Nazarí NO debe ver (ni en grid, ni en sidebar, ni en KPIs)
  static const _kNazariModulosOcultos = {'tareas', 'reservas', 'valoraciones', 'fichaje', 'vacaciones'};

  // ── Tiles del launcher (3×3 + tecla "0") ─────────────────────────────────
  static const _kAllTiles = [
    _AppTile('dashboard',   Icons.grid_view_rounded,           'Dashboard',    Color(0xFF3B82F6)),
    _AppTile('facturacion', Icons.receipt_long_rounded,        'Facturación',  Color(0xFF10B981)),
    _AppTile('clientes',    Icons.people_alt_rounded,          'Clientes',     Color(0xFF3B82F6)),
    _AppTile('web',         Icons.language_rounded,            'Web',          Color(0xFF22D3EE)),
    _AppTile('tpv',         Icons.point_of_sale_rounded,       'TPV',          Color(0xFFF59E0B)),
    _AppTile('personal',    Icons.badge_rounded,               'Personal',     Color(0xFF8B5CF6)),
    _AppTile('pedidos',     Icons.inventory_2_rounded,         'Pedidos',      Color(0xFFEC4899)),
    _AppTile('tareas',      Icons.task_alt_rounded,            'Tareas',       Color(0xFF14B8A6)),
    _AppTile('perfil',      Icons.account_circle_rounded,      'Mi Perfil',    Color(0xFF6366F1)),
    _AppTile('carpeta',     Icons.folder_special_rounded,      'Más',          Color(0xFF6366F1)),
  ];

  bool get _esNazari => _empresaId == _kNazariId;

  // Tiles filtrados por suscripción, rol y empresa
  List<_AppTile> get _tilesPermitidos {
    final sesion = _sesionEfectiva;
    List<_AppTile> base;

    if (sesion == null || (sesion.esPropietarioPlatforma && _rolVistaActual == null)) {
      base = List.of(_kAllTiles);
    } else {
      final modulosEnPlan = _suscripcionService.getModulosActivos();
      const aliases = <String, String>{'personal': 'empleados', 'web': 'contenido_web'};
      base = _kAllTiles.where((t) {
        if (t.id == 'perfil' || t.id == 'carpeta') return true;
        final moduloId = aliases[t.id] ?? t.id;
        final enRol = sesion.modulosVisibles.contains(t.id) ||
                      sesion.modulosVisibles.contains(moduloId);
        if (!enRol) return false;
        return modulosEnPlan.contains(moduloId) || modulosEnPlan.contains(t.id);
      }).toList();
    }

    if (_esNazari) {
      // Para Nazarí: quitar módulos ocultos y sustituir "carpeta" por "Plantillas PDF"
      base = base
          .where((t) => !_kNazariModulosOcultos.contains(t.id))
          .map((t) => t.id == 'carpeta'
              ? const _AppTile('plantillas_pdf', Icons.picture_as_pdf_rounded, 'Plantillas', Color(0xFFEF4444))
              : t)
          .toList();
    }

    return base;
  }

  // Descripciones para list/card view responsive
  static const _kDesc = <String, String>{
    'dashboard':     'Resumen y estadísticas de tu negocio',
    'facturacion':   'Crea y gestiona facturas, presupuestos y rectificativas',
    'clientes':      'Gestiona tus clientes y su información',
    'web':           'Gestiona el contenido de tu sitio web',
    'tpv':           'Gestiona ventas, productos y caja',
    'personal':      'Empleados, fichajes, vacaciones y más',
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
    'personal':      'Empleados, fichajes y más',
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
    _facturacionMes    = DateTime(DateTime.now().year, DateTime.now().month);
    _facturacionVentana = DateTime(DateTime.now().year, DateTime.now().month - 5);
    // Sincronizar dark mode con AppSettings
    _darkMode = AppSettings.darkMode.value;
    AppSettings.darkMode.addListener(_syncDarkMode);
    // Listener para cambiar tab del dashboard cuando vuelve de un módulo
    AppSettings.targetTab.addListener(_syncTargetTab);
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
        if (message != null) _manejarNavegacionNotificacion(message.data);
      });
      // Notificaciones en primer plano — persistente para mensajes/pedidos
      FirebaseMessaging.onMessage.listen((msg) {
        if (!mounted) return;
        final titulo = msg.notification?.title ?? 'Fluix';
        final cuerpo = msg.notification?.body ?? '';
        final esMensaje = titulo.toLowerCase().contains('mensaje') ||
            titulo.toLowerCase().contains('manuscrito') ||
            titulo.toLowerCase().contains('pedido') ||
            titulo.toLowerCase().contains('reserva');
        _mostrarToast(
          titulo: titulo, cuerpo: cuerpo,
          icono: esMensaje ? Icons.mark_email_unread_rounded : Icons.notifications_rounded,
          color: esMensaje ? const Color(0xFF059669) : const Color(0xFF0D47A1),
          persistente: esMensaje,
        );
      });
    }
  }

  /// Escuchar cambios en mensajes de contacto web sin leer
  void _escucharMensajesSinLeer() {
    if (_empresaId == null) return;

    // ── Mensajes de contacto web — solo no leídos, docChanges para detectar nuevos ──
    bool _mensajesInicial = true;
    _mensajesWebSub?.cancel();
    _mensajesWebSub = FirebaseFirestore.instance
        .collection('empresas').doc(_empresaId)
        .collection('contacto_web')
        .where('leido', isEqualTo: false)
        .snapshots().listen((snapshot) {
      if (!mounted) return;
      // Primera llamada: inicializar contador sin toast
      if (_mensajesInicial) {
        _mensajesInicial = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _mensajesSinLeer = snapshot.docs.length);
          // Mostrar toast si ya hay mensajes sin leer al abrir la app
          if (snapshot.docs.isNotEmpty) {
            final count = snapshot.docs.length;
            final ultimo = snapshot.docs.first.data();
            _mostrarToast(
              titulo: count == 1 ? '1 mensaje sin leer' : '$count mensajes sin leer',
              cuerpo: (ultimo['nombre'] as String? ?? 'Web') +
                  ' — ' + (ultimo['asunto'] as String? ?? ''),
              icono: Icons.mark_email_unread_rounded,
              color: const Color(0xFF059669),
              persistente: false,
            );
          }
        });
        return;
      }
      // Detectar documentos AÑADIDOS (nuevos mensajes)
      final nuevos = snapshot.docChanges
          .where((c) => c.type == DocumentChangeType.added)
          .toList();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _mensajesSinLeer = snapshot.docs.length);
        if (nuevos.isNotEmpty) {
          final ultimo = nuevos.last.doc.data() as Map<String, dynamic>? ?? {};
          _mostrarToast(
            titulo: nuevos.length == 1 ? '¡Nuevo mensaje!' : '¡${nuevos.length} mensajes nuevos!',
            cuerpo: (ultimo['nombre'] as String? ?? 'Web') +
                ' — ' + (ultimo['asunto'] as String? ?? ''),
            icono: Icons.mark_email_unread_rounded,
            color: const Color(0xFF059669),
            persistente: true,
          );
        }
      });
    }, onError: (_) {});

    // ── Pedidos nuevos — filtro por estado pendiente ──────────────────────────
    bool _pedidosInicial = true;
    _pedidosPendientesSub?.cancel();
    _pedidosPendientesSub = FirebaseFirestore.instance
        .collection('empresas').doc(_empresaId)
        .collection('pedidos')
        .where('estado', isEqualTo: 'pendiente')
        .snapshots().listen((snapshot) {
      if (!mounted) return;
      if (_pedidosInicial) { _pedidosInicial = false; return; }
      final nuevos = snapshot.docChanges
          .where((c) => c.type == DocumentChangeType.added)
          .toList();
      if (nuevos.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ultimo = nuevos.last.doc.data() as Map<String, dynamic>? ?? {};
        _mostrarToast(
          titulo: nuevos.length == 1 ? '¡Nuevo pedido!' : '¡${nuevos.length} pedidos nuevos!',
          cuerpo: (ultimo['cliente_nombre'] as String? ?? 'Cliente') +
              ' — ' + (ultimo['total']?.toString() ?? '') + ' €',
          icono: Icons.shopping_bag_rounded,
          color: const Color(0xFFF59E0B),
          persistente: true,
        );
      });
    }, onError: (_) {});

    // Toast cuando llegan nuevas notificaciones internas
    _noLeidasSub?.cancel();
    _noLeidasSub = BandejaNotificacionesService().noLeidasCount(_empresaId!).listen((count) {
      if (!mounted) return;
      final prev = _prevNoLeidas;
      _prevNoLeidas = count;
      if (prev != null && count > prev) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _mostrarToast(
            titulo: '¡Nueva notificación!',
            cuerpo:  'Tienes $count aviso${count == 1 ? '' : 's'} sin leer — toca para ver',
            icono:   Icons.notifications_active_rounded,
            color:   const Color(0xFF3B82F6),
            persistente: true,
          );
        });
      }
    }, onError: (_) {});
  }

  void _mostrarToast({
    required String titulo,
    required String cuerpo,
    required IconData icono,
    required Color color,
    bool persistente = false,
  }) {
    // Usar FluxToast (overlay root) para visibilidad en todas las pantallas
    FluxToast.show(
      context,
      cuerpo,
      title: titulo,
      icon: icono,
      color: color,
      duration: persistente
          ? const Duration(days: 1)  // "permanente" hasta que el usuario lo cierre
          : const Duration(seconds: 8),
    );
  }

  @override
  void dispose() {
    AppSettings.darkMode.removeListener(_syncDarkMode);
    AppSettings.targetTab.removeListener(_syncTargetTab);
    _tabController?.dispose();
    _toastTimer?.cancel();
    _searchCtrl.dispose();
    _notifSubscription?.cancel();
    _mensajesWebSub?.cancel();
    _pedidosPendientesSub?.cancel();
    _noLeidasSub?.cancel();
    super.dispose();
  }

  void _syncDarkMode() {
    if (mounted) setState(() => _darkMode = AppSettings.darkMode.value);
  }

  void _syncTargetTab() {
    final tab = AppSettings.targetTab.value;
    if (tab == null || !mounted) return;
    // Resetear ANTES de setState para que la notificación re-entrante del
    // ValueNotifier no dispare otra llamada a _syncTargetTab durante el rebuild.
    AppSettings.targetTab.value = null;
    setState(() => _paginaHome = tab);
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
        if (!mounted) return;
        setState(() {
          _empresaId = empresaId;
          _empresaIdPropia ??= empresaId;
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
          await _suscripcionService.cargarSuscripcion(empresaId);
          _escucharMensajesSinLeer();
          // Cargar nombre de la empresa para el header desktop
          try {
            final empDoc = await FirebaseFirestore.instance
                .collection('empresas').doc(empresaId).get();
            if (empDoc.exists && mounted) {
              final empData = empDoc.data()!;
              final nombre = empData['perfil']?['nombre'] ??
                  empData['nombre'] ?? '';
              setState(() => _nombreEmpresa = nombre.toString());
            }
          } catch (_) {}
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

            if (!mounted) return;
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

        if (!mounted) return;
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
    return Stack(children: [
      kDebugMode ? Stack(children: [screen, const DebugFCMWidget()]) : screen,
      if (_notifToast != null) _buildNotifToast(),
    ]);
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
                final esStaff = _sesion != null && !(_sesion!.esAdmin);
                var modulosFiltrados = modulosActivos.where((m) {
                  if (m.id == 'propietario') return esPropietario;
                  // Nóminas: solo visible para staff (como "Mis Nóminas")
                  // Admin/propietario lo acceden desde el módulo de empleados
                  if (m.id == 'nominas') return esStaff;
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
                  var visiblesPorRol = sesionActiva != null
                      ? modulosFiltrados.where((m) =>
                          sesionActiva.modulosVisibles.contains(m.id)).toList()
                      : modulosFiltrados.toList();

                  // Filtrar por suscripción: solo mostrar módulos que el plan incluye.
                  // esPropietarioEfectivo = propietario en su propia vista real.
                  // Si simula otra empresa (_rolVistaActual != null) se aplica
                  // el filtro igualmente para ver exactamente lo que ve esa empresa.
                  final esPropietarioEfectivo = esPropietario && _rolVistaActual == null;
                  if (!esPropietarioEfectivo) {
                    final modulosEnPlan = _suscripcionService.getModulosActivos();
                    visiblesPorRol = visiblesPorRol.where((m) {
                      if (ModulosDisponibles.activosPorDefecto.contains(m.id)) return true;
                      if (modulosEnPlan.contains(m.id)) return true;
                      // Alias: módulo 'web' ↔ 'contenido_web' en el plan
                      if (m.id == 'web' && modulosEnPlan.contains('contenido_web')) return true;
                      return false;
                    }).toList();
                  }
                  modulosVisibles = visiblesPorRol;
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

  // ─── Toast notificación grande centrado arriba ──────────────────────────────

  Widget _buildNotifToast() {
    final data = _notifToast!;
    // Posicionar debajo del AppBar (status bar + toolbar + margen)
    final topOffset = MediaQuery.of(context).padding.top + kToolbarHeight + 8;
    return Positioned(
      top: topOffset,
      left: 16,
      right: 16,
      child: TweenAnimationBuilder<double>(
        key: ValueKey('${data.titulo}${data.cuerpo}'),
        tween: Tween(begin: -120.0, end: 0.0),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Transform.translate(offset: Offset(0, v), child: child),
        child: Material(
          elevation: 20,
          shadowColor: data.color.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              setState(() => _notifToast = null);
              if (_empresaId != null) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => BandejaNotificacionesScreen(empresaId: _empresaId!),
                ));
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: data.color.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Barra de color superior
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: data.color,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: data.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(data.icono, color: data.color, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data.titulo,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                              color: data.color)),
                      const SizedBox(height: 3),
                      Text(data.cuerpo,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF374151),
                              height: 1.4),
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                    ])),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _notifToast = null),
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 16,
                            color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LAUNCHER iOS-style
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileLauncher() {
    final dark = _darkMode;
    final size = MediaQuery.of(context).size;
    // Panel layout (sidebar visible): >= 640px (tablet estrecho/landscape y desktop).
    // Por debajo → layout móvil con barra inferior.
    final usePanelLayout = size.width >= 640;

    if (usePanelLayout) {
      return Scaffold(
        backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        body: _buildDesktopLayout(dark),
      );
    }

    // Móvil puro: < 700px → barra inferior + AppBar superior.
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
                        _buildDashboardHome(dark),      // Inicio = dashboard completo
                        _buildModuleList(_tilesPermitidos, dark),
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
    final iconColor = dark ? Colors.white70 : Colors.black87;

    // Botones extra: cambio de vista de rol (solo propietario)
    final extraActions = <Widget>[
      if (_sesion?.esPropietario == true)
        PopupMenuButton<String>(
          tooltip: 'Cambiar vista de rol',
          icon: Stack(clipBehavior: Clip.none, children: [
            Icon(Icons.manage_accounts_rounded, color: iconColor, size: 22),
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
    ];

    // Campana de notificaciones
    final notifWidget = _empresaId != null
        ? StreamBuilder<int>(
            stream: BandejaNotificacionesService().noLeidasCount(_empresaId!),
            builder: (_, snap) => IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              icon: BadgeIcon(
                icon: Icons.notifications_outlined,
                count: snap.data ?? 0,
                iconColor: iconColor,
                iconSize: 22,
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => BandejaNotificacionesScreen(empresaId: _empresaId!),
              )),
            ),
          )
        : null;

    return FluixAppBar(
      esPropietarioPlatforma: _sesion?.esPropietarioPlatforma == true,
      empresaActiva:          _empresaId != _empresaIdPropia,
      onCambiarEmpresa:       () => _abrirSelectorEmpresa(dark),
      onManejarMenu:          _manejarMenu,
      extraActions:           extraActions,
      notifWidget:            notifWidget,
    );
  }

  // ── Launcher panel — responsive ───────────────────────────────────────────
  Widget _buildLauncherPanel(bool dark) {
    final size = MediaQuery.of(context).size;
    final isPortraitMobile = size.shortestSide < 600 && size.height > size.width;
    return isPortraitMobile
        ? _buildModuleList(_kAllTiles, dark)
        : _buildModuleCards(_tilesPermitidos, dark, size.width);
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
          childAspectRatio: 1.25,
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
              padding: const EdgeInsets.all(14),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: dark ? 0.14 : 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(t.icon, color: t.accent, size: 19),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: t.accent.withValues(alpha: 0.5)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.label,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      _kDesc[t.id] ?? '',
                      style: TextStyle(fontSize: 11, color: sub, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (action.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
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
    final outerBg = dark ? const Color(0xFF0A0F23) : const Color(0xFFF0F4F8);
    final cardBg  = dark ? const Color(0xFF1E2139) : Colors.white;
    final border  = dark ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0);
    final text    = dark ? Colors.white : const Color(0xFF0F172A);
    final sub     = dark ? const Color(0xFFB0B3C1) : const Color(0xFF6B7280);

    return ColoredBox(
      color: outerBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Hero Fintech ──────────────────────────────────────────────────
          _buildFintechHeroMobile(dark),
          const SizedBox(height: 16),
          // ── KPI: scroll horizontal 2 cards visibles ───────────────────────
          _buildKpiScrollMovil(dark),
          const SizedBox(height: 16),
          // ── Acciones rápidas: pills horizontales ───────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildAccionesRapidasPills(dark),
          ),
          const SizedBox(height: 16),
          // ── Módulos: compact en móvil, cards en desktop ────────────────────
          LayoutBuilder(builder: (_, cons) => cons.maxWidth >= 600
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildModulesGridDesktop(dark))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildModulosMovil(dark))),
          const SizedBox(height: 16),
          // ── Actividad de hoy ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildActividadRecienteMovil(dark, cardBg, border, text, sub),
          ),
        ]),
      ),
    );
  }

  Widget _buildFintechHeroMobile(bool dark) {
    final hour = DateTime.now().hour;
    final saludo = hour < 12 ? 'Buenos días' : hour < 19 ? 'Buenas tardes' : 'Buenas noches';
    final emoji  = hour < 12 ? '☀️' : hour < 19 ? '🌤️' : '🌙';
    final primerNombre = _obtenerPrimerNombre(_nombreUsuario);
    final inicial = primerNombre.isNotEmpty ? primerNombre[0].toUpperCase() : 'U';
    final empresaLabel = _nombreEmpresa.isNotEmpty ? _nombreEmpresa : 'Mi empresa';
    final fecha = _formatearFechaHoy();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
              : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Fila superior: avatar + nombre + fecha
        Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(inicial, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$saludo $emoji', style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75), fontSize: 11.5, fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(primerNombre, style: const TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Text(fecha, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9), fontSize: 10.5, fontWeight: FontWeight.w500)),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        // Badge de empresa
        GestureDetector(
          onTap: _mostrarSelectorEmpresa,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.business_rounded, size: 12, color: Colors.white.withValues(alpha: 0.85)),
              const SizedBox(width: 6),
              Flexible(child: Text(empresaLabel,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95), fontSize: 12, fontWeight: FontWeight.w600))),
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Colors.white.withValues(alpha: 0.7)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildKpiScrollMovil(bool dark) {
    if (_empresaId == null) return const SizedBox.shrink();
    final kpisAll = [
      (Icons.receipt_long_rounded,  const Color(0xFF3B82F6), 'Facturas',   _streamFacturasPendientes(),   (int n) => n == 0 ? 'Al día' : 'pendientes',   false),
      (Icons.people_alt_rounded,    const Color(0xFF10B981), 'Clientes',   _streamTotalClientes(),        (int n) => 'activos',                           false),
      (Icons.inventory_2_rounded,   const Color(0xFFF59E0B), 'Pedidos',    _streamPedidosActivos(),       (int n) => 'en proceso',                        false),
      (Icons.task_alt_rounded,      const Color(0xFF8B5CF6), 'Tareas',     _streamTareasPendientes(),     (int n) => n == 1 ? 'pendiente' : 'pendientes', true),
      (Icons.badge_rounded,         const Color(0xFF6366F1), 'Empleados',  _streamEmpleadosActivos(),     (int n) => 'en plantilla',                      true),
      (Icons.calendar_month_rounded,const Color(0xFF14B8A6), 'Reservas',   _streamReservasHoy(),          (int n) => n == 0 ? 'Sin reservas' : 'hoy',     true),
    ];
    final kpis = kpisAll.where((k) => !(_esNazari && k.$6)).toList();
    final cardBg = dark ? const Color(0xFF1E2139) : Colors.white;
    return SizedBox(
      height: 108,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemCount: kpis.length,
        itemBuilder: (_, i) {
          final k = kpis[i];
          return StreamBuilder<int>(
            stream: k.$4,
            builder: (_, snap) {
              final n = snap.data ?? 0;
              return Container(
                width: 128,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: k.$2, width: 3)),
                  boxShadow: dark ? [] : [BoxShadow(
                    color: k.$2.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(k.$1, size: 18, color: k.$2),
                  const Spacer(),
                  Text('$n', style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : const Color(0xFF0F172A), height: 1)),
                  const SizedBox(height: 3),
                  Text(k.$3, style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: dark ? const Color(0xFF9CA3AF) : const Color(0xFF374151))),
                  Text(k.$5(n), style: TextStyle(fontSize: 10, color: k.$2, fontWeight: FontWeight.w500)),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAccionesRapidasPills(bool dark) {
    final accionesAll = [
      (Icons.receipt_long_rounded, const Color(0xFF3B82F6), 'Nueva factura',  'facturacion', false),
      (Icons.person_add_rounded,   const Color(0xFF10B981), 'Nuevo cliente',  'clientes',    false),
      (Icons.task_alt_rounded,     const Color(0xFF8B5CF6), 'Nueva tarea',    'tareas',      true),
      (Icons.inventory_2_rounded,  const Color(0xFFF59E0B), 'Nuevo pedido',   'pedidos',     false),
    ];
    final acciones = accionesAll.where((a) => !(_esNazari && a.$5)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Acciones rápidas', style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w700,
        color: dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A))),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: acciones.map((a) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => _abrirModulo(a.$4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: a.$2.withValues(alpha: dark ? 0.16 : 0.10),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: a.$2.withValues(alpha: 0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(a.$1, size: 14, color: a.$2),
                const SizedBox(width: 6),
                Text(a.$3, style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: a.$2)),
              ]),
            ),
          ),
        )).toList()),
      ),
    ]);
  }

  // ── Acciones rápidas móvil: 4 botones en fila horizontal ──────────────────
  Widget _buildAccionesRapidasMovil(bool dark, Color cardBg, Color border, Color text, Color sub) {
    final acciones = [
      (Icons.receipt_long_rounded, const Color(0xFF10B981), 'Factura',    'facturacion'),
      (Icons.people_alt_rounded,   const Color(0xFF3B82F6), 'Cliente',    'clientes'),
      (Icons.task_alt_rounded,     const Color(0xFF8B5CF6), 'Tarea',      'tareas'),
      (Icons.inventory_2_rounded,  const Color(0xFFF59E0B), 'Pedido',     'pedidos'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bolt_rounded, size: 13, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 5),
          Text('Acciones rápidas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text)),
        ]),
        const SizedBox(height: 12),
        Row(
          children: acciones.map((a) => Expanded(
            child: GestureDetector(
              onTap: () => _abrirModulo(a.$4),
              child: Column(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: a.$2.withValues(alpha: dark ? 0.14 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: a.$2.withValues(alpha: 0.2)),
                  ),
                  child: Icon(a.$1, size: 20, color: a.$2),
                ),
                const SizedBox(height: 5),
                Text(a.$3, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: a.$2)),
              ]),
            ),
          )).toList(),
        ),
      ]),
    );
  }

  // ── Módulos móvil: grid de 4 columnas, ancho completo ─────────────────────
  Widget _buildModulosMovil(bool dark) {
    final text = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub  = dark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);
    final mainTiles = _tilesPermitidos.take(8).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Módulos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _paginaHome = 1),
          child: const Text('Ver todos',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
        ),
      ]),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.9,
        ),
        itemCount: mainTiles.length,
        itemBuilder: (_, i) {
          final t = mainTiles[i];
          return GestureDetector(
            onTap: () => t.id == 'carpeta' ? _mostrarCarpeta(dark) : _abrirModulo(t.id),
            child: Container(
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1E2139) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dark ? const Color(0xFF2A2E45) : const Color(0xFFE8EAEE)),
                boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: dark ? 0.14 : 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(t.icon, color: t.accent, size: 18),
                ),
                const SizedBox(height: 5),
                Text(t.label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: sub),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          );
        },
      ),
    ]);
  }

  // ── Actividad reciente móvil (ancho completo, compacto) ───────────────────
  Widget _buildActividadRecienteMovil(bool dark, Color cardBg, Color border, Color text, Color sub) {
    if (_empresaId == null) return const SizedBox.shrink();
    final eid   = _empresaId!;
    final ahora = DateTime.now();
    final tsInicio = Timestamp.fromDate(DateTime(ahora.year, ahora.month, ahora.day));
    final tsFin    = Timestamp.fromDate(DateTime(ahora.year, ahora.month, ahora.day + 1));
    return Container(
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: Color(0xFF14B8A6), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Actividad de hoy', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: text)),
        ]),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('empresas').doc(eid)
              .collection('facturas')
              .where('fecha_creacion', isGreaterThanOrEqualTo: tsInicio)
              .where('fecha_creacion', isLessThan: tsFin)
              .orderBy('fecha_creacion', descending: true).limit(4).snapshots(),
          builder: (_, fSnap) => StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('empresas').doc(eid)
                .collection('tareas')
                .where('fecha_creacion', isGreaterThanOrEqualTo: tsInicio)
                .where('fecha_creacion', isLessThan: tsFin)
                .orderBy('fecha_creacion', descending: true).limit(4).snapshots(),
            builder: (_, tSnap) => StreamBuilder<QuerySnapshot>(
              // Nuevos clientes hoy
              stream: FirebaseFirestore.instance.collection('empresas').doc(eid)
                  .collection('clientes')
                  .where('fecha_registro', isGreaterThanOrEqualTo: tsInicio)
                  .where('fecha_registro', isLessThan: tsFin)
                  .orderBy('fecha_registro', descending: true).limit(4).snapshots(),
              builder: (_, cSnap) => StreamBuilder<QuerySnapshot>(
                // Reservas de hoy
                stream: FirebaseFirestore.instance.collection('empresas').doc(eid)
                    .collection('reservas')
                    .where('creado_en', isGreaterThanOrEqualTo: tsInicio)
                    .where('creado_en', isLessThan: tsFin)
                    .orderBy('creado_en', descending: true).limit(4).snapshots(),
                builder: (_, rSnap) {
                  // (icono, color, desc, tiempo, ts real)
                  final items = <(IconData, Color, String, String, DateTime)>[];
                  for (final doc in fSnap.data?.docs ?? []) {
                    final d = doc.data() as Map;
                    final num = d['numero'] as String? ?? '';
                    final cli = d['cliente_nombre'] as String? ?? '';
                    final ts  = (d['fecha_creacion'] as Timestamp?)?.toDate() ?? ahora;
                    items.add((Icons.receipt_long_rounded, const Color(0xFF3B82F6),
                        num.isNotEmpty
                            ? 'Factura $num${cli.isNotEmpty ? ' · $cli' : ''}'
                            : cli.isNotEmpty ? 'Factura · $cli' : 'Factura emitida',
                        _tiempoRelativo(ts), ts));
                  }
                  for (final doc in tSnap.data?.docs ?? []) {
                    final d = doc.data() as Map;
                    final ts  = (d['fecha_creacion'] as Timestamp?)?.toDate() ?? ahora;
                    items.add((Icons.task_alt_rounded, const Color(0xFF8B5CF6),
                        d['titulo'] as String? ?? 'Tarea', _tiempoRelativo(ts), ts));
                  }
                  for (final doc in cSnap.data?.docs ?? []) {
                    final d = doc.data() as Map;
                    final nombre = d['nombre'] as String? ?? 'Sin nombre';
                    final ts = (d['fecha_registro'] as Timestamp?)?.toDate() ?? ahora;
                    items.add((Icons.person_add_alt_1_rounded, const Color(0xFF10B981),
                        'Nuevo cliente: $nombre', _tiempoRelativo(ts), ts));
                  }
                  for (final doc in rSnap.data?.docs ?? []) {
                    final d = doc.data() as Map;
                    final cli  = d['nombre'] as String? ?? d['cliente'] as String? ?? '';
                    final hora = d['hora'] as String? ?? '';
                    final ts   = (d['creado_en'] as Timestamp?)?.toDate() ?? ahora;
                    items.add((Icons.event_available_outlined, const Color(0xFF8B5CF6),
                        cli.isNotEmpty
                            ? 'Reserva: $cli${hora.isNotEmpty ? ' · $hora' : ''}'
                            : 'Nueva reserva',
                        _tiempoRelativo(ts), ts));
                  }

                  if (items.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Column(children: [
                        Icon(Icons.history_rounded, size: 28, color: sub.withValues(alpha: 0.3)),
                        const SizedBox(height: 6),
                        Text('Sin actividad hoy', style: TextStyle(fontSize: 12, color: sub)),
                      ])),
                    );
                  }
                  items.sort((a, b) => b.$5.compareTo(a.$5));
                  return Column(
                    children: items.take(6).map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Container(width: 32, height: 32,
                            decoration: BoxDecoration(
                                color: e.$2.withValues(alpha: 0.10), shape: BoxShape.circle),
                            child: Icon(e.$1, color: e.$2, size: 15)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.$3, style: TextStyle(fontSize: 12.5,
                              fontWeight: FontWeight.w500, color: text),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (e.$4.isNotEmpty)
                            Text(e.$4, style: TextStyle(fontSize: 10.5, color: sub)),
                        ])),
                      ]),
                    )).toList(),
                  );
                },
              ),
            ),
          ),
        ),
      ]),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('¡$saludo, $primerNombre! $emoji',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: text),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text('Resumen de tu negocio.',
            style: TextStyle(fontSize: 12, color: sub)),
      ]),
    );
  }

  String _formatearFechaHoy() => _formatearFecha(DateTime.now());

  String _formatearFecha(DateTime dt) {
    const meses = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final now = DateTime.now();
    final esHoy = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final esAyer = dt.year == now.year && dt.month == now.month && dt.day == now.day - 1;
    if (esHoy)  return 'Hoy, ${dt.day} ${meses[dt.month - 1]} ${dt.year}';
    if (esAyer) return 'Ayer, ${dt.day} ${meses[dt.month - 1]} ${dt.year}';
    return '${dt.day} ${meses[dt.month - 1]} ${dt.year}';
  }

  Widget _buildKpiGrid(bool dark) {
    if (_empresaId == null) return const SizedBox.shrink();
    final kpiChildren = [
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
      _buildKpiCardStream(dark: dark, titulo: 'Tareas',
          stream: _streamTareasPendientes(),
          subtituloFn: (n) => n == 1 ? 'pendiente' : 'pendientes',
          icono: Icons.task_alt_rounded, color: const Color(0xFF8B5CF6)),
      _buildKpiCardStream(dark: dark, titulo: 'Empleados',
          stream: _streamEmpleadosActivos(),
          subtituloFn: (_) => 'en plantilla',
          icono: Icons.badge_rounded, color: const Color(0xFF6366F1)),
      _buildKpiCardStream(dark: dark, titulo: 'Reservas hoy',
          stream: _streamReservasHoy(),
          subtituloFn: (n) => n == 0 ? 'Sin reservas' : 'confirmadas',
          icono: Icons.calendar_month_rounded, color: const Color(0xFF14B8A6)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(builder: (_, constraints) {
        // Cada celda necesita ~110px de alto para el contenido compacto
        const cols        = 3;
        const spacing     = 8.0;
        final cellW       = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        const minCellH    = 110.0;
        final ratio       = (cellW / minCellH).clamp(0.75, 1.5);

        return GridView.count(
          crossAxisCount: cols,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: ratio,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: kpiChildren,
        );
      }),
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
        const SizedBox(width: 12),
        Expanded(child: _buildKpiCardStream(dark: dark, titulo: 'Empleados',
            stream: _streamEmpleadosActivos(), subtituloFn: (_) => 'en plantilla',
            icono: Icons.badge_rounded, color: const Color(0xFF6366F1))),
        const SizedBox(width: 12),
        Expanded(child: _buildKpiCardStream(dark: dark, titulo: 'Reservas hoy',
            stream: _streamReservasHoy(), subtituloFn: (n) => n == 0 ? 'Sin reservas' : 'confirmadas',
            icono: Icons.calendar_month_rounded, color: const Color(0xFF14B8A6))),
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
          padding: const EdgeInsets.all(10),
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
              Container(width: 28, height: 28,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: dark ? 0.14 : 0.10),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icono, color: color, size: 14)),
              const SizedBox(height: 6),
              Text('$n', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: numColor, height: 1)),
              const SizedBox(height: 3),
              Text(titulo, style: TextStyle(fontSize: 10, color: subColor, height: 1.2),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(subtituloFn(n),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
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
        .where('estado', whereIn: ['pendiente', 'enProgreso', 'enRevision'])
        .snapshots().map((s) => s.size);
  }

  Stream<int> _streamEmpleadosActivos() {
    if (_empresaId == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('empresas').doc(_empresaId).collection('empleados')
        .where('activo', isEqualTo: true)
        .snapshots().map((s) => s.size);
  }

  Stream<int> _streamReservasHoy() {
    if (_empresaId == null) return const Stream.empty();
    final hoy = DateTime.now();
    final inicio = Timestamp.fromDate(DateTime(hoy.year, hoy.month, hoy.day));
    final fin    = Timestamp.fromDate(DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59));
    return FirebaseFirestore.instance
        .collection('empresas').doc(_empresaId).collection('reservas')
        .where('fecha', isGreaterThanOrEqualTo: inicio)
        .where('fecha', isLessThanOrEqualTo: fin)
        .where('estado', whereIn: ['confirmada', 'pendiente'])
        .snapshots().map((s) => s.size);
  }

  Widget _buildModuleShortcutSection(bool dark) {
    final text    = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final subText = dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final mainTiles = _tilesPermitidos.take(8).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Módulos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _paginaHome = 1),
          child: const Text('Ver todos',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
        ),
      ]),
      const SizedBox(height: 12),
      // Cuadrícula 2×4 de módulos (sin scroll horizontal) para ocupar el ancho del flex
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.1,
        ),
        itemCount: mainTiles.length,
        itemBuilder: (ctx, i) {
          final t = mainTiles[i];
          return GestureDetector(
            onTap: () => t.id == 'carpeta' ? _mostrarCarpeta(dark) : _abrirModulo(t.id),
            child: Container(
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1E2139) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dark ? const Color(0xFF2A2E45) : const Color(0xFFE8EAEE)),
                boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(t.icon, color: t.accent, size: 22),
                const SizedBox(height: 5),
                Text(t.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subText),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          );
        },
      ),
    ]);
  }

  // ── Actividad reciente compacta (panel derecho del home) ──────────────────

  Widget _buildActividadRecienteCompact(bool dark, Color cardBg, Color border, Color text, Color sub) {
    if (_empresaId == null) return const SizedBox.shrink();
    final eid = _empresaId!;
    final tsInicio = Timestamp.fromDate(DateTime(_fechaFiltro.year, _fechaFiltro.month, _fechaFiltro.day));
    final tsFin    = Timestamp.fromDate(DateTime(_fechaFiltro.year, _fechaFiltro.month, _fechaFiltro.day + 1));
    return Container(
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border),
        boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.timeline_rounded, size: 13, color: const Color(0xFF14B8A6)),
          const SizedBox(width: 5),
          Expanded(child: Text('Actividad', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text))),
        ]),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('empresas').doc(eid)
              .collection('facturas')
              .where('fecha_creacion', isGreaterThanOrEqualTo: tsInicio)
              .where('fecha_creacion', isLessThan: tsFin)
              .orderBy('fecha_creacion', descending: true).limit(3).snapshots(),
          builder: (_, fSnap) => StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('empresas').doc(eid)
                .collection('tareas')
                .where('fecha_creacion', isGreaterThanOrEqualTo: tsInicio)
                .where('fecha_creacion', isLessThan: tsFin)
                .orderBy('fecha_creacion', descending: true).limit(3).snapshots(),
            builder: (_, tSnap) {
              final items = <(IconData, Color, String)>[];
              for (final doc in fSnap.data?.docs ?? []) {
                final d = doc.data() as Map;
                final num = d['numero'] as String? ?? '';
                items.add((Icons.receipt_long_rounded, const Color(0xFF3B82F6), num.isNotEmpty ? 'Factura $num' : 'Factura'));
              }
              for (final doc in tSnap.data?.docs ?? []) {
                final d = doc.data() as Map;
                final tit = d['titulo'] as String? ?? 'Tarea';
                items.add((Icons.task_alt_rounded, const Color(0xFF8B5CF6), tit));
              }
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sin actividad hoy', style: TextStyle(fontSize: 11, color: sub), textAlign: TextAlign.center),
                );
              }
              return Column(children: items.take(4).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Icon(e.$1, size: 12, color: e.$2),
                  const SizedBox(width: 6),
                  Expanded(child: Text(e.$3, style: TextStyle(fontSize: 11, color: text),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              )).toList());
            },
          ),
        ),
      ]),
    );
  }

  // ── Acciones rápidas compactas (panel derecho del home) ───────────────────

  Widget _buildAccionesRapidasCompact(bool dark, Color cardBg, Color border, Color text, Color sub) {
    final accent = const Color(0xFF3B82F6);
    final acciones = [
      (Icons.receipt_long_rounded,   const Color(0xFF10B981), 'Factura',   'facturacion'),
      (Icons.people_alt_rounded,     const Color(0xFF3B82F6), 'Cliente',   'clientes'),
      (Icons.task_alt_rounded,       const Color(0xFF8B5CF6), 'Tarea',     'tareas'),
      (Icons.inventory_2_rounded,    const Color(0xFFF59E0B), 'Pedido',    'pedidos'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: border),
        boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bolt_rounded, size: 13, color: accent),
          const SizedBox(width: 5),
          Text('Acciones', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text)),
        ]),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.8,
          children: acciones.map((a) => GestureDetector(
            onTap: () => _abrirModulo(a.$4),
            child: Container(
              decoration: BoxDecoration(
                color: a.$2.withValues(alpha: dark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: a.$2.withValues(alpha: 0.2)),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(a.$1, size: 14, color: a.$2),
                const SizedBox(height: 2),
                Text(a.$3, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: a.$2)),
              ]),
            ),
          )).toList(),
        ),
      ]),
    );
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
            _bottomNavItem(Icons.person_outline_rounded, 'Perfil', 4, selected, unselected, dark),
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
          Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaPerfil(sesion: _sesion, dark: _darkMode)));
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
    final w = size.width;

    // Sistema de 3 modos progresivos para el sidebar:
    //   full    (≥ 1100px) → 240px con etiquetas completas
    //   compact (760–1099px) → 80px con icono + etiqueta corta debajo
    //   rail    (640–759px)  → 56px con iconos y tooltip
    final sidebarMode = w >= 1100
        ? _SidebarMode.full
        : w >= 760
            ? _SidebarMode.compact
            : _SidebarMode.rail;

    final showRightPanel = sidebarMode == _SidebarMode.full && _moduloDesktopActivo == null;
    final rightPanelWidth = w >= 1380 ? 300.0 : 260.0;
    final border = dark ? Colors.white12 : Colors.grey.shade200;

    // Sidebar a la izquierda, de arriba a abajo. Header + contenido a la derecha.
    return Row(children: [
      _buildDesktopSidebar(dark, mode: sidebarMode),
      Expanded(child: Column(children: [
        if (_empresaId != null)
          BannerSuscripcion(
              empresaId: _empresaId!, esPropietario: _sesion?.esPropietario ?? false),
        if (_sesion?.esPropietario == true && _rolVistaActual != null) _buildSimulacionBanner(),
        _buildDesktopModuloHeader(_moduloDesktopActivo ?? '', dark),
        Divider(height: 1, color: border),
        Expanded(child: Row(children: [
          Expanded(child: _buildDesktopContent(dark)),
          if (showRightPanel)
            SizedBox(width: rightPanelWidth, child: _buildDesktopRightPanel(dark)),
        ])),
      ])),
    ]);
  }

  // ── Popup de notificaciones ────────────────────────────────────────────────

  void _mostrarNotificacionesPopup(BuildContext context, bool dark) {
    if (_empresaId == null) return;
    final eid = _empresaId!;
    final svc = BandejaNotificacionesService();
    final cardBg = dark ? const Color(0xFF1E2139) : Colors.white;
    final bg     = dark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final border = dark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    final text   = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub    = dark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    showGeneralDialog(
      context: context,
      barrierLabel: 'Notificaciones',
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (ctx, anim, _) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        return Stack(children: [
          // Tap fuera → cerrar
          Positioned.fill(child: GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: const ColoredBox(color: Colors.transparent),
          )),
          // Panel en la esquina superior derecha
          Positioned(
            top: 50, right: 16,
            child: FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, -0.05), end: Offset.zero)
                    .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: Material(
                  elevation: 16,
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: (MediaQuery.of(context).size.width - 32).clamp(280.0, 380.0),
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // Header del popup
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: border)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.notifications_rounded, size: 16, color: Color(0xFF7C3AED)),
                          ),
                          const SizedBox(width: 10),
                          Text('Notificaciones',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text)),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              svc.marcarTodasLeidas(eid);
                              Navigator.pop(ctx);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              foregroundColor: const Color(0xFF7C3AED),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            child: const Text('Marcar leídas'),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => BandejaNotificacionesScreen(empresaId: eid)));
                            },
                            icon: Icon(Icons.open_in_new_rounded, size: 16, color: sub),
                            tooltip: 'Ver todas',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ]),
                      ),
                      // Lista de notificaciones
                      Flexible(
                        child: StreamBuilder<List<NotificacionInApp>>(
                          stream: svc.notificacionesStream(eid),
                          builder: (_, snap) {
                            final items = snap.data ?? [];
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            }
                            if (items.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32),
                                child: Column(children: [
                                  Icon(Icons.notifications_none_outlined, size: 40, color: sub.withValues(alpha: 0.4)),
                                  const SizedBox(height: 8),
                                  Text('Sin notificaciones', style: TextStyle(fontSize: 13, color: sub)),
                                ]),
                              );
                            }
                            final noLeidas = items.where((n) => !n.leida).toList();
                            final leidas = items.where((n) => n.leida).take(5).toList();
                            final allShown = [...noLeidas, ...leidas];
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shrinkWrap: true,
                              itemCount: allShown.length,
                              itemBuilder: (_, i) {
                                final n = allShown[i];
                                return _buildNotifPopupItem(ctx, n, eid, svc, dark, cardBg, bg, border, text, sub);
                              },
                            );
                          },
                        ),
                      ),
                      // Footer
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(top: BorderSide(color: border)),
                          color: bg,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => BandejaNotificacionesScreen(empresaId: eid)));
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF7C3AED),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            child: const Text('Ver todas las notificaciones →'),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildNotifPopupItem(
    BuildContext ctx,
    NotificacionInApp n,
    String eid,
    BandejaNotificacionesService svc,
    bool dark, Color cardBg, Color bg, Color border, Color text, Color sub,
  ) {
    final unread = !n.leida;
    final tipoColors = {
      'tareas':      const Color(0xFF8B5CF6),
      'facturacion': const Color(0xFF3B82F6),
      'reservas':    const Color(0xFF10B981),
      'citas':       const Color(0xFF10B981),
      'pedidos':     const Color(0xFFF59E0B),
      'empleados':   const Color(0xFF6366F1),
      'fiscal':      const Color(0xFFEF4444),
      'nominas':     const Color(0xFF14B8A6),
      'fichajes':    const Color(0xFF0EA5E9),
    };
    final color = tipoColors[n.moduloDestino] ?? const Color(0xFF7C3AED);

    return GestureDetector(
      onTap: () async {
        await svc.marcarLeida(eid, n.id);
        if (!ctx.mounted) return;
        Navigator.pop(ctx);
        _navegarAModuloDesdePopup(n, eid);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: unread ? color.withValues(alpha: dark ? 0.08 : 0.05) : bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: unread ? color.withValues(alpha: 0.2) : border),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: dark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(child: Text(n.tipo.emoji, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.titulo,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5, fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                  color: text,
                )),
            if (n.cuerpo.isNotEmpty)
              Text(n.cuerpo,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: sub)),
          ])),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(_tiempoRelativo(n.timestamp), style: TextStyle(fontSize: 9.5, color: sub)),
            if (unread) ...[
              const SizedBox(height: 4),
              Container(width: 7, height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ],
          ]),
        ]),
      ),
    );
  }

  String _tiempoRelativo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Ahora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24)   return '${diff.inHours}h';
    if (diff.inDays == 1)    return 'Ayer';
    return '${diff.inDays}d';
  }

  void _navegarAModuloDesdePopup(NotificacionInApp n, String eid) {
    _navegarAModuloDesktopOMovil(n, eid);
  }

  void _navegarAModuloDesktopOMovil(NotificacionInApp n, String eid) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    if (isDesktop) {
      // En desktop: abrir inline
      final moduloMap = {
        'tareas': 'tareas', 'facturacion': 'facturacion', 'reservas': 'reservas',
        'citas': 'reservas', 'pedidos': 'pedidos', 'empleados': 'personal',
        'fichajes': 'fichaje', 'nominas': 'mas', 'fiscal': 'facturacion',
        'clientes': 'clientes',
      };
      final modulo = moduloMap[n.moduloDestino];
      if (modulo != null) setState(() => _moduloDesktopActivo = modulo);
    } else {
      // En móvil: push de pantalla
      _navegarAModuloDesdeNotificacion(n, eid);
    }
  }

  void _navegarAModuloDesdeNotificacion(NotificacionInApp n, String eid) {
    if (_empresaId == null) return;
    switch (n.moduloDestino) {
      case 'tareas':      _abrirModulo('tareas'); break;
      case 'facturacion':
      case 'fiscal':      _abrirModulo('facturacion'); break;
      case 'reservas':
      case 'citas':       _abrirModulo('reservas'); break;
      case 'pedidos':     _abrirModulo('pedidos'); break;
      case 'empleados':   _abrirModulo('personal'); break;
      case 'fichajes':    _abrirModulo('fichaje'); break;
      case 'clientes':    _abrirModulo('clientes'); break;
      default: break;
    }
  }

  Widget _buildDesktopSidebar(bool dark, {_SidebarMode mode = _SidebarMode.full}) {
    // El TPV puede colapsar manualmente el sidebar a iconos (rail).
    final efectivoCollapsado = _sidebarEfectivoCollapsado;
    final collapsed = (mode == _SidebarMode.rail) || efectivoCollapsado;
    final isCompact = mode == _SidebarMode.compact && !efectivoCollapsado;

    // Ancho animado según modo
    final double sidebarWidth = efectivoCollapsado
        ? 56
        : mode == _SidebarMode.full
            ? 240
            : mode == _SidebarMode.compact
                ? 80
                : 56;

    final bg     = dark ? const Color(0xFF111827) : Colors.white;
    final border = dark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200;
    final text   = dark ? const Color(0xFFE2E8F0) : const Color(0xFF374151);
    final sub    = dark ? const Color(0xFF6B7280) : Colors.grey.shade500;
    final _planModulos = _suscripcionService.getModulosActivos();
    final _sesEf = _sesionEfectiva;
    final _propEf = _sesEf?.esPropietarioPlatforma == true && _rolVistaActual == null;
    bool _enPlan(String id) {
      if (_propEf) return true;
      const _al = <String,String>{'personal':'empleados','web':'contenido_web'};
      final pid = _al[id] ?? id;
      return _planModulos.contains(pid) || _planModulos.contains(id);
    }
    final navItems = [
      _SidebarItem(Icons.home_rounded, 'Inicio', null),
      if (_enPlan('dashboard'))                      _SidebarItem(Icons.dashboard_rounded,       'Dashboard',     'dashboard'),
      if (_enPlan('facturacion'))                    _SidebarItem(Icons.receipt_long_rounded,    'Facturación',   'facturacion'),
      if (_enPlan('clientes'))                       _SidebarItem(Icons.people_alt_rounded,      'Clientes',      'clientes'),
      if (_enPlan('pedidos'))                        _SidebarItem(Icons.inventory_2_rounded,     'Pedidos',       'pedidos'),
      if (_enPlan('tpv'))                            _SidebarItem(Icons.point_of_sale_rounded,   'TPV',           'tpv'),
      if (_enPlan('tareas') && !_esNazari)           _SidebarItem(Icons.task_alt_rounded,        'Tareas',        'tareas'),
      if (_enPlan('personal') && !_esNazari)         _SidebarItem(Icons.badge_rounded,           'Personal',      'personal'),
      if (_enPlan('web'))                            _SidebarItem(Icons.language_rounded,        'Web',           'web'),
      // Nazarí: acceso directo a Plantillas PDF en lugar del menú "Más módulos"
      if (_esNazari)                                 _SidebarItem(Icons.picture_as_pdf_rounded,  'Plantillas PDF','plantillas_pdf'),
      if (!_esNazari)                                _SidebarItem(Icons.apps_rounded,            'Más módulos',   'carpeta'),
    ];
    final bottomItems = [
      _SidebarItem(Icons.person_rounded, 'Mi perfil', 'perfil'),
      _SidebarItem(Icons.support_agent_rounded, 'Soporte', 'soporte'),
      _SidebarItem(Icons.settings_rounded, 'Configuración', null),
      if (_sesion?.esPropietarioPlatforma == true)
        _SidebarItem(Icons.account_tree_rounded, 'Grafo App', 'grafo_app'),
    ];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      decoration: BoxDecoration(
          color: bg, border: Border(right: BorderSide(color: border))),
      child: Column(children: [
        // ── Logo + botón colapsar ─────────────────────────────────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            (collapsed || isCompact) ? 0 : 20, 18,
            (collapsed || isCompact) ? 0 : 12, 12,
          ),
          child: (collapsed || isCompact)
              ? Column(children: [
                  Container(width: 32, height: 32,
                      decoration: BoxDecoration(color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18)),
                  const SizedBox(height: 8),
                  // Botón expandir solo si el modo full está disponible (no en rail forzado por ancho)
                  if (efectivoCollapsado)
                    Tooltip(
                      message: 'Expandir menú',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => setState(() => _sidebarCollapsado = false),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.chevron_right, size: 16, color: sub),
                        ),
                      ),
                    ),
                ])
              : Row(children: [
                  Container(width: 32, height: 32,
                      decoration: BoxDecoration(color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18)),
                  const SizedBox(width: 10),
                  Text('Fluix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                      color: text, letterSpacing: -0.3)),
                  const Spacer(),
                  if (_moduloDesktopActivo == 'tpv')
                    Tooltip(
                      message: 'Colapsar menú',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => setState(() => _sidebarCollapsado = true),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(Icons.chevron_left, size: 16, color: sub),
                        ),
                      ),
                    ),
                ]),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: (collapsed || isCompact) ? 4 : 12,
              vertical: 4,
            ),
            children: navItems.map((item) {
              final isSelected = (item.label == 'Inicio' && _moduloDesktopActivo == null) ||
                  (item.moduloId != null && _moduloDesktopActivo == item.moduloId);
              return _buildSidebarNavItem(item, isSelected, dark, text, sub,
                  collapsed: collapsed, compact: isCompact);
            }).toList(),
          ),
        ),
        // ── Selector de rol (solo full, propietario) ──────────────────────
        if (_sesion?.esPropietario == true && !collapsed && !isCompact)
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
          padding: EdgeInsets.all((collapsed || isCompact) ? 4 : 16),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
          child: Column(children: bottomItems.map((item) =>
              _buildSidebarNavItem(item, false, dark, text, sub,
                  collapsed: collapsed, compact: isCompact)).toList()),
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

  Widget _buildSidebarNavItem(
    _SidebarItem item, bool isSelected, bool dark, Color text, Color sub, {
    bool collapsed = false,
    bool compact   = false,
  }) {
    final selBg   = const Color(0xFF3B82F6).withValues(alpha: dark ? 0.15 : 0.08);
    final selText = const Color(0xFF3B82F6);
    void onTap() {
      if (item.moduloId == null) {
        setState(() => _moduloDesktopActivo = null);
      } else if (item.moduloId == 'carpeta') {
        setState(() => _moduloDesktopActivo = 'mas');
      } else if (item.moduloId == 'perfil') {
        setState(() => _moduloDesktopActivo = 'perfil');
      } else {
        _abrirModulo(item.moduloId!);
      }
    }

    // Modo rail: solo icono + tooltip
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Tooltip(
          message: item.label,
          preferBelow: false,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                  color: isSelected ? selBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Icon(item.icon, size: 20, color: isSelected ? selText : sub),
              ),
            ),
          ),
        ),
      );
    }

    // Modo compact: icono centrado + etiqueta corta debajo (80px de ancho)
    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Tooltip(
          message: item.label,
          preferBelow: false,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                  color: isSelected ? selBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(8)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(item.icon, size: 19, color: isSelected ? selText : sub),
                const SizedBox(height: 3),
                Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? selText : sub,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ]),
            ),
          ),
        ),
      );
    }

    // Modo full: icono + etiqueta en filaR
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
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
    final bg      = dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardBg  = dark ? const Color(0xFF1E2139) : Colors.white;
    final border  = dark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;
    final text    = dark ? const Color(0xFFE2E8F0) : const Color(0xFF1F2937);
    final sub     = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    return switch (_moduloDesktopActivo) {
      // Home: misma pantalla Fintech que en móvil (KPIs, pills, módulos)
      null         => _buildHomeScreen(dark),
      'dashboard'  => _buildDashboardHome(dark),
      'personal'   => _buildPersonalSection(dark),
      'perfil'     => PantallaPerfil(sesion: _sesion, embedded: true, dark: dark,
                        onAbrirCuentas: () => setState(() => _moduloDesktopActivo = 'cuentas')),
      'mas'        => _buildMasModulosSection(dark),
      _            => _empresaId != null
                        ? _buildContenidoModulo(_moduloDesktopActivo!)
                        : const Center(child: Text('Sin empresa')),
    };
  }

  Widget _buildDesktopModuloHeader(String moduloId, bool dark) {
    final bg   = dark ? const Color(0xFF111827) : Colors.white;
    final text = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub  = dark ? Colors.white54 : const Color(0xFF94A3B8);
    final primerNombre = _obtenerPrimerNombre(_nombreUsuario);
    final inicial = primerNombre.isNotEmpty ? primerNombre[0].toUpperCase() : 'U';
    final empresaLabel = _nombreEmpresa.isNotEmpty ? _nombreEmpresa : 'Mi empresa';

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        // ── Breadcrumb / Título ───────────────────────────────────────────
        if (moduloId.isEmpty) ...[
          Icon(Icons.home_rounded, size: 16, color: const Color(0xFF7C3AED)),
          const SizedBox(width: 8),
          Text('Inicio', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
        ] else ...[
          // ← Inicio (siempre va al hub principal)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() {
              _webSubModulo = null;
              _moduloDesktopActivo = null;
              _webVolverAlHub.value++;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.arrow_back_rounded, size: 15, color: sub),
                const SizedBox(width: 5),
                Text('INICIO', style: TextStyle(fontSize: 12, color: sub, letterSpacing: 0.4)),
              ]),
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 14, color: sub),
          const SizedBox(width: 4),
          // Módulo actual
          if (_webSubModulo != null && moduloId == 'web') ...[
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                setState(() => _webSubModulo = null);
                _webVolverAlHub.value++;
              },
              child: Text('WEB',
                  style: TextStyle(fontSize: 12, color: sub, letterSpacing: 0.4)),
            ),
            Icon(Icons.chevron_right_rounded, size: 14, color: sub),
            const SizedBox(width: 4),
            Text(_webSubModuloNombre(_webSubModulo!).toUpperCase(),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                    color: text, letterSpacing: 0.3)),
          ] else
            Flexible(
              child: Text(_nombreModulo(moduloId).toUpperCase(),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                      color: text, letterSpacing: 0.3),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ),
        ],
        const SizedBox(width: 12),

        // ── Buscador global (compacto, siempre visible) ───────────────────
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: GestureDetector(
            onTap: _abrirBusquedaGlobal,
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: dark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: dark ? Colors.white12 : const Color(0xFFE2E8F0)),
              ),
              child: Row(children: [
                const SizedBox(width: 8),
                Icon(Icons.search_rounded, size: 13, color: sub),
                const SizedBox(width: 6),
                Expanded(child: Text('Buscar...', style: TextStyle(fontSize: 11, color: sub))),
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: dark ? Colors.white12 : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('⌘K', style: TextStyle(fontSize: 9, color: sub, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),

        // ── Acciones genéricas del módulo activo (inyectadas por módulos) ──
        // Consumer evita que el watch quede registrado en el context del StreamBuilder
        Consumer<FluixModuleActionsNotifier>(
          builder: (_, notifier, __) => notifier.actions.isEmpty
              ? const SizedBox.shrink()
              : Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: notifier.actions,
                    ),
                  ),
                ),
        ),

        // ── Acciones TPV a la derecha del buscador (solo módulo 'tpv') ───
        if (moduloId == 'tpv' && _tpvActions != null) ...[
          const SizedBox(width: 10),
          // Hold con badge reactivo
          if (_tpvActions!.verHold != null && _tpvActions!.holdCount != null)
            ValueListenableBuilder<int>(
              valueListenable: _tpvActions!.holdCount!,
              builder: (_, count, __) => Stack(clipBehavior: Clip.none, children: [
                IconButton(
                  onPressed: _tpvActions!.verHold,
                  icon: Icon(Icons.pause_circle_outline, size: 18,
                      color: count > 0 ? Colors.orange : const Color(0xFF6B7280)),
                  tooltip: 'Pedidos en espera',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
                if (count > 0)
                  Positioned(top: 0, right: 0, child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    child: Center(child: Text('$count',
                        style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700))),
                  )),
              ]),
            ),
          // Cajón
          if (_tpvActions!.abrirCajon != null) ...[
            const SizedBox(width: 4),
            _TpvHeaderBtn(label: 'Cajón', icon: Icons.point_of_sale_outlined,
                onTap: _tpvActions!.abrirCajon!),
          ],
          // Apertura Caja
          if (_tpvActions!.aperturaCaja != null) ...[
            const SizedBox(width: 4),
            _TpvHeaderBtn(label: 'Caja', icon: Icons.account_balance_wallet_outlined,
                onTap: _tpvActions!.aperturaCaja!),
          ],
          // Cierre
          if (_tpvActions!.cierreCaja != null) ...[
            const SizedBox(width: 4),
            _TpvHeaderBtn(label: 'Cierre', icon: Icons.summarize_outlined,
                onTap: _tpvActions!.cierreCaja!),
          ],
          // Nueva venta (solo tienda, filled azul)
          if (_tpvActions!.nuevaVenta != null) ...[
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: _tpvActions!.nuevaVenta,
              icon: const Icon(Icons.add_rounded, size: 13),
              label: const Text('Nueva venta',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
          // Más opciones ⋯
          if (_tpvActions!.masOpciones != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: _tpvActions!.masOpciones,
              icon: Icon(Icons.more_horiz, size: 18, color: sub),
              tooltip: 'Más opciones',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            ),
          ],
        ],

        // Spacer empuja notificaciones + empresa + usuario siempre a la derecha
        const Spacer(),

        // ── Toggle tema del TPV (solo visible cuando el TPV está activo) ──
        if (_tpvActions?.toggleTema != null && _tpvActions?.temaOscuro != null)
          ValueListenableBuilder<bool>(
            valueListenable: _tpvActions!.temaOscuro!,
            builder: (_, oscuro, __) => Tooltip(
              message: oscuro ? 'Modo claro' : 'Modo oscuro',
              child: IconButton(
                onPressed: _tpvActions!.toggleTema,
                icon: Icon(
                  oscuro ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 19,
                  color: dark ? Colors.white70 : const Color(0xFF64748B),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          ),

        // ── Toggle modo oscuro (siempre visible en desktop) ───────────────
        IconButton(
          tooltip: dark ? 'Modo claro' : 'Modo oscuro',
          onPressed: () => AppSettings.setDark(!dark),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: dark
                ? const Icon(Icons.nightlight_round, key: ValueKey('moon'), size: 20, color: Color(0xFF93C5FD))
                : const Icon(Icons.wb_sunny_rounded, key: ValueKey('sun'), size: 20, color: Color(0xFFF59E0B)),
          ),
        ),
        const SizedBox(width: 4),

        // ── Notificaciones — popup en desktop ─────────────────────────────
        if (_empresaId != null)
          StreamBuilder<int>(
            stream: BandejaNotificacionesService().noLeidasCount(_empresaId!),
            builder: (_, snap) {
              final count = snap.data ?? 0;
              return Stack(children: [
                IconButton(
                  onPressed: () => _mostrarNotificacionesPopup(context, dark),
                  icon: Icon(Icons.notifications_outlined, size: 20,
                      color: dark ? Colors.white70 : const Color(0xFF64748B)),
                ),
                if (count > 0)
                  Positioned(top: 6, right: 6, child: Container(
                    width: 15, height: 15,
                    decoration: const BoxDecoration(
                        color: Color(0xFF7C3AED), shape: BoxShape.circle),
                    child: Center(child: Text('$count',
                        style: const TextStyle(color: Colors.white, fontSize: 8,
                            fontWeight: FontWeight.w700))),
                  )),
              ]);
            },
          ),

        // ── Empresa + selector ────────────────────────────────────────────
        const SizedBox(width: 4),
        GestureDetector(
          onTap: _mostrarSelectorEmpresa,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: dark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: dark ? Colors.white12 : const Color(0xFFE2E8F0)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.business_rounded, size: 11, color: Color(0xFF7C3AED)),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(empresaLabel,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: text)),
              ),
              const SizedBox(width: 3),
              Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: sub),
            ]),
          ),
        ),

        // ── Usuario ───────────────────────────────────────────────────────
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          onSelected: _manejarMenu,
          tooltip: '',
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.14),
              child: Text(inicial,
                  style: const TextStyle(color: Color(0xFF7C3AED),
                      fontWeight: FontWeight.w700, fontSize: 11)),
            ),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(primerNombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: text)),
                Text(_sesion?.rol.name ?? 'Administrador', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: sub)),
              ]),
            ),
            const SizedBox(width: 3),
            Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: sub),
          ]),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'perfil',
                child: ListTile(leading: Icon(Icons.person), title: Text('Mi Perfil'),
                    contentPadding: EdgeInsets.zero, dense: true)),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'cerrar_sesion',
                child: ListTile(leading: Icon(Icons.logout, color: Colors.red),
                    title: Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                    contentPadding: EdgeInsets.zero, dense: true)),
          ],
        ),
      ]),
    );
  }

  void _abrirBusquedaGlobal() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => _BuscadorGlobal(
        empresaId: _empresaId ?? '',
        dark: _darkMode,
        onNavegar: (moduloId) {
          Navigator.pop(context);
          setState(() => _moduloDesktopActivo = moduloId);
        },
      ),
    );
  }

  void _mostrarSelectorEmpresa() {
    // Propietario de plataforma → selector completo con todas las empresas
    if (_sesion?.esPropietarioPlatforma == true) {
      _abrirSelectorEmpresa(_darkMode);
      return;
    }
    // Resto de usuarios → info solo
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Empresa activa',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.business_rounded, color: Color(0xFF7C3AED), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_nombreEmpresa.isNotEmpty ? _nombreEmpresa : 'Mi empresa',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('ID: ${_empresaId ?? ''}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ])),
              const Icon(Icons.check_circle_rounded, color: Color(0xFF7C3AED), size: 20),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('Para cambiar de empresa, cierra sesión\ny entra con otra cuenta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _nombreModulo(String id) {
    const nombres = {
      'personal': 'Personal', 'empleados': 'Empleados', 'facturacion': 'Facturación', 'contabilidad': 'Contabilidad',
      'clientes': 'Clientes', 'web': 'Web', 'tpv': 'TPV', 'pedidos': 'Pedidos',
      'tareas': 'Tareas', 'reservas': 'Reservas', 'fichaje': 'Fichajes',
      'vacaciones': 'Vacaciones', 'servicios': 'Servicios',
      'plantillas_pdf': 'Plantillas PDF', 'valoraciones': 'Valoraciones',
      'dashboard': 'Dashboard', 'propietario': 'Admin',
      'perfil': 'Perfil', 'cuentas': 'Cuentas',
    };
    return nombres[id] ?? id;
  }

  String _webSubModuloNombre(String id) {
    const nombres = {
      'secciones':      'Secciones',
      'catalogo':       'Catálogo',
      'blog':           'Blog',
      'mensajes':       'Mensajes',
      'agenda':         'Agenda',
      'galeria':        'Galería',
      'analytics':      'Analytics',
      'config':         'Configuración',
      'seleccion':      'Selección Nazarí',
      'campanas':       'Email',
      'noticias':       'Noticias',
      'entrevistas':    'Entrevistas',
      'autores':        'Autores',
      'plantillas_pdf': 'PDF',
      'archivo':        'Archivo',
      'editor_blog':      'Editor Blog',
      'editor_catalogo':  'Editor Catálogo',
      'editor_seccion':   'Editor Sección',
    };
    // Si el id no está en el mapa (ej: nombre de sección dinámica pasado directamente)
    // lo devolvemos tal cual — ya es el nombre legible.
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

  Widget _buildMasModulosSection(bool dark) {
    final bg     = dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardBg = dark ? const Color(0xFF1E2139) : Colors.white;
    final border = dark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;
    final text   = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub    = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    const tiles = [
      _AppTile('nominas',        Icons.payments_rounded,         'Nóminas',       Color(0xFF10B981)),
      _AppTile('plantillas_pdf', Icons.picture_as_pdf_rounded,   'Plantillas PDF',Color(0xFFEF4444)),
      _AppTile('servicios',      Icons.design_services_rounded,  'Servicios',     Color(0xFF3B82F6)),
      _AppTile('valoraciones',   Icons.star_rate_rounded,        'Valoraciones',  Color(0xFFF59E0B)),
      _AppTile('propietario',    Icons.admin_panel_settings_rounded,'Propietario', Color(0xFF8B5CF6)),
    ];
    return ColoredBox(
      color: bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Más módulos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: text)),
          const SizedBox(height: 4),
          Text('Nóminas, servicios, plantillas y más', style: TextStyle(fontSize: 14, color: sub)),
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
                onTap: () => _abrirModulo(t.id),
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
                    Text(_kDesc[t.id] ?? 'Gestiona desde aquí',
                        style: TextStyle(fontSize: 11, color: sub, height: 1.4),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
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
            crossAxisCount: 3, childAspectRatio: 1.35,
            crossAxisSpacing: 14, mainAxisSpacing: 14),
        itemCount: _tilesPermitidos.length,
        itemBuilder: (_, i) {
          final t = _tilesPermitidos[i];
          final action = _kAction[t.id] ?? '';
          return GestureDetector(
            onTap: () => t.id == 'carpeta' ? _mostrarCarpeta(dark) : _abrirModulo(t.id),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardBg, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
                boxShadow: dark ? [] : [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(width: 38, height: 38,
                      decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: dark ? 0.14 : 0.10),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(t.icon, color: t.accent, size: 19)),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, size: 13, color: t.accent.withValues(alpha: 0.5)),
                ]),
                const SizedBox(height: 8),
                Text(t.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: text),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(_kDesc[t.id] ?? '',
                      style: TextStyle(fontSize: 11, color: sub, height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
                if (action.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
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

  // ══════════════════════════════════════════════════════════════════════════
  // DASHBOARD HOME — replicado de la imagen de referencia
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardHome(bool dark) {
    if (_empresaId == null) return ColoredBox(
      color: dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      child: _buildSinEmpresa(),
    );
    final bg     = dark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final cardBg = dark ? const Color(0xFF1E2139) : Colors.white;
    final border = dark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;
    final text   = dark ? const Color(0xFFE2E8F0) : const Color(0xFF1F2937);
    final sub    = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return LayoutBuilder(builder: (_, cons) {
      final isMobile = cons.maxWidth < 600;
      final hPad     = isMobile ? 12.0 : 20.0;

      return ColoredBox(
        color: bg,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(hPad, isMobile ? 16 : 20, hPad, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Cabecera ─────────────────────────────────────────────────────
            if (isMobile) ...[
              _buildFintechHeroMobile(dark),
              const SizedBox(height: 14),
            ] else ...[
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Dashboard', style: TextStyle(fontSize: 20,
                      fontWeight: FontWeight.w800, color: text)),
                  Text('Panel de negocio', style: TextStyle(fontSize: 12, color: sub)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: cardBg, border: Border.all(color: border),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_today_outlined, size: 13, color: sub),
                    const SizedBox(width: 6),
                    Text(_formatearFechaHoy(), style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w500, color: text)),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: sub),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
            ],


            // ── Fila 1: Briefing | Agenda 7 días | Facturación | Alertas + Obligaciones ──────
            if (isMobile) ...[
              ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: SizedBox(height: 300, child: _buildBriefingIACard(dark, cardBg, border, text, sub))),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: SizedBox(height: 300, child: _buildAgenda7DiasCard(dark, cardBg, border, text, sub))),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: SizedBox(height: 300, child: _buildFacturacionOverviewCard(dark, cardBg, border, text, sub))),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: SizedBox(height: 220, child: _buildAlertasCard(dark, cardBg, border, text, sub))),
              const SizedBox(height: 10),
              ClipRRect(borderRadius: BorderRadius.circular(12),
                  child: SizedBox(height: 200, child: _buildObligacionesFiscalesCard(dark, cardBg, border, text, sub))),
            ] else ...[
              _dashRow(330, [
                _buildBriefingIACard(dark, cardBg, border, text, sub),
                _buildAgenda7DiasCard(dark, cardBg, border, text, sub),
              ]),
              const SizedBox(height: 14),
              _dashRow(300, [
                _buildFacturacionOverviewCard(dark, cardBg, border, text, sub),
                _buildAlertasCard(dark, cardBg, border, text, sub),
                _buildObligacionesFiscalesCard(dark, cardBg, border, text, sub),
              ]),
            ],
            const SizedBox(height: 14),

            // ── Fila 3 (antes 2): Pedidos | Tareas | Reservas ────────────────
            _dashRow(290, [
              _buildPedidosRecientesCard(dark, cardBg, border, text, sub),
              if (!_esNazari) _buildTareasPendientesCard(dark, cardBg, border, text, sub),
              if (!_esNazari) _buildProximasReservasCard(dark, cardBg, border, text, sub),
            ]),
            const SizedBox(height: 14),

            // ── Fila 3: Estado financiero | Rendimiento | Valoraciones ────────
            _dashRow(300, [
              _buildEstadoFinancieroCard(dark, cardBg, border, text, sub),
              if (!_esNazari) _buildRendimientoEmpleadosCard(dark, cardBg, border, text, sub),
              if (!_esNazari) _buildValoracionesRecientesCard(dark, cardBg, border, text, sub),
            ]),
            const SizedBox(height: 14),

            // ── Fila 4: Actividad reciente ────────────────────────────────────
            _dashRow(300, [
              _buildActividadRecienteCard(dark, cardBg, border, text, sub),
            ]),

            // Panel propietario: completo en desktop, acceso rápido en mobile
            if (_sesion?.esPropietario == true) ...[
              const SizedBox(height: 20),
              if (isMobile)
                GestureDetector(
                  onTap: () => _abrirModulo('propietario'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: dark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Container(width: 36, height: 36,
                          decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.admin_panel_settings_outlined, size: 18, color: Color(0xFF7C3AED))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Panel de Plataforma', style: TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w700, color: dark ? Colors.white : const Color(0xFF0F172A))),
                        Text('Métricas globales de Fluix', style: TextStyle(fontSize: 12, color: sub)),
                      ])),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF7C3AED)),
                    ]),
                  ),
                )
              else
                _buildDashPropietarioSection(dark, cardBg, border, text, sub),
            ],
          ]),
        ),
      );
    });
  }

  // ── KPI Strip: 5 tarjetas de empleados ────────────────────────────────────

  Widget _buildDashKpiEmpleados(bool dark, Color cardBg, Color border, Color text, Color sub) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('usuarios')
          .where('empresa_id', isEqualTo: _empresaId).snapshots(),
      builder: (_, snap) {
        final docs  = snap.data?.docs ?? [];
        final total = docs.length;
        final activos    = docs.where((d) => (d.data() as Map)['activo'] == true).length;
        final vacaciones = docs.where((d) => (d.data() as Map)['estado'] == 'vacaciones').length;
        final bajas      = docs.where((d) => (d.data() as Map)['activo'] == false).length;
        final presencia  = total > 0 ? (activos * 100 ~/ total) : 0;
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _dashKpiTile(Icons.people_alt_outlined, const Color(0xFFDCFCE7),
                const Color(0xFF22C55E), 'Total empleados', '$total', '+1 este mes', cardBg, border, text, sub)),
            const SizedBox(width: 10),
            Expanded(child: _dashKpiTile(Icons.beach_access_outlined, const Color(0xFFFEF3C7),
                const Color(0xFFF59E0B), 'Vacaciones', '$vacaciones', vacaciones == 0 ? 'Ninguno' : '$vacaciones empleado(s)', cardBg, border, text, sub)),
            const SizedBox(width: 10),
            Expanded(child: _dashKpiTile(Icons.sick_outlined, const Color(0xFFFFE4E6),
                const Color(0xFFEF4444), 'De baja', '$bajas', 'Ver detalle →', cardBg, border, text, sub)),
            const SizedBox(width: 10),
            Expanded(child: _dashKpiTile(Icons.percent_rounded, const Color(0xFFDCFCE7),
                const Color(0xFF22C55E), 'Tasa de presencia', '$presencia%', 'hoy en oficina', cardBg, border, text, sub)),
            const SizedBox(width: 10),
            Expanded(child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('empresas').doc(_empresaId)
                  .collection('valoraciones').snapshots(),
              builder: (_, vSnap) {
                final vDocs = vSnap.data?.docs ?? [];
                double avg = 0;
                if (vDocs.isNotEmpty) {
                  final sum = vDocs.fold<double>(0, (s, d) =>
                      s + ((d.data() as Map)['puntuacion'] as num? ?? 0).toDouble());
                  avg = sum / vDocs.length;
                }
                return _dashKpiTile(Icons.star_outline_rounded, const Color(0xFFFEF3C7),
                    const Color(0xFFF59E0B), 'Valoraciones',
                    avg > 0 ? avg.toStringAsFixed(1) : '—', '${vDocs.length} reseñas', cardBg, border, text, sub);
              },
            )),
          ]),
        );
      },
    );
  }

  Widget _dashKpiTile(IconData icon, Color iconBg, Color iconColor, String label,
      String valor, String sub2, Color cardBg, Color border, Color text, Color sub) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6, offset: const Offset(0, 2))]),
        child: Row(children: [
          Container(width: 38, height: 38,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: sub), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: text)),
            Text(sub2, style: TextStyle(fontSize: 10, color: sub), overflow: TextOverflow.ellipsis),
          ])),
        ]),
      );

  // ── Tabla "Próximas a 0hs" — empleados activos recientes ──────────────────

  Widget _buildProximasEmpleadosCard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Text('Próximas a 0hs', style: TextStyle(fontSize: 14,
                fontWeight: FontWeight.w700, color: text)),
            const Spacer(),
            Text('Ver todos →', style: TextStyle(fontSize: 12,
                color: const Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
          ]),
        ),
        const Divider(height: 1),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('usuarios')
              .where('empresa_id', isEqualTo: _empresaId)
              .where('activo', isEqualTo: true).limit(6).snapshots(),
          builder: (_, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Sin empleados activos', style: TextStyle(color: sub, fontSize: 12)),
            );
            return Column(
              children: docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final nombre = d['nombre'] as String? ?? 'Sin nombre';
                final puesto = d['puesto'] as String? ?? d['rol'] as String? ?? '';
                final dept   = d['departamento'] as String? ?? '';
                final fotoUrl = d['foto_url'] as String?;
                final ini = nombre.trim().isNotEmpty ? nombre.trim()[0].toUpperCase() : 'E';
                return Container(
                  decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: border))),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    CircleAvatar(radius: 16,
                        backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                        child: fotoUrl == null ? Text(ini, style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold,
                            color: Color(0xFF3B82F6))) : null),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nombre, style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600, color: text),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(puesto.isNotEmpty ? puesto : 'Staff', style: TextStyle(
                          fontSize: 10.5, color: sub), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    if (dept.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(dept, style: const TextStyle(
                            fontSize: 9.5, color: Color(0xFF3B82F6))),
                      ),
                    const SizedBox(width: 8),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(
                        color: Color(0xFF22C55E), shape: BoxShape.circle)),
                  ]),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }

  // ── Facturación overview ──────────────────────────────────────────────────

  Widget _buildFacturacionOverviewCard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    final meses6 = List.generate(6, (i) =>
        DateTime(_facturacionVentana.year, _facturacionVentana.month + i));
    const etiq = ['','ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    const kBlue   = Color(0xFF3B82F6);
    const kGreen  = Color(0xFF22C55E);
    const kOrange = Color(0xFFF59E0B);

    // LayoutBuilder en la raíz para obtener la altura real disponible
    return LayoutBuilder(builder: (_, lc) {
      final cardH = lc.maxHeight.isFinite ? lc.maxHeight : 300.0;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(_empresaId)
          .collection('facturas').snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        final Map<String, double> porMes = {};
        double totalMesSelec = 0, totalMesAnterior = 0;
        int pagadasMes = 0, pendientesMes = 0;
        final mesAnt = DateTime(_facturacionMes.year, _facturacionMes.month - 1);

        for (final doc in docs) {
          final d = doc.data() as Map;
          final imp = (d['total'] as num? ?? d['importe'] as num? ?? 0).toDouble();
          final ts  = d['fecha_emision'] as Timestamp? ?? d['fecha_creacion'] as Timestamp?;
          if (ts == null) continue;
          final dt  = ts.toDate();
          porMes['${dt.year}-${dt.month}'] = (porMes['${dt.year}-${dt.month}'] ?? 0) + imp;
          if (dt.year == _facturacionMes.year && dt.month == _facturacionMes.month) {
            totalMesSelec += imp;
            final estado = d['estado'] as String? ?? '';
            if (estado == 'pagada' || estado == 'cobrada') pagadasMes++;
            else pendientesMes++;
          }
          if (dt.year == mesAnt.year && dt.month == mesAnt.month) totalMesAnterior += imp;
        }

        final valores = meses6.map((m) => porMes['${m.year}-${m.month}'] ?? 0.0).toList();
        final maxVal  = valores.fold(0.0, (a, b) => a > b ? a : b);
        final fmt     = (double v) => v >= 1000 ? '${(v/1000).toStringAsFixed(1)}k€' : '${v.toStringAsFixed(0)}€';

        // Variación vs mes anterior — solo si ambos meses tienen datos
        final hasPrev   = totalMesAnterior > 0 && totalMesSelec > 0;
        final varPct    = hasPrev ? ((totalMesSelec - totalMesAnterior) / totalMesAnterior * 100) : 0.0;
        final varPosit  = varPct >= 0;
        final varLabel  = hasPrev ? '${varPosit ? '+' : ''}${varPct.toStringAsFixed(0)}% vs ${etiq[mesAnt.month]}' : null;

        return Container(
          height: cardH, // altura explícita → Column con constrains acotados
          clipBehavior: Clip.hardEdge,  // evita overflow de 2px por el borde
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Cabecera ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 0),
              child: Row(children: [
                Container(width: 24, height: 24,
                    decoration: BoxDecoration(
                        color: kBlue.withValues(alpha: dark ? 0.18 : 0.10),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.receipt_long_rounded, size: 13, color: kBlue)),
                const SizedBox(width: 7),
                Expanded(child: Text('Facturación', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: text),
                    overflow: TextOverflow.ellipsis, maxLines: 1)),
                // Navegación ventana (±6 meses) — no mueve el mes seleccionado
                GestureDetector(
                  onTap: () => setState(() => _facturacionVentana =
                      DateTime(_facturacionVentana.year, _facturacionVentana.month - 6)),
                  child: Icon(Icons.chevron_left_rounded, size: 20, color: sub),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${etiq[meses6.first.month]}–${etiq[meses6.last.month]}',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: sub),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final sig = DateTime(_facturacionVentana.year, _facturacionVentana.month + 6);
                    // No avanzar más allá del mes actual
                    if (!sig.isAfter(DateTime.now())) {
                      setState(() => _facturacionVentana = sig);
                    }
                  },
                  child: Icon(Icons.chevron_right_rounded, size: 20,
                      color: DateTime(_facturacionVentana.year, _facturacionVentana.month + 6)
                          .isAfter(DateTime.now()) ? border : sub),
                ),
              ]),
            ),
            // ── Hero metric ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(fmt(totalMesSelec),
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                            color: text, letterSpacing: -1.5),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${etiq[_facturacionMes.month]} ${_facturacionMes.year}',
                        style: TextStyle(fontSize: 10, color: sub)),
                  ]),
                ),
                if (varLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (varPosit ? kGreen : kOrange).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(varPosit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          size: 10, color: varPosit ? kGreen : kOrange),
                      const SizedBox(width: 3),
                      Text(varLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                              color: varPosit ? kGreen : kOrange),
                          maxLines: 1),
                    ]),
                  ),
              ]),
            ),
            // ── Mini stats ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                _factBadge(Icons.check_circle_outline_rounded, '$pagadasMes cobradas', kGreen, dark),
                _factBadge(Icons.hourglass_empty_rounded, '$pendientesMes pendientes', kOrange, dark),
              ]),
            ),
            // ── Sparkline ─────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Column(children: [
                  Expanded(
                    child: CustomPaint(
                      painter: _SparklinePainter(
                        values: valores,
                        selectedIndex: meses6.indexWhere((m) =>
                            m.month == _facturacionMes.month && m.year == _facturacionMes.year),
                        color: kBlue,
                        dark: dark,
                        sub: sub,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Row(children: List.generate(meses6.length, (i) {
                    final mes = meses6[i];
                    final isSel = mes.month == _facturacionMes.month &&
                        mes.year == _facturacionMes.year;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _facturacionMes = mes),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(etiq[mes.month],
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 8.5,
                                  color: isSel ? kBlue : sub,
                                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w400)),
                        ),
                      ),
                    );
                  })),
                ]),
              ),
            ),
            // ── CTA ──────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: GestureDetector(
                onTap: () => _moduloDesktopActivo != null
                    ? setState(() => _moduloDesktopActivo = 'facturacion')
                    : _abrirModulo('facturacion'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: kBlue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.receipt_long_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Ver facturación', style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w600, color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ]),
        );
      },
    );
    }); // LayoutBuilder
  }

  Widget _factBadge(IconData icon, String label, Color color, bool dark) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
        ]),
      );

  Widget _factDivider() => Container(width: 1, height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 6), color: const Color(0xFFE5E7EB));

  // ── Obligaciones fiscales ─────────────────────────────────────────────────

  Widget _buildObligacionesFiscalesCard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    final now  = DateTime.now();
    final year = now.year;
    // Calcular trimestre actual y próximas fechas de presentación
    final plazos = <({String modelo, String periodo, DateTime vence, Color color})>[
      (modelo: 'Mod. 303 — IVA',  periodo: 'T1 Ene/Mar', vence: DateTime(year, 4, 20),  color: const Color(0xFF3B82F6)),
      (modelo: 'Mod. 303 — IVA',  periodo: 'T2 Abr/Jun', vence: DateTime(year, 7, 20),  color: const Color(0xFF3B82F6)),
      (modelo: 'Mod. 303 — IVA',  periodo: 'T3 Jul/Sep', vence: DateTime(year, 10, 20), color: const Color(0xFF3B82F6)),
      (modelo: 'Mod. 303 — IVA',  periodo: 'T4 Oct/Dic', vence: DateTime(year + 1, 1, 30), color: const Color(0xFF3B82F6)),
      (modelo: 'Mod. 130 — IRPF', periodo: 'T1 Ene/Mar', vence: DateTime(year, 4, 20),  color: const Color(0xFF8B5CF6)),
      (modelo: 'Mod. 130 — IRPF', periodo: 'T2 Abr/Jun', vence: DateTime(year, 7, 20),  color: const Color(0xFF8B5CF6)),
      (modelo: 'Mod. 130 — IRPF', periodo: 'T3 Jul/Sep', vence: DateTime(year, 10, 20), color: const Color(0xFF8B5CF6)),
      (modelo: 'Mod. 111 — Ret.',  periodo: 'T1 Ene/Mar', vence: DateTime(year, 4, 20),  color: const Color(0xFF10B981)),
      (modelo: 'Mod. 111 — Ret.',  periodo: 'T2 Abr/Jun', vence: DateTime(year, 7, 20),  color: const Color(0xFF10B981)),
      (modelo: 'Mod. 111 — Ret.',  periodo: 'T3 Jul/Sep', vence: DateTime(year, 10, 20), color: const Color(0xFF10B981)),
      (modelo: 'Mod. 390 — Anual', periodo: 'Ejercicio $year', vence: DateTime(year + 1, 1, 30), color: const Color(0xFF0EA5E9)),
    ];
    // Mostrar solo los 4 próximos plazos futuros (o pasados <30 días)
    final futuros = plazos
        .where((p) => p.vence.isAfter(now.subtract(const Duration(days: 30))))
        .toList()
      ..sort((a, b) => a.vence.compareTo(b.vence));
    final mostrar = futuros.take(3).toList();

    String _fmt(DateTime d) {
      final diff = d.difference(now).inDays;
      if (diff < 0) return 'Vencido';
      if (diff == 0) return 'Hoy';
      if (diff <= 7) return 'En $diff d.';
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}';
    }

    return LayoutBuilder(builder: (_, lc) {
      const headerH = 46.0;
      const itemH   = 41.0;
      final cardH   = lc.maxHeight.isFinite ? lc.maxHeight : 200.0;
      final maxItems = ((cardH - headerH) / itemH).floor().clamp(1, 4);
      final visible  = mostrar.take(maxItems).toList();

    return Container(
      height: cardH,
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(width: 24, height: 24,
                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.account_balance_outlined, size: 14, color: Color(0xFFF59E0B))),
            const SizedBox(width: 8),
            Expanded(child: Text('Obligaciones Fiscales $year',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text))),
            GestureDetector(
              onTap: () => setState(() => _moduloDesktopActivo = 'facturacion'),
              child: Text('Ver →', style: const TextStyle(
                  fontSize: 10, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        ...visible.map((o) {
          final vencido = o.vence.isBefore(now);
          final urgente = !vencido && o.vence.difference(now).inDays <= 7;
          final labelColor = vencido
              ? const Color(0xFFEF4444)
              : urgente ? const Color(0xFFF59E0B) : sub;
          return Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
            child: Row(children: [
              Container(width: 3, height: 28, decoration: BoxDecoration(
                  color: vencido ? const Color(0xFFEF4444) : o.color,
                  borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(o.modelo, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: text),
                    overflow: TextOverflow.ellipsis),
                Text(o.periodo, style: TextStyle(fontSize: 9, color: sub)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_fmt(o.vence), style: TextStyle(
                    fontSize: 9.5, color: labelColor, fontWeight: FontWeight.w700)),
              ),
            ]),
          );
        }),
      ]),
    );
    }); // LayoutBuilder
  }

  // ── Pedidos recientes ─────────────────────────────────────────────────────

  Widget _buildPedidosRecientesCard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Text('Pedidos recientes', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: text)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _moduloDesktopActivo = 'pedidos'),
              child: const Text('Ver todos →', style: TextStyle(fontSize: 11,
                  color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas').doc(_empresaId)
              .collection('pedidos')
              .orderBy('fecha_creacion', descending: true).limit(5).snapshots(),
          builder: (_, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Sin pedidos', style: TextStyle(color: sub, fontSize: 12)),
            );
            return Column(children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final cliente = d['cliente_nombre'] as String?
                  ?? d['cliente'] as String?
                  ?? d['nombre_cliente'] as String?
                  ?? 'Sin nombre';
              final estado  = d['estado'] as String? ?? 'pendiente';
              final total   = (d['total'] as num? ?? d['importe'] as num? ?? 0).toDouble();
              final fechaTs = d['fecha_creacion'];
              DateTime? fechaDate;
              if (fechaTs is Timestamp) fechaDate = fechaTs.toDate();
              final fechaStr = fechaDate != null
                  ? '${fechaDate.day.toString().padLeft(2,'0')}/${fechaDate.month.toString().padLeft(2,'0')}'
                  : '';
              final col = estado == 'completado' || estado == 'entregado'
                  ? const Color(0xFF22C55E)
                  : estado == 'en_proceso' ? const Color(0xFF3B82F6) : const Color(0xFFF59E0B);
              return Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
                child: Row(children: [
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cliente, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: text),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (fechaStr.isNotEmpty)
                      Text(fechaStr, style: TextStyle(fontSize: 10, color: sub)),
                  ])),
                  Text('${total.toStringAsFixed(0)}€',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text)),
                ]),
              );
            }).toList());
          },
        ),
      ]),
    );
  }

  // ── Próximas reservas ─────────────────────────────────────────────────────

  Widget _buildProximasReservasCard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Text('Próximas Reservas', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: text)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _moduloDesktopActivo = 'reservas'),
              child: const Text('Ver todas →', style: TextStyle(fontSize: 11,
                  color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas').doc(_empresaId)
              .collection('reservas')
              .where('estado', whereIn: ['pendiente', 'confirmada'])
              .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(
                  DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)))
              .orderBy('fecha').limit(4).snapshots(),
          builder: (_, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Sin reservas próximas', style: TextStyle(color: sub, fontSize: 12)),
            );
            return Column(children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final nombre  = d['nombre'] as String?
                  ?? d['cliente_nombre'] as String?
                  ?? d['cliente'] as String? ?? 'Sin nombre';
              final hora    = d['hora'] as String? ?? d['hora_inicio'] as String? ?? '';
              final fecha   = d['fecha'] is Timestamp
                  ? (d['fecha'] as Timestamp).toDate()
                  : null;
              final isHoy = fecha != null &&
                  fecha.day == DateTime.now().day &&
                  fecha.month == DateTime.now().month;
              final fechaStr = fecha != null
                  ? (isHoy ? 'Hoy' : '${fecha.day.toString().padLeft(2,'0')}/${fecha.month.toString().padLeft(2,'0')}')
                  : d['fecha']?.toString() ?? '';
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
                child: Row(children: [
                  Container(width: 30, height: 30,
                      decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.calendar_today_outlined, size: 14,
                          color: Color(0xFF8B5CF6))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nombre, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: text),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (hora.isNotEmpty)
                      Text(hora, style: TextStyle(fontSize: 10.5, color: sub)),
                  ])),
                  Text(fechaStr, style: TextStyle(fontSize: 11, color: sub)),
                ]),
              );
            }).toList());
          },
        ),
      ]),
    );
  }

  // ── Valoraciones recientes ────────────────────────────────────────────────

  Widget _buildValoracionesRecientesCard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Text('Valoraciones recientes', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: text)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _moduloDesktopActivo = 'valoraciones'),
              child: const Text('Ver todas →', style: TextStyle(fontSize: 11,
                  color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas').doc(_empresaId)
              .collection('valoraciones')
              .orderBy('fecha', descending: true).limit(5).snapshots(),
          builder: (_, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Sin valoraciones', style: TextStyle(color: sub, fontSize: 12)),
            );
            return Column(children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final nombre  = d['cliente_nombre'] as String? ?? d['nombre'] as String? ?? 'Anónimo';
              final puntos  = (d['estrellas'] as num? ?? d['puntuacion'] as num? ?? 0).round();
              final coment  = d['comentario'] as String? ?? '';
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(radius: 14,
                        backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        child: Text(nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                                color: Color(0xFF3B82F6)))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(nombre, style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.w600, color: text),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Row(mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (i) => Icon(
                          i < puntos ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 12,
                          color: i < puntos ? const Color(0xFFF59E0B) : sub,
                        ))),
                  ]),
                  if (coment.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(coment, style: TextStyle(fontSize: 10.5, color: sub, height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ]),
              );
            }).toList());
          },
        ),
      ]),
    );
  }

  // ── Alertas ───────────────────────────────────────────────────────────────

  Widget _buildAlertasCard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    const headerH = 45.0;
    const itemH   = 46.0;

    Widget buildAlerta(({IconData icon, Color color, String titulo, String desc, String modulo}) a) =>
        InkWell(
          onTap: () => _moduloDesktopActivo != null
              ? setState(() => _moduloDesktopActivo = a.modulo.isEmpty ? null : a.modulo)
              : _abrirModulo(a.modulo),
          child: Container(
            height: itemH,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
            child: Row(children: [
              Container(width: 28, height: 28,
                  decoration: BoxDecoration(color: a.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(7)),
                  child: Icon(a.icon, size: 14, color: a.color)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(a.titulo, style: TextStyle(fontSize: 11.5, color: text,
                    fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(a.desc, style: TextStyle(fontSize: 10, color: sub),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Icon(Icons.chevron_right_rounded, size: 14, color: a.color),
            ]),
          ),
        );

    return LayoutBuilder(builder: (_, cons) {
      final cardH    = cons.maxHeight.isFinite ? cons.maxHeight : 220.0;
      final contentH = (cardH - headerH - 1).clamp(0.0, double.infinity);
      final maxItems = (contentH / itemH).floor().clamp(1, 4);

      return Container(
        height: cardH, // altura explícita garantiza constrains acotados
        clipBehavior: Clip.hardEdge,  // evita overflow de 2px por el borde
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Cabecera fija
          SizedBox(
            height: headerH,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Row(children: [
                Container(width: 24, height: 24,
                    decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFEF4444))),
                const SizedBox(width: 8),
                Text('Alertas del negocio', style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700, color: text)),
              ]),
            ),
          ),
          Divider(height: 1, color: border),
          // Listado acotado con SizedBox explícito — imposible desbordarse
          SizedBox(
            height: contentH,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('empresas').doc(_empresaId)
                  .collection('facturas')
                  .where('estado', whereIn: ['pendiente', 'enviada']).snapshots(),
              builder: (_, fSnap) {
                final now = DateTime.now();
                final factVencidas = (fSnap.data?.docs ?? []).where((doc) {
                  final d = doc.data() as Map;
                  final f = d['fecha_vencimiento'];
                  return f is Timestamp && f.toDate().isBefore(now);
                }).length;
                final factProximas = (fSnap.data?.docs ?? []).where((doc) {
                  final d = doc.data() as Map;
                  final f = d['fecha_vencimiento'];
                  if (f is Timestamp) {
                    final dt = f.toDate();
                    return dt.isAfter(now) && dt.isBefore(now.add(const Duration(days: 7)));
                  }
                  return false;
                }).length;
                return StreamBuilder<int>(
                  stream: _streamTareasPendientes(),
                  builder: (_, tSnap) {
                    final tareas = tSnap.data ?? 0;
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('empresas').doc(_empresaId)
                          .collection('reservas')
                          .where('estado', isEqualTo: 'pendiente').snapshots(),
                      builder: (_, rSnap) {
                        final reservasPend = rSnap.data?.docs.length ?? 0;
                        final alertas = <({IconData icon, Color color, String titulo, String desc, String modulo})>[
                          if (factVencidas > 0)
                            (icon: Icons.receipt_long_outlined, color: const Color(0xFFEF4444),
                              titulo: '$factVencidas factura${factVencidas > 1 ? 's' : ''} vencida${factVencidas > 1 ? 's' : ''}',
                              desc: 'Pendiente${factVencidas > 1 ? 's' : ''} de cobro', modulo: 'facturacion'),
                          if (factProximas > 0)
                            (icon: Icons.schedule_rounded, color: const Color(0xFFF59E0B),
                              titulo: '$factProximas próxima${factProximas > 1 ? 's' : ''} a vencer',
                              desc: 'Vence${factProximas > 1 ? 'n' : ''} esta semana', modulo: 'facturacion'),
                          if (reservasPend > 0)
                            (icon: Icons.calendar_today_rounded, color: const Color(0xFF8B5CF6),
                              titulo: '$reservasPend reserva${reservasPend > 1 ? 's' : ''} por confirmar',
                              desc: 'Requiere${reservasPend > 1 ? 'n' : ''} atención', modulo: 'reservas'),
                          if (tareas > 0)
                            (icon: Icons.task_alt_rounded, color: const Color(0xFF3B82F6),
                              titulo: '$tareas tarea${tareas > 1 ? 's' : ''} pendiente${tareas > 1 ? 's' : ''}',
                              desc: 'Sin completar', modulo: 'tareas'),
                        ];
                        if (alertas.isEmpty) {
                          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.check_circle_rounded, size: 26, color: Color(0xFF22C55E)),
                            const SizedBox(height: 5),
                            Text('Todo al día', style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.w600, color: const Color(0xFF22C55E))),
                            Text('Sin alertas activas', style: TextStyle(fontSize: 10, color: sub)),
                          ]));
                        }
                        return Column(mainAxisSize: MainAxisSize.min,
                          children: alertas.take(maxItems).map(buildAlerta).toList());
                      },
                    );
                  },
                );
              },
            ),
          ),
        ]),
      );
    });
  }

  // ── Panel de Plataforma (Propietario) ─────────────────────────────────────

  Widget _buildDashPropietarioSection(bool dark, Color cardBg, Color border, Color text, Color sub) {
    const purple = Color(0xFF7C3AED);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Cabecera con botón "Ver panel completo" ───────────────────────────
      Row(children: [
        Container(width: 28, height: 28,
            decoration: BoxDecoration(color: purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.admin_panel_settings_outlined, size: 15, color: purple)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Panel de Plataforma', style: TextStyle(fontSize: 15,
              fontWeight: FontWeight.w700, color: text)),
          Text('Métricas globales de Fluix', style: TextStyle(fontSize: 11, color: sub)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _moduloDesktopActivo = 'propietario'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: purple,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white),
              SizedBox(width: 6),
              Text('Ver panel completo', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 14),

      // ── Fila 1: KPIs empresa y facturación ────────────────────────────────
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('empresas').get(),
            builder: (_, s) => _propKpiBox(Icons.business_outlined, const Color(0xFF3B82F6),
                'Empresas en plataforma', '${s.data?.docs.length ?? 0}', 'registradas', cardBg, border, text, sub),
          )),
          const SizedBox(width: 10),
          Expanded(child: _buildPropKpi(Icons.receipt_long_outlined, const Color(0xFFEF4444),
              'Facturas pendientes', _streamFacturasPendientes(), cardBg, border, text, sub)),
          const SizedBox(width: 10),
          Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('empresas').doc(_empresaId)
                .collection('facturas')
                .where('estado', isEqualTo: 'pagada').snapshots(),
            builder: (_, s) {
              double total = 0;
              for (final doc in s.data?.docs ?? []) {
                final d = doc.data() as Map;
                total += (d['total'] as num? ?? d['importe'] as num? ?? 0).toDouble();
              }
              final str = total >= 1000
                  ? '${(total/1000).toStringAsFixed(1)}k€'
                  : '${total.toStringAsFixed(0)}€';
              return _propKpiBox(Icons.trending_up_rounded, const Color(0xFF22C55E),
                  'Facturación total', str, 'cobrado', cardBg, border, text, sub);
            },
          )),
          const SizedBox(width: 10),
          Expanded(child: StreamBuilder<int>(
            stream: _streamTareasPendientes(),
            builder: (_, s) => _propKpiBox(Icons.task_alt_rounded, const Color(0xFF8B5CF6),
                'Tareas abiertas', '${s.data ?? 0}', 'pendientes', cardBg, border, text, sub),
          )),
          const SizedBox(width: 10),
          Expanded(child: StreamBuilder<int>(
            stream: _streamPedidosActivos(),
            builder: (_, s) => _propKpiBox(Icons.inventory_2_outlined, const Color(0xFFF59E0B),
                'Pedidos activos', '${s.data ?? 0}', 'en proceso', cardBg, border, text, sub),
          )),
          const SizedBox(width: 10),
          Expanded(child: StreamBuilder<int>(
            stream: _streamTotalClientes(),
            builder: (_, s) => _propKpiBox(Icons.people_alt_outlined, const Color(0xFF14B8A6),
                'Clientes totales', '${s.data ?? 0}', 'registrados', cardBg, border, text, sub),
          )),
        ]),
      ),
      const SizedBox(height: 14),

      // ── Fila 2: Empleados, B2C, Suscripciones, Valoraciones ──────────────
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('usuarios')
                .where('empresa_id', isEqualTo: _empresaId)
                .where('activo', isEqualTo: true).snapshots(),
            builder: (_, s) => _propKpiBox(Icons.badge_outlined, const Color(0xFF22C55E),
                'Empleados activos', '${s.data?.docs.length ?? 0}', 'en plantilla', cardBg, border, text, sub),
          )),
          const SizedBox(width: 10),
          Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('usuarios')
                .where('rol', isEqualTo: 'clienteFinal').snapshots(),
            builder: (_, s) => _propKpiBox(Icons.phone_android_outlined, const Color(0xFF0EA5E9),
                'Usuarios B2C', '${s.data?.docs.length ?? 0}', 'app clientes', cardBg, border, text, sub),
          )),
          const SizedBox(width: 10),
          Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('empresas').doc(_empresaId)
                .collection('reservas')
                .where('estado', whereIn: ['pendiente', 'confirmada']).snapshots(),
            builder: (_, s) => _propKpiBox(Icons.calendar_month_outlined, const Color(0xFF8B5CF6),
                'Reservas activas', '${s.data?.docs.length ?? 0}', 'pendientes', cardBg, border, text, sub),
          )),
          const SizedBox(width: 10),
          // Suscripciones (info de esta empresa)
          Expanded(child: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('empresas').doc(_empresaId)
                .collection('suscripcion').doc('actual').get(),
            builder: (_, s) {
              String estado = '—';
              Color color = const Color(0xFF9CA3AF);
              if (s.hasData && s.data!.exists) {
                final d = s.data!.data() as Map<String, dynamic>;
                final e = (d['estado'] as String? ?? '').toUpperCase();
                estado = e == 'ACTIVA' ? 'Activa' : e == 'VENCIDA' ? 'Vencida' : e;
                color = e == 'ACTIVA' ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
              }
              return _propKpiBox(Icons.card_membership_outlined, color,
                  'Suscripción', estado, 'estado actual', cardBg, border, text, sub);
            },
          )),
          const SizedBox(width: 10),
          Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('empresas').doc(_empresaId)
                .collection('valoraciones').snapshots(),
            builder: (_, s) {
              final docs = s.data?.docs ?? [];
              double avg = 0;
              if (docs.isNotEmpty) {
                avg = docs.fold<double>(0, (sum, d) =>
                    sum + ((d.data() as Map)['puntuacion'] as num? ?? 0).toDouble()) / docs.length;
              }
              return _propKpiBox(Icons.star_outline_rounded, const Color(0xFFF59E0B),
                  'Valoración media', avg > 0 ? avg.toStringAsFixed(1) : '—',
                  '${docs.length} reseñas', cardBg, border, text, sub);
            },
          )),
          const SizedBox(width: 10),
          // Negocios públicos
          Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('negocios_publicos')
                .where('activo', isEqualTo: true).snapshots(),
            builder: (_, s) => _propKpiBox(Icons.store_outlined, const Color(0xFF14B8A6),
                'Negocios públicos', '${s.data?.docs.length ?? 0}', 'activos en app', cardBg, border, text, sub),
          )),
        ]),
      ),
    ]);
  }

  Widget _buildPropKpi(IconData icon, Color color, String label,
      Stream<int> stream, Color cardBg, Color border, Color text, Color sub) =>
      StreamBuilder<int>(
        stream: stream,
        builder: (_, s) => _propKpiBox(icon, color, label, '${s.data ?? 0}',
            '', cardBg, border, text, sub),
      );

  Widget _propKpiBox(IconData icon, Color color, String label, String valor, String sub2,
      Color cardBg, Color border, Color text, Color sub) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6, offset: const Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 17)),
          const SizedBox(height: 10),
          Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: text)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10.5, color: sub, height: 1.3),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          if (sub2.isNotEmpty)
            Text(sub2, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ]),
      );

  // ── Helper: fila de N tarjetas a la misma altura ──────────────────────────

  Widget _dashRow(double height, List<Widget> cards) {
    return LayoutBuilder(builder: (_, cons) {
      if (cons.maxWidth < 600) {
        // Mobile: apilar verticalmente, cada tarjeta ocupa todo el ancho
        return Column(mainAxisSize: MainAxisSize.min, children: [
          for (int i = 0; i < cards.length; i++) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(height: height, width: double.infinity, child: cards[i]),
            ),
            if (i < cards.length - 1) const SizedBox(height: 10),
          ],
        ]);
      }
      // Desktop: fila horizontal de ancho fijo
      final items = <Widget>[];
      for (int i = 0; i < cards.length; i++) {
        items.add(Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: cards[i],
        )));
        if (i < cards.length - 1) items.add(const SizedBox(width: 14));
      }
      return SizedBox(
        height: height,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: items),
      );
    });
  }

  // ── Block 1: KPIs de negocio (6 métricas clave) ───────────────────────────

  Widget _buildDashKpiNegocio(bool dark, Color cardBg, Color border, Color text, Color sub) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas').doc(_empresaId)
              .collection('facturas')
              .where('estado', isEqualTo: 'pagada').snapshots(),
          builder: (_, s) {
            final now = DateTime.now();
            double mes = 0;
            for (final doc in s.data?.docs ?? []) {
              final d = doc.data() as Map;
              final ts = d['fecha_emision'] as Timestamp?;
              if (ts != null && ts.toDate().month == now.month && ts.toDate().year == now.year) {
                mes += (d['total'] as num? ?? d['importe'] as num? ?? 0).toDouble();
              }
            }
            final str = mes >= 1000 ? '${(mes/1000).toStringAsFixed(1)}k€' : '${mes.toStringAsFixed(0)}€';
            return _dashKpiTile(Icons.trending_up_rounded, const Color(0xFFDCFCE7),
                const Color(0xFF22C55E), 'Facturación mes', str, 'cobrado este mes', cardBg, border, text, sub);
          },
        )),
        const SizedBox(width: 10),
        Expanded(child: StreamBuilder<int>(
          stream: _streamTotalClientes(),
          builder: (_, s) => _dashKpiTile(Icons.people_alt_outlined, const Color(0xFFDBEAFE),
              const Color(0xFF3B82F6), 'Clientes', '${s.data ?? 0}', 'activos en total', cardBg, border, text, sub),
        )),
        const SizedBox(width: 10),
        Expanded(child: StreamBuilder<int>(
          stream: _streamPedidosActivos(),
          builder: (_, s) => _dashKpiTile(Icons.inventory_2_outlined, const Color(0xFFFEF3C7),
              const Color(0xFFF59E0B), 'Pedidos activos', '${s.data ?? 0}', 'en proceso', cardBg, border, text, sub),
        )),
        const SizedBox(width: 10),
        Expanded(child: StreamBuilder<int>(
          stream: _streamTareasPendientes(),
          builder: (_, s) => _dashKpiTile(Icons.task_alt_rounded, const Color(0xFFF3E8FF),
              const Color(0xFF8B5CF6), 'Tareas', '${s.data ?? 0}', 'pendientes', cardBg, border, text, sub),
        )),
        const SizedBox(width: 10),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas').doc(_empresaId)
              .collection('reservas')
              .where('estado', whereIn: ['pendiente', 'confirmada']).snapshots(),
          builder: (_, s) => _dashKpiTile(Icons.calendar_month_outlined, const Color(0xFFEDE9FE),
              const Color(0xFF7C3AED), 'Reservas', '${s.data?.docs.length ?? 0}', 'próximas', cardBg, border, text, sub),
        )),
        const SizedBox(width: 10),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('usuarios')
              .where('empresa_id', isEqualTo: _empresaId)
              .where('activo', isEqualTo: true).snapshots(),
          builder: (_, s) => _dashKpiTile(Icons.badge_outlined, const Color(0xFFDCFCE7),
              const Color(0xFF22C55E), 'Empleados activos', '${s.data?.docs.length ?? 0}', 'en plantilla', cardBg, border, text, sub),
        )),
      ]),
    );
  }

  // ── Block 2: Briefing del día ─────────────────────────────────────────────

  Widget _buildBriefingIACard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    if (_empresaId == null) return const SizedBox.shrink();
    final now  = DateTime.now();
    final hoy  = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    final hora = now.hour;
    final saludo = hora < 12 ? 'Buenos días' : hora < 20 ? 'Buenas tardes' : 'Buenas noches';
    const meses = ['','ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final fechaStr = '${now.day} de ${meses[now.month]} de ${now.year}';

    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cabecera
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            gradient: LinearGradient(
              colors: [const Color(0xFF7C3AED).withValues(alpha: 0.08),
                       const Color(0xFF3B82F6).withValues(alpha: 0.04)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Row(children: [
            Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF3B82F6)]),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.wb_sunny_outlined, size: 18, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$saludo, ${_obtenerPrimerNombre(_nombreUsuario)}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
              Text(fechaStr, style: TextStyle(fontSize: 11, color: sub)),
            ])),
          ]),
        ),
        const Divider(height: 1),
        // Datos de hoy en tiempo real
        FutureBuilder<Map<String, int>>(
          future: _cargarResumenHoy(hoy),
          builder: (_, snap) {
            final data = snap.data ?? {};
            final reservasHoy  = data['reservas'] ?? 0;
            final pedidosHoy   = data['pedidos'] ?? 0;
            final facturasHoy  = data['facturas'] ?? 0;
            final tareasAbier  = data['tareas'] ?? 0;
            final items = [
              (Icons.calendar_today_outlined, const Color(0xFF8B5CF6), 'Reservas hoy', '$reservasHoy'),
              (Icons.inventory_2_outlined, const Color(0xFFF59E0B), 'Pedidos nuevos', '$pedidosHoy'),
              (Icons.receipt_long_outlined, const Color(0xFF3B82F6), 'Facturas emitidas', '$facturasHoy'),
              (Icons.task_alt_rounded, const Color(0xFF22C55E), 'Tareas abiertas', '$tareasAbier'),
            ];
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Grid 2x2 de métricas del día
                Row(children: [
                  Expanded(child: _briefingItem(items[0].$1, items[0].$2, items[0].$3, items[0].$4, text, sub)),
                  const SizedBox(width: 10),
                  Expanded(child: _briefingItem(items[1].$1, items[1].$2, items[1].$3, items[1].$4, text, sub)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _briefingItem(items[2].$1, items[2].$2, items[2].$3, items[2].$4, text, sub)),
                  const SizedBox(width: 10),
                  Expanded(child: _briefingItem(items[3].$1, items[3].$2, items[3].$3, items[3].$4, text, sub)),
                ]),
                const SizedBox(height: 14),
                // Mensaje del día — IA si está configurada, regla-based si no
                _BriefingMensajeIA(
                  reservasHoy: reservasHoy,
                  pedidosHoy: pedidosHoy,
                  facturasHoy: facturasHoy,
                  tareasAbiertas: tareasAbier,
                  facturasPendientes: 0,
                  nombreEmpresa: _nombreEmpresa,
                  fallback: _mensajeBriefing(reservasHoy, pedidosHoy, facturasHoy, tareasAbier),
                ),
              ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _briefingItem(IconData icon, Color color, String label, String valor, Color text, Color sub) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: text)),
            Text(label, style: TextStyle(fontSize: 9.5, color: sub), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      );

  String _mensajeBriefing(int reservas, int pedidos, int facturas, int tareas) {
    if (reservas == 0 && pedidos == 0 && facturas == 0) {
      return 'Hoy no hay registros nuevos todavía. Es un buen momento para planificar el día.';
    }
    final parts = <String>[];
    if (reservas > 0) parts.add('$reservas reserva${reservas > 1 ? 's' : ''}');
    if (pedidos > 0)  parts.add('$pedidos pedido${pedidos > 1 ? 's' : ''}');
    if (facturas > 0) parts.add('$facturas factura${facturas > 1 ? 's' : ''}');
    final actividad = parts.join(', ');
    final tareasMsg = tareas > 0 ? ' Tienes $tareas tarea${tareas > 1 ? 's' : ''} pendiente${tareas > 1 ? 's' : ''} por completar.' : '';
    return 'Hoy llevas $actividad registrada${parts.length > 1 ? 's' : ''}.$tareasMsg';
  }

  Future<Map<String, int>> _cargarResumenHoy(String hoy) async {
    if (_empresaId == null) return {};
    try {
      final ref = FirebaseFirestore.instance.collection('empresas').doc(_empresaId);
      final now = DateTime.now();
      final inicioHoy = DateTime(now.year, now.month, now.day);
      final finHoy    = inicioHoy.add(const Duration(days: 1));
      final tsInicio  = Timestamp.fromDate(inicioHoy);
      final tsFin     = Timestamp.fromDate(finHoy);

      final results = await Future.wait([
        ref.collection('reservas').where('fecha', isGreaterThanOrEqualTo: tsInicio)
            .where('fecha', isLessThan: tsFin).count().get(),
        ref.collection('pedidos').where('fecha_creacion', isGreaterThanOrEqualTo: tsInicio)
            .where('fecha_creacion', isLessThan: tsFin).count().get(),
        ref.collection('facturas').where('fecha_emision', isGreaterThanOrEqualTo: tsInicio)
            .where('fecha_emision', isLessThan: tsFin).count().get(),
        ref.collection('tareas').where('estado', whereIn: ['pendiente', 'enProgreso', 'enRevision']).count().get(),
      ]);
      return {
        'reservas': results[0].count ?? 0,
        'pedidos':  results[1].count ?? 0,
        'facturas': results[2].count ?? 0,
        'tareas':   results[3].count ?? 0,
      };
    } catch (_) {
      return {'reservas': 0, 'pedidos': 0, 'facturas': 0, 'tareas': 0};
    }
  }

  // ── Block 3: Agenda próximos 7 días ──────────────────────────────────────

  Widget _buildAgenda7DiasCard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    final today    = DateTime.now();
    final startDay = DateTime(today.year, today.month, today.day)
        .add(Duration(days: _calendarWeekOffset));
    const dayAbbr  = ['LUN','MAR','MIÉ','JUE','VIE','SÁB','DOM'];
    const monthAbbr = ['Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];
    final accent    = const Color(0xFF4F7CFB);
    final isCurrentWeek = _calendarWeekOffset == 0;

    // ── Botones de navegación ──────────────────────────────────────────────
    Widget navBtn(IconData icon, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(6),
          color: dark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
        ),
        child: Icon(icon, size: 14, color: text),
      ),
    );

    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Cabecera ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
          child: Row(children: [
            Text('Agenda de los próximos 7 días',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: text)),
            const Spacer(),
            // Botón "Hoy"
            if (!isCurrentWeek)
              GestureDetector(
                onTap: () => setState(() => _calendarWeekOffset = 0),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Text('Hoy', style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w600)),
                ),
              ),
            navBtn(Icons.chevron_left_rounded,
                () => setState(() => _calendarWeekOffset -= 7)),
            const SizedBox(width: 4),
            navBtn(Icons.chevron_right_rounded,
                () => setState(() => _calendarWeekOffset += 7)),
          ]),
        ),
        Divider(height: 1, color: border),
        // ── Grid de 7 días ────────────────────────────────────────────────
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas').doc(_empresaId)
              .collection('reservas')
              .where('estado', whereIn: ['pendiente', 'confirmada'])
              .limit(80).snapshots(),
          builder: (_, rSnap) => StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('empresas').doc(_empresaId)
                .collection('tareas')
                .where('estado', whereIn: ['pendiente', 'enProgreso', 'enRevision']).limit(80).snapshots(),
            builder: (_, tSnap) => StreamBuilder<QuerySnapshot>(
              // Eventos del módulo web (agenda Nazarí y cualquier empresa)
              stream: FirebaseFirestore.instance
                  .collection('empresas').doc(_empresaId)
                  .collection('eventos')
                  .where('activo', isEqualTo: true)
                  .where('eliminado', isEqualTo: false)
                  .limit(60).snapshots(),
              builder: (_, eSnap) {
              final todos = <_AgendaEvento>[];

              for (final doc in rSnap.data?.docs ?? []) {
                final d = doc.data() as Map;
                DateTime? dt;
                final f = d['fecha'];
                if (f is Timestamp) dt = f.toDate();
                else if (f is String) dt = DateTime.tryParse(f);
                if (dt == null) continue;
                final nombre = d['nombre'] as String? ?? d['cliente'] as String? ?? 'Reserva';
                final hora   = d['hora'] as String? ?? '';
                todos.add(_AgendaEvento(
                  fecha: dt, titulo: nombre,
                  subtitulo: hora.isNotEmpty ? hora : '',
                  tipo: 'reserva', color: accent,
                  icon: Icons.event_available_outlined,
                ));
              }

              for (final doc in tSnap.data?.docs ?? []) {
                final d = doc.data() as Map;
                final tsLimite = d['fecha_limite'];
                if (tsLimite == null) continue;
                DateTime? dt;
                if (tsLimite is Timestamp) dt = tsLimite.toDate();
                else if (tsLimite is String) dt = DateTime.tryParse(tsLimite);
                if (dt == null) continue;
                final titulo   = d['titulo'] as String? ?? 'Tarea';
                final prioridad = d['prioridad'] as String? ?? 'media';
                final colorT   = prioridad == 'alta' ? const Color(0xFFEF4444)
                    : prioridad == 'media' ? const Color(0xFFF59E0B) : const Color(0xFF22C55E);
                todos.add(_AgendaEvento(
                  fecha: dt, titulo: titulo, subtitulo: '',
                  tipo: 'tarea', color: colorT, icon: Icons.task_alt_rounded,
                ));
              }

              // Eventos del módulo web (presentaciones, ferias, talleres)
              for (final doc in eSnap.data?.docs ?? []) {
                final d = doc.data() as Map;
                final f = d['fecha'];
                DateTime? dt;
                if (f is Timestamp) dt = f.toDate();
                else if (f is String) dt = DateTime.tryParse(f);
                if (dt == null) continue;
                final titulo = d['titulo'] as String? ?? 'Evento';
                final hora   = d['hora'] as String? ?? '';
                todos.add(_AgendaEvento(
                  fecha: dt, titulo: titulo,
                  subtitulo: hora.isNotEmpty ? hora : '',
                  tipo: 'evento', color: const Color(0xFF7C3AED),
                  icon: Icons.event_note_rounded,
                ));
              }

              // Altura adaptada para encajar en el contenedor de 300px del _dashRow
              return SizedBox(
                height: 210,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List.generate(7, (i) {
                    final day = startDay.add(Duration(days: i));
                    final isToday = day.year == today.year &&
                        day.month == today.month && day.day == today.day;
                    final isWeekend = day.weekday == 6 || day.weekday == 7;
                    final dayEvents = todos.where((e) =>
                        e.fecha.year == day.year &&
                        e.fecha.month == day.month &&
                        e.fecha.day == day.day).toList()
                      ..sort((a, b) => a.subtitulo.compareTo(b.subtitulo));
                    final count = dayEvents.length;

                    final colBg = dark
                        ? (isWeekend ? Colors.white.withValues(alpha: 0.015) : Colors.transparent)
                        : (isWeekend ? const Color(0xFFFAFBFF) : Colors.transparent);

                    return Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colBg,
                          border: Border(
                            right: i < 6
                                ? BorderSide(color: border, width: 0.8)
                                : BorderSide.none,
                          ),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // ── Cabecera día ──────────────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 14, 6, 8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(dayAbbr[day.weekday - 1],
                                  style: TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.w700,
                                      color: isWeekend ? accent : sub,
                                      letterSpacing: 0.6)),
                              const SizedBox(height: 4),
                              isToday
                                  ? Container(
                                      width: 30, height: 30,
                                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                      alignment: Alignment.center,
                                      child: Text('${day.day}', style: const TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w900,
                                          color: Colors.white, height: 1)),
                                    )
                                  : Text('${day.day}', style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.w800,
                                      color: isWeekend ? accent : text, height: 1)),
                              const SizedBox(height: 2),
                              Text(monthAbbr[day.month - 1],
                                  style: TextStyle(fontSize: 9, color: sub)),
                            ]),
                          ),
                          // ── Separador ─────────────────────────────────
                          Divider(height: 1, color: border),
                          // ── Conteo ────────────────────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 7, 6, 4),
                            child: Text(
                              count == 0 ? '0 eventos'
                                  : count == 1 ? '1 evento'
                                  : '$count eventos',
                              style: TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w600,
                                  color: count == 0 ? sub : accent),
                            ),
                          ),
                          // ── Lista eventos: "— HH:MM Título" ──────────
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 8, 8),
                              child: count == 0
                                  ? Text('Sin eventos',
                                      style: TextStyle(fontSize: 10, color: sub.withValues(alpha: 0.5)))
                                  : SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: dayEvents.map((ev) {
                                          final tieneHora = ev.subtitulo.isNotEmpty;
                                          // Cada evento: hora en negrita + título en línea nueva
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                if (tieneHora)
                                                  Text(
                                                    ev.subtitulo,
                                                    style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: accent),
                                                  ),
                                                Text(
                                                  ev.titulo,
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: text,
                                                      height: 1.3),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                            ),
                          ),
                        ]),
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ),
      ]),
    );
  }

  // ── Block 10: Tareas pendientes ───────────────────────────────────────────

  Widget _buildTareasPendientesCard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(width: 24, height: 24,
                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.task_alt_rounded, size: 13, color: Color(0xFF8B5CF6))),
            const SizedBox(width: 8),
            Text('Tareas pendientes', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: text)),
            const Spacer(),
            Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () {
                  if (_empresaId == null) return;
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => Container(
                      height: MediaQuery.of(context).size.height * 0.92,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FormularioTareaScreen(
                        empresaId: _empresaId!,
                        usuarioId: FirebaseAuth.instance.currentUser?.uid ?? '',
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 12, color: Color(0xFF3B82F6)),
                    SizedBox(width: 3),
                    Text('Nueva', style: TextStyle(fontSize: 10,
                        fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _moduloDesktopActivo = 'tareas'),
                child: const Text('Ver todas →', style: TextStyle(fontSize: 11,
                    color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
              ),
            ]),
          ]),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas').doc(_empresaId)
              .collection('tareas')
              .where('estado', whereIn: ['pendiente', 'enProgreso', 'enRevision'])
              .limit(6).snapshots(),
          builder: (_, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF22C55E)),
                const SizedBox(width: 8),
                Text('Sin tareas pendientes', style: TextStyle(fontSize: 12, color: sub)),
              ]),
            );
            return Column(children: docs.map((doc) {
              final d       = doc.data() as Map;
              final titulo  = d['titulo'] as String? ?? d['descripcion'] as String? ?? 'Tarea';
              final prioridad = d['prioridad'] as String? ?? 'normal';
              final color   = prioridad == 'alta' ? const Color(0xFFEF4444)
                  : prioridad == 'media' ? const Color(0xFFF59E0B) : const Color(0xFF22C55E);
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: border))),
                child: Row(children: [
                  GestureDetector(
                    onTap: () async {
                      await FirebaseFirestore.instance
                          .collection('empresas').doc(_empresaId)
                          .collection('tareas').doc(doc.id)
                          .update({'estado': 'completada'});
                    },
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                          border: Border.all(color: color, width: 1.5),
                          borderRadius: BorderRadius.circular(4)),
                      child: const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(titulo, style: TextStyle(fontSize: 12, color: text),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  Container(width: 6, height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                ]),
              );
            }).toList());
          },
        ),
      ]),
    );
  }

  // ── Block 11: Actividad reciente ──────────────────────────────────────────

  Widget _buildActividadRecienteCard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    if (_empresaId == null) return const SizedBox.shrink();
    final eid = _empresaId!;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(width: 28, height: 28,
                decoration: BoxDecoration(color: const Color(0xFF14B8A6).withValues(alpha: dark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.timeline_rounded, size: 15, color: Color(0xFF14B8A6))),
            const SizedBox(width: 10),
            Text('Actividad reciente', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
            const Spacer(),
            Text(_formatearFecha(_fechaFiltro),
                style: TextStyle(fontSize: 10.5, color: sub)),
          ]),
        ),
        Builder(builder: (_) {
          final _tsInicio = Timestamp.fromDate(DateTime(_fechaFiltro.year, _fechaFiltro.month, _fechaFiltro.day));
          final _tsFin    = Timestamp.fromDate(DateTime(_fechaFiltro.year, _fechaFiltro.month, _fechaFiltro.day + 1));
          return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('empresas').doc(eid)
              .collection('facturas')
              .where('fecha_creacion', isGreaterThanOrEqualTo: _tsInicio)
              .where('fecha_creacion', isLessThan: _tsFin)
              .orderBy('fecha_creacion', descending: true).limit(10).snapshots(),
          builder: (_, fSnap) => StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('empresas').doc(eid)
                .collection('pedidos')
                .where('fecha_creacion', isGreaterThanOrEqualTo: _tsInicio)
                .where('fecha_creacion', isLessThan: _tsFin)
                .orderBy('fecha_creacion', descending: true).limit(10).snapshots(),
            builder: (_, pSnap) => StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('empresas').doc(eid)
                  .collection('tareas')
                  .where('fecha_creacion', isGreaterThanOrEqualTo: _tsInicio)
                  .where('fecha_creacion', isLessThan: _tsFin)
                  .orderBy('fecha_creacion', descending: true).limit(10).snapshots(),
              builder: (_, tSnap) {
                final eventos = <({String tipo, String desc, String modulo, IconData icon, Color color, Timestamp? ts})>[];

                for (final doc in fSnap.data?.docs ?? []) {
                  final d = doc.data() as Map;
                  final num = d['numero'] as String? ?? d['numero_factura'] as String? ?? '';
                  final cli = d['cliente_nombre'] as String? ?? d['nombre_cliente'] as String? ?? '';
                  eventos.add((
                    tipo: 'Factura', modulo: 'facturacion',
                    desc: num.isNotEmpty && cli.isNotEmpty ? 'Factura $num · $cli'
                        : num.isNotEmpty ? 'Factura $num' : cli.isNotEmpty ? 'Factura a $cli' : 'Factura emitida',
                    icon: Icons.receipt_long_rounded, color: const Color(0xFF3B82F6),
                    ts: d['fecha_creacion'] as Timestamp? ?? d['fecha_emision'] as Timestamp?,
                  ));
                }
                for (final doc in pSnap.data?.docs ?? []) {
                  final d = doc.data() as Map;
                  final cli = d['cliente_nombre'] as String? ?? d['nombre_cliente'] as String? ?? '';
                  final total = (d['total'] as num? ?? 0).toDouble();
                  eventos.add((
                    tipo: 'Pedido', modulo: 'pedidos',
                    desc: cli.isNotEmpty ? 'Pedido de $cli${total > 0 ? ' · ${total.toStringAsFixed(0)}€' : ''}' : 'Nuevo pedido',
                    icon: Icons.inventory_2_rounded, color: const Color(0xFFF59E0B),
                    ts: d['fecha_creacion'] as Timestamp?,
                  ));
                }
                for (final doc in tSnap.data?.docs ?? []) {
                  final d = doc.data() as Map;
                  final tit = d['titulo'] as String? ?? d['nombre'] as String? ?? 'Tarea';
                  eventos.add((
                    tipo: 'Tarea', modulo: 'tareas',
                    desc: tit,
                    icon: Icons.task_alt_rounded, color: const Color(0xFF8B5CF6),
                    ts: d['fecha_creacion'] as Timestamp?,
                  ));
                }

                // Filtrar por fecha seleccionada
                final fechaInicio = DateTime(_fechaFiltro.year, _fechaFiltro.month, _fechaFiltro.day);
                final fechaFin = fechaInicio.add(const Duration(days: 1));
                final filtrados = eventos.where((e) {
                  if (e.ts == null) return false;
                  final dt = e.ts!.toDate();
                  return dt.isAfter(fechaInicio) && dt.isBefore(fechaFin);
                }).toList();

                filtrados.sort((a, b) {
                  if (a.ts == null) return 1;
                  if (b.ts == null) return -1;
                  return b.ts!.compareTo(a.ts!);
                });
                final top = filtrados.take(6).toList();

                if (top.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      const SizedBox(height: 12),
                      Icon(Icons.history_rounded, size: 32, color: sub.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text('Sin actividad este día', style: TextStyle(fontSize: 12.5, color: sub)),
                      const SizedBox(height: 4),
                      Text('Prueba a seleccionar otra fecha', style: TextStyle(fontSize: 11, color: sub.withValues(alpha: 0.6))),
                    ]),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Column(children: top.map((e) {
                    final now = DateTime.now();
                    final dt  = e.ts?.toDate();
                    String tiempo = '—';
                    if (dt != null) {
                      final diff = now.difference(dt);
                      if (diff.inMinutes < 1)       tiempo = 'Ahora';
                      else if (diff.inMinutes < 60) tiempo = 'Hace ${diff.inMinutes}m';
                      else if (diff.inHours < 24)   tiempo = 'Hace ${diff.inHours}h';
                      else                           tiempo = 'Hace ${diff.inDays}d';
                    }
                    return GestureDetector(
                      onTap: () => _abrirModulo(e.modulo),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: dark ? Colors.white.withValues(alpha: 0.04) : e.color.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.07) : e.color.withValues(alpha: 0.12)),
                        ),
                        child: Row(children: [
                          Container(width: 32, height: 32,
                              decoration: BoxDecoration(
                                  color: e.color.withValues(alpha: dark ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(9)),
                              child: Icon(e.icon, size: 16, color: e.color)),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e.desc, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: text),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(e.tipo, style: TextStyle(fontSize: 10, color: e.color, fontWeight: FontWeight.w600)),
                          ])),
                          const SizedBox(width: 8),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(tiempo, style: TextStyle(fontSize: 10, color: sub)),
                            const SizedBox(height: 2),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: sub),
                          ]),
                        ]),
                      ),
                    );
                  }).toList()),
                );
              },
            ),
          ),
        ); }),
      ]),
    );
  }

  // ── Block 12: Objetivos del mes ───────────────────────────────────────────

  Widget _buildObjetivosCard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(width: 24, height: 24,
                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.flag_outlined, size: 13, color: Color(0xFFF59E0B))),
            const SizedBox(width: 8),
            Text('Objetivos del mes', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: text)),
            const Spacer(),
            GestureDetector(
              onTap: () => _editarObjetivos(cardBg, border, text, sub),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    border: Border.all(color: border),
                    borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.edit_outlined, size: 11, color: sub),
                  const SizedBox(width: 4),
                  Text('Editar', style: TextStyle(fontSize: 10, color: sub)),
                ]),
              ),
            ),
          ]),
        ),
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('empresas').doc(_empresaId)
              .collection('config').doc('objetivos').get(),
          builder: (_, cfgSnap) {
            final cfg = cfgSnap.data?.data() as Map<String, dynamic>? ?? {};
            final objFact     = (cfg['facturacion_mes'] as num? ?? 5000).toDouble();
            final objReservas = (cfg['reservas_mes'] as num? ?? 20).toDouble();
            final objSatisfac = (cfg['satisfaccion'] as num? ?? 4.5).toDouble();

            final now = DateTime.now();
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('empresas').doc(_empresaId)
                  .collection('facturas')
                  .where('estado', isEqualTo: 'pagada').snapshots(),
              builder: (_, fSnap) {
                double factMes = 0;
                for (final doc in fSnap.data?.docs ?? []) {
                  final d = doc.data() as Map;
                  final ts = d['fecha_emision'] as Timestamp?;
                  if (ts != null && ts.toDate().month == now.month && ts.toDate().year == now.year) {
                    factMes += (d['total'] as num? ?? 0).toDouble();
                  }
                }
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('empresas').doc(_empresaId)
                      .collection('reservas')
                      .where('estado', whereIn: ['confirmada', 'completada']).snapshots(),
                  builder: (_, rSnap) {
                    final reservasMes = (rSnap.data?.docs ?? []).where((doc) {
                      final d = doc.data() as Map;
                      final ts = d['fecha_creacion'] as Timestamp? ?? d['fecha'] as Timestamp?;
                      return ts != null && ts.toDate().month == now.month && ts.toDate().year == now.year;
                    }).length.toDouble();

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('empresas').doc(_empresaId)
                          .collection('valoraciones').snapshots(),
                      builder: (_, vSnap) {
                        final vDocs = vSnap.data?.docs ?? [];
                        double avgVal = 0;
                        if (vDocs.isNotEmpty) {
                          avgVal = vDocs.fold<double>(0, (s, d) =>
                              s + ((d.data() as Map)['estrellas'] as num? ?? 0).toDouble()) / vDocs.length;
                        }
                        String fmtEuro(double v) => v >= 1000
                            ? '${(v/1000).toStringAsFixed(1)}k€' : '${v.toStringAsFixed(0)}€';
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Column(children: [
                            _objetivoBar('Facturación mes', factMes, objFact,
                                const Color(0xFF22C55E),
                                '${fmtEuro(factMes)} / ${fmtEuro(objFact)}', text, sub),
                            const SizedBox(height: 10),
                            _objetivoBar('Reservas confirmadas', reservasMes, objReservas,
                                const Color(0xFF8B5CF6),
                                '${reservasMes.toInt()} / ${objReservas.toInt()}', text, sub),
                            const SizedBox(height: 10),
                            _objetivoBar('Satisfacción media', avgVal, objSatisfac,
                                const Color(0xFFF59E0B),
                                '${avgVal.toStringAsFixed(1)} / ${objSatisfac.toStringAsFixed(1)} ⭐', text, sub),
                          ]),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ]),
    );
  }

  Future<void> _editarObjetivos(Color cardBg, Color border, Color text, Color sub) async {
    if (_empresaId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('empresas').doc(_empresaId)
        .collection('config').doc('objetivos').get();
    final cfg = doc.data() ?? <String, dynamic>{};

    final factCtrl = TextEditingController(
        text: (cfg['facturacion_mes'] as num? ?? 5000).toStringAsFixed(0));
    final resCtrl  = TextEditingController(
        text: (cfg['reservas_mes'] as num? ?? 20).toString());
    final satCtrl  = TextEditingController(
        text: (cfg['satisfaccion'] as num? ?? 4.5).toStringAsFixed(1));

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.flag_outlined, color: Color(0xFFF59E0B)),
          SizedBox(width: 8),
          Text('Objetivos del mes', style: TextStyle(fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: factCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Facturación objetivo (€)',
                  prefixIcon: Icon(Icons.euro_outlined))),
          const SizedBox(height: 12),
          TextField(controller: resCtrl, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Reservas objetivo',
                  prefixIcon: Icon(Icons.calendar_month_outlined))),
          const SizedBox(height: 12),
          TextField(controller: satCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Satisfacción objetivo (1-5)',
                  prefixIcon: Icon(Icons.star_outline_rounded))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('empresas').doc(_empresaId)
                  .collection('config').doc('objetivos').set({
                'facturacion_mes': double.tryParse(factCtrl.text) ?? 5000,
                'reservas_mes':    int.tryParse(resCtrl.text) ?? 20,
                'satisfaccion':    double.tryParse(satCtrl.text) ?? 4.5,
                'actualizado':     Timestamp.now(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Widget _objetivoBar(String label, double actual, double objetivo, Color color,
      String texto, Color text, Color sub) {
    final pct = objetivo > 0 ? (actual / objetivo).clamp(0.0, 1.0) : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: TextStyle(fontSize: 11, color: sub)),
        const Spacer(),
        Text(texto, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: text)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 7,
          backgroundColor: color.withValues(alpha: 0.12),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }

  // ── Block 13: Estado financiero ───────────────────────────────────────────

  Widget _buildEstadoFinancieroCard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(width: 24, height: 24,
                decoration: BoxDecoration(color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.account_balance_wallet_outlined, size: 13,
                    color: Color(0xFF22C55E))),
            const SizedBox(width: 8),
            Text('Estado financiero', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: text)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _moduloDesktopActivo = 'facturacion'),
              child: const Text('Ver tesorería →', style: TextStyle(fontSize: 11,
                  color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('empresas').doc(_empresaId)
              .collection('facturas').snapshots(),
          builder: (_, fSnap) {
            final now = DateTime.now();
            double ingresosMes = 0;
            int pendientesCount = 0;
            for (final doc in fSnap.data?.docs ?? []) {
              final d = doc.data() as Map;
              final estado = d['estado'] as String? ?? '';
              final total  = (d['total'] as num? ?? d['importe'] as num? ?? 0).toDouble();
              if (estado == 'pagada' || estado == 'cobrada') {
                final ts = d['fecha_emision'] as Timestamp? ?? d['fecha_pago'] as Timestamp?;
                if (ts != null && ts.toDate().month == now.month) ingresosMes += total;
              } else if (estado == 'pendiente' || estado == 'enviada') {
                pendientesCount++;
              }
            }
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('empresas').doc(_empresaId)
                  .collection('gastos').snapshots(),
              builder: (_, gSnap) {
                double gastosMes = 0;
                for (final doc in gSnap.data?.docs ?? []) {
                  final d = doc.data() as Map;
                  final importe = (d['total'] as num? ?? d['base_imponible'] as num? ?? 0).toDouble();
                  final ts = d['fecha_gasto'] as Timestamp?
                      ?? d['fecha_pago'] as Timestamp?
                      ?? d['fecha_creacion'] as Timestamp?;
                  if (ts != null && ts.toDate().month == now.month && ts.toDate().year == now.year) {
                    gastosMes += importe;
                  }
                }
                final neto = ingresosMes - gastosMes;
                final esPositivo = neto >= 0;
                String fmtMes(double v) => v >= 1000 ? '${(v/1000).toStringAsFixed(1)}k€' : '${v.toStringAsFixed(0)}€';
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Column(children: [
                    // Resultado neto del mes (destacado)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: (esPositivo ? const Color(0xFF22C55E) : const Color(0xFFEF4444))
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: (esPositivo
                            ? const Color(0xFF22C55E) : const Color(0xFFEF4444)).withValues(alpha: 0.2)),
                      ),
                      child: Column(children: [
                        Text('Resultado neto este mes', style: TextStyle(fontSize: 10, color: sub)),
                        const SizedBox(height: 4),
                        Text(
                          '${esPositivo ? '+' : ''}${fmtMes(neto)}',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                              color: esPositivo ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _finRow(Icons.trending_up_rounded, const Color(0xFF22C55E),
                        'Ingresos mes', fmtMes(ingresosMes), text, sub),
                    const SizedBox(height: 8),
                    _finRow(Icons.trending_down_rounded, const Color(0xFFEF4444),
                        'Gastos mes', fmtMes(gastosMes), text, sub),
                    const SizedBox(height: 8),
                    _finRow(Icons.receipt_long_outlined, const Color(0xFFF59E0B),
                        'Por cobrar', '$pendientesCount facturas', text, sub),
                  ]),
                );
              },
            );
          },
        ),
      ]),
    );
  }

  Widget _finRow(IconData icon, Color color, String label, String valor, Color text, Color sub) =>
      Row(children: [
        Container(width: 28, height: 28,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, size: 13, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: sub))),
        Text(valor, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text)),
      ]);

  // ── Block 14: Rendimiento empleados ───────────────────────────────────────

  Widget _buildRendimientoEmpleadosCard(bool dark, Color cardBg, Color border, Color text, Color sub) {
    return Container(
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(width: 24, height: 24,
                decoration: BoxDecoration(color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.groups_outlined, size: 13, color: Color(0xFF8B5CF6))),
            const SizedBox(width: 8),
            Text('Equipo hoy', style: TextStyle(fontSize: 13,
                fontWeight: FontWeight.w700, color: text)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _moduloDesktopActivo = 'personal'),
              child: const Text('RRHH →', style: TextStyle(fontSize: 11,
                  color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('usuarios')
              .where('empresa_id', isEqualTo: _empresaId)
              .where('rol', whereIn: ['propietario', 'admin', 'staff']).snapshots(),
          builder: (_, snap) {
            final docs    = snap.data?.docs ?? [];
            final activos = docs.where((d) => (d.data() as Map)['activo'] == true
                && (d.data() as Map)['estado'] != 'vacaciones'
                && (d.data() as Map)['activo'] != false).toList();
            final vacac   = docs.where((d) => (d.data() as Map)['estado'] == 'vacaciones').toList();
            final bajas   = docs.where((d) => (d.data() as Map)['activo'] == false).toList();
            final total   = docs.length;
            final presencia = total > 0 ? (activos.length * 100 ~/ total) : 0;

            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(children: [
                // Fila superior: tasa + avatares
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  // Indicador de presencia (visual circular)
                  SizedBox(width: 72, height: 72, child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(width: 72, height: 72,
                        child: CircularProgressIndicator(
                          value: presencia / 100,
                          strokeWidth: 7,
                          backgroundColor: const Color(0xFF22C55E).withValues(alpha: 0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
                        ),
                      ),
                      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('$presencia%', style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w800, color: text)),
                        Text('presencia', style: TextStyle(fontSize: 8, color: sub)),
                      ]),
                    ],
                  )),
                  const SizedBox(width: 14),
                  // Stats verticales
                  Expanded(child: Column(children: [
                    _empStatRow(Icons.check_circle_outline, const Color(0xFF22C55E),
                        'Activos', '${activos.length}', text, sub),
                    const SizedBox(height: 6),
                    _empStatRow(Icons.beach_access_outlined, const Color(0xFFF59E0B),
                        'Vacaciones', '${vacac.length}', text, sub),
                    const SizedBox(height: 6),
                    _empStatRow(Icons.sick_outlined, const Color(0xFFEF4444),
                        'De baja', '${bajas.length}', text, sub),
                    const SizedBox(height: 6),
                    _empStatRow(Icons.people_alt_outlined, const Color(0xFF3B82F6),
                        'Total', '$total', text, sub),
                  ])),
                ]),
                // Avatares de empleados activos
                if (activos.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Activos hoy', style: TextStyle(fontSize: 9.5,
                        fontWeight: FontWeight.w700, color: sub, letterSpacing: 0.3)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6,
                    children: activos.take(8).map((doc) {
                      final d = doc.data() as Map;
                      final nombre = d['nombre'] as String? ?? '?';
                      final ini    = nombre.trim().isNotEmpty ? nombre.trim()[0].toUpperCase() : '?';
                      final fotoUrl = d['foto_url'] as String?;
                      return Tooltip(
                        message: nombre,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                          child: fotoUrl == null ? Text(ini, style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold,
                              color: Color(0xFF3B82F6))) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  if (activos.length > 8)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('+${activos.length - 8} más',
                          style: TextStyle(fontSize: 10, color: sub)),
                    ),
                ],
                // Fichajes del día
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('empresas').doc(_empresaId)
                      .collection('fichajes')
                      .where('fecha', isEqualTo: () {
                        final n = DateTime.now();
                        return '${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')}';
                      }()).snapshots(),
                  builder: (_, fSnap) {
                    final fichados = fSnap.data?.docs.length ?? 0;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6).withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.fingerprint_rounded, size: 14, color: Color(0xFF14B8A6)),
                        const SizedBox(width: 8),
                        Expanded(child: Text('$fichados de ${activos.length} han fichado hoy',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF14B8A6),
                                fontWeight: FontWeight.w600))),
                        if (activos.isNotEmpty)
                          Text('${(fichados * 100 / (activos.isNotEmpty ? activos.length : 1)).round()}%',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                  color: Color(0xFF14B8A6))),
                      ]),
                    );
                  },
                ),
              ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _empStatRow(IconData icon, Color color, String label, String val, Color text, Color sub) =>
      Row(children: [
        Container(width: 22, height: 22,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Icon(icon, size: 11, color: color)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: sub))),
        Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text)),
      ]);

  Widget _buildDesktopRightPanel(bool dark) {
    final bg     = dark ? const Color(0xFF111827) : Colors.white;
    final border = dark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200;
    final text   = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub    = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final acciones = [
      _QuickActionData(Icons.receipt_long_rounded, const Color(0xFF3B82F6), 'Nueva factura', 'facturacion'),
      _QuickActionData(Icons.people_alt_rounded, const Color(0xFF10B981), 'Nuevo cliente', 'clientes'),
      _QuickActionData(Icons.inventory_2_rounded, const Color(0xFFF59E0B), 'Nuevo pedido', 'pedidos'),
      _QuickActionData(Icons.task_alt_rounded, const Color(0xFF8B5CF6), 'Nueva tarea', 'tareas'),
      _QuickActionData(Icons.badge_rounded, const Color(0xFF6366F1), 'Nuevo empleado', 'empleados'),
    ];
    return Container(
      decoration: BoxDecoration(
          color: bg, border: Border(left: BorderSide(color: border))),
      child: Column(children: [
        // ── KPIs en 2 filas (arriba, fijo) ───────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          child: _buildKpiCarouselDoble(dark, text, sub),
        ),
        Divider(height: 1, color: border),
        // ── Selector de pestaña ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          child: Row(children: [
            _rightPanelTabChip('Actividad', 'inicio', dark, border),
            const SizedBox(width: 6),
            _rightPanelTabChip('Fiscal', 'fiscal', dark, border),
          ]),
        ),
        Divider(height: 1, color: border),
        // ── Contenido según pestaña ───────────────────────────────────────
        if (_rightPanelTab == 'fiscal')
          Expanded(child: _buildRightPanelFiscal(dark, text, sub, border))
        else ...[
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(children: [
                  Container(width: 6, height: 6,
                      decoration: const BoxDecoration(color: Color(0xFF14B8A6), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('Actividad reciente',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text)),
                ]),
              ),
              Expanded(child: _buildActividadRecientePanelDesktop(dark, text, sub, border)),
            ]),
          ),
          // ── Acciones rápidas (fijas abajo) ──────────────────────────────
          Divider(height: 1, color: border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Acciones rápidas',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text)),
              ]),
              const SizedBox(height: 8),
              ...acciones.map((qa) => InkWell(
                onTap: () => _abrirModulo(qa.moduloId),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(children: [
                    Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(
                        color: qa.color.withValues(alpha: dark ? 0.14 : 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(qa.icon, color: qa.color, size: 13),
                    ),
                    const SizedBox(width: 8),
                    Text('+ ${qa.label}',
                        style: TextStyle(fontSize: 12, color: qa.color, fontWeight: FontWeight.w500)),
                  ]),
                ),
              )),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _rightPanelTabChip(String label, String tab, bool dark, Color border) {
    final sel = _rightPanelTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _rightPanelTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? const Color(0xFF3B82F6) : border),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11,
          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
          color: sel ? Colors.white : (dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
        )),
      ),
    );
  }

  Widget _buildRightPanelFiscal(bool dark, Color text, Color sub, Color border) {
    final year = DateTime.now().year;
    final now  = DateTime.now();
    final plazos = [
      _FiscalPlazo('303 — IVA',  'T1  Ene/Mar', DateTime(year, 4, 20),     const Color(0xFF3B82F6)),
      _FiscalPlazo('303 — IVA',  'T2  Abr/Jun', DateTime(year, 7, 20),     const Color(0xFF3B82F6)),
      _FiscalPlazo('303 — IVA',  'T3  Jul/Sep', DateTime(year, 10, 20),    const Color(0xFF3B82F6)),
      _FiscalPlazo('303 — IVA',  'T4  Oct/Dic', DateTime(year + 1, 1, 30), const Color(0xFF3B82F6)),
      _FiscalPlazo('130 — IRPF', 'T1  Ene/Mar', DateTime(year, 4, 20),     const Color(0xFF8B5CF6)),
      _FiscalPlazo('130 — IRPF', 'T2  Abr/Jun', DateTime(year, 7, 20),     const Color(0xFF8B5CF6)),
      _FiscalPlazo('130 — IRPF', 'T3  Jul/Sep', DateTime(year, 10, 20),    const Color(0xFF8B5CF6)),
      _FiscalPlazo('111 — Ret.',  'T1  Ene/Mar', DateTime(year, 4, 20),     const Color(0xFF10B981)),
      _FiscalPlazo('111 — Ret.',  'T2  Abr/Jun', DateTime(year, 7, 20),     const Color(0xFF10B981)),
      _FiscalPlazo('111 — Ret.',  'T3  Jul/Sep', DateTime(year, 10, 20),    const Color(0xFF10B981)),
      _FiscalPlazo('390 — IVA Anual', 'Antes 30 Ene', DateTime(year + 1, 1, 30), const Color(0xFF0EA5E9)),
    ];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Row(children: [
          Container(width: 6, height: 6,
              decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Modelos Fiscales $year',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: text)),
          const Spacer(),
          GestureDetector(
            onTap: () => _abrirModulo('facturacion'),
            child: const Text('Ver →',
                style: TextStyle(fontSize: 10, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
      Expanded(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          itemCount: plazos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 5),
          itemBuilder: (_, i) {
            final p = plazos[i];
            final dias = p.plazo.difference(now).inDays;
            final vencido = dias < 0;
            final proximo = !vencido && dias <= 20;
            final alertColor = vencido
                ? const Color(0xFFEF4444)
                : proximo
                    ? const Color(0xFFF59E0B)
                    : p.color;
            final textoFecha =
                '${p.plazo.day.toString().padLeft(2, '0')}/${p.plazo.month.toString().padLeft(2, '0')}';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: alertColor.withValues(alpha: dark ? 0.08 : 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: alertColor.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.modelo,
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: alertColor)),
                  Text(p.periodo,
                      style: TextStyle(fontSize: 9.5, color: sub)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(textoFecha,
                      style: TextStyle(fontSize: 10, color: text, fontWeight: FontWeight.w600)),
                  Text(
                    vencido ? 'Vencido' : '$dias d.',
                    style: TextStyle(fontSize: 9, color: alertColor, fontWeight: FontWeight.w700),
                  ),
                ]),
              ]),
            );
          },
        ),
      ),
    ]);
  }

  // ── Carrusel doble: 2 chips lado a lado, cada uno avanza por 3 KPIs ─────

  // El carrusel KPI es un StatefulWidget aislado para que su timer
  // no provoque rebuilds del dashboard entero.
  Widget _buildKpiCarouselDoble(bool dark, Color text, Color sub) =>
      _KpiCarouselDoble(
        dark: dark, text: text, sub: sub,
        streamFacturas:  _streamFacturasPendientes(),
        streamClientes:  _streamTotalClientes(),
        streamPedidos:   _streamPedidosActivos(),
        streamTareas:    _streamTareasPendientes(),
        streamEmpleados: _streamEmpleadosActivos(),
        streamReservas:  _streamReservasHoy(),
      );

  // ── Actividad reciente real (panel derecho desktop) ───────────────────────

  Widget _buildActividadRecientePanelDesktop(bool dark, Color text, Color sub, Color border) {
    if (_empresaId == null) return const SizedBox.shrink();
    final eid = _empresaId!;
    final ahora = DateTime.now();
    final tsInicio = Timestamp.fromDate(DateTime(ahora.year, ahora.month, ahora.day));
    final tsFin    = Timestamp.fromDate(DateTime(ahora.year, ahora.month, ahora.day + 1));

    final db = FirebaseFirestore.instance;
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('empresas').doc(eid).collection('facturas')
          .where('fecha_creacion', isGreaterThanOrEqualTo: tsInicio)
          .where('fecha_creacion', isLessThan: tsFin)
          .orderBy('fecha_creacion', descending: true).limit(5).snapshots(),
      builder: (_, fSnap) => StreamBuilder<QuerySnapshot>(
        stream: db.collection('empresas').doc(eid).collection('pedidos')
            .where('fecha_creacion', isGreaterThanOrEqualTo: tsInicio)
            .where('fecha_creacion', isLessThan: tsFin)
            .orderBy('fecha_creacion', descending: true).limit(5).snapshots(),
        builder: (_, pSnap) => StreamBuilder<QuerySnapshot>(
          stream: db.collection('empresas').doc(eid).collection('tareas')
              .where('fecha_creacion', isGreaterThanOrEqualTo: tsInicio)
              .where('fecha_creacion', isLessThan: tsFin)
              .orderBy('fecha_creacion', descending: true).limit(5).snapshots(),
          builder: (_, tSnap) => StreamBuilder<QuerySnapshot>(
            // Nuevos clientes creados hoy (web, reserva o manual)
            stream: db.collection('empresas').doc(eid).collection('clientes')
                .where('fecha_registro', isGreaterThanOrEqualTo: tsInicio)
                .where('fecha_registro', isLessThan: tsFin)
                .orderBy('fecha_registro', descending: true).limit(5).snapshots(),
            builder: (_, cSnap) => StreamBuilder<QuerySnapshot>(
              // Reservas de hoy
              stream: db.collection('empresas').doc(eid).collection('reservas')
                  .where('creado_en', isGreaterThanOrEqualTo: tsInicio)
                  .where('creado_en', isLessThan: tsFin)
                  .orderBy('creado_en', descending: true).limit(5).snapshots(),
              builder: (_, rSnap) {
                // tipo: (icono, color, descripción, tiempo, orden)
                final items = <(IconData, Color, String, String, DateTime)>[];

                // Facturas
                for (final doc in fSnap.data?.docs ?? []) {
                  final d = doc.data() as Map;
                  final num = d['numero'] as String? ?? '';
                  final cli = d['cliente_nombre'] as String? ?? d['nombre_cliente'] as String? ?? '';
                  final ts  = (d['fecha_creacion'] as Timestamp?)?.toDate() ?? ahora;
                  items.add((Icons.receipt_long_rounded, const Color(0xFF3B82F6),
                      num.isNotEmpty
                          ? 'Factura $num${cli.isNotEmpty ? ' · $cli' : ''}'
                          : cli.isNotEmpty ? 'Factura · $cli' : 'Factura emitida',
                      _tiempoRelativo(ts), ts));
                }

                // Pedidos
                for (final doc in pSnap.data?.docs ?? []) {
                  final d = doc.data() as Map;
                  final cli = d['cliente_nombre'] as String? ?? d['nombre_cliente'] as String? ?? '';
                  final ts  = (d['fecha_creacion'] as Timestamp?)?.toDate() ?? ahora;
                  items.add((Icons.inventory_2_rounded, const Color(0xFFF59E0B),
                      cli.isNotEmpty ? 'Pedido · $cli' : 'Nuevo pedido',
                      _tiempoRelativo(ts), ts));
                }

                // Tareas
                for (final doc in tSnap.data?.docs ?? []) {
                  final d = doc.data() as Map;
                  final ts  = (d['fecha_creacion'] as Timestamp?)?.toDate() ?? ahora;
                  items.add((Icons.task_alt_rounded, const Color(0xFF8B5CF6),
                      d['titulo'] as String? ?? 'Tarea',
                      _tiempoRelativo(ts), ts));
                }

                // Nuevos clientes — "Nuevo cliente: [Nombre]"
                for (final doc in cSnap.data?.docs ?? []) {
                  final d = doc.data() as Map;
                  final nombre = d['nombre'] as String? ?? 'Sin nombre';
                  final ts = (d['fecha_registro'] as Timestamp?)?.toDate() ?? ahora;
                  items.add((Icons.person_add_alt_1_rounded, const Color(0xFF10B981),
                      'Nuevo cliente: $nombre', _tiempoRelativo(ts), ts));
                }

                // Reservas web o internas
                for (final doc in rSnap.data?.docs ?? []) {
                  final d = doc.data() as Map;
                  final cli   = d['nombre'] as String? ?? d['cliente'] as String? ?? '';
                  final hora  = d['hora'] as String? ?? '';
                  final ts    = (d['creado_en'] as Timestamp?)?.toDate() ?? ahora;
                  items.add((Icons.event_available_outlined, const Color(0xFF8B5CF6),
                      cli.isNotEmpty
                          ? 'Reserva: $cli${hora.isNotEmpty ? ' · $hora' : ''}'
                          : 'Nueva reserva',
                      _tiempoRelativo(ts), ts));
                }

                if (items.isEmpty) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.history_rounded, size: 28, color: sub.withValues(alpha: 0.3)),
                      const SizedBox(height: 8),
                      Text('Sin actividad hoy', style: TextStyle(fontSize: 12, color: sub)),
                    ]),
                  ));
                }

                // Ordenar por tiempo real (más reciente primero)
                items.sort((a, b) => b.$5.compareTo(a.$5));

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  itemCount: items.take(8).length,
                  itemBuilder: (_, i) {
                    final e = items[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Container(width: 28, height: 28,
                            decoration: BoxDecoration(
                                color: e.$2.withValues(alpha: 0.10), shape: BoxShape.circle),
                            child: Icon(e.$1, color: e.$2, size: 13)),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.$3,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: text),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(e.$4, style: TextStyle(fontSize: 10, color: sub)),
                        ])),
                      ]),
                    );
                  },
                );
              },
            ),
          ),
        ),
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
    final isCarpeta  = t.id == 'carpeta';

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

  // ── Hub de Personal en móvil (igual estilo que _mostrarCarpeta) ─────────────
  void _mostrarPersonal(bool dark) {
    final folderBg     = dark ? const Color(0xFF0B0E18) : Colors.white;
    final folderBorder = dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06);
    final textColor    = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);

    const tiles = [
      _AppTile('empleados',  Icons.badge_rounded,         'Empleados',  Color(0xFF8B5CF6)),
      _AppTile('fichaje',    Icons.schedule_rounded,       'Fichajes',   Color(0xFF14B8A6)),
      _AppTile('vacaciones', Icons.beach_access_rounded,   'Vacaciones', Color(0xFF0EA5E9)),
      _AppTile('nominas',    Icons.payments_rounded,       'Nóminas',    Color(0xFF10B981)),
    ];

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: folderBg, borderRadius: BorderRadius.circular(28),
            border: Border.all(color: folderBorder),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.6 : 0.12),
                blurRadius: 60, offset: const Offset(0, 20))],
          ),
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Personal', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
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

  void _mostrarCarpeta(bool dark) {
    final folderBg = dark ? const Color(0xFF0B0E18) : Colors.white;
    final folderBorder = dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06);
    final textColor = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final esPropietario   = _sesion?.esPropietario == true;
    final _propEfectivo   = _sesionEfectiva?.esPropietarioPlatforma == true && _rolVistaActual == null;
    final _folderModulos  = _suscripcionService.getModulosActivos();
    const _folderAliases  = <String,String>{'personal':'empleados','web':'contenido_web'};
    final tiles = _kFolderTiles.where((t) {
      if (t.id == 'propietario') return esPropietario;
      if (_propEfectivo) return true;
      final pid = _folderAliases[t.id] ?? t.id;
      return _folderModulos.contains(pid) || _folderModulos.contains(t.id);
    }).toList();

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
    // Panel layout (tablet + desktop): renderizar inline con sidebar fija.
    final isDesktop = MediaQuery.of(context).size.width >= 640;
    if (isDesktop) {
      // Limpiar acciones del módulo anterior al cambiar de módulo
      context.read<FluixModuleActionsNotifier>().reset();
      // perfil y carpeta se muestran inline sin necesitar empresaId
      if (id == 'perfil')  { setState(() => _moduloDesktopActivo = 'perfil');  return; }
      if (id == 'carpeta') { setState(() => _moduloDesktopActivo = 'mas');     return; }
      if (_empresaId == null) return;
      // 'empleados' desde accesos rápidos → sección personal
      setState(() => _moduloDesktopActivo = id == 'empleados' ? 'personal' : id);
      return;
    }

    // En móvil, 'personal' abre el hub con los sub-módulos (igual que 'carpeta')
    if (id == 'personal') { _mostrarPersonal(_darkMode); return; }

    if (_empresaId == null && id != 'perfil') return;
    final eid = _empresaId ?? '';
    final ses = _sesionEfectiva;
    Widget? screen;
    switch (id) {
      case 'dashboard':
        screen = Scaffold(
          backgroundColor: _darkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          appBar: AppBar(
            title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: _darkMode ? const Color(0xFF111827) : Colors.white,
            foregroundColor: _darkMode ? Colors.white : const Color(0xFF0F172A),
            elevation: 0,
            surfaceTintColor: Colors.transparent,
          ),
          body: _buildDashboardHome(_darkMode),
        );
        break;
      case 'facturacion':    screen = ModuloFacturacionScreen(empresaId: eid); break;
      case 'contabilidad':   screen = PantallaContabilidad(empresaId: eid); break;
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
      case 'cuentas':        screen = GestionarCuentasScreen(sesion: _sesion); break;
      case 'perfil':         screen = PantallaPerfil(sesion: _sesion, dark: _darkMode); break;
      case 'reservas':       screen = ModuloReservasScreen(empresaId: eid, sesion: ses); break;
      case 'valoraciones':   screen = ModuloValoraciones(empresaId: eid); break;
      case 'fichaje':        screen = GestionFichajesScreen(empresaId: eid, esAdmin: ses?.esAdmin ?? false); break;
      case 'vacaciones':     screen = VacacionesScreen(empresaId: eid, sesion: ses); break;
      case 'nominas':
        screen = (ses != null && !ses.esAdmin)
            ? MisNominasScreen(empresaId: eid)
            : ModuloNominasScreen(empresaId: eid);
        break;
      case 'servicios':      screen = ModuloServiciosScreen(empresaId: eid, sesion: ses); break;
      case 'plantillas_pdf': screen = PdfTemplatesListScreen(empresaId: eid); break;
      case 'propietario':    screen = _sesion?.esPropietario == true ? const ModuloPropietario() : null; break;
      case 'grafo_app':      screen = _sesion?.esPropietarioPlatforma == true ? const PantallaGrafoApp() : null; break;
      default: return;
    }
    if (screen == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => FluixModuleShell(child: screen!, empresaId: eid),
    )).then((_) {
      // Al volver del módulo, limpiar las acciones inyectadas
      if (mounted) context.read<FluixModuleActionsNotifier>().reset();
    });
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
                                onEmbedReady: (a) => setState(() => _tpvActions = a),
                                onDispose: () { if (mounted) setState(() => _tpvActions = null); },
                              );
      case 'whatsapp':        return ModuloWhatsAppScreen(empresaId: id);
      case 'contabilidad':    return PantallaContabilidad(empresaId: id, initialTab: 0);
      case 'facturacion':     return ModuloFacturacionScreen(
                                empresaId: id,
                                onOpenContabilidad: () => setState(() => _moduloDesktopActivo = 'contabilidad'),
                              );
      case 'empleados':       return ModuloEmpleadosScreen(empresaId: id, sesion: sesionActiva);
      case 'clientes':        return ModuloClientesScreen(empresaId: id, sesion: sesionActiva);
      case 'servicios':       return ModuloServiciosScreen(empresaId: id, sesion: sesionActiva);
      case 'nominas':
        // Staff ve solo sus propias nóminas; admin/propietario ve el módulo completo
        if (sesionActiva != null && !sesionActiva.esAdmin) {
          return MisNominasScreen(empresaId: id);
        }
        return ModuloNominasScreen(empresaId: id);
      case 'fichaje':         return _construirPantallaFichaje();
      case 'vacaciones':      return VacacionesScreen(empresaId: id, sesion: sesionActiva);
      case 'web':             return _buildVistaWeb();
      case 'app':             return ModuloAppScreen(empresaId: id);
      case 'plantillas_pdf':  return PdfTemplatesListScreen(empresaId: id);
      case 'soporte':         return ModuloSoporteScreen(
                                empresaId: _empresaId ?? '',
                                nombreEmpresa: _nombreEmpresa,
                                autorUid: _sesion?.uid ?? '',
                              );
      case 'grafo_app':       return _sesion?.esPropietarioPlatforma == true ? const PantallaGrafoApp() : const Center(child: Text('Sin acceso'));
      case 'cuentas':         return _sesion?.esPropietarioPlatforma == true ? GestionarCuentasScreen(sesion: _sesion) : const Center(child: Text('Sin acceso'));
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
          // Botón reordenar widgets
          GestureDetector(
            onTap: () => setState(() => _editandoDashboard = !_editandoDashboard),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _editandoDashboard
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  _editandoDashboard ? Icons.check_rounded : Icons.drag_indicator_rounded,
                  size: 15,
                  color: _editandoDashboard ? const Color(0xFF1976D2) : Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  _editandoDashboard ? 'Listo' : 'Organizar',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: _editandoDashboard ? const Color(0xFF1976D2) : Colors.white,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 6),
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
        FluxToast.exito(context, 'Datos demo completos generados correctamente');
      }
    } catch (e) {
      if (mounted) {
        FluxToast.error(context, 'Error generando datos: $e');
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

  Future<void> _abrirSelectorEmpresa(bool dark) async {
    final TextEditingController busqCtrl = TextEditingController();
    List<QueryDocumentSnapshot> todas = [];
    List<QueryDocumentSnapshot> filtradas = [];

    try {
      final snap = await FirebaseFirestore.instance.collection('empresas').get();
      todas = snap.docs;
      filtradas = todas;
      // Guardar el recuento para que FluixAppBar pueda mostrar/ocultar el botón
      AppSettings.setNumEmpresas(todas.length);
    } catch (_) {
      if (!mounted) return;
      FluxToast.aviso(context, 'No se pudo cargar la lista de empresas');
      return;
    }

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModal) => AlertDialog(
          backgroundColor: dark ? const Color(0xFF1A1F33) : Colors.white,
          title: Row(children: [
            const Icon(Icons.business_rounded, size: 20),
            const SizedBox(width: 8),
            const Text('Seleccionar empresa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (_empresaId != _empresaIdPropia)
              TextButton.icon(
                icon: const Icon(Icons.home_rounded, size: 14),
                label: const Text('Mi empresa', style: TextStyle(fontSize: 12)),
                onPressed: () async {
                  Navigator.pop(ctx2);
                  final propiaId = _empresaIdPropia;
                  if (propiaId == null) return;
                  final empDoc = await FirebaseFirestore.instance.collection('empresas').doc(propiaId).get();
                  final nombre = empDoc.data()?['perfil']?['nombre'] ?? empDoc.data()?['nombre'] ?? '';
                  if (mounted) setState(() { _empresaId = propiaId; _nombreEmpresa = nombre.toString(); });
                },
              ),
          ]),
          content: SizedBox(
            width: 400, height: 450,
            child: Column(children: [
              TextField(
                controller: busqCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar empresa...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                onChanged: (v) => setModal(() {
                  filtradas = todas.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    final nombre = ((data['perfil']?['nombre'] ?? data['nombre'] ?? '') as String).toLowerCase();
                    return nombre.contains(v.toLowerCase());
                  }).toList();
                }),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: filtradas.length,
                  itemBuilder: (_, i) {
                    final data = filtradas[i].data() as Map<String, dynamic>;
                    final nombre = data['perfil']?['nombre'] ?? data['nombre'] ?? filtradas[i].id;
                    final esActual = filtradas[i].id == _empresaId;
                    return ListTile(
                      dense: true,
                      selected: esActual,
                      selectedTileColor: const Color(0xFF00FFC8).withValues(alpha: 0.1),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: esActual ? const Color(0xFF00FFC8) : Colors.grey.shade200,
                        child: Text(nombre.toString().substring(0, 1).toUpperCase(),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                color: esActual ? Colors.black : Colors.grey.shade700)),
                      ),
                      title: Text(nombre.toString(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(filtradas[i].id, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      trailing: esActual ? const Icon(Icons.check_circle, size: 16, color: Color(0xFF00FFC8)) : null,
                      onTap: () async {
                        Navigator.pop(ctx2);
                        final id = filtradas[i].id;
                        if (mounted) setState(() { _empresaId = id; _nombreEmpresa = nombre.toString(); });
                      },
                    );
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    busqCtrl.dispose();
  }

  void _manejarMenu(String accion) {
    switch (accion) {
      case 'perfil':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaPerfil(sesion: _sesion, dark: _darkMode),
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
    return PantallaContenidoWeb(
      empresaId: _empresaId!,
      onSubModuloChanged: (sub) => setState(() => _webSubModulo = sub),
      volverAlHub: _webVolverAlHub,
    );
  }

  /// Activa/desactiva el módulo web desde el dashboard
  void _toggleContenidoWeb() async {
    if (_empresaId == null) return;
    try {
      final modulos = await _widgetService.obtenerTodosModulos(_empresaId!).first;
      final webActivo = modulos.any((m) => m.id == 'web' && m.activo);
      await _widgetService.toggleModulo(_empresaId!, 'web', !webActivo);
      if (mounted) {
        if (!webActivo) {
          FluxToast.exito(context, 'Contenido web activado');
        } else {
          FluxToast.aviso(context, 'Contenido web desactivado');
        }
      }
    } catch (e) {
      if (mounted) {
        FluxToast.error(context, 'Error: $e');
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
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Row(children: [
                      Icon(Icons.inventory_2_outlined, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Stock bajo'),
                    ]),
                    content: SizedBox(
                      width: 320,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: productos.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final p = productos[i];
                          final stock = p['stock'] ?? 0;
                          final min = p['stock_minimo'] ?? 0;
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 20),
                            title: Text(p['nombre'] ?? '',
                                style: const TextStyle(fontSize: 13)),
                            trailing: Text('$stock / $min',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.red,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('Stock actual / Mínimo',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey[500])),
                          );
                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cerrar')),
                    ],
                  ),
                ),
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
  final void Function(TpvEmbedActions)? onEmbedReady;
  final VoidCallback? onDispose;

  const _LanzadorTpv({
    required this.empresaId,
    this.esAdmin = false,
    this.esPropietario = false,
    this.esPropietarioPlatforma = false,
    this.propietarioUid = '',
    this.onEmbedReady,
    this.onDispose,
  });

  @override
  State<_LanzadorTpv> createState() => _LanzadorTpvState();
}

class _LanzadorTpvState extends State<_LanzadorTpv> {
  late final Future<String> _tipoTpvFuture;
  // Sub-navegación interna: null = mostrar selector (propietario) o cargando
  String? _empresaActivaId;
  String? _tipoActivo;
  bool _haLanzadoLegacy = false;

  @override
  void initState() {
    super.initState();
    if (widget.esPropietario || widget.esPropietarioPlatforma) {
      _tipoTpvFuture = Future.value('selector');
    } else {
      _tipoTpvFuture = _leerTipoTpv();
    }
  }

  @override
  void dispose() {
    // Avisar al dashboard para que limpie _tpvActions (evita usar notifier dispuesto)
    widget.onDispose?.call();
    super.dispose();
  }

  Future<String> _leerTipoTpv() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId).get();
      return snap.data()?['tipo_tpv'] as String? ?? 'bar';
    } catch (_) {
      return 'bar';
    }
  }

  /// Llamado desde el selector cuando el propietario elige un negocio.
  void _onEmpresaSeleccionada(String empresaId, String tipoTpv) {
    // Todos los tipos soportados en modo embebido
    setState(() { _empresaActivaId = empresaId; _tipoActivo = tipoTpv; });
  }

  Future<void> _abrirTpvLegacy(String empresaId, String tipoTpv) async {
    if (!mounted || _haLanzadoLegacy) return;
    _haLanzadoLegacy = true;

    Widget tpvScreen;
    switch (tipoTpv) {
      case 'peluqueria_estetica':
        tpvScreen = TpvPeluqueriaScreen(
            empresaId: empresaId,
            esAdmin: widget.esAdmin || widget.esPropietario,
            esPropietario: widget.esPropietario || widget.esPropietarioPlatforma);
        break;
      default:
        tpvScreen = TpvRootScreen(
            empresaId: empresaId,
            esAdmin: widget.esAdmin || widget.esPropietario,
            esPropietario: widget.esPropietario || widget.esPropietarioPlatforma);
    }

    await Navigator.of(context).push(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => tpvScreen),
    );
    if (mounted) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      setState(() => _haLanzadoLegacy = false);
    }
  }

  Widget _buildTpvEmbebido(String empresaId, String tipo) {
    final esAdmin = widget.esAdmin || widget.esPropietario || widget.esPropietarioPlatforma;
    final esProp  = widget.esPropietario || widget.esPropietarioPlatforma;
    switch (tipo) {
      case 'tienda':
        return TpvTiendaScreen(
          empresaId: empresaId,
          esAdmin: esAdmin,
          esPropietario: esProp,
          embedded: true,
          onEmbedReady: widget.onEmbedReady,
        );
      case 'peluqueria_estetica':
        return TpvPeluqueriaScreen(
          empresaId: empresaId,
          esAdmin: esAdmin,
          esPropietario: esProp,
          embedded: true,
          onEmbedReady: widget.onEmbedReady,
        );
      default: // 'bar' y cualquier otro tipo
        return TpvRootScreen(
          empresaId: empresaId,
          esAdmin: esAdmin,
          esPropietario: esProp,
          embedded: true,
          onEmbedReady: widget.onEmbedReady,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sub-navegación activa: mostrar el TPV embebido
    if (_empresaActivaId != null && _tipoActivo != null) {
      return _buildTpvEmbebido(_empresaActivaId!, _tipoActivo!);
    }

    // Propietarios: mostrar selector embebido
    if (widget.esPropietario || widget.esPropietarioPlatforma) {
      return TpvSelectorNegocioScreen(
        propietarioUid: widget.propietarioUid.isNotEmpty
            ? widget.propietarioUid
            : FirebaseAuth.instance.currentUser?.uid ?? '',
        empresaIdPropia: widget.empresaId,
        esPropietarioPlatforma: widget.esPropietarioPlatforma,
        embedded: true,
        onEmpresaSeleccionada: _onEmpresaSeleccionada,
      );
    }

    // Admin/staff: leer tipo y mostrar TPV directamente
    return FutureBuilder<String>(
      future: _tipoTpvFuture,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const SizedBox.expand(
              child: Center(child: CircularProgressIndicator()));
        }
        return _buildTpvEmbebido(widget.empresaId, snap.data!);
      },
    );
  }
}

// ── Botón compacto para acciones TPV en el header del dashboard ──────────────

class _TpvHeaderBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _TpvHeaderBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 13),
    label: Text(label, style: const TextStyle(fontSize: 11.5)),
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF374151),
      side: const BorderSide(color: Color(0xFFD1D5DB)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

// ── Briefing mensaje IA (con fallback a reglas si no hay API key) ─────────────

class _BriefingMensajeIA extends StatefulWidget {
  final int reservasHoy, pedidosHoy, facturasHoy, tareasAbiertas, facturasPendientes;
  final String nombreEmpresa;
  final String fallback;
  const _BriefingMensajeIA({
    required this.reservasHoy, required this.pedidosHoy, required this.facturasHoy,
    required this.tareasAbiertas, required this.facturasPendientes,
    required this.nombreEmpresa, required this.fallback,
  });
  @override State<_BriefingMensajeIA> createState() => _BriefingMensajeIAState();
}

class _BriefingMensajeIAState extends State<_BriefingMensajeIA> {
  String? _mensajeIA;
  bool _cargando = false;
  bool _intentado = false;

  @override
  void initState() {
    super.initState();
    _cargarMensajeIA();
  }

  Future<void> _cargarMensajeIA() async {
    if (_intentado) return;
    setState(() { _cargando = true; _intentado = true; });
    try {
      final resp = await IaService().generarBriefingIA(
        reservasHoy:       widget.reservasHoy,
        pedidosHoy:        widget.pedidosHoy,
        facturasHoy:       widget.facturasHoy,
        tareasAbiertas:    widget.tareasAbiertas,
        facturasPendientes: widget.facturasPendientes,
        nombreEmpresa:     widget.nombreEmpresa,
      );
      if (mounted) setState(() => _mensajeIA = resp);
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final mensaje = _mensajeIA ?? widget.fallback;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.15)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_mensajeIA != null)
          const Padding(
            padding: EdgeInsets.only(right: 6, top: 1),
            child: Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF7C3AED)),
          ),
        Expanded(
          child: _cargando
              ? Row(children: [
                  const SizedBox(width: 12, height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5,
                          color: Color(0xFF7C3AED))),
                  const SizedBox(width: 8),
                  Text('Generando resumen IA...',
                      style: TextStyle(fontSize: 11, color: const Color(0xFF7C3AED).withValues(alpha: 0.7))),
                ])
              : Text(mensaje,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7C3AED), height: 1.4)),
        ),
      ]),
    );
  }
}

// ── Dato inmutable para un evento de la agenda ────────────────────────────────
class _AgendaEvento {
  final DateTime fecha;
  final String titulo;
  final String subtitulo;
  final String tipo;
  final Color color;
  final IconData icon;
  const _AgendaEvento({
    required this.fecha,
    required this.titulo,
    required this.subtitulo,
    required this.tipo,
    required this.color,
    required this.icon,
  });
}

// ── Dato inmutable para un item del sidebar de desktop ────────────────────────
// Modo progresivo del sidebar lateral
enum _SidebarMode {
  full,    // 240px — icono + etiqueta en fila (≥ 1100px)
  compact, //  80px — icono + etiqueta corta debajo (760-1099px)
  rail,    //  56px — solo icono + tooltip (640-759px)
}

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

// ── Dato inmutable para un plazo fiscal ───────────────────────────────────────
class _FiscalPlazo {
  final String modelo;
  final String periodo;
  final DateTime plazo;
  final Color color;
  const _FiscalPlazo(this.modelo, this.periodo, this.plazo, this.color);
}

// ── Dato inmutable para un tile del launcher ──────────────────────────────────
class _AppTile {
  final String id;
  final IconData icon;
  final String label;
  final Color accent;
  const _AppTile(this.id, this.icon, this.label, this.accent);
}

// ══════════════════════════════════════════════════════════════════════════════
// KPI Carousel — StatefulWidget aislado para evitar rebuilds del dashboard
// ══════════════════════════════════════════════════════════════════════════════

class _KpiCarouselDoble extends StatefulWidget {
  final bool dark;
  final Color text, sub;
  final Stream<int> streamFacturas, streamClientes, streamPedidos;
  final Stream<int> streamTareas, streamEmpleados, streamReservas;
  const _KpiCarouselDoble({
    required this.dark, required this.text, required this.sub,
    required this.streamFacturas, required this.streamClientes, required this.streamPedidos,
    required this.streamTareas,   required this.streamEmpleados, required this.streamReservas,
  });
  @override
  State<_KpiCarouselDoble> createState() => _KpiCarouselDobleState();
}

class _KpiCarouselDobleState extends State<_KpiCarouselDoble> {
  int _idx = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _idx = (_idx + 1) % 3);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final text = widget.text;
    final sub  = widget.sub;
    final grupo1 = [
      (titulo: 'Facturas',  stream: widget.streamFacturas,  icon: Icons.receipt_long_rounded,
       color: const Color(0xFF3B82F6), subtituloFn: (int n) => n == 0 ? 'Al día' : '$n pendientes'),
      (titulo: 'Clientes',  stream: widget.streamClientes,  icon: Icons.people_alt_rounded,
       color: const Color(0xFF10B981), subtituloFn: (int n) => '$n activos'),
      (titulo: 'Pedidos',   stream: widget.streamPedidos,   icon: Icons.inventory_2_rounded,
       color: const Color(0xFFF59E0B), subtituloFn: (int n) => '$n en proceso'),
    ];
    final grupo2 = [
      (titulo: 'Tareas',    stream: widget.streamTareas,    icon: Icons.task_alt_rounded,
       color: const Color(0xFF8B5CF6), subtituloFn: (int n) => '$n pendientes'),
      (titulo: 'Empleados', stream: widget.streamEmpleados, icon: Icons.badge_rounded,
       color: const Color(0xFF6366F1), subtituloFn: (int n) => '$n en plantilla'),
      (titulo: 'Reservas',  stream: widget.streamReservas,  icon: Icons.calendar_month_rounded,
       color: const Color(0xFF14B8A6), subtituloFn: (int n) => n == 0 ? 'Sin reservas' : '$n hoy'),
    ];
    return Column(children: [
      _chip(dark, text, sub, grupo1, _idx, 0),
      const SizedBox(height: 8),
      _chip(dark, text, sub, grupo2, _idx, 3),
    ]);
  }

  Widget _chip(bool dark, Color text, Color sub,
      List<({String titulo, Stream<int> stream, IconData icon, Color color, String Function(int) subtituloFn})> kpis,
      int idx, int dotOffset) {
    final kpi    = kpis[idx];
    final cardBg = dark ? const Color(0xFF1A1F35) : const Color(0xFFF8FAFC);
    final border = dark ? const Color(0xFF2A2E45) : const Color(0xFFE8ECF4);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      child: StreamBuilder<int>(
        key: ValueKey('${dotOffset}_$idx'),
        stream: kpi.stream,
        builder: (_, snap) {
          final n = snap.data ?? 0;
          return Container(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
            decoration: BoxDecoration(
              color: cardBg, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
              boxShadow: dark ? [] : [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: kpi.color.withValues(alpha: dark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(kpi.icon, color: kpi.color, size: 17),
                ),
                const Spacer(),
                Row(children: List.generate(3, (i) => Container(
                  width: i == idx ? 10 : 4, height: 4,
                  margin: const EdgeInsets.only(left: 3),
                  decoration: BoxDecoration(
                    color: i == idx ? kpi.color : kpi.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ))),
              ]),
              const SizedBox(height: 10),
              Text('$n', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: text, height: 1)),
              const SizedBox(height: 2),
              Text(kpi.titulo, style: TextStyle(fontSize: 11, color: sub, fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(kpi.subtituloFn(n),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kpi.color)),
            ]),
          );
        },
      ),
    );
  }
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

// ─── Buscador Global ─────────────────────────────────────────────────────────

class _BuscadorGlobal extends StatefulWidget {
  final String empresaId;
  final bool dark;
  final void Function(String moduloId) onNavegar;

  const _BuscadorGlobal({
    required this.empresaId,
    required this.dark,
    required this.onNavegar,
  });

  @override
  State<_BuscadorGlobal> createState() => _BuscadorGlobalState();
}

class _BuscadorGlobalState extends State<_BuscadorGlobal> {
  final _ctrl = TextEditingController();
  String _query = '';

  static const _grupos = [
    ('clientes',     'Clientes',    Icons.people_alt_rounded,     Color(0xFF3B82F6)),
    ('facturacion',  'Facturas',    Icons.receipt_long_rounded,   Color(0xFF10B981)),
    ('tareas',       'Tareas',      Icons.task_alt_rounded,       Color(0xFF8B5CF6)),
    ('reservas',     'Reservas',    Icons.calendar_month_rounded, Color(0xFF6366F1)),
    ('pedidos',      'Pedidos',     Icons.inventory_2_rounded,    Color(0xFFF59E0B)),
    ('web',          'Web',         Icons.language_rounded,       Color(0xFF22D3EE)),
  ];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final bg = dark ? const Color(0xFF1E2139) : Colors.white;
    final text = dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
    final sub = dark ? const Color(0xFF9CA3AF) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 100, vertical: 80),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Icon(Icons.search_rounded, size: 20, color: sub),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: TextStyle(fontSize: 16, color: text),
                  decoration: InputDecoration(
                    hintText: 'Buscar clientes, facturas, tareas...',
                    hintStyle: TextStyle(color: sub, fontSize: 16),
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              if (_query.isNotEmpty)
                IconButton(
                  onPressed: () { _ctrl.clear(); setState(() => _query = ''); },
                  icon: Icon(Icons.close_rounded, size: 18, color: sub),
                ),
            ]),
          ),
          Divider(color: dark ? Colors.white12 : const Color(0xFFE2E8F0), height: 1),
          if (_query.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('Accesos rápidos',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: sub, letterSpacing: 0.5)),
                ),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _grupos.map((g) {
                    final id = g.$1; final label = g.$2;
                    final icon = g.$3; final color = g.$4;
                    return GestureDetector(
                      onTap: () => widget.onNavegar(id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: dark ? 0.14 : 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withValues(alpha: 0.25)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(icon, size: 15, color: color),
                          const SizedBox(width: 6),
                          Text(label, style: TextStyle(fontSize: 13,
                              color: color, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ]),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                children: _grupos.map((g) {
                  final id = g.$1; final label = g.$2;
                  final icon = g.$3; final color = g.$4;
                  return ListTile(
                    leading: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: dark ? 0.14 : 0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, size: 17, color: color),
                    ),
                    title: Text('Buscar "$_query" en $label',
                        style: TextStyle(fontSize: 13, color: text)),
                    subtitle: Text('Ir al módulo $label',
                        style: TextStyle(fontSize: 11, color: sub)),
                    onTap: () => widget.onNavegar(id),
                    dense: true,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  );
                }).toList(),
              ),
            ),
        ]),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final int selectedIndex;
  final Color color;
  final bool dark;
  final Color sub;

  const _SparklinePainter({
    required this.values,
    required this.selectedIndex,
    required this.color,
    required this.dark,
    required this.sub,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.fold(0.0, (a, b) => a > b ? a : b);
    final pts = List.generate(values.length, (i) => Offset(
      i * size.width / (values.length - 1),
      maxV > 0
          ? size.height * 0.9 - (values[i] / maxV) * size.height * 0.75
          : size.height * 0.9,
    ));

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final p0 = pts[i - 1];
      final p1 = pts[i];
      final cx = p0.dx + (p1.dx - p0.dx) * 0.5;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    final fill = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: dark ? 0.22 : 0.15),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    canvas.drawPath(path, Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);

    for (int i = 0; i < pts.length; i++) {
      if (maxV <= 0 || values[i] <= 0) continue;
      final isSel = i == selectedIndex;
      canvas.drawCircle(pts[i], isSel ? 4.5 : 2.5, Paint()..color = color);
      if (isSel) {
        canvas.drawCircle(pts[i], 4.5, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
        final tp = TextPainter(
          text: TextSpan(
            text: values[i] >= 1000
                ? '${(values[i] / 1000).toStringAsFixed(1)}k€'
                : '${values[i].toStringAsFixed(0)}€',
            style: TextStyle(fontSize: 8.0, fontWeight: FontWeight.w700, color: color),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(
          (pts[i].dx - tp.width / 2).clamp(0, size.width - tp.width),
          (pts[i].dy - tp.height - 6).clamp(0, size.height - tp.height),
        ));
      }
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.selectedIndex != selectedIndex || old.dark != dark;
}








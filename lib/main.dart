                if (!snapSuscripcion.hasData || !snapSuscripcion.data!.exists) {
                if (snapSuscripcion.connectionState == ConnectionState.waiting) {
              future: FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(empresaId)
       kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
                  .doc('actual')
                  .get(),
            // Comprobar suscripción
            final empresaData = snapEmpresa.data?.data() as Map<String, dynamic>?;
    ChangeNotifierProvider.value(
        return FutureBuilder<DocumentSnapshot>(
class FluixCrmApp extends StatelessWidget {
class FluixCrmApp extends StatelessWidget {
        final empresaId = userData?['empresa_id'] as String?;
                bool estaVencida = estado == 'VENCIDA' || estado == 'SUSPENDIDA';
import 'services/auth/sesion_service.dart';
        // Sin empresa → ir al dashboard (lo crea automáticamente)
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('empresas')
              .doc(empresaId)
              .get(),
            final empresaData = snapEmpresa.data?.data() as Map<String, dynamic>?;
            final onboardingCompletado = empresaData?['onboarding_completado'] as bool? ?? false;
                if (snapSuscripcion.connectionState == ConnectionState.waiting) {
            if (!onboardingCompletado) {
              return PantallaOnboarding(empresaId: empresaId);
            final empresaData = snapEmpresa.data?.data() as Map<String, dynamic>?;
            // Comprobar suscripción
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
              builder: (context, snapSuscripcion) {
      builder: (context, config, _) => MaterialApp(
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        debugShowCheckedModeBanner: false,
        theme: config.temaClaro,
        darkTheme: config.temaOscuro,
        themeMode: config.themeMode,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
  _intentarInicializarAdmin();
            // Sin sesión → detener el servicio
            TokenRefreshService().detener();
    ChangeNotifierProvider(
      create: (_) => AppConfigProvider()..inicializar(),

  await FirebaseAppCheck.instance.activate(
    androidProvider:
       kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider:
class FluixCrmApp extends StatefulWidget {
  const FluixCrmApp({super.key});
  // Activar persistencia offline de Firestore
  FirebaseFirestore.instance.settings = const Settings(
  State<FluixCrmApp> createState() => _FluixCrmAppState();
}
  // No bloquea el arranque: se lanza tras el primer frame para reducir
class _FluixCrmAppState extends State<FluixCrmApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  _inicializarNotificacionesEnBackground();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  // Se ejecutan tras el login (necesitan usuario autenticado para Firestore)
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SesionService().detener();
    super.dispose();
  }
      child: const FluixCrmApp(),
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        SesionService().registrarPausa();
        break;
      case AppLifecycleState.resumed:
        SesionService().manejarResumen();
        break;
      default:
        break;
    }
  }
}
  void _onSesionExpirada() {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
      (_) => false,
    );
  }
class FluixCrmApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppConfigProvider>(
      builder: (context, config, _) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => SesionService().registrarActividad(),
        onPanDown: (_) => SesionService().registrarActividad(),
        child: MaterialApp(
          title: 'Fluix CRM',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          theme: config.temaClaro,
          darkTheme: config.temaOscuro,
          themeMode: config.themeMode,
          locale: const Locale('es', 'ES'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', 'ES'),
            Locale('en', 'US'),
          ],
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges().distinct(
              (a, b) => a?.uid == b?.uid,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const PantallaCarga();
              }
              if (snapshot.hasData) {
                SesionService().iniciar(
                  onSesionExpirada: _onSesionExpirada,
                );
                return const _PantallaRuta();
              }
              TokenRefreshService().detener();
              SesionService().detener();
              return const PantallaLogin();
            },
          ),
        ),
      ),
    );
  }
}

class PantallaCarga extends StatelessWidget {
  const PantallaCarga({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D47A1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  .get(),
              builder: (context, snapSuscripcion) {
      builder: (context, config, _) => MaterialApp(
        title: 'Fluix CRM',
        debugShowCheckedModeBanner: false,
        darkTheme: config.temaOscuro,
                size: 40,
        themeMode: config.themeMode,
        locale: const Locale('es', 'ES'),
            const SizedBox(height: 24),
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
                fontSize: 28,
          Locale('es', 'ES'),
          Locale('en', 'US'),
        ],
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const PantallaCarga();
            }
            if (snapshot.hasData) {
              return const _PantallaRuta();
            }
            // Sin sesión → detener el servicio
            TokenRefreshService().detener();
          },
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.business_center_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
class _PantallaRuta extends StatefulWidget {
  const _PantallaRuta();

  @override
  State<_PantallaRuta> createState() => _PantallaRutaState();
}

class _PantallaRutaState extends State<_PantallaRuta> {
  late Future<DocumentSnapshot> _futureUsuario;
  Future<DocumentSnapshot>? _futureEmpresa;
  Future<DocumentSnapshot>? _futureSuscripcion;

  String? _uid;
  String? _empresaId;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid != null) {
      _futureUsuario = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_uid)
          .get();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) return const PantallaLogin();

    return FutureBuilder<DocumentSnapshot>(
      future: _futureUsuario,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const PantallaCarga();
        }

        final userData = snap.data?.data() as Map<String, dynamic>?;
        final empresaId = userData?['empresa_id'] as String?;

        if (empresaId == null) return const PantallaDashboard();

        if (_empresaId != empresaId || _futureEmpresa == null) {
          _empresaId = empresaId;
          _futureEmpresa = FirebaseFirestore.instance
              .collection('empresas')
              .doc(empresaId)
              .get();
          _futureSuscripcion = FirebaseFirestore.instance
              .collection('empresas')
              .doc(empresaId)
              .collection('suscripcion')
              .doc('actual')
              .get();
        }

        return FutureBuilder<DocumentSnapshot>(
          future: _futureEmpresa,
          builder: (context, snapEmpresa) {
            if (snapEmpresa.connectionState == ConnectionState.waiting) {
              return const PantallaCarga();
            }

            final empresaData =
                snapEmpresa.data?.data() as Map<String, dynamic>?;
            final onboardingCompletado =
                empresaData?['onboarding_completado'] as bool? ?? false;

            if (!onboardingCompletado) {
              return PantallaOnboarding(empresaId: empresaId);
            }

            return FutureBuilder<DocumentSnapshot>(
              future: _futureSuscripcion,
              builder: (context, snapSuscripcion) {
                if (snapSuscripcion.connectionState ==
                    ConnectionState.waiting) {
                  return const PantallaCarga();
                }

                if (!snapSuscripcion.hasData ||
                    !snapSuscripcion.data!.exists) {
                  return const PantallaDashboard();
                }

                final suscData =
                    snapSuscripcion.data!.data() as Map<String, dynamic>;
                final estado = suscData['estado'] as String? ?? 'ACTIVA';
                final fechaFinTs = suscData['fecha_fin'] as Timestamp?;
                final fechaFin = fechaFinTs?.toDate();

                bool estaVencida =
                    estado == 'VENCIDA' || estado == 'SUSPENDIDA';

                if (!estaVencida &&
                    fechaFin != null &&
                    estado == 'ACTIVA') {
                  final diasDespues =
                      DateTime.now().difference(fechaFin).inDays;
                  if (diasDespues > 7) estaVencida = true;
                }

                if (estaVencida) {
                  return PantallaSuscripcionVencida(
                    empresaId: empresaId,
                    estado: estado,
                    fechaFin: fechaFin,
                  );
                }

                return const PantallaDashboard();
              },
            );
          },
        );
      },
    );
  }
}

              style: TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
      // ignore: avoid_print
            const SizedBox(height: 8),

            Text(
              'Cargando...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 32),

            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}

/// Decide si mostrar onboarding o dashboard según el estado de Firestore
class _PantallaRuta extends StatelessWidget {
/// Se ejecuta en background para no bloquear el arranque de la app.
void _intentarInicializarAdmin() {
  Future(() async {
    try {
      await AdminInitializer.crearUsuarioAdmin();
      await AdminInitializer.actualizarModulos();
    } catch (e) {
      print('ℹ️ AdminInitializer no ejecutado: $e');
    }
  });
}

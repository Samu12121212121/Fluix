import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'features/registro/pantallas/pantalla_registro_invitacion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/navigation/app_navigator.dart';
import 'core/providers/app_config_provider.dart';
import 'features/tpv/providers/mesa_theme_provider.dart';
import 'core/utils/admin_initializer.dart';
import 'features/autenticacion/pantallas/pantalla_login.dart';
import 'features/dashboard/pantallas/pantalla_dashboard.dart';
import 'features/explorar_negocios/pantallas/pantalla_explorar.dart';
import 'features/onboarding/pantallas/pantalla_onboarding.dart';
import 'features/suscripcion/pantallas/pantalla_suscripcion_vencida.dart';
import 'firebase_options.dart';
import 'services/auth/sesion_service.dart';
import 'services/auth/token_refresh_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En Windows los errores async no capturados matan el proceso.
  // Firebase/Firestore los lanza desde threads nativos → los capturamos aquí.
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    PlatformDispatcher.instance.onError = (error, stack) {
      final msg = error.toString();
      if (msg.contains('permission-denied') ||
          msg.contains('firebase_auth') ||
          msg.contains('unknown-error') ||
          msg.contains('non-platform thread') ||
          msg.contains('FirebaseFirestore') ||
          msg.contains('cloud_firestore')) {
        debugPrint('⚠️ Firebase error capturado (desktop): $error');
        return true;
      }
      debugPrint('❌ Error no manejado: $error\n$stack');
      return true; // nunca cerrar la app en desktop
    };
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await _configurarFirestore();

  if (!kIsWeb &&
      !kDebugMode &&
      defaultTargetPlatform != TargetPlatform.windows &&
      defaultTargetPlatform != TargetPlatform.linux &&
      defaultTargetPlatform != TargetPlatform.macOS) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppConfigProvider()..inicializar()),
        ChangeNotifierProvider(create: (_) => MesaThemeProvider()..cargarTema()),
      ],
      child: const FluixCrmApp(),
    ),
  );
}

/// Configura Firestore con ajustes específicos por plataforma.
/// 
/// - **Windows/Desktop**: Caché limitada (100MB) + limpieza al inicio
///   → Previene crashes de platform channels y crecimiento ilimitado de disco
/// 
/// - **Mobile (Android/iOS)**: Caché ilimitada
///   → Aprovecha persistencia nativa optimizada del SDK
/// 
/// - **Web**: Sin persistencia
///   → No soportado en navegadores
Future<void> _configurarFirestore() async {
  if (kIsWeb) {
    // ── WEB: Sin persistencia (no soportado) ──────────────────────────
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    debugPrint('🌐 Firestore configurado para Web (sin persistencia)');
    
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
             defaultTargetPlatform == TargetPlatform.linux ||
             defaultTargetPlatform == TargetPlatform.macOS) {
    // ── DESKTOP: Caché limitada + limpieza preventiva ─────────────────
    
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024, // 100MB máximo
    );
    
    // Limpiar caché al iniciar app (previene acumulación)
    try {
      await FirebaseFirestore.instance.clearPersistence();
      debugPrint('✅ Caché Firestore limpiada (Windows)');
    } catch (e) {
      // Error esperado si app ya está usando Firestore
      debugPrint('ℹ️ No se pudo limpiar caché (app activa): $e');
    }
    
    debugPrint('💻 Firestore configurado para Desktop (caché 100MB)');
    
  } else {
    // ── MOBILE: Caché ilimitada (óptimo para iOS/Android) ─────────────
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('📱 Firestore configurado para Mobile (caché ilimitada)');
  }
}

class FluixCrmApp extends StatefulWidget {
  const FluixCrmApp({super.key});

  @override
  State<FluixCrmApp> createState() => _FluixCrmAppState();
}

class _FluixCrmAppState extends State<FluixCrmApp>
    with WidgetsBindingObserver {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    // No bloquea el arranque: se lanza tras el primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _intentarInicializarAdmin();
    });
  }

  // ── Deep Links ──────────────────────────────────────────────────────────────

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Manejar deep link cuando la app estaba cerrada
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleDeepLink(initialUri);
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error leyendo initial deep link: $e');
    }

    // Escuchar deep links en background/foreground
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleDeepLink,
      onError: (e) => debugPrint('⚠️ Error en deep link stream: $e'),
    );
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('🔗 Deep link recibido: $uri');
    if (uri.scheme != 'fluixcrm') return;

    final nav = AppNavigator.key.currentState;
    if (nav == null) return;

    if (uri.host == 'invite') {
      final token = uri.queryParameters['token'];
      if (token != null && token.isNotEmpty) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => PantallaRegistroInvitacion(token: token),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    SesionService().detener();
    super.dispose();
  }

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

  void _onSesionExpirada() {
    AppNavigator.irALogin();
  }

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
          navigatorKey: AppNavigator.key,
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
          routes: {
            '/login': (_) => const PantallaLogin(),
          },
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
              // Sin sesión → detener el servicio
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
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(60),
              ),
              child: const Icon(
                Icons.business_center_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Fluix CRM',
              style: TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cargando...',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white.withOpacity(0.8),
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

/// Decide si mostrar onboarding, pantalla de suscripción vencida o dashboard
/// según el estado de Firestore.
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

        // Si es cliente final, ir a la pantalla de explorar
        if (userData != null) {
          final rolString = userData['role'] as String?;
          if (rolString == 'clienteFinal') {
            return const PantallaExplorar();
          }
        }

        final empresaId = userData?['empresa_id'] as String?;

        // Sin empresa → ir al dashboard (lo crea automáticamente)
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

/// Se ejecuta en background para no bloquear el arranque de la app.
void _intentarInicializarAdmin() {
  Future(() async {
    try {
      await AdminInitializer.crearUsuarioAdmin();
      await AdminInitializer.actualizarModulos();
    } catch (e) {
      // ignore: avoid_print
      print('ℹ️ AdminInitializer no ejecutado: $e');
    }
  });
}
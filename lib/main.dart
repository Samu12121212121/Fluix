import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Firebase options
import 'firebase_options.dart';

// Core
import 'core/providers/app_config_provider.dart';
import 'core/utils/admin_initializer.dart';

// Services
import 'services/notificaciones_service.dart';
import 'services/auth/token_refresh_service.dart';

// Features
import 'features/autenticacion/pantallas/pantalla_login.dart';
import 'features/dashboard/pantallas/pantalla_dashboard.dart';
import 'features/onboarding/pantallas/pantalla_onboarding.dart';
import 'features/suscripcion/pantallas/pantalla_suscripcion_vencida.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar locales
  timeago.setLocaleMessages('es', timeago.EsMessages());
  await initializeDateFormatting('es_ES', null);

  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Firebase App Check ──────────────────────────────────────────────────
  // Protege Firestore, Functions y Storage contra accesos no autorizados.
  // En debug usa DebugProvider (no llega a producción gracias a kDebugMode).
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider: kDebugMode
        ? AppleProvider.debug
        : AppleProvider.deviceCheck,
  );

  // Activar persistencia offline de Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // ── Inicialización diferida de notificaciones ─────────────────────────
  // No bloquea el arranque: se lanza tras el primer frame para reducir
  // los frames saltados en el Choreographer.
  // (El token FCM se guarda tras login, no necesita estar listo antes de la UI)
  _inicializarNotificacionesEnBackground();

  // ── Auto-inicializaciones ────────────────────────────────────────────────
  // Se ejecutan tras el login (necesitan usuario autenticado para Firestore)
  // Ver: pantalla_login.dart → _iniciarSesion()

  // Cargar preferencias de tema y color
  final appConfig = AppConfigProvider();
  await appConfig.inicializar();

  runApp(
    ChangeNotifierProvider.value(
      value: appConfig,
      child: const FluixCrmApp(),
    ),
  );
}


class FluixCrmApp extends StatelessWidget {
  const FluixCrmApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Consumer proporciona un context descendiente del ChangeNotifierProvider
    return Consumer<AppConfigProvider>(
      builder: (context, config, _) => MaterialApp(
        title: 'Fluix CRM',
        debugShowCheckedModeBanner: false,
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
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const PantallaCarga();
            }
            if (snapshot.hasData) {
              // Iniciar renovación automática de token cuando hay sesión activa
              TokenRefreshService().iniciar(
                onSesionInvalida: (mensaje) {
                  // Redirigir al login si la sesión es completamente inválida
                  FirebaseAuth.instance.signOut();
                  // El StreamBuilder detectará el cambio y mostrará PantallaLogin
                  debugPrint('⚠️ Sesión inválida: $mensaje');
                },
              );
              return const _PantallaRuta();
            }
            // Sin sesión → detener el servicio
            TokenRefreshService().detener();
            return const PantallaLogin();
          },
        ),
      ),
    );
  }
}

/// Decide si mostrar onboarding o dashboard según el estado de Firestore
class _PantallaRuta extends StatelessWidget {
  const _PantallaRuta();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const PantallaLogin();

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('usuarios').doc(uid).get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const PantallaCarga();
        }

        final userData = snap.data?.data() as Map<String, dynamic>?;
        final empresaId = userData?['empresa_id'] as String?;

        // Sin empresa → ir al dashboard (lo crea automáticamente)
        if (empresaId == null) return const PantallaDashboard();

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('empresas')
              .doc(empresaId)
              .get(),
          builder: (context, snapEmpresa) {
            if (snapEmpresa.connectionState == ConnectionState.waiting) {
              return const PantallaCarga();
            }

            final empresaData = snapEmpresa.data?.data() as Map<String, dynamic>?;
            final onboardingCompletado = empresaData?['onboarding_completado'] as bool? ?? false;

            if (!onboardingCompletado) {
              return PantallaOnboarding(empresaId: empresaId);
            }

            // Comprobar suscripción
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(empresaId)
                  .collection('suscripcion')
                  .doc('actual')
                  .get(),
              builder: (context, snapSuscripcion) {
                if (snapSuscripcion.connectionState == ConnectionState.waiting) {
                  return const PantallaCarga();
                }

                // Si no existe doc de suscripción → dejar pasar (nueva empresa)
                if (!snapSuscripcion.hasData || !snapSuscripcion.data!.exists) {
                  return const PantallaDashboard();
                }

                final suscData = snapSuscripcion.data!.data() as Map<String, dynamic>;
                final estado = suscData['estado'] as String? ?? 'ACTIVA';

                DateTime? fechaFin;
                final raw = suscData['fecha_fin'];
                if (raw is Timestamp) fechaFin = raw.toDate();

                // Determinar si la suscripción está efectivamente vencida
                bool estaVencida = estado == 'VENCIDA' || estado == 'SUSPENDIDA';

                // Fallback: si la CF aún no marcó VENCIDA pero pasaron 7+ días
                // de gracia, bloquear desde el cliente también
                if (!estaVencida && fechaFin != null && estado == 'ACTIVA') {
                  final diasDespues = DateTime.now().difference(fechaFin).inDays;
                  if (diasDespues > 7) {
                    estaVencida = true;
                  }
                }

                if (estaVencida) {
                  return PantallaSuscripcionVencida(
                    empresaId: empresaId,
                    estado: estado == 'ACTIVA' ? 'VENCIDA' : estado,
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

class PantallaCarga extends StatelessWidget {
  const PantallaCarga({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1976D2),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
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

/// Inicializa las notificaciones push en background (no bloquea el arranque).
void _inicializarNotificacionesEnBackground() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future(() async {
      try {
        await NotificacionesService().inicializar();
      } catch (e) {
        debugPrint('⚠️ Error inicializando notificaciones: $e');
      }
    });
  });
}

/// Inicializa la cuenta admin y actualiza los módulos de la empresa.
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







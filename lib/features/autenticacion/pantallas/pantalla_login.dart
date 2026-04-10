import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../../services/apple_auth_service.dart';
import '../../../features/dashboard/pantallas/pantalla_dashboard.dart';
import '../../../features/registro/pantallas/pantalla_registro.dart';
import '../../../features/registro/pantallas/pantalla_registrar_empresa_social.dart';
import '../../../services/notificaciones_service.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../core/utils/admin_initializer.dart';
import '../../../services/auth/auditoria_service.dart';
import '../../../services/auth/fuerza_bruta_service.dart';
import '../../../services/auth/dos_factores_service.dart';
import '../../../services/auth/biometria_service.dart';
import 'pantalla_verificacion_2fa.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _formKey = GlobalKey<FormState>();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _cargando = false;
  bool _cargandoGoogle = false;
  bool _cargandoApple = false;

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80),

              // Logo y título
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Fluix CRM',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                'Gestión empresarial simplificada',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 40),

              // Formulario
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Campo de correo
                    TextFormField(
                      controller: _correoController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa tu correo electrónico';
                        }
                        if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Ingresa un correo válido';
                        }
                        return null;
                      },
                      enabled: !_cargando,
                    ),
                    const SizedBox(height: 16),

                    // Campo de contraseña
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingresa tu contraseña';
                        }
                        if (value.length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres';
                        }
                        return null;
                      },
                      enabled: !_cargando,
                    ),
                    const SizedBox(height: 24),

                    // Botón de iniciar sesión
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _iniciarSesion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _cargando
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Iniciar Sesión',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Enlace de recuperar contraseña
                    TextButton(
                      onPressed: _cargando ? null : _mostrarRecuperacionPassword,
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                    const SizedBox(height: 16),

                    // ── Separador "o" ────────────────────────────
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[300])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('o', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                        ),
                        Expanded(child: Divider(color: Colors.grey[300])),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Botón Google Sign-In ────────────────────
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: (_cargando || _cargandoGoogle || _cargandoApple) ? null : _iniciarSesionConGoogle,
                        icon: _cargandoGoogle
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Image.network(
                                'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                                width: 20, height: 20,
                                errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 24),
                              ),
                        label: const Text('Continuar con Google', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[800],
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Botón Apple Sign-In (solo iOS) ───────────
                    // Apple requiere este botón si ofreces login con terceros
                    _buildAppleSignInButton(),

                    const SizedBox(height: 24),

                    // Botón de registro
                    OutlinedButton(
                      onPressed: _cargando ? null : _navegarARegistro,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Registrar Nueva Empresa',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  final _auditSvc = AuditoriaService();
  final _bruteSvc = FuerzaBrutaService();
  final _2faSvc = DosFactoresService();
  final _bioSvc = BiometriaService();

  void _iniciarSesion() async {
    if (_formKey.currentState!.validate()) {
      final email = _correoController.text.trim();

      // ── 1. Verificar bloqueo por fuerza bruta ──────────────────────────
      final estado = await _bruteSvc.verificarEstado(email);
      if (estado.bloqueado) {
        final minutos = estado.tiempoRestante.inMinutes + 1;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('🔒 Cuenta bloqueada. Inténtalo en $minutos min.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ));
        }
        return;
      }

      setState(() => _cargando = true);

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );

        // Login OK → reset contador de intentos
        await _bruteSvc.registrarIntento(email: email, exito: true);

        // Cargar permisos
        await Future.wait([
          NotificacionesService().guardarTokenTrasLogin(),
          PermisosService().cargarSesion(),
        ]);

        final sesion = PermisosService().sesion;

        // ── 2. Registrar auditoría ──────────────────────────────────────
        _auditSvc.registrar(
          tipo: TipoEventoAuditoria.loginOk,
          email: email,
          metodo: MetodoAuth.email,
          usuarioId: FirebaseAuth.instance.currentUser?.uid,
          empresaId: sesion?.empresaId,
          rol: sesion?.rolNombre,
        );

        // ── 3. Verificar 2FA ────────────────────────────────────────────
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final config2fa = await _2faSvc.obtenerConfig(uid);
          if (config2fa.activo && config2fa.telefono.isNotEmpty) {
            // Enviar SMS y abrir pantalla 2FA
            try {
              final verificationId = await _2faSvc.enviarCodigo(
                telefono: config2fa.telefono,
                onError: (msg) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(msg), backgroundColor: Colors.red,
                    ));
                  }
                },
              );
              if (mounted) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => PantallaVerificacion2FA(
                    telefono: config2fa.telefono,
                    verificationId: verificationId,
                  ),
                ));
              }
              return; // No navegar al dashboard todavía
            } catch (_) {
              // Si falla el envío de SMS, dejar pasar (sin bloquear)
            }
          }
        }

        // ── 4. Ofrecer biometría (si primer login sin biometría activa) ─
        final bioActiva = await _bioSvc.estaActiva;
        if (!bioActiva && uid != null && mounted) {
          final soportada = await _bioSvc.tiposDisponibles();
          if (soportada.isNotEmpty) {
            _ofrecerBiometria(uid, email);
          }
        }

        // Background init
        Future(() async {
          try { await AdminInitializer.crearUsuarioAdmin(); } catch (_) {}
        });

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PantallaDashboard()),
          );
        }
      } on FirebaseAuthException catch (e) {
        // Login fallido → registrar intento
        await _bruteSvc.registrarIntento(email: email, exito: false);
        _auditSvc.registrar(
          tipo: TipoEventoAuditoria.loginFallido,
          email: email,
          metodo: MetodoAuth.email,
          mensajeError: e.code,
        );

        String mensaje;
        switch (e.code) {
          case 'user-not-found':
            mensaje = 'No se encontró un usuario con este correo.';
            break;
          case 'wrong-password':
          case 'invalid-credential':
            mensaje = 'Correo o contraseña incorrectos.';
            break;
          case 'invalid-email':
            mensaje = 'Correo electrónico inválido.';
            break;
          case 'network-request-failed':
            mensaje = 'Sin conexión a internet. Comprueba tu red e inténtalo de nuevo.';
            break;
          case 'too-many-requests':
            mensaje = 'Demasiados intentos. Espera unos minutos.';
            break;
          case 'user-disabled':
            mensaje = 'Esta cuenta ha sido desactivada.';
            break;
          default:
            mensaje = 'Error al iniciar sesión: ${e.message}';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensaje),
              backgroundColor: e.code == 'network-request-failed'
                  ? Colors.orange
                  : Colors.red,
              duration: const Duration(seconds: 4),
              action: e.code == 'network-request-failed'
                  ? SnackBarAction(
                      label: 'Reintentar',
                      textColor: Colors.white,
                      onPressed: _iniciarSesion,
                    )
                  : null,
            ),
          );
        }
      } catch (e) {
        final msg = e.toString();
        final esRedError = msg.contains('network') ||
            msg.contains('timeout') ||
            msg.contains('unreachable') ||
            msg.contains('SocketException');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(esRedError
                  ? 'Sin conexión a internet. Comprueba tu red.'
                  : 'Error inesperado: $e'),
              backgroundColor: esRedError ? Colors.orange : Colors.red,
              duration: const Duration(seconds: 4),
              action: esRedError
                  ? SnackBarAction(
                      label: 'Reintentar',
                      textColor: Colors.white,
                      onPressed: _iniciarSesion,
                    )
                  : null,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _cargando = false;
          });
        }
      }
    }
  }

  void _navegarARegistro() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PantallaRegistro(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GOOGLE SIGN-IN
  // ═══════════════════════════════════════════════════════════════════════════

  void _iniciarSesionConGoogle() async {
    setState(() => _cargandoGoogle = true);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _cargandoGoogle = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;

      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios').doc(user.uid).get();

      bool esNuevoUsuario = false;
      if (!userDoc.exists) {
        esNuevoUsuario = true;
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
          'nombre': user.displayName ?? user.email?.split('@').first ?? 'Usuario',
          'correo': user.email ?? '',
          'telefono': user.phoneNumber ?? '',
          'empresa_id': '',
          'rol': 'propietario',
          'activo': true,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'permisos': [],
          'proveedor_auth': 'google',
        });
      } else {
        final empresaId = (userDoc.data()?['empresa_id'] as String?) ?? '';
        esNuevoUsuario = empresaId.isEmpty;
      }

      await Future.wait([
        NotificacionesService().guardarTokenTrasLogin(),
        PermisosService().cargarSesion(),
      ]);

      if (mounted) {
        if (esNuevoUsuario) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PantallaRegistrarEmpresaSocial(
                nombreUsuario: user.displayName ??
                    user.email?.split('@').first ??
                    'Usuario',
                correoUsuario: user.email ?? '',
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PantallaDashboard()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error con Google: ${e.message}'),
          backgroundColor: Colors.red,
        ));
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error de plataforma: ${e.message ?? e.code}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _cargandoGoogle = false);
    }
  }

  Widget _buildAppleSignInButton() {
    final isApplePlatform = !kIsWeb && (Platform.isIOS || Platform.isMacOS);
    if (!isApplePlatform) return const SizedBox.shrink();

    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: (_cargando || _cargandoGoogle || _cargandoApple)
            ? null
            : _iniciarSesionConApple,
        icon: _cargandoApple
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.apple, size: 24, color: Colors.white),
        label: const Text(
          'Continuar con Apple',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          disabledBackgroundColor: Colors.grey[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  void _iniciarSesionConApple() async {
    setState(() => _cargandoApple = true);
    try {
      final userCredential = await AppleAuthService.signIn();
      final user = userCredential.user!;

      final userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      bool esNuevoUsuario = false;
      if (!userDoc.exists) {
        final nombre = user.displayName ?? 'Usuario Apple';
        final correo = user.email ?? '';
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .set({
          'nombre': nombre,
          'correo': correo,
          'telefono': '',
          'empresa_id': '',
          'rol': 'propietario',
          'activo': true,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'permisos': [],
          'proveedor_auth': 'apple',
          'email_relay': correo.contains('@privaterelay.appleid.com'),
        });
        esNuevoUsuario = true;
      } else {
        final empresaId = (userDoc.data()?['empresa_id'] as String?) ?? '';
        esNuevoUsuario = empresaId.isEmpty;
      }

      await Future.wait([
        NotificacionesService().guardarTokenTrasLogin(),
        PermisosService().cargarSesion(),
      ]);

      if (mounted) {
        if (esNuevoUsuario) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PantallaRegistrarEmpresaSocial(
                nombreUsuario: user.displayName ?? 'Usuario Apple',
                correoUsuario: user.email ?? '',
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PantallaDashboard()),
          );
        }
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        debugPrint('Apple Sign-In cancelado por el usuario');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error con Apple: ${e.message}'),
          backgroundColor: Colors.red,
        ));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error de autenticación: ${e.message}'),
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _cargandoApple = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECUPERAR CONTRASEÑA (real con Firebase)
  // ═══════════════════════════════════════════════════════════════════════════

  void _mostrarRecuperacionPassword() {
    final emailCtrl = TextEditingController(text: _correoController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar Contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('📧 Enlace de recuperación enviado a $email'),
                    backgroundColor: const Color(0xFF4CAF50),
                    duration: const Duration(seconds: 5),
                  ));
                }
              } on FirebaseAuthException catch (e) {
                if (mounted) {
                  String msg = switch (e.code) {
                    'user-not-found' => 'No hay ninguna cuenta con ese correo.',
                    'invalid-email' => 'El correo no es válido.',
                    _ => 'Error: ${e.message}',
                  };
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(msg),
                    backgroundColor: Colors.red,
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2)),
            child: const Text('Enviar enlace', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _llenarCredencialesAdmin() {
    setState(() {
      _correoController.text = AdminInitializer.adminEmail;
      _passwordController.text = AdminInitializer.adminPassword;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Credenciales de admin cargadas'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF1976D2),
      ),
    );
  }

  /// Ofrece activar biometría tras login exitoso con email/contraseña
  void _ofrecerBiometria(String uid, String email) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.fingerprint, color: Color(0xFF0D47A1)),
            SizedBox(width: 8),
            Text('Acceso rápido'),
          ]),
          content: const Text(
            '¿Quieres usar huella dactilar o Face ID para acceder más rápido la próxima vez?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ahora no'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _bioSvc.activar(uid: uid, email: email);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Activar'),
            ),
          ],
        ),
      );
    });
  }

  /// Limpia los datos de prueba y reinicializa la empresa con módulos completos.
  /// ORDEN CRÍTICO: primero autenticar, después operar Firestore.
  void _reinicializarEmpresa() async {
    // Confirmar antes de borrar
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Reinicializar empresa'),
        content: const Text(
          'Esto borrará TODOS los datos de prueba (clientes, reservas, '
          'valoraciones, etc.) y recreará la estructura desde cero.\n\n'
          '¿Estás seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, reinicializar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _cargando = true);
    try {
      // PASO 1: Crear/verificar usuario admin Y autenticarse
      // (crearUsuarioAdmin hace signIn si el email ya existe en Auth)
      await AdminInitializer.crearUsuarioAdmin();

      // PASO 2: Ahora que estamos autenticados, limpiar datos de prueba
      await AdminInitializer.limpiarDatosPrueba();

      // PASO 3: Actualizar módulos con la lista completa
      await AdminInitializer.actualizarModulos();

      if (mounted) {
        // Rellenar credenciales para facilitar el login inmediato
        _correoController.text = AdminInitializer.adminEmail;
        _passwordController.text = AdminInitializer.adminPassword;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Empresa reinicializada. Pulsa "Iniciar Sesión".'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }
}


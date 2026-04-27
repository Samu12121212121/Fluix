// ═══════════════════════════════════════════════════════════════════════════════
// PANTALLA DE LOGIN — Fluix CRM
//
// FLUJOS DE CREACIÓN DE CUENTAS:
//
// 1. REGISTRO EMAIL (botón "Registrar Nueva Empresa"):
//    → PantallaRegistro → FormularioRegistro
//    → Crea Auth user + empresa + usuario con rol 'admin'
//    → Navega directamente al Dashboard
//
// 2. GOOGLE / APPLE SIGN-IN:
//    → Si usuario nuevo: crea doc con rol 'admin' y empresa_id vacío
//    → Redirige a PantallaRegistrarEmpresaSocial para completar empresa
//    → Si ya existe con empresa: navega al Dashboard
//
// 3. INVITACIÓN EMPLEADO (deep link fluixcrm://invite?token=XXX):
//    → PantallaRegistroInvitacion
//    → Crea Auth + doc usuario con rol asignado por el admin
//    → empresa_id del invitador, módulos limitados
//
// ROLES:
//    - 'propietario': EXCLUSIVO de FluixTech (empresaPropietariaId)
//    - 'admin': dueño de cualquier otra empresa (acceso total a su empresa)
//    - 'staff': empleado invitado (acceso limitado por módulos asignados)
//
// BIOMETRÍA (Face ID / Huella):
//    - Tras primer login exitoso se ofrece activar biometría (diálogo bloqueante)
//    - Si acepta → siguiente apertura muestra PantallaLoginBiometrico
//    - NSFaceIDUsageDescription configurado en ios/Runner/Info.plist
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../features/dashboard/pantallas/pantalla_dashboard.dart';
import '../../../features/registro/pantallas/pantalla_registro.dart';
import '../../../services/notificaciones_service.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../core/utils/admin_initializer.dart';
import '../../../services/auth/auditoria_service.dart';
import '../../../services/auth/fuerza_bruta_service.dart';
import '../../../services/auth/dos_factores_service.dart';
import '../../../services/auth/biometria_service.dart';
import '../../../services/demo_cuenta_service.dart';
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
  bool _cargandoDemo = false;

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  bool get _ocupado => _cargando || _cargandoDemo;

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 1),
                      _buildLogo(),
                      const SizedBox(height: 48),
                      _buildLoginForm(),
                      const SizedBox(height: 32),
                      _buildFooterLinks(),
                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF43A047).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.business_center_rounded,
            color: Colors.white,
            size: 60,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Fluix CRM',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Gestiona tu negocio de forma inteligente',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // ── Email ─────────────────────────────────────────
          TextFormField(
            controller: _correoController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_ocupado,
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Por favor ingresa tu correo';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // ── Contraseña ────────────────────────────────────
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_ocupado,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Por favor ingresa tu contraseña';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // ── Botón iniciar sesión ─────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _ocupado ? null : _iniciarSesion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: _cargando
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Iniciar Sesión',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      children: [
        // ── Registrar nueva empresa ─────────────────────────
        TextButton(
          onPressed: _ocupado ? null : () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PantallaRegistro()),
            );
          },
          child: const Text(
            'Registrar Nueva Empresa',
            style: TextStyle(
              color: Color(0xFF43A047),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // ── Olvidé mi contraseña ────────────────────────────
        TextButton(
          onPressed: _ocupado ? null : _restablecerPassword,
          child: Text(
            '¿Olvidaste tu contraseña?',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
        const SizedBox(height: 16),

        // ── Separador ──────────────────────────────────────
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[300])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('o prueba la demo', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ),
            Expanded(child: Divider(color: Colors.grey[300])),
          ],
        ),
        const SizedBox(height: 16),

        // ── Botón demo ─────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _ocupado ? null : _iniciarSesionDemo,
            icon: _cargandoDemo
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_circle_outline, color: Color(0xFF1565C0)),
            label: Text(
              _cargandoDemo ? 'Cargando demo...' : 'Probar cuenta demo',
              style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF1565C0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sin registro · Datos de ejemplo · Solo lectura',
          style: TextStyle(color: Colors.grey[400], fontSize: 11),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTODOS DE AUTENTICACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    final correo = _correoController.text.trim();
    final password = _passwordController.text;

    setState(() => _cargando = true);

    try {
      // ── 1. Protección fuerza bruta ──────────────────────────────────────
      final estado = await FuerzaBrutaService().verificarEstado(correo);
      if (estado.bloqueado) {
        final min = estado.tiempoRestante.inMinutes;
        _mostrarError('Cuenta bloqueada temporalmente. Inténtalo en $min minutos.');
        return;
      }

      // ── 2. Inicializar admin en debug ───────────────────────────────────
      await AdminInitializer.crearUsuarioAdmin();

      // ── 3. Firebase Auth ────────────────────────────────────────────────
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: correo,
        password: password,
      );
      final user = cred.user!;

      // ── 4. Registrar intento exitoso ────────────────────────────────────
      await FuerzaBrutaService().registrarIntento(email: correo, exito: true);

      // ── 5. Verificar 2FA ────────────────────────────────────────────────
      final config2fa = await DosFactoresService().obtenerConfig(user.uid);
      if (config2fa.activo && config2fa.telefono.isNotEmpty) {
        if (!mounted) return;
        final verificationId = await DosFactoresService().enviarCodigo(
          telefono: config2fa.telefono,
          onError: (msg) => _mostrarError(msg),
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaVerificacion2FA(
              telefono: _enmascararTelefono(config2fa.telefono),
              verificationId: verificationId,
            ),
          ),
        );
        return;
      }

      // ── 6. Post-login ───────────────────────────────────────────────────
      await _postLoginExitoso(user, MetodoAuth.email);

    } on FirebaseAuthException catch (e) {
      await FuerzaBrutaService().registrarIntento(email: correo, exito: false);
      await AuditoriaService().registrar(
        tipo: TipoEventoAuditoria.loginFallido,
        email: correo,
        metodo: MetodoAuth.email,
        mensajeError: e.code,
      );
      _mostrarError(_mapearErrorFirebase(e));
    } catch (e) {
      _mostrarError('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Acciones tras cualquier login exitoso.
  Future<void> _postLoginExitoso(User user, MetodoAuth metodo) async {
    // Cargar sesión + guardar token FCM en paralelo
    await Future.wait([
      PermisosService().cargarSesion(),
      NotificacionesService().guardarTokenTrasLogin(),
    ]);

    // Auditoría
    final sesion = PermisosService().sesion;
    await AuditoriaService().registrar(
      tipo: TipoEventoAuditoria.loginOk,
      email: user.email ?? '',
      metodo: metodo,
      usuarioId: user.uid,
      empresaId: sesion?.empresaId,
      rol: sesion?.rol.name,
    );

    // Ofrecer biometría si no está activa
    final bioActiva = await BiometriaService().estaActiva;
    if (!bioActiva && mounted) {
      await _ofrecerBiometria(user);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PantallaDashboard()),
    );
  }

  Future<void> _iniciarSesionDemo() async {
    setState(() => _cargandoDemo = true);
    try {
      await DemoCuentaService().loginComoDemo();
      await Future.wait([
        PermisosService().cargarSesion(),
        NotificacionesService().guardarTokenTrasLogin(),
      ]);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PantallaDashboard()),
      );
    } catch (e) {
      _mostrarError('No se pudo iniciar la demo: $e');
    } finally {
      if (mounted) setState(() => _cargandoDemo = false);
    }
  }


  // ═══════════════════════════════════════════════════════════════════════════
  // BIOMETRÍA — oferta tras primer login
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _ofrecerBiometria(User user) async {
    final soporta = await BiometriaService().dispositivoSoportaBiometria();
    if (!soporta || !mounted) return;

    final label = await BiometriaService().labelBoton();

    final acepta = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Acceso rápido'),
        content: Text(
          '¿Quieres usar $label para entrar la próxima vez sin escribir tu contraseña?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Ahora no'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF43A047)),
            child: const Text('Activar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (acepta == true) {
      await BiometriaService().activar(
        uid: user.uid,
        email: user.email ?? '',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red[700]),
    );
  }

  String _mapearErrorFirebase(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found'           => 'No existe ninguna cuenta con ese correo.',
      'wrong-password'           => 'Contraseña incorrecta.',
      'invalid-credential'       => 'Correo o contraseña incorrectos.',
      'invalid-email'            => 'El correo no tiene un formato válido.',
      'user-disabled'            => 'Esta cuenta ha sido deshabilitada.',
      'too-many-requests'        => 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
      'network-request-failed'   => 'Sin conexión a internet. Comprueba tu red.',
      'email-already-in-use'     => 'Ya existe una cuenta con este correo.',
      'operation-not-allowed'    => 'Método de inicio de sesión no habilitado.',
      _                          => 'Error: ${e.message ?? e.code}',
    };
  }

  String _enmascararTelefono(String telefono) {
    if (telefono.length < 6) return telefono;
    final visible = telefono.substring(telefono.length - 2);
    return '${telefono.substring(0, 3)} *** *** $visible';
  }

  Future<void> _restablecerPassword() async {
    if (_correoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa tu correo electrónico primero'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _correoController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se ha enviado un enlace de restablecimiento a tu correo'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar el correo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

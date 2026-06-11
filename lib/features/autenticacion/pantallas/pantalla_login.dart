import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../features/dashboard/pantallas/pantalla_dashboard.dart';
import '../../../features/explorar_negocios/pantallas/pantalla_explorar.dart';
import '../../../services/notificaciones_service.dart';
import 'form_contacto_interes.dart';
import 'form_registro_modal.dart';
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

  bool get _ocupado => _cargando || _cargandoDemo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F23), // Mismo fondo que pantalla explorar
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

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00FFC8), Color(0xFFFF3296)], // Cian a magenta
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FFC8).withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.business_center_rounded,
            color: Color(0xFF0A0F23),
            size: 60,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Fluix',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00FFC8), // Cian brillante
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Descubre y planea en tu ciudad',
          style: TextStyle(fontSize: 16, color: Color(0xFFB0B3C1)), // Gris claro
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
          TextFormField(
            controller: _correoController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_ocupado,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              labelStyle: const TextStyle(color: Color(0xFFB0B3C1)),
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF00FFC8)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2E45)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2E45)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00FFC8), width: 2),
              ),
              filled: true,
              fillColor: const Color(0xFF1E2139),
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
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_ocupado,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              labelStyle: const TextStyle(color: Color(0xFFB0B3C1)),
              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00FFC8)),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: Color(0xFFB0B3C1)),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2E45)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2E45)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF00FFC8), width: 2),
              ),
              filled: true,
              fillColor: const Color(0xFF1E2139),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Por favor ingresa tu contraseña';
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _ocupado ? null : _iniciarSesion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FFC8), // Cian brillante
                foregroundColor: const Color(0xFF0A0F23), // Texto oscuro
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _cargando
                  ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A0F23)),
              )
                  : const Text(
                'Iniciar Sesión',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        TextButton(
          onPressed: _ocupado ? null : _restablecerPassword,
          child: const Text(
            '¿Olvidaste tu contraseña?',
            style: TextStyle(color: Color(0xFF6B6E82), fontSize: 14), // Gris muted
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider(color: Color(0xFF2A2E45))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: const Text('o prueba la demo', style: TextStyle(color: Color(0xFF6B6E82), fontSize: 12)),
            ),
            const Expanded(child: Divider(color: Color(0xFF2A2E45))),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _ocupado ? null : _iniciarSesionDemo,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00FFC8)),
              foregroundColor: const Color(0xFF00FFC8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _cargandoDemo
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FFC8)))
                : const Icon(Icons.play_circle_outline, color: Color(0xFF00FFC8)),
            label: Text(
              _cargandoDemo ? 'Cargando demo...' : 'Probar cuenta demo',
              style: const TextStyle(color: Color(0xFF00FFC8), fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sin registro · Datos de ejemplo · Solo lectura',
          style: TextStyle(color: Color(0xFF6B6E82), fontSize: 11), // Texto hint
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // ── Botones pequeños de registro ────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _ocupado
                  ? null
                  : () => mostrarFormRegistro(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF3296),
                side: const BorderSide(color: Color(0xFFFF3296)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Regístrate',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              width: 1, height: 16,
              color: const Color(0xFF2A2E45),
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
            TextButton(
              onPressed: _ocupado ? null : () => mostrarFormContactoInteres(context),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00FFC8),
                side: const BorderSide(color: Color(0xFF00FFC8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Trabaja con nosotros',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── FIX: método _restablecerPassword que faltaba ──────────────────────────
  Future<void> _restablecerPassword() async {
    final correo = _correoController.text.trim();

    // Si el campo está vacío pedimos el correo en un diálogo
    if (correo.isEmpty) {
      final ctrl = TextEditingController();
      final ingresado = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restablecer contraseña'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Tu correo electrónico',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Enviar'),
            ),
          ],
        ),
      );
      ctrl.dispose();
      if (ingresado == null || ingresado.isEmpty) return;
      await _enviarCorreoRestablecimiento(ingresado);
    } else {
      await _enviarCorreoRestablecimiento(correo);
    }
  }

  Future<void> _enviarCorreoRestablecimiento(String correo) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Correo de restablecimiento enviado a $correo'),
          backgroundColor: Colors.green[700],
        ),
      );
    } on FirebaseAuthException catch (e) {
      _mostrarError(_mapearErrorFirebase(e));
    } catch (e) {
      _mostrarError('Error al enviar correo: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTENTICACIÓN
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;

    final correo = _correoController.text.trim();
    final password = _passwordController.text;

    setState(() => _cargando = true);

    try {
      final estado = await FuerzaBrutaService().verificarEstado(correo);
      if (estado.bloqueado) {
        final min = estado.tiempoRestante.inMinutes;
        _mostrarError('Cuenta bloqueada temporalmente. Inténtalo en $min minutos.');
        return;
      }

      await AdminInitializer.crearUsuarioAdmin();

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: correo,
        password: password,
      );
      final user = cred.user!;

      await FuerzaBrutaService().registrarIntento(email: correo, exito: true);

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

  Future<void> _postLoginExitoso(User user, MetodoAuth metodo) async {
    await Future.wait([
      PermisosService().cargarSesion(),
      NotificacionesService().guardarTokenTrasLogin(),
    ]);

    final sesion = PermisosService().sesion;
    await AuditoriaService().registrar(
      tipo: TipoEventoAuditoria.loginOk,
      email: user.email ?? '',
      metodo: metodo,
      usuarioId: user.uid,
      empresaId: sesion?.empresaId,
      rol: sesion?.rol.name,
    );

    final bioActiva = await BiometriaService().estaActiva;
    if (!bioActiva && mounted) {
      await _ofrecerBiometria(user);
    }

    if (!mounted) return;
    // Redirigir según rol
    if (sesion?.rol == RolApp.clienteFinal) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PantallaExplorar()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PantallaDashboard()),
      );
    }
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

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red[700]),
    );
  }

  String _mapearErrorFirebase(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found'         => 'No existe ninguna cuenta con ese correo.',
      'wrong-password'         => 'Contraseña incorrecta.',
      'invalid-credential'     => 'Correo o contraseña incorrectos.',
      'invalid-email'          => 'El correo no tiene un formato válido.',
      'user-disabled'          => 'Esta cuenta ha sido deshabilitada.',
      'too-many-requests'      => 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
      'network-request-failed' => 'Sin conexión a internet. Comprueba tu red.',
      'email-already-in-use'   => 'Ya existe una cuenta con este correo.',
      'operation-not-allowed'  => 'Método de inicio de sesión no habilitado.',
      _                        => 'Error: ${e.message ?? e.code}',
    };
  }

  String _enmascararTelefono(String telefono) {
    if (telefono.length < 6) return telefono;
    final visible = telefono.substring(telefono.length - 2);
    return '${telefono.substring(0, 3)} *** *** $visible';
  }

  /// Verifica si el usuario actual (si está logueado) es propietario de plataforma.
  /// Retorna true si tiene el rol 'propietario' o el campo 'es_plataforma_admin: true'.
  Future<bool> _esUsuarioPropietarioPlataforma() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final rol = data['rol'] as String?;
      final esPlataformaAdmin = data['es_plataforma_admin'] as bool? ?? false;

      return rol == 'propietario' || esPlataformaAdmin;
    } catch (e) {
      debugPrint('❌ Error al verificar rol propietario: $e');
      return false;
    }
  }
}

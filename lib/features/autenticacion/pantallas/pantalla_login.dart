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

  // ── COLORES ───────────────────────────────────────────────────────────────

  static const _darkBg    = Color(0xFF070B14);
  static const _green     = Color(0xFF4ADE80);
  static const _greenDark = Color(0xFF15703A);
  static const _textDark  = Color(0xFF0E1626);
  static const _textMuted = Color(0xFF566072);
  static const _textHint  = Color(0xFF6B7485);
  static const _borderNormal = Color(0xFFC3C9D4);

  OutlineInputBorder _borde([Color? c]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c ?? _borderNormal),
  );

  InputDecoration _decoCampo({required String hint, required Widget prefix, Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _textHint),
    prefixIcon: prefix,
    suffixIcon: suffix,
    border: _borde(), enabledBorder: _borde(),
    focusedBorder: _borde(_greenDark),
    errorBorder: _borde(Colors.red), focusedErrorBorder: _borde(Colors.red),
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 14),
  );

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (_, c) => c.maxWidth >= 800 ? _buildWide() : _buildMobile(),
        ),
      ),
    );
  }

  // ── LAYOUT WIDE (desktop / tablet) ────────────────────────────────────────

  Widget _buildWide() => Row(children: [
    Expanded(flex: 55, child: _buildPanelIzquierdo()),
    Expanded(flex: 45, child: _buildPanelDerecho()),
  ]);

  Widget _buildPanelIzquierdo() {
    return Container(
      color: _darkBg,
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildMarca(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 72, height: 6, color: _green),
              const SizedBox(height: 28),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 52,
                    height: 1.02,
                    letterSpacing: -1.5,
                    color: Color(0xFFEAF0FA),
                  ),
                  children: [
                    TextSpan(text: 'Tu negocio,\n'),
                    TextSpan(
                      text: 'en una sola\npantalla.',
                      style: TextStyle(color: _green),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 24, runSpacing: 14,
                children: ['Reservas', 'TPV', 'Fichajes', 'Facturación']
                    .map((f) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, color: _green, size: 20),
                            const SizedBox(width: 10),
                            Text(f, style: const TextStyle(color: Color(0xFFEAF0FA), fontSize: 16, fontWeight: FontWeight.w500)),
                          ],
                        ))
                    .toList(),
              ),
            ],
          ),
          const Text(
            'Para hostelería, peluquería y comercio.',
            style: TextStyle(fontSize: 13, color: Color(0xFF9AA7BF)),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelDerecho() {
    return Container(
      color: Colors.white,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: _buildContenidoFormulario(),
          ),
        ),
      ),
    );
  }

  // ── LAYOUT MOBILE ─────────────────────────────────────────────────────────

  Widget _buildMobile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _buildMarca()),
          const SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(28),
            child: _buildContenidoFormulario(compact: true),
          ),
        ],
      ),
    );
  }

  // ── WIDGETS COMUNES ───────────────────────────────────────────────────────

  Widget _buildMarca() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(10)),
        child: const Center(
          child: Text('F', style: TextStyle(color: Color(0xFF052E16), fontSize: 24, fontWeight: FontWeight.w800)),
        ),
      ),
      const SizedBox(width: 12),
      const Text('Fluix', style: TextStyle(color: Color(0xFFEAF0FA), fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
    ],
  );

  Widget _buildContenidoFormulario({bool compact = false}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'Iniciar sesión',
        style: TextStyle(color: _textDark, fontSize: compact ? 24 : 30, fontWeight: FontWeight.w700, letterSpacing: -0.5),
      ),
      const SizedBox(height: 6),
      const Text('Introduce tus datos para acceder.', style: TextStyle(color: _textMuted, fontSize: 14)),
      SizedBox(height: compact ? 20 : 28),
      _buildFormulario(),
      SizedBox(height: compact ? 16 : 20),
      _buildDivisor(),
      SizedBox(height: compact ? 16 : 20),
      _buildEnlacesInferiores(),
    ],
  );

  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Correo electrónico', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _textDark)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _correoController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_ocupado,
            style: const TextStyle(color: _textDark, fontSize: 15),
            decoration: _decoCampo(
              hint: 'tu@correo.es',
              prefix: const Icon(Icons.email_outlined, color: _textMuted, size: 18),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Por favor ingresa tu correo';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Correo inválido';
              return null;
            },
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Contraseña', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _textDark)),
              TextButton(
                onPressed: _ocupado ? null : _restablecerPassword,
                style: TextButton.styleFrom(
                  foregroundColor: _greenDark,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('¿La has olvidado?', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_ocupado,
            style: const TextStyle(color: _textDark, fontSize: 15),
            decoration: _decoCampo(
              hint: 'Tu contraseña',
              prefix: const Icon(Icons.lock_outline, color: _textMuted, size: 18),
              suffix: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _textMuted, size: 18),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Por favor ingresa tu contraseña' : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _ocupado ? null : _iniciarSesion,
              style: ElevatedButton.styleFrom(
                backgroundColor: _darkBg,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFCBCFD8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _cargando
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Iniciar sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_forward, size: 18, color: _green),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivisor() => const Row(children: [
    Expanded(child: Divider(color: Color(0xFFE3E6EB))),
    Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Text('¿Aún no tienes cuenta?', style: TextStyle(fontSize: 13, color: _textMuted)),
    ),
    Expanded(child: Divider(color: Color(0xFFE3E6EB))),
  ]);

  Widget _buildEnlacesInferiores() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 48,
        child: OutlinedButton(
          onPressed: _ocupado ? null : () => mostrarFormRegistro(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: _greenDark,
            side: const BorderSide(color: _greenDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Regístrate', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(height: 16),
      Center(
        child: TextButton(
          onPressed: _ocupado ? null : () => mostrarFormContactoInteres(context),
          style: TextButton.styleFrom(foregroundColor: _textMuted),
          child: const Text(
            'Trabaja con nosotros',
            style: TextStyle(fontSize: 14, decoration: TextDecoration.underline, decorationColor: _textMuted),
          ),
        ),
      ),
    ],
  );

  // ── RESTABLECER CONTRASEÑA ────────────────────────────────────────────────

  Future<void> _restablecerPassword() async {
    final correo = _correoController.text.trim();
    if (correo.isEmpty) {
      final ctrl = TextEditingController();
      final ingresado = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restablecer contraseña'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Tu correo electrónico', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Enviar')),
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
        SnackBar(content: Text('Correo de restablecimiento enviado a $correo'), backgroundColor: Colors.green[700]),
      );
    } on FirebaseAuthException catch (e) {
      _mostrarError(_mapearErrorFirebase(e));
    } catch (e) {
      _mostrarError('Error al enviar correo: $e');
    }
  }

  // ── AUTENTICACIÓN ─────────────────────────────────────────────────────────

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
        email: correo, password: password,
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
      if (e.code == 'internal-error' || e.code == 'user-token-expired') {
        try {
          await FirebaseAuth.instance.signOut();
          await Future.delayed(const Duration(milliseconds: 800));
          final cred2 = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: correo, password: password,
          );
          await FuerzaBrutaService().registrarIntento(email: correo, exito: true);
          await _postLoginExitoso(cred2.user!, MetodoAuth.email);
          return;
        } catch (_) {}
      }
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
    if (sesion?.rol == RolApp.clienteFinal) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PantallaExplorar()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PantallaDashboard()));
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
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PantallaDashboard()));
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
        content: Text('¿Quieres usar $label para entrar la próxima vez sin escribir tu contraseña?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Ahora no')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF43A047)),
            child: const Text('Activar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (acepta == true) {
      await BiometriaService().activar(uid: user.uid, email: user.email ?? '');
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
      'internal-error'         => 'Error de sesión. Cierra la app completamente y vuelve a abrirla.',
      'user-token-expired'     => 'Sesión expirada. Vuelve a iniciar sesión.',
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

  Future<bool> _esUsuarioPropietarioPlataforma() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
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

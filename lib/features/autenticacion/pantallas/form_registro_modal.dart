import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';
import '../../../core/utils/permisos_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODAL DE REGISTRO — Estilo negro / rosa (contraste con login cian)
// ─────────────────────────────────────────────────────────────────────────────

void mostrarFormRegistro(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _FormRegistroModal(),
  );
}

class _FormRegistroModal extends StatefulWidget {
  const _FormRegistroModal();

  @override
  State<_FormRegistroModal> createState() => _FormRegistroModalState();
}

class _FormRegistroModalState extends State<_FormRegistroModal> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController        = TextEditingController();
  final _correoController        = TextEditingController();
  final _telefonoController      = TextEditingController();
  final _passwordController      = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword        = true;
  bool _obscureConfirmPassword = true;
  bool _cargando               = false;
  bool _registrado             = false;

  // ── Paleta negro / rosa ──────────────────────────────────────────────────
  static const _bg        = Color(0xFF08060E); // casi negro
  static const _surface   = Color(0xFF160F1E); // superficie oscura con toque morado
  static const _border    = Color(0xFF2E1E3A);
  static const _pink      = Color(0xFFFF3296); // rosa / magenta
  static const _textMuted = Color(0xFFB0A3BE);

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFF3296),
            blurRadius: 0,
            spreadRadius: 0,
            offset: Offset(0, -1),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _registrado ? _buildExito() : _buildFormulario(),
          ],
        ),
      ),
    );
  }

  // ── Pantalla de éxito ─────────────────────────────────────────────────────
  Widget _buildExito() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _pink.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: _pink, size: 44),
          ),
          const SizedBox(height: 20),
          const Text(
            '¡Cuenta creada! 🎉',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Bienvenido/a a Fluix.\nYa puedes empezar a explorar negocios y hacer reservas.',
            style: TextStyle(fontSize: 15, color: _textMuted, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('¡Empezar!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Formulario ────────────────────────────────────────────────────────────
  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Crear cuenta ✨',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Regístrate y empieza a reservar gratis',
                      style: TextStyle(fontSize: 13, color: _textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                color: _textMuted,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Nombre
          _campo(
            controller: _nombreController,
            label: 'Nombre completo',
            icono: Icons.person_outline,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Por favor ingresa tu nombre' : null,
          ),
          const SizedBox(height: 12),

          // Correo
          _campo(
            controller: _correoController,
            label: 'Correo electrónico',
            icono: Icons.email_outlined,
            tipo: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Por favor ingresa tu correo';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Teléfono
          _campo(
            controller: _telefonoController,
            label: 'Teléfono',
            icono: Icons.phone_outlined,
            tipo: TextInputType.phone,
            hint: '+34 600 000 000',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Por favor ingresa tu teléfono' : null,
          ),
          const SizedBox(height: 12),

          // Contraseña
          _campoPassword(
            controller: _passwordController,
            label: 'Contraseña',
            obscure: _obscurePassword,
            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Por favor ingresa una contraseña';
              if (v.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Confirmar contraseña
          _campoPassword(
            controller: _confirmPasswordController,
            label: 'Confirmar contraseña',
            obscure: _obscureConfirmPassword,
            onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Por favor confirma tu contraseña';
              if (v != _passwordController.text) return 'Las contraseñas no coinciden';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Botón registrarse
          SizedBox(
            width: double.infinity,
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF3296), Color(0xFFB0007A)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _pink.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _cargando ? null : _registrarUsuario,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _cargando
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Crear cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '🔒 Tus datos están protegidos',
              style: TextStyle(fontSize: 11, color: _textMuted.withValues(alpha: 0.6)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Helpers de campos ────────────────────────────────────────────────────
  Widget _campo({
    required TextEditingController controller,
    required String label,
    required IconData icono,
    TextInputType tipo = TextInputType.text,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: tipo,
      enabled: !_cargando,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textMuted),
        hintText: hint,
        hintStyle: TextStyle(color: _textMuted.withValues(alpha: 0.4), fontSize: 12),
        prefixIcon: Icon(icono, color: _pink),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _pink, width: 2)),
        filled: true,
        fillColor: _surface,
      ),
      validator: validator,
    );
  }

  Widget _campoPassword({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      enabled: !_cargando,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _textMuted),
        prefixIcon: const Icon(Icons.lock_outline, color: _pink),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: _textMuted),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _pink, width: 2)),
        filled: true,
        fillColor: _surface,
      ),
      validator: validator,
    );
  }

  // ── Lógica de registro ───────────────────────────────────────────────────
  Future<void> _registrarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      final credencial = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _correoController.text.trim(),
        password: _passwordController.text,
      );

      final user = credencial.user!;
      await user.updateDisplayName(_nombreController.text.trim());

      final appUser = AppUser(
        id: user.uid,
        email: _correoController.text.trim(),
        name: _nombreController.text.trim(),
        role: UserRole.clienteFinal,
        telefono: _telefonoController.text.trim(),
        createdAt: DateTime.now(),
        isActive: true,
      );

      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
        ...appUser.toJson(),
        'rol': 'clienteFinal',
        'correo': _correoController.text.trim(),
        'nombre': _nombreController.text.trim(),
        'empresa_id': '',
      });

      if (!mounted) return;
      await PermisosService().cargarSesion();
      if (!mounted) return;

      setState(() { _cargando = false; _registrado = true; });

      // Navegar a Explorar tras cerrar el modal
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
        // La navegación a PantallaExplorar la gestiona el auth state listener
      });

    } on FirebaseAuthException catch (e) {
      _mostrarError(_mapearErrorFirebase(e));
    } catch (e) {
      _mostrarError('Error al crear cuenta: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
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
      'email-already-in-use'   => 'Ya existe una cuenta con este correo.',
      'invalid-email'          => 'El correo no tiene un formato válido.',
      'operation-not-allowed'  => 'Registro no habilitado.',
      'weak-password'          => 'La contraseña es muy débil.',
      'network-request-failed' => 'Sin conexión a internet.',
      _                        => 'Error: ${e.message ?? e.code}',
    };
  }
}




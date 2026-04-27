import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA — Recuperar contraseña
//
// Llama a la Cloud Function 'sendResetPasswordEmail' que genera un link
// de reset con Firebase Admin SDK y lo envía con nuestro template HTML
// personalizado via Resend (mismo diseño que invitacion.html).
//
// Flujo:
//   1. Usuario introduce su correo
//   2. Se llama a la Cloud Function
//   3. Mensaje de éxito genérico (no revela si el email está registrado)
// ─────────────────────────────────────────────────────────────────────────────

class PantallaRecuperarPassword extends StatefulWidget {
  /// Pre-rellena el campo de email si viene desde la pantalla de login.
  final String? emailInicial;

  const PantallaRecuperarPassword({super.key, this.emailInicial});

  @override
  State<PantallaRecuperarPassword> createState() =>
      _PantallaRecuperarPasswordState();
}

class _PantallaRecuperarPasswordState
    extends State<PantallaRecuperarPassword> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  bool _enviando = false;
  bool _enviado = false;

  static const _primaryColor = Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.emailInicial ?? '');
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Envío ──────────────────────────────────────────────────────────────────

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    try {
      final fn = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable(
        'sendResetPasswordEmail',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      await fn.call({'email': _emailCtrl.text.trim()});
      if (mounted) setState(() => _enviado = true);
    } on FirebaseFunctionsException catch (e) {
      _mostrarError(_mapearError(e));
    } catch (e) {
      _mostrarError('Error inesperado. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  String _mapearError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'invalid-argument':
        return 'El correo introducido no es válido.';
      case 'unavailable':
        return 'Servicio no disponible. Inténtalo más tarde.';
      default:
        return 'No se pudo enviar el email. Inténtalo de nuevo.';
    }
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Recuperar contraseña',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _enviado ? _buildExito() : _buildFormulario(),
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Icono ──────────────────────────────────────────────────────────
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_reset, color: _primaryColor, size: 40),
          ),
        ),
        const SizedBox(height: 24),

        // ── Texto ──────────────────────────────────────────────────────────
        const Text(
          '¿Olvidaste tu contraseña?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Introduce tu correo electrónico y te enviaremos un enlace para que puedas crear una nueva contraseña.',
          style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
        ),
        const SizedBox(height: 32),

        // ── Formulario ──────────────────────────────────────────────────────
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                enabled: !_enviando,
                onFieldSubmitted: (_) => _enviar(),
                decoration: InputDecoration(
                  labelText: 'Correo electrónico',
                  hintText: 'nombre@empresa.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Por favor ingresa tu correo';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$')
                      .hasMatch(v.trim())) {
                    return 'Formato de correo inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Botón enviar ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _enviando ? null : _enviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _enviando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Enviar enlace',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Info expiración ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber[800], size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'El enlace de restablecimiento caduca en 1 hora.',
                  style: TextStyle(fontSize: 13, color: Colors.amber[900]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildExito() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green[50],
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.mark_email_read_outlined,
                size: 52, color: Colors.green[700]),
          ),
          const SizedBox(height: 28),
          const Text(
            '¡Email enviado!',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Si el correo ${_emailCtrl.text.trim()} está registrado, recibirás en breve un enlace para restablecer tu contraseña.',
              style: TextStyle(
                  fontSize: 15, color: Colors.grey[600], height: 1.6),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Revisa también tu carpeta de spam.',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _primaryColor),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Volver al inicio de sesión',
                style: TextStyle(
                    color: _primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() {
              _enviado = false;
              _emailCtrl.clear();
            }),
            child: Text(
              '¿No llegó el email? Reenviar',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}


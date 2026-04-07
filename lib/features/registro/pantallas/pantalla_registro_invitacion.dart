import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/auth/invitaciones_service.dart';
import '../../../services/notificaciones_service.dart';
import '../../../core/utils/permisos_service.dart';
import '../../dashboard/pantallas/pantalla_dashboard.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA — Registro desde invitación
//
// Se abre cuando la app recibe el deep link:
//   fluixcrm://invite?token=XXX
//
// Flujo:
//   1. Valida el token (existencia, expiración, ya usado)
//   2. Muestra formulario: nombre + contraseña
//   3. Crea cuenta en Firebase Auth + documento en Firestore
//   4. Marca la invitación como usada
// ─────────────────────────────────────────────────────────────────────────────

class PantallaRegistroInvitacion extends StatefulWidget {
  final String token;

  const PantallaRegistroInvitacion({super.key, required this.token});

  @override
  State<PantallaRegistroInvitacion> createState() =>
      _PantallaRegistroInvitacionState();
}

class _PantallaRegistroInvitacionState
    extends State<PantallaRegistroInvitacion> {
  final _svc = InvitacionesService();
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _cargando = true;
  bool _registrando = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  Invitacion? _invitacion;
  String? _errorToken;

  @override
  void initState() {
    super.initState();
    _validarToken();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _validarToken() async {
    final inv = await _svc.validarToken(widget.token);
    if (!mounted) return;

    if (inv == null) {
      setState(() {
        _errorToken = 'El enlace de invitación no existe o ha sido eliminado.';
        _cargando = false;
      });
      return;
    }

    if (!inv.valida) {
      setState(() {
        _errorToken = inv.estado == EstadoInvitacion.usada
            ? 'Este enlace ya fue usado. Si necesitas acceso, pide al administrador que te envíe uno nuevo.'
            : 'Este enlace ha expirado (válido 72 horas). Pide al administrador un nuevo enlace.';
        _cargando = false;
      });
      return;
    }

    setState(() { _invitacion = inv; _cargando = false; });
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    final inv = _invitacion!;

    setState(() => _registrando = true);
    try {
      // 1. Crear cuenta en Firebase Auth
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: inv.email,
        password: _passCtrl.text,
      );

      await cred.user!.updateDisplayName(_nombreCtrl.text.trim());

      // 2. Crear doc en Firestore + marcar invitación como usada
      await _svc.completarRegistro(
        token: widget.token,
        firebaseUser: cred.user!,
        nombre: _nombreCtrl.text.trim(),
        invitacion: inv,
      );

      // 3. Cargar sesión y navegar
      await Future.wait([
        NotificacionesService().guardarTokenTrasLogin(),
        PermisosService().cargarSesion(),
      ]);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PantallaDashboard()),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'email-already-in-use' =>
          'Ya existe una cuenta con este email. Inicia sesión en lugar de registrarte.',
        'weak-password' => 'La contraseña es demasiado débil.',
        _ => 'Error: ${e.message}',
      };
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg), backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _registrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Unirse al equipo'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _errorToken != null
              ? _buildError()
              : _buildFormulario(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.link_off, size: 72, color: Colors.red),
          const SizedBox(height: 20),
          Text(_errorToken!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.5)),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Volver'),
          ),
        ]),
      ),
    );
  }

  Widget _buildFormulario() {
    final inv = _invitacion!;
    final rolLabel = inv.rol == 'admin' ? 'Administrador' : 'Empleado';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera informativa
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.2)),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Invitación para unirte a',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(inv.empresaNombre,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1))),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.email_outlined, size: 15, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(inv.email, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(rolLabel,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: Color(0xFF0D47A1))),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 28),

            const Text('Crea tu cuenta',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre completo *',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Introduce tu nombre' : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              decoration: InputDecoration(
                labelText: 'Contraseña *',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass
                      ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Introduce una contraseña';
                if (v.length < 8) return 'Mínimo 8 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña *',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) => v != _passCtrl.text
                  ? 'Las contraseñas no coinciden' : null,
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _registrando ? null : _registrar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _registrando
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                label: Text(_registrando ? 'Creando cuenta...' : 'Crear cuenta y entrar',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


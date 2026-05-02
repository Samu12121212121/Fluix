import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../dashboard/pantallas/pantalla_dashboard.dart';

/// Pantalla para que un empleado invitado complete su registro
/// usando el token recibido por deep link (fluixcrm://invite?token=XXX).
class PantallaRegistroInvitacion extends StatefulWidget {
  final String token;

  const PantallaRegistroInvitacion({super.key, required this.token});

  @override
  State<PantallaRegistroInvitacion> createState() =>
      _PantallaRegistroInvitacionState();
}

class _PantallaRegistroInvitacionState
    extends State<PantallaRegistroInvitacion> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _cargando = true;
  bool _guardando = false;
  bool _obscure = true;
  String? _error;

  Map<String, dynamic>? _invitacion;

  @override
  void initState() {
    super.initState();
    _cargarInvitacion();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarInvitacion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('invitaciones')
          .doc(widget.token)
          .get();

      if (!doc.exists) {
        setState(() {
          _error = 'Invitación no válida o ya utilizada.';
          _cargando = false;
        });
        return;
      }

      final data = doc.data()!;
      if (data['usada'] == true) {
        setState(() {
          _error = 'Esta invitación ya fue utilizada.';
          _cargando = false;
        });
        return;
      }

      setState(() {
        _invitacion = data;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar la invitación: $e';
        _cargando = false;
      });
    }
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_invitacion == null) return;

    setState(() => _guardando = true);

    try {
      final email = _invitacion!['email'] as String;
      final empresaId = _invitacion!['empresa_id'] as String;
      final rol = _invitacion!['rol'] as String? ?? 'staff';

      // Crear cuenta en Firebase Auth
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: _passwordCtrl.text,
      );

      final uid = cred.user!.uid;

      // Crear documento de usuario
      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        'nombre': _nombreCtrl.text.trim(),
        'email': email,
        'empresa_id': empresaId,
        'rol': rol,
        'activo': true,
        'fecha_registro': FieldValue.serverTimestamp(),
        'modulos_permitidos': _invitacion!['modulos_permitidos'] ?? [],
      });

      // Marcar invitación como usada
      await FirebaseFirestore.instance
          .collection('invitaciones')
          .doc(widget.token)
          .update({
        'usada': true,
        'usado_por': uid,
        'fecha_uso': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PantallaDashboard()),
            (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mapError(e)),
          backgroundColor: Colors.red[700],
        ),
      );
    } catch (e) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
      );
    }
  }

  String _mapError(FirebaseAuthException e) {
    return switch (e.code) {
      'email-already-in-use' => 'Ya existe una cuenta con este correo.',
      'weak-password'        => 'La contraseña debe tener al menos 6 caracteres.',
      'invalid-email'        => 'El correo no es válido.',
      _                      => 'Error: ${e.message ?? e.code}',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unirte al equipo'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Has sido invitado a unirte como ${_invitacion!['rol'] ?? 'staff'}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Correo: ${_invitacion!['email']}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nombreCtrl,
                decoration: InputDecoration(
                  labelText: 'Tu nombre',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'El nombre es obligatorio'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () =>
                        setState(() => _obscure = !_obscure),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'La contraseña es obligatoria';
                  }
                  if (v.length < 6) {
                    return 'Mínimo 6 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _registrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _guardando
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Crear cuenta y entrar',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
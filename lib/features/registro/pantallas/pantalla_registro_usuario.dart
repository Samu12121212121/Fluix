import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../dashboard/pantallas/pantalla_dashboard.dart';
import '../../../core/enums/enums.dart';

/// Registro para clientes B2C (usuarios sin empresa).
class PantallaRegistroUsuario extends StatefulWidget {
  const PantallaRegistroUsuario({super.key});

  @override
  State<PantallaRegistroUsuario> createState() => _PantallaRegistroUsuarioState();
}

class _PantallaRegistroUsuarioState extends State<PantallaRegistroUsuario> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl    = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  bool _cargando = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      await cred.user!.updateDisplayName(_nombreCtrl.text.trim());
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(cred.user!.uid)
          .set({
        'nombre': _nombreCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'rol': 'usuario',
        'tipo_cuenta': 'usuario',
        'empresa_id': null,
        'vista_activa': 'usuario',
        'fecha_creacion': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => const PantallaDashboard(
                    vistaInicial: VistaActiva.usuario,
                  )),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.code == 'email-already-in-use'
          ? 'Ya existe una cuenta con ese email'
          : e.code == 'weak-password'
              ? 'La contraseña debe tener al menos 6 caracteres'
              : 'Error al crear la cuenta';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(children: [
              const Text(
                'Únete a Fluix',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Descubre los mejores negocios cerca de ti',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _nombreCtrl,
                decoration: InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey[50],
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 2) return 'Introduce tu nombre (mín. 2 chars)';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey[50],
                ),
                validator: (v) {
                  if (v == null || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                    return 'Introduce un email válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey[50],
                ),
                validator: (v) {
                  if (v == null || v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true, fillColor: Colors.grey[50],
                ),
                validator: (v) {
                  if (v != _passCtrl.text) return 'Las contraseñas no coinciden';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _cargando ? null : _registrar,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF43A047),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _cargando
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Crear cuenta',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('¿Ya tienes cuenta? Inicia sesión',
                    style: TextStyle(color: Colors.grey[600])),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}


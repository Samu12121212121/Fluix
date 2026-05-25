import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/user_model.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../features/explorar_negocios/pantallas/pantalla_explorar.dart';

class PantallaRegistroCliente extends StatefulWidget {
  const PantallaRegistroCliente({super.key});

  @override
  State<PantallaRegistroCliente> createState() => _PantallaRegistroClienteState();
}

class _PantallaRegistroClienteState extends State<PantallaRegistroCliente> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _cargando = false;

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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF43A047)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildFormFields(),
                const SizedBox(height: 32),
                _buildRegistrarButton(),
                const SizedBox(height: 16),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.person_add_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Crear cuenta',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Regístrate para reservar en tus negocios favoritos',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nombreController,
          enabled: !_cargando,
          decoration: InputDecoration(
            labelText: 'Nombre completo',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Por favor ingresa tu nombre';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _correoController,
          keyboardType: TextInputType.emailAddress,
          enabled: !_cargando,
          decoration: InputDecoration(
            labelText: 'Correo electrónico',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Por favor ingresa tu correo';
            }
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
              return 'Ingresa un correo válido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _telefonoController,
          keyboardType: TextInputType.phone,
          enabled: !_cargando,
          decoration: InputDecoration(
            labelText: 'Teléfono',
            prefixIcon: const Icon(Icons.phone_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
            hintText: '+34 600 000 000',
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Por favor ingresa tu teléfono';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          enabled: !_cargando,
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
            if (value == null || value.isEmpty) {
              return 'Por favor ingresa una contraseña';
            }
            if (value.length < 6) {
              return 'La contraseña debe tener al menos 6 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          enabled: !_cargando,
          decoration: InputDecoration(
            labelText: 'Confirmar contraseña',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Por favor confirma tu contraseña';
            }
            if (value != _passwordController.text) {
              return 'Las contraseñas no coinciden';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildRegistrarButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _cargando ? null : _registrarUsuario,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF43A047),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: _cargando
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Crear cuenta',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: TextButton(
        onPressed: _cargando ? null : () => Navigator.pop(context),
        child: const Text(
          '¿Ya tienes cuenta? Inicia sesión',
          style: TextStyle(
            color: Color(0xFF43A047),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _registrarUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      // Crear usuario en Firebase Auth
      final credencial = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _correoController.text.trim(),
        password: _passwordController.text,
      );

      final user = credencial.user!;

      // Actualizar displayName
      await user.updateDisplayName(_nombreController.text.trim());

      // Crear documento en Firestore
      final appUser = AppUser(
        id: user.uid,
        email: _correoController.text.trim(),
        name: _nombreController.text.trim(),
        role: UserRole.clienteFinal,
        telefono: _telefonoController.text.trim(),
        createdAt: DateTime.now(),
        isActive: true,
      );

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .set({
            ...appUser.toJson(),
            'rol': 'clienteFinal',  // campo canónico leído por PermisosService
            'correo': _correoController.text.trim(),
            'nombre': _nombreController.text.trim(),
            'empresa_id': '',
          });

      if (!mounted) return;

      // Cargar sesión y navegar a Explorar directamente
      await PermisosService().cargarSesion();

      if (!mounted) return;

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuenta creada exitosamente! Bienvenido 🎉'),
          backgroundColor: Colors.green,
        ),
      );

      // Navegar directamente a Explorar
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PantallaExplorar()),
        (_) => false,
      );
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
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red[700],
      ),
    );
  }

  String _mapearErrorFirebase(FirebaseAuthException e) {
    return switch (e.code) {
      'email-already-in-use' => 'Ya existe una cuenta con este correo.',
      'invalid-email' => 'El correo no tiene un formato válido.',
      'operation-not-allowed' => 'Registro no habilitado.',
      'weak-password' => 'La contraseña es muy débil.',
      'network-request-failed' => 'Sin conexión a internet.',
      _ => 'Error: ${e.message ?? e.code}',
    };
  }
}


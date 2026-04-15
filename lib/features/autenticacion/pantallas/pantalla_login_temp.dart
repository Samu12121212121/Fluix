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

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 1),
                      
                      // ── Logo ──────────────────────────────────────
                      _buildLogo(),
                      const SizedBox(height: 48),
                      
                      // ── Formulario ───────────────────────────────
                      _buildLoginForm(),
                      const SizedBox(height: 24),
                      
                      // ── Botones sociales ─────────────────────────
                      _buildSocialButtons(),
                      const SizedBox(height: 32),
                      
                      // ── Enlaces ──────────────────────────────────
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
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
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
            enabled: !_cargando && !_cargandoGoogle && !_cargandoApple,
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu correo';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
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
            enabled: !_cargando && !_cargandoGoogle && !_cargandoApple,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa tu contraseña';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // ── Botón iniciar sesión ─────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: (_cargando || _cargandoGoogle || _cargandoApple) ? null : _iniciarSesion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                      'Iniciar Sesión',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
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
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Image.asset('assets/iconos/google.png', height: 20),
            label: Text(_cargandoGoogle ? 'Conectando...' : 'Continuar con Google'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        
        // ── Botón Apple Sign-In (solo iOS) ─────────
        if (!kIsWeb && Platform.isIOS) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: (_cargando || _cargandoGoogle || _cargandoApple) ? null : _iniciarSesionConApple,
              icon: _cargandoApple
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.apple, color: Colors.black),
              label: Text(_cargandoApple ? 'Conectando...' : 'Continuar con Apple'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooterLinks() {
    return Column(
      children: [
        // ── Registrar Nueva Empresa ─────────────────
        TextButton(
          onPressed: (_cargando || _cargandoGoogle || _cargandoApple) ? null : () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PantallaRegistro()),
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
        
        // ── ¿Olvidaste tu contraseña? ───────────────
        TextButton(
          onPressed: (_cargando || _cargandoGoogle || _cargandoApple) ? null : _restablecerPassword,
          child: Text(
            '¿Olvidaste tu contraseña?',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MÉTODOS DE AUTENTICACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _cargando = true);

    try {
      final correo = _correoController.text.trim();
      final password = _passwordController.text;

      // Aquí va la lógica de autenticación con email/password
      // Por ahora solo simulamos el login
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PantallaDashboard()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _iniciarSesionConGoogle() async {
    setState(() => _cargandoGoogle = true);

    try {
      // Aquí va la lógica de autenticación con Google
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PantallaDashboard()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error con Google Sign-In: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargandoGoogle = false);
      }
    }
  }

  Future<void> _iniciarSesionConApple() async {
    setState(() => _cargandoApple = true);

    try {
      // Aquí va la lógica de autenticación con Apple
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PantallaDashboard()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error con Apple Sign-In: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargandoApple = false);
      }
    }
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

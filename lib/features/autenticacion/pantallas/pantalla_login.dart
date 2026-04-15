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
                    children: const [
                      // Widget content will be built by other methods
                      Text('Login Screen - Basic structure')
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

  // Placeholder methods for basic compilation
  Future<void> _iniciarSesion() async {}
  Future<void> _iniciarSesionConGoogle() async {}
  Future<void> _iniciarSesionConApple() async {}
  Future<void> _restablecerPassword() async {}
}

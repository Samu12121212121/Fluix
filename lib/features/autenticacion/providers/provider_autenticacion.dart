import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Estados posibles del proceso de autenticación
enum EstadoAutenticacion {
  inicial,
  cargando,
  autenticado,
  noAutenticado,
  error,
  requiereOnboarding,
}

/// Provider de autenticación basado en Firebase Auth real.
/// Escucha [FirebaseAuth.authStateChanges] para reaccionar a cambios de sesión.
class ProviderAutenticacion extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  EstadoAutenticacion _estado = EstadoAutenticacion.inicial;
  String? _mensajeError;

  // Getters
  EstadoAutenticacion get estado => _estado;
  User? get usuarioActual => _auth.currentUser;
  String? get mensajeError => _mensajeError;
  bool get estaAutenticado => _estado == EstadoAutenticacion.autenticado;
  bool get estaCargando => _estado == EstadoAutenticacion.cargando;

  /// Constructor - Inicializar listener del estado de autenticación
  ProviderAutenticacion() {
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _cambiarEstado(EstadoAutenticacion.autenticado);
      } else {
        _cambiarEstado(EstadoAutenticacion.noAutenticado);
      }
    });
  }

  /// Iniciar sesión con email y contraseña
  Future<void> iniciarSesion({
    required String correo,
    required String password,
  }) async {
    _limpiarError();
    _cambiarEstado(EstadoAutenticacion.cargando);

    try {
      await _auth.signInWithEmailAndPassword(email: correo, password: password);
      // El authStateChanges listener manejará el cambio de estado
    } on FirebaseAuthException catch (e) {
      _manejarError(_mensajeFirebase(e.code));
    } catch (e) {
      _manejarError(e.toString());
    }
  }

  /// Registrar nueva empresa con su propietario
  Future<void> registrarEmpresa({
    required String nombreEmpresa,
    required String correoEmpresa,
    required String telefonoEmpresa,
    required String direccionEmpresa,
    required String nombrePropietario,
    required String correoPropietario,
    required String telefonoPropietario,
    required String password,
  }) async {
    _limpiarError();
    _cambiarEstado(EstadoAutenticacion.cargando);

    try {
      // 1. Crear usuario en Firebase Auth
      final cred = await _auth.createUserWithEmailAndPassword(
        email: correoPropietario,
        password: password,
      );
      final uid = cred.user!.uid;

      // 2. Crear empresa en Firestore
      final empresaRef = _db.collection('empresas').doc();
      await empresaRef.set({
        'nombre': nombreEmpresa,
        'correo': correoEmpresa,
        'telefono': telefonoEmpresa,
        'direccion': direccionEmpresa,
        'propietario_id': uid,
        'onboarding_completado': false,
        'plan': 'basico',
        'activo': true,
        'fecha_creacion': FieldValue.serverTimestamp(),
      });

      // 3. Crear documento del propietario
      await _db.collection('usuarios').doc(uid).set({
        'nombre': nombrePropietario,
        'correo': correoPropietario,
        'telefono': telefonoPropietario,
        'empresa_id': empresaRef.id,
        'rol': 'propietario',
        'activo': true,
        'fecha_creacion': FieldValue.serverTimestamp(),
        'permisos': [],
      });

      _cambiarEstado(EstadoAutenticacion.requiereOnboarding);
    } on FirebaseAuthException catch (e) {
      _manejarError(_mensajeFirebase(e.code));
    } catch (e) {
      _manejarError(e.toString());
    }
  }

  /// Cerrar sesión
  Future<void> cerrarSesion() async {
    _cambiarEstado(EstadoAutenticacion.cargando);
    
    try {
      await _auth.signOut();
      // El authStateChanges listener manejará el cambio de estado
    } catch (e) {
      _manejarError(e.toString());
    }
  }

  /// Enviar email de recuperación de contraseña
  Future<void> enviarRecuperacionPassword(String correo) async {
    _limpiarError();
    
    try {
      await _auth.sendPasswordResetEmail(email: correo);
    } on FirebaseAuthException catch (e) {
      _manejarError(_mensajeFirebase(e.code));
    } catch (e) {
      _manejarError(e.toString());
    }
  }

  /// Completar onboarding tras registro
  void completarOnboarding() {
    if (_estado == EstadoAutenticacion.requiereOnboarding) {
      _cambiarEstado(EstadoAutenticacion.autenticado);
    }
  }

  /// Limpiar mensajes de error
  void limpiarError() => _limpiarError();

  // Métodos privados
  
  void _cambiarEstado(EstadoAutenticacion nuevoEstado) {
    _estado = nuevoEstado;
    notifyListeners();
  }

  void _manejarError(String error) {
    _mensajeError = error;
    _cambiarEstado(EstadoAutenticacion.error);
  }

  void _limpiarError() {
    _mensajeError = null;
    notifyListeners();
  }

  String _mensajeFirebase(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con este correo.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este correo.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'too-many-requests':
        return 'Demasiados intentos. Inténtalo más tarde.';
      default:
        return 'Error de autenticación: $code';
    }
  }
}

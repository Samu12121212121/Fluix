      // TODO: Implementar con repositorio real
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
      await Future.delayed(const Duration(seconds: 1)); // Simulación
/// Provider de autenticación basado en Firebase Auth real.
/// Escucha [FirebaseAuth.authStateChanges] para reaccionar a cambios de sesión.
      // TODO: Implementar con repositorio real
      await Future.delayed(const Duration(milliseconds: 500)); // Simulación

      // TODO: Implementar con repositorio real
      await Future.delayed(const Duration(seconds: 2)); // Simulación


  // Métodos simplificados temporales
import 'package:flutter/foundation.dart';
enum EstadoAutenticacion {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  inicial,
  cargando,
  autenticado,
  noAutenticado,
  error,
// Provider temporal simplificado para autenticación
  String? _mensajeError;

  User? get usuarioActual => _auth.currentUser;
  // Getters
  String? get mensajeError => _mensajeError;
  bool get estaAutenticado => _estado == EstadoAutenticacion.autenticado;
  bool get estaCargando => _estado == EstadoAutenticacion.cargando;

    required String password,
  }) async {
    _limpiarError();
      await _auth.signInWithEmailAndPassword(email: correo, password: password);
      // TODO: Implementar con repositorio real
    } on FirebaseAuthException catch (e) {
      _manejarError(_mensajeFirebase(e.code));
      await Future.delayed(const Duration(seconds: 1)); // Simulación
      _cambiarEstado(EstadoAutenticacion.autenticado);
    } catch (e) {
      _manejarError(e.toString());
    }
  }

  Future<void> registrarEmpresa({
    required String correoEmpresa,
    required String telefonoEmpresa,
    required String direccionEmpresa,
    required String nombrePropietario,
    required String correoPropietario,
      // TODO: Implementar con repositorio real
      await Future.delayed(const Duration(seconds: 1)); // Simulación
    required String password,
  }) async {

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

      await Future.delayed(const Duration(seconds: 2)); // Simulación
    } on FirebaseAuthException catch (e) {
      _manejarError(_mensajeFirebase(e.code));
      _cambiarEstado(EstadoAutenticacion.requiereOnboarding);
    } catch (e) {
      _manejarError(e.toString());
    }
  }

  Future<void> cerrarSesion() async {

      await _auth.signOut();
      await Future.delayed(const Duration(milliseconds: 500)); // Simulación
      _cambiarEstado(EstadoAutenticacion.noAutenticado);
    } catch (e) {
      _manejarError(e.toString());
    }
  }

  Future<void> enviarRecuperacionPassword(String correo) async {

      await _auth.sendPasswordResetEmail(email: correo);
    } on FirebaseAuthException catch (e) {
      _manejarError(_mensajeFirebase(e.code));
      await Future.delayed(const Duration(seconds: 1)); // Simulación
    } catch (e) {
      _manejarError(e.toString());
    }
  }

  void completarOnboarding() {
    if (_estado == EstadoAutenticacion.requiereOnboarding) {
      _cambiarEstado(EstadoAutenticacion.autenticado);
    }
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


  void limpiarError() => _limpiarError();
}

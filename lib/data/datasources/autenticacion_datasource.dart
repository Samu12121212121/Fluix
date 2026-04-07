import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/errores/excepciones.dart';
import '../../core/constantes/constantes_app.dart';

abstract class DataSourceAutenticacion {
  Stream<User?> get estadoAutenticacion;
  User? get usuarioActual;

  Future<UserCredential> iniciarSesionConCorreo(String correo, String password);
  Future<UserCredential> registrarConCorreo(String correo, String password);
  Future<void> cerrarSesion();
  Future<void> enviarRecuperacionPassword(String correo);
  Future<void> actualizarPassword(String passwordActual, String nuevoPassword);
  Future<void> eliminarCuenta();
}

class DataSourceAutenticacionFirebase implements DataSourceAutenticacion {
  final FirebaseAuth _firebaseAuth;

  DataSourceAutenticacionFirebase(this._firebaseAuth);

  @override
  Stream<User?> get estadoAutenticacion => _firebaseAuth.authStateChanges();

  @override
  User? get usuarioActual => _firebaseAuth.currentUser;

  @override
  Future<UserCredential> iniciarSesionConCorreo(
    String correo,
    String password,
  ) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: correo,
        password: password,
      );

      if (credential.user == null) {
        throw const ExcepcionAutenticacion('No se pudo autenticar el usuario');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _mapearExcepcionFirebaseAuth(e);
    } catch (e) {
      throw ExcepcionAutenticacion(e.toString());
    }
  }

  @override
  Future<UserCredential> registrarConCorreo(
    String correo,
    String password,
  ) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: correo,
        password: password,
      );

      if (credential.user == null) {
        throw const ExcepcionAutenticacion('No se pudo crear el usuario');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _mapearExcepcionFirebaseAuth(e);
    } catch (e) {
      throw ExcepcionAutenticacion(e.toString());
    }
  }

  @override
  Future<void> cerrarSesion() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw ExcepcionAutenticacion(e.toString());
    }
  }

  @override
  Future<void> enviarRecuperacionPassword(String correo) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: correo);
    } on FirebaseAuthException catch (e) {
      throw _mapearExcepcionFirebaseAuth(e);
    } catch (e) {
      throw ExcepcionAutenticacion(e.toString());
    }
  }

  @override
  Future<void> actualizarPassword(
    String passwordActual,
    String nuevoPassword,
  ) async {
    try {
      final usuario = _firebaseAuth.currentUser;
      if (usuario == null) {
        throw const ExcepcionAutenticacion('Usuario no autenticado');
      }

      // Re-autenticar antes de cambiar contraseña
      final credential = EmailAuthProvider.credential(
        email: usuario.email!,
        password: passwordActual,
      );

      await usuario.reauthenticateWithCredential(credential);
      await usuario.updatePassword(nuevoPassword);
    } on FirebaseAuthException catch (e) {
      throw _mapearExcepcionFirebaseAuth(e);
    } catch (e) {
      throw ExcepcionAutenticacion(e.toString());
    }
  }

  @override
  Future<void> eliminarCuenta() async {
    try {
      final usuario = _firebaseAuth.currentUser;
      if (usuario == null) {
        throw const ExcepcionAutenticacion('Usuario no autenticado');
      }

      await usuario.delete();
    } on FirebaseAuthException catch (e) {
      throw _mapearExcepcionFirebaseAuth(e);
    } catch (e) {
      throw ExcepcionAutenticacion(e.toString());
    }
  }

  ExcepcionAutenticacion _mapearExcepcionFirebaseAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return const ExcepcionAutenticacion(
          'No se encontró un usuario con este correo electrónico.',
          codigo: 'usuario-no-encontrado',
        );
      case 'wrong-password':
        return const ExcepcionAutenticacion(
          'Contraseña incorrecta.',
          codigo: 'password-incorrecto',
        );
      case 'email-already-in-use':
        return const ExcepcionAutenticacion(
          'Ya existe una cuenta con este correo electrónico.',
          codigo: 'correo-en-uso',
        );
      case 'weak-password':
        return const ExcepcionAutenticacion(
          'La contraseña es muy débil.',
          codigo: 'password-debil',
        );
      case 'invalid-email':
        return const ExcepcionAutenticacion(
          'El correo electrónico no es válido.',
          codigo: 'correo-invalido',
        );
      case 'user-disabled':
        return const ExcepcionAutenticacion(
          'Esta cuenta ha sido deshabilitada.',
          codigo: 'usuario-deshabilitado',
        );
      case 'too-many-requests':
        return const ExcepcionAutenticacion(
          'Demasiados intentos fallidos. Intenta más tarde.',
          codigo: 'demasiados-intentos',
        );
      case 'requires-recent-login':
        return const ExcepcionAutenticacion(
          'Esta operación requiere autenticación reciente.',
          codigo: 'requiere-reautenticacion',
        );
      default:
        return ExcepcionAutenticacion(
          e.message ?? 'Error de autenticación',
          codigo: e.code,
        );
    }
  }
}

abstract class DataSourceUsuarios {
  Future<Map<String, dynamic>?> obtenerUsuario(String uid);
  Future<void> crearUsuario(String uid, Map<String, dynamic> datos);
  Future<void> actualizarUsuario(String uid, Map<String, dynamic> datos);
  Future<void> eliminarUsuario(String uid);
  Stream<Map<String, dynamic>?> streamUsuario(String uid);
}

class DataSourceUsuariosFirestore implements DataSourceUsuarios {
  final FirebaseFirestore _firestore;

  DataSourceUsuariosFirestore(this._firestore);

  CollectionReference get _coleccionUsuarios =>
      _firestore.collection(ConstantesApp.coleccionUsuarios);

  @override
  Future<Map<String, dynamic>?> obtenerUsuario(String uid) async {
    try {
      final doc = await _coleccionUsuarios.doc(uid).get();
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    } on FirebaseException catch (e) {
      throw _mapearExcepcionFirestore(e);
    } catch (e) {
      throw ExcepcionServidor(e.toString());
    }
  }

  @override
  Future<void> crearUsuario(String uid, Map<String, dynamic> datos) async {
    try {
      await _coleccionUsuarios.doc(uid).set(datos);
    } on FirebaseException catch (e) {
      throw _mapearExcepcionFirestore(e);
    } catch (e) {
      throw ExcepcionServidor(e.toString());
    }
  }

  @override
  Future<void> actualizarUsuario(String uid, Map<String, dynamic> datos) async {
    try {
      await _coleccionUsuarios.doc(uid).update(datos);
    } on FirebaseException catch (e) {
      throw _mapearExcepcionFirestore(e);
    } catch (e) {
      throw ExcepcionServidor(e.toString());
    }
  }

  @override
  Future<void> eliminarUsuario(String uid) async {
    try {
      await _coleccionUsuarios.doc(uid).delete();
    } on FirebaseException catch (e) {
      throw _mapearExcepcionFirestore(e);
    } catch (e) {
      throw ExcepcionServidor(e.toString());
    }
  }

  @override
  Stream<Map<String, dynamic>?> streamUsuario(String uid) {
    return _coleccionUsuarios.doc(uid).snapshots().map((doc) {
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    });
  }

  ExcepcionBase _mapearExcepcionFirestore(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return const ExcepcionPermisos(
          'No tienes permisos para realizar esta operación.',
        );
      case 'unavailable':
        return const ExcepcionRedOConexion(
          'Servicio temporalmente no disponible.',
        );
      case 'deadline-exceeded':
        return const ExcepcionRedOConexion(
          'Tiempo de espera agotado.',
        );
      default:
        return ExcepcionServidor(
          e.message ?? 'Error del servidor',
          codigo: e.code,
        );
    }
  }
}

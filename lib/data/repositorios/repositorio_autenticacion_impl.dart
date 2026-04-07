import '../../domain/repositorios/repositorio_autenticacion.dart';
import '../../domain/modelos/usuario.dart';
import '../../core/errores/excepciones.dart';
import '../../core/constantes/constantes_app.dart';
import '../../core/enums/enums.dart';
import '../datasources/autenticacion_datasource.dart';

class RepositorioAutenticacionImpl implements RepositorioAutenticacion {
  final DataSourceAutenticacion _dataSourceAuth;
  final DataSourceUsuarios _dataSourceUsuarios;

  RepositorioAutenticacionImpl(
    this._dataSourceAuth,
    this._dataSourceUsuarios,
  );

  @override
  Stream<Usuario?> get estadoAutenticacion {
    return _dataSourceAuth.estadoAutenticacion.asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;

      try {
        final datosUsuario = await _dataSourceUsuarios.obtenerUsuario(
          firebaseUser.uid,
        );

        if (datosUsuario == null) return null;

        return Usuario.fromFirestore(datosUsuario, firebaseUser.uid);
      } catch (e) {
        return null;
      }
    });
  }

  @override
  Usuario? get usuarioActual {
    final firebaseUser = _dataSourceAuth.usuarioActual;
    if (firebaseUser == null) return null;

    // Para obtener datos completos, se debe usar el stream o métodos async
    return null;
  }

  @override
  bool get estaAutenticado => _dataSourceAuth.usuarioActual != null;

  @override
  Future<Resultado<Usuario>> iniciarSesionConCorreo({
    required String correo,
    required String password,
  }) async {
    try {
      // 1. Autenticar con Firebase Auth
      final credential = await _dataSourceAuth.iniciarSesionConCorreo(
        correo,
        password,
      );

      if (credential.user == null) {
        return Resultado.error(const ExcepcionAutenticacion(
          'No se pudo autenticar el usuario',
        ));
      }

      // 2. Obtener datos del usuario de Firestore
      final datosUsuario = await _dataSourceUsuarios.obtenerUsuario(
        credential.user!.uid,
      );

      if (datosUsuario == null) {
        return Resultado.error(const ExcepcionAutenticacion(
          'Datos de usuario no encontrados',
        ));
      }

      final usuario = Usuario.fromFirestore(datosUsuario, credential.user!.uid);

      return Resultado.exitoso(usuario);
    } on ExcepcionBase catch (e) {
      return Resultado.error(e);
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  @override
  Future<Resultado<Usuario>> registrarConCorreo({
    required String correo,
    required String password,
    required String nombre,
    required String telefono,
  }) async {
    try {
      // 1. Crear usuario en Firebase Auth
      final credential = await _dataSourceAuth.registrarConCorreo(
        correo,
        password,
      );

      if (credential.user == null) {
        return Resultado.error(const ExcepcionAutenticacion(
          'No se pudo crear el usuario',
        ));
      }

      // 2. Crear perfil de usuario en Firestore
      final usuario = Usuario(
        id: credential.user!.uid,
        nombre: nombre,
        correo: correo,
        telefono: telefono,
        rol: RolUsuario.propietario, // Por defecto al registrarse
        fechaCreacion: DateTime.now(),
      );

      await _dataSourceUsuarios.crearUsuario(
        credential.user!.uid,
        usuario.toFirestore(),
      );

      return Resultado.exitoso(usuario);
    } on ExcepcionBase catch (e) {
      return Resultado.error(e);
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  @override
  Future<Resultado<void>> cerrarSesion() async {
    try {
      await _dataSourceAuth.cerrarSesion();
      return Resultado.exitoso(null);
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  @override
  Future<Resultado<void>> enviarRecuperacionPassword(String correo) async {
    try {
      await _dataSourceAuth.enviarRecuperacionPassword(correo);
      return Resultado.exitoso(null);
    } on ExcepcionBase catch (e) {
      return Resultado.error(e);
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  @override
  Future<Resultado<void>> confirmarRecuperacionPassword({
    required String codigo,
    required String nuevoPassword,
  }) async {
    // TODO: Implementar verificación de código si es necesario
    return Resultado.error(const ExcepcionBase(
      'Funcionalidad no implementada aún',
    ));
  }

  @override
  Future<Resultado<void>> enviarVerificacionEmail() async {
    // TODO: Implementar si es necesario
    return Resultado.error(const ExcepcionBase(
      'Funcionalidad no implementada aún',
    ));
  }

  @override
  Future<Resultado<void>> verificarEmail(String codigo) async {
    // TODO: Implementar si es necesario
    return Resultado.error(const ExcepcionBase(
      'Funcionalidad no implementada aún',
    ));
  }

  @override
  Future<Resultado<void>> actualizarPassword({
    required String passwordActual,
    required String nuevoPassword,
  }) async {
    try {
      await _dataSourceAuth.actualizarPassword(passwordActual, nuevoPassword);
      return Resultado.exitoso(null);
    } on ExcepcionBase catch (e) {
      return Resultado.error(e);
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  @override
  Future<Resultado<Usuario>> actualizarPerfil(Usuario usuario) async {
    try {
      await _dataSourceUsuarios.actualizarUsuario(
        usuario.id,
        usuario.toFirestore(),
      );

      return Resultado.exitoso(usuario);
    } on ExcepcionBase catch (e) {
      return Resultado.error(e);
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  @override
  Future<Resultado<void>> eliminarCuenta(String password) async {
    try {
      final usuarioId = _dataSourceAuth.usuarioActual?.uid;

      if (usuarioId == null) {
        return Resultado.error(const ExcepcionAutenticacion(
          'Usuario no autenticado',
        ));
      }

      // 1. Eliminar datos de Firestore
      await _dataSourceUsuarios.eliminarUsuario(usuarioId);

      // 2. Eliminar cuenta de Firebase Auth
      await _dataSourceAuth.eliminarCuenta();

      return Resultado.exitoso(null);
    } on ExcepcionBase catch (e) {
      return Resultado.error(e);
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  @override
  Future<Resultado<void>> guardarTokenSesion(String token) async {
    try {
      // TODO: Implementar con SharedPreferences cuando esté disponible
      return Resultado.exitoso(null);
    } catch (e) {
      return Resultado.error(ExcepcionCache(e.toString()));
    }
  }

  @override
  Future<Resultado<String?>> obtenerTokenSesion() async {
    try {
      // TODO: Implementar con SharedPreferences cuando esté disponible
      return Resultado.exitoso(null);
    } catch (e) {
      return Resultado.error(ExcepcionCache(e.toString()));
    }
  }

  @override
  Future<Resultado<void>> limpiarTokenSesion() async {
    try {
      // TODO: Implementar con SharedPreferences cuando esté disponible
      return Resultado.exitoso(null);
    } catch (e) {
      return Resultado.error(ExcepcionCache(e.toString()));
    }
  }
}

import '../modelos/usuario.dart';
import '../../core/errores/excepciones.dart';

abstract class RepositorioAutenticacion {
  // Estado de autenticación
  Stream<Usuario?> get estadoAutenticacion;
  Usuario? get usuarioActual;
  bool get estaAutenticado;

  // Autenticación básica
  Future<Resultado<Usuario>> iniciarSesionConCorreo({
    required String correo,
    required String password,
  });

  Future<Resultado<Usuario>> registrarConCorreo({
    required String correo,
    required String password,
    required String nombre,
    required String telefono,
  });

  Future<Resultado<void>> cerrarSesion();

  // Recuperación de contraseña
  Future<Resultado<void>> enviarRecuperacionPassword(String correo);
  Future<Resultado<void>> confirmarRecuperacionPassword({
    required String codigo,
    required String nuevoPassword,
  });

  // Verificación de email
  Future<Resultado<void>> enviarVerificacionEmail();
  Future<Resultado<void>> verificarEmail(String codigo);

  // Gestión de perfil
  Future<Resultado<void>> actualizarPassword({
    required String passwordActual,
    required String nuevoPassword,
  });

  Future<Resultado<Usuario>> actualizarPerfil(Usuario usuario);

  // Eliminación de cuenta
  Future<Resultado<void>> eliminarCuenta(String password);

  // Persistencia de sesión
  Future<Resultado<void>> guardarTokenSesion(String token);
  Future<Resultado<String?>> obtenerTokenSesion();
  Future<Resultado<void>> limpiarTokenSesion();
}

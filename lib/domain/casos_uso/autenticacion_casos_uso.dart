import '../repositorios/repositorio_autenticacion.dart';
import '../repositorios/repositorio_empresa.dart';
import '../modelos/usuario.dart';
import '../modelos/empresa.dart';
import '../../core/errores/excepciones.dart';
import '../../core/enums/enums.dart';

class CasoUsoIniciarSesion {
  final RepositorioAutenticacion _repositorioAuth;
  final RepositorioEmpresa _repositorioEmpresa;

  CasoUsoIniciarSesion(this._repositorioAuth, this._repositorioEmpresa);

  Future<Resultado<Map<String, dynamic>>> ejecutar({
    required String correo,
    required String password,
  }) async {
    try {
      // 1. Autenticar usuario
      final resultadoAuth = await _repositorioAuth.iniciarSesionConCorreo(
        correo: correo,
        password: password,
      );

      if (resultadoAuth.esFallo) {
        return Resultado.error(resultadoAuth.excepcion!);
      }

      final usuario = resultadoAuth.datosOError;

      // 2. Validar que el usuario tenga empresa asignada
      if (usuario.empresaId == null) {
        return Resultado.error(const ExcepcionValidacion(
          'El usuario no está asociado a ninguna empresa',
        ));
      }

      // 3. Obtener datos de la empresa
      final resultadoEmpresa = await _repositorioEmpresa.obtenerEmpresa(
        usuario.empresaId!,
      );

      if (resultadoEmpresa.esFallo) {
        return Resultado.error(resultadoEmpresa.excepcion!);
      }

      final empresa = resultadoEmpresa.datosOError;

      // 4. Validar suscripción activa
      if (!empresa.suscripcion.estaActiva && !usuario.esPropietario) {
        return Resultado.error(const ExcepcionSuscripcion(
          'La suscripción de la empresa ha vencido',
          codigo: 'SUSCRIPCION_VENCIDA',
        ));
      }

      // 5. Guardar token de sesión
      await _repositorioAuth.guardarTokenSesion('session_${usuario.id}');

      return Resultado.exitoso({
        'usuario': usuario,
        'empresa': empresa,
        'requiere_onboarding': _requiereOnboarding(empresa),
        'aviso_suscripcion': empresa.suscripcion.requiereAviso,
      });
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }

  bool _requiereOnboarding(Empresa empresa) {
    // Verificar si la empresa tiene configuración básica completa
    final configuracion = empresa.configuracion;
    final tienePerfil = empresa.perfil.nombre.isNotEmpty;
    final tieneModulos = configuracion.modulosActivosList.isNotEmpty;

    return !tienePerfil || !tieneModulos;
  }
}

class CasoUsoRegistrarEmpresa {
  final RepositorioAutenticacion _repositorioAuth;
  final RepositorioEmpresa _repositorioEmpresa;

  CasoUsoRegistrarEmpresa(this._repositorioAuth, this._repositorioEmpresa);

  Future<Resultado<Map<String, dynamic>>> ejecutar({
    required String nombreEmpresa,
    required String correoEmpresa,
    required String telefonoEmpresa,
    required String direccionEmpresa,
    required String nombrePropietario,
    required String correoPropietario,
    required String telefonoPropietario,
    required String password,
  }) async {
    try {
      // 1. Validar que el nombre de empresa esté disponible
      final nombreDisponible = await _repositorioEmpresa.validarNombreDisponible(
        nombreEmpresa,
      );

      if (nombreDisponible.esFallo || !nombreDisponible.datosOError) {
        return Resultado.error(const ExcepcionValidacion(
          'El nombre de empresa ya está en uso',
        ));
      }

      // 2. Registrar usuario propietario
      final resultadoRegistro = await _repositorioAuth.registrarConCorreo(
        correo: correoPropietario,
        password: password,
        nombre: nombrePropietario,
        telefono: telefonoPropietario,
      );

      if (resultadoRegistro.esFallo) {
        return Resultado.error(resultadoRegistro.excepcion!);
      }

      final usuario = resultadoRegistro.datosOError;

      // 3. Crear empresa
      final ahora = DateTime.now();
      final empresa = Empresa(
        id: '', // Se asignará automáticamente
        perfil: PerfilEmpresa(
          nombre: nombreEmpresa,
          correo: correoEmpresa,
          telefono: telefonoEmpresa,
          direccion: direccionEmpresa,
          fechaCreacion: ahora,
        ),
        suscripcion: SuscripcionEmpresa(
          estado: EstadoSuscripcion.activa,
          fechaInicio: ahora,
          fechaFin: ahora.add(const Duration(days: 30)), // 30 días gratis
          monto: 0.0, // Período gratuito
        ),
        configuracion: const ConfiguracionEmpresa(
          modulosActivos: {
            // Módulos básicos activados por defecto
            ModuloEmpresa.reservas: true,
            ModuloEmpresa.clientes: true,
            ModuloEmpresa.servicios: true,
          },
        ),
        estadisticas: EstadisticasEmpresa(
          fechaActualizacion: ahora,
        ),
      );

      final resultadoEmpresa = await _repositorioEmpresa.crearEmpresa(empresa);

      if (resultadoEmpresa.esFallo) {
        // Rollback: eliminar usuario si falla la creación de empresa
        await _repositorioAuth.eliminarCuenta(password);
        return Resultado.error(resultadoEmpresa.excepcion!);
      }

      final empresaCreada = resultadoEmpresa.datosOError;

      // 4. Actualizar usuario con empresa y rol
      final usuarioActualizado = usuario.copyWith(
        empresaId: empresaCreada.id,
        rol: RolUsuario.propietario,
      );

      final resultadoActualizacion = await _repositorioAuth.actualizarPerfil(
        usuarioActualizado,
      );

      if (resultadoActualizacion.esFallo) {
        return Resultado.error(resultadoActualizacion.excepcion!);
      }

      return Resultado.exitoso({
        'usuario': usuarioActualizado,
        'empresa': empresaCreada,
        'requiere_onboarding': true,
      });
    } catch (e) {
      return Resultado.error(ManejadorExcepciones.mapearExcepcion(e));
    }
  }
}

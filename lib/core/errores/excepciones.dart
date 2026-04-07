import 'dart:io';

// Clase base para manejo de excepciones personalizadas
class ExcepcionBase implements Exception {
  final String mensaje;
  final String? codigo;
  final dynamic detalles;

  const ExcepcionBase(this.mensaje, {this.codigo, this.detalles});

  @override
  String toString() => 'ExcepcionBase: $mensaje';
}

class ExcepcionAutenticacion extends ExcepcionBase {
  const ExcepcionAutenticacion(String mensaje, {String? codigo, dynamic detalles})
      : super(mensaje, codigo: codigo, detalles: detalles);
}

class ExcepcionSuscripcion extends ExcepcionBase {
  const ExcepcionSuscripcion(String mensaje, {String? codigo, dynamic detalles})
      : super(mensaje, codigo: codigo, detalles: detalles);
}

class ExcepcionPermisos extends ExcepcionBase {
  const ExcepcionPermisos(String mensaje, {String? codigo, dynamic detalles})
      : super(mensaje, codigo: codigo, detalles: detalles);
}

class ExcepcionRedOConexion extends ExcepcionBase {
  const ExcepcionRedOConexion(String mensaje, {String? codigo, dynamic detalles})
      : super(mensaje, codigo: codigo, detalles: detalles);
}

class ExcepcionValidacion extends ExcepcionBase {
  const ExcepcionValidacion(String mensaje, {String? codigo, dynamic detalles})
      : super(mensaje, codigo: codigo, detalles: detalles);
}

class ExcepcionServidor extends ExcepcionBase {
  const ExcepcionServidor(String mensaje, {String? codigo, dynamic detalles})
      : super(mensaje, codigo: codigo, detalles: detalles);
}

class ExcepcionCache extends ExcepcionBase {
  const ExcepcionCache(String mensaje, {String? codigo, dynamic detalles})
      : super(mensaje, codigo: codigo, detalles: detalles);
}

// Clase para el resultado de operaciones
class Resultado<T> {
  final T? datos;
  final ExcepcionBase? excepcion;
  final bool esExitoso;

  const Resultado._({
    this.datos,
    this.excepcion,
    required this.esExitoso,
  });

  // Constructor para éxito
  factory Resultado.exitoso(T datos) {
    return Resultado._(datos: datos, esExitoso: true);
  }

  // Constructor para error
  factory Resultado.error(ExcepcionBase excepcion) {
    return Resultado._(excepcion: excepcion, esExitoso: false);
  }

  // Getters de conveniencia
  bool get esFallo => !esExitoso;
  T? get datosONull => datos;

  T get datosOError {
    if (esExitoso && datos != null) {
      return datos!;
    }
    throw excepcion ?? ExcepcionBase('Datos no disponibles');
  }

  // Método para mapear el resultado
  Resultado<R> map<R>(R Function(T) transformar) {
    if (esExitoso && datos != null) {
      try {
        return Resultado.exitoso(transformar(datos!));
      } catch (e) {
        return Resultado.error(ExcepcionBase(e.toString()));
      }
    }
    return Resultado.error(excepcion ?? ExcepcionBase('Error desconocido'));
  }

  // Método para manejar ambos casos
  R fold<R>(
    R Function(ExcepcionBase) enError,
    R Function(T) enExito,
  ) {
    if (esExitoso && datos != null) {
      return enExito(datos!);
    }
    return enError(excepcion ?? ExcepcionBase('Error desconocido'));
  }
}

// Clase para manejar estados de carga
enum EstadoCarga {
  inicial,
  cargando,
  exitoso,
  error,
}

class EstadoRecurso<T> {
  final EstadoCarga estado;
  final T? datos;
  final ExcepcionBase? excepcion;
  final String? mensaje;

  const EstadoRecurso._({
    required this.estado,
    this.datos,
    this.excepcion,
    this.mensaje,
  });

  factory EstadoRecurso.inicial() {
    return const EstadoRecurso._(estado: EstadoCarga.inicial);
  }

  factory EstadoRecurso.cargando({String? mensaje}) {
    return EstadoRecurso._(
      estado: EstadoCarga.cargando,
      mensaje: mensaje,
    );
  }

  factory EstadoRecurso.exitoso(T datos) {
    return EstadoRecurso._(
      estado: EstadoCarga.exitoso,
      datos: datos,
    );
  }

  factory EstadoRecurso.error(ExcepcionBase excepcion) {
    return EstadoRecurso._(
      estado: EstadoCarga.error,
      excepcion: excepcion,
    );
  }

  // Getters de conveniencia
  bool get esInicial => estado == EstadoCarga.inicial;
  bool get estaCargando => estado == EstadoCarga.cargando;
  bool get esExitoso => estado == EstadoCarga.exitoso;
  bool get esError => estado == EstadoCarga.error;

  // Método para mapear datos
  EstadoRecurso<R> map<R>(R Function(T) transformar) {
    if (esExitoso && datos != null) {
      try {
        return EstadoRecurso.exitoso(transformar(datos!));
      } catch (e) {
        return EstadoRecurso.error(ExcepcionBase(e.toString()));
      }
    }
    return EstadoRecurso._(
      estado: estado,
      excepcion: excepcion,
      mensaje: mensaje,
    );
  }
}

// Utilidades para manejo de excepciones
class ManejadorExcepciones {
  static ExcepcionBase mapearExcepcion(dynamic error) {
    if (error is ExcepcionBase) {
      return error;
    }

    if (error is SocketException) {
      return const ExcepcionRedOConexion(
        'Sin conexión a internet. Verifica tu conectividad.',
      );
    }

    if (error is FormatException) {
      return ExcepcionValidacion(
        'Formato de datos inválido: ${error.message}',
      );
    }

    // Error genérico
    return ExcepcionBase(
      error?.toString() ?? 'Ha ocurrido un error inesperado',
    );
  }

  static String obtenerMensajeAmigable(ExcepcionBase excepcion) {
    switch (excepcion.runtimeType) {
      case ExcepcionAutenticacion:
        return 'Error de autenticación: ${excepcion.mensaje}';
      case ExcepcionSuscripcion:
        return 'Problema con la suscripción: ${excepcion.mensaje}';
      case ExcepcionPermisos:
        return 'Permisos insuficientes: ${excepcion.mensaje}';
      case ExcepcionRedOConexion:
        return 'Problema de conexión: ${excepcion.mensaje}';
      case ExcepcionValidacion:
        return 'Error de validación: ${excepcion.mensaje}';
      default:
        return excepcion.mensaje;
    }
  }
}

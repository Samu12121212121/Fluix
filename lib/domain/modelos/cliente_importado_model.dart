enum EstadoValidacion { valido, warning, error }

class ResultadoValidacion {
  final EstadoValidacion estado;
  final String mensaje;

  const ResultadoValidacion({required this.estado, this.mensaje = ''});

  bool get esValido => estado == EstadoValidacion.valido;
  bool get esWarning => estado == EstadoValidacion.warning;
  bool get esError => estado == EstadoValidacion.error;
}

class ClienteImportado {
  final String nombre;
  final String nif;
  final String? email;
  final String? telefono;
  final String? direccion;
  final String? poblacion;
  final String? cp;
  
  // Estado de validación
  final List<ResultadoValidacion> validaciones;
  
  // Estado respecto a la base de datos
  bool existeEnDb;
  
  ClienteImportado({
    required this.nombre,
    required this.nif,
    this.email,
    this.telefono,
    this.direccion,
    this.poblacion,
    this.cp,
    this.validaciones = const [],
    this.existeEnDb = false,
  });

  bool get esValidoParaImportar => 
      !validaciones.any((v) => v.estado == EstadoValidacion.error);

  bool get tieneWarnings => 
      validaciones.any((v) => v.estado == EstadoValidacion.warning);

  String get motivosError => validaciones
      .where((v) => v.esError)
      .map((v) => v.mensaje)
      .join(', ');

  String get motivosWarning => validaciones
      .where((v) => v.esWarning)
      .map((v) => v.mensaje)
      .join(', ');

  Map<String, dynamic> toMapFirestore(String empresaId) {
    final map = <String, dynamic>{
      'nombre': nombre,
      'nif': nif, // Se usará como ID o campo clave
      if (email != null) 'correo': email,
      if (telefono != null) 'telefono': telefono,
      if (direccion != null) 'direccion': direccion,
      if (poblacion != null) 'localidad': poblacion, // Mapeo a 'localidad' del modelo Cliente
      if (cp != null) 'codigo_postal': cp,
      'origen_importacion': 'csv',
      'fecha_importacion': DateTime.now().toIso8601String(),
    };

    // Solo para nuevos (luego haremos merge: true para update, donde estos campos no molestan si ya existen, 
    // pero si es update selectivo mejor separarlos en servicio)
    if (!existeEnDb) {
      map['empresa_id'] = empresaId;
      map['fecha_registro'] = DateTime.now().toIso8601String();
      map['activo'] = true;
      map['total_gastado'] = 0.0;
      map['numero_reservas'] = 0;
      map['etiquetas'] = <String>[];
    }
    
    return map;
  }
}

class ResultadoPreview {
  final List<ClienteImportado> validos;
  final List<ClienteImportado> conErrores;
  final List<String> columnasDetectadas;
  final List<String> columnasIgnoradas;

  ResultadoPreview({
    this.validos = const [],
    this.conErrores = const [],
    this.columnasDetectadas = const [],
    this.columnasIgnoradas = const [],
  });

  int get totalNuevos => validos.where((c) => !c.existeEnDb).length;
  int get totalActualizaciones => validos.where((c) => c.existeEnDb).length;
  int get totalWarnings => validos.where((c) => c.tieneWarnings).length;
}


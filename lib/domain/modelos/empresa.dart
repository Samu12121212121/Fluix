  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is DateTime) return v;
  return DateTime.now();
}
/// Helper para parsear fechas desde Firestore
DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is Timestamp) return v.toDate();

  @override
  int get hashCode => id.hashCode;
}
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Empresa && other.id == id;
  }
  // Campos nuevos del mapa Firestore
  final String? ciudad;
  final String? codigoPostal;
  final String? provincia;
  final String? pais;
  final String? web;

  PerfilEmpresa({
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.direccion,
    required this.descripcion,
    this.logoUrl,
      estadisticas: estadisticas ?? this.estadisticas,
    this.ciudad,
    this.codigoPostal,
    this.provincia,
    this.pais,
    this.web,
    );
  }
class Empresa {
  final String id;
  final PerfilEmpresa perfil;
  final SuscripcionEmpresa suscripcion;
  final ConfiguracionEmpresa configuracion;
    required this.suscripcion,
      descripcion: datos['descripcion'] ?? '',
      logoUrl: datos['logo_url'],
      fechaCreacion: _parseDate(datos['fecha_creacion']),
      ciudad: datos['ciudad'],
      codigoPostal: datos['codigo_postal'],
      provincia: datos['provincia'],
      pais: datos['pais'] ?? 'ES',
      web: datos['web'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
    required this.configuracion,
    required this.estadisticas,
  });

  factory Empresa.fromFirestore(String id, Map<String, dynamic> datos) {
    return Empresa(
      'ciudad': ciudad,
      'codigo_postal': codigoPostal,
      'provincia': provincia,
      'pais': pais ?? 'ES',
      'web': web,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'perfil': perfil.toFirestore(),
      'suscripcion': suscripcion.toFirestore(),
    String? direccion,
    String? descripcion,
    String? logoUrl,
    String? ciudad,
    String? codigoPostal,
    String? provincia,
    String? pais,
    String? web,
  }) {
    return PerfilEmpresa(
  }
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      descripcion: descripcion ?? this.descripcion,
  }
      ciudad: ciudad ?? this.ciudad,
      ciudad: ciudad ?? this.ciudad,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      provincia: provincia ?? this.provincia,
      pais: pais ?? this.pais,
      web: web ?? this.web,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      provincia: provincia ?? this.provincia,
      pais: pais ?? this.pais,
      web: web ?? this.web,
    this.ciudad,
    this.codigoPostal,
    this.provincia,
  final DateTime fechaFin;
  final bool avisoEnviado;
  final double monto;
  final String? transaccionId;

  const SuscripcionEmpresa({

// Criterio de liquidación de IVA para la empresa
// devengo: por fecha de emisión/recepción (régimen general)
  final String correo;
  final String telefono;
    this.transaccionId,
  });

  factory SuscripcionEmpresa.fromFirestore(Map<String, dynamic> datos) {
    return SuscripcionEmpresa(
      estado: EstadoSuscripcion.values.firstWhere(
        (e) => e.name == (datos['estado'] ?? 'pendiente'),
        orElse: () => EstadoSuscripcion.pendiente,
      ),
  final String direccion;
  final String descripcion;
  final String? logoUrl;
  final DateTime fechaCreacion;
      transaccionId: datos['transaccion_id'],
    );
  }

  Map<String, dynamic> toFirestore() {

      direccion: datos['direccion'] ?? '',
      'correo': correo,
      'fecha_fin': fechaFin.toIso8601String(),
      'aviso_enviado': avisoEnviado,
      'monto': monto,
      'transaccion_id': transaccionId,
    };
  }

  int get diasRestantes => fechaFin.difference(DateTime.now()).inDays;
  bool get estaActiva => estado == EstadoSuscripcion.activa;
      'telefono': telefono,
      'descripcion': descripcion,
      'logo_url': logoUrl,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      ciudad: datos['ciudad'],
      codigoPostal: datos['codigo_postal'],
      provincia: datos['provincia'],
    String? nombre,
    String? correo,
    String? telefono,
      'provincia': provincia,
      'pais': pais ?? 'ES',
      'web': web,
      nombre: nombre ?? this.nombre,
      logoUrl: logoUrl ?? this.logoUrl,
      fechaCreacion: fechaCreacion,
    );
  }
}

      pais: pais ?? this.pais,
      web: web ?? this.web,
    this.avisoEnviado = false,
    this.monto = 0.0,
      fechaInicio: _parseDate(datos['fecha_inicio']),
      fechaFin: _parseDate(datos['fecha_fin']),
      avisoEnviado: datos['aviso_enviado'] ?? false,
      monto: (datos['monto'] ?? 0.0).toDouble(),
    return {
      'estado': estado.toString().split('.').last,
      'fecha_inicio': fechaInicio.toIso8601String(),
  bool get estaVencida => estado == EstadoSuscripcion.vencida;
  }

  bool get requiereAviso {
    return diasRestantes <= 7 && diasRestantes > 0 && !avisoEnviado;
  }

      ciudad: datos['ciudad'],
      codigoPostal: datos['codigo_postal'],
      provincia: datos['provincia'],
      pais: datos['pais'] ?? 'ES',
      web: datos['web'],
    double? monto,
    String? transaccionId,
  }) {
      'provincia': provincia,
      'pais': pais ?? 'ES',
      'web': web,
      monto: monto ?? this.monto,
      transaccionId: transaccionId ?? this.transaccionId,
    );
  }
}

class ConfiguracionEmpresa {
  final Map<ModuloEmpresa, bool> modulosActivos;
    this.configuracionModulos = const {},
    this.criterioIva = CriterioIVA.devengo,
  });

  factory ConfiguracionEmpresa.fromFirestore(Map<String, dynamic> datos) {
    final modulosMap = <ModuloEmpresa, bool>{};
    }

    return ConfiguracionEmpresa(
      modulosActivos: modulosMap,
      configuracionModulos: datos['configuracion_modulos'] ?? {},
      criterioIva: CriterioIVA.values.firstWhere(
        (e) => e.name == (datos['criterio_iva'] ?? 'devengo'),
        orElse: () => CriterioIVA.devengo,
      ),
    );
  }

    String? ciudad,
    String? codigoPostal,
    String? provincia,
    String? pais,
    return modulosActivos.entries
        .where((entrada) => entrada.value)
        .map((entrada) => entrada.key)
        .toList();
  }

  ConfiguracionEmpresa copyWith({
    Map<ModuloEmpresa, bool>? modulosActivos,
    Map<String, dynamic>? configuracionModulos,
    CriterioIVA? criterioIva,
  }) {
    return ConfiguracionEmpresa(
      modulosActivos: modulosActivos ?? this.modulosActivos,
      configuracionModulos: configuracionModulos ?? this.configuracionModulos,
      criterioIva: criterioIva ?? this.criterioIva,
    final nuevosModulos = Map<ModuloEmpresa, bool>.from(modulosActivos);
    nuevosModulos[modulo] = !(nuevosModulos[modulo] ?? false);

    return copyWith(modulosActivos: nuevosModulos);
  }
}


  const EstadisticasEmpresa({
    this.totalClientes = 0,
    this.totalReservas = 0,
    this.totalServicios = 0,
    this.ingresosMes = 0.0,
    this.ingresosAnio = 0.0,
    this.valoracionPromedio = 0.0,
    this.totalValoraciones = 0,
    required this.fechaActualizacion,
  });

  factory EstadisticasEmpresa.fromFirestore(Map<String, dynamic> datos) {
    return EstadisticasEmpresa(
      totalClientes: datos['total_clientes'] ?? 0,
      totalReservas: datos['total_reservas'] ?? 0,
      totalServicios: datos['total_servicios'] ?? 0,
      ingresosMes: (datos['ingresos_mes'] ?? 0.0).toDouble(),
      ingresosAnio: (datos['ingresos_anio'] ?? 0.0).toDouble(),
      valoracionPromedio: (datos['valoracion_promedio'] ?? 0.0).toDouble(),
      totalValoraciones: datos['total_valoraciones'] ?? 0,
      fechaActualizacion: _parseDate(datos['fecha_actualizacion']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'total_clientes': totalClientes,
      'total_reservas': totalReservas,
      'total_servicios': totalServicios,
      'ingresos_mes': ingresosMes,
      'ingresos_anio': ingresosAnio,
      'valoracion_promedio': valoracionPromedio,
      'total_valoraciones': totalValoraciones,
      'fecha_actualizacion': fechaActualizacion.toIso8601String(),
    };
  }

  EstadisticasEmpresa copyWith({
    int? totalClientes,
    int? totalReservas,
    int? totalServicios,
    double? ingresosMes,
    double? ingresosAnio,
    double? valoracionPromedio,
    int? totalValoraciones,
    DateTime? fechaActualizacion,
  }) {
    return EstadisticasEmpresa(
      totalClientes: totalClientes ?? this.totalClientes,
      totalReservas: totalReservas ?? this.totalReservas,
      totalServicios: totalServicios ?? this.totalServicios,
      ingresosMes: ingresosMes ?? this.ingresosMes,
      ingresosAnio: ingresosAnio ?? this.ingresosAnio,
      valoracionPromedio: valoracionPromedio ?? this.valoracionPromedio,
      totalValoraciones: totalValoraciones ?? this.totalValoraciones,
      fechaActualizacion: fechaActualizacion ?? this.fechaActualizacion,
    );
  }
}

class Empresa {
  final String id;
  final PerfilEmpresa perfil;
  final SuscripcionEmpresa suscripcion;
  final ConfiguracionEmpresa configuracion;
  final EstadisticasEmpresa estadisticas;

  const Empresa({
  final List<String> codigosCnae;

  const RegimenFiscal({
    this.tipo = 'general',
    this.periodicidadIva = 'trimestral',
    this.obligadoSii = false,
    this.obligadoVerifactu = false,
    this.esNuevaCreacion = false,
    this.codigosCnae = const [],
  });

  factory RegimenFiscal.fromFirestore(Map<String, dynamic> datos) {
    return RegimenFiscal(
      tipo: datos['tipo'] as String? ?? 'general',
      periodicidadIva: datos['periodicidad_iva'] as String? ?? 'trimestral',
      obligadoSii: datos['obligado_sii'] as bool? ?? false,
    this.cnae,
    this.actividad,
    this.activePacks = const [],
    this.regimenFiscal = const RegimenFiscal(),
    this.estado = 'activa',
    this.createdBy,
      estadisticas: estadisticas ?? this.estadisticas,
    );
      obligadoVerifactu: datos['obligado_verifactu'] as bool? ?? false,
      esNuevaCreacion: datos['es_nueva_creacion'] as bool? ?? false,
      codigosCnae: List<String>.from(datos['codigos_cnae'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'tipo': tipo,
    'periodicidad_iva': periodicidadIva,
    'obligado_sii': obligadoSii,
    'obligado_verifactu': obligadoVerifactu,
    'es_nueva_creacion': esNuevaCreacion,
    'codigos_cnae': codigosCnae,
  };

  RegimenFiscal copyWith({
    String? tipo,
    String? periodicidadIva,
    bool? obligadoSii,
    bool? obligadoVerifactu,
    bool? esNuevaCreacion,
    List<String>? codigosCnae,
  }) {
    return RegimenFiscal(
      tipo: tipo ?? this.tipo,
      periodicidadIva: periodicidadIva ?? this.periodicidadIva,
      obligadoSii: obligadoSii ?? this.obligadoSii,
      obligadoVerifactu: obligadoVerifactu ?? this.obligadoVerifactu,
      esNuevaCreacion: esNuevaCreacion ?? this.esNuevaCreacion,
      codigosCnae: codigosCnae ?? this.codigosCnae,
    );
  }
}

// ── EMPRESA ───────────────────────────────────────────────────────────────────

class Empresa {
  final String id;
  final PerfilEmpresa perfil;
  final SuscripcionEmpresa suscripcion;
  final ConfiguracionEmpresa configuracion;
  final EstadisticasEmpresa estadisticas;

  // ⭐ Campos nuevos del mapa Firestore
  final String? legalName;        // razón social
  final String? taxId;            // CIF / NIF
  final String? sector;           // 'hosteleria', 'peluqueria', etc.
  final String? cnae;             // código CNAE oficial
  final String? actividad;        // descripción libre
  final List<String> activePacks; // ['base', 'fiscal_ai', ...]
  final RegimenFiscal regimenFiscal;
  final String estado;            // 'activa', 'suspendida', 'baja'
  final String? createdBy;

  const Empresa({
    required this.id,
    required this.perfil,
    required this.suscripcion,
    required this.configuracion,
    required this.estadisticas,
    this.legalName,
    this.taxId,
    this.sector,
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Empresa && other.id == id;
  });
      sector: datos['sector'] as String?,
  factory Empresa.fromFirestore(String id, Map<String, dynamic> datos) {
    return Empresa(
      id: id,
      perfil: PerfilEmpresa.fromFirestore(datos['perfil'] ?? {}),
      suscripcion: SuscripcionEmpresa.fromFirestore(datos['suscripcion'] ?? {}),
      configuracion: ConfiguracionEmpresa.fromFirestore(datos['configuracion'] ?? {}),
      estadisticas: EstadisticasEmpresa.fromFirestore(datos['estadisticas'] ?? {}),
      ),
      estado: datos['estado'] as String? ?? 'activa',
      createdBy: datos['created_by'] as String?,

  @override
  int get hashCode => id.hashCode;
}

/// Helper para parsear fechas desde Firestore
DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
    );
  }
      'cnae': cnae,
  Map<String, dynamic> toFirestore() {
    return {
      'perfil': perfil.toFirestore(),
      'suscripcion': suscripcion.toFirestore(),
      'configuracion': configuracion.toFirestore(),
      'estadisticas': estadisticas.toFirestore(),
      'created_by': createdBy,
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is DateTime) return v;
  return DateTime.now();
}

  /// ¿Tiene un pack concreto activo?
  bool tienePack(String packId) => activePacks.contains(packId);

    };
  }

  bool get puedeUsarModulo => suscripcion.estaActiva;

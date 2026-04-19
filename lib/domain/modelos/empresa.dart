import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/enums/enums.dart';

// caja: por fecha de cobro/pago (solo RECC)
enum CriterioIVA { devengo, caja }

// ── RÉGIMEN FISCAL ────────────────────────────────────────────────────────────

class RegimenFiscal {
  final String tipo;              // 'general', 'recargo_equivalencia', 'modulo', 'simplificado'
  final String periodicidadIva;   // 'trimestral', 'mensual'
  final bool obligadoSii;
  final bool obligadoVerifactu;
  final bool esNuevaCreacion;     // tipo reducido 15% IS
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
}

class PerfilEmpresa {
  final String nombre;
  final String correo;
  final String telefono;
  final String direccion;
  final String descripcion;
  final String? logoUrl;
  final DateTime fechaCreacion;
  final String? ciudad;
  final String? codigoPostal;
  final String? provincia;
  final String pais;
  final String? web;

  const PerfilEmpresa({
    required this.nombre,
    required this.correo,
    required this.telefono,
    this.direccion = '',
    this.descripcion = '',
    this.logoUrl,
    required this.fechaCreacion,
    this.ciudad,
    this.codigoPostal,
    this.provincia,
    this.pais = 'ES',
    this.web,
  });

  factory PerfilEmpresa.fromFirestore(Map<String, dynamic> datos) {
    return PerfilEmpresa(
      nombre: datos['nombre'] ?? '',
      correo: datos['correo'] ?? '',
      telefono: datos['telefono'] ?? '',
      direccion: datos['direccion'] ?? '',
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
      'correo': correo,
      'telefono': telefono,
      'direccion': direccion,
      'descripcion': descripcion,
      'logo_url': logoUrl,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'ciudad': ciudad,
      'codigo_postal': codigoPostal,
      'provincia': provincia,
      'pais': pais,
      'web': web,
    };
  }

  PerfilEmpresa copyWith({
    String? nombre,
    String? correo,
    String? telefono,
    String? direccion,
    String? descripcion,
    String? logoUrl,
    DateTime? fechaCreacion,
    String? ciudad,
    String? codigoPostal,
    String? provincia,
    String? pais,
    String? web,
  }) {
    return PerfilEmpresa(
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      descripcion: descripcion ?? this.descripcion,
      logoUrl: logoUrl ?? this.logoUrl,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      ciudad: ciudad ?? this.ciudad,
      codigoPostal: codigoPostal ?? this.codigoPostal,
      provincia: provincia ?? this.provincia,
      pais: pais ?? this.pais,
      web: web ?? this.web,
    );
  }
}

class SuscripcionEmpresa {
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final bool avisoEnviado;
  final double monto;
  final String? transaccionId;
  final EstadoSuscripcion estado;

  const SuscripcionEmpresa({
    required this.fechaInicio,
    required this.fechaFin,
    this.avisoEnviado = false,
    this.monto = 0.0,
    this.transaccionId,
    this.estado = EstadoSuscripcion.activa,
  });

  factory SuscripcionEmpresa.fromFirestore(Map<String, dynamic> datos) {
    return SuscripcionEmpresa(
      fechaInicio: _parseDate(datos['fecha_inicio']),
      fechaFin: _parseDate(datos['fecha_fin']),
      avisoEnviado: datos['aviso_enviado'] ?? false,
      monto: (datos['monto'] ?? 0.0).toDouble(),
      transaccionId: datos['transaccion_id'],
      estado: EstadoSuscripcion.values.firstWhere(
        (e) => e.name == (datos['estado'] ?? 'activa'),
        orElse: () => EstadoSuscripcion.activa,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin.toIso8601String(),
      'aviso_enviado': avisoEnviado,
      'monto': monto,
      'transaccion_id': transaccionId,
      'estado': estado.name,
    };
  }

  int get diasRestantes => fechaFin.difference(DateTime.now()).inDays;
  bool get estaActiva => estado == EstadoSuscripcion.activa;
  bool get estaVencida => estado == EstadoSuscripcion.vencida;

  bool get requiereAviso {
    return diasRestantes <= 7 && diasRestantes > 0 && !avisoEnviado;
  }

  SuscripcionEmpresa copyWith({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool? avisoEnviado,
    double? monto,
    String? transaccionId,
    EstadoSuscripcion? estado,
  }) {
    return SuscripcionEmpresa(
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      avisoEnviado: avisoEnviado ?? this.avisoEnviado,
      monto: monto ?? this.monto,
      transaccionId: transaccionId ?? this.transaccionId,
      estado: estado ?? this.estado,
    );
  }
}

class ConfiguracionEmpresa {
  final Map<ModuloEmpresa, bool> modulosActivos;
  final Map<String, dynamic> configuracionModulos;
  final CriterioIVA criterioIva;

  const ConfiguracionEmpresa({
    this.modulosActivos = const {},
    this.configuracionModulos = const {},
    this.criterioIva = CriterioIVA.devengo,
  });

  factory ConfiguracionEmpresa.fromFirestore(Map<String, dynamic> datos) {
    final modulosMap = <ModuloEmpresa, bool>{};
    final modulosData = datos['modulos_activos'] as Map<String, dynamic>? ?? {};
    for (final entry in modulosData.entries) {
      final modulo = ModuloEmpresa.values.firstWhere(
        (m) => m.name == entry.key,
        orElse: () => ModuloEmpresa.values.first,
      );
      modulosMap[modulo] = entry.value as bool? ?? false;
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

  Map<String, dynamic> toFirestore() {
    return {
      'modulos_activos': modulosActivos.map((k, v) => MapEntry(k.name, v)),
      'configuracion_modulos': configuracionModulos,
      'criterio_iva': criterioIva.name,
    };
  }

  List<ModuloEmpresa> get modulosActivosList {
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
    );
  }

  ConfiguracionEmpresa toggleModulo(ModuloEmpresa modulo) {
    final nuevosModulos = Map<ModuloEmpresa, bool>.from(modulosActivos);
    nuevosModulos[modulo] = !(nuevosModulos[modulo] ?? false);
    return copyWith(modulosActivos: nuevosModulos);
  }
}

class EstadisticasEmpresa {
  final int totalClientes;
  final int totalReservas;
  final int totalServicios;
  final double ingresosMes;
  final double ingresosAnio;
  final double valoracionPromedio;
  final int totalValoraciones;
  final DateTime fechaActualizacion;

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
  final String? legalName;
  final String? taxId;
  final String? sector;
  final String? cnae;
  final String? actividad;
  final List<String> activePacks;
  final RegimenFiscal regimenFiscal;
  final String estado;
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
    this.cnae,
    this.actividad,
    this.activePacks = const [],
    this.regimenFiscal = const RegimenFiscal(),
    this.estado = 'activa',
    this.createdBy,
  });

  factory Empresa.fromFirestore(String id, Map<String, dynamic> datos) {
    return Empresa(
      id: id,
      perfil: PerfilEmpresa.fromFirestore(datos['perfil'] ?? {}),
      suscripcion: SuscripcionEmpresa.fromFirestore(datos['suscripcion'] ?? {}),
      configuracion: ConfiguracionEmpresa.fromFirestore(datos['configuracion'] ?? {}),
      estadisticas: EstadisticasEmpresa.fromFirestore(datos['estadisticas'] ?? {}),
      legalName: datos['legal_name'] as String?,
      taxId: datos['tax_id'] as String?,
      sector: datos['sector'] as String?,
      cnae: datos['cnae'] as String?,
      actividad: datos['actividad'] as String?,
      activePacks: List<String>.from(datos['active_packs'] ?? []),
      regimenFiscal: RegimenFiscal.fromFirestore(
        datos['regimen_fiscal'] as Map<String, dynamic>? ?? {},
      ),
      estado: datos['estado'] as String? ?? 'activa',
      createdBy: datos['created_by'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'perfil': perfil.toFirestore(),
      'suscripcion': suscripcion.toFirestore(),
      'configuracion': configuracion.toFirestore(),
      'estadisticas': estadisticas.toFirestore(),
      'legal_name': legalName,
      'tax_id': taxId,
      'sector': sector,
      'cnae': cnae,
      'actividad': actividad,
      'active_packs': activePacks,
      'regimen_fiscal': regimenFiscal.toFirestore(),
      'estado': estado,
      'created_by': createdBy,
    };
  }

  Empresa copyWith({
    String? id,
    PerfilEmpresa? perfil,
    SuscripcionEmpresa? suscripcion,
    ConfiguracionEmpresa? configuracion,
    EstadisticasEmpresa? estadisticas,
    String? legalName,
    String? taxId,
    String? sector,
    String? cnae,
    String? actividad,
    List<String>? activePacks,
    RegimenFiscal? regimenFiscal,
    String? estado,
    String? createdBy,
  }) {
    return Empresa(
      id: id ?? this.id,
      perfil: perfil ?? this.perfil,
      suscripcion: suscripcion ?? this.suscripcion,
      configuracion: configuracion ?? this.configuracion,
      estadisticas: estadisticas ?? this.estadisticas,
      legalName: legalName ?? this.legalName,
      taxId: taxId ?? this.taxId,
      sector: sector ?? this.sector,
      cnae: cnae ?? this.cnae,
      actividad: actividad ?? this.actividad,
      activePacks: activePacks ?? this.activePacks,
      regimenFiscal: regimenFiscal ?? this.regimenFiscal,
      estado: estado ?? this.estado,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  /// ¿Tiene un pack concreto activo?
  bool tienePack(String packId) => activePacks.contains(packId);

  /// ¿Tiene el Pack Fiscal IA?
  bool get tienePackFiscal => tienePack('fiscal_ai');

  bool get puedeUsarModulo => suscripcion.estaActiva;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Empresa && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Helper para parsear fechas desde Firestore
DateTime _parseDate(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is DateTime) return v;
  return DateTime.now();
}

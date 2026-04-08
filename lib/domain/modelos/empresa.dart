import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/enums/enums.dart';

// Criterio de liquidación de IVA para la empresa
// devengo: por fecha de emisión/recepción (régimen general)
// caja: por fecha de cobro/pago (solo RECC)
enum CriterioIVA { devengo, caja }

class PerfilEmpresa {
  final String nombre;
  final String correo;
  final String telefono;
  final String direccion;
  final String descripcion;
  final String? logoUrl;
  final DateTime fechaCreacion;

  const PerfilEmpresa({
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.direccion,
    this.descripcion = '',
    this.logoUrl,
    required this.fechaCreacion,
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
    };
  }

  PerfilEmpresa copyWith({
    String? nombre,
    String? correo,
    String? telefono,
    String? direccion,
    String? descripcion,
    String? logoUrl,
  }) {
    return PerfilEmpresa(
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      descripcion: descripcion ?? this.descripcion,
      logoUrl: logoUrl ?? this.logoUrl,
      fechaCreacion: fechaCreacion,
    );
  }
}

class SuscripcionEmpresa {
  final EstadoSuscripcion estado;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final bool avisoEnviado;
  final double monto;
  final String? transaccionId;

  const SuscripcionEmpresa({
    required this.estado,
    required this.fechaInicio,
    required this.fechaFin,
    this.avisoEnviado = false,
    this.monto = 0.0,
    this.transaccionId,
  });

  factory SuscripcionEmpresa.fromFirestore(Map<String, dynamic> datos) {
    return SuscripcionEmpresa(
      estado: EstadoSuscripcion.values.firstWhere(
        (e) => e.name == (datos['estado'] ?? 'pendiente'),
        orElse: () => EstadoSuscripcion.pendiente,
      ),
      fechaInicio: _parseDate(datos['fecha_inicio']),
      fechaFin: _parseDate(datos['fecha_fin']),
      avisoEnviado: datos['aviso_enviado'] ?? false,
      monto: (datos['monto'] ?? 0.0).toDouble(),
      transaccionId: datos['transaccion_id'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'estado': estado.toString().split('.').last,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_fin': fechaFin.toIso8601String(),
      'aviso_enviado': avisoEnviado,
      'monto': monto,
      'transaccion_id': transaccionId,
    };
  }

  bool get estaActiva => estado == EstadoSuscripcion.activa;
  bool get estaVencida => estado == EstadoSuscripcion.vencida;
  bool get estaPendiente => estado == EstadoSuscripcion.pendiente;

  int get diasRestantes {
    final ahora = DateTime.now();
    if (fechaFin.isBefore(ahora)) return 0;
    return fechaFin.difference(ahora).inDays;
  }

  bool get requiereAviso {
    return diasRestantes <= 7 && diasRestantes > 0 && !avisoEnviado;
  }

  SuscripcionEmpresa copyWith({
    EstadoSuscripcion? estado,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    bool? avisoEnviado,
    double? monto,
    String? transaccionId,
  }) {
    return SuscripcionEmpresa(
      estado: estado ?? this.estado,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      avisoEnviado: avisoEnviado ?? this.avisoEnviado,
      monto: monto ?? this.monto,
      transaccionId: transaccionId ?? this.transaccionId,
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
    final modulosData = datos['modulos'] as Map<String, dynamic>? ?? {};

    for (final modulo in ModuloEmpresa.values) {
      final key = modulo.toString().split('.').last;
      modulosMap[modulo] = modulosData[key] ?? false;
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
    final modulosData = <String, bool>{};
    for (final entrada in modulosActivos.entries) {
      final key = entrada.key.toString().split('.').last;
      modulosData[key] = entrada.value;
    }

    return {
      'modulos': modulosData,
      'configuracion_modulos': configuracionModulos,
      'criterio_iva': criterioIva.name,
    };
  }

  bool estaModuloActivo(ModuloEmpresa modulo) {
    return modulosActivos[modulo] ?? false;
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

  const Empresa({
    required this.id,
    required this.perfil,
    required this.suscripcion,
    required this.configuracion,
    required this.estadisticas,
  });

  factory Empresa.fromFirestore(String id, Map<String, dynamic> datos) {
    return Empresa(
      id: id,
      perfil: PerfilEmpresa.fromFirestore(datos['perfil'] ?? {}),
      suscripcion: SuscripcionEmpresa.fromFirestore(datos['suscripcion'] ?? {}),
      configuracion: ConfiguracionEmpresa.fromFirestore(datos['configuracion'] ?? {}),
      estadisticas: EstadisticasEmpresa.fromFirestore(datos['estadisticas'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'perfil': perfil.toFirestore(),
      'suscripcion': suscripcion.toFirestore(),
      'configuracion': configuracion.toFirestore(),
      'estadisticas': estadisticas.toFirestore(),
    };
  }

  bool get puedeUsarModulo => suscripcion.estaActiva;

  Empresa copyWith({
    PerfilEmpresa? perfil,
    SuscripcionEmpresa? suscripcion,
    EstadisticasEmpresa? estadisticas,
  }) {
    return Empresa(
      id: id,
      perfil: perfil ?? this.perfil,
      suscripcion: suscripcion ?? this.suscripcion,
      configuracion: configuracion ?? this.configuracion,
      estadisticas: estadisticas ?? this.estadisticas,
    );
  }

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

import 'package:cloud_firestore/cloud_firestore.dart';

/// Recompensa dentro del programa de fidelización
class RecompensaPrograma {
  final String id;
  final String titulo;
  final String descripcion;
  final String tipo; // 'descuento_porcentaje' | 'visita_gratis' | 'producto' | 'otro'
  final dynamic valor; // 20 (%), 100 (%), texto libre
  final int sellosNecesarios;

  const RecompensaPrograma({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    required this.valor,
    required this.sellosNecesarios,
  });

  factory RecompensaPrograma.fromMap(Map<String, dynamic> map) {
    return RecompensaPrograma(
      id: map['id'] as String? ?? '',
      titulo: map['titulo'] as String? ?? '',
      descripcion: map['descripcion'] as String? ?? '',
      tipo: map['tipo'] as String? ?? 'otro',
      valor: map['valor'],
      sellosNecesarios: map['sellos_necesarios'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'titulo': titulo,
    'descripcion': descripcion,
    'tipo': tipo,
    'valor': valor,
    'sellos_necesarios': sellosNecesarios,
  };

  RecompensaPrograma copyWith({
    String? id,
    String? titulo,
    String? descripcion,
    String? tipo,
    dynamic valor,
    int? sellosNecesarios,
  }) {
    return RecompensaPrograma(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      tipo: tipo ?? this.tipo,
      valor: valor ?? this.valor,
      sellosNecesarios: sellosNecesarios ?? this.sellosNecesarios,
    );
  }

  String get textoValor {
    if (tipo == 'descuento_porcentaje') return '$valor%';
    if (tipo == 'visita_gratis') return 'Gratis';
    if (tipo == 'producto') return valor.toString();
    return valor.toString();
  }
}

/// Programa de fidelización del negocio
class ProgramaFidelizacionModel {
  final String id;
  final String negocioId;
  final bool activo;
  final String nombre;
  final String descripcion;
  final int sellosParaRecompensa;
  final List<RecompensaPrograma> recompensas;
  final int? caducidadMeses; // null = no caduca
  final DateTime creadoAt;
  final DateTime? actualizadoAt;

  const ProgramaFidelizacionModel({
    required this.id,
    required this.negocioId,
    required this.activo,
    required this.nombre,
    required this.descripcion,
    required this.sellosParaRecompensa,
    required this.recompensas,
    this.caducidadMeses,
    required this.creadoAt,
    this.actualizadoAt,
  });

  factory ProgramaFidelizacionModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final recompensasList = (d['recompensas'] as List<dynamic>?)
        ?.map((r) => RecompensaPrograma.fromMap(r as Map<String, dynamic>))
        .toList() ?? [];

    return ProgramaFidelizacionModel(
      id: doc.id,
      negocioId: d['negocio_id'] as String? ?? '',
      activo: d['activo'] as bool? ?? false,
      nombre: d['nombre'] as String? ?? 'Programa de Fidelización',
      descripcion: d['descripcion'] as String? ?? '',
      sellosParaRecompensa: d['sellos_para_recompensa'] as int? ?? 8,
      recompensas: recompensasList,
      caducidadMeses: d['caducidad_meses'] as int?,
      creadoAt: (d['creado_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      actualizadoAt: (d['actualizado_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'negocio_id': negocioId,
    'activo': activo,
    'nombre': nombre,
    'descripcion': descripcion,
    'sellos_para_recompensa': sellosParaRecompensa,
    'recompensas': recompensas.map((r) => r.toMap()).toList(),
    if (caducidadMeses != null) 'caducidad_meses': caducidadMeses,
    'creado_at': Timestamp.fromDate(creadoAt),
    if (actualizadoAt != null) 'actualizado_at': Timestamp.fromDate(actualizadoAt!),
  };

  ProgramaFidelizacionModel copyWith({
    String? id,
    String? negocioId,
    bool? activo,
    String? nombre,
    String? descripcion,
    int? sellosParaRecompensa,
    List<RecompensaPrograma>? recompensas,
    int? caducidadMeses,
    DateTime? creadoAt,
    DateTime? actualizadoAt,
  }) {
    return ProgramaFidelizacionModel(
      id: id ?? this.id,
      negocioId: negocioId ?? this.negocioId,
      activo: activo ?? this.activo,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      sellosParaRecompensa: sellosParaRecompensa ?? this.sellosParaRecompensa,
      recompensas: recompensas ?? this.recompensas,
      caducidadMeses: caducidadMeses ?? this.caducidadMeses,
      creadoAt: creadoAt ?? this.creadoAt,
      actualizadoAt: actualizadoAt ?? this.actualizadoAt,
    );
  }

  /// Obtiene la recompensa correspondiente al nivel de sellos
  RecompensaPrograma? obtenerRecompensaPorSellos(int sellosActuales) {
    if (recompensas.isEmpty) return null;

    // Ordenar de mayor a menor sellos necesarios
    final recompensasOrdenadas = List<RecompensaPrograma>.from(recompensas)
      ..sort((a, b) => b.sellosNecesarios.compareTo(a.sellosNecesarios));

    // Retornar la primera que se haya alcanzado
    for (final r in recompensasOrdenadas) {
      if (sellosActuales >= r.sellosNecesarios) return r;
    }

    return null;
  }

  /// Obtiene la siguiente recompensa a desbloquear
  RecompensaPrograma? obtenerSiguienteRecompensa(int sellosActuales) {
    if (recompensas.isEmpty) return null;

    // Ordenar de menor a mayor sellos necesarios
    final recompensasOrdenadas = List<RecompensaPrograma>.from(recompensas)
      ..sort((a, b) => a.sellosNecesarios.compareTo(b.sellosNecesarios));

    // Retornar la primera que NO se haya alcanzado
    for (final r in recompensasOrdenadas) {
      if (sellosActuales < r.sellosNecesarios) return r;
    }

    return null;
  }
}


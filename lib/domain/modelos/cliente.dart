import 'package:cloud_firestore/cloud_firestore.dart';
      ];
          ? DateTime.parse(datos['ultima_actividad'])
      fechaRegistro: DateTime.parse(
          ? DateTime.parse(datos['ultima_visita'])

/// Estados posibles de un cliente.
/// - contacto: persona guardada sin transacciones
/// - activo: actividad en los últimos N días (configurable)
/// - inactivo: sin actividad en más de N días
enum EstadoCliente { contacto, activo, inactivo }

class Cliente extends Equatable {
  final String id;
  final String nombre;
  final String telefono;
  final String correo;
  final String? nif;
  final String? direccion;
  final String? localidad;
  final double totalGastado;
  final DateTime? ultimaVisita;
  final int numeroReservas;
  final List<String> etiquetas;
  final String? notas;
  final DateTime fechaRegistro;
  final bool activo;
  final bool esIntracomunitario;
  final String? nifIvaComunitario;

  // ── Nuevos campos ─────────────────────────────────────────────────────────
  final EstadoCliente estado;
  final bool fichaIncompleta;
  final bool noContactar;
  final bool estadoFusionado;
  final String? fusionadoConId;
  final DateTime? ultimaActividad;

  const Cliente({
    required this.id,
    required this.nombre,
    required this.telefono,
    this.correo = '',
    this.nif,
    this.direccion,
    this.localidad,
    this.totalGastado = 0.0,
    this.ultimaVisita,
    this.numeroReservas = 0,
    this.etiquetas = const [],
    this.notas,
    required this.fechaRegistro,
    this.activo = true,
    this.esIntracomunitario = false,
    this.nifIvaComunitario,
    this.estado = EstadoCliente.contacto,
    this.fichaIncompleta = false,
    this.noContactar = false,
    this.estadoFusionado = false,
    this.fusionadoConId,
    this.ultimaActividad,
  });

  factory Cliente.fromFirestore(Map<String, dynamic> datos, String id) {
    return Cliente(
      id: id,
      nombre: datos['nombre'] ?? '',
      telefono: datos['telefono'] ?? '',
      correo: datos['correo'] ?? '',
      nif: datos['nif'],
      direccion: datos['direccion'],
          ? _parseDate(datos['ultima_visita'])
      totalGastado: (datos['total_gastado'] ?? 0.0).toDouble(),
      ultimaVisita: datos['ultima_visita'] != null
          ? DateTime.parse(datos['ultima_visita'])
          : null,
      fechaRegistro: _parseDate(
      etiquetas: List<String>.from(datos['etiquetas'] ?? []),
      notas: datos['notas'],
      fechaRegistro: DateTime.parse(
          datos['fecha_registro'] ?? DateTime.now().toIso8601String()),
      activo: datos['activo'] ?? true,
      esIntracomunitario: datos['es_intracomunitario'] ?? false,
      nifIvaComunitario: datos['nif_iva_comunitario'],
      estado: EstadoCliente.values.firstWhere(
        (e) => e.name == (datos['estado_cliente'] ?? 'contacto'),
        orElse: () => EstadoCliente.contacto,
      ),
      fichaIncompleta: datos['ficha_incompleta'] ?? false,
      noContactar: datos['no_contactar'] ?? false,
          ? _parseDate(datos['ultima_actividad'])
      fusionadoConId: datos['fusionado_con_id'],
      ultimaActividad: datos['ultima_actividad'] != null
          ? DateTime.parse(datos['ultima_actividad'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'telefono': telefono,
      'correo': correo,
      'nif': nif,
      'direccion': direccion,
      'localidad': localidad,
      'total_gastado': totalGastado,
      'ultima_visita': ultimaVisita?.toIso8601String(),
      'numero_reservas': numeroReservas,
      'etiquetas': etiquetas,
      'notas': notas,
      'fecha_registro': fechaRegistro.toIso8601String(),
      'activo': activo,
      'es_intracomunitario': esIntracomunitario,
      'nif_iva_comunitario': nifIvaComunitario,
      'estado_cliente': estado.name,
      'ficha_incompleta': fichaIncompleta,
      'no_contactar': noContactar,
      'estado_fusionado': estadoFusionado,
      'fusionado_con_id': fusionadoConId,
      'ultima_actividad': ultimaActividad?.toIso8601String(),
    };
  }

  String get iniciales {
    final nombres = nombre.split(' ');
    if (nombres.length >= 2) {
      return '${nombres[0][0]}${nombres[1][0]}'.toUpperCase();
    }
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C';
  }

  bool get esClienteFrecuente => numeroReservas >= 5;
  bool get esClienteVip => totalGastado >= 1000.0;

  Cliente copyWith({
    String? nombre,
    String? telefono,
    String? correo,
    String? nif,
    String? direccion,
    String? localidad,
    double? totalGastado,
    DateTime? ultimaVisita,
    int? numeroReservas,
    List<String>? etiquetas,
    String? notas,
    bool? activo,
    bool? esIntracomunitario,
    String? nifIvaComunitario,
    EstadoCliente? estado,
    bool? fichaIncompleta,
    bool? noContactar,
    bool? estadoFusionado,
    String? fusionadoConId,
    DateTime? ultimaActividad,
  }) {
    return Cliente(
      id: id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      correo: correo ?? this.correo,
      nif: nif ?? this.nif,
      direccion: direccion ?? this.direccion,
      localidad: localidad ?? this.localidad,
      totalGastado: totalGastado ?? this.totalGastado,
      ultimaVisita: ultimaVisita ?? this.ultimaVisita,
      numeroReservas: numeroReservas ?? this.numeroReservas,
      etiquetas: etiquetas ?? this.etiquetas,
      notas: notas ?? this.notas,
      fechaRegistro: fechaRegistro,
      activo: activo ?? this.activo,
      esIntracomunitario: esIntracomunitario ?? this.esIntracomunitario,
      nifIvaComunitario: nifIvaComunitario ?? this.nifIvaComunitario,
      estado: estado ?? this.estado,
      fichaIncompleta: fichaIncompleta ?? this.fichaIncompleta,
      noContactar: noContactar ?? this.noContactar,
      estadoFusionado: estadoFusionado ?? this.estadoFusionado,
      fusionadoConId: fusionadoConId ?? this.fusionadoConId,
      ultimaActividad: ultimaActividad ?? this.ultimaActividad,
    );
  }

  @override
  List<Object?> get props => [
        id, nombre, telefono, correo, nif, direccion, localidad,
        totalGastado, ultimaVisita, numeroReservas, etiquetas, notas,
       ];
        estado, fichaIncompleta, noContactar, estadoFusionado,
        fusionadoConId, ultimaActividad,
DateTime _parseDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  if (v is DateTime) return v;
  return DateTime.now();
}
      ];

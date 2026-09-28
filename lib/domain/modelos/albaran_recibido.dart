import 'package:cloud_firestore/cloud_firestore.dart';

// ── ENUMS ─────────────────────────────────────────────────────────────────────

enum EstadoAlbaranRecibido { pendiente, conforme, disconforme, parcial }

extension EstadoAlbaranRecibidoExt on EstadoAlbaranRecibido {
  String get etiqueta {
    switch (this) {
      case EstadoAlbaranRecibido.pendiente:    return 'Pendiente';
      case EstadoAlbaranRecibido.conforme:     return 'Conforme';
      case EstadoAlbaranRecibido.disconforme:  return 'Disconforme';
      case EstadoAlbaranRecibido.parcial:      return 'Parcial';
    }
  }
}

// ── LÍNEA DE ALBARÁN ──────────────────────────────────────────────────────────

class LineaAlbaran {
  final String descripcion;
  final String referencia;         // código/ref del producto (puede estar vacío)
  final double cantidadPedida;     // 0 si no se sabe
  final double cantidadRecibida;
  final String notas;              // discrepancias, daños, etc.

  const LineaAlbaran({
    required this.descripcion,
    this.referencia = '',
    this.cantidadPedida = 0,
    required this.cantidadRecibida,
    this.notas = '',
  });

  factory LineaAlbaran.fromMap(Map<String, dynamic> m) => LineaAlbaran(
    descripcion:      m['descripcion'] ?? '',
    referencia:       m['referencia']  ?? '',
    cantidadPedida:   (m['cantidad_pedida'] as num?)?.toDouble() ?? 0,
    cantidadRecibida: (m['cantidad_recibida'] as num?)?.toDouble() ?? 0,
    notas:            m['notas'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'descripcion':       descripcion,
    'referencia':        referencia,
    'cantidad_pedida':   cantidadPedida,
    'cantidad_recibida': cantidadRecibida,
    'notas':             notas,
  };

  LineaAlbaran copyWith({
    String? descripcion,
    String? referencia,
    double? cantidadPedida,
    double? cantidadRecibida,
    String? notas,
  }) => LineaAlbaran(
    descripcion:      descripcion      ?? this.descripcion,
    referencia:       referencia       ?? this.referencia,
    cantidadPedida:   cantidadPedida   ?? this.cantidadPedida,
    cantidadRecibida: cantidadRecibida ?? this.cantidadRecibida,
    notas:            notas            ?? this.notas,
  );
}

// ── ALBARÁN RECIBIDO ──────────────────────────────────────────────────────────

class AlbaranRecibido {
  final String id;
  final String empresaId;
  final String numeroAlbaran;        // referencia del proveedor
  final String nombreProveedor;
  final String nifProveedor;         // puede estar vacío
  final String telefonoProveedor;
  final DateTime fechaAlbaran;       // fecha que aparece en el documento
  final DateTime fechaRecepcion;     // cuando lo recibiste tú
  final List<LineaAlbaran> lineas;
  final EstadoAlbaranRecibido estado;
  final String notas;
  final DateTime fechaCreacion;
  final DateTime? fechaActualizacion;

  const AlbaranRecibido({
    required this.id,
    required this.empresaId,
    required this.numeroAlbaran,
    required this.nombreProveedor,
    this.nifProveedor = '',
    this.telefonoProveedor = '',
    required this.fechaAlbaran,
    required this.fechaRecepcion,
    this.lineas = const [],
    this.estado = EstadoAlbaranRecibido.pendiente,
    this.notas = '',
    required this.fechaCreacion,
    this.fechaActualizacion,
  });

  factory AlbaranRecibido.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AlbaranRecibido(
      id:                  doc.id,
      empresaId:           d['empresa_id'] ?? '',
      numeroAlbaran:       d['numero_albaran'] ?? '',
      nombreProveedor:     d['nombre_proveedor'] ?? '',
      nifProveedor:        d['nif_proveedor'] ?? '',
      telefonoProveedor:   d['telefono_proveedor'] ?? '',
      fechaAlbaran:        _parseTs(d['fecha_albaran']),
      fechaRecepcion:      _parseTs(d['fecha_recepcion']),
      lineas: (d['lineas'] as List<dynamic>?)
          ?.map((e) => LineaAlbaran.fromMap(e as Map<String, dynamic>))
          .toList() ?? [],
      estado: EstadoAlbaranRecibido.values.firstWhere(
        (e) => e.name == d['estado'],
        orElse: () => EstadoAlbaranRecibido.pendiente,
      ),
      notas:               d['notas'] ?? '',
      fechaCreacion:       _parseTs(d['fecha_creacion']),
      fechaActualizacion:  d['fecha_actualizacion'] != null
          ? _parseTs(d['fecha_actualizacion'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id':          empresaId,
    'numero_albaran':      numeroAlbaran,
    'nombre_proveedor':    nombreProveedor,
    'nif_proveedor':       nifProveedor,
    'telefono_proveedor':  telefonoProveedor,
    'fecha_albaran':       Timestamp.fromDate(fechaAlbaran),
    'fecha_recepcion':     Timestamp.fromDate(fechaRecepcion),
    'lineas':              lineas.map((l) => l.toMap()).toList(),
    'estado':              estado.name,
    'notas':               notas,
    'fecha_creacion':      Timestamp.fromDate(fechaCreacion),
    'fecha_actualizacion': Timestamp.fromDate(fechaActualizacion ?? DateTime.now()),
  };

  AlbaranRecibido copyWith({
    String? numeroAlbaran,
    String? nombreProveedor,
    String? nifProveedor,
    String? telefonoProveedor,
    DateTime? fechaAlbaran,
    DateTime? fechaRecepcion,
    List<LineaAlbaran>? lineas,
    EstadoAlbaranRecibido? estado,
    String? notas,
    DateTime? fechaActualizacion,
  }) => AlbaranRecibido(
    id:                  id,
    empresaId:           empresaId,
    numeroAlbaran:       numeroAlbaran       ?? this.numeroAlbaran,
    nombreProveedor:     nombreProveedor     ?? this.nombreProveedor,
    nifProveedor:        nifProveedor        ?? this.nifProveedor,
    telefonoProveedor:   telefonoProveedor   ?? this.telefonoProveedor,
    fechaAlbaran:        fechaAlbaran        ?? this.fechaAlbaran,
    fechaRecepcion:      fechaRecepcion      ?? this.fechaRecepcion,
    lineas:              lineas              ?? this.lineas,
    estado:              estado              ?? this.estado,
    notas:               notas               ?? this.notas,
    fechaCreacion:       fechaCreacion,
    fechaActualizacion:  fechaActualizacion  ?? this.fechaActualizacion,
  );

  bool get estaConforme   => estado == EstadoAlbaranRecibido.conforme;
  bool get estaPendiente  => estado == EstadoAlbaranRecibido.pendiente;
  int  get totalLineas    => lineas.length;
}

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

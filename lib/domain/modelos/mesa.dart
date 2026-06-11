  import 'package:cloud_firestore/cloud_firestore.dart';

  /// Mesa del restaurante/bar
  class Mesa {
    final String id;
    final String empresaId;
    final int numero;
    final String nombre;
    final String zona;
    final int capacidad;
    final String estado; // libre | ocupada | reservada
  final String? comandaId;
  final String? camareroUid;
  final Timestamp? fechaApertura;
  final int? comensales;
  final String? asignadoAUid;
  final String? asignadoANombre;

  // Plano visual de mesas (floor plan)
  final double posX;
  final double posY;
  final double mesaAncho;
  final double mesaAlto;
  final String forma; // 'rect' | 'circle' | 'bar'

  const Mesa({
    required this.id,
    required this.empresaId,
    required this.numero,
    required this.nombre,
    required this.zona,
    required this.capacidad,
    required this.estado,
    this.comandaId,
    this.camareroUid,
    this.fechaApertura,
    this.comensales,
    this.asignadoAUid,
    this.asignadoANombre,
    this.posX = 0.05,
    this.posY = 0.05,
    this.mesaAncho = 0.18,
    this.mesaAlto = 0.14,
    this.forma = 'rect',
  });

    bool get esLibre => estado == 'libre';
    bool get esOcupada => estado == 'ocupada';
    bool get esReservada => estado == 'reservada';

    factory Mesa.fromFirestore(DocumentSnapshot doc, {String? empresaId}) {
      final data = doc.data() as Map<String, dynamic>;
      return Mesa(
        id: doc.id,
        empresaId: empresaId ?? doc.reference.parent.parent!.id,
        numero: (data['numero'] as num?)?.toInt() ?? 0,
        nombre: data['nombre'] as String? ?? '',
        zona: data['zona'] as String? ?? '',
        capacidad: (data['capacidad'] as num?)?.toInt() ?? 4,
        estado: data['estado'] as String? ?? 'libre',
      comandaId: data['comanda_id'] as String?,
      camareroUid: data['camarero_uid'] as String?,
      fechaApertura: data['fecha_apertura'] as Timestamp?,
      comensales: (data['comensales'] as num?)?.toInt(),
      asignadoAUid: data['asignado_a_uid'] as String?,
      asignadoANombre: data['asignado_a_nombre'] as String?,
      posX: (data['pos_x'] as num?)?.toDouble() ?? 0.05,
      posY: (data['pos_y'] as num?)?.toDouble() ?? 0.05,
      mesaAncho: (data['mesa_ancho'] as num?)?.toDouble() ?? 0.18,
      mesaAlto: (data['mesa_alto'] as num?)?.toDouble() ?? 0.14,
      forma: data['forma'] as String? ?? 'rect',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'numero': numero,
    'nombre': nombre,
    'zona': zona,
    'capacidad': capacidad,
    'estado': estado,
    'comanda_id': comandaId,
    'camarero_uid': camareroUid,
    'fecha_apertura': fechaApertura,
    'comensales': comensales,
    'asignado_a_uid': asignadoAUid,
    'asignado_a_nombre': asignadoANombre,
    'pos_x': posX,
    'pos_y': posY,
    'mesa_ancho': mesaAncho,
    'mesa_alto': mesaAlto,
    'forma': forma,
  };

  Mesa copyWith({
    String? nombre,
    String? zona,
    int? capacidad,
    String? estado,
    String? comandaId,
    String? camareroUid,
    Timestamp? fechaApertura,
    int? comensales,
    bool clearComensales = false,
    String? asignadoAUid,
    String? asignadoANombre,
    bool clearAsignacion = false,
    double? posX,
    double? posY,
    double? mesaAncho,
    double? mesaAlto,
    String? forma,
  }) => Mesa(
    id: id,
    empresaId: empresaId,
    numero: numero,
    nombre: nombre ?? this.nombre,
    zona: zona ?? this.zona,
    capacidad: capacidad ?? this.capacidad,
    estado: estado ?? this.estado,
    comandaId: comandaId ?? this.comandaId,
    camareroUid: camareroUid ?? this.camareroUid,
    fechaApertura: fechaApertura ?? this.fechaApertura,
    comensales: clearComensales ? null : (comensales ?? this.comensales),
    asignadoAUid: clearAsignacion ? null : (asignadoAUid ?? this.asignadoAUid),
    asignadoANombre: clearAsignacion ? null : (asignadoANombre ?? this.asignadoANombre),
    posX: posX ?? this.posX,
    posY: posY ?? this.posY,
    mesaAncho: mesaAncho ?? this.mesaAncho,
    mesaAlto: mesaAlto ?? this.mesaAlto,
    forma: forma ?? this.forma,
  );
}





















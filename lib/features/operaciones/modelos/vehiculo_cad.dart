import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

enum EstadoVehiculo { disponible, enRoute, atendiendo, regresando, offline }

extension EstadoVehiculoExt on EstadoVehiculo {
  String get label => switch (this) {
    EstadoVehiculo.disponible   => 'Disponible',
    EstadoVehiculo.enRoute      => 'En ruta',
    EstadoVehiculo.atendiendo   => 'Atendiendo',
    EstadoVehiculo.regresando   => 'Regresando',
    EstadoVehiculo.offline      => 'Sin conexión',
  };

  static EstadoVehiculo fromString(String? s) => switch (s) {
    'en_route'    => EstadoVehiculo.enRoute,
    'atendiendo'  => EstadoVehiculo.atendiendo,
    'regresando'  => EstadoVehiculo.regresando,
    'offline'     => EstadoVehiculo.offline,
    _             => EstadoVehiculo.disponible,
  };

  String get firestoreValue => switch (this) {
    EstadoVehiculo.disponible  => 'disponible',
    EstadoVehiculo.enRoute     => 'en_route',
    EstadoVehiculo.atendiendo  => 'atendiendo',
    EstadoVehiculo.regresando  => 'regresando',
    EstadoVehiculo.offline     => 'offline',
  };
}

class VehiculoCAD {
  final String id;
  final String nombre;       // 'AMB-01'
  final String tipo;         // 'SVB' | 'SVA'
  final String matricula;
  final List<String> tripulacion;
  final EstadoVehiculo estado;
  final double lat;
  final double lng;
  final double velocidad;    // km/h
  final double rumbo;        // grados 0=norte
  final DateTime ultimaGPS;
  final String? alertaAsignadaId;
  final String zona;

  LatLng get posicion => LatLng(lat, lng);

  const VehiculoCAD({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.matricula,
    required this.tripulacion,
    required this.estado,
    required this.lat,
    required this.lng,
    required this.velocidad,
    required this.rumbo,
    required this.ultimaGPS,
    this.alertaAsignadaId,
    required this.zona,
  });

  factory VehiculoCAD.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return VehiculoCAD(
      id:              doc.id,
      nombre:          d['nombre']     as String? ?? doc.id,
      tipo:            d['tipo']       as String? ?? 'SVB',
      matricula:       d['matricula']  as String? ?? '',
      tripulacion:     (d['tripulacion'] as List<dynamic>?)?.cast<String>() ?? [],
      estado:          EstadoVehiculoExt.fromString(d['estado'] as String?),
      lat:             (d['lat'] as num?)?.toDouble() ?? 40.6333,
      lng:             (d['lng'] as num?)?.toDouble() ?? -3.1667,
      velocidad:       (d['velocidad'] as num?)?.toDouble() ?? 0,
      rumbo:           (d['rumbo']     as num?)?.toDouble() ?? 0,
      ultimaGPS:       (d['ultima_gps'] as Timestamp?)?.toDate() ?? DateTime.now(),
      alertaAsignadaId: d['alerta_asignada_id'] as String?,
      zona:            d['zona'] as String? ?? '—',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'nombre':    nombre,
    'tipo':      tipo,
    'matricula': matricula,
    'tripulacion': tripulacion,
    'estado':    estado.firestoreValue,
    'lat':       lat,
    'lng':       lng,
    'velocidad': velocidad,
    'rumbo':     rumbo,
    'ultima_gps': FieldValue.serverTimestamp(),
    if (alertaAsignadaId != null) 'alerta_asignada_id': alertaAsignadaId,
    'zona':      zona,
  };

  VehiculoCAD copyWith({
    EstadoVehiculo? estado,
    double? lat,
    double? lng,
    double? velocidad,
    double? rumbo,
    String? alertaAsignadaId,
    bool clearAlerta = false,
  }) => VehiculoCAD(
    id: id, nombre: nombre, tipo: tipo, matricula: matricula,
    tripulacion: tripulacion, zona: zona,
    ultimaGPS: DateTime.now(),
    estado: estado ?? this.estado,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    velocidad: velocidad ?? this.velocidad,
    rumbo: rumbo ?? this.rumbo,
    alertaAsignadaId: clearAlerta ? null : (alertaAsignadaId ?? this.alertaAsignadaId),
  );
}


// Vehículos de demostración para cuando no hay datos en Firestore
final List<VehiculoCAD> kVehiculosDemo = [
  VehiculoCAD(id: 'AMB-01', nombre: 'AMB-01', tipo: 'SVB', matricula: '0001-GUA',
    tripulacion: ['Carlos Pérez (TES)', 'Ana Molina (TES)'],
    estado: EstadoVehiculo.disponible, lat: 40.6264, lng: -3.1660,
    velocidad: 42, rumbo: 15, ultimaGPS: DateTime.now(), zona: 'Hospital'),
  VehiculoCAD(id: 'AMB-02', nombre: 'AMB-02', tipo: 'SVA', matricula: '0002-GUA',
    tripulacion: ['Carmen Ruiz (Médico)', 'Javier Torres (DUE)', 'Luis García (TES)'],
    estado: EstadoVehiculo.disponible, lat: 40.6240, lng: -3.1707,
    velocidad: 38, rumbo: 45, ultimaGPS: DateTime.now(), zona: 'Av. Castilla'),
  VehiculoCAD(id: 'AMB-03', nombre: 'AMB-03', tipo: 'SVB', matricula: '0003-GUA',
    tripulacion: ['Marta Blanco (TES)', 'Roberto Díaz (TES)'],
    estado: EstadoVehiculo.disponible, lat: 40.6342, lng: -3.1498,
    velocidad: 35, rumbo: 270, ultimaGPS: DateTime.now(), zona: 'Zona Este'),
  VehiculoCAD(id: 'AMB-04', nombre: 'AMB-04', tipo: 'SVA', matricula: '0004-GUA',
    tripulacion: ['Elena Sánchez (Médico)', 'Pablo Moreno (DUE)', 'Sofía Castro (TES)'],
    estado: EstadoVehiculo.disponible, lat: 40.6422, lng: -3.1649,
    velocidad: 44, rumbo: 190, ultimaGPS: DateTime.now(), zona: 'Zona Norte'),
  VehiculoCAD(id: 'AMB-05', nombre: 'AMB-05', tipo: 'SVB', matricula: '0005-GUA',
    tripulacion: ['Adrián López (TES)', 'Natalia Vega (TES)'],
    estado: EstadoVehiculo.offline, lat: 40.6152, lng: -3.1658,
    velocidad: 0, rumbo: 90,
    ultimaGPS: DateTime.now().subtract(const Duration(minutes: 9)), zona: 'Zona Sur'),
];

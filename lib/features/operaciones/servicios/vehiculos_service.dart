import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import '../modelos/vehiculo_cad.dart';
import 'osrm_service.dart';

// ignore: unused_import
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

// Colección: empresas/{id}/vehiculos_cad/{vehiculoId}
class VehiculosCADService {
  final String empresaId;
  final _db = FirebaseFirestore.instance;

  VehiculosCADService(this.empresaId);

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('empresas').doc(empresaId).collection('vehiculos_cad');

  // Stream en tiempo real de todos los vehículos
  Stream<List<VehiculoCAD>> vehiculosStream() =>
      _col.orderBy('nombre').snapshots().map(
        (s) => s.docs.map(VehiculoCAD.fromFirestore).toList(),
      );

  // Actualizar posición GPS (llamado desde la app del TES cada 5s)
  Future<void> actualizarGPS({
    required String vehiculoId,
    required double lat,
    required double lng,
    required double velocidad,
    required double rumbo,
  }) =>
      _col.doc(vehiculoId).update({
        'lat': lat,
        'lng': lng,
        'velocidad': velocidad,
        'rumbo': rumbo,
        'ultima_gps': FieldValue.serverTimestamp(),
      });

  // Cambiar estado (ej: disponible → en_route al aceptar despacho)
  Future<void> cambiarEstado(String vehiculoId, EstadoVehiculo estado, {String? alertaId}) =>
      _col.doc(vehiculoId).update({
        'estado': estado.firestoreValue,
        if (alertaId != null) 'alerta_asignada_id': alertaId,
        if (estado == EstadoVehiculo.disponible) 'alerta_asignada_id': FieldValue.delete(),
      });

  // Seed de vehículos demo + emergencias de prueba si las colecciones están vacías
  Future<void> seedVehiculosDemoSiVacio() async {
    final vehSnap = await _col.limit(1).get();
    if (vehSnap.docs.isEmpty) {
      final batch = _db.batch();
      for (final v in kVehiculosDemo) {
        batch.set(_col.doc(v.id), v.toFirestore());
      }
      await batch.commit();
    }

    // Seed de emergencias de prueba
    final alertasCol = _db.collection('empresas').doc(empresaId).collection('alertas_despacho');
    final alertSnap = await alertasCol.limit(1).get();
    if (alertSnap.docs.isEmpty) {
      final now = DateTime.now();
      await alertasCol.add({
        'tipo_codigo': 'PCR',
        'descripcion': 'Varón de 62 años, pérdida de conocimiento, posible parada cardiorrespiratoria. Testigos realizando RCP.',
        'direccion': 'Av. del Ejército, 15',
        'localidad': 'Guadalajara',
        'prioridad': 'critica',
        'num_pacientes': 1,
        'lat': 40.6367,
        'lng': -3.1612,
        'ambulancia_asignada': null,
        'estado': 'pendiente',
        'fecha_hora': Timestamp.fromDate(now.subtract(const Duration(minutes: 3))),
        'operador_uid': 'seed',
      });
      await alertasCol.add({
        'tipo_codigo': 'ACCIDENT',
        'descripcion': 'Colisión frontal entre dos vehículos. Herido atrapado y politraumatizados.',
        'direccion': 'C/ Albarracín, 5',
        'localidad': 'Guadalajara',
        'prioridad': 'alta',
        'num_pacientes': 2,
        'lat': 40.6314,
        'lng': -3.1545,
        'ambulancia_asignada': null,
        'estado': 'pendiente',
        'fecha_hora': Timestamp.fromDate(now.subtract(const Duration(minutes: 7))),
        'operador_uid': 'seed',
      });
      await alertasCol.add({
        'tipo_codigo': 'TCE',
        'descripcion': 'Varón 45 años, caída desde altura. Traumatismo craneoencefálico. Inconsciente.',
        'direccion': 'Av. de Castilla, 44',
        'localidad': 'Guadalajara',
        'prioridad': 'critica',
        'num_pacientes': 1,
        'lat': 40.6242,
        'lng': -3.1707,
        'ambulancia_asignada': null,
        'estado': 'pendiente',
        'fecha_hora': Timestamp.fromDate(now.subtract(const Duration(minutes: 1))),
        'operador_uid': 'seed',
      });
      await alertasCol.add({
        'tipo_codigo': 'RESPIRATORY',
        'descripcion': 'Mujer 72 años con disnea severa y saturación baja. Antecedentes de EPOC.',
        'direccion': 'C/ Cardenal Lorenzana, 22',
        'localidad': 'Guadalajara',
        'prioridad': 'alta',
        'num_pacientes': 1,
        'lat': 40.6295,
        'lng': -3.1680,
        'ambulancia_asignada': null,
        'estado': 'pendiente',
        'fecha_hora': Timestamp.fromDate(now.subtract(const Duration(minutes: 5))),
        'operador_uid': 'seed',
      });
    }
  }
}

// Resultado del algoritmo de despacho
class RecomendacionDespacho {
  final VehiculoCAD vehiculo;
  final RouteResult ruta;
  final bool disponible;
  final String? razonNoDisponible;
  final bool compatibleTipo; // SVA para PCR/IAM

  const RecomendacionDespacho({
    required this.vehiculo,
    required this.ruta,
    required this.disponible,
    this.razonNoDisponible,
    required this.compatibleTipo,
  });
}

class AlgoritmoDespacho {
  // Tipos que requieren SVA
  static const _requiereSVA = {'PCR', 'IAM'};

  // Calcula recomendaciones ordenadas por ETA real (OSRM)
  static Future<List<RecomendacionDespacho>> calcular({
    required List<VehiculoCAD> vehiculos,
    required LatLng posicionEmergencia,
    required String tipoEmergencia,
  }) async {
    final necesitaSVA = _requiereSVA.contains(tipoEmergencia);
    final disponibles = vehiculos.where((v) => v.estado == EstadoVehiculo.disponible).toList();

    // Calcular rutas OSRM para disponibles en paralelo
    final futures = disponibles.map((v) async {
      final ruta = await OsrmService.calcularRuta(v.posicion, posicionEmergencia);
      return RecomendacionDespacho(
        vehiculo: v,
        ruta: ruta,
        disponible: true,
        compatibleTipo: !necesitaSVA || v.tipo == 'SVA',
      );
    });

    final resultados = await Future.wait(futures);

    // Ordenar: primero tipo compatible, luego por ETA
    resultados.sort((a, b) {
      if (a.compatibleTipo != b.compatibleTipo) {
        return a.compatibleTipo ? -1 : 1;
      }
      return a.ruta.etaMinutes.compareTo(b.ruta.etaMinutes);
    });

    // Añadir no disponibles al final
    final noDisponibles = vehiculos
        .where((v) => v.estado != EstadoVehiculo.disponible)
        .map((v) => RecomendacionDespacho(
              vehiculo: v,
              ruta: const RouteResult(distanceKm: 0, etaMinutes: 0, waypoints: []),
              disponible: false,
              razonNoDisponible: v.estado.label,
              compatibleTipo: false,
            ))
        .toList();

    return [...resultados, ...noDisponibles];
  }
}

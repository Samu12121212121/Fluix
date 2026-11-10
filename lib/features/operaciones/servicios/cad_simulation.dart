import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../modelos/vehiculo_cad.dart';

final _rng = math.Random();

// ═══════════════════════════════════════════════════════════════════════════════
// SIMULACIÓN GPS — Ambulancias patrullando Guadalajara
//
// Cada vehículo sigue una ruta de waypoints cíclica.
// Al despacharse, cambia a la ruta OSRM calculada.
// Tick cada 2500ms. Velocidad: 30-45 km/h patrulla, 55-65 despacho.
// ═══════════════════════════════════════════════════════════════════════════════

// Rutas de patrulla por calles reales de Guadalajara
final Map<String, List<LatLng>> kPatrolRoutes = {
  'AMB-01': [
    LatLng(40.6264, -3.1660), // Hospital Universitario
    LatLng(40.6282, -3.1672), // C/ Cardenal González de Mendoza
    LatLng(40.6307, -3.1676), // C/ Alfonso VIII
    LatLng(40.6333, -3.1663), // Plaza Mayor / Centro
    LatLng(40.6351, -3.1638), // C/ Mayor Este
    LatLng(40.6364, -3.1594), // Av. del Ejército
    LatLng(40.6341, -3.1554), // C/ Obispo Ángel Hidalgo
    LatLng(40.6314, -3.1535), // Estación Autobuses
    LatLng(40.6294, -3.1550), // C/ Albarracín
    LatLng(40.6270, -3.1597), // Barranco del Alamín
  ],
  'AMB-02': [
    LatLng(40.6183, -3.1775), // Polígono El Balconcillo
    LatLng(40.6213, -3.1738), // C/ Hispanidad
    LatLng(40.6242, -3.1707), // Av. de Castilla
    LatLng(40.6265, -3.1690), // near Hospital W
    LatLng(40.6295, -3.1680), // C/ Cardenal Lorenzana
    LatLng(40.6333, -3.1668), // Centro
    LatLng(40.6355, -3.1640), // Av. del Ejército W
    LatLng(40.6371, -3.1597), // Av. del Ejército E
    LatLng(40.6350, -3.1549), // C/ Alvar Fáñez
    LatLng(40.6300, -3.1537), // near Estación
    LatLng(40.6253, -3.1601), // Circunvalación S
  ],
  'AMB-03': [
    LatLng(40.6342, -3.1498), // Barrio Aguas Vivas (E)
    LatLng(40.6335, -3.1540), // C/ Sigüenza
    LatLng(40.6330, -3.1572), // C/ Medina
    LatLng(40.6334, -3.1621), // C/ Fernández Iparraguirre
    LatLng(40.6336, -3.1668), // Centro / Plaza Mayor
    LatLng(40.6338, -3.1700), // C/ General Moscardó (W)
    LatLng(40.6330, -3.1742), // Paseo de las Cruces
    LatLng(40.6310, -3.1728), // C/ Alonso Coello
    LatLng(40.6294, -3.1703), // near Hospital W
    LatLng(40.6300, -3.1650), // C/ Cardenal Lorenzana S
  ],
  'AMB-04': [
    LatLng(40.6422, -3.1649), // Norte Guadalajara
    LatLng(40.6401, -3.1621), // C/ Palancares
    LatLng(40.6382, -3.1611), // Av. del Ejército Centro
    LatLng(40.6360, -3.1578), // Av. del Ejército E
    LatLng(40.6340, -3.1551), // C/ Obispo Ángel Hidalgo
    LatLng(40.6314, -3.1535), // Estación
    LatLng(40.6288, -3.1558), // C/ Ferial
    LatLng(40.6267, -3.1620), // Barranco del Alamín
    LatLng(40.6264, -3.1660), // Hospital Universitario
    LatLng(40.6282, -3.1702), // C/ Juan de Villanueva
    LatLng(40.6315, -3.1710), // Hospital W approach
    LatLng(40.6356, -3.1682), // C/ Cardenal Lorenzana N
  ],
  'AMB-05': [
    LatLng(40.6152, -3.1658), // Sur / CM-200
    LatLng(40.6183, -3.1672), // Acceso Sur
    LatLng(40.6213, -3.1667), // C/ Cardenal Lorenzana S
    LatLng(40.6243, -3.1663), // Hospital S
    LatLng(40.6264, -3.1660), // Hospital Universitario
    LatLng(40.6295, -3.1653), // Hospital N entrance
    LatLng(40.6320, -3.1660), // C/ Cardenal González N
    LatLng(40.6334, -3.1658), // Centro
    LatLng(40.6300, -3.1638), // C/ Juan Villamajor
    LatLng(40.6267, -3.1638), // Barranco E
  ],
};

class SimVehiculo {
  final String id;
  double lat;
  double lng;
  double heading;
  double speed; // km/h
  List<LatLng> route;
  List<LatLng> baseRoute;
  int routeIndex;
  EstadoVehiculo estado;
  String? alertaId;
  int attendingTicks; // para retorno automático

  SimVehiculo({
    required this.id,
    required this.lat,
    required this.lng,
    required this.heading,
    required this.speed,
    required this.route,
    required this.baseRoute,
    this.routeIndex = 0,
    this.estado = EstadoVehiculo.disponible,
    this.alertaId,
    this.attendingTicks = 0,
  });

  LatLng get posicion => LatLng(lat, lng);
}

double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const R = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLng = (lng2 - lng1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _bearing(double lat1, double lng1, double lat2, double lng2) {
  final dLng = (lng2 - lng1) * math.pi / 180;
  final y = math.sin(dLng) * math.cos(lat2 * math.pi / 180);
  final x = math.cos(lat1 * math.pi / 180) * math.sin(lat2 * math.pi / 180) -
      math.sin(lat1 * math.pi / 180) *
          math.cos(lat2 * math.pi / 180) *
          math.cos(dLng);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

// Avanza un vehículo 2.5 segundos en su ruta actual.
// Devuelve true si llegó al final de la ruta (para despacho/regreso).
bool tickVehiculo(SimVehiculo v, double deltaSeconds) {
  if (v.estado == EstadoVehiculo.offline || v.estado == EstadoVehiculo.atendiendo) {
    return false;
  }

  final speedKmh = v.estado == EstadoVehiculo.enRoute
      ? 55 + _rng.nextDouble() * 10
      : v.estado == EstadoVehiculo.regresando
          ? 42 + _rng.nextDouble() * 6
          : 28 + _rng.nextDouble() * 18;
  v.speed = speedKmh;

  final moveKm = (speedKmh / 3600) * deltaSeconds;
  double remaining = moveKm;

  while (remaining > 0 && v.routeIndex < v.route.length) {
    final target = v.route[v.routeIndex];
    final distKm = _haversineKm(v.lat, v.lng, target.latitude, target.longitude);

    if (distKm < 0.015) {
      // Reached waypoint
      v.lat = target.latitude;
      v.lng = target.longitude;
      v.routeIndex++;

      if (v.routeIndex >= v.route.length) {
        // End of route
        if (v.estado == EstadoVehiculo.disponible) {
          v.routeIndex = 0; // patrol loop
        } else {
          v.routeIndex = v.route.length - 1;
          return true; // reached destination
        }
        break;
      }
      continue;
    }

    final fraction = remaining / distKm;
    if (fraction >= 1.0) {
      remaining -= distKm;
      v.heading = _bearing(v.lat, v.lng, target.latitude, target.longitude);
      v.lat = target.latitude;
      v.lng = target.longitude;
      v.routeIndex++;
      if (v.routeIndex >= v.route.length) {
        if (v.estado == EstadoVehiculo.disponible) {
          v.routeIndex = 0;
        } else {
          v.routeIndex = v.route.length - 1;
          return true;
        }
        break;
      }
    } else {
      v.heading = _bearing(v.lat, v.lng, target.latitude, target.longitude);
      v.lat += (target.latitude - v.lat) * fraction;
      v.lng += (target.longitude - v.lng) * fraction;
      remaining = 0;
    }
  }
  return false;
}

// Inicializa la simulación desde los vehículos demo
List<SimVehiculo> initSimulacion() {
  return kVehiculosDemo.map((v) {
    final route = kPatrolRoutes[v.id] ?? [LatLng(v.lat, v.lng)];
    return SimVehiculo(
      id: v.id,
      lat: v.lat,
      lng: v.lng,
      heading: v.rumbo,
      speed: v.velocidad,
      route: List.from(route),
      baseRoute: route,
      routeIndex: (v.id == 'AMB-01') ? 1 :
                  (v.id == 'AMB-02') ? 3 :
                  (v.id == 'AMB-03') ? 1 : 0,
      estado: v.estado,
    );
  }).toList();
}

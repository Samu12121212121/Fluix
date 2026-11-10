import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// OSRM ROUTING SERVICE
//
// Calcula rutas reales por carretera usando OpenStreetMap Routing Machine.
// - Primario:  router.project-osrm.org  (público, sin clave, ~200ms)
// - Fallback:  Haversine × 1.35         (sin red)
//
// Para producción: apuntar _baseUrl a instancia propia con datos Spain:
//   https://hub.docker.com/r/osrm/osrm-backend
// ═══════════════════════════════════════════════════════════════════════════════

class RouteResult {
  final double distanceKm;
  final double etaMinutes;
  final List<LatLng> waypoints; // geometría real de la ruta
  final bool isFallback;        // true si se usó Haversine por fallo de red

  const RouteResult({
    required this.distanceKm,
    required this.etaMinutes,
    required this.waypoints,
    this.isFallback = false,
  });
}

class OsrmService {
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1/driving';
  static const Duration _timeout = Duration(seconds: 8);

  // Calcula ruta real entre dos puntos.
  // Devuelve la geometría completa para dibujar en el mapa.
  static Future<RouteResult> calcularRuta(LatLng origen, LatLng destino) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/${origen.longitude},${origen.latitude};${destino.longitude},${destino.latitude}'
        '?overview=full&geometries=geojson&steps=false',
      );

      final response = await http.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final routes = data['routes'] as List<dynamic>?;
        if (routes == null || routes.isEmpty) return _fallback(origen, destino);

        final route = routes[0] as Map<String, dynamic>;
        final distanceM  = (route['distance'] as num).toDouble();
        final durationS  = (route['duration'] as num).toDouble();
        final geometry   = route['geometry'] as Map<String, dynamic>;
        final coords     = geometry['coordinates'] as List<dynamic>;

        final waypoints = coords.map((c) {
          final pair = c as List<dynamic>;
          return LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble());
        }).toList();

        return RouteResult(
          distanceKm: distanceM / 1000,
          etaMinutes: durationS / 60,
          waypoints:  waypoints,
        );
      }
    } catch (_) {}

    return _fallback(origen, destino);
  }

  // Fallback: Haversine × factor de ruta urbana + velocidad de emergencia
  static RouteResult _fallback(LatLng origen, LatLng destino) {
    final straight = _haversineKm(origen, destino);
    final roadDist = straight * 1.38;
    // Ambulancia en emergencia: 55 km/h media en ciudad
    final eta = (roadDist / 55) * 60;
    // Generar ruta aproximada con punto intermedio
    final mid = LatLng(
      (origen.latitude + destino.latitude) / 2,
      (origen.longitude + destino.longitude) / 2,
    );
    return RouteResult(
      distanceKm: roadDist,
      etaMinutes: eta,
      waypoints:  [origen, mid, destino],
      isFallback: true,
    );
  }

  static double _haversineKm(LatLng a, LatLng b) {
    const R = 6371.0;
    final dLat = (b.latitude  - a.latitude)  * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude  * math.pi / 180) *
        math.cos(b.latitude  * math.pi / 180) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  // Calcula ETA y distancia para múltiples orígenes → mismo destino
  // Útil para ordenar ambulancias por tiempo de llegada
  static Future<List<({String id, RouteResult ruta})>> rankearVehiculos(
    List<({String id, LatLng pos})> vehiculos,
    LatLng destino,
  ) async {
    final futures = vehiculos.map((v) async {
      final ruta = await calcularRuta(v.pos, destino);
      return (id: v.id, ruta: ruta);
    });
    final resultados = await Future.wait(futures);
    resultados.sort((a, b) => a.ruta.etaMinutes.compareTo(b.ruta.etaMinutes));
    return resultados;
  }
}

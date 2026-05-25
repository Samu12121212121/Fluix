import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Resultado de la solicitud de ubicación.
class ResultadoUbicacion {
  final Position? posicion;
  final String? error;
  final bool permisoDenegadoPermanente;

  const ResultadoUbicacion({
    this.posicion,
    this.error,
    this.permisoDenegadoPermanente = false,
  });

  bool get ok => posicion != null;
}

/// Servicio de geolocalización para la pantalla Explorar.
class GeolocalizacionService {
  static const double _radioKmDefecto = 5.0;

  /// Solicita la posición actual del usuario.
  /// Gestiona permisos en runtime de forma segura.
  static Future<ResultadoUbicacion> obtenerPosicion() async {
    try {
      // Verificar si el servicio de localización está habilitado
      final servicioHabilitado = await Geolocator.isLocationServiceEnabled();
      if (!servicioHabilitado) {
        return const ResultadoUbicacion(error: 'Activa la ubicación del dispositivo');
      }

      // Solicitar permiso
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied) {
          return const ResultadoUbicacion(error: 'Permiso de ubicación denegado');
        }
      }

      if (permiso == LocationPermission.deniedForever) {
        return const ResultadoUbicacion(
          error: 'Permiso de ubicación denegado permanentemente',
          permisoDenegadoPermanente: true,
        );
      }

      // Obtener posición
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return ResultadoUbicacion(posicion: pos);
    } catch (e) {
      return ResultadoUbicacion(error: 'No se pudo obtener la ubicación: $e');
    }
  }

  /// Calcula la distancia en km entre dos coordenadas usando la fórmula de Haversine.
  static double distanciaKm(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Radio de la Tierra en km
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180);

  /// Devuelve texto formateado de distancia: "0.3 km", "1.2 km", "15 km"
  static String formatearDistancia(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  /// Filtrar lista por radio en km, ordenada de más cercana a más lejana.
  static List<T> filtrarPorRadio<T>({
    required List<T> items,
    required Position posicion,
    required double Function(T) getLat,
    required double Function(T) getLon,
    double radioKm = _radioKmDefecto,
  }) {
    final conDistancia = items
        .map((item) {
          final dist = distanciaKm(
            posicion.latitude, posicion.longitude,
            getLat(item), getLon(item),
          );
          return MapEntry(item, dist);
        })
        .where((e) => e.value <= radioKm)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return conDistancia.map((e) => e.key).toList();
  }
}

/// Widget que pide permiso de ubicación con botón para abrir ajustes.
class WidgetPermisUbicacion extends StatelessWidget {
  final String mensaje;
  final VoidCallback? onReintentar;

  const WidgetPermisUbicacion({
    super.key,
    required this.mensaje,
    this.onReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_rounded, size: 40, color: Color(0xFF6B6E82)),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (onReintentar != null)
              FilledButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Reintentar'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC8),
                  foregroundColor: const Color(0xFF0A0F23),
                ),
              )
            else
              FilledButton.icon(
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings, size: 16),
                label: const Text('Abrir ajustes'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC8),
                  foregroundColor: const Color(0xFF0A0F23),
                ),
              ),
          ],
        ),
      ),
    );
  }
}



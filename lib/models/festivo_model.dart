import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODELO DE FESTIVO — Datos de festivos nacionales, autonómicos y locales
// ═══════════════════════════════════════════════════════════════════════════════

enum TipoFestivo { nacional, autonomico, local }

class Festivo {
  final DateTime fecha;
  final String nombre;
  final TipoFestivo tipo;
  final String? codigoComunidad; // ej: "ES-CM" para Castilla-La Mancha
  final bool esLocal; // añadido manualmente por la empresa

  const Festivo({
    required this.fecha,
    required this.nombre,
    this.tipo = TipoFestivo.nacional,
    this.codigoComunidad,
    this.esLocal = false,
  });

  /// Clave normalizada del día (sin hora).
  DateTime get fechaNormalizada => DateTime(fecha.year, fecha.month, fecha.day);

  factory Festivo.fromMap(Map<String, dynamic> m) {
    return Festivo(
      fecha: _parseDate(m['fecha']),
      nombre: m['nombre'] as String? ?? '',
      tipo: _parseTipo(m['tipo'] as String?),
      codigoComunidad: m['codigo_comunidad'] as String?,
      esLocal: m['es_local'] as bool? ?? false,
    );
  }

  /// Desde la respuesta JSON de Nager.Date API.
  factory Festivo.fromNagerApi(Map<String, dynamic> json) {
    final dateStr = json['date'] as String? ?? '';
    final fecha = DateTime.tryParse(dateStr) ?? DateTime.now();
    final counties = json['counties'] as List<dynamic>?;
    final isNational = json['global'] == true || (counties == null || counties.isEmpty);

    return Festivo(
      fecha: fecha,
      nombre: json['localName'] as String? ?? json['name'] as String? ?? '',
      tipo: isNational ? TipoFestivo.nacional : TipoFestivo.autonomico,
      codigoComunidad: counties != null && counties.isNotEmpty
          ? counties.first.toString()
          : null,
      esLocal: false,
    );
  }

  Map<String, dynamic> toMap() => {
        'fecha': Timestamp.fromDate(fecha),
        'nombre': nombre,
        'tipo': tipo.name,
        'codigo_comunidad': codigoComunidad,
        'es_local': esLocal,
      };

  static DateTime _parseDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }

  static TipoFestivo _parseTipo(String? s) {
    switch (s) {
      case 'nacional':
        return TipoFestivo.nacional;
      case 'autonomico':
        return TipoFestivo.autonomico;
      case 'local':
        return TipoFestivo.local;
      default:
        return TipoFestivo.nacional;
    }
  }
}

/// Códigos de comunidades autónomas para la API Nager.Date.
class ComunidadesAutonomas {
  static const Map<String, String> codigos = {
    'ES-AN': 'Andalucía',
    'ES-AR': 'Aragón',
    'ES-AS': 'Asturias',
    'ES-IB': 'Islas Baleares',
    'ES-CN': 'Canarias',
    'ES-CB': 'Cantabria',
    'ES-CM': 'Castilla-La Mancha',
    'ES-CL': 'Castilla y León',
    'ES-CT': 'Cataluña',
    'ES-EX': 'Extremadura',
    'ES-GA': 'Galicia',
    'ES-MD': 'Madrid',
    'ES-MC': 'Murcia',
    'ES-NC': 'Navarra',
    'ES-PV': 'País Vasco',
    'ES-RI': 'La Rioja',
    'ES-VC': 'Comunidad Valenciana',
    'ES-CE': 'Ceuta',
    'ES-ML': 'Melilla',
  };

  static String nombre(String codigo) => codigos[codigo] ?? codigo;

  static List<MapEntry<String, String>> get lista =>
      codigos.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
}


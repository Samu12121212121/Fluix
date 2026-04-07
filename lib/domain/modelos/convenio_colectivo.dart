import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de datos para un Convenio Colectivo.
class Convenio {
  final String id;
  final String nombre;
  final String ambito;
  final String sector;
  final Map<String, String> vigencia;

  Convenio({
    required this.id,
    required this.nombre,
    required this.ambito,
    required this.sector,
    required this.vigencia,
  });

  factory Convenio.fromMap(Map<String, dynamic> map) {
    return Convenio(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      ambito: map['ambito'] ?? '',
      sector: map['sector'] ?? '',
      vigencia: Map<String, String>.from(map['vigencia'] ?? {}),
    );
  }
}

/// Modelo para una categoría profesional dentro de un convenio.
class CategoriaConvenio {
  final String id;
  final String nombre;
  final String grupoProfesional;
  final double salarioBaseMensual;
  final double salarioAnual;
  final int numPagas;

  CategoriaConvenio({
    required this.id,
    required this.nombre,
    required this.grupoProfesional,
    required this.salarioBaseMensual,
    required this.salarioAnual,
    required this.numPagas,
  });

    factory CategoriaConvenio.fromMap(Map<String, dynamic> map) {
    return CategoriaConvenio(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      grupoProfesional: map['grupo_profesional'] ?? '',
      salarioBaseMensual: (map['salario_base_mensual'] as num? ?? 0).toDouble(),
      salarioAnual: (map['salario_anual'] as num? ?? 0).toDouble(),
      numPagas: (map['num_pagas'] as num? ?? 0).toInt(),
    );
  }
}

/// Modelo para un plus o complemento salarial de un convenio.
class PlusConvenio {
  final String id;
  final String nombre;
  final String tipo; // 'fijo', 'porcentaje'
  final double importe;
  final String? baseCalculo; // 'salario_base', 'total_devengado'

  PlusConvenio({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.importe,
    this.baseCalculo,
  });

    factory PlusConvenio.fromMap(Map<String, dynamic> map) {
    return PlusConvenio(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      tipo: map['tipo'] ?? '',
      importe: (map['importe'] as num? ?? 0).toDouble(),
      baseCalculo: map['base_calculo'],
    );
  }
}


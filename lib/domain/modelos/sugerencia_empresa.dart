import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO — Sugerencia de mejora enviada por una empresa
//
// Estructura Firestore:
//   empresas/{empresaId}/sugerencias/{sugerenciaId}
//
// Relación:  1 sugerencia → 1 tarea (solo_propietario: true)
// ─────────────────────────────────────────────────────────────────────────────

enum EstadoSugerencia {
  /// Recién enviada, aún no revisada por el propietario de la plataforma.
  pendiente,

  /// El propietario de la plataforma ya la revisó.
  revisada,

  /// La mejora fue implementada en la app.
  implementada,
}

extension EstadoSugerenciaX on EstadoSugerencia {
  String get etiqueta {
    switch (this) {
      case EstadoSugerencia.pendiente:    return 'Pendiente de revisión';
      case EstadoSugerencia.revisada:     return 'Revisada';
      case EstadoSugerencia.implementada: return 'Implementada ✨';
    }
  }

  String get emoji {
    switch (this) {
      case EstadoSugerencia.pendiente:    return '⏳';
      case EstadoSugerencia.revisada:     return '👀';
      case EstadoSugerencia.implementada: return '✅';
    }
  }
}

class SugerenciaEmpresa {
  final String id;
  final String texto;
  final DateTime fechaCreacion;
  final EstadoSugerencia estado;
  final String autorUid;

  /// ID de la tarea que se creó automáticamente al guardar esta sugerencia.
  /// null sólo si la tarea falló al crearse (caso excepcional).
  final String? tareaId;

  const SugerenciaEmpresa({
    required this.id,
    required this.texto,
    required this.fechaCreacion,
    required this.estado,
    required this.autorUid,
    this.tareaId,
  });

  factory SugerenciaEmpresa.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SugerenciaEmpresa(
      id: doc.id,
      texto: data['texto'] as String? ?? '',
      fechaCreacion: _parseTs(data['fecha_creacion']),
      estado: EstadoSugerencia.values.firstWhere(
        (e) => e.name == (data['estado'] as String? ?? ''),
        orElse: () => EstadoSugerencia.pendiente,
      ),
      autorUid: data['autor_uid'] as String? ?? '',
      tareaId: data['tarea_id'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'texto':          texto,
    'fecha_creacion': Timestamp.fromDate(fechaCreacion),
    'estado':         estado.name,
    'autor_uid':      autorUid,
    'tarea_id':       tareaId,
  };

  SugerenciaEmpresa copyWith({String? tareaId, EstadoSugerencia? estado}) =>
      SugerenciaEmpresa(
        id:             id,
        texto:          texto,
        fechaCreacion:  fechaCreacion,
        estado:         estado ?? this.estado,
        autorUid:       autorUid,
        tareaId:        tareaId ?? this.tareaId,
      );
}

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}


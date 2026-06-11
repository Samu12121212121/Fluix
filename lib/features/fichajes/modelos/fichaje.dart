import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// MODELOS DE FICHAJE — Normativa Real Decreto 2026
//
// Arquitectura: UN documento por jornada laboral.
// Cada fichaje contiene: entrada, salida, y array de pausas.
// Las correcciones crean un NUEVO documento (inmutabilidad).
// ═══════════════════════════════════════════════════════════════════════════════

/// Estados posibles de un fichaje (calculados, no almacenados en Firestore)
enum EstadoFichaje {
  sinFichar,   // No ha fichado entrada hoy
  trabajando,  // Ha fichado entrada, sin pausa activa
  enPausa,     // Hay una pausa sin cerrar
  cerrado,     // Ha fichado salida — jornada inmutable
}

/// Tipos de horas según normativa española
enum TipoHoras {
  ordinarias,
  extraordinarias,
  complementarias,
}

// ─────────────────────────────────────────────────────────────────────────────
// Pausa
// ─────────────────────────────────────────────────────────────────────────────

class Pausa {
  final Timestamp inicio;
  final Timestamp? fin; // null = pausa activa

  const Pausa({required this.inicio, this.fin});

  bool get activa => fin == null;

  /// Duración de la pausa (null si sigue activa)
  Duration? get duracion {
    if (fin == null) return null;
    return fin!.toDate().difference(inicio.toDate());
  }

  factory Pausa.fromMap(Map<String, dynamic> map) {
    return Pausa(
      inicio: map['inicio'] as Timestamp,
      fin: map['fin'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
    'inicio': inicio,
    'fin': fin,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Fichaje
// ─────────────────────────────────────────────────────────────────────────────

/// Documento principal de fichaje.
/// Colección: empresas/{empresaId}/fichajes/{fichajeId}
class Fichaje {
  final String id;
  final String empleadoId;
  final String empleadoNombre;

  /// Formato "yyyy-MM-dd" — permite queries eficientes por día sin índice compuesto
  final String fecha;

  /// ServerTimestamp de entrada. Null si aún no ha entrado (no debería ocurrir)
  final Timestamp? entrada;

  /// ServerTimestamp de salida. Null = jornada abierta
  final Timestamp? salida;

  final List<Pausa> pausas;
  final TipoHoras tipoHoras;

  /// Identificador del dispositivo desde el que se fichó (tablet_cocina, etc.)
  final String dispositivoId;

  /// Timestamp de creación — NUNCA se modifica
  final Timestamp creadoAt;

  // ── Campos de inmutabilidad / audit trail ──────────────────────────────────
  final bool esCorreccion;
  final String? correccionDe;      // ID del fichaje original
  final String? motivoCorreccion;
  final String? corregidoPorUid;
  final Timestamp? corregidoAt;

  const Fichaje({
    required this.id,
    required this.empleadoId,
    required this.empleadoNombre,
    required this.fecha,
    this.entrada,
    this.salida,
    required this.pausas,
    required this.tipoHoras,
    required this.dispositivoId,
    required this.creadoAt,
    this.esCorreccion = false,
    this.correccionDe,
    this.motivoCorreccion,
    this.corregidoPorUid,
    this.corregidoAt,
  });

  // ── Estado calculado ───────────────────────────────────────────────────────

  EstadoFichaje get estado {
    if (salida != null) return EstadoFichaje.cerrado;
    if (pausas.isNotEmpty && pausas.last.activa) return EstadoFichaje.enPausa;
    if (entrada != null) return EstadoFichaje.trabajando;
    return EstadoFichaje.sinFichar;
  }

  bool get jornadadCerrada => estado == EstadoFichaje.cerrado;

  // ── Cálculo de horas ───────────────────────────────────────────────────────

  /// Minutos totales de pausa (solo pausas cerradas)
  int get minutosPausa => pausas
      .where((p) => p.fin != null)
      .fold(0, (sum, p) => sum + p.duracion!.inMinutes);

  /// Horas brutas (entrada → salida o ahora si sigue abierto)
  Duration? get tiempoBruto {
    if (entrada == null) return null;
    final fin = salida?.toDate() ?? DateTime.now();
    return fin.difference(entrada!.toDate());
  }

  /// Horas netas (brutas − pausas cerradas)
  Duration? get tiempoNeto {
    final bruto = tiempoBruto;
    if (bruto == null) return null;
    final neto = bruto.inMinutes - minutosPausa;
    return Duration(minutes: neto < 0 ? 0 : neto);
  }

  // ── Serialización ──────────────────────────────────────────────────────────

  factory Fichaje.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Fichaje(
      id: doc.id,
      empleadoId: data['empleado_id'] as String? ?? '',
      empleadoNombre: data['empleado_nombre'] as String? ?? '',
      fecha: data['fecha'] as String? ?? '',
      entrada: data['entrada'] as Timestamp?,
      salida: data['salida'] as Timestamp?,
      pausas: (data['pausas'] as List<dynamic>?)
          ?.map((p) => Pausa.fromMap(p as Map<String, dynamic>))
          .toList() ??
          [],
      tipoHoras: TipoHoras.values.firstWhere(
            (t) => t.name == (data['tipo_horas'] as String?),
        orElse: () => TipoHoras.ordinarias,
      ),
      dispositivoId: data['dispositivo_id'] as String? ?? '',
      // Null-safe: en modo offline el serverTimestamp llega momentáneamente como null
      creadoAt: data['creado_at'] as Timestamp? ?? Timestamp.now(),
      esCorreccion: data['es_correccion'] as bool? ?? false,
      correccionDe: data['correccion_de'] as String?,
      motivoCorreccion: data['motivo_correccion'] as String?,
      corregidoPorUid: data['corregido_por_uid'] as String?,
      corregidoAt: data['corregido_at'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empleado_id': empleadoId,
    'empleado_nombre': empleadoNombre,
    'fecha': fecha,
    'entrada': entrada,
    'salida': salida,
    'pausas': pausas.map((p) => p.toMap()).toList(),
    'tipo_horas': tipoHoras.name,
    'dispositivo_id': dispositivoId,
    'creado_at': creadoAt,
    'es_correccion': esCorreccion,
    'correccion_de': correccionDe,
    'motivo_correccion': motivoCorreccion,
    'corregido_por_uid': corregidoPorUid,
    'corregido_at': corregidoAt,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// EmpleadoFichaje
// ─────────────────────────────────────────────────────────────────────────────

/// Empleado habilitado para fichar con PIN.
/// Colección: empresas/{empresaId}/empleados_fichaje/{empleadoId}
class EmpleadoFichaje {
  final String uid;
  final String nombre;
  final String pin; // 4 dígitos
  final String empresaId;
  final bool activo;
  final int jornadaDiaria; // minutos por día, por defecto 480 (8h)

  const EmpleadoFichaje({
    required this.uid,
    required this.nombre,
    required this.pin,
    required this.empresaId,
    this.activo = true,
    this.jornadaDiaria = 480,
  });

  factory EmpleadoFichaje.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EmpleadoFichaje(
      uid: doc.id,
      nombre: data['nombre'] as String? ?? '',
      pin: data['pin'] as String? ?? '',
      empresaId: data['empresa_id'] as String? ?? '',
      activo: data['activo'] as bool? ?? true,
      jornadaDiaria: data['jornada_diaria'] as int? ?? 480,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'nombre': nombre,
    'pin': pin,
    'empresa_id': empresaId,
    'activo': activo,
    'jornada_diaria': jornadaDiaria,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ResumenDiaFichaje  (usado en dashboard y exportación)
// ─────────────────────────────────────────────────────────────────────────────

class ResumenDiaFichaje {
  final DateTime fecha;
  final String empleadoId;
  final String empleadoNombre;
  final DateTime? entrada;
  final DateTime? salida;
  final int minutosBrutos;
  final int minutosPausa;
  final int minutosNetos;
  final List<Pausa> pausas;
  final bool fichajePendiente; // entrada sin salida
  final bool tieneHorasExtra;  // neto > 480 min (8h)

  const ResumenDiaFichaje({
    required this.fecha,
    required this.empleadoId,
    required this.empleadoNombre,
    this.entrada,
    this.salida,
    this.minutosBrutos = 0,
    this.minutosPausa = 0,
    this.minutosNetos = 0,
    this.pausas = const [],
    this.fichajePendiente = false,
    this.tieneHorasExtra = false,
  });

  double get horasNetas => minutosNetos / 60.0;
  double get horasBrutas => minutosBrutos / 60.0;
  double get horasExtra => tieneHorasExtra ? (minutosNetos - 480) / 60.0 : 0.0;

  static ResumenDiaFichaje desdeFFichaje(Fichaje f) {
    final bruto = f.tiempoBruto?.inMinutes ?? 0;
    final pausa = f.minutosPausa;
    final neto = (bruto - pausa).clamp(0, double.maxFinite.toInt());
    return ResumenDiaFichaje(
      fecha: DateTime.parse(f.fecha),
      empleadoId: f.empleadoId,
      empleadoNombre: f.empleadoNombre,
      entrada: f.entrada?.toDate(),
      salida: f.salida?.toDate(),
      minutosBrutos: bruto,
      minutosPausa: pausa,
      minutosNetos: neto,
      pausas: f.pausas,
      fichajePendiente: f.estado == EstadoFichaje.trabajando ||
          f.estado == EstadoFichaje.enPausa,
      tieneHorasExtra: neto > 480,
    );
  }
}
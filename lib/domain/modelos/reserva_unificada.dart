import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════
// RESERVA UNIFICADA — document en empresas/{id}/reservas/{id}
// Fusiona los campos de citas/ (TPV peluquería) y reservas/ (B2C/web)
// ═══════════════════════════════════════════════════════════════════════════

class ReservaUnificada {
  final String id;

  // ── Identificación del cliente ─────────────────────────────────────────
  final String clienteNombre;
  final String? clienteTelefono;
  final String? clienteUid;      // solo reservas B2C
  final String? emailCliente;

  // ── Fecha / hora ───────────────────────────────────────────────────────
  /// "yyyy-MM-dd" — siempre presente
  final String fecha;
  /// "HH:mm" — siempre presente (derivado de hora_inicio o fecha_hora)
  final String horaInicio;
  final int duracionMinutos;

  // ── Servicio ───────────────────────────────────────────────────────────
  /// Nombre del primer servicio o del servicio único
  final String servicioNombre;
  final List<Map<String, dynamic>> servicios; // [{nombre, precio, ...}]

  // ── Estado y origen ────────────────────────────────────────────────────
  /// pendiente | confirmada | en_curso | completada | cancelada | no_asistio
  final String estado;
  /// tpv_peluqueria | app_cliente | web_publica | manual
  final String origen;

  // ── Profesional ────────────────────────────────────────────────────────
  /// ID del profesional/empleado asignado (campo unificado)
  final String? profId;

  // ── Precio ────────────────────────────────────────────────────────────
  final double precio;

  // ── Campos extras B2C ─────────────────────────────────────────────────
  final String? zona;
  final int? numPersonas;
  final List<String>? alergenos;
  final String? empresaIdVinculada;

  // ── Recordatorios ─────────────────────────────────────────────────────
  final bool recordatorioEnviado;
  final bool recordatorioClienteEnviado;

  // ── Walk-in ───────────────────────────────────────────────────────────
  final bool esWalkin;

  // ── Notas ─────────────────────────────────────────────────────────────
  final String? notas;

  // ── Metadata ──────────────────────────────────────────────────────────
  final DateTime? fechaCreacion;

  const ReservaUnificada({
    required this.id,
    required this.clienteNombre,
    this.clienteTelefono,
    this.clienteUid,
    this.emailCliente,
    required this.fecha,
    required this.horaInicio,
    required this.duracionMinutos,
    required this.servicioNombre,
    this.servicios = const [],
    this.estado = 'pendiente',
    this.origen = 'manual',
    this.profId,
    this.precio = 0.0,
    this.zona,
    this.numPersonas,
    this.alergenos,
    this.empresaIdVinculada,
    this.recordatorioEnviado = false,
    this.recordatorioClienteEnviado = false,
    this.esWalkin = false,
    this.notas,
    this.fechaCreacion,
  });

  // ── GETTERS de conveniencia ────────────────────────────────────────────

  DateTime get horaInicioDateTime {
    final parts = horaInicio.split(':');
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]));
  }

  DateTime get horaFinDateTime =>
      horaInicioDateTime.add(Duration(minutes: duracionMinutos));

  String get horaFinStr {
    final fin = horaFinDateTime;
    return '${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}';
  }

  double get importeTotal => servicios.fold(
      0.0, (sum, s) => sum + ((s['precio'] as num?)?.toDouble() ?? 0));

  // ── FACTORY: desde Firestore (con doble fallback cita/reserva) ─────────

  factory ReservaUnificada.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    // ── Servicios ──────────────────────────────────────────────────────
    final List<Map<String, dynamic>> serviciosList = [];
    if (data['servicios'] != null) {
      for (final s in data['servicios'] as List) {
        serviciosList.add(Map<String, dynamic>.from(s as Map));
      }
    }

    // ── Precio total ──────────────────────────────────────────────────
    final double importeServicios = serviciosList.fold(
        0.0, (sum, s) => sum + ((s['precio'] as num?)?.toDouble() ?? 0));
    final double precio = importeServicios > 0
        ? importeServicios
        : ((data['precio'] as num?)?.toDouble() ?? 0);

    // ── Nombre del servicio ───────────────────────────────────────────
    final String servicioNombre = data['servicio_nombre'] as String? ??
        (serviciosList.isNotEmpty
            ? (serviciosList.first['nombre'] as String? ?? 'Servicio')
            : (data['servicio'] as String? ?? data['servicio_nombre'] as String? ?? 'Servicio'));

    // ── Profesional ID (doble clave) ──────────────────────────────────
    final String? profId = data['prof_id'] as String? ??
        data['profesional_id'] as String?;

    // ── Hora inicio ───────────────────────────────────────────────────
    String horaStr = '09:00';
    if (data['hora_inicio'] is Timestamp) {
      final dt = (data['hora_inicio'] as Timestamp).toDate();
      horaStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (data['hora_inicio'] is String && (data['hora_inicio'] as String).isNotEmpty) {
      horaStr = data['hora_inicio'] as String;
    } else if (data['fecha_hora'] != null) {
      // Derivar hora de fecha_hora (Timestamp o ISO string)
      DateTime? dt;
      if (data['fecha_hora'] is Timestamp) {
        dt = (data['fecha_hora'] as Timestamp).toDate();
      } else if (data['fecha_hora'] is String) {
        dt = DateTime.tryParse(data['fecha_hora'] as String);
      }
      if (dt != null) {
        horaStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    // ── Fecha "yyyy-MM-dd" ─────────────────────────────────────────────
    String fechaStr = data['fecha'] as String? ?? '';
    if (fechaStr.isEmpty) {
      // Derivar de fecha_hora si falta el campo fecha
      DateTime? dt;
      if (data['fecha_hora'] is Timestamp) {
        dt = (data['fecha_hora'] as Timestamp).toDate();
      } else if (data['fecha_hora'] is String) {
        dt = DateTime.tryParse(data['fecha_hora'] as String);
      }
      if (dt != null) {
        fechaStr =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }
    }

    // ── Notas (acepta nota y notas) ───────────────────────────────────
    final String? notas = (data['notas'] as String?)?.isNotEmpty == true
        ? data['notas'] as String
        : data['nota'] as String?;

    // ── fechaCreacion ─────────────────────────────────────────────────
    DateTime? fechaCreacion;
    if (data['fecha_creacion'] is Timestamp) {
      fechaCreacion = (data['fecha_creacion'] as Timestamp).toDate();
    }

    return ReservaUnificada(
      id: doc.id,
      clienteNombre: data['cliente_nombre'] as String? ??
          data['nombre_cliente'] as String? ??
          'Cliente',
      clienteTelefono: data['cliente_telefono'] as String? ??
          data['telefono_cliente'] as String?,
      clienteUid: data['cliente_uid'] as String?,
      emailCliente: data['email_cliente'] as String? ??
          data['correo_cliente'] as String?,
      fecha: fechaStr,
      horaInicio: horaStr,
      duracionMinutos: (data['duracion_minutos'] as int?) ??
          (data['duracion'] as int?) ??
          30,
      servicioNombre: servicioNombre,
      servicios: serviciosList,
      estado: data['estado'] as String? ?? 'pendiente',
      origen: data['origen'] as String? ?? 'manual',
      profId: profId,
      precio: precio,
      zona: data['zona'] as String?,
      numPersonas: (data['num_personas'] as int?) ??
          (data['numero_personas'] as int?),
      alergenos: (data['alergenos'] as List?)?.cast<String>(),
      empresaIdVinculada: data['empresa_id_vinculada'] as String?,
      recordatorioEnviado: data['recordatorio_enviado'] as bool? ??
          data['recordatorioEnviado'] as bool? ??
          false,
      recordatorioClienteEnviado:
          data['recordatorio_cliente_enviado'] as bool? ?? false,
      esWalkin: data['es_walkin'] as bool? ?? false,
      notas: notas,
      fechaCreacion: fechaCreacion,
    );
  }

  // ── toFirestore: snake_case, campos unificados ─────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      'cliente_nombre': clienteNombre,
      if (clienteTelefono != null) 'cliente_telefono': clienteTelefono,
      if (clienteUid != null) 'cliente_uid': clienteUid,
      if (emailCliente != null) 'email_cliente': emailCliente,
      'fecha': fecha,
      'hora_inicio': horaInicio,
      'duracion_minutos': duracionMinutos,
      'servicio_nombre': servicioNombre,
      'servicios': servicios,
      'estado': estado,
      'origen': origen,
      // Guardar ambos aliases para compatibilidad con queries existentes
      if (profId != null) 'prof_id': profId,
      if (profId != null) 'profesional_id': profId,
      'precio': precio,
      if (zona != null) 'zona': zona,
      if (numPersonas != null) 'num_personas': numPersonas,
      if (alergenos != null) 'alergenos': alergenos,
      if (empresaIdVinculada != null)
        'empresa_id_vinculada': empresaIdVinculada,
      'recordatorio_enviado': recordatorioEnviado,
      'recordatorio_cliente_enviado': recordatorioClienteEnviado,
      'es_walkin': esWalkin,
      if (notas != null && notas!.isNotEmpty) 'notas': notas,
      'fecha_creacion': FieldValue.serverTimestamp(),
    };
  }

  // ── copyWith ───────────────────────────────────────────────────────────

  ReservaUnificada copyWith({
    String? clienteNombre,
    String? clienteTelefono,
    String? clienteUid,
    String? emailCliente,
    String? fecha,
    String? horaInicio,
    int? duracionMinutos,
    String? servicioNombre,
    List<Map<String, dynamic>>? servicios,
    String? estado,
    String? origen,
    String? profId,
    double? precio,
    String? zona,
    int? numPersonas,
    List<String>? alergenos,
    String? empresaIdVinculada,
    bool? recordatorioEnviado,
    bool? recordatorioClienteEnviado,
    bool? esWalkin,
    String? notas,
    DateTime? fechaCreacion,
  }) =>
      ReservaUnificada(
        id: id,
        clienteNombre: clienteNombre ?? this.clienteNombre,
        clienteTelefono: clienteTelefono ?? this.clienteTelefono,
        clienteUid: clienteUid ?? this.clienteUid,
        emailCliente: emailCliente ?? this.emailCliente,
        fecha: fecha ?? this.fecha,
        horaInicio: horaInicio ?? this.horaInicio,
        duracionMinutos: duracionMinutos ?? this.duracionMinutos,
        servicioNombre: servicioNombre ?? this.servicioNombre,
        servicios: servicios ?? this.servicios,
        estado: estado ?? this.estado,
        origen: origen ?? this.origen,
        profId: profId ?? this.profId,
        precio: precio ?? this.precio,
        zona: zona ?? this.zona,
        numPersonas: numPersonas ?? this.numPersonas,
        alergenos: alergenos ?? this.alergenos,
        empresaIdVinculada: empresaIdVinculada ?? this.empresaIdVinculada,
        recordatorioEnviado: recordatorioEnviado ?? this.recordatorioEnviado,
        recordatorioClienteEnviado:
            recordatorioClienteEnviado ?? this.recordatorioClienteEnviado,
        esWalkin: esWalkin ?? this.esWalkin,
        notas: notas ?? this.notas,
        fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      );
}


import 'package:cloud_firestore/cloud_firestore.dart';

// ── ENUMS ─────────────────────────────────────────────────────────────────────

enum CanalChat { whatsapp, web, app }
enum EstadoChat { activo, cerrado, esperando }
enum AutorMensaje { cliente, bot, agente }
enum IntentBot {
  reservarCita,
  cancelarReserva,
  consultarServicios,
  hacerPedido,
  consultarHorario,
  informacionNegocio,
  desconocido,
}

// ── RESPUESTA RÁPIDA ──────────────────────────────────────────────────────────

class BotRespuesta {
  final String id;
  final List<String> palabrasClave;
  final String respuesta;
  final IntentBot? intent;
  final bool activa;

  const BotRespuesta({
    required this.id,
    required this.palabrasClave,
    required this.respuesta,
    this.intent,
    this.activa = true,
  });

  factory BotRespuesta.fromMap(Map<String, dynamic> d) => BotRespuesta(
    id: d['id'] ?? '',
    palabrasClave: List<String>.from(d['palabras_clave'] ?? []),
    respuesta: d['respuesta'] ?? '',
    intent: d['intent'] != null
        ? IntentBot.values.firstWhere(
            (i) => i.name == d['intent'],
            orElse: () => IntentBot.desconocido)
        : null,
    activa: d['activa'] ?? true,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'palabras_clave': palabrasClave,
    'respuesta': respuesta,
    if (intent != null) 'intent': intent!.name,
    'activa': activa,
  };
}

// ── MENSAJE ───────────────────────────────────────────────────────────────────

class MensajeChat {
  final String id;
  final AutorMensaje autor;
  final String mensaje;
  final DateTime fecha;
  final IntentBot? intentDetectado;
  final bool accionEjecutada;

  const MensajeChat({
    required this.id,
    required this.autor,
    required this.mensaje,
    required this.fecha,
    this.intentDetectado,
    this.accionEjecutada = false,
  });

  factory MensajeChat.fromMap(Map<String, dynamic> d) => MensajeChat(
    id: d['id'] ?? '',
    autor: AutorMensaje.values.firstWhere(
        (a) => a.name == d['autor'], orElse: () => AutorMensaje.cliente),
    mensaje: d['mensaje'] ?? '',
    fecha: _parseTs(d['fecha']),
    intentDetectado: d['intent_detectado'] != null
        ? IntentBot.values.firstWhere(
            (i) => i.name == d['intent_detectado'],
            orElse: () => IntentBot.desconocido)
        : null,
    accionEjecutada: d['accion_ejecutada'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'autor': autor.name,
    'mensaje': mensaje,
    'fecha': Timestamp.fromDate(fecha),
    if (intentDetectado != null) 'intent_detectado': intentDetectado!.name,
    'accion_ejecutada': accionEjecutada,
  };
}

// ── CHAT ──────────────────────────────────────────────────────────────────────

class Chat {
  final String id;
  final String empresaId;
  final String clienteNombre;
  final String? telefono;
  final CanalChat canal;
  final EstadoChat estado;
  final DateTime fechaInicio;
  final DateTime? ultimoMensaje;
  final String? ultimoTexto;
  final int mensajesSinLeer;

  const Chat({
    required this.id,
    required this.empresaId,
    required this.clienteNombre,
    this.telefono,
    required this.canal,
    required this.estado,
    required this.fechaInicio,
    this.ultimoMensaje,
    this.ultimoTexto,
    this.mensajesSinLeer = 0,
  });

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Chat(
      id: doc.id,
      empresaId: d['empresa_id'] ?? '',
      clienteNombre: d['cliente_nombre'] ?? 'Cliente',
      telefono: d['telefono'],
      canal: CanalChat.values.firstWhere(
          (c) => c.name == d['canal'], orElse: () => CanalChat.whatsapp),
      estado: EstadoChat.values.firstWhere(
          (e) => e.name == d['estado'], orElse: () => EstadoChat.activo),
      fechaInicio: _parseTs(d['fecha_inicio']),
      ultimoMensaje: d['ultimo_mensaje'] != null ? _parseTs(d['ultimo_mensaje']) : null,
      ultimoTexto: d['ultimo_texto'],
      mensajesSinLeer: d['mensajes_sin_leer'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'empresa_id': empresaId,
    'cliente_nombre': clienteNombre,
    if (telefono != null) 'telefono': telefono,
    'canal': canal.name,
    'estado': estado.name,
    'fecha_inicio': Timestamp.fromDate(fechaInicio),
    if (ultimoMensaje != null) 'ultimo_mensaje': Timestamp.fromDate(ultimoMensaje!),
    if (ultimoTexto != null) 'ultimo_texto': ultimoTexto,
    'mensajes_sin_leer': mensajesSinLeer,
  };
}

// ── CONFIG BOT ────────────────────────────────────────────────────────────────

class ConfigBot {
  final bool activo;
  final String mensajeBienvenida;
  final String mensajeFallback;
  final String horarioTexto;
  final String telefonoContacto;
  final bool respuestaAutomatica;
  final List<String> menuPrincipal;

  const ConfigBot({
    this.activo = true,
    this.mensajeBienvenida = '¡Hola! Soy el asistente virtual. ¿En qué puedo ayudarte?',
    this.mensajeFallback = 'No he entendido tu mensaje. Un agente te atenderá pronto.',
    this.horarioTexto = 'Lunes a Viernes de 10:00 a 18:00',
    this.telefonoContacto = '',
    this.respuestaAutomatica = true,
    this.menuPrincipal = const [
      '1. Ver servicios',
      '2. Reservar cita',
      '3. Consultar horario',
      '4. Hablar con un agente',
    ],
  });

  factory ConfigBot.fromMap(Map<String, dynamic> d) => ConfigBot(
    activo: d['activo'] ?? true,
    mensajeBienvenida: d['mensaje_bienvenida'] ??
        '¡Hola! Soy el asistente virtual. ¿En qué puedo ayudarte?',
    mensajeFallback: d['mensaje_fallback'] ??
        'No he entendido tu mensaje. Un agente te atenderá pronto.',
    horarioTexto: d['horario_texto'] ?? 'Lunes a Viernes de 10:00 a 18:00',
    telefonoContacto: d['telefono_contacto'] ?? '',
    respuestaAutomatica: d['respuesta_automatica'] ?? true,
    menuPrincipal: List<String>.from(
        d['menu_principal'] ?? ['1. Ver servicios', '2. Reservar cita',
            '3. Consultar horario', '4. Hablar con un agente']),
  );

  Map<String, dynamic> toMap() => {
    'activo': activo,
    'mensaje_bienvenida': mensajeBienvenida,
    'mensaje_fallback': mensajeFallback,
    'horario_texto': horarioTexto,
    'telefono_contacto': telefonoContacto,
    'respuesta_automatica': respuestaAutomatica,
    'menu_principal': menuPrincipal,
  };

  ConfigBot copyWith({
    bool? activo,
    String? mensajeBienvenida,
    String? mensajeFallback,
    String? horarioTexto,
    String? telefonoContacto,
    bool? respuestaAutomatica,
    List<String>? menuPrincipal,
  }) => ConfigBot(
    activo: activo ?? this.activo,
    mensajeBienvenida: mensajeBienvenida ?? this.mensajeBienvenida,
    mensajeFallback: mensajeFallback ?? this.mensajeFallback,
    horarioTexto: horarioTexto ?? this.horarioTexto,
    telefonoContacto: telefonoContacto ?? this.telefonoContacto,
    respuestaAutomatica: respuestaAutomatica ?? this.respuestaAutomatica,
    menuPrincipal: menuPrincipal ?? this.menuPrincipal,
  );
}

DateTime _parseTs(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}


import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/bot_chat.dart';

/// Servicio del chatbot multiempresa.
/// Capa 1: palabras clave → respuesta directa
/// Capa 2: detección de intent → acción en Firestore
/// Capa 3: fallback con mensaje genérico
class ChatbotService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── REFS ──────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _chats(String e) =>
      _db.collection('empresas').doc(e).collection('chats');

  CollectionReference<Map<String, dynamic>> _mensajes(String e, String chatId) =>
      _chats(e).doc(chatId).collection('mensajes');

  CollectionReference<Map<String, dynamic>> _respuestas(String e) =>
      _db.collection('empresas').doc(e).collection('bot_respuestas');

  DocumentReference<Map<String, dynamic>> _configBot(String e) =>
      _db.collection('empresas').doc(e).collection('configuracion').doc('bot');

  // ═════════════════════════════════════════════════════════════════════════
  // CONFIG BOT
  // ═════════════════════════════════════════════════════════════════════════

  Stream<ConfigBot> configBotStream(String empresaId) =>
      _configBot(empresaId).snapshots().map((d) =>
          d.exists ? ConfigBot.fromMap(d.data()!) : const ConfigBot());

  Future<void> guardarConfigBot(String empresaId, ConfigBot config) =>
      _configBot(empresaId).set(config.toMap(), SetOptions(merge: true));

  // ═════════════════════════════════════════════════════════════════════════
  // RESPUESTAS RÁPIDAS
  // ═════════════════════════════════════════════════════════════════════════

  Stream<List<BotRespuesta>> respuestasStream(String empresaId) =>
      _respuestas(empresaId).snapshots().map((s) =>
          s.docs.map((d) => BotRespuesta.fromMap({...d.data(), 'id': d.id})).toList());

  Future<void> guardarRespuesta(String empresaId, BotRespuesta r) async {
    final ref = r.id.isEmpty ? _respuestas(empresaId).doc() : _respuestas(empresaId).doc(r.id);
    await ref.set({...r.toMap(), 'id': ref.id});
  }

  Future<void> eliminarRespuesta(String empresaId, String id) =>
      _respuestas(empresaId).doc(id).delete();

  // ═════════════════════════════════════════════════════════════════════════
  // CHATS
  // ═════════════════════════════════════════════════════════════════════════

  Stream<List<Chat>> chatsStream(String empresaId) =>
      _chats(empresaId)
          .snapshots()
          .map((s) {
            final lista = s.docs.map(Chat.fromFirestore).toList();
            lista.sort((a, b) {
              final ta = a.ultimoMensaje ?? a.fechaInicio;
              final tb = b.ultimoMensaje ?? b.fechaInicio;
              return tb.compareTo(ta);
            });
            return lista;
          });

  Stream<List<MensajeChat>> mensajesStream(String empresaId, String chatId) =>
      _mensajes(empresaId, chatId)
          .snapshots()
          .map((s) {
            final lista = s.docs
                .map((d) => MensajeChat.fromMap({...d.data(), 'id': d.id}))
                .toList();
            lista.sort((a, b) => a.fecha.compareTo(b.fecha));
            return lista;
          });

  /// Crea un nuevo chat desde WhatsApp
  Future<Chat> iniciarChat({
    required String empresaId,
    required String clienteNombre,
    String? telefono,
    CanalChat canal = CanalChat.whatsapp,
  }) async {
    final ref = _chats(empresaId).doc();
    final chat = Chat(
      id: ref.id,
      empresaId: empresaId,
      clienteNombre: clienteNombre,
      telefono: telefono,
      canal: canal,
      estado: EstadoChat.activo,
      fechaInicio: DateTime.now(),
    );
    await ref.set(chat.toFirestore());

    // Enviar bienvenida automática
    final config = await _configBot(empresaId).get();
    final cfg = config.exists ? ConfigBot.fromMap(config.data()!) : const ConfigBot();
    if (cfg.activo && cfg.respuestaAutomatica) {
      await _enviarMensajeBot(empresaId, ref.id, cfg.mensajeBienvenida);
      await _enviarMensajeBot(
          empresaId, ref.id, cfg.menuPrincipal.join('\n'));
    }

    return chat;
  }

  /// Marca mensajes sin leer como leídos
  Future<void> marcarLeido(String empresaId, String chatId) =>
      _chats(empresaId).doc(chatId).update({'mensajes_sin_leer': 0});

  Future<void> cerrarChat(String empresaId, String chatId) =>
      _chats(empresaId).doc(chatId).update({'estado': EstadoChat.cerrado.name});

  // ═════════════════════════════════════════════════════════════════════════
  // MOTOR DEL BOT — procesa mensaje del cliente
  // ═════════════════════════════════════════════════════════════════════════

  Future<String> procesarMensaje({
    required String empresaId,
    required String chatId,
    required String mensajeCliente,
    String clienteNombre = 'Cliente',
  }) async {
    final texto = mensajeCliente.toLowerCase().trim();

    // Guardar mensaje del cliente
    await _guardarMensaje(empresaId, chatId, AutorMensaje.cliente, mensajeCliente);

    // ── CAPA 1: Palabras clave ─────────────────────────────────────────────
    final respuesta = await _buscarPorPalabrasClave(empresaId, texto);
    if (respuesta != null) {
      await _enviarMensajeBot(empresaId, chatId, respuesta.respuesta,
          intent: respuesta.intent);
      return respuesta.respuesta;
    }

    // ── CAPA 2: Intent detection ───────────────────────────────────────────
    final intent = _detectarIntent(texto);
    final respuestaIntent = await _ejecutarIntent(
        empresaId, chatId, intent, clienteNombre, texto);
    if (respuestaIntent != null) {
      await _enviarMensajeBot(empresaId, chatId, respuestaIntent,
          intent: intent, accionEjecutada: true);
      return respuestaIntent;
    }

    // ── CAPA 3: Fallback ───────────────────────────────────────────────────
    final config = await _configBot(empresaId).get();
    final fallback = config.exists
        ? ConfigBot.fromMap(config.data()!).mensajeFallback
        : 'No he entendido tu mensaje. Un agente te atenderá pronto.';
    await _enviarMensajeBot(empresaId, chatId, fallback,
        intent: IntentBot.desconocido);
    return fallback;
  }

  // ── Guardar mensaje ────────────────────────────────────────────────────

  Future<void> _guardarMensaje(
    String empresaId,
    String chatId,
    AutorMensaje autor,
    String texto, {
    IntentBot? intent,
    bool accionEjecutada = false,
  }) async {
    final ref = _mensajes(empresaId, chatId).doc();
    final msg = MensajeChat(
      id: ref.id,
      autor: autor,
      mensaje: texto,
      fecha: DateTime.now(),
      intentDetectado: intent,
      accionEjecutada: accionEjecutada,
    );
    await ref.set(msg.toMap());

    // Actualizar último mensaje del chat
    await _chats(empresaId).doc(chatId).update({
      'ultimo_mensaje': Timestamp.fromDate(DateTime.now()),
      'ultimo_texto': texto.length > 60 ? '${texto.substring(0, 60)}...' : texto,
      if (autor == AutorMensaje.cliente)
        'mensajes_sin_leer': FieldValue.increment(1),
    });
  }

  Future<void> _enviarMensajeBot(
    String empresaId,
    String chatId,
    String texto, {
    IntentBot? intent,
    bool accionEjecutada = false,
  }) =>
      _guardarMensaje(empresaId, chatId, AutorMensaje.bot, texto,
          intent: intent, accionEjecutada: accionEjecutada);

  // ── Capa 1: búsqueda por palabras clave ────────────────────────────────

  Future<BotRespuesta?> _buscarPorPalabrasClave(
      String empresaId, String texto) async {
    final snap = await _respuestas(empresaId)
        .where('activa', isEqualTo: true)
        .get();

    for (final doc in snap.docs) {
      final r = BotRespuesta.fromMap({...doc.data(), 'id': doc.id});
      for (final clave in r.palabrasClave) {
        if (texto.contains(clave.toLowerCase())) return r;
      }
    }
    return null;
  }

  // ── Capa 2: detección de intent ─────────────────────────────────────────

  IntentBot _detectarIntent(String texto) {
    final patrones = <IntentBot, List<String>>{
      IntentBot.reservarCita: [
        'reserva', 'cita', 'reservar', 'agendar', 'pedir hora',
        'quiero una cita', 'hacer una reserva', 'turno',
      ],
      IntentBot.cancelarReserva: [
        'cancelar', 'anular', 'quitar cita', 'borrar reserva', 'cancelar cita',
      ],
      IntentBot.consultarServicios: [
        'servicio', 'que ofrecen', 'qué hacen', 'tratamiento',
        'precio', 'tarifas', 'cuánto cuesta', 'cuanto vale',
        'carta', 'menu', 'menú', 'productos',
      ],
      IntentBot.hacerPedido: [
        'pedir', 'pedido', 'quiero pedir', 'para llevar',
        'delivery', 'domicilio', 'encargar',
      ],
      IntentBot.consultarHorario: [
        'horario', 'hora', 'abren', 'cierran', 'abierto', 'cerrado',
        'cuando abren', 'a qué hora', 'dias',
      ],
      IntentBot.informacionNegocio: [
        'dirección', 'donde están', 'ubicación', 'como llegar',
        'teléfono', 'contacto', 'información',
      ],
    };

    for (final entry in patrones.entries) {
      for (final palabra in entry.value) {
        if (texto.contains(palabra)) return entry.key;
      }
    }
    return IntentBot.desconocido;
  }

  // ── Capa 2: ejecución de intent ─────────────────────────────────────────

  Future<String?> _ejecutarIntent(
    String empresaId,
    String chatId,
    IntentBot intent,
    String clienteNombre,
    String textoOriginal,
  ) async {
    switch (intent) {
      case IntentBot.consultarServicios:
        return await _respuestaServicios(empresaId);

      case IntentBot.consultarHorario:
        final config = await _configBot(empresaId).get();
        if (config.exists) {
          final cfg = ConfigBot.fromMap(config.data()!);
          return '⏰ Nuestro horario:\n${cfg.horarioTexto}';
        }
        return null;

      case IntentBot.reservarCita:
        return '📅 Para reservar una cita necesito algunos datos:\n\n'
            '1️⃣ ¿Qué servicio deseas?\n'
            '2️⃣ ¿Qué día prefieres?\n'
            '3️⃣ ¿A qué hora?\n\n'
            'Respóndeme con esos datos y creo la reserva ahora mismo 😊';

      case IntentBot.cancelarReserva:
        return '❌ Para cancelar tu reserva necesito:\n\n'
            '• Tu nombre completo\n'
            '• La fecha de la reserva\n\n'
            'Escríbeme esos datos y la cancelo de inmediato.';

      case IntentBot.hacerPedido:
        return await _respuestaPedido(empresaId);

      case IntentBot.informacionNegocio:
        return await _respuestaInfoNegocio(empresaId);

      case IntentBot.desconocido:
        return null;
    }
  }

  Future<String> _respuestaServicios(String empresaId) async {
    try {
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('servicios')
          .where('activo', isEqualTo: true)
          .limit(8)
          .get();

      if (snap.docs.isEmpty) {
        return 'Puedes consultarnos directamente por aquí o llamarnos para más información sobre nuestros servicios.';
      }

      final buf = StringBuffer('💆 Nuestros servicios:\n\n');
      for (final doc in snap.docs) {
        final d = doc.data();
        final nombre = d['nombre'] ?? '';
        final precio = (d['precio'] as num?)?.toStringAsFixed(2) ?? '';
        final duracion = d['duracion'] as int?;
        buf.write('• *$nombre*');
        if (precio.isNotEmpty) buf.write(' — ${precio}€');
        if (duracion != null) buf.write(' (${duracion} min)');
        buf.write('\n');
      }
      buf.write('\n¿Deseas reservar alguno de estos servicios?');
      return buf.toString();
    } catch (_) {
      return 'Tenemos varios servicios disponibles. ¿Sobre cuál quieres información?';
    }
  }

  Future<String> _respuestaPedido(String empresaId) async {
    try {
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('productos')
          .where('activo', isEqualTo: true)
          .limit(8)
          .get();

      if (snap.docs.isEmpty) {
        return '🛒 Para hacer un pedido, dinos qué quieres y te lo preparamos.\n'
            '¿Qué te apetece?';
      }

      final buf = StringBuffer('🛒 Lo que tenemos disponible:\n\n');
      for (final doc in snap.docs) {
        final d = doc.data();
        final nombre = d['nombre'] ?? '';
        final precio = (d['precio'] as num?)?.toStringAsFixed(2) ?? '';
        buf.write('• *$nombre*');
        if (precio.isNotEmpty) buf.write(' — ${precio}€');
        buf.write('\n');
      }
      buf.write('\n¿Qué quieres pedir? Dime el nombre y la cantidad 😊');
      return buf.toString();
    } catch (_) {
      return '🛒 ¡Claro! Dinos qué quieres pedir y la cantidad.';
    }
  }

  Future<String> _respuestaInfoNegocio(String empresaId) async {
    try {
      final snap = await _db
          .collection('empresas')
          .doc(empresaId)
          .collection('perfil')
          .doc('datos')
          .get();
      if (!snap.exists) return 'Puedes contactarnos por aquí mismo 😊';
      final d = snap.data()!;
      final buf = StringBuffer('ℹ️ Información:\n\n');
      if (d['nombre'] != null) buf.write('🏪 *${d['nombre']}*\n');
      if (d['direccion'] != null) buf.write('📍 ${d['direccion']}\n');
      if (d['telefono'] != null) buf.write('📞 ${d['telefono']}\n');
      if (d['correo'] != null) buf.write('✉️ ${d['correo']}\n');
      return buf.toString();
    } catch (_) {
      return 'Puedes contactarnos directamente por este chat 😊';
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // AGENTE PUEDE RESPONDER MANUALMENTE
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> responderComoAgente({
    required String empresaId,
    required String chatId,
    required String mensaje,
  }) =>
      _guardarMensaje(empresaId, chatId, AutorMensaje.agente, mensaje);

  // ═════════════════════════════════════════════════════════════════════════
  // DATOS DE PRUEBA
  // ═════════════════════════════════════════════════════════════════════════

  Future<void> inicializarBotPorDefecto(String empresaId) async {
    // Config por defecto
    final configSnap = await _configBot(empresaId).get();
    if (!configSnap.exists) {
      await guardarConfigBot(empresaId, const ConfigBot());
    }

    // Respuestas por defecto
    final respSnap = await _respuestas(empresaId).limit(1).get();
    if (respSnap.docs.isNotEmpty) return;

    final respuestasDefault = [
      BotRespuesta(
        id: '',
        palabrasClave: ['hola', 'buenas', 'buenos días', 'buenas tardes', 'hey'],
        respuesta: '¡Hola! 👋 Bienvenido/a. ¿En qué puedo ayudarte?\n\n'
            '1️⃣ Ver servicios\n'
            '2️⃣ Reservar cita\n'
            '3️⃣ Consultar horario\n'
            '4️⃣ Hacer un pedido',
        intent: null,
      ),
      BotRespuesta(
        id: '',
        palabrasClave: ['gracias', 'muchas gracias', 'perfecto', 'genial', 'ok'],
        respuesta: '¡De nada! 😊 Si necesitas algo más, aquí estoy.',
      ),
      BotRespuesta(
        id: '',
        palabrasClave: ['adios', 'adiós', 'hasta luego', 'bye', 'hasta pronto'],
        respuesta: '¡Hasta pronto! 👋 Ha sido un placer atenderte.',
      ),
      BotRespuesta(
        id: '',
        palabrasClave: ['humano', 'persona', 'agente', 'hablar con alguien'],
        respuesta: '🧑‍💼 Entendido, voy a avisar a un agente para que te atienda personalmente. En breve te contactamos.',
      ),
      BotRespuesta(
        id: '',
        palabrasClave: ['pago', 'formas de pago', 'tarjeta', 'efectivo', 'bizum'],
        respuesta: '💳 Aceptamos:\n• Tarjeta (Visa/MasterCard)\n• Efectivo\n• Bizum\n• Transferencia',
      ),
    ];

    for (final r in respuestasDefault) {
      await guardarRespuesta(empresaId, r);
    }

    // Crear chats de prueba
    await _crearChatsPrueba(empresaId);
  }

  Future<void> _crearChatsPrueba(String empresaId) async {
    final chatsSnap = await _chats(empresaId).limit(1).get();
    if (chatsSnap.docs.isNotEmpty) return;

    final conversaciones = [
      {
        'cliente': 'María García',
        'telefono': '+34 612 345 678',
        'mensajes': [
          {'autor': 'cliente', 'texto': 'Hola, buenas tardes'},
          {'autor': 'bot', 'texto': '¡Hola! 👋 Bienvenida. ¿En qué puedo ayudarte?\n\n1️⃣ Ver servicios\n2️⃣ Reservar cita\n3️⃣ Consultar horario'},
          {'autor': 'cliente', 'texto': 'Quería saber el horario'},
          {'autor': 'bot', 'texto': '⏰ Nuestro horario:\nLunes a Viernes de 10:00 a 18:00'},
          {'autor': 'cliente', 'texto': 'Perfecto, gracias'},
          {'autor': 'bot', 'texto': '¡De nada! 😊 Si necesitas algo más, aquí estoy.'},
        ],
      },
      {
        'cliente': 'Carlos Ruiz',
        'telefono': '+34 698 111 222',
        'mensajes': [
          {'autor': 'cliente', 'texto': 'Hola quiero reservar una cita'},
          {'autor': 'bot', 'texto': '📅 Para reservar una cita necesito algunos datos:\n\n1️⃣ ¿Qué servicio deseas?\n2️⃣ ¿Qué día prefieres?\n3️⃣ ¿A qué hora?'},
          {'autor': 'cliente', 'texto': 'Quiero corte de pelo, mañana a las 11'},
          {'autor': 'bot', 'texto': '✅ Perfecto, voy a comprobar disponibilidad para mañana a las 11:00. Un momento...'},
          {'autor': 'agente', 'texto': 'Hola Carlos, confirmamos tu cita para mañana a las 11:00. ¡Te esperamos!'},
        ],
      },
      {
        'cliente': 'Ana López',
        'telefono': '+34 655 999 000',
        'mensajes': [
          {'autor': 'cliente', 'texto': 'Buenos días, cuáles son vuestros servicios?'},
          {'autor': 'bot', 'texto': '💆 Nuestros servicios:\n\n• Corte de pelo — 28.00€\n• Coloración — 65.00€\n• Tratamiento capilar — 45.00€\n\n¿Deseas reservar alguno?'},
          {'autor': 'cliente', 'texto': 'Cuánto cuesta la coloración?'},
          {'autor': 'bot', 'texto': 'La coloración completa tiene un precio de 65€ e incluye tinte y mechas con productos de alta calidad. ¿Te gustaría reservar?'},
        ],
      },
    ];

    for (final conv in conversaciones) {
      final chatRef = _chats(empresaId).doc();
      final ahora = DateTime.now();
      final mensajes = conv['mensajes'] as List;

      await chatRef.set({
        'empresa_id': empresaId,
        'cliente_nombre': conv['cliente'],
        'telefono': conv['telefono'],
        'canal': CanalChat.whatsapp.name,
        'estado': EstadoChat.activo.name,
        'fecha_inicio': Timestamp.fromDate(ahora.subtract(const Duration(hours: 2))),
        'ultimo_mensaje': Timestamp.fromDate(ahora),
        'ultimo_texto': (mensajes.last as Map)['texto'].toString().length > 60
            ? '${(mensajes.last as Map)['texto'].toString().substring(0, 60)}...'
            : (mensajes.last as Map)['texto'],
        'mensajes_sin_leer': 1,
      });

      for (int i = 0; i < mensajes.length; i++) {
        final m = mensajes[i] as Map;
        final msgRef = _mensajes(empresaId, chatRef.id).doc();
        await msgRef.set({
          'id': msgRef.id,
          'autor': m['autor'],
          'mensaje': m['texto'],
          'fecha': Timestamp.fromDate(
              ahora.subtract(Duration(minutes: (mensajes.length - i) * 5))),
          'accion_ejecutada': false,
        });
      }
    }
  }
}



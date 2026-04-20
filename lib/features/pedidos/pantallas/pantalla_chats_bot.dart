import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../domain/modelos/bot_chat.dart';
import '../../../services/chatbot_service.dart';
import 'configurar_bot_whatsapp_screen.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL — lista de chats
// ═════════════════════════════════════════════════════════════════════════════

class PantallaChatsBot extends StatefulWidget {
  final String empresaId;
  const PantallaChatsBot({super.key, required this.empresaId});

  @override
  State<PantallaChatsBot> createState() => _PantallaChatsBotState();
}

class _PantallaChatsBotState extends State<PantallaChatsBot>
    with SingleTickerProviderStateMixin {
  final ChatbotService _svc = ChatbotService();
  late TabController _tabs;
  bool _inicializando = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Bot WhatsApp',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Inicializar bot con datos de prueba
          _inicializando
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)),
                )
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (v) async {
                    if (v == 'init') {
                      setState(() => _inicializando = true);
                      await _svc.inicializarBotPorDefecto(widget.empresaId);
                      if (mounted) setState(() => _inicializando = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Bot inicializado con datos de prueba'),
                            backgroundColor: Color(0xFF25D366),
                          ),
                        );
                      }
                    }
                    if (v == 'config') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PantallaConfigBot(
                              empresaId: widget.empresaId),
                        ),
                      );
                    }
                    if (v == 'whatsapp_api') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConfigurarBotWhatsAppScreen(
                              empresaId: widget.empresaId),
                        ),
                      );
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'init',
                      child: ListTile(
                        leading: Icon(Icons.science_outlined, color: Colors.green),
                        title: Text('Inicializar bot con datos de prueba'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'config',
                      child: ListTile(
                        leading: Icon(Icons.settings, color: Colors.blue),
                        title: Text('Configurar bot'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'whatsapp_api',
                      child: ListTile(
                        leading: Icon(Icons.api, color: Color(0xFF25D366)),
                        title: Text('WhatsApp API (Meta)'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '💬 Conversaciones'),
            Tab(text: '🤖 Respuestas Bot'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TabConversaciones(empresaId: widget.empresaId, svc: _svc),
          _TabRespuestasBot(empresaId: widget.empresaId, svc: _svc),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_nuevo_chat',
        onPressed: () => _nuevoChat(),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Nuevo chat'),
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _nuevoChat() async {
    final ctrl = TextEditingController();
    final tel  = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo chat WhatsApp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: ctrl,
                decoration: const InputDecoration(labelText: 'Nombre cliente')),
            const SizedBox(height: 12),
            TextField(controller: tel,
                decoration: const InputDecoration(labelText: 'Teléfono'),
                keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    final chat = await _svc.iniciarChat(
      empresaId: widget.empresaId,
      clienteNombre: ctrl.text.trim(),
      telefono: tel.text.trim().isEmpty ? null : tel.text.trim(),
    );
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PantallaDetalleChat(
            chat: chat, empresaId: widget.empresaId),
      ));
    }
  }
}

// ── Tab conversaciones ────────────────────────────────────────────────────────

class _TabConversaciones extends StatelessWidget {
  final String empresaId;
  final ChatbotService svc;
  const _TabConversaciones({required this.empresaId, required this.svc});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Chat>>(
      stream: svc.chatsStream(empresaId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final chats = snap.data ?? [];
        if (chats.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 72, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Sin conversaciones aún',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                const SizedBox(height: 8),
                Text('Pulsa el botón "+" para iniciar un chat de prueba',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: chats.length,
          itemBuilder: (_, i) => _tarjetaChat(context, chats[i]),
        );
      },
    );
  }

  Widget _tarjetaChat(BuildContext context, Chat chat) {
    final sinLeer = chat.mensajesSinLeer > 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: sinLeer ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: sinLeer
            ? const BorderSide(color: Color(0xFF25D366), width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
              child: Text(
                chat.clienteNombre.isNotEmpty
                    ? chat.clienteNombre[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Color(0xFF25D366), fontWeight: FontWeight.bold),
              ),
            ),
            if (sinLeer)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                      color: Color(0xFF25D366), shape: BoxShape.circle),
                  child: Center(
                    child: Text('${chat.mensajesSinLeer}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        ),
        title: Text(chat.clienteNombre,
            style: TextStyle(
                fontWeight: sinLeer ? FontWeight.bold : FontWeight.w600,
                fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chat.telefono != null)
              Text(chat.telefono!,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            if (chat.ultimoTexto != null)
              Text(chat.ultimoTexto!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      color: sinLeer ? Colors.black87 : Colors.grey[600])),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (chat.ultimoMensaje != null)
              Text(
                DateFormat('HH:mm').format(chat.ultimoMensaje!),
                style: TextStyle(
                    fontSize: 11,
                    color: sinLeer
                        ? const Color(0xFF25D366)
                        : Colors.grey[500]),
              ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: chat.estado == EstadoChat.activo
                    ? const Color(0xFF25D366).withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                chat.estado == EstadoChat.activo ? 'Activo' : 'Cerrado',
                style: TextStyle(
                    fontSize: 10,
                    color: chat.estado == EstadoChat.activo
                        ? const Color(0xFF25D366)
                        : Colors.grey),
              ),
            ),
          ],
        ),
        onTap: () {
          svc.marcarLeido(empresaId, chat.id);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) =>
                PantallaDetalleChat(chat: chat, empresaId: empresaId),
          ));
        },
      ),
    );
  }
}

// ── Tab respuestas bot ────────────────────────────────────────────────────────

class _TabRespuestasBot extends StatelessWidget {
  final String empresaId;
  final ChatbotService svc;
  const _TabRespuestasBot({required this.empresaId, required this.svc});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BotRespuesta>>(
      stream: svc.respuestasStream(empresaId),
      builder: (context, snap) {
        final respuestas = snap.data ?? [];
        return Stack(
          children: [
            respuestas.isEmpty
                ? Center(
                    child: Text('Sin respuestas configuradas',
                        style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    itemCount: respuestas.length,
                    itemBuilder: (_, i) =>
                        _tarjetaRespuesta(context, respuestas[i]),
                  ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'nueva_respuesta',
                onPressed: () => _editarRespuesta(context, null),
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tarjetaRespuesta(BuildContext context, BotRespuesta r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    children: r.palabrasClave
                        .map((c) => Chip(
                              label: Text(c,
                                  style: const TextStyle(fontSize: 11)),
                              padding: EdgeInsets.zero,
                              backgroundColor: const Color(0xFF25D366)
                                  .withValues(alpha: 0.1),
                              side: BorderSide.none,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: Colors.blue),
                  onPressed: () => _editarRespuesta(context, r),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.red),
                  onPressed: () => svc.eliminarRespuesta(empresaId, r.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(r.respuesta,
                  style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editarRespuesta(
      BuildContext context, BotRespuesta? existente) async {
    final clavesCtrl = TextEditingController(
        text: existente?.palabrasClave.join(', ') ?? '');
    final respCtrl =
        TextEditingController(text: existente?.respuesta ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existente == null
            ? 'Nueva respuesta automática'
            : 'Editar respuesta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: clavesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Palabras clave (separadas por comas)',
                  hintText: 'hola, buenos días, buenas',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: respCtrl,
                decoration: const InputDecoration(
                  labelText: 'Respuesta del bot',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final claves = clavesCtrl.text
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
    if (claves.isEmpty || respCtrl.text.trim().isEmpty) return;

    await svc.guardarRespuesta(
      empresaId,
      BotRespuesta(
        id: existente?.id ?? '',
        palabrasClave: claves,
        respuesta: respCtrl.text.trim(),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA DETALLE CHAT — conversación
// ═════════════════════════════════════════════════════════════════════════════

class PantallaDetalleChat extends StatefulWidget {
  final Chat chat;
  final String empresaId;
  const PantallaDetalleChat(
      {super.key, required this.chat, required this.empresaId});

  @override
  State<PantallaDetalleChat> createState() => _PantallaDetalleChatState();
}

class _PantallaDetalleChatState extends State<PantallaDetalleChat> {
  final ChatbotService _svc = ChatbotService();
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _enviando = false;
  bool _modoAgente = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD), // fondo tipo WhatsApp
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Text(
                widget.chat.clienteNombre.isNotEmpty
                    ? widget.chat.clienteNombre[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chat.clienteNombre,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                if (widget.chat.telefono != null)
                  Text(widget.chat.telefono!,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          // Toggle modo agente / bot
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Icon(
                  _modoAgente ? Icons.person : Icons.smart_toy_outlined,
                  color: Colors.white70,
                  size: 16,
                ),
                const SizedBox(width: 4),
                  Switch(
                  value: _modoAgente,
                  onChanged: (v) => setState(() => _modoAgente = v),
                  activeThumbColor: Colors.yellow,
                  inactiveTrackColor: Colors.white30,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner modo agente
          if (_modoAgente)
            Container(
              color: Colors.orange[100],
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Modo agente activo — tus mensajes no los procesa el bot',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),

          // Lista de mensajes
          Expanded(
            child: StreamBuilder<List<MensajeChat>>(
              stream: _svc.mensajesStream(widget.empresaId, widget.chat.id),
              builder: (context, snap) {
                final mensajes = snap.data ?? [];
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.animateTo(
                      _scroll.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: mensajes.length,
                  itemBuilder: (_, i) => _burbuja(mensajes[i]),
                );
              },
            ),
          ),

          // Input
          _buildInput(),
        ],
      ),
    );
  }

  Widget _burbuja(MensajeChat msg) {
    final esCliente = msg.autor == AutorMensaje.cliente;
    final esBot = msg.autor == AutorMensaje.bot;
    final esAgente = msg.autor == AutorMensaje.agente;

    final color = esCliente
        ? Colors.white
        : esBot
            ? const Color(0xFFDCF8C6)
            : const Color(0xFFE8D5FF);

    final alineacion =
        esCliente ? CrossAxisAlignment.start : CrossAxisAlignment.end;
    final mainAlineacion =
        esCliente ? MainAxisAlignment.start : MainAxisAlignment.end;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: mainAlineacion,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esCliente) const SizedBox(width: 40),
          Flexible(
            child: Column(
              crossAxisAlignment: alineacion,
              children: [
                if (esBot)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.smart_toy_outlined,
                            size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                        Text('Bot',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                if (esAgente)
                  Padding(
                    padding: const EdgeInsets.only(right: 4, bottom: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person, size: 12, color: Colors.purple),
                        const SizedBox(width: 4),
                        Text('Agente',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(12),
                      topRight: const Radius.circular(12),
                      bottomLeft: Radius.circular(esCliente ? 0 : 12),
                      bottomRight: Radius.circular(esCliente ? 12 : 0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(msg.mensaje,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('HH:mm').format(msg.fecha),
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (esCliente) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: _modoAgente
                      ? 'Responder como agente...'
                      : 'Simular mensaje del cliente...',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                maxLines: null,
                onSubmitted: (_) => _enviar(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _enviando ? null : _enviar,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                shape: BoxShape.circle,
              ),
              child: _enviando
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _enviar() async {
    final texto = _ctrl.text.trim();
    if (texto.isEmpty) return;
    _ctrl.clear();
    setState(() => _enviando = true);

    try {
      if (_modoAgente) {
        await _svc.responderComoAgente(
          empresaId: widget.empresaId,
          chatId: widget.chat.id,
          mensaje: texto,
        );
      } else {
        // Simula mensaje del cliente y respuesta del bot
        await _svc.procesarMensaje(
          empresaId: widget.empresaId,
          chatId: widget.chat.id,
          mensajeCliente: texto,
          clienteNombre: widget.chat.clienteNombre,
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA CONFIGURACIÓN BOT
// ═════════════════════════════════════════════════════════════════════════════

class PantallaConfigBot extends StatefulWidget {
  final String empresaId;
  const PantallaConfigBot({super.key, required this.empresaId});

  @override
  State<PantallaConfigBot> createState() => _PantallaConfigBotState();
}

class _PantallaConfigBotState extends State<PantallaConfigBot> {
  final ChatbotService _svc = ChatbotService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bienvenida;
  late TextEditingController _fallback;
  late TextEditingController _horario;
  late TextEditingController _telefono;
  bool _activo = true;
  bool _respuestaAuto = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _bienvenida = TextEditingController();
    _fallback   = TextEditingController();
    _horario    = TextEditingController();
    _telefono   = TextEditingController();
  }

  @override
  void dispose() {
    _bienvenida.dispose();
    _fallback.dispose();
    _horario.dispose();
    _telefono.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración del Bot'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<ConfigBot>(
        stream: _svc.configBotStream(widget.empresaId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final cfg = snap.data ?? const ConfigBot();

          // Rellenar controladores solo la primera vez
          if (_bienvenida.text.isEmpty) {
            _bienvenida.text = cfg.mensajeBienvenida;
            _fallback.text   = cfg.mensajeFallback;
            _horario.text    = cfg.horarioTexto;
            _telefono.text   = cfg.telefonoContacto;
            _activo          = cfg.activo;
            _respuestaAuto   = cfg.respuestaAutomatica;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Bot activo',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text(
                                'El bot responde automáticamente a los mensajes'),
                            value: _activo,
                            onChanged: (v) => setState(() => _activo = v),
                            activeThumbColor: const Color(0xFF25D366),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const Divider(),
                          SwitchListTile(
                            title: const Text('Respuesta automática'),
                            subtitle: const Text(
                                'Enviar bienvenida al iniciar un chat'),
                            value: _respuestaAuto,
                            onChanged: (v) =>
                                setState(() => _respuestaAuto = v),
                            activeThumbColor: const Color(0xFF25D366),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _seccion('Mensajes del bot'),
                  _campo(_bienvenida, 'Mensaje de bienvenida', maxLines: 3),
                  const SizedBox(height: 12),
                  _campo(_fallback, 'Mensaje cuando no entiende', maxLines: 2),
                  const SizedBox(height: 16),

                  _seccion('Información del negocio'),
                  _campo(_horario, 'Horario del negocio',
                      hint: 'Ej: Lunes a Viernes de 10:00 a 18:00'),
                  const SizedBox(height: 12),
                  _campo(_telefono, 'Teléfono de contacto',
                      hint: '+34 600 000 000',
                      tipo: TextInputType.phone),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: const Text('Guardar configuración'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _seccion(String titulo) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(titulo,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Color(0xFF075E54))),
  );

  Widget _campo(TextEditingController ctrl, String label,
      {String? hint, int maxLines = 1, TextInputType? tipo}) =>
      TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        maxLines: maxLines,
        keyboardType: tipo,
      );

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final config = ConfigBot(
      activo: _activo,
      mensajeBienvenida: _bienvenida.text.trim(),
      mensajeFallback: _fallback.text.trim(),
      horarioTexto: _horario.text.trim(),
      telefonoContacto: _telefono.text.trim(),
      respuestaAutomatica: _respuestaAuto,
    );
    await _svc.guardarConfigBot(widget.empresaId, config);
    if (mounted) {
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Configuración guardada'),
        backgroundColor: Color(0xFF25D366),
      ));
      Navigator.pop(context);
    }
  }
}




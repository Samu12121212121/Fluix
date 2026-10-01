import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/contacto_web_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB MENSAJES DE CONTACTO WEB
// Lista mensajes recibidos desde el formulario web + permite responder.
// La respuesta dispara onMensajeContactoRespondido (Cloud Function) que
// envía automáticamente un email al visitante con Resend.
// ═════════════════════════════════════════════════════════════════════════════

class TabMensajesContacto extends StatefulWidget {
  final String empresaId;
  final Color color;

  const TabMensajesContacto({
    super.key,
    required this.empresaId,
    required this.color,
  });

  @override
  State<TabMensajesContacto> createState() => _TabMensajesContactoState();
}

class _TabMensajesContactoState extends State<TabMensajesContacto> {
  String _filtro = 'contacto';
  String _busqueda = '';
  final _buscadorCtrl = TextEditingController();
  final _svc = ContactoWebService();

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MensajeContactoWeb>>(
      stream: _svc.obtenerMensajes(widget.empresaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final todos = snapshot.data ?? [];
        final contacto    = todos.where((m) => !m.esManuscrito).toList();
        final manuscritos = todos.where((m) => m.esManuscrito).toList();
        var lista = _filtro == 'manuscritos' ? manuscritos : contacto;
        // Filtro de búsqueda
        if (_busqueda.isNotEmpty) {
          final q = _busqueda.toLowerCase();
          lista = lista.where((m) =>
            m.nombre.toLowerCase().contains(q) ||
            m.email.toLowerCase().contains(q) ||
            m.asunto.toLowerCase().contains(q) ||
            m.mensaje.toLowerCase().contains(q)).toList();
        }
        final sinLeer = lista.where((m) => !m.leido).length;

        return Column(children: [
          _buildHeader(sinLeer, contacto.length, manuscritos.length),
          _buildBuscador(),
          if (lista.isEmpty)
            Expanded(child: _buildVacio())
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: lista.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) => _TarjetaMensaje(
                  mensaje: lista[i],
                  color: widget.color,
                  onTap: () => _abrirDetalle(context, lista[i]),
                  onMarcarUrgente: () => _toggleUrgente(lista[i]),
                ),
              ),
            ),
        ]);
      },
    );
  }

  Widget _buildBuscador() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: TextField(
        controller: _buscadorCtrl,
        style: const TextStyle(fontSize: 13),
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, email, asunto o mensaje…',
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF94A3B8)),
          suffixIcon: _busqueda.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 15),
                  onPressed: () { _buscadorCtrl.clear(); setState(() => _busqueda = ''); })
              : null,
          filled: true,
          fillColor: const Color(0xFFF8F9FB),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.color)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _toggleUrgente(MensajeContactoWeb msg) async {
    final esUrgente = (msg as dynamic).prioridad == 'urgente';
    await _svc.actualizarCampo(widget.empresaId, msg.id,
        'prioridad', esUrgente ? null : 'urgente');
  }

  Widget _buildHeader(int sinLeer, int nContacto, int nManus) {
    return Container(
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Sub-tabs
        Row(children: [
          _SubTab('Contacto', 'contacto', nContacto),
          _SubTab('Manuscritos', 'manuscritos', nManus),
          const Spacer(),
          if (sinLeer > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: () => _svc.marcarTodosComoLeidos(widget.empresaId),
                icon: Icon(Icons.done_all_rounded, size: 15, color: widget.color),
                label: Text('Marcar leídos', style: TextStyle(fontSize: 11, color: widget.color)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ]),
        Container(height: 1, color: const Color(0xFFE2E8F0)),
        if (sinLeer > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text('$sinLeer sin leer',
                style: TextStyle(fontSize: 11, color: widget.color, fontWeight: FontWeight.w600)),
          ),
      ]),
    );
  }

  Widget _SubTab(String label, String id, int count) {
    final activo = _filtro == id;
    return GestureDetector(
      onTap: () => setState(() => _filtro = id),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: activo ? widget.color : Colors.transparent,
            width: 2,
          )),
        ),
        child: Row(children: [
          Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: activo ? widget.color : const Color(0xFF64748B),
          )),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: activo ? widget.color : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: activo ? Colors.white : const Color(0xFF64748B),
              )),
            ),
          ],
        ]),
      ),
    );
  }

  void _abrirDetalle(BuildContext context, MensajeContactoWeb msg) {
    if (!msg.leido) _svc.marcarComoLeido(widget.empresaId, msg.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetDetalleMensaje(
        empresaId: widget.empresaId,
        mensaje: msg,
        color: widget.color,
      ),
    );
  }

  Widget _buildVacio() {
    final esManuscrito = _filtro == 'manuscritos';
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(
          esManuscrito ? Icons.description_outlined : Icons.mark_email_unread_outlined,
          size: 72, color: Colors.grey[300],
        ),
        const SizedBox(height: 16),
        Text(
          esManuscrito ? 'Sin manuscritos recibidos' : 'Sin mensajes de contacto',
          style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          esManuscrito
              ? 'Los envíos del formulario de manuscritos aparecerán aquí'
              : 'Los mensajes del formulario web aparecerán aquí',
          style: TextStyle(color: Colors.grey[500], fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA MENSAJE
// ─────────────────────────────────────────────────────────────────────────────

class _TarjetaMensaje extends StatelessWidget {
  final MensajeContactoWeb mensaje;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onMarcarUrgente;

  const _TarjetaMensaje({
    required this.mensaje,
    required this.color,
    required this.onTap,
    this.onMarcarUrgente,
  });

  @override
  Widget build(BuildContext context) {
    final noLeido = !mensaje.leido;
    final respondido = mensaje.respondido;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: noLeido
              ? color.withValues(alpha: 0.3)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: noLeido ? 0.05 : 0.02),
            blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 10),
              child: Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: noLeido ? color : const Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(mensaje.nombre,
                        style: TextStyle(
                            fontWeight: noLeido ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 13.5,
                            color: noLeido
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF334155))),
                  ),
                  Text(_formatFecha(mensaje.fechaCreacion),
                      style: const TextStyle(
                          fontSize: 10.5, color: Color(0xFF94A3B8))),
                ]),
                const SizedBox(height: 2),
                Text(mensaje.asunto,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: noLeido ? FontWeight.w600 : FontWeight.normal,
                        color: noLeido
                            ? const Color(0xFF1E293B)
                            : const Color(0xFF64748B))),
                const SizedBox(height: 2),
                Text(mensaje.mensaje,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF94A3B8))),
                const SizedBox(height: 5),
                Row(children: [
                  if (noLeido)
                    _statusBadge('Nuevo', color, color.withValues(alpha: 0.1)),
                  if (respondido)
                    _statusBadge('Respondido',
                        const Color(0xFF059669), const Color(0xFFD1FAE5)),
                  if (!respondido && mensaje.leido)
                    _statusBadge('Pendiente',
                        const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                  // Prioridad urgente
                  if ((mensaje as dynamic).prioridad == 'urgente')
                    _statusBadge('⚡ Urgente',
                        const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
                  const Spacer(),
                  // Botón urgente rápido
                  GestureDetector(
                    onTap: onMarcarUrgente,
                    child: Icon(
                      (mensaje as dynamic).prioridad == 'urgente'
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      size: 14,
                      color: (mensaje as dynamic).prioridad == 'urgente'
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _statusBadge(String label, Color textColor, Color bgColor) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: textColor, fontWeight: FontWeight.w700)),
    );
  }

  String _formatFecha(DateTime fecha) {
    final dif = DateTime.now().difference(fecha);
    if (dif.inMinutes < 60) return '${dif.inMinutes}min';
    if (dif.inHours < 24) return '${dif.inHours}h';
    if (dif.inDays < 7) return '${dif.inDays}d';
    return DateFormat('dd/MM').format(fecha);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET DETALLE + RESPUESTA
// ─────────────────────────────────────────────────────────────────────────────

class _SheetDetalleMensaje extends StatefulWidget {
  final String empresaId;
  final MensajeContactoWeb mensaje;
  final Color color;

  const _SheetDetalleMensaje({
    required this.empresaId,
    required this.mensaje,
    required this.color,
  });

  @override
  State<_SheetDetalleMensaje> createState() => _SheetDetalleMensajeState();
}

class _SheetDetalleMensajeState extends State<_SheetDetalleMensaje> {
  final _respCtrl = TextEditingController();
  bool _enviando = false;
  bool _respondido = false;

  @override
  void initState() {
    super.initState();
    _respondido = widget.mensaje.respondido;
    if (widget.mensaje.respuesta != null) {
      _respCtrl.text = widget.mensaje.respuesta!;
    }
  }

  @override
  void dispose() {
    _respCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarRespuesta() async {
    final texto = _respCtrl.text.trim();
    if (texto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe una respuesta')),
      );
      return;
    }
    setState(() => _enviando = true);
    try {
      await ContactoWebService().responderMensaje(
        widget.empresaId,
        widget.mensaje.id,
        texto,
      );
      if (!mounted) return;
      setState(() {
        _respondido = true;
        _enviando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Respuesta enviada a ${widget.mensaje.email}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _eliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar mensaje'),
        content: const Text('¿Seguro que quieres eliminar este mensaje?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ContactoWebService()
          .eliminarMensaje(widget.empresaId, widget.mensaje.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final msg = widget.mensaje;
    final c = widget.color;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.92,
          maxChildSize: 0.97,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      msg.asunto,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: _eliminar,
                    icon:
                        const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Eliminar',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                fmt.format(msg.fechaCreacion),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Badge tipo
              if (msg.esManuscrito)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B1E2A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF6B1E2A).withValues(alpha: 0.3)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.description_outlined, size: 13, color: Color(0xFF6B1E2A)),
                    SizedBox(width: 5),
                    Text('Manuscrito', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B1E2A))),
                  ]),
                ),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _FilaDato(Icons.person_outline, 'Nombre', msg.nombre),
                    const Divider(height: 16),
                    _FilaDato(Icons.email_outlined, 'Email', msg.email),
                    if (msg.telefono != null && msg.telefono!.isNotEmpty) ...[
                      const Divider(height: 16),
                      _FilaDato(Icons.phone_outlined, 'Teléfono', msg.telefono!),
                    ],
                    if (msg.tituloObra != null && msg.tituloObra!.isNotEmpty) ...[
                      const Divider(height: 16),
                      _FilaDato(Icons.book_outlined, 'Título de la obra', msg.tituloObra!),
                    ],
                    if (msg.genero != null && msg.genero!.isNotEmpty) ...[
                      const Divider(height: 16),
                      _FilaDato(Icons.category_outlined, 'Género', msg.genero!),
                    ],
                    if (msg.enlace != null && msg.enlace!.isNotEmpty) ...[
                      const Divider(height: 16),
                      _FilaDato(Icons.link_rounded, 'Enlace manuscrito', msg.enlace!),
                    ],
                    if (msg.archivoUrl != null && msg.archivoUrl!.isNotEmpty) ...[
                      const Divider(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Color(0xFF6B1E2A)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            msg.archivoNombre ?? 'Manuscrito adjunto',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          )),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse(msg.archivoUrl!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            icon: const Icon(Icons.download_rounded, size: 14),
                            label: const Text('Abrir', style: TextStyle(fontSize: 12)),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6B1E2A),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text('Mensaje',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  msg.mensaje,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Icon(Icons.reply, size: 16, color: c),
                  const SizedBox(width: 6),
                  Text(
                    _respondido ? 'Respuesta enviada' : 'Responder',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c),
                  ),
                  const Spacer(),
                  if (_respondido && msg.fechaRespuesta != null)
                    Text(
                      fmt.format(msg.fechaRespuesta!),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (!_respondido) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.withValues(alpha: 0.18)),
                  ),
                  child: Row(children: [
                    Icon(Icons.email_outlined, size: 14, color: c),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          children: [
                            const TextSpan(text: 'Se enviará un email a '),
                            TextSpan(
                              text: msg.email,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: c),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
              ],

              TextField(
                controller: _respCtrl,
                maxLines: 5,
                readOnly: _respondido,
                decoration: InputDecoration(
                  hintText: _respondido
                      ? 'Ya se respondió este mensaje'
                      : 'Escribe tu respuesta...',
                  filled: true,
                  fillColor: _respondido
                      ? Colors.green[50]
                      : const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: _respondido
                        ? const BorderSide(color: Colors.green, width: 1)
                        : BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: _respondido
                        ? const BorderSide(color: Colors.green, width: 1)
                        : BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (!_respondido)
                Column(children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _enviando ? null : _enviarRespuesta,
                      icon: _enviando
                          ? const SizedBox(height: 16, width: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.email_rounded, size: 18),
                      label: Text(_enviando ? 'Enviando...' : 'Enviar email de respuesta'),
                      style: FilledButton.styleFrom(
                        backgroundColor: c, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  // WhatsApp reply si hay teléfono
                  if (msg.telefono != null && msg.telefono!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final tel = msg.telefono!.replaceAll(RegExp(r'[^\d+]'), '');
                          final texto = Uri.encodeComponent(
                              'Hola ${msg.nombre}, gracias por tu mensaje. ');
                          final uri = Uri.parse('https://wa.me/$tel?text=$texto');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: Text('WhatsApp a ${msg.telefono}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF25D366),
                          side: const BorderSide(color: Color(0xFF25D366)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ])
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Respuesta enviada a ${msg.email}',
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _FilaDato extends StatelessWidget {
  final IconData icono;
  final String label;
  final String valor;

  const _FilaDato(this.icono, this.label, this.valor);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text('$label: ',
            style: const TextStyle(
                fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

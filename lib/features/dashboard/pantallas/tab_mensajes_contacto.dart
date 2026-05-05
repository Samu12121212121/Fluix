import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/contacto_web_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB MENSAJES DE CONTACTO WEB
// Lista mensajes recibidos desde el formulario web + permite responder.
// La respuesta dispara onMensajeContactoRespondido (Cloud Function) que
// envía automáticamente un email al visitante con Resend.
// ═════════════════════════════════════════════════════════════════════════════

class TabMensajesContacto extends StatelessWidget {
  final String empresaId;
  final Color color;

  const TabMensajesContacto({
    super.key,
    required this.empresaId,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final svc = ContactoWebService();
    return StreamBuilder<List<MensajeContactoWeb>>(
      stream: svc.obtenerMensajes(empresaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final mensajes = snapshot.data ?? [];
        if (mensajes.isEmpty) {
          return _buildVacio();
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          itemCount: mensajes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final msg = mensajes[i];
            return _TarjetaMensaje(
              mensaje: msg,
              color: color,
              onTap: () => _abrirDetalle(context, msg),
            );
          },
        );
      },
    );
  }

  void _abrirDetalle(BuildContext context, MensajeContactoWeb msg) {
    // Marcar como leído
    if (!msg.leido) {
      ContactoWebService().marcarComoLeido(empresaId, msg.id);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetDetalleMensaje(
        empresaId: empresaId,
        mensaje: msg,
        color: color,
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mark_email_unread_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Sin mensajes de contacto',
            style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Los mensajes del formulario web aparecerán aquí',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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

  const _TarjetaMensaje({
    required this.mensaje,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final noLeido = !mensaje.leido;
    final respondido = mensaje.respondido;

    return Card(
      elevation: noLeido ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: noLeido
            ? BorderSide(color: color.withValues(alpha: 0.5), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: noLeido
                      ? color.withValues(alpha: 0.12)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    mensaje.nombre.isNotEmpty
                        ? mensaje.nombre[0].toUpperCase()
                        : 'C',
                    style: TextStyle(
                      color: noLeido ? color : Colors.grey[500],
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mensaje.nombre,
                            style: TextStyle(
                              fontWeight: noLeido
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          _formatFecha(mensaje.fechaCreacion),
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mensaje.asunto,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: noLeido
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: noLeido ? Colors.black87 : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mensaje.mensaje,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (noLeido)
                          _Badge('NUEVO', color, color.withValues(alpha: 0.12)),
                        if (respondido)
                          _Badge('RESPONDIDO', Colors.green[700]!,
                              Colors.green[50]!),
                        if (!respondido && mensaje.leido)
                          _Badge('PENDIENTE', Colors.orange[700]!,
                              Colors.orange[50]!),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
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

Widget _Badge(String label, Color textColor, Color bgColor) {
  return Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(
          fontSize: 10, color: textColor, fontWeight: FontWeight.w700),
    ),
  );
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
              '✅ Respuesta enviada a ${widget.mensaje.email}'),
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
              // Handle
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

              // Cabecera
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

              // Datos del remitente
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
                    if (msg.telefono != null &&
                        msg.telefono!.isNotEmpty) ...[
                      const Divider(height: 16),
                      _FilaDato(
                          Icons.phone_outlined, 'Teléfono', msg.telefono!),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mensaje original
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

              // Sección respuesta
              Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Color(0xFF00796B)),
                  const SizedBox(width: 6),
                  Text(
                    _respondido ? 'Respuesta enviada' : 'Responder',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00796B)),
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
              const SizedBox(height: 8),

              // Campo de respuesta
              TextField(
                controller: _respCtrl,
                maxLines: 5,
                readOnly: _respondido,
                decoration: InputDecoration(
                  hintText: _respondido
                      ? 'Ya se respondió este mensaje'
                      : 'Escribe tu respuesta... Se enviará por email a ${msg.email}',
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _enviando ? null : _enviarRespuesta,
                    icon: _enviando
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: Text(_enviando
                        ? 'Enviando...'
                        : 'Enviar respuesta por email'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                )
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


import 'package:flutter/material.dart';
import '../../../services/contacto_web_service.dart';

class PantallaMensajesContacto extends StatefulWidget {
  final String empresaId;

  const PantallaMensajesContacto({super.key, required this.empresaId});

  @override
  State<PantallaMensajesContacto> createState() => _PantallaMensajesContactoState();
}

class _PantallaMensajesContactoState extends State<PantallaMensajesContacto> {
  final ContactoWebService _service = ContactoWebService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mensajes de Contacto Web'),
        backgroundColor: const Color(0xFF1976D2),
      ),
      body: StreamBuilder<List<MensajeContactoWeb>>(
        stream: _service.obtenerMensajes(widget.empresaId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay mensajes', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final mensajes = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mensajes.length,
            itemBuilder: (context, index) {
              final mensaje = mensajes[index];
              return _buildMensajeCard(mensaje);
            },
          );
        },
      ),
    );
  }

  Widget _buildMensajeCard(MensajeContactoWeb mensaje) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: mensaje.leido ? 0 : 2,
      color: mensaje.leido ? Colors.white : const Color(0xFFF3F9FF),
      child: InkWell(
        onTap: () => _mostrarDetalles(mensaje),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!mensaje.leido)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1976D2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (!mensaje.leido) const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mensaje.asunto,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: mensaje.leido ? FontWeight.w500 : FontWeight.w700,
                      ),
                    ),
                  ),
                  if (mensaje.respondido)
                    const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                mensaje.nombre,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              Text(
                mensaje.email,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                mensaje.mensaje,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    _formatearFecha(mensaje.fechaCreacion),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      mensaje.origen.toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: Color(0xFF1976D2), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarDetalles(MensajeContactoWeb mensaje) {
    // Marcar como leído
    if (!mensaje.leido) {
      _service.marcarComoLeido(widget.empresaId, mensaje.id);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1976D2),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mail, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      mensaje.asunto,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildInfoRow(Icons.person, 'Nombre', mensaje.nombre),
                  _buildInfoRow(Icons.email, 'Email', mensaje.email),
                  if (mensaje.telefono != null)
                    _buildInfoRow(Icons.phone, 'Teléfono', mensaje.telefono!),
                  _buildInfoRow(Icons.access_time, 'Fecha', _formatearFecha(mensaje.fechaCreacion)),
                  const Divider(height: 32),
                  const Text('Mensaje:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(mensaje.mensaje, style: const TextStyle(fontSize: 14, height: 1.5)),
                  if (mensaje.respondido) ...[
                    const Divider(height: 32),
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                        const SizedBox(width: 8),
                        const Text('Respuesta enviada:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(mensaje.respuesta!, style: const TextStyle(fontSize: 14, height: 1.5)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enviada: ${_formatearFecha(mensaje.fechaRespuesta!)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!mensaje.respondido)
                    ElevatedButton.icon(
                      onPressed: () => _mostrarDialogoRespuesta(mensaje),
                      icon: const Icon(Icons.reply),
                      label: const Text('Responder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _eliminarMensaje(mensaje),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Eliminar mensaje', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1976D2)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoRespuesta(MensajeContactoWeb mensaje) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Responder mensaje'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Para: ${mensaje.nombre} (${mensaje.email})'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Escribe tu respuesta aquí...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await _service.responderMensaje(widget.empresaId, mensaje.id, controller.text.trim());
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✓ Respuesta enviada (deberías enviarla por email)')),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void _eliminarMensaje(MensajeContactoWeb mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar mensaje'),
        content: const Text('¿Estás seguro de que quieres eliminar este mensaje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await _service.eliminarMensaje(widget.empresaId, mensaje.id);
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✓ Mensaje eliminado')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inMinutes < 1) return 'Ahora';
    if (diferencia.inMinutes < 60) return 'Hace ${diferencia.inMinutes}min';
    if (diferencia.inHours < 24) return 'Hace ${diferencia.inHours}h';
    if (diferencia.inDays < 7) return 'Hace ${diferencia.inDays}d';

    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }
}


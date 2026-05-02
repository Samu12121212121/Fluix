import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB MENSAJES CONTACTO — Bandeja de mensajes del formulario web
// ═════════════════════════════════════════════════════════════════════════════

class TabMensajesContacto extends StatelessWidget {
  final String empresaId;
  const TabMensajesContacto({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('contacto_web')
          .orderBy('fecha_creacion', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mail_outline, size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Sin mensajes todavía',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text(
                    'Cuando alguien envíe un mensaje desde el formulario de contacto de tu web, aparecerá aquí.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final leido = data['leido'] as bool? ?? false;
            return _TarjetaMensaje(
              docId: docs[i].id,
              empresaId: empresaId,
              data: data,
              leido: leido,
            );
          },
        );
      },
    );
  }
}

class _TarjetaMensaje extends StatelessWidget {
  final String docId;
  final String empresaId;
  final Map<String, dynamic> data;
  final bool leido;

  const _TarjetaMensaje({
    required this.docId,
    required this.empresaId,
    required this.data,
    required this.leido,
  });

  String _formatFecha(dynamic raw) {
    if (raw == null) return '';
    DateTime? dt;
    if (raw is Timestamp) dt = raw.toDate();
    if (raw is String) dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy HH:mm', 'es').format(dt);
  }

  Future<void> _marcarLeido() async {
    if (leido) return;
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('contacto_web')
        .doc(docId)
        .update({'leido': true});
  }

  @override
  Widget build(BuildContext context) {
    final nombre = data['nombre'] as String? ?? 'Sin nombre';
    final email = data['email'] as String? ?? '';
    final mensaje = data['mensaje'] as String? ?? '';
    final telefono = data['telefono'] as String? ?? '';
    final fecha = _formatFecha(data['fecha_creacion'] ?? data['fecha']);

    return GestureDetector(
      onTap: () {
        _marcarLeido();
        _abrirDetalle(context, nombre, email, telefono, mensaje, fecha);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: leido ? null : Border.all(color: const Color(0xFF1976D2).withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: leido
                    ? Colors.grey[100]
                    : const Color(0xFF1976D2).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: leido ? Colors.grey[500] : const Color(0xFF1976D2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(nombre,
                          style: TextStyle(
                            fontWeight: leido ? FontWeight.w500 : FontWeight.bold,
                            fontSize: 14,
                          )),
                    ),
                    if (!leido)
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1976D2),
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 4),
                    Text(fecha, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                  ]),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(children: [
                      const Icon(Icons.email_outlined, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ]),
                  ],
                  const SizedBox(height: 4),
                  Text(mensaje,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: leido ? Colors.grey[500] : Colors.grey[700],
                        fontSize: 13,
                        height: 1.4,
                      )),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Icono responder
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  void _abrirDetalle(BuildContext context, String nombre, String email,
      String telefono, String mensaje, String fecha) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleMensajeSheet(
        docId: docId,
        empresaId: empresaId,
        nombre: nombre,
        email: email,
        telefono: telefono,
        mensaje: mensaje,
        fecha: fecha,
        data: data,
      ),
    );
  }
}

class _DetalleMensajeSheet extends StatelessWidget {
  final String docId;
  final String empresaId;
  final String nombre;
  final String email;
  final String telefono;
  final String mensaje;
  final String fecha;
  final Map<String, dynamic> data;

  const _DetalleMensajeSheet({
    required this.docId,
    required this.empresaId,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.mensaje,
    required this.fecha,
    required this.data,
  });

  Future<void> _responderEmail() async {
    if (email.isEmpty) return;
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Respuesta a tu mensaje',
        'body': 'Hola $nombre,\n\n',
      },
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _eliminar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Eliminar mensaje'),
        content: const Text('¿Eliminar este mensaje permanentemente?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('contacto_web')
        .doc(docId)
        .delete();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20,
          20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cabecera
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Color(0xFF1976D2)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    if (fecha.isNotEmpty)
                      Text(fecha,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Eliminar',
                onPressed: () => _eliminar(context),
              ),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Info de contacto
            if (email.isNotEmpty) ...[
              _infoFila(Icons.email_outlined, 'Email', email),
              const SizedBox(height: 8),
            ],
            if (telefono.isNotEmpty) ...[
              _infoFila(Icons.phone_outlined, 'Teléfono', telefono),
              const SizedBox(height: 8),
            ],

            // Mensaje
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mensaje',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.grey)),
                  const SizedBox(height: 6),
                  Text(mensaje,
                      style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Botón responder
            if (email.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _responderEmail,
                  icon: const Icon(Icons.reply),
                  label: const Text('Responder por email'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoFila(IconData icono, String label, String valor) {
    return Row(children: [
      Icon(icono, size: 16, color: Colors.grey[600]),
      const SizedBox(width: 8),
      Text('$label: ',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      Expanded(
        child: Text(valor,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}




import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:convert';

// Colores del dark theme TPV
const _kBg = Color(0xFF0A0F23);
const _kCard = Color(0xFF1E2139);
const _kVerde = Color(0xFF00FFC8);
const _kSecondary = Color(0xFFB0B3C1);

class HistorialTicketsWidget extends StatelessWidget {
  final String empresaId;
  final int maxItems;

  const HistorialTicketsWidget({
    super.key,
    required this.empresaId,
    this.maxItems = 20,
  });

  static Future<void> mostrar(BuildContext context, String empresaId) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => HistorialTicketsWidget(empresaId: empresaId),
    );
  }

  Stream<QuerySnapshot> _pedidosHoy() {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    return FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos')
        .where('fecha_creacion', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .orderBy('fecha_creacion', descending: true)
        .limit(maxItems)
        .snapshots();
  }

  Future<String> _nombreEmpresa() async {
    final doc = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .get();
    return (doc.data()?['nombre'] as String?) ?? 'Empresa';
  }

  Future<void> _reimprimir(BuildContext context, Map<String, dynamic> data) async {
    final nombre = await _nombreEmpresa();
    final doc = pw.Document();
    final lineas = (data['lineas'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final ticket = data['numero_ticket'] ?? '';
    final metodoPago = data['metodo_pago'] ?? '';
    final fecha = data['fecha_creacion'] is Timestamp
        ? (data['fecha_creacion'] as Timestamp).toDate()
        : DateTime.now();
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(nombre,
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('TICKET #$ticket')),
            pw.Center(child: pw.Text(fmt.format(fecha))),
            pw.Divider(),
            ...lineas.map((l) {
              final pNombre = l['producto_nombre'] ?? '';
              final qty = l['cantidad'] ?? 1;
              final precio = (l['precio_unitario'] as num?)?.toDouble() ?? 0.0;
              return pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('$qty x $pNombre',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('${(precio * qty).toStringAsFixed(2)} €',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              );
            }),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('${total.toStringAsFixed(2)} €',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text('Pago: $metodoPago',
                style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 8),
            pw.Center(child: pw.Text('¡Gracias por su compra!',
                style: const pw.TextStyle(fontSize: 10))),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'Ticket_$ticket.pdf',
    );
  }

  void _verDetalle(BuildContext context, Map<String, dynamic> data) {
    final lineas = (data['lineas'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Ticket #${data['numero_ticket'] ?? ''}',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: lineas.map((l) {
              final qty = l['cantidad'] ?? 1;
              final nombre = l['producto_nombre'] ?? '';
              final precio = (l['precio_unitario'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('$qty x $nombre',
                          style:
                              const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    Text('${(precio * qty).toStringAsFixed(2)} €',
                        style: const TextStyle(color: _kVerde, fontSize: 13)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: _kVerde)),
          ),
        ],
      ),
    );
  }

  Future<void> _reenviarEmail(BuildContext context, Map<String, dynamic> data) async {
    String? email = data['cliente_email'] as String? ?? data['email_cliente'] as String?;

    // Si no hay email, pedir uno al usuario
    if (email == null || email.isEmpty) {
      final ctrl = TextEditingController();
      final introducido = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.email_outlined, color: _kVerde, size: 20),
            SizedBox(width: 8),
            Text('Enviar ticket por email', style: TextStyle(fontSize: 16)),
          ]),
          content: SizedBox(
            width: 300,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Este ticket no tiene email registrado.\nIntroduce una dirección para enviarlo.',
                  style: TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.alternate_email, size: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final e = ctrl.text.trim();
                if (e.contains('@') && e.contains('.')) {
                  Navigator.pop(ctx, e);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: _kVerde, foregroundColor: _kBg),
              child: const Text('Enviar'),
            ),
          ],
        ),
      );
      if (introducido == null || !context.mounted) return;
      email = introducido;
    }

    // Construir PDF y enviar
    final nombre = await _nombreEmpresa();
    final ticket = data['numero_ticket'] ?? '';
    final lineas = (data['lineas'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final total  = (data['total'] as num?)?.toDouble() ?? 0.0;
    final metodo = data['metodo_pago'] ?? '';
    final fmtFecha = DateFormat('dd/MM/yyyy HH:mm');
    final fecha = data['fecha_creacion'] is Timestamp
        ? (data['fecha_creacion'] as Timestamp).toDate() : DateTime.now();

    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.roll80,
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Center(child: pw.Text(nombre, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('TICKET #$ticket')),
        pw.Center(child: pw.Text(fmtFecha.format(fecha))),
        pw.Divider(),
        ...lineas.map((l) {
          final qty   = (l['cantidad'] as num?)?.toDouble() ?? 1;
          final nom   = l['producto_nombre'] ?? '';
          final precio = (l['precio_unitario'] as num?)?.toDouble() ?? 0.0;
          return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('${qty.toInt()} × $nom', style: const pw.TextStyle(fontSize: 10)),
            pw.Text('${(precio * qty).toStringAsFixed(2)} €', style: const pw.TextStyle(fontSize: 10)),
          ]);
        }),
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text('${total.toStringAsFixed(2)} €', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ]),
        pw.SizedBox(height: 4),
        pw.Text('Pago: $metodo', style: const pw.TextStyle(fontSize: 10)),
      ]),
    ));

    try {
      final pdfBytes = await doc.save();
      final pdfBase64 = base64Encode(pdfBytes);
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final resp = await http.post(
        Uri.parse('https://europe-west1-planeaapp-4bea4.cloudfunctions.net/enviarEmailConPdf'),
        headers: {
          'Content-Type': 'application/json',
          if (idToken != null) 'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'data': {
          'destinatario': email,
          'asunto': '🧾 Tu ticket #$ticket — $nombre',
          'cuerpoHtml': _buildHtmlTicket(
            empresaNombre: nombre,
            ticket: '$ticket',
            fecha: fmtFecha.format(fecha),
            lineas: lineas,
            total: total,
            metodo: metodo,
          ),
          'pdfBase64': pdfBase64,
          'nombreArchivo': 'ticket_$ticket.pdf',
          'empresaId': empresaId,
        }}),
      );
      if (resp.statusCode >= 400) throw Exception('HTTP ${resp.statusCode}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Ticket enviado a $email'),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error enviando email: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  /// Template HTML profesional para el email del ticket.
  static String _buildHtmlTicket({
    required String empresaNombre,
    required String ticket,
    required String fecha,
    required List<Map<String, dynamic>> lineas,
    required double total,
    required String metodo,
  }) {
    final lineasHtml = lineas.map((l) {
      final qty    = (l['cantidad'] as num?)?.toDouble() ?? 1;
      final nom    = l['producto_nombre'] ?? '';
      final precio = (l['precio_unitario'] as num?)?.toDouble() ?? 0.0;
      final subtotal = (precio * qty).toStringAsFixed(2);
      return '<tr>'
          '<td style="padding:7px 0;color:#374151;border-bottom:1px solid #f3f4f6;">'
          '${qty.toInt()} × $nom</td>'
          '<td style="padding:7px 0;color:#374151;border-bottom:1px solid #f3f4f6;'
          'text-align:right;">$subtotal&nbsp;€</td>'
          '</tr>';
    }).join('');

    return '''<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
</head>
<body style="margin:0;padding:20px;background:#f5f5f5;font-family:-apple-system,Helvetica,Arial,sans-serif;">
  <div style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.10);">
    <!-- Header -->
    <div style="background:#111827;padding:28px 24px;text-align:center;">
      <p style="margin:0;font-size:22px;font-weight:800;color:#ffffff;letter-spacing:-0.5px;">$empresaNombre</p>
      <p style="margin:6px 0 0;font-size:13px;color:rgba(255,255,255,.55);">Comprobante de compra</p>
    </div>
    <!-- Badge ticket -->
    <div style="padding:20px 24px 0;">
      <div style="background:#eff6ff;border:1px solid #bfdbfe;border-radius:8px;padding:10px 14px;display:inline-block;">
        <span style="font-size:13px;font-weight:700;color:#1d4ed8;">Ticket&nbsp;#$ticket</span>
        <span style="font-size:12px;color:#3b82f6;margin-left:10px;">$fecha</span>
      </div>
    </div>
    <!-- Líneas -->
    <div style="padding:16px 24px;">
      <table style="width:100%;border-collapse:collapse;">
        $lineasHtml
        <!-- Total -->
        <tr>
          <td style="padding:12px 0 4px;font-weight:800;font-size:16px;color:#111827;border-top:2px solid #e5e7eb;">TOTAL</td>
          <td style="padding:12px 0 4px;font-weight:800;font-size:16px;color:#111827;border-top:2px solid #e5e7eb;text-align:right;">${total.toStringAsFixed(2)}&nbsp;€</td>
        </tr>
      </table>
      <p style="margin:8px 0 0;font-size:12px;color:#6b7280;">Forma de pago: $metodo</p>
    </div>
    <!-- Footer -->
    <div style="background:#f9fafb;border-top:1px solid #e5e7eb;padding:16px 24px;text-align:center;">
      <p style="margin:0;font-size:12px;color:#9ca3af;">Gracias por su compra · $empresaNombre</p>
    </div>
  </div>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    final fmtHora = DateFormat('HH:mm');
    final fmtEuro = NumberFormat.currency(locale: 'es_ES', symbol: '€');

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _kSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Historial del día',
            style: TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _pedidosHoy(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: _kVerde));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No hay tickets hoy',
                        style: TextStyle(color: _kSecondary)),
                  );
                }
                return ListView.builder(
                  controller: scrollCtrl,
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final fecha = data['fecha_creacion'] is Timestamp
                        ? (data['fecha_creacion'] as Timestamp).toDate()
                        : DateTime.now();
                    final total =
                        (data['total'] as num?)?.toDouble() ?? 0.0;
                    final metodo = data['metodo_pago'] ?? '';
                    final cliente = (data['cliente_nombre'] as String?)
                            ?.isNotEmpty == true
                        ? data['cliente_nombre'] as String
                        : 'Cliente';
                    final ticket = data['numero_ticket'] ?? '-';

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _kVerde.withOpacity(0.15),
                          child: Text(
                            '#$ticket',
                            style: const TextStyle(
                                color: _kVerde,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          cliente,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${fmtHora.format(fecha)}  ·  $metodo',
                          style: const TextStyle(
                              color: _kSecondary, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fmtEuro.format(total),
                              style: const TextStyle(
                                  color: _kVerde,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              color: _kCard,
                              icon: const Icon(Icons.more_vert,
                                  color: _kSecondary, size: 18),
                              onSelected: (v) {
                                if (v == 'reimprimir') {
                                  _reimprimir(context, data);
                                } else if (v == 'detalle') {
                                  _verDetalle(context, data);
                                } else if (v == 'email') {
                                  _reenviarEmail(context, data);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'reimprimir',
                                  child: Row(children: [
                                    Icon(Icons.print_outlined, color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Text('Reimprimir', style: TextStyle(color: Colors.white)),
                                  ]),
                                ),
                                const PopupMenuItem(
                                  value: 'email',
                                  child: Row(children: [
                                    Icon(Icons.email_outlined, color: _kVerde, size: 16),
                                    SizedBox(width: 8),
                                    Text('Reenviar email', style: TextStyle(color: Colors.white)),
                                  ]),
                                ),
                                const PopupMenuItem(
                                  value: 'detalle',
                                  child: Row(children: [
                                    Icon(Icons.list_alt_outlined, color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Text('Ver detalle', style: TextStyle(color: Colors.white)),
                                  ]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

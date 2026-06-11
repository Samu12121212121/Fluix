import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'reimprimir',
                                  child: Row(children: [
                                    Icon(Icons.print_outlined,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Text('Reimprimir',
                                        style:
                                            TextStyle(color: Colors.white)),
                                  ]),
                                ),
                                const PopupMenuItem(
                                  value: 'detalle',
                                  child: Row(children: [
                                    Icon(Icons.list_alt_outlined,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 8),
                                    Text('Ver detalle',
                                        style:
                                            TextStyle(color: Colors.white)),
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

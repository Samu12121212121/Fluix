import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'dialogo_factura_tpv.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PANTALLA: CIERRE DE CAJA
// ═══════════════════════════════════════════════════════════════════════════

Future<void> mostrarPantallaCierreCaja(
    BuildContext context, String empresaId) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
        builder: (_) => _PantallaCierreCaja(empresaId: empresaId)),
  );
}

class _PantallaCierreCaja extends StatelessWidget {
  final String empresaId;
  const _PantallaCierreCaja({required this.empresaId});

  @override
  Widget build(BuildContext context) {
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F23),
      appBar: AppBar(
        title: const Text('Cierre de caja'),
        backgroundColor: const Color(0xFF1E2139),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas')
            .doc(empresaId)
            .collection('caja_diaria')
            .doc(hoy)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
                child: Text('No hay movimientos de caja hoy',
                    style: TextStyle(color: Color(0xFFB0B3C1))));
          }
          final d = snapshot.data!.data() as Map<String, dynamic>;
          final ef = (d['total_efectivo'] as num?)?.toDouble() ?? 0.0;
          final ta = (d['total_tarjeta'] as num?)?.toDouble() ?? 0.0;
          final bi = (d['total_bizum'] as num?)?.toDouble() ?? 0.0;
          final pr = (d['total_propinas'] as num?)?.toDouble() ?? 0.0;
          final nt = d['num_tickets'] ?? 0;
          final fi = (d['fondo_inicial'] as num?)?.toDouble() ?? 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF00FFC8), Color(0xFF00D9FF)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    const Text('TOTAL DEL DÍA',
                        style: TextStyle(
                            color: Color(0xFF0A0F23),
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(fmt.format(ef + ta + bi),
                        style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0A0F23))),
                    Text('$nt tickets',
                        style:
                            const TextStyle(color: Color(0xFF0A0F23))),
                  ]),
                ),
                const SizedBox(height: 24),
                LineaResumen(label: 'Efectivo', valor: ef,
                    icono: Icons.payments, color: const Color(0xFF00FFC8)),
                LineaResumen(label: 'Tarjeta', valor: ta,
                    icono: Icons.credit_card, color: const Color(0xFFFF3296)),
                LineaResumen(label: 'Bizum/QR', valor: bi,
                    icono: Icons.qr_code, color: const Color(0xFFFF4678)),
                const Divider(color: Color(0xFF2A2E45), height: 32),
                LineaResumen(label: 'Propinas', valor: pr,
                    icono: Icons.volunteer_activism,
                    color: const Color(0xFFFF4678)),
                LineaResumen(label: 'Fondo inicial', valor: fi,
                    icono: Icons.account_balance_wallet,
                    color: const Color(0xFFB0B3C1)),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _confirmarCierre(context, empresaId, hoy),
                  icon: const Icon(Icons.lock_clock),
                  label: const Text('Cerrar caja'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2850),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmarCierre(
      BuildContext context, String empresaId, String fecha) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar cierre'),
        content: const Text(
            '¿Cerrar la caja del día? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2850)),
              child: const Text('Cerrar caja')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection('empresas').doc(empresaId)
          .collection('caja_diaria').doc(fecha)
          .update({
        'abierta': false,
        'cerrada_en': FieldValue.serverTimestamp(),
      });
      if (!context.mounted) return;
      final m = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      m.showSnackBar(
          const SnackBar(content: Text('Caja cerrada correctamente')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DIÁLOGO: APERTURA DE CAJA
// ═══════════════════════════════════════════════════════════════════════════

Future<void> mostrarDialogoAperturaCaja(
    BuildContext context, String empresaId) async {
  await showDialog(
      context: context,
      builder: (_) => _DialogoAperturaCaja(empresaId: empresaId));
}

class _DialogoAperturaCaja extends StatefulWidget {
  final String empresaId;
  const _DialogoAperturaCaja({required this.empresaId});

  @override
  State<_DialogoAperturaCaja> createState() => _DialogoAperturaCajaState();
}

class _DialogoAperturaCajaState extends State<_DialogoAperturaCaja> {
  final _ctrl = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.account_balance_wallet, color: Color(0xFF00FFC8)),
        SizedBox(width: 8),
        Text('Apertura de caja'),
      ]),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Introduce el efectivo inicial en caja:'),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fondo inicial (€)',
              prefixIcon: Icon(Icons.euro),
              hintText: '100.00',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [50.0, 100.0, 150.0, 200.0]
                .map((v) => ActionChip(
                    label: Text('$v €'),
                    onPressed: () =>
                        setState(() => _ctrl.text = v.toString())))
                .toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: _guardando ? null : () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00FFC8)),
          child: _guardando
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Abrir caja'),
        ),
      ],
    );
  }

  Future<void> _guardar() async {
    final fondo = double.tryParse(_ctrl.text.trim());
    if (fondo == null || fondo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Introduce un importe válido')));
      return;
    }
    setState(() => _guardando = true);
    try {
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('caja_diaria').doc(hoy)
          .set({
        'fecha': hoy, 'fondo_inicial': fondo,
        'total_efectivo': 0.0, 'total_tarjeta': 0.0,
        'total_bizum': 0.0, 'total_propinas': 0.0,
        'num_tickets': 0, 'abierta': true,
        'abierta_en': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      final m = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      m.showSnackBar(const SnackBar(
          content: Text('Caja abierta correctamente'),
          backgroundColor: Color(0xFF00FFC8)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET: Línea de resumen de caja
// ═══════════════════════════════════════════════════════════════════════════

class LineaResumen extends StatelessWidget {
  final String label;
  final double valor;
  final IconData icono;
  final Color color;

  const LineaResumen({
    super.key,
    required this.label,
    required this.valor,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1E2139),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icono, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Text(label,
            style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 16))),
        Text(fmt.format(valor),
            style: const TextStyle(
                color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// IMPRIMIR TICKET
// ═══════════════════════════════════════════════════════════════════════════

Future<void> imprimirTicket({
  required String nombreMesa,
  required List<Map<String, dynamic>> lineas,
  required double totalFinal,
  required double descuentoCupon,
  required double propina,
  required String metodoPago,
  required double cambio,
}) async {
  final pdf = pw.Document();
  final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.roll80,
    build: (_) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(child: pw.Text('TICKET DE VENTA',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 8),
        pw.Center(child: pw.Text(nombreMesa)),
        pw.Divider(),
        pw.SizedBox(height: 8),
        ...lineas.map((l) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text(l['nombre'] ?? '')),
                pw.Text(fmt.format(l['precio'] ?? 0.0)),
              ],
            )),
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(fmt.format(totalFinal),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ]),
        if (descuentoCupon > 0) pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Text('Descuento'),
            pw.Text('-${fmt.format(descuentoCupon)}')]),
        if (propina > 0) pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [pw.Text('Propina'), pw.Text(fmt.format(propina))]),
        pw.SizedBox(height: 8),
        pw.Center(child: pw.Text('Método: ${metodoPago.toUpperCase()}')),
        if (metodoPago == 'efectivo' && cambio > 0)
          pw.Center(child: pw.Text('Cambio: ${fmt.format(cambio)}')),
        pw.SizedBox(height: 16),
        pw.Center(child: pw.Text('¡Gracias por su visita!')),
        pw.Center(child: pw.Text(
            DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()))),
      ],
    ),
  ));
  await Printing.layoutPdf(onLayout: (_) => pdf.save());
}

// ═══════════════════════════════════════════════════════════════════════════
// MOSTRAR DIÁLOGO DE FACTURA
// ═══════════════════════════════════════════════════════════════════════════

Future<void> mostrarFacturaTpvSiProcede({
  required BuildContext context,
  required String empresaId,
  required String mesaId,
  required Pedido? pedido,
}) async {
  if (pedido == null || !context.mounted) return;
  await DialogoFacturaTpv.mostrar(
    context: context,
    empresaId: empresaId,
    pedido: pedido,
    terminalId: mesaId,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET: Chip de método de pago
// ═══════════════════════════════════════════════════════════════════════════

class MetodoPagoChip extends StatelessWidget {
  final IconData icono;
  final String label;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;

  const MetodoPagoChip({
    super.key,
    required this.icono,
    required this.label,
    required this.color,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: seleccionado
              ? color.withValues(alpha: 0.2)
              : const Color(0xFF1E2139),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado ? color : Colors.transparent, width: 2),
        ),
        child: Column(children: [
          Icon(icono,
              color: seleccionado ? color : const Color(0xFFB0B3C1),
              size: 26),
          const SizedBox(height: 4),
          Text(label,
            style: TextStyle(
              color: seleccionado ? color : const Color(0xFFB0B3C1),
              fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

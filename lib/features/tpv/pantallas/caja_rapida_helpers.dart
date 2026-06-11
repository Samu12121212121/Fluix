import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../domain/modelos/pedido.dart';

// ── MODELO LOCAL ───────────────────────────────────────────────────────────────

class LineaTicket {
  final String productoId;
  final String nombre;
  final double precioUnitario;
  int cantidad = 1;
  double descuentoImporte = 0;

  LineaTicket({
    required this.productoId,
    required this.nombre,
    required this.precioUnitario,
  });

  double get subtotal => (precioUnitario - descuentoImporte) * cantidad;
}

// ── HELPER: diálogo etiqueta pedido en espera ─────────────────────────────────

Future<String?> pedirEtiquetaEspera(BuildContext context) async {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Guardar en espera'),
      content: TextField(
        controller: ctrl, autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Etiqueta (ej. Mesa 3, Cliente Juan…)',
          border: OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (v) => Navigator.pop(context,
            v.trim().isEmpty ? 'Pedido en espera' : v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final v = ctrl.text.trim();
            Navigator.pop(context, v.isEmpty ? 'Pedido en espera' : v);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

// ── HELPER: generar ticket texto ──────────────────────────────────────────────

String generarTicketTexto({
  required List<LineaTicket> lineas,
  required double total,
  required MetodoPago metodoPago,
  required double cambio,
  required String pedidoId,
  required String Function(double) fmt,
  required String Function(MetodoPago) nombrePago,
}) {
  final fmtDate = DateFormat('dd/MM/yyyy HH:mm');
  final buf = StringBuffer()
    ..writeln('================================')
    ..writeln('     FLUIX CRM — TICKET')
    ..writeln('================================')
    ..writeln('Fecha: ${fmtDate.format(DateTime.now())}')
    ..writeln('Ref: ${pedidoId.substring(0, 8).toUpperCase()}')
    ..writeln('--------------------------------');
  for (final l in lineas) {
    final nombre = l.nombre.length > 18
        ? '${l.nombre.substring(0, 18)}…'
        : l.nombre.padRight(20);
    buf.writeln('$nombre x${l.cantidad}  ${fmt(l.subtotal).padLeft(8)}');
  }
  buf
    ..writeln('--------------------------------')
    ..writeln('TOTAL:${fmt(total).padLeft(26)}')
    ..writeln('Método de pago: ${nombrePago(metodoPago)}');
  if (metodoPago == MetodoPago.efectivo && cambio > 0) {
    buf.writeln('Cambio:${fmt(cambio).padLeft(25)}');
  }
  buf
    ..writeln('================================')
    ..writeln('        ¡Gracias!')
    ..writeln('================================');
  return buf.toString();
}

// ── HELPER: mostrar error crítico ─────────────────────────────────────────────

Future<void> mostrarErrorCritico(
    BuildContext context, String paso, dynamic error, StackTrace? stack) async {
  debugPrint('ERROR CRÍTICO: $paso | $error');
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/fluixcrm_error_cobro.txt');
    await file.writeAsString(
        '═══\nERROR COBRO TPV\n═══\nFecha: ${DateTime.now()}\nPaso: $paso\nError: $error\nStack:\n$stack\n═══\n');
  } catch (_) {}
  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Row(children: [
        Icon(Icons.error, color: Colors.red, size: 32), SizedBox(width: 12),
        Expanded(child: Text('Error al Cobrar', style: TextStyle(color: Colors.red))),
      ]),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('La aplicación detectó un error y lo capturó antes de cerrarse.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          const Text('Paso que falló:', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(paso, style: const TextStyle(color: Colors.orange)),
          const SizedBox(height: 12),
          const Text('Error:', style: TextStyle(fontWeight: FontWeight.bold)),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50, borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: SelectableText(error.toString(),
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 12),
          const Text('Stack Trace:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
            height: 100,
            child: SingleChildScrollView(
              child: SelectableText(stack?.toString() ?? 'No disponible',
                  style: const TextStyle(fontSize: 9, fontFamily: 'monospace')),
            ),
          ),
        ]),
      ),
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.close),
          label: const Text('CERRAR'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

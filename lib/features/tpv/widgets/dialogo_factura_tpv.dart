import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../domain/modelos/pedido.dart';
import '../../../domain/modelos/factura.dart';
import '../../../services/tpv_facturacion_service.dart';
import '../../../services/pdf_service.dart';
import '../../../services/email_service.dart';

/// Diálogo post-cobro: pregunta si se desea generar factura y, si sí,
/// genera la factura automáticamente y muestra la vista de factura generada.
class DialogoFacturaTpv {
  static Future<void> mostrar({
    required BuildContext context,
    required String empresaId,
    required Pedido pedido,
    String? terminalId,
  }) async {
    final quiere = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.receipt_long, color: Color(0xFF1565C0)),
          SizedBox(width: 10),
          Text('¿Generar factura?', style: TextStyle(fontSize: 17)),
        ]),
        content: const Text(
          '¿Desea emitir una factura para esta venta?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, continuar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
            child: const Text('Sí, generar factura'),
          ),
        ],
      ),
    );

    if (quiere != true || !context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _FormularioFacturaDialog(
        empresaId: empresaId,
        pedido: pedido,
        terminalId: terminalId,
      ),
    );
  }
}

class _FormularioFacturaDialog extends StatefulWidget {
  final String empresaId;
  final Pedido pedido;
  final String? terminalId;

  const _FormularioFacturaDialog({
    required this.empresaId,
    required this.pedido,
    this.terminalId,
  });

  @override
  State<_FormularioFacturaDialog> createState() => _FormularioFacturaDialogState();
}

class _FormularioFacturaDialogState extends State<_FormularioFacturaDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nombreCtrl;
  late TextEditingController _emailCtrl;
  final _nifCtrl = TextEditingController();
  bool _generando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
        text: widget.pedido.clienteNombre.isNotEmpty ? widget.pedido.clienteNombre : '');
    _emailCtrl = TextEditingController(text: widget.pedido.clienteCorreo ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _nifCtrl.dispose();
    super.dispose();
  }

  Future<void> _generar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _generando = true;
      _error = null;
    });
    try {
      final svc = TpvFacturacionService();
      final config = await svc.obtenerConfig(widget.empresaId);
      final factura = await svc.generarFacturaPorPedido(
        empresaId: widget.empresaId,
        pedido: widget.pedido,
        config: config,
        usuarioNombre: FirebaseAuth.instance.currentUser?.displayName ?? 'TPV',
        terminalId: widget.terminalId,
        clienteNombreOverride: _nombreCtrl.text.trim(),
        clienteEmailOverride:
            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        clienteNifOverride:
            _nifCtrl.text.trim().isEmpty ? null : _nifCtrl.text.trim(),
      );
      if (!mounted) return;
      // Cerrar el formulario y mostrar la vista de factura generada
      Navigator.pop(context);
      await showDialog(
        context: context,
        builder: (ctx) => _DialogoFacturaGenerada(
          factura: factura,
          empresaId: widget.empresaId,
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _generando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(children: [
        Icon(Icons.receipt_long, color: Color(0xFF1565C0)),
        SizedBox(width: 10),
        Text('Datos de la factura', style: TextStyle(fontSize: 17)),
      ]),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.point_of_sale, size: 16, color: Color(0xFF1565C0)),
                  const SizedBox(width: 8),
                  Text(
                    'Ticket #${widget.pedido.numeroTicket}  ·  ${widget.pedido.total.toStringAsFixed(2)} €  ·  ${widget.pedido.metodoPago.name}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre / Razón social *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nifCtrl,
                decoration: const InputDecoration(
                  labelText: 'NIF / CIF (opcional)',
                  prefixIcon: Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email (opcional)',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_error!,
                      style: TextStyle(
                          color: Colors.red.shade700, fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _generando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _generando ? null : _generar,
          icon: _generando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.receipt_long, size: 16),
          label: Text(_generando ? 'Generando…' : 'Generar factura'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
        ),
      ],
    );
  }
}

/// Vista de factura generada: tarjeta limpia con líneas, totales y dos botones.
class _DialogoFacturaGenerada extends StatefulWidget {
  final Factura factura;
  final String empresaId;

  const _DialogoFacturaGenerada({
    required this.factura,
    required this.empresaId,
  });

  @override
  State<_DialogoFacturaGenerada> createState() => _DialogoFacturaGeneradaState();
}

class _DialogoFacturaGeneradaState extends State<_DialogoFacturaGenerada> {
  bool _enviando = false;

  Future<void> _verPdf() async {
    await PdfService.verFacturaPdf(context, widget.factura, widget.empresaId);
  }

  Future<void> _enviarEmail() async {
    // Si no hay email registrado, preguntar al usuario
    String? destino = widget.factura.clienteCorreo;
    if (destino == null || destino.isEmpty) {
      destino = await _pedirEmail();
      if (destino == null || destino.isEmpty) return; // el usuario canceló
    }

    setState(() => _enviando = true);
    try {
      // Generar los bytes del PDF dinámico antes de enviar
      final pdfBytes = await PdfService.generarFacturaPdfDinamico(
        widget.factura,
        widget.empresaId,
      );

      await EmailService.enviarFactura(
        destinatario: destino,
        pdfBytes: pdfBytes,
        numeroFactura: widget.factura.numeroFactura,
        total: widget.factura.total,
        empresaId: widget.empresaId,
        nombreCliente: widget.factura.clienteNombre,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Factura enviada a $destino'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Muestra un diálogo para que el cajero introduzca el email destino.
  /// Devuelve el email introducido, o null si el usuario canceló.
  Future<String?> _pedirEmail() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.email_outlined, color: Color(0xFF1565C0)),
          SizedBox(width: 10),
          Text('¿A qué email enviamos?', style: TextStyle(fontSize: 16)),
        ]),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          textInputAction: TextInputAction.send,
          onSubmitted: (v) {
            final email = v.trim();
            if (_esEmailValido(email)) Navigator.pop(ctx, email);
          },
          decoration: const InputDecoration(
            labelText: 'Email del cliente',
            hintText: 'cliente@ejemplo.com',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.alternate_email),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0)),
            onPressed: () {
              final email = ctrl.text.trim();
              if (_esEmailValido(email)) {
                Navigator.pop(ctx, email);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Introduce un email válido'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return result;
  }

  static bool _esEmailValido(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  @override
  Widget build(BuildContext context) {
    final f = widget.factura;
    const primario = Color(0xFF1565C0);
    const fondo = Color(0xFFF5F7FA);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ────────────────────────────────────────────────
            Container(
              color: primario,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.numeroFactura,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(f.fechaEmision),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AUTO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Datos del cliente
                    Text(
                      'Cliente: ${f.clienteNombre}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    if (f.datosFiscales?.nif != null)
                      Text(
                        'NIF: ${f.datosFiscales!.nif}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 10),

                    // Líneas
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Descripcion',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey,
                                  letterSpacing: 0.5)),
                        ),
                        const SizedBox(
                          width: 72,
                          child: Text('Base',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey)),
                        ),
                        const SizedBox(
                          width: 68,
                          child: Text('IVA',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey)),
                        ),
                        const SizedBox(
                          width: 72,
                          child: Text('Total',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...f.lineas.map((l) {
                      final iva = l.importeIva;
                      final base = l.subtotalSinIva;
                      final total = l.subtotalConIva;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.descripcion,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                            SizedBox(
                              width: 72,
                              child: Text(
                                '${base.toStringAsFixed(2)} €',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace'),
                              ),
                            ),
                            SizedBox(
                              width: 68,
                              child: Text(
                                '${iva.toStringAsFixed(2)} €',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: Colors.grey.shade600),
                              ),
                            ),
                            SizedBox(
                              width: 72,
                              child: Text(
                                '${total.toStringAsFixed(2)} €',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    color: primario),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 10),
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 8),

                    // Totales
                    _TotalRow(label: 'Base imponible', value: f.subtotal),
                    _TotalRow(label: 'IVA', value: f.totalIva),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                          Text(
                            '${f.total.toStringAsFixed(2)} €',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: primario,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Meta
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        '${f.metodoPago?.name ?? "Efectivo"}  ·  ${_formatDate(f.fechaEmision)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Footer con botones ─────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: fondo,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _verPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: const Text('Ver PDF'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: Colors.grey.shade300),
                        foregroundColor: Colors.grey.shade700,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _enviando ? null : _enviarEmail,
                      icon: _enviando
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_outlined, size: 16),
                      label: Text(_enviando ? 'Enviando…' : 'Enviar por email'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: primario,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  const _TotalRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(
            '${value.toStringAsFixed(2)} €',
            style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

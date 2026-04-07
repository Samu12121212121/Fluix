import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:planeag_flutter/domain/modelos/factura.dart';
import 'package:planeag_flutter/services/facturacion_service.dart';
import 'package:planeag_flutter/services/pdf_service.dart';
import 'package:planeag_flutter/services/email_service.dart';
import 'package:planeag_flutter/services/verifactu_service.dart';
import 'formulario_factura_screen.dart';
import 'formulario_rectificativa_screen.dart';

class DetalleFacturaScreen extends StatefulWidget {
  final Factura factura;
  final String empresaId;

  const DetalleFacturaScreen({
    super.key,
    required this.factura,
    required this.empresaId,
  });

  @override
  State<DetalleFacturaScreen> createState() => _DetalleFacturaScreenState();
}

class _DetalleFacturaScreenState extends State<DetalleFacturaScreen> {
  final _service = FacturacionService();
  String get empresaId => widget.empresaId;

  String get _userName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Usuario';
  String get _userId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.factura.numeroFactura),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Ver / Imprimir PDF',
            onPressed: () => PdfService.verFacturaPdf(context, widget.factura, empresaId),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) => _accion(context, v),
            itemBuilder: (_) => [
              if (widget.factura.esPendiente) ...[
                const PopupMenuItem(
                    value: 'editar',
                    child: ListTile(
                      leading: Icon(Icons.edit, color: Color(0xFF0D47A1)),
                      title: Text('Editar'),
                      contentPadding: EdgeInsets.zero,
                    )),
                const PopupMenuItem(
                    value: 'pagar',
                    child: ListTile(
                      leading: Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                      title: Text('Marcar como pagada'),
                      contentPadding: EdgeInsets.zero,
                    )),
              ],
              const PopupMenuItem(
                  value: 'enviar',
                  child: ListTile(
                    leading: Icon(Icons.send, color: Color(0xFF0D47A1)),
                    title: Text('Enviar al cliente'),
                    contentPadding: EdgeInsets.zero,
                  )),
              const PopupMenuItem(
                  value: 'duplicar',
                  child: ListTile(
                    leading: Icon(Icons.copy, color: Colors.orange),
                    title: Text('Duplicar factura'),
                    contentPadding: EdgeInsets.zero,
                  )),
              if (!widget.factura.esAnulada && !widget.factura.esRectificativa)
                const PopupMenuItem(
                    value: 'rectificativa',
                    child: ListTile(
                      leading: Icon(Icons.swap_horiz, color: Colors.deepPurple),
                      title: Text('Crear rectificativa'),
                      contentPadding: EdgeInsets.zero,
                    )),
              if (widget.factura.esProforma)
                const PopupMenuItem(
                    value: 'convertir_proforma',
                    child: ListTile(
                      leading: Icon(Icons.transform, color: Color(0xFF4CAF50)),
                      title: Text('Convertir a factura'),
                      contentPadding: EdgeInsets.zero,
                    )),
              if (widget.factura.esPendiente || widget.factura.estado == EstadoFactura.vencida)
                const PopupMenuItem(
                    value: 'anular',
                    child: ListTile(
                      leading: Icon(Icons.cancel, color: Colors.red),
                      title: Text('Anular factura'),
                      contentPadding: EdgeInsets.zero,
                    )),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Factura>>(
        stream: _service.obtenerFacturas(empresaId),
        builder: (context, snap) {
          Factura facturaActual = widget.factura;
          if (snap.hasData) {
            try {
              facturaActual =
                  snap.data!.firstWhere((f) => f.id == widget.factura.id);
            } catch (_) {}
          }
          return _buildContenido(context, facturaActual);
        },
      ),
    );
  }

  Widget _buildContenido(BuildContext context, Factura f) {
    final color = _colorEstado(f.estado);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Estado y número
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconoEstado(f.estado), color: color, size: 36),
                ),
                const SizedBox(height: 12),
                Text(
                  f.numeroFactura,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        f.estado.etiqueta,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (f.estaVencida && f.estado != EstadoFactura.vencida) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('VENCIDA',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ],
                    if (f.esRectificativa) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('RECTIFICATIVA',
                            style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w700, fontSize: 10)),
                      ),
                    ],
                    if (f.estado == EstadoFactura.rectificada) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('RECTIFICADA',
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w700, fontSize: 10)),
                      ),
                    ],
                    if (f.esProforma) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('PROFORMA',
                            style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w700, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildChipInfo(Icons.calendar_today, _formatFecha(f.fechaEmision)),
                    const SizedBox(width: 16),
                    _buildChipInfo(Icons.receipt, f.tipo.etiqueta),
                    if (f.fechaVencimiento != null) ...[
                      const SizedBox(width: 16),
                      _buildChipInfo(Icons.timer, 'Vence: ${_formatFecha(f.fechaVencimiento!)}'),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Cliente
        _buildSeccion('👤 Cliente', [
          _buildFila('Nombre',
              f.clienteNombre.isEmpty ? 'Cliente general' : f.clienteNombre),
          if (f.clienteTelefono != null)
            _buildFila('Teléfono', f.clienteTelefono!),
          if (f.clienteCorreo != null) _buildFila('Correo', f.clienteCorreo!),
          if (f.datosFiscales?.tieneDatos == true) ...[
            const Divider(height: 16),
            const Text('Datos Fiscales',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            if (f.datosFiscales!.nif != null) _buildFila('NIF/CIF', f.datosFiscales!.nif!),
            if (f.datosFiscales!.razonSocial != null) _buildFila('Razón Social', f.datosFiscales!.razonSocial!),
            if (f.datosFiscales!.direccion != null) _buildFila('Dirección', f.datosFiscales!.direccion!),
          ],
        ]),
        const SizedBox(height: 16),

        // Líneas
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🛒 Detalle de la Factura',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 12),
                ...f.lineas.map((l) => _buildLineaDetalle(l)),
                const Divider(height: 24),
                _buildFilaTotal('Base imponible', '${f.subtotal.toStringAsFixed(2)}€'),
                if (f.descuentoGlobal > 0)
                  _buildFilaTotal('Descuento global (${f.descuentoGlobal.toInt()}%)',
                      '-${f.importeDescuentoGlobal.toStringAsFixed(2)}€'),
                _buildFilaTotal('IVA', '${f.totalIva.toStringAsFixed(2)}€'),
                if (f.totalRecargoEquivalencia > 0)
                  _buildFilaTotal('Recargo equiv.', '${f.totalRecargoEquivalencia.toStringAsFixed(2)}€'),
                if (f.porcentajeIrpf > 0)
                  _buildFilaTotal('Retención IRPF (${f.porcentajeIrpf.toInt()}%)',
                      '-${f.retencionIrpf.toStringAsFixed(2)}€'),
                const Divider(height: 12),
                _buildFilaTotal('TOTAL', '${f.total.toStringAsFixed(2)}€', bold: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Datos de Rectificativa
        if (f.esRectificativa && f.facturaOriginalNumero != null) ...[
          _buildSeccion('📋 Datos de Rectificación', [
            _buildFila('Factura rectificada', f.facturaOriginalNumero!),
            if (f.facturaOriginalFecha != null)
              _buildFila('Fecha original', _formatFecha(f.facturaOriginalFecha!)),
            if (f.motivoRectificacion != null)
              _buildFila('Motivo', f.motivoRectificacion!.etiqueta),
            if (f.motivoRectificacionTexto != null && f.motivoRectificacionTexto!.isNotEmpty)
              _buildFila('Detalle', f.motivoRectificacionTexto!),
            if (f.metodoRectificacion != null)
              _buildFila('Método', f.metodoRectificacion!.etiqueta),
          ]),
          const SizedBox(height: 16),
        ],

        // Pago
        if (f.metodoPago != null || f.fechaPago != null) ...[
          _buildSeccion('💳 Pago', [
            if (f.metodoPago != null) _buildFila('Método', f.metodoPago!.etiqueta),
            if (f.fechaPago != null) _buildFila('Fecha de pago', _formatFecha(f.fechaPago!)),
          ]),
          const SizedBox(height: 16),
        ],

        // Notas
        if (f.notasInternas != null || f.notasCliente != null) ...[
          _buildSeccion('📝 Notas', [
            if (f.notasInternas != null) ...[
              const Text('Internas:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(f.notasInternas!, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
            ],
            if (f.notasCliente != null) ...[
              const Text('Para el cliente:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text(f.notasCliente!, style: const TextStyle(fontSize: 13)),
            ],
          ]),
          const SizedBox(height: 16),
        ],

        // Historial
        if (f.historial.isNotEmpty)
          _buildSeccion('📋 Historial de Cambios', [
            ...f.historial.reversed.map((h) => _buildEntradaHistorial(h)),
          ]),

        // Verifactu — estado del registro fiscal electrónico
        _buildSeccionVerifactu(f),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildLineaDetalle(LineaFactura l) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.descripcion, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  '${l.cantidad} × ${l.precioUnitario.toStringAsFixed(2)}€'
                  '  (IVA ${l.porcentajeIva.toInt()}%)'
                  '${l.descuento > 0 ? '  -${l.descuento.toInt()}% dto' : ''}'
                  '${l.recargoEquivalencia > 0 ? '  +${l.recargoEquivalencia}% RE' : ''}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Text('${l.subtotalConIva.toStringAsFixed(2)}€',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── ACCIONES ──────────────────────────────────────────────────────────────

  void _accion(BuildContext context, String accion) async {
    switch (accion) {
      case 'editar':
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FormularioFacturaScreen(
              empresaId: empresaId,
              facturaExistente: widget.factura,
            ),
          ),
        );
        if (result == true && mounted) {
          Navigator.pop(context, true); // refresh parent
        }
        break;

      case 'pagar':
        final metodo = await _elegirMetodoPago(context);
        if (metodo == null) return;
        await _service.actualizarEstado(
          empresaId: empresaId,
          facturaId: widget.factura.id,
          nuevoEstado: EstadoFactura.pagada,
          metodoPago: metodo,
          usuarioId: _userId,
          usuarioNombre: _userName,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Factura pagada'), backgroundColor: Color(0xFF4CAF50)),
          );
        }
        break;

      case 'enviar':
        await _enviarFactura(context);
        break;

      case 'duplicar':
        try {
          final resultado = await _service.duplicarFactura(
            empresaId: empresaId,
            facturaId: widget.factura.id,
            usuarioId: _userId,
            usuarioNombre: _userName,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Factura duplicada: ${resultado.factura.numeroFactura}'),
                backgroundColor: const Color(0xFF4CAF50),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
        break;

      case 'rectificativa':
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FormularioRectificativaScreen(
              empresaId: empresaId,
              facturaOriginal: widget.factura,
            ),
          ),
        );
        if (result == true && mounted) {
          Navigator.pop(context, true);
        }
        break;

      case 'convertir_proforma':
        try {
          final resultado = await _service.convertirProformaAFactura(
            empresaId: empresaId,
            proformaId: widget.factura.id,
            usuarioId: _userId,
            usuarioNombre: _userName,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Factura creada: ${resultado.factura.numeroFactura}'),
                backgroundColor: const Color(0xFF4CAF50),
              ),
            );
            Navigator.pop(context, true);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
            );
          }
        }
        break;

      case 'anular':
        final ctrl = TextEditingController();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Anular factura'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Motivo'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _service.anularFactura(
                    empresaId: empresaId,
                    facturaId: widget.factura.id,
                    motivo: ctrl.text,
                    usuarioId: _userId,
                    usuarioNombre: _userName,
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Anular', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        break;
    }
  }

  // ── ENVIAR POR EMAIL/WHATSAPP ─────────────────────────────────────────────

  Future<void> _enviarFactura(BuildContext context) async {
    final opcion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enviar factura'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.share, color: Color(0xFF0D47A1)),
              title: const Text('Compartir PDF'),
              subtitle: const Text('WhatsApp, Telegram, etc.'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.email, color: Colors.orange),
              title: const Text('Enviar por email'),
              subtitle: Text(widget.factura.clienteCorreo ?? 'Sin correo'),
              onTap: () => Navigator.pop(ctx, 'email'),
            ),
            if (widget.factura.clienteTelefono != null)
              ListTile(
                leading: const Icon(Icons.message, color: Color(0xFF25D366)),
                title: const Text('WhatsApp directo'),
                subtitle: Text(widget.factura.clienteTelefono!),
                onTap: () => Navigator.pop(ctx, 'whatsapp'),
              ),
          ],
        ),
      ),
    );
    if (opcion == null) return;

    try {
      // Generate PDF bytes (usa generarFacturaPdfConDatos que lee los datos correctamente)
      final pdfBytes = await PdfService.generarFacturaPdfConDatos(widget.factura, empresaId);
      final dir = await getTemporaryDirectory();
      final nombre = 'Factura_${widget.factura.numeroFactura.replaceAll('/', '_')}.pdf';
      final file = File('${dir.path}/$nombre');
      await file.writeAsBytes(pdfBytes);
      final xfile = XFile(file.path, mimeType: 'application/pdf');

      if (opcion == 'share') {
        await Share.shareXFiles(
          [xfile],
          subject: 'Factura ${widget.factura.numeroFactura}',
          text: 'Adjunto la factura ${widget.factura.numeroFactura} por ${widget.factura.total.toStringAsFixed(2)}€',
        );
      } else if (opcion == 'email') {
        final correo = widget.factura.clienteCorreo ?? '';
        if (correo.isNotEmpty) {
          // Intentar enviar por Cloud Function (servidor)
          try {
            final msg = await EmailService.enviarFactura(
              destinatario: correo,
              pdfBytes: pdfBytes,
              numeroFactura: widget.factura.numeroFactura,
              total: widget.factura.total,
              empresaId: empresaId,
              nombreCliente: widget.factura.clienteNombre,
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✅ $msg'), backgroundColor: const Color(0xFF4CAF50)),
              );
            }
          } catch (_) {
            // Fallback: compartir vía sistema
            if (mounted) {
              await Share.shareXFiles([xfile], subject: 'Factura ${widget.factura.numeroFactura}');
            }
          }
        } else {
          // Sin correo: compartir vía sistema
          await Share.shareXFiles([xfile], subject: 'Factura ${widget.factura.numeroFactura}');
        }
      } else if (opcion == 'whatsapp') {
        final tel = widget.factura.clienteTelefono!.replaceAll(RegExp(r'[^0-9+]'), '');
        final texto = 'Hola, te envío la factura ${widget.factura.numeroFactura} '
            'por importe de ${widget.factura.total.toStringAsFixed(2)}€.';
        final waUri = Uri.parse('https://wa.me/$tel?text=${Uri.encodeComponent(texto)}');
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
        if (mounted) {
          await Share.shareXFiles([xfile], subject: 'Factura ${widget.factura.numeroFactura}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al enviar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<MetodoPagoFactura?> _elegirMetodoPago(BuildContext context) {
    return showDialog<MetodoPagoFactura>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Método de pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: MetodoPagoFactura.values
              .map((m) => ListTile(
                    leading: Icon(_iconoMetodoPago(m)),
                    title: Text(m.etiqueta),
                    onTap: () => Navigator.pop(ctx, m),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────

  Widget _buildSeccion(String titulo, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildFila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildFilaTotal(String label, String valor, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: bold ? Colors.black : Colors.grey[700])),
          Text(valor,
              style: TextStyle(
                  fontSize: bold ? 15 : 13,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: bold ? const Color(0xFF0D47A1) : Colors.black)),
        ],
      ),
    );
  }

  Widget _buildChipInfo(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(texto, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildEntradaHistorial(EntradaHistorialFactura h) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8, height: 8,
            margin: const EdgeInsets.only(top: 5, right: 8),
            decoration: const BoxDecoration(color: Color(0xFF0D47A1), shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.descripcion, style: const TextStyle(fontSize: 13)),
                Text('${h.usuarioNombre} · ${_formatFecha(h.fecha)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _colorEstado(EstadoFactura estado) {
    switch (estado) {
      case EstadoFactura.pendiente: return const Color(0xFFFF9800);
      case EstadoFactura.pagada: return const Color(0xFF4CAF50);
      case EstadoFactura.anulada: return Colors.grey;
      case EstadoFactura.vencida: return Colors.red;
      case EstadoFactura.rectificada: return Colors.orange;
    }
  }

  IconData _iconoEstado(EstadoFactura estado) {
    switch (estado) {
      case EstadoFactura.pendiente: return Icons.pending_actions;
      case EstadoFactura.pagada: return Icons.check_circle;
      case EstadoFactura.anulada: return Icons.cancel;
      case EstadoFactura.vencida: return Icons.warning;
      case EstadoFactura.rectificada: return Icons.swap_horiz;
    }
  }

  IconData _iconoMetodoPago(MetodoPagoFactura m) {
    switch (m) {
      case MetodoPagoFactura.tarjeta: return Icons.credit_card;
      case MetodoPagoFactura.paypal: return Icons.paypal;
      case MetodoPagoFactura.bizum: return Icons.phone_android;
      case MetodoPagoFactura.efectivo: return Icons.money;
      case MetodoPagoFactura.transferencia: return Icons.account_balance;
    }
  }

  String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  /// Muestra el estado del registro Verifactu de la factura
  Widget _buildSeccionVerifactu(Factura f) {
    final vfMap = f.verifactu;
    if (vfMap == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified_outlined, size: 18, color: Colors.grey),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Verifactu: No registrada. Activa Verifactu en Configuración.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final vf = DatosVerifactu.fromMap(vfMap);
    final color = _colorVerifactu(vf.estado);
    final icono = _iconoVerifactu(vf.estado);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 18, color: color),
                const SizedBox(width: 10),
                Text(
                  'Verifactu — ${_etiquetaVerifactu(vf.estado)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 13),
                ),
              ],
            ),
            if (vf.hashRegistro.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Hash: ${vf.hashRegistro.substring(0, 16)}...',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontFamily: 'monospace'),
              ),
            ],
            if (vf.urlVerificacion != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(vf.urlVerificacion!);
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
                child: Text(
                  'Ver en AEAT →',
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      decoration: TextDecoration.underline),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _colorVerifactu(EstadoVerifactu estado) {
    switch (estado) {
      case EstadoVerifactu.pendiente: return Colors.orange;
      case EstadoVerifactu.enviada: return Colors.blue;
      case EstadoVerifactu.aceptada: return Colors.green;
      case EstadoVerifactu.rechazada: return Colors.red;
      case EstadoVerifactu.error: return Colors.red;
    }
  }

  IconData _iconoVerifactu(EstadoVerifactu estado) {
    switch (estado) {
      case EstadoVerifactu.pendiente: return Icons.schedule;
      case EstadoVerifactu.enviada: return Icons.send;
      case EstadoVerifactu.aceptada: return Icons.verified;
      case EstadoVerifactu.rechazada: return Icons.cancel;
      case EstadoVerifactu.error: return Icons.error_outline;
    }
  }

  String _etiquetaVerifactu(EstadoVerifactu estado) {
    switch (estado) {
      case EstadoVerifactu.pendiente: return 'Pendiente de envío';
      case EstadoVerifactu.enviada: return 'Enviado a AEAT';
      case EstadoVerifactu.aceptada: return 'Aceptado por AEAT ✓';
      case EstadoVerifactu.rechazada: return 'Rechazado por AEAT';
      case EstadoVerifactu.error: return 'Error de envío';
    }
  }

}



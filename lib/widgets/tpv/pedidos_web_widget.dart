import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFIER — mantiene el conteo de pedidos web pendientes para el badge
// ═══════════════════════════════════════════════════════════════════════════

class PedidosWebNotifier extends ChangeNotifier {
  int _pendientes = 0;
  int get pendientes => _pendientes;

  StreamSubscription<QuerySnapshot>? _sub;

  void iniciar(String empresaId) {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos')
        .where('origen', isEqualTo: 'tienda_online')
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .listen((snap) {
      _pendientes = snap.docs.length;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BADGE — icono en la AppBar con contador
// ═══════════════════════════════════════════════════════════════════════════

class PedidosWebBadge extends StatelessWidget {
  final PedidosWebNotifier notifier;
  final String empresaId;

  const PedidosWebBadge({
    super.key,
    required this.notifier,
    required this.empresaId,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_bag_outlined, size: 18),
          tooltip: 'Pedidos online',
          onPressed: () => PedidosWebWidget.mostrar(context, empresaId),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        ListenableBuilder(
          listenable: notifier,
          builder: (_, __) => notifier.pendientes == 0
              ? const SizedBox.shrink()
              : Positioned(
                  top: 2,
                  right: 2,
                  child: CircleAvatar(
                    radius: 7,
                    backgroundColor: Colors.orange,
                    child: Text(
                      '${notifier.pendientes}',
                      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PANEL PRINCIPAL — lista de pedidos web con gestión de estado
// ═══════════════════════════════════════════════════════════════════════════

class PedidosWebWidget extends StatefulWidget {
  final String empresaId;

  const PedidosWebWidget({super.key, required this.empresaId});

  static Future<void> mostrar(BuildContext context, String empresaId) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 640,
          height: 580,
          child: PedidosWebWidget(empresaId: empresaId),
        ),
      ),
    );
  }

  @override
  State<PedidosWebWidget> createState() => _PedidosWebWidgetState();
}

class _PedidosWebWidgetState extends State<PedidosWebWidget>
    with SingleTickerProviderStateMixin {
  static const _estados = ['pendiente', 'en_preparacion', 'enviado', 'completado'];
  static const _colores = {
    'pendiente':       Color(0xFFF57F17),
    'en_preparacion':  Color(0xFF1565C0),
    'enviado':         Color(0xFF6A1B9A),
    'completado':      Color(0xFF1B5E20),
    'cancelado':       Color(0xFFB71C1C),
  };
  static const _etiquetas = {
    'pendiente':       'Pendiente',
    'en_preparacion':  'En preparación',
    'enviado':         'Enviado',
    'completado':      'Completado',
    'cancelado':       'Cancelado',
  };

  late TabController _tab;
  String? _expandidoId;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Header ────────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
        decoration: const BoxDecoration(
          color: Color(0xFF1B5E20),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(children: [
          const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          const Text('Pedidos online',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
          ),
        ]),
      ),
      // ── Tabs de estado ────────────────────────────────────────────────────
      Material(
        color: const Color(0xFF1B5E20),
        child: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.white,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'En prep.'),
            Tab(text: 'Enviados'),
            Tab(text: 'Completados'),
          ],
        ),
      ),
      // ── Contenido ─────────────────────────────────────────────────────────
      Expanded(
        child: TabBarView(
          controller: _tab,
          children: _estados.map((estado) => _listaEstado(estado)).toList(),
        ),
      ),
    ]);
  }

  Widget _listaEstado(String estado) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('pedidos')
          .where('origen', isEqualTo: 'tienda_online')
          .where('estado', isEqualTo: estado)
          .orderBy('fecha_pedido', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 10),
              Text('No hay pedidos ${ _etiquetas[estado]?.toLowerCase() ?? estado}',
                  style: TextStyle(color: Colors.grey.shade500)),
            ]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, idx) {
            final doc = docs[idx];
            final data = doc.data() as Map<String, dynamic>;
            final expandido = _expandidoId == doc.id;
            return _TarjetaPedidoWeb(
              id: doc.id,
              empresaId: widget.empresaId,
              data: data,
              expandido: expandido,
              colores: _colores,
              etiquetas: _etiquetas,
              onExpand: () => setState(
                  () => _expandidoId = expandido ? null : doc.id),
              onCambiarEstado: (nuevoEstado, {String? transportista, String? tracking}) =>
                  _cambiarEstado(doc.id, nuevoEstado,
                      transportista: transportista, tracking: tracking),
            );
          },
        );
      },
    );
  }

  Future<void> _cambiarEstado(String pedidoId, String nuevoEstado,
      {String? transportista, String? tracking}) async {
    final data = <String, dynamic>{
      'estado': nuevoEstado,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    };
    if (transportista != null) data['tracking_transportista'] = transportista;
    if (tracking != null) data['tracking_numero'] = tracking;
    if (nuevoEstado == 'enviado') data['fecha_envio'] = FieldValue.serverTimestamp();

    final docRef = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('pedidos')
        .doc(pedidoId);

    await docRef.update(data);

    // Enviar email de seguimiento al cliente si hay tracking
    if (nuevoEstado == 'enviado' && tracking != null && tracking.isNotEmpty) {
      try {
        final pedidoSnap = await docRef.get();
        final pedidoData = pedidoSnap.data() ?? {};
        final email = pedidoData['cliente_email'] as String?;
        final clienteNombre = pedidoData['cliente_nombre'] as String? ?? 'Cliente';
        final numTicket = pedidoData['numero_ticket'];
        if (email != null && email.isNotEmpty) {
          final empresaSnap = await FirebaseFirestore.instance
              .collection('empresas').doc(widget.empresaId).get();
          final nombreEmpresa = empresaSnap.data()?['nombre'] as String? ?? 'La tienda';
          await FirebaseFunctions.instanceFor(region: 'europe-west1')
              .httpsCallable('enviarEmailConPdf')
              .call({
            'destinatario': email,
            'asunto': '📦 Tu pedido${numTicket != null ? ' #$numTicket' : ''} ha sido enviado — $nombreEmpresa',
            'cuerpoHtml': '''
              <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
                <h2 style="color:#4A7C59;">¡Tu pedido está de camino! 🚚</h2>
                <p>Hola $clienteNombre,</p>
                <p>Tu pedido ha sido enviado${transportista != null && transportista.isNotEmpty ? ' con <strong>$transportista</strong>' : ''}.</p>
                <div style="background:#DCF0E6;border-radius:10px;padding:16px;margin:16px 0;">
                  <p style="margin:0;font-size:13px;color:#1A3A27;"><strong>Número de seguimiento:</strong></p>
                  <p style="margin:8px 0 0;font-size:20px;font-weight:bold;color:#4A7C59;letter-spacing:1px;">$tracking</p>
                </div>
                <p>Puedes usar este número para rastrear tu envío en la web del transportista.</p>
                <p style="color:#999;font-size:12px;">— $nombreEmpresa</p>
              </div>
            ''',
            'empresaId': widget.empresaId,
          });
        }
      } catch (e) {
        debugPrint('Error enviando email de tracking: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tracking != null
            ? 'Enviado · Tracking: $tracking ${email_sent_hint(tracking)}'
            : 'Pedido marcado como ${_etiquetas[nuevoEstado] ?? nuevoEstado}'),
        backgroundColor: _colores[nuevoEstado] ?? Colors.grey,
      ));
    }
  }

  String email_sent_hint(String tracking) => '— email enviado al cliente';
}

// ── Tarjeta individual de pedido ──────────────────────────────────────────────

class _TarjetaPedidoWeb extends StatelessWidget {
  final String id;
  final String empresaId;
  final Map<String, dynamic> data;
  final bool expandido;
  final Map<String, Color> colores;
  final Map<String, String> etiquetas;
  final VoidCallback onExpand;
  final void Function(String estado, {String? transportista, String? tracking}) onCambiarEstado;

  const _TarjetaPedidoWeb({
    required this.id,
    required this.empresaId,
    required this.data,
    required this.expandido,
    required this.colores,
    required this.etiquetas,
    required this.onExpand,
    required this.onCambiarEstado,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final fechaTs = data['fecha_pedido'];
    final fecha = fechaTs is Timestamp
        ? DateFormat('dd/MM/yyyy HH:mm').format(fechaTs.toDate())
        : '—';
    final estado = data['estado'] as String? ?? 'pendiente';
    final colorEstado = colores[estado] ?? Colors.grey;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final cliente = data['cliente_nombre'] as String? ?? 'Cliente online';
    final email = data['cliente_email'] as String?;
    final numTicket = data['numero_ticket'] as int?;
    final lineas = (data['lineas'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final direccion = data['direccion_envio'] as String?;
    final trackingNum   = data['tracking_numero'] as String?;
    final trackingTransp = data['tracking_transportista'] as String?;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: expandido ? colorEstado : Colors.grey.shade200,
          width: expandido ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Fila resumen (siempre visible)
        InkWell(
          onTap: onExpand,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              // Badge de estado
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: colorEstado, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              // Info
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(
                      numTicket != null ? '#$numTicket — ' : '',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                    ),
                    Text(cliente,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 2),
                  Text(fecha, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ]),
              ),
              // Total
              Text(fmt.format(total),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Icon(expandido ? Icons.expand_less : Icons.expand_more,
                  size: 18, color: Colors.grey.shade400),
            ]),
          ),
        ),
        // Detalle expandido
        if (expandido) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Líneas del pedido
              ...lineas.map((l) {
                final nombre = l['producto_nombre'] as String? ?? l['nombre'] as String? ?? '—';
                final cantidad = (l['cantidad'] as num?)?.toInt() ?? 1;
                final precio = (l['precio_unitario'] as num?)?.toDouble() ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Text('${cantidad}x', style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(nombre, style: const TextStyle(fontSize: 12))),
                    Text(fmt.format(precio * cantidad),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                );
              }),
              if (direccion != null) ...[
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.local_shipping_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(child: Text(direccion,
                      style: const TextStyle(fontSize: 11, color: Colors.grey))),
                ]),
              ],
              if (email != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              ],
              // ── Tracking info ────────────────────────────────────────────
              if (trackingNum != null && trackingNum.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCF0E6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBDD8C4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.local_shipping_rounded, size: 15, color: Color(0xFF4A7C59)),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        trackingTransp != null && trackingTransp.isNotEmpty
                            ? trackingTransp : 'Número de tracking',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF81B29A),
                            fontWeight: FontWeight.w600),
                      ),
                      Text(trackingNum,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                              color: Color(0xFF1A3A27), letterSpacing: 0.5)),
                    ])),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: trackingNum));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Número de tracking copiado'),
                          duration: Duration(seconds: 2),
                        ));
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF81B29A)),
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              // Acciones de estado
              Wrap(spacing: 8, runSpacing: 8, children: _accionesEstado(context, estado)),
            ]),
          ),
        ],
      ]),
    );
  }

  List<Widget> _accionesEstado(BuildContext context, String estadoActual) {
    final widgets = <Widget>[];
    final kColor = const Color(0xFF4A7C59);

    switch (estadoActual) {
      case 'pendiente':
        widgets.add(FilledButton.icon(
          onPressed: () => onCambiarEstado('en_preparacion'),
          icon: const Icon(Icons.inventory_2_outlined, size: 14),
          label: const Text('En preparación', style: TextStyle(fontSize: 11)),
          style: FilledButton.styleFrom(backgroundColor: kColor,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ));
        widgets.add(OutlinedButton.icon(
          onPressed: () => onCambiarEstado('cancelado'),
          icon: const Icon(Icons.cancel_outlined, size: 14),
          label: const Text('Cancelar', style: TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ));

      case 'en_preparacion':
        // "Marcar como enviado" abre diálogo de tracking
        widgets.add(FilledButton.icon(
          onPressed: () => _mostrarDialogoEnvio(context),
          icon: const Icon(Icons.local_shipping_rounded, size: 14),
          label: const Text('Enviar pedido', style: TextStyle(fontSize: 11)),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ));
        widgets.add(OutlinedButton.icon(
          onPressed: () => onCambiarEstado('pendiente'),
          icon: const Icon(Icons.undo, size: 14),
          label: const Text('Volver a pendiente', style: TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(foregroundColor: kColor,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ));

      case 'enviado':
        widgets.add(FilledButton.icon(
          onPressed: () => onCambiarEstado('completado'),
          icon: const Icon(Icons.check_circle_outline, size: 14),
          label: const Text('Marcar como completado', style: TextStyle(fontSize: 11)),
          style: FilledButton.styleFrom(backgroundColor: kColor,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ));
        // Re-enviar email de tracking
        widgets.add(OutlinedButton.icon(
          onPressed: () => _mostrarDialogoEnvio(context, reenviar: true),
          icon: const Icon(Icons.email_outlined, size: 14),
          label: const Text('Reenviar tracking', style: TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF6A1B9A),
              side: const BorderSide(color: Color(0xFF6A1B9A)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ));
    }
    return widgets;
  }

  Future<void> _mostrarDialogoEnvio(BuildContext context, {bool reenviar = false}) async {
    final trackingCtrl = TextEditingController(
        text: reenviar ? (data['tracking_numero'] as String? ?? '') : '');
    final transpCtrl = TextEditingController(
        text: reenviar ? (data['tracking_transportista'] as String? ?? '') : '');

    const transportistas = ['Correos', 'MRW', 'SEUR', 'GLS', 'DHL', 'UPS', 'FedEx', 'Nacex', 'Otro'];

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.local_shipping_rounded, color: Color(0xFF4A7C59), size: 20),
            const SizedBox(width: 8),
            Text(reenviar ? 'Actualizar envío' : 'Registrar envío',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Transportista
              DropdownButtonFormField<String>(
                value: transportistas.contains(transpCtrl.text)
                    ? transpCtrl.text : null,
                decoration: InputDecoration(
                  labelText: 'Transportista',
                  prefixIcon: const Icon(Icons.directions_car_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                hint: const Text('Seleccionar…'),
                items: transportistas.map((t) =>
                    DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setS(() => transpCtrl.text = v ?? ''),
              ),
              const SizedBox(height: 12),
              // Número de tracking
              TextField(
                controller: trackingCtrl,
                autofocus: !reenviar,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Número de tracking *',
                  hintText: 'ES123456789CN',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF4A7C59), width: 1.5)),
                ),
              ),
              const SizedBox(height: 8),
              if (data['cliente_email'] != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCF0E6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.email_outlined, size: 14, color: Color(0xFF4A7C59)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      'Se enviará email con el tracking a ${data['cliente_email']}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF4A7C59)),
                    )),
                  ]),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: trackingCtrl.text.trim().isNotEmpty
                  ? () => Navigator.pop(ctx, {
                      'tracking': trackingCtrl.text.trim(),
                      'transportista': transpCtrl.text.trim(),
                    })
                  : null,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4A7C59)),
              child: Text(reenviar ? 'Actualizar y reenviar' : 'Registrar envío'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      onCambiarEstado(
        reenviar ? (data['estado'] as String? ?? 'enviado') : 'enviado',
        transportista: result['transportista'],
        tracking: result['tracking'],
      );
    }
  }

}

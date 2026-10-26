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
  static const _kNazariId = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

  int _pendientesBase   = 0;
  int _pendientesEbooks = 0;
  int get pendientes => _pendientesBase + _pendientesEbooks;

  StreamSubscription<QuerySnapshot>? _sub;
  StreamSubscription<QuerySnapshot>? _subEbooks;

  void iniciar(String empresaId) {
    _sub?.cancel();
    _subEbooks?.cancel();

    _sub = FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('pedidos')
        .where('origen', whereIn: ['tienda_online', 'web_nazari'])
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .listen((snap) {
      _pendientesBase = snap.docs.length;
      notifyListeners();
    });

    if (empresaId == _kNazariId) {
      // Bizum + transferencia pendientes — Stripe se descarta porque pasa a 'pagado' tras el webhook
      _subEbooks = FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('pedidos_web_nazari')
          .where('estado_pago', isEqualTo: 'pendiente')
          .snapshots()
          .listen((snap) {
        _pendientesEbooks = snap.docs
            .where((d) {
              final m = d.data()['metodo_pago'] as String? ?? '';
              return m == 'transferencia' || m == 'bizum';
            })
            .length;
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _subEbooks?.cancel();
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
  static const _kNazariId = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
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

  bool get _esNazari => widget.empresaId == _kNazariId;
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
          tabs: [
            const Tab(text: 'Pendientes'),
            const Tab(text: 'En prep.'),
            const Tab(text: 'Enviados'),
            const Tab(text: 'Completados'),
          ],
        ),
      ),
      // ── Contenido ─────────────────────────────────────────────────────────
      Expanded(
        child: TabBarView(
          controller: _tab,
          children: [
            ..._estados.map((estado) => _listaEstado(estado)),
          ],
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
          .where('origen', whereIn: ['tienda_online', 'web_nazari'])
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

  // ── Tab Ebooks (Nazarí) ─────────────────────────────────────────────────────

  Widget _listaEbooks() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('pedidos_web_nazari')
          .orderBy('fecha_creacion', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.menu_book_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text('Sin pedidos de ebooks', style: TextStyle(color: Colors.grey.shade500)),
          ]));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, idx) {
            final doc = docs[idx];
            final data = doc.data() as Map<String, dynamic>;
            final expandido = _expandidoId == doc.id;
            return TarjetaEbookWeb(
              id: doc.id,
              empresaId: widget.empresaId,
              data: data,
              expandido: expandido,
              onExpand: () => setState(() => _expandidoId = expandido ? null : doc.id),
              onConfirmarPago: () => _confirmarTransferencia(doc.id),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmarTransferencia(String pedidoId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar pago por transferencia'),
        content: const Text(
          'Al confirmar, se enviará automáticamente el enlace de descarga al comprador.\n\n¿El pago ha sido recibido?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1B5E20)),
            child: const Text('Confirmar y entregar ebook'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('pedidos_web_nazari')
          .doc(pedidoId)
          .update({
        'estado_pago': 'pagado',
        'estado': 'pagado',
        'fecha_pago': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Pago confirmado — el ebook se entregará en breve'),
          backgroundColor: Color(0xFF1B5E20),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

// ── Tarjeta pedido de ebook (pedidos_web_nazari) ──────────────────────────────

class TarjetaEbookWeb extends StatefulWidget {
  final String id;
  final String empresaId;
  final Map<String, dynamic> data;
  final Map<String, String> catalogoImgs;
  final bool expandido;
  final VoidCallback onExpand;
  final VoidCallback onConfirmarPago;

  const TarjetaEbookWeb({
    super.key,
    required this.id,
    required this.empresaId,
    required this.data,
    this.catalogoImgs = const {},
    required this.expandido,
    required this.onExpand,
    required this.onConfirmarPago,
  });

  @override
  State<TarjetaEbookWeb> createState() => _TarjetaEbookWebState();
}

class _TarjetaEbookWebState extends State<TarjetaEbookWeb> {
  Map<String, dynamic>? _dirRecuperada;
  bool _recuperando = false;

  // ── Helpers de color/label según estado ─────────────────────────────────
  static Color _colorEstado(String estadoPago, String metodoPago) {
    if (estadoPago == 'pagado')    return const Color(0xFF1B5E20);
    if (estadoPago == 'cancelado') return const Color(0xFF94A3B8);
    if (metodoPago == 'transferencia') return const Color(0xFFD97706);
    if (metodoPago == 'bizum')        return const Color(0xFF0369A1);
    return const Color(0xFF64748B);
  }

  static String _labelEstado(String estadoPago, String metodoPago) {
    if (estadoPago == 'pagado')    return 'Pagado';
    if (estadoPago == 'cancelado') return 'Cancelado';
    if (metodoPago == 'transferencia') return 'Transf. pendiente';
    if (metodoPago == 'bizum')        return 'Bizum pendiente';
    return 'Pendiente';
  }

  void _mostrarDetalles(BuildContext context, {
    required String nombre, required String email,
    required Map<String, dynamic>? dir, required List<Map<String, dynamic>> items,
    required double total, required double? subtotal, required double? envio,
    required String estadoPago, required String metodoPago, required String fecha,
    required NumberFormat fmt,
    Map<String, String> imgs = const {},
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2)),
            )),
            Text('Detalle del pedido', style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            // Items
            ...items.map((item) {
              final t = item['titulo'] as String? ?? item['catalogo_id'] as String? ?? '—';
              final q = (item['cantidad'] as num?)?.toInt() ?? 1;
              final p = (item['precio'] as num?)?.toDouble() ?? 0.0;
              final _catId = item['catalogo_id'] as String? ?? '';
              final img = (item['imagen_url'] as String? ?? '').isNotEmpty
                  ? item['imagen_url'] as String
                  : imgs[_catId] ?? '';
              final esEbook = item['es_ebook'] as bool? ?? false;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  if (img.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(img, width: 44, height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _coverPlaceholder()),
                    )
                  else _coverPlaceholder(),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('$q × ${fmt.format(p)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    if (esEbook)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Ebook', style: TextStyle(
                            fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600)),
                      ),
                  ])),
                  Text(fmt.format(p * q),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              );
            }),
            const Divider(),
            // Desglose
            if (subtotal != null && envio != null) ...[
              _desgloseFila('Libros', fmt.format(subtotal)),
              _desgloseFila('Envío', envio == 0 ? 'Gratis' : fmt.format(envio)),
              const Divider(height: 8),
            ],
            _desgloseFila('Total', fmt.format(total), bold: true),
            const SizedBox(height: 16),
            // Datos cliente
            if (nombre.isNotEmpty && nombre != '—') ...[
              _seccionLabel('Comprador'),
              _infoFilaDetalle(Icons.person_outline, nombre),
              if (email.isNotEmpty) _infoFilaDetalle(Icons.email_outlined, email),
            ],
            // Dirección
            if (dir != null) ...[
              const SizedBox(height: 12),
              _seccionLabel('Dirección de envío'),
              if ((dir['nombre'] as String? ?? '').isNotEmpty)
                _infoFilaDetalle(Icons.person_outline, dir['nombre'] as String),
              if ((dir['telefono'] as String? ?? '').isNotEmpty)
                _infoFilaDetalle(Icons.phone_outlined, dir['telefono'] as String),
              if ((dir['linea1'] as String? ?? '').isNotEmpty)
                _infoFilaDetalle(Icons.home_outlined,
                    [dir['linea1'], dir['linea2'], dir['cp'], dir['ciudad'], dir['pais']]
                        .where((v) => v != null && (v as String).isNotEmpty)
                        .join(', ')),
            ] else ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(
                      estadoPago == 'pagado'
                          ? Icons.warning_amber_rounded
                          : Icons.schedule_rounded,
                      size: 14,
                      color: estadoPago == 'pagado'
                          ? const Color(0xFFD97706)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 7),
                    Expanded(child: Text(
                      estadoPago == 'pagado'
                          ? 'Dirección no recibida de Stripe'
                          : metodoPago == 'stripe'
                              ? 'Se recibirá cuando el cliente complete el pago en Stripe'
                              : 'Sin dirección registrada',
                      style: TextStyle(
                        fontSize: 11,
                        color: estadoPago == 'pagado'
                            ? const Color(0xFFD97706)
                            : const Color(0xFF94A3B8),
                      ),
                    )),
                  ]),
                  if (estadoPago == 'pagado') ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _recuperando ? null : () async {
                          Navigator.pop(context);
                          await _recuperarDireccion();
                        },
                        icon: _recuperando
                            ? const SizedBox(width: 12, height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1.5))
                            : const Icon(Icons.refresh_rounded, size: 14),
                        label: Text(_recuperando ? 'Buscando…' : 'Recuperar dirección de Stripe',
                            style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD97706),
                          side: const BorderSide(color: Color(0xFFD97706)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ]),
              ),
            ],
            const SizedBox(height: 20),
            // Acción confirmar transferencia
            if (estadoPago == 'pendiente' && metodoPago == 'transferencia')
              FilledButton.icon(
                onPressed: () { Navigator.pop(context); widget.onConfirmarPago(); },
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Confirmar pago recibido', style: TextStyle(fontSize: 13)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _desgloseFila(String label, String valor, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text(label, style: TextStyle(
              fontSize: 13,
              color: bold ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          const Spacer(),
          Text(valor, style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: bold ? const Color(0xFF0F172A) : const Color(0xFF475569))),
        ]),
      );

  static Widget _seccionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700,
        letterSpacing: 0.5, color: Color(0xFF94A3B8))),
  );

  static Widget _infoFilaDetalle(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
    ]),
  );

  static Widget _coverPlaceholder() => Container(
    width: 44, height: 64,
    decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4)),
    child: const Icon(Icons.menu_book_rounded, size: 20, color: Color(0xFFCBD5E1)),
  );

  Future<void> _recuperarDireccion() async {
    setState(() => _recuperando = true);
    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('recuperarDireccionPedidoNazari')
          .call({'pedidoWebId': widget.id, 'empresaId': widget.empresaId});
      final rData = result.data is Map ? Map<String, dynamic>.from(result.data as Map) : null;
      final dirRaw = rData?['dir'];
      final dirMap = dirRaw is Map ? Map<String, dynamic>.from(dirRaw) : null;
      final dirStr = rData?['direccion'] as String? ?? '';
      if (mounted) {
        if (dirMap != null || dirStr.isNotEmpty) {
          setState(() => _dirRecuperada = dirMap ?? {'linea1': dirStr});
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Dirección: $dirStr'),
            backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se encontró dirección en Stripe para este pedido'),
            backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: ${e.message}'),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _recuperando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);
    final fechaTs = widget.data['fecha_creacion'];
    final fecha = fechaTs is Timestamp
        ? DateFormat('dd/MM HH:mm').format(fechaTs.toDate())
        : '—';
    final fechaLarga = fechaTs is Timestamp
        ? DateFormat('dd/MM/yyyy HH:mm').format(fechaTs.toDate())
        : '—';

    final estadoPago = widget.data['estado_pago'] as String? ?? 'pendiente';
    final metodoPago = widget.data['metodo_pago'] as String? ?? 'stripe';
    final nombre     = widget.data['nombre'] as String? ?? widget.data['cliente_nombre'] as String? ?? '—';
    final email      = widget.data['email']  as String? ?? widget.data['cliente_email']  as String? ?? '';
    final total      = (widget.data['total'] as num?)?.toDouble() ?? 0.0;
    final subtotal   = (widget.data['subtotal'] as num?)?.toDouble();
    final envio      = (widget.data['envio'] as num?)?.toDouble();
    final items      = (widget.data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final dir        = _dirRecuperada ?? widget.data['direccion_envio'] as Map<String, dynamic>?;

    final colorEstado  = _colorEstado(estadoPago, metodoPago);
    final labelEstado  = _labelEstado(estadoPago, metodoPago);
    final numPedido    = '#${widget.id.substring(0, 6).toUpperCase()}';

    // Primer item para mostrar portada
    final primerItem   = items.isNotEmpty ? items.first : <String, dynamic>{};
    final _primerCatId = primerItem['catalogo_id'] as String? ?? '';
    final primerImagen = (primerItem['imagen_url'] as String? ?? '').isNotEmpty
        ? primerItem['imagen_url'] as String
        : widget.catalogoImgs[_primerCatId] ?? '';
    final primerTitulo = primerItem['titulo'] as String? ?? '—';
    final primerCant   = (primerItem['cantidad'] as num?)?.toInt() ?? 1;
    final primerPrecio = (primerItem['precio'] as num?)?.toDouble() ?? 0.0;

    // Barra de estado inferior
    final (IconData statusIcon, Color statusBg, Color statusFg, String statusText) = switch (estadoPago) {
      'pagado'    => (Icons.check_circle_rounded, const Color(0xFFDCFCE7), const Color(0xFF15803D),
                      'Pago confirmado · ${_labelMetodo(metodoPago)} · $fechaLarga'),
      'cancelado' => (Icons.cancel_rounded, const Color(0xFFF1F5F9), const Color(0xFF94A3B8),
                      'Cancelado'),
      _           => metodoPago == 'transferencia'
          ? (Icons.account_balance_rounded, const Color(0xFFFFF7ED), const Color(0xFFD97706),
              'Pendiente de pago · Esperando transferencia')
          : metodoPago == 'bizum'
              ? (Icons.phone_android_rounded, const Color(0xFFEFF6FF), const Color(0xFF1D4ED8),
                  'Pendiente de pago · Esperando Bizum')
              : (Icons.pending_rounded, const Color(0xFFF8FAFC), const Color(0xFF64748B),
                  'En espera'),
    };

    // Dirección en una línea para la columna izquierda
    String dirLinea = '';
    if (dir != null) {
      dirLinea = [dir['linea1'], dir['cp'], dir['ciudad'], dir['pais']]
          .where((v) => v != null && (v as String).isNotEmpty)
          .join(', ');
    }

    final telefono = dir?['telefono'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: colorEstado, width: 4)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: LayoutBuilder(builder: (_, bc) {
        final wide = bc.maxWidth > 560;
        if (wide) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Columna izquierda: cliente ──────────────────────────────
            SizedBox(
              width: 190,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(numPedido, style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(width: 6),
                    _badge(labelEstado, colorEstado),
                  ]),
                  const SizedBox(height: 8),
                  Text(nombre, style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    _infoFila(Icons.email_outlined, email),
                  ],
                  if (telefono.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _infoFila(Icons.phone_outlined, telefono),
                  ],
                  if (dirLinea.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    _infoFila(Icons.location_on_outlined, dirLinea),
                  ] else if (estadoPago == 'pendiente' && metodoPago == 'stripe') ...[
                    const SizedBox(height: 3),
                    _infoFila(Icons.schedule_rounded, 'Dir. pendiente de Stripe'),
                  ],
                ]),
              ),
            ),
            const VerticalDivider(width: 1),
            // ── Centro: libros + estado ─────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Portada
                    if (primerImagen.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(primerImagen, width: 44, height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _coverPlaceholder()),
                      )
                    else _coverPlaceholder(),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(primerTitulo,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text('$primerCant × ${fmt.format(primerPrecio)}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        if (items.length > 1) ...[
                          const SizedBox(height: 2),
                          Text('+ ${items.length - 1} ítem${items.length > 2 ? "s" : ""} más',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                        ],
                      ],
                    )),
                  ]),
                  const SizedBox(height: 10),
                  // Barra de estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                        color: statusBg, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(statusIcon, size: 14, color: statusFg),
                      const SizedBox(width: 7),
                      Expanded(child: Text(statusText,
                          style: TextStyle(fontSize: 11, color: statusFg, fontWeight: FontWeight.w500),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ]),
              ),
            ),
            const VerticalDivider(width: 1),
            // ── Columna derecha: total + botones ───────────────────────
            SizedBox(
              width: 150,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmt.format(total), style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                    const SizedBox(height: 3),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 3),
                      Text(fecha, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _mostrarDetalles(context,
                            nombre: nombre, email: email, dir: dir, items: items,
                            total: total, subtotal: subtotal, envio: envio,
                            estadoPago: estadoPago, metodoPago: metodoPago,
                            fecha: fechaLarga, fmt: fmt, imgs: widget.catalogoImgs),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: estadoPago == 'pagado'
                              ? const Color(0xFF1B5E20) : const Color(0xFF3B82F6),
                          side: BorderSide(
                              color: estadoPago == 'pagado'
                                  ? const Color(0xFF1B5E20) : const Color(0xFF3B82F6)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Ver detalles'),
                      ),
                    ),
                    if (estadoPago == 'pendiente' && metodoPago == 'transferencia') ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: widget.onConfirmarPago,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Confirmar pago'),
                        ),
                      ),
                    ],
                    if (dir == null && estadoPago == 'pagado') ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _recuperando ? null : _recuperarDireccion,
                          icon: _recuperando
                              ? const SizedBox(width: 11, height: 11,
                                  child: CircularProgressIndicator(strokeWidth: 1.5))
                              : const Icon(Icons.location_on_outlined, size: 13),
                          label: Text(_recuperando ? 'Buscando…' : 'Recuperar dirección',
                              style: const TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFD97706),
                            side: const BorderSide(color: Color(0xFFD97706)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            minimumSize: const Size(0, 36),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ]);
        }
        // ── Móvil: compacto ─────────────────────────────────────────────
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          InkWell(
            onTap: () => _mostrarDetalles(context,
                nombre: nombre, email: email, dir: dir, items: items,
                total: total, subtotal: subtotal, envio: envio,
                estadoPago: estadoPago, metodoPago: metodoPago,
                fecha: fechaLarga, fmt: fmt, imgs: widget.catalogoImgs),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                if (primerImagen.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(primerImagen, width: 40, height: 58,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _coverPlaceholder()),
                  )
                else _coverPlaceholder(),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(numPedido,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B))),
                    const SizedBox(width: 6),
                    _badge(labelEstado, colorEstado),
                  ]),
                  const SizedBox(height: 3),
                  Text(nombre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(primerTitulo, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(fmt.format(total),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(fecha, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ]),
              ]),
            ),
          ),
          if (dir == null && estadoPago == 'pagado') ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: OutlinedButton.icon(
                onPressed: _recuperando ? null : _recuperarDireccion,
                icon: _recuperando
                    ? const SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5))
                    : const Icon(Icons.location_on_outlined, size: 14),
                label: Text(_recuperando ? 'Buscando dirección…' : 'Recuperar dirección de Stripe',
                    style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD97706),
                  side: const BorderSide(color: Color(0xFFD97706)),
                  minimumSize: const Size(double.infinity, 36),
                ),
              ),
            ),
          ],
        ]);
      }),
    );
  }

  static Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(
        fontSize: 9, color: color, fontWeight: FontWeight.w700)),
  );

  static Widget _infoFila(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 11, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 4),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
          maxLines: 2, overflow: TextOverflow.ellipsis)),
    ],
  );

  static String _labelMetodo(String m) {
    if (m == 'transferencia') return 'Transferencia';
    if (m == 'bizum') return 'Bizum';
    return 'Stripe';
  }
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

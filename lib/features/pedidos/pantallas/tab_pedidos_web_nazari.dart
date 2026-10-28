import 'dart:convert';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// ignore_for_file: prefer_const_constructors

const _kNazariId = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

// ═══════════════════════════════════════════════════════════════════════════════
// TAB PEDIDOS WEB NAZARÍ — 4 sub-tabs: En curso · Pagados · Incompleto · Cancelados
// ═══════════════════════════════════════════════════════════════════════════════

class TabPedidosWebNazari extends StatefulWidget {
  final String empresaId;
  const TabPedidosWebNazari({super.key, required this.empresaId});

  @override
  State<TabPedidosWebNazari> createState() => _TabPedidosWebNazariState();
}

class _TabPedidosWebNazariState extends State<TabPedidosWebNazari>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchCtrl = TextEditingController();
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Clasificación en tabs ──────────────────────────────────────────────────
  String _tabDe(Map<String, dynamic> d) {
    final estado     = (d['estado']      as String? ?? '').toLowerCase();
    final estadoPago = (d['estado_pago'] as String? ?? '').toLowerCase();
    final metodo     = (d['metodo_pago'] as String? ?? '').toLowerCase();

    if (estado == 'cancelado') return 'cancelado';
    if (estadoPago == 'pagado') return 'pagado';
    if (metodo == 'stripe' && estadoPago != 'pagado') return 'incompleto';
    // transferencia, bizum pendiente o cualquier otro en curso
    return 'en_curso';
  }

  List<QueryDocumentSnapshot> _filtrar(
      List<QueryDocumentSnapshot> docs, String tab) {
    final q = _busqueda.toLowerCase();
    return docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      if (_tabDe(data) != tab) return false;
      if (q.isEmpty) return true;
      // Buscar primero por título de los libros del pedido
      final items = (data['items'] as List?) ?? [];
      final enLibros = items.any((it) {
        final titulo = ((it as Map<String, dynamic>)['titulo'] as String? ?? '').toLowerCase();
        return titulo.contains(q);
      });
      if (enLibros) return true;
      final nombre = (data['nombre'] as String? ?? '').toLowerCase();
      final email  = (data['email']  as String? ?? '').toLowerCase();
      final ref    = (data['ref']    as String? ?? '').toLowerCase();
      return nombre.contains(q) || email.contains(q) || ref.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('pedidos_web_nazari')
          .orderBy('fecha_creacion', descending: true)
          .limit(300)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];

        final enCurso    = docs.where((d) => _tabDe(d.data() as Map<String,dynamic>) == 'en_curso').length;
        final pagados    = docs.where((d) => _tabDe(d.data() as Map<String,dynamic>) == 'pagado').length;
        final incompleto = docs.where((d) => _tabDe(d.data() as Map<String,dynamic>) == 'incompleto').length;
        final cancelados = docs.where((d) => _tabDe(d.data() as Map<String,dynamic>) == 'cancelado').length;

        return Column(children: [
          // ── Buscador ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por título de libro, nombre o email…',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () { _searchCtrl.clear(); setState(() => _busqueda = ''); })
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8F9FB),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF6B7280))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
          // ── Sub-tabs ─────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              indicatorColor: const Color(0xFF6B21A8),
              labelColor: const Color(0xFF6B21A8),
              unselectedLabelColor: const Color(0xFF64748B),
              tabs: [
                _tabLabel('En curso', enCurso, const Color(0xFFF59E0B)),
                _tabLabel('Pagados', pagados, const Color(0xFF10B981)),
                _tabLabel('Incompleto', incompleto, const Color(0xFFEF4444)),
                _tabLabel('Cancelados', cancelados, const Color(0xFF94A3B8)),
              ],
            ),
          ),
          // ── Contenido ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _lista(_filtrar(docs, 'en_curso'),    'Sin pedidos en curso'),
                _lista(_filtrar(docs, 'pagado'),      'Sin pedidos pagados'),
                _lista(_filtrar(docs, 'incompleto'),  'Sin pedidos incompletos'),
                _lista(_filtrar(docs, 'cancelado'),   'Sin pedidos cancelados'),
              ],
            ),
          ),
        ]);
      },
    );
  }

  Tab _tabLabel(String label, int count, Color color) => Tab(
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      if (count > 0) ...[
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
        ),
      ],
    ]),
  );

  Widget _lista(List<QueryDocumentSnapshot> items, String mensajeVacio) {
    if (items.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(mensajeVacio, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final d    = items[i];
        final data = d.data() as Map<String, dynamic>;
        return _PedidoNazariCard(
          docId: d.id,
          data: data,
          empresaId: widget.empresaId,
          onCambioEstado: () => setState(() {}),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CARD de pedido
// ═══════════════════════════════════════════════════════════════════════════════

class _PedidoNazariCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String empresaId;
  final VoidCallback onCambioEstado;

  const _PedidoNazariCard({
    required this.docId,
    required this.data,
    required this.empresaId,
    required this.onCambioEstado,
  });

  @override
  Widget build(BuildContext context) {
    final nombre     = data['nombre']      as String? ?? 'Sin nombre';
    final email      = data['email']       as String? ?? '';
    final total      = (data['total']      as num?)?.toDouble() ?? 0.0;
    final metodo     = data['metodo_pago'] as String? ?? '';
    final estadoPago = data['estado_pago'] as String? ?? 'pendiente';
    final estado     = data['estado']      as String? ?? '';
    final ref        = data['ref']         as String? ?? docId.substring(0, 8).toUpperCase();
    final ts         = (data['fecha_creacion'] as Timestamp?)?.toDate();
    final items      = (data['items'] as List?)?.length ?? 0;

    final (badgeColor, badgeLabel) = _metodoBadge(metodo);
    final (pagoColor,  pagoLabel)  = estadoPago == 'pagado'
        ? (const Color(0xFF10B981), 'Pagado')
        : (const Color(0xFFF59E0B), 'Pendiente');

    final enviado = estado == 'enviado';

    return GestureDetector(
      onTap: () => _abrirDetalle(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Fila superior: badges (wrap) + precio
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Wrap(spacing: 5, runSpacing: 4, children: [
                  _badge('#$ref', const Color(0xFF6B21A8), monospace: true),
                  _badge(badgeLabel, badgeColor),
                  _badge(pagoLabel, pagoColor),
                  if (enviado) _badge('Enviado', const Color(0xFF0EA5E9)),
                ]),
              ),
              const SizedBox(width: 8),
              Text('${total.toStringAsFixed(2)} €',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
            ]),
            const SizedBox(height: 8),
            Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (email.isNotEmpty)
              Text(email, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.shopping_bag_outlined, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text('$items producto${items == 1 ? "" : "s"}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              if (ts != null) ...[
                const SizedBox(width: 10),
                Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(_formatFecha(ts),
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  void _abrirDetalle(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.97,
        expand: false,
        builder: (ctx, scroll) => DetallePedidoNazariSheet(
          docId: docId,
          data: data,
          empresaId: empresaId,
          scrollCtrl: scroll,
          onCambioEstado: onCambioEstado,
        ),
      ),
    );
  }

  static Widget _badge(String label, Color color, {bool monospace = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(5)),
    child: Text(label, style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w700, color: color,
        fontFamily: monospace ? 'monospace' : null)),
  );

  static (Color, String) _metodoBadge(String metodo) => switch (metodo) {
    'stripe'        => (const Color(0xFF6366F1), 'Stripe'),
    'transferencia' => (const Color(0xFF0099DF), 'Transferencia'),
    'bizum'         => (const Color(0xFF0099DF), 'Bizum'),
    'paypal'        => (const Color(0xFF003087), 'PayPal'),
    _               => (const Color(0xFF6B7280), metodo.isEmpty ? 'Desconocido' : metodo),
  };

  static String _formatFecha(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays == 0) return 'Hoy ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7)  return 'Hace ${diff.inDays} días';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DETAIL SHEET — detalle completo de un pedido web Nazarí
// ═══════════════════════════════════════════════════════════════════════════════

class DetallePedidoNazariSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String empresaId;
  final ScrollController scrollCtrl;
  final VoidCallback onCambioEstado;

  const DetallePedidoNazariSheet({
    super.key,
    required this.docId,
    required this.data,
    required this.empresaId,
    required this.scrollCtrl,
    required this.onCambioEstado,
  });

  @override
  State<DetallePedidoNazariSheet> createState() => _DetallePedidoNazariSheetState();
}

class _DetallePedidoNazariSheetState extends State<DetallePedidoNazariSheet> {
  late Map<String, dynamic> _data;
  final _mensajeCtrl = TextEditingController();
  bool _enviandoAccion  = false;
  bool _enviandoMensaje = false;
  bool _mostrarMensaje  = false;

  @override
  void initState() {
    super.initState();
    _data = Map.from(widget.data);
  }

  @override
  void dispose() {
    _mensajeCtrl.dispose();
    super.dispose();
  }

  DocumentReference get _ref => FirebaseFirestore.instance
      .collection('empresas').doc(widget.empresaId)
      .collection('pedidos_web_nazari').doc(widget.docId);

  Future<void> _actualizarLocal() async {
    final snap = await _ref.get();
    if (mounted && snap.exists) setState(() => _data = snap.data() as Map<String, dynamic>);
  }

  Future<void> _marcarEnviado() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marcar como enviado'),
        content: const Text('Se enviará un email al comprador notificando que su pedido está en camino.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
            child: const Text('Marcar enviado'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _enviandoAccion = true);
    try {
      await _callCF('marcarPedidoWebNazariEnviado',
          {'pedidoId': widget.docId, 'empresaId': widget.empresaId});
      await _actualizarLocal();
      widget.onCambioEstado();
      if (mounted) _dialogo('✅ Enviado', 'Pedido marcado como enviado. Email enviado al comprador.');
    } on FirebaseFunctionsException catch (e) {
      // Refrescar aunque falle — la CF puede haber actualizado estado antes de fallar en el email
      await _actualizarLocal();
      widget.onCambioEstado();
      final msg = e.message ?? '';
      if (mounted) _dialogo('Error', msg.isNotEmpty ? msg : 'No se pudo completar la operación.');
    } catch (e) {
      await _actualizarLocal();
      widget.onCambioEstado();
      if (mounted) _dialogo('Error', 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _enviandoAccion = false);
    }
  }

  // Cloud Functions no tiene plugin nativo en Windows → llamada HTTP directa
  Future<void> _callCF(String nombre, Map<String, dynamic> params) async {
    if (!kIsWeb && Platform.isWindows) {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final uri = Uri.parse(
        'https://europe-west1-planeaapp-4bea4.cloudfunctions.net/$nombre',
      );
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'data': params}),
      );
      if (res.statusCode != 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final error = body['error'] as Map<String, dynamic>?;
        throw Exception(error?['message'] ?? 'Error HTTP ${res.statusCode}');
      }
    } else {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable(nombre)
          .call(params);
    }
  }

  void _dialogo(String titulo, String mensaje) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pedido'),
        content: const Text('¿Mover este pedido a Cancelados?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancelar pedido'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _enviandoAccion = true);
    await _ref.update({'estado': 'cancelado'});
    await _actualizarLocal();
    widget.onCambioEstado();
    if (mounted) {
      setState(() => _enviandoAccion = false);
      _snack('Pedido cancelado', const Color(0xFFEF4444));
    }
  }

  Future<void> _moverA(BuildContext context) async {
    final tabActual = _tabActual();
    final opciones = <String, String>{
      if (tabActual != 'en_curso')    'en_curso':   'En curso',
      if (tabActual != 'pagado')      'pagado':     'Pagados',
      if (tabActual != 'cancelado')   'cancelado':  'Cancelados',
    };
    final sel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mover pedido a…'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: opciones.entries.map((e) => ListTile(
            leading: Icon(_iconoTab(e.key), color: _colorTab(e.key)),
            title: Text(e.value),
            onTap: () => Navigator.pop(ctx, e.key),
          )).toList(),
        ),
      ),
    );
    if (sel == null || !mounted) return;
    setState(() => _enviandoAccion = true);
    final update = <String, dynamic>{};
    switch (sel) {
      case 'en_curso':
        update['estado'] = 'pendiente';
        update['estado_pago'] = 'pendiente';
      case 'pagado':
        update['estado_pago'] = 'pagado';
        update['estado'] = 'pendiente';
        update['fecha_pago'] = FieldValue.serverTimestamp();
      case 'cancelado':
        update['estado'] = 'cancelado';
    }
    await _ref.update(update);
    await _actualizarLocal();
    widget.onCambioEstado();
    if (mounted) {
      setState(() => _enviandoAccion = false);
      _snack('Pedido movido a ${opciones[sel]}', const Color(0xFF6B21A8));
    }
  }

  Future<void> _enviarMensaje() async {
    final texto = _mensajeCtrl.text.trim();
    if (texto.isEmpty) return;
    setState(() => _enviandoMensaje = true);
    try {
      await _callCF('enviarMensajePedidoWebNazari', {
        'pedidoId': widget.docId,
        'empresaId': widget.empresaId,
        'mensaje': texto,
      });
      _mensajeCtrl.clear();
      if (mounted) {
        setState(() { _enviandoMensaje = false; _mostrarMensaje = false; });
        _snack('✅ Mensaje enviado al comprador', Colors.green);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _enviandoMensaje = false);
        _snack('Error: ${e.message}', Colors.red);
      }
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _tabActual() {
    final estado     = (_data['estado']      as String? ?? '').toLowerCase();
    final estadoPago = (_data['estado_pago'] as String? ?? '').toLowerCase();
    final metodo     = (_data['metodo_pago'] as String? ?? '').toLowerCase();
    if (estado == 'cancelado') return 'cancelado';
    if (estadoPago == 'pagado') return 'pagado';
    if (metodo == 'stripe' && estadoPago != 'pagado') return 'incompleto';
    return 'en_curso';
  }

  @override
  Widget build(BuildContext context) {
    final nombre     = _data['nombre']      as String? ?? 'Sin nombre';
    final email      = _data['email']       as String? ?? '';
    final telefono   = _data['telefono']    as String? ?? '';
    final total      = (_data['total']      as num?)?.toDouble() ?? 0.0;
    final metodo     = _data['metodo_pago'] as String? ?? '';
    final estadoPago = _data['estado_pago'] as String? ?? 'pendiente';
    final estado     = _data['estado']      as String? ?? '';
    final ref        = _data['ref']         as String? ?? widget.docId.substring(0, 8).toUpperCase();
    final items      = (_data['items'] as List?) ?? [];
    final enviado    = estado == 'enviado';
    final cancelado  = estado == 'cancelado';
    final tsCreacion = (_data['fecha_creacion'] as Timestamp?)?.toDate();
    final tsPago     = (_data['fecha_pago']     as Timestamp?)?.toDate();
    final tsEnvio    = (_data['fecha_envio']    as Timestamp?)?.toDate();

    // Dirección
    final dirRaw = _data['direccion_envio'];
    final dir = dirRaw is Map ? _formatDir(dirRaw) : (dirRaw as String? ?? '');

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // Handle
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF6B21A8).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shopping_bag_rounded, color: Color(0xFF6B21A8), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pedido #$ref',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
              Text(nombre, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${total.toStringAsFixed(2)} €',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF6B21A8))),
              _badgePago(estadoPago),
            ]),
          ]),
        ),
        Expanded(child: ListView(
          controller: widget.scrollCtrl,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
          children: [
            // ── Método de pago ─────────────────────────────────────────────
            _card(
              icon: Icons.payment_rounded,
              color: const Color(0xFF6366F1),
              titulo: 'Pago',
              child: Column(children: [
                _fila('Método', _labelMetodo(metodo), Icons.credit_card_outlined),
                _fila('Estado', estadoPago == 'pagado' ? 'Pagado ✓' : 'Pendiente', Icons.check_circle_outline),
                if (enviado) _fila('Envío', 'Enviado ✓', Icons.local_shipping_outlined),
                if (tsCreacion != null) _fila('Fecha pedido', _fmtLarga(tsCreacion), Icons.calendar_today_outlined),
                if (tsPago != null) _fila('Fecha pago', _fmtLarga(tsPago), Icons.event_available_outlined),
                if (tsEnvio != null) _fila('Fecha envío', _fmtLarga(tsEnvio), Icons.local_shipping_outlined),
              ]),
            ),
            const SizedBox(height: 10),

            // ── Productos ──────────────────────────────────────────────────
            _card(
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFF3B82F6),
              titulo: 'Productos (${items.length})',
              child: Column(children: [
                ...items.map((item) {
                  final it = Map<String, dynamic>.from(item as Map);
                  final titulo   = it['titulo'] as String? ?? 'Producto';
                  final cantidad = (it['cantidad'] as num?)?.toInt() ?? 1;
                  final precio   = (it['precio']   as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5)),
                        child: Center(child: Text('${cantidad}x',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                                color: Color(0xFF3B82F6))))),
                      const SizedBox(width: 8),
                      Expanded(child: Text(titulo,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                      Text('${(precio * cantidad).toStringAsFixed(2)} €',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                              color: Color(0xFF3B82F6))),
                    ]),
                  );
                }),
                const Divider(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  Text('${total.toStringAsFixed(2)} €',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
                          color: Color(0xFF3B82F6))),
                ]),
              ]),
            ),
            const SizedBox(height: 10),

            // ── Cliente ────────────────────────────────────────────────────
            _card(
              icon: Icons.person_rounded,
              color: const Color(0xFF8B5CF6),
              titulo: 'Cliente',
              child: Column(children: [
                _fila('Nombre', nombre, Icons.person_outline),
                if (email.isNotEmpty)
                  GestureDetector(
                    onTap: () => Clipboard.setData(ClipboardData(text: email)),
                    child: _fila('Email', email, Icons.email_outlined),
                  ),
                if (telefono.isNotEmpty)
                  _fila('Teléfono', telefono, Icons.phone_outlined),
                if (dir.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.local_shipping_outlined, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    const Text('Dirección', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(dir,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                        textAlign: TextAlign.right)),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 14),

            // ── Acciones ───────────────────────────────────────────────────
            if (!cancelado) ...[
              if (!enviado)
                _accionBtn(
                  label: 'Marcar enviado',
                  icon: Icons.local_shipping_rounded,
                  color: const Color(0xFF0EA5E9),
                  onTap: _enviandoAccion ? null : _marcarEnviado,
                  loading: _enviandoAccion,
                )
              else
                _enviadoNotice(),
              const SizedBox(height: 8),
              _accionBtn(
                label: 'Mover a…',
                icon: Icons.swap_horiz_rounded,
                color: const Color(0xFF6B21A8),
                onTap: _enviandoAccion ? null : () => _moverA(context),
                loading: false,
                outlined: true,
              ),
              const SizedBox(height: 8),
              _accionBtn(
                label: 'Cancelar pedido',
                icon: Icons.cancel_outlined,
                color: Colors.red,
                onTap: _enviandoAccion ? null : _cancelar,
                loading: false,
                outlined: true,
              ),
            ] else
              _accionBtn(
                label: 'Restaurar a En curso',
                icon: Icons.restore_rounded,
                color: const Color(0xFFF59E0B),
                onTap: _enviandoAccion ? null : () => _moverA(context),
                loading: false,
                outlined: true,
              ),

            const SizedBox(height: 14),

            // ── Enviar mensaje ──────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(children: [
                InkWell(
                  onTap: () => setState(() => _mostrarMensaje = !_mostrarMensaje),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.mail_outline_rounded, size: 18, color: Color(0xFF6B7280)),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Enviar mensaje al comprador',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Icon(_mostrarMensaje ? Icons.expand_less : Icons.expand_more,
                          color: const Color(0xFF64748B)),
                    ]),
                  ),
                ),
                if (_mostrarMensaje)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(children: [
                      TextField(
                        controller: _mensajeCtrl,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: 'Escribe aquí el mensaje para el comprador. Se enviará por email incluyendo la información de su pedido.',
                          hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                          hintMaxLines: 3,
                          filled: true, fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                          contentPadding: const EdgeInsets.all(10),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _enviandoMensaje ? null : _enviarMensaje,
                          icon: _enviandoMensaje
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send_rounded, size: 15),
                          label: Text(_enviandoMensaje ? 'Enviando…' : 'Enviar mensaje'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B21A8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
          ],
        )),
      ]),
    );
  }

  // ── Helpers UI ────────────────────────────────────────────────────────────

  Widget _card({required IconData icon, required Color color,
      required String titulo, required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 26, height: 26,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 14, color: color)),
        const SizedBox(width: 8),
        Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
      ]),
      const SizedBox(height: 10),
      child,
    ]),
  );

  Widget _fila(String label, String valor, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      const Spacer(),
      Flexible(child: Text(valor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: Color(0xFF0F172A)), textAlign: TextAlign.right)),
    ]),
  );

  Widget _accionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    required bool loading,
    bool outlined = false,
  }) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 16),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: loading
            ? const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          padding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }

  Widget _badgePago(String estadoPago) {
    final (color, label) = estadoPago == 'pagado'
        ? (const Color(0xFF10B981), 'Pagado')
        : (const Color(0xFFF59E0B), 'Pendiente pago');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  static String _formatDir(Map dir) {
    final partes = [
      dir['nombre'], dir['linea1'], dir['linea2'],
      dir['ciudad'], dir['provincia'], dir['cp'], dir['pais'],
    ].where((v) => v != null && v.toString().trim().isNotEmpty).toList();
    return partes.join(', ');
  }

  static String _labelMetodo(String m) => switch (m) {
    'stripe'        => 'Tarjeta (Stripe)',
    'transferencia' => 'Transferencia bancaria',
    'bizum'         => 'Bizum',
    'paypal'        => 'PayPal',
    'simulacion'    => 'Simulación (test)',
    _               => m.isEmpty ? 'Desconocido' : m,
  };

  static Color _colorTab(String tab) => switch (tab) {
    'en_curso'   => const Color(0xFFF59E0B),
    'pagado'     => const Color(0xFF10B981),
    'incompleto' => const Color(0xFFEF4444),
    'cancelado'  => const Color(0xFF94A3B8),
    _            => const Color(0xFF6B7280),
  };

  static IconData _iconoTab(String tab) => switch (tab) {
    'en_curso'   => Icons.hourglass_top_rounded,
    'pagado'     => Icons.check_circle_outline_rounded,
    'incompleto' => Icons.warning_amber_rounded,
    'cancelado'  => Icons.cancel_outlined,
    _            => Icons.circle_outlined,
  };

  Widget _enviadoNotice() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.local_shipping_rounded, color: Color(0xFF0EA5E9), size: 16),
      const SizedBox(width: 8),
      const Text('Pedido ya marcado como enviado',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0EA5E9))),
    ]),
  );

  static String _fmtLarga(DateTime d) {
    final dd  = d.day.toString().padLeft(2, '0');
    final mm  = d.month.toString().padLeft(2, '0');
    final hh  = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}  $hh:$min';
  }
}

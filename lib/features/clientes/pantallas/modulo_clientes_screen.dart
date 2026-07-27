import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/firebase/firestore_stream_helper.dart';
import '../../../core/platform/platform_data_source.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../services/clientes_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// MÓDULO CLIENTES — blue accent, dark/light, tarjetas compactas
// ═════════════════════════════════════════════════════════════════════════════

class ModuloClientesScreen extends StatefulWidget {
  final String empresaId;
  final SesionUsuario? sesion;
  const ModuloClientesScreen({super.key, required this.empresaId, this.sesion});
  @override
  State<ModuloClientesScreen> createState() => _ModuloClientesScreenState();
}

class _ModuloClientesScreenState extends State<ModuloClientesScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _helper    = FirestoreStreamHelper();
  bool   _dark     = false;
  String _busqueda = '';
  String _filtroTag = 'todos';
  String _sortBy   = 'nombre'; // 'nombre' | 'total' | 'visita' | 'reciente'

  static const _kAzul   = Color(0xFF3B82F6);
  static const _kVerde  = Color(0xFF22C55E);
  static const _kAmbar  = Color(0xFFEAB308);
  static const _kRojo   = Color(0xFFEF4444);
  static const _kMorado = Color(0xFF8B5CF6);
  static const _kRosa   = Color(0xFFEC4899);

  Color get _bg      => _dark ? const Color(0xFF05060A) : const Color(0xFFF4F6FB);
  Color get _panel   => _dark ? const Color(0xFF0D1117) : Colors.white;
  Color get _border  => _dark ? const Color(0x14FFFFFF) : const Color(0x14000000);
  Color get _text    => _dark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _soft    => _dark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get _inputBg => _dark ? const Color(0x08FFFFFF) : const Color(0xFFF8FAFC);

  Color _avatarColor(String nombre) {
    const cols = [_kAzul, _kVerde, _kAmbar, _kMorado, _kRosa, _kRojo,
                  Color(0xFF0891B2), Color(0xFF16A34A), Color(0xFF9333EA)];
    if (nombre.isEmpty) return _kAzul;
    return cols[nombre.codeUnitAt(0) % cols.length];
  }

  // ── Parseo seguro de fechas Firestore (Timestamp o String) ────────────────
  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        _glow(_kAzul,   top: -160, left: -100),
        _glow(_kMorado, top:  200, right: -120),
        SafeArea(child: Column(children: [
          _buildTopBar(),
          Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: _helper.collectionStream(
              _firestore.collection('empresas').doc(widget.empresaId)
                  .collection('clientes').orderBy('nombre'),
              priority: PollingPriority.high,
            ),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting && (snap.data?.docs.isEmpty ?? true)) {
                return const Center(child: CircularProgressIndicator(color: _kAzul));
              }
              final docs = snap.data?.docs ?? [];
              var clientes = ClientesService.filtrarClientes(
                docs: docs, textoBusqueda: _busqueda,
                etiquetasActivas: _filtroTag == 'todos' ? {} : {_filtroTag},
              );

              // Ordenación
              clientes = _sortClientes(clientes);

              // KPIs
              final total   = docs.length;
              final mes30   = DateTime.now().subtract(const Duration(days: 30));
              final activos = docs.where((d) {
                final m = d.data() as Map<String, dynamic>;
                final uv = _parseDate(m['ultima_visita'] ?? m['ultima_actividad']);
                return uv != null && uv.isAfter(mes30);
              }).length;
              final vips    = docs.where((d) =>
                ((d.data() as Map)['etiquetas'] as List?)?.contains('VIP') == true).length;
              final nuevos  = docs.where((d) {
                final dt = _parseDate((d.data() as Map)['fecha_registro']);
                return dt != null && dt.isAfter(mes30);
              }).length;
              final totalGasto = docs.fold(0.0, (s, d) =>
                s + (((d.data() as Map)['total_gastado'] ?? 0) as num).toDouble());

              return CustomScrollView(slivers: [
                // KPIs
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  child: Row(children: [
                    _kpi('$total',    'Clientes',  _kAzul),   const SizedBox(width: 8),
                    _kpi('$activos',  'Activos',   _kVerde),  const SizedBox(width: 8),
                    _kpi('$vips',     'VIP',       _kAmbar),  const SizedBox(width: 8),
                    _kpi('${totalGasto.toStringAsFixed(0)}€', 'Facturado', _kRosa),
                  ]),
                )),
                // Toolbar: búsqueda + sort + añadir
                SliverToBoxAdapter(child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: Row(children: [
                    Expanded(child: _searchBox()),
                    const SizedBox(width: 8),
                    _sortBtn(),
                    const SizedBox(width: 8),
                    _addBtn(() => _mostrarPopupCliente()),
                  ]),
                )),
                // Filtro etiquetas
                SliverToBoxAdapter(child: _buildTagFilter(docs)),
                // Contador
                if (clientes.isNotEmpty)
                  SliverToBoxAdapter(child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    child: Text('${clientes.length} cliente${clientes.length != 1 ? 's' : ''}',
                      style: TextStyle(fontSize: 11.5, color: _soft, fontFamily: 'monospace')),
                  )),
                // Lista
                if (clientes.isEmpty)
                  SliverFillRemaining(child: _empty())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
                    sliver: SliverList(delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final d = clientes[i].data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _clienteCard(clientes[i].id, d),
                        );
                      },
                      childCount: clientes.length,
                    )),
                  ),
              ]);
            },
          )),
        ])),
      ]),
    );
  }

  List<QueryDocumentSnapshot> _sortClientes(List<QueryDocumentSnapshot> list) {
    final sorted = List<QueryDocumentSnapshot>.from(list);
    sorted.sort((a, b) {
      final ma = a.data() as Map<String, dynamic>;
      final mb = b.data() as Map<String, dynamic>;
      switch (_sortBy) {
        case 'total':
          final ta = ((ma['total_gastado'] ?? 0) as num).toDouble();
          final tb = ((mb['total_gastado'] ?? 0) as num).toDouble();
          return tb.compareTo(ta);
        case 'visita':
          final va = _parseDate(ma['ultima_visita']) ?? DateTime(2000);
          final vb = _parseDate(mb['ultima_visita']) ?? DateTime(2000);
          return vb.compareTo(va);
        case 'reciente':
          final ra = _parseDate(ma['fecha_registro']) ?? DateTime(2000);
          final rb = _parseDate(mb['fecha_registro']) ?? DateTime(2000);
          return rb.compareTo(ra);
        default: // nombre
          return (ma['nombre'] ?? '').toString().toLowerCase()
              .compareTo((mb['nombre'] ?? '').toString().toLowerCase());
      }
    });
    return sorted;
  }

  // ── Glow ─────────────────────────────────────────────────────────────────
  Widget _glow(Color c, {double? top, double? left, double? right}) =>
      Positioned(top: top, left: left, right: right,
        child: IgnorePointer(child: Container(width: 340, height: 340,
          decoration: BoxDecoration(shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: c.withValues(alpha: _dark ? 0.18 : 0.06),
              blurRadius: 110, spreadRadius: 40)]))));

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() => Container(
    padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
    decoration: BoxDecoration(
      color: _panel.withValues(alpha: 0.9),
      border: Border(bottom: BorderSide(color: _border))),
    child: Row(children: [
      IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: _soft, size: 18),
        onPressed: () => Navigator.of(context).pop()),
      Container(width: 32, height: 32,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(9),
          gradient: LinearGradient(colors: [_kAzul.withValues(alpha: 0.18), _kAzul.withValues(alpha: 0.04)]),
          border: Border.all(color: _kAzul.withValues(alpha: 0.35))),
        child: const Icon(Icons.people_alt_rounded, color: _kAzul, size: 16)),
      const SizedBox(width: 10),
      Text('Clientes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _text)),
      const Spacer(),
      GestureDetector(
        onTap: () => setState(() => _dark = !_dark),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 44, height: 22,
          decoration: BoxDecoration(
            color: _dark ? const Color(0xFF1E2A3A) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _dark ? _kAzul.withValues(alpha: 0.4) : const Color(0xFFCBD5E1))),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 280), curve: Curves.easeInOutCubic,
            alignment: _dark ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(width: 16, height: 16, margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(shape: BoxShape.circle,
                gradient: LinearGradient(colors: _dark
                  ? [const Color(0xFF3B82F6), const Color(0xFF2563EB)]
                  : [const Color(0xFFF59E0B), const Color(0xFFD97706)])),
              child: Icon(_dark ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded, size: 9, color: Colors.white)),
          ),
        ),
      ),
    ]),
  );

  // ── Filtro etiquetas ──────────────────────────────────────────────────────
  Widget _buildTagFilter(List<QueryDocumentSnapshot> docs) {
    final allTags = <String>{};
    for (final d in docs) {
      final m = d.data() as Map<String, dynamic>;
      final tags = (m['etiquetas'] as List?)?.cast<String>() ?? [];
      allTags.addAll(tags);
    }
    if (allTags.isEmpty) return const SizedBox(height: 8);
    final tags = ['todos', ...allTags];
    return SizedBox(height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemCount: tags.length,
        itemBuilder: (_, i) {
          final tag = tags[i];
          final sel = _filtroTag == tag;
          return GestureDetector(
            onTap: () => setState(() => _filtroTag = tag),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? _kAzul : _inputBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? _kAzul : _border)),
              child: Text(tag == 'todos' ? 'Todos' : tag,
                style: TextStyle(fontSize: 11.5, fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                  color: sel ? Colors.white : _soft)),
            ),
          );
        },
      ),
    );
  }

  // ── Tarjeta compacta y profesional ────────────────────────────────────────
  Widget _clienteCard(String id, Map<String, dynamic> d) {
    final nombre    = (d['nombre'] ?? '') as String;
    final telefono  = (d['telefono'] ?? '') as String;
    final correo    = (d['correo'] ?? '') as String;
    final total     = ((d['total_gastado'] ?? 0) as num).toDouble();
    final reservas  = ((d['numero_reservas'] ?? 0) as num).toInt();
    final etiquetas = (d['etiquetas'] as List?)?.cast<String>() ?? <String>[];
    final ultimaVisita  = _parseDate(d['ultima_visita'] ?? d['ultima_actividad']);
    final fechaRegistro = _parseDate(d['fecha_registro']);
    final avatarColor   = _avatarColor(nombre);
    final iniciales     = nombre.trim().split(' ').take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
    final mes30    = DateTime.now().subtract(const Duration(days: 30));
    final isActivo = ultimaVisita != null && ultimaVisita.isAfter(mes30);
    final ticketMedio = reservas > 0 ? (total / reservas) : 0.0;

    return GestureDetector(
      onTap: () => _mostrarDetalleCliente(id, d),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _panel, borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _border),
          boxShadow: _dark ? [] : [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          // Fila superior: avatar + nombre/correo + etiqueta + acciones
          Row(children: [
            // Avatar con indicador de actividad
            Stack(children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11), color: avatarColor),
                child: Center(child: Text(iniciales.isEmpty ? '?' : iniciales,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)))),
              Positioned(bottom: 1, right: 1, child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: isActivo ? _kVerde : _soft.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(color: _panel, width: 1.5)),
              )),
            ]),
            const SizedBox(width: 11),
            // Nombre + correo/teléfono
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre.isEmpty ? 'Sin nombre' : nombre,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _text),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              if (correo.isNotEmpty || telefono.isNotEmpty)
                Text(correo.isNotEmpty ? correo : telefono,
                  style: TextStyle(fontSize: 11, color: _soft),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            // Etiqueta (si tiene)
            if (etiquetas.isNotEmpty) ...[
              _tag(etiquetas.first),
              const SizedBox(width: 4),
            ],
            // Acciones rápidas
            if (telefono.isNotEmpty)
              _iconAction(Icons.phone_outlined, _kVerde, () =>
                launchUrl(Uri.parse('tel:$telefono'))),
            if (correo.isNotEmpty)
              _iconAction(Icons.email_outlined, _kAzul, () =>
                launchUrl(Uri.parse('mailto:$correo'))),
          ]),
          const SizedBox(height: 10),
          // Fila inferior: stats
          Container(
            padding: const EdgeInsets.fromLTRB(0, 9, 0, 0),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: _border))),
            child: Row(children: [
              _stat('VISITAS', '$reservas'),
              _statDiv(),
              _stat('GASTO', '${total.toStringAsFixed(0)}€'),
              if (ticketMedio > 0) ...[
                _statDiv(),
                _stat('TICKET MEDIO', '${ticketMedio.toStringAsFixed(0)}€'),
              ],
              if (ultimaVisita != null) ...[
                _statDiv(),
                _stat('ÚLTIMA', DateFormat('dd/MM/yy').format(ultimaVisita)),
              ] else if (fechaRegistro != null) ...[
                _statDiv(),
                _stat('REGISTRO', DateFormat('dd/MM/yy').format(fechaRegistro)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 8.5, color: _soft, fontFamily: 'monospace', letterSpacing: 0.3)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _text),
        overflow: TextOverflow.ellipsis),
    ]));

  Widget _statDiv() => Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 8),
    color: _border);

  Widget _iconAction(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30, height: 30, margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Icon(icon, color: color, size: 14)));

  Widget _tag(String tag) {
    const colors = {
      'VIP': _kAmbar, 'Frecuente': _kVerde, 'Moroso': _kRojo,
      'Proveedor': _kAzul, 'Potencial': _kMorado,
    };
    final color = colors[tag] ?? _kAzul;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.35))),
      child: Text(tag, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)));
  }

  // ── Detalle cliente ───────────────────────────────────────────────────────
  void _mostrarDetalleCliente(String id, Map<String, dynamic> d) {
    final nombre    = (d['nombre'] ?? '') as String;
    final telefono  = (d['telefono'] ?? '') as String;
    final correo    = (d['correo'] ?? '') as String;
    final notas     = (d['notas'] ?? '') as String;
    final total     = ((d['total_gastado'] ?? 0) as num).toDouble();
    final reservas  = ((d['numero_reservas'] ?? 0) as num).toInt();
    final etiquetas = (d['etiquetas'] as List?)?.cast<String>() ?? <String>[];
    final ultima    = _parseDate(d['ultima_visita'] ?? d['ultima_actividad']);
    final registro  = _parseDate(d['fecha_registro']);
    final avatar    = _avatarColor(nombre);
    final iniciales = nombre.trim().split(' ').take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();
    final ticketMedio = reservas > 0 ? (total / reservas) : 0.0;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.82),
        decoration: BoxDecoration(color: _panel,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: _border)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14), color: avatar),
                child: Center(child: Text(iniciales.isEmpty ? '?' : iniciales,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre.isEmpty ? 'Sin nombre' : nombre,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _text)),
                if (correo.isNotEmpty) Text(correo, style: TextStyle(fontSize: 12, color: _soft)),
                if (etiquetas.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 4, children: etiquetas.map(_tag).toList())),
              ])),
              GestureDetector(
                onTap: () { Navigator.pop(ctx); _mostrarPopupCliente({'id': id, ...d}); },
                child: Container(width: 30, height: 30, decoration: BoxDecoration(
                  color: _inputBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
                  child: Icon(Icons.edit_outlined, size: 15, color: _soft))),
            ])),
          // Stats rápidos
          Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              _detailKpi(Icons.shopping_bag_outlined, _kAzul, '$reservas', 'Visitas'),
              const SizedBox(width: 10),
              _detailKpi(Icons.euro_rounded, _kVerde, '${total.toStringAsFixed(0)}€', 'Facturado'),
              const SizedBox(width: 10),
              if (ticketMedio > 0)
                _detailKpi(Icons.receipt_outlined, _kAmbar, '${ticketMedio.toStringAsFixed(0)}€', 'Ticket medio'),
            ])),
          Divider(height: 24, indent: 20, endIndent: 20, color: _border),
          Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(children: [
              if (telefono.isNotEmpty)
                _infoRow(Icons.phone_outlined, 'TELÉFONO', telefono,
                  onTap: () => launchUrl(Uri.parse('tel:$telefono'))),
              if (correo.isNotEmpty)
                _infoRow(Icons.email_outlined, 'CORREO', correo,
                  onTap: () => launchUrl(Uri.parse('mailto:$correo'))),
              if (ultima != null)
                _infoRow(Icons.schedule_outlined, 'ÚLTIMA VISITA',
                  DateFormat('dd MMMM yyyy', 'es').format(ultima)),
              if (registro != null)
                _infoRow(Icons.person_add_outlined, 'CLIENTE DESDE',
                  DateFormat('dd MMMM yyyy', 'es').format(registro)),
              if (notas.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 12),
                  child: Container(width: double.infinity, padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border)),
                    child: Text(notas, style: TextStyle(fontSize: 13, color: _soft, height: 1.5)))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await showDialog<bool>(context: context,
                      builder: (c) => AlertDialog(
                        backgroundColor: _panel,
                        title: Text('Eliminar cliente', style: TextStyle(color: _text)),
                        content: Text('¿Eliminar a $nombre?', style: TextStyle(color: _soft)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                          TextButton(onPressed: () => Navigator.pop(c, true),
                            style: TextButton.styleFrom(foregroundColor: _kRojo),
                            child: const Text('Eliminar')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await _firestore.collection('empresas').doc(widget.empresaId)
                          .collection('clientes').doc(id).delete();
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 15),
                  label: const Text('Eliminar'),
                  style: OutlinedButton.styleFrom(foregroundColor: _kRojo,
                    side: BorderSide(color: _kRojo.withValues(alpha: 0.4))),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _mostrarPopupCliente({'id': id, ...d}); },
                  icon: const Icon(Icons.edit_outlined, size: 15),
                  label: const Text('Editar'),
                  style: ElevatedButton.styleFrom(backgroundColor: _kAzul, foregroundColor: Colors.white,
                    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                )),
              ]),
              const SizedBox(height: 8),
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _detailKpi(IconData icon, Color color, String value, String label) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _text)),
        Text(label, style: TextStyle(fontSize: 10, color: _soft)),
      ]),
    ]),
  ));

  Widget _infoRow(IconData icon, String label, String value, {VoidCallback? onTap}) => GestureDetector(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Icon(icon, size: 16, color: _soft),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 9.5, color: _soft, fontFamily: 'monospace')),
          const SizedBox(height: 1),
          Text(value, style: TextStyle(fontSize: 13, color: onTap != null ? _kAzul : _text,
            decoration: onTap != null ? TextDecoration.underline : null)),
        ]),
      ]),
    ),
  );

  // ── Popup añadir / editar ─────────────────────────────────────────────────
  void _mostrarPopupCliente([Map<String, dynamic>? data]) {
    final esEdicion  = data != null && data.containsKey('id');
    final id         = esEdicion ? data['id'] as String : null;
    final nombreCtrl = TextEditingController(text: data?['nombre'] ?? '');
    final telCtrl    = TextEditingController(text: data?['telefono'] ?? '');
    final correoCtrl = TextEditingController(text: data?['correo'] ?? '');
    final nifCtrl    = TextEditingController(text: data?['nif'] ?? '');
    final dirCtrl    = TextEditingController(text: data?['direccion'] ?? '');
    final notasCtrl  = TextEditingController(text: data?['notas'] ?? '');
    final etiqSel    = <String>{...((data?['etiquetas'] as List?)?.cast<String>() ?? <String>[])};
    bool guardando   = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.9),
            decoration: BoxDecoration(color: _panel,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(color: _border)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 10),
              Container(width: 36, height: 4,
                decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(children: [
                  Container(width: 32, height: 32, decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: LinearGradient(colors: [_kAzul.withValues(alpha: 0.18), _kAzul.withValues(alpha: 0.04)]),
                    border: Border.all(color: _kAzul.withValues(alpha: 0.3))),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: _kAzul, size: 16)),
                  const SizedBox(width: 10),
                  Text(esEdicion ? 'Editar cliente' : 'Nuevo cliente',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
                  const Spacer(),
                  GestureDetector(onTap: () => Navigator.pop(ctx),
                    child: Icon(Icons.close_rounded, size: 20, color: _soft)),
                ])),
              Divider(height: 20, indent: 20, endIndent: 20, color: _border),
              Flexible(child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _popupField(nombreCtrl, 'NOMBRE *', 'Ej. Juan García'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _popupField(telCtrl, 'TELÉFONO', '+34 600 000 000')),
                    const SizedBox(width: 10),
                    Expanded(child: _popupField(correoCtrl, 'CORREO', 'juan@mail.com')),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _popupField(nifCtrl, 'NIF / CIF', '12345678A')),
                    const SizedBox(width: 10),
                    Expanded(child: _popupField(dirCtrl, 'DIRECCIÓN', 'Calle...')),
                  ]),
                  const SizedBox(height: 10),
                  _popupField(notasCtrl, 'NOTAS', 'Preferencias, observaciones...', maxLines: 2),
                  const SizedBox(height: 12),
                  Text('ETIQUETAS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: _soft, letterSpacing: 0.4, fontFamily: 'monospace')),
                  const SizedBox(height: 7),
                  Wrap(spacing: 7, runSpacing: 7,
                    children: kEtiquetasPredefinidas.map((tag) {
                      final sel = etiqSel.contains(tag);
                      const colors = {'VIP': _kAmbar, 'Frecuente': _kVerde, 'Moroso': _kRojo,
                        'Proveedor': _kAzul, 'Potencial': _kMorado};
                      final color = colors[tag] ?? _kAzul;
                      return GestureDetector(
                        onTap: () => setS(() { sel ? etiqSel.remove(tag) : etiqSel.add(tag); }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: sel ? color.withValues(alpha: 0.15) : _inputBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sel ? color.withValues(alpha: 0.5) : _border)),
                          child: Text(tag, style: TextStyle(fontSize: 12,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                            color: sel ? color : _soft))));
                    }).toList()),
                  const SizedBox(height: 20),
                ]),
              )),
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Row(children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(foregroundColor: _soft),
                    child: const Text('Cancelar')),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: guardando ? null : () async {
                      final nombre = nombreCtrl.text.trim();
                      if (nombre.isEmpty) return;
                      setS(() => guardando = true);
                      try {
                        final datos = {
                          'nombre': nombre,
                          'telefono': telCtrl.text.trim(),
                          'correo': correoCtrl.text.trim(),
                          if (nifCtrl.text.trim().isNotEmpty) 'nif': nifCtrl.text.trim(),
                          if (dirCtrl.text.trim().isNotEmpty) 'direccion': dirCtrl.text.trim(),
                          if (notasCtrl.text.trim().isNotEmpty) 'notas': notasCtrl.text.trim(),
                          'etiquetas': etiqSel.toList(),
                          'activo': true,
                        };
                        final col = _firestore.collection('empresas')
                            .doc(widget.empresaId).collection('clientes');
                        if (esEdicion) {
                          await col.doc(id).update(datos);
                        } else {
                          datos['fecha_registro'] = Timestamp.now();
                          datos['total_gastado']  = 0.0;
                          datos['numero_reservas'] = 0;
                          await col.add(datos);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      } finally {
                        if (ctx.mounted) setS(() => guardando = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _kAzul, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                    child: guardando
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(esEdicion ? 'Guardar' : 'Crear cliente',
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                ])),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _popupField(TextEditingController ctrl, String label, String hint, {int maxLines = 1}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
        color: _soft, letterSpacing: 0.4, fontFamily: 'monospace')),
      const SizedBox(height: 5),
      TextField(controller: ctrl, maxLines: maxLines,
        style: TextStyle(color: _text, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: _soft.withValues(alpha: 0.5), fontSize: 13),
          filled: true, fillColor: _inputBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kAzul, width: 1.5)))),
    ]);

  // ── Helpers UI ────────────────────────────────────────────────────────────
  Widget _kpi(String num, String label, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border)),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(top: -12, right: -12, child: Container(width: 44, height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 16, spreadRadius: 8)]))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(num, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _text),
            overflow: TextOverflow.ellipsis),
          const SizedBox(height: 1),
          Text(label, style: TextStyle(fontSize: 9.5, color: _soft), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ]),
    ),
  );

  Widget _searchBox() => Container(
    height: 36,
    decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _border)),
    child: TextField(
      onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
      style: TextStyle(color: _text, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Buscar cliente...',
        hintStyle: TextStyle(color: _soft, fontSize: 12.5),
        prefixIcon: Icon(Icons.search, color: _soft, size: 16),
        border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 8)),
    ),
  );

  Widget _sortBtn() => PopupMenuButton<String>(
    onSelected: (v) => setState(() => _sortBy = v),
    color: _panel,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _border)),
    child: Container(height: 36, width: 36,
      decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border)),
      child: Icon(Icons.sort_rounded, color: _soft, size: 18)),
    itemBuilder: (_) => [
      _sortItem('nombre',  'Nombre',         Icons.sort_by_alpha),
      _sortItem('total',   'Mayor gasto',    Icons.euro_rounded),
      _sortItem('visita',  'Última visita',  Icons.schedule_outlined),
      _sortItem('reciente','Más recientes',  Icons.fiber_new_outlined),
    ],
  );

  PopupMenuItem<String> _sortItem(String val, String label, IconData icon) =>
    PopupMenuItem(value: val, child: Row(children: [
      Icon(icon, size: 16, color: _sortBy == val ? _kAzul : _soft),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 13, color: _sortBy == val ? _kAzul : _text,
        fontWeight: _sortBy == val ? FontWeight.w700 : FontWeight.normal)),
    ]));

  Widget _addBtn(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 36, width: 36,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_kAzul, Color(0xFF2563EB)]),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: _kAzul.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))]),
      child: const Icon(Icons.add_rounded, color: Colors.white, size: 18)),
  );

  Widget _empty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.people_outline, size: 44, color: _soft.withValues(alpha: 0.3)),
    const SizedBox(height: 8),
    Text('No hay clientes', style: TextStyle(fontSize: 13, color: _soft)),
    const SizedBox(height: 12),
    GestureDetector(
      onTap: () => _mostrarPopupCliente(),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_kAzul, Color(0xFF2563EB)]),
          borderRadius: BorderRadius.circular(10)),
        child: const Text('Añadir primer cliente',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)))),
  ]));
}

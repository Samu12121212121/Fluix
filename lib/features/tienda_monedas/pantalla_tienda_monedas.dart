import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/trofeos_service.dart';
import '../../services/canjeo_service.dart';
import '../../core/widgets/flux_toast.dart';
import 'modelos/item_canje.dart';

const _kBg    = Color(0xFF0A0F23);
const _kCard  = Color(0xFF1E2139);
const _kCard2 = Color(0xFF252A45);
const _kBorde = Color(0xFF2A2E45);
const _kTexto = Colors.white;
const _kMuted = Color(0xFFB0B3C1);
const _kOro   = Color(0xFFFFB830);
const _kBg2   = Color(0xFF0A0F23);

const kColoresNombre = <String, Color>{
  'Cian':   Color(0xFF00FFC8), 'Rosa':   Color(0xFFFF3296),
  'Dorado': Color(0xFFFFB830), 'Morado': Color(0xFF8B5CF6),
  'Azul':   Color(0xFF1A73E8), 'Rojo':   Color(0xFFE53935),
};
const kEmojisFirma = ['✨','⭐','🔥','💫','🎯','🌟','💎','🦋','🐺','🚀','🎸','⚡','🌈','🍀','🏄'];

class PantallaTiendaMonedas extends StatefulWidget {
  const PantallaTiendaMonedas({super.key});
  @override
  State<PantallaTiendaMonedas> createState() => _PantallaTiendaMonedasState();
}

class _PantallaTiendaMonedasState extends State<PantallaTiendaMonedas> {
  CategoriaItem? _cat;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  List<ItemCanje> get _items => _cat == null
      ? kCatalogoCanje
      : kCatalogoCanje.where((i) => i.categoria == _cat).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: StreamBuilder<int>(
        stream: TrofeosService.streamMonedas(_uid),
        builder: (_, snapM) {
          final saldo = snapM.data ?? 0;
          return StreamBuilder<List<CanjeActivo>>(
            stream: CanjeoService.streamCanjesActivos(_uid),
            builder: (_, snapC) {
              final canjes = snapC.data ?? [];
              return CustomScrollView(slivers: [
                _buildAppBar(saldo),
                SliverToBoxAdapter(child: _buildHeaderSaldo(saldo)),
                SliverToBoxAdapter(child: _buildFiltros()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _TarjetaItem(item: _items[i], saldo: saldo, canjesActivos: canjes, uid: _uid),
                      childCount: _items.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, childAspectRatio: 0.72,
                      crossAxisSpacing: 12, mainAxisSpacing: 12,
                    ),
                  ),
                ),
              ]);
            },
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(int saldo) => SliverAppBar(
    pinned: true,
    backgroundColor: const Color(0xFF151932),
    foregroundColor: _kTexto,
    title: const Text('Tienda', style: TextStyle(fontWeight: FontWeight.bold)),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _kOro.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kOro.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('🪙', style: TextStyle(fontSize: 13)),
            const SizedBox(width: 5),
            Text('$saldo', style: const TextStyle(color: _kOro, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    ],
  );

  Widget _buildHeaderSaldo(int saldo) {
    const maxMonedas = 5910;
    final pct = (saldo / maxMonedas).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1035), Color(0xFF1E2139)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kOro.withValues(alpha: 0.25)),
      ),
      child: Column(children: [
        Row(children: [
          const Text('🪙', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$saldo', style: const TextStyle(color: _kOro, fontSize: 36, fontWeight: FontWeight.w900, height: 1.0)),
            const Text('monedas disponibles', style: TextStyle(color: _kMuted, fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${(pct * 100).toInt()}%', style: const TextStyle(color: _kOro, fontSize: 14, fontWeight: FontWeight.bold)),
            const Text('del total', style: TextStyle(color: _kMuted, fontSize: 10)),
          ]),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct, minHeight: 6,
            backgroundColor: _kBorde,
            valueColor: const AlwaysStoppedAnimation<Color>(_kOro),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${kCatalogoCanje.where((i) => i.costo <= saldo).length} items disponibles',
            style: const TextStyle(color: _kMuted, fontSize: 11)),
          Text('Máx: $maxMonedas🪙', style: const TextStyle(color: _kMuted, fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _buildFiltros() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          _FilterChip(label: '✨ Todos', selected: _cat == null, color: _kOro, onTap: () => setState(() => _cat = null)),
          ...CategoriaItem.values.map((c) => _FilterChip(
            label: c.label, selected: _cat == c, color: c.color,
            onTap: () => setState(() => _cat = _cat == c ? null : c),
          )),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? color : _kCard2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : _kBorde),
      ),
      child: Text(label, style: TextStyle(color: selected ? _kBg2 : _kMuted, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
    ),
  );
}

// ── Tarjeta de item (grid vertical) ──────────────────────────────────────────

class _TarjetaItem extends StatefulWidget {
  final ItemCanje item;
  final int saldo;
  final List<CanjeActivo> canjesActivos;
  final String uid;
  const _TarjetaItem({required this.item, required this.saldo, required this.canjesActivos, required this.uid});
  @override
  State<_TarjetaItem> createState() => _TarjetaItemState();
}

class _TarjetaItemState extends State<_TarjetaItem> {
  bool _comprando = false;

  CanjeActivo? get _canjeActivo => widget.canjesActivos.where((c) => c.itemId == widget.item.id).firstOrNull;
  bool get _tieneActivo => _canjeActivo != null;
  bool get _puedeComprar => !_comprando && widget.saldo >= widget.item.costo &&
      (widget.item.esSiempreComprable || widget.item.tipo == TipoCanje.usoUnico || !_tieneActivo);
  Color get _col => widget.item.categoria.color;

  @override
  Widget build(BuildContext context) {
    final activo = _tieneActivo;
    final sinSaldo = widget.saldo < widget.item.costo && !activo;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: activo ? _col.withValues(alpha: 0.6) : _kBorde, width: activo ? 1.5 : 0.8),
        boxShadow: activo ? [BoxShadow(color: _col.withValues(alpha: 0.15), blurRadius: 12)] : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Emoji + active badge
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: _col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: _col.withValues(alpha: 0.25))),
              child: Center(child: Text(widget.item.emoji, style: const TextStyle(fontSize: 26))),
            ),
            if (activo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: _col.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _col.withValues(alpha: 0.4))),
                child: Text('Activo', style: TextStyle(color: _col, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
          ]),
          const SizedBox(height: 10),
          // Nombre
          Text(widget.item.nombre, style: const TextStyle(color: _kTexto, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          // Descripción
          Expanded(child: Text(widget.item.descripcion, style: const TextStyle(color: _kMuted, fontSize: 11, height: 1.3), maxLines: 3, overflow: TextOverflow.ellipsis)),
          const SizedBox(height: 8),
          // Duración badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _kCard2, borderRadius: BorderRadius.circular(6)),
            child: Text(widget.item.etiquetaDuracion, style: const TextStyle(color: _kMuted, fontSize: 9, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          // Precio + botón
          if (activo && _canjeActivo?.expiraAt != null)
            Text('Expira ${_fmtExpira(_canjeActivo!.expiraAt!)}', style: TextStyle(color: _col, fontSize: 10, fontWeight: FontWeight.w600))
          else if (activo && _canjeActivo?.usosRestantes != null)
            Text('${_canjeActivo!.usosRestantes} usos restantes', style: TextStyle(color: _col, fontSize: 10, fontWeight: FontWeight.w600))
          else
            GestureDetector(
              onTap: _puedeComprar ? _iniciarCanje : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _puedeComprar ? _kOro : _kCard2,
                  borderRadius: BorderRadius.circular(10),
                  border: sinSaldo ? Border.all(color: _kBorde) : null,
                ),
                child: _comprando
                    ? const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _kBg2)))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Text('🪙', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text('${widget.item.costo}', style: TextStyle(
                          color: _puedeComprar ? _kBg2 : _kMuted,
                          fontWeight: FontWeight.w800, fontSize: 13)),
                      ]),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _iniciarCanje() async {
    if (!_puedeComprar) return;
    if (widget.item.esCajaMisteriosa) {
      if (!await _confirmar(extra: 'El resultado es completamente aleatorio. ¡Buena suerte!')) return;
      setState(() => _comprando = true);
      try {
        final premio = await CanjeoService.canjearCajaMisteriosa(widget.uid);
        if (mounted) FluxToast.exito(context, '${premio.emoji} ¡Has obtenido: ${premio.nombre}!', title: '🎲 Caja abierta');
      } catch (e) {
        if (mounted) FluxToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _comprando = false);
      }
      return;
    }
    String? extra;
    switch (widget.item.inputExtra) {
      case InputExtra.texto:  extra = await _pedirTexto(); if (extra == null) return;
      case InputExtra.emoji:  extra = await _pedirEmoji(); if (extra == null) return;
      case InputExtra.color:  extra = await _pedirColor(); if (extra == null) return;
      case InputExtra.ninguno: if (!await _confirmar()) return;
    }
    setState(() => _comprando = true);
    try {
      await CanjeoService.canjear(widget.uid, widget.item, datoExtra: extra);
      if (mounted) FluxToast.exito(context, '${widget.item.emoji} ¡${widget.item.nombre} activado!');
    } catch (e) {
      if (mounted) FluxToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _comprando = false);
    }
  }

  Future<bool> _confirmar({String? extra}) async => await showDialog<bool>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.item.emoji, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        Text(widget.item.nombre, style: const TextStyle(color: _kTexto, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(extra ?? widget.item.descripcion, style: const TextStyle(color: _kMuted, fontSize: 13, height: 1.4), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Row(mainAxisSize: MainAxisSize.min, children: [const Text('🪙', style: TextStyle(fontSize: 14)), const SizedBox(width: 4), Text('${widget.item.costo} monedas', style: const TextStyle(color: _kOro, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: _kMuted)))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: _kOro, foregroundColor: _kBg2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold)))),
        ]),
      ])),
    ),
  ) ?? false;

  Future<String?> _pedirTexto() async {
    final ctrl = TextEditingController();
    return showDialog<String>(context: context, builder: (_) => Dialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.item.emoji, style: const TextStyle(fontSize: 40)),
        const SizedBox(height: 10),
        Text(widget.item.id == 'vitrina_trofeos' ? 'IDs separados por coma' : 'Escribe tu título (máx. 28 car.)',
            style: const TextStyle(color: _kTexto, fontSize: 14), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        TextField(controller: ctrl, autofocus: true, maxLength: widget.item.id == 'vitrina_trofeos' ? 120 : 28,
            style: const TextStyle(color: _kTexto),
            decoration: _dec(widget.item.id == 'vitrina_trofeos' ? 'primera_reserva,flash_primera,…' : 'Ej: Amante del café ☕')),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: _kMuted)))),
          Expanded(child: FilledButton(onPressed: () { final t = ctrl.text.trim(); if (t.isNotEmpty) Navigator.pop(context, t); },
            style: FilledButton.styleFrom(backgroundColor: _kOro, foregroundColor: _kBg2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Aplicar', style: TextStyle(fontWeight: FontWeight.bold)))),
        ]),
      ])),
    ));
  }

  Future<String?> _pedirEmoji() async => showDialog<String>(context: context, builder: (_) => Dialog(
    backgroundColor: _kCard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('✍️', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 10),
      const Text('Elige tu emoji firma', style: TextStyle(color: _kTexto, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      const Text('Aparecerá al final de tus reseñas', style: TextStyle(color: _kMuted, fontSize: 12)),
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: kEmojisFirma.map((e) => GestureDetector(
        onTap: () => Navigator.pop(context, e),
        child: Container(width: 44, height: 44, decoration: BoxDecoration(color: _kCard2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kBorde)),
          child: Center(child: Text(e, style: const TextStyle(fontSize: 22)))),
      )).toList()),
      const SizedBox(height: 12),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: _kMuted))),
    ])),
  ));

  Future<String?> _pedirColor() async => showDialog<String>(context: context, builder: (_) => Dialog(
    backgroundColor: _kCard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🎨', style: TextStyle(fontSize: 40)),
      const SizedBox(height: 10),
      const Text('Elige el color de tu nombre', style: TextStyle(color: _kTexto, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: kColoresNombre.entries.map((e) {
        final hex = '#${e.value.value.toRadixString(16).substring(2).toUpperCase()}';
        return GestureDetector(onTap: () => Navigator.pop(context, hex), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: e.value, shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2))),
          const SizedBox(height: 4),
          Text(e.key, style: TextStyle(color: e.value, fontSize: 10, fontWeight: FontWeight.w600)),
        ]));
      }).toList()),
      const SizedBox(height: 12),
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: _kMuted))),
    ])),
  ));

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: _kMuted),
    filled: true, fillColor: _kCard2,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorde)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorde)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kOro)),
  );

  String _fmtExpira(DateTime dt) {
    final d = dt.difference(DateTime.now()).inDays;
    if (d <= 0) return 'hoy'; if (d == 1) return 'mañana'; return 'en $d días';
  }
}

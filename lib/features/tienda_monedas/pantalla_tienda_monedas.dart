import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/trofeos_service.dart';
import '../../services/canjeo_service.dart';
import '../../core/widgets/flux_toast.dart';
import 'modelos/item_canje.dart';

const _kBg      = Color(0xFF0A0F23);
const _kSurface = Color(0xFF151932);
const _kCard    = Color(0xFF1E2139);
const _kCard2   = Color(0xFF252A45);
const _kBorde   = Color(0xFF2A2E45);
const _kTexto   = Colors.white;
const _kMuted   = Color(0xFFB0B3C1);
const _kOro     = Color(0xFFFFB830);

// Colores preset para picker de nombre
const kColoresNombre = <String, Color>{
  'Cian':    Color(0xFF00FFC8),
  'Rosa':    Color(0xFFFF3296),
  'Dorado':  Color(0xFFFFB830),
  'Morado':  Color(0xFF8B5CF6),
  'Azul':    Color(0xFF1A73E8),
  'Rojo':    Color(0xFFE53935),
};

// Emojis preset para firma
const kEmojisFirma = ['✨', '⭐', '🔥', '💫', '🎯', '🌟', '💎', '🦋', '🐺', '🚀', '🎸', '⚡', '🌈', '🍀', '🏄'];

class PantallaTiendaMonedas extends StatefulWidget {
  const PantallaTiendaMonedas({super.key});
  @override
  State<PantallaTiendaMonedas> createState() => _PantallaTiendaMonedasState();
}

class _PantallaTiendaMonedasState extends State<PantallaTiendaMonedas>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: CategoriaItem.values.length, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildHeader()],
        body: Column(children: [
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tc,
              children: CategoriaItem.values
                  .map((cat) => _ListaItems(uid: _uid, categoria: cat))
                  .toList(),
            ),
          ),
        ]),
      ),
    );
  }

  SliverAppBar _buildHeader() {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: _kSurface,
      foregroundColor: _kTexto,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A1035), Color(0xFF151932)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 12),
              child: Row(children: [
                const Text('🪙', style: TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Tienda de Monedas', style: TextStyle(
                      color: _kTexto, fontSize: 20, fontWeight: FontWeight.bold)),
                  StreamBuilder<int>(
                    stream: TrofeosService.streamMonedas(_uid),
                    builder: (_, snap) => Text(
                      'Saldo: ${snap.data ?? 0} monedas',
                      style: const TextStyle(color: _kOro, fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: _kSurface,
      child: TabBar(
        controller: _tc,
        indicatorColor: _kOro,
        indicatorWeight: 2.5,
        labelColor: _kOro,
        unselectedLabelColor: _kMuted,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        tabs: CategoriaItem.values.map((c) => Tab(text: c.label)).toList(),
      ),
    );
  }
}

// ── Lista por categoría ────────────────────────────────────────────
class _ListaItems extends StatelessWidget {
  final String uid;
  final CategoriaItem categoria;
  const _ListaItems({required this.uid, required this.categoria});

  @override
  Widget build(BuildContext context) {
    final items = kCatalogoCanje.where((i) => i.categoria == categoria).toList();
    return StreamBuilder<int>(
      stream: TrofeosService.streamMonedas(uid),
      builder: (_, snapM) {
        final saldo = snapM.data ?? 0;
        return StreamBuilder<List<CanjeActivo>>(
          stream: CanjeoService.streamCanjesActivos(uid),
          builder: (_, snapC) {
            final canjes = snapC.data ?? [];
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _TarjetaItem(
                item: items[i], saldo: saldo,
                canjesActivos: canjes, uid: uid,
              ),
            );
          },
        );
      },
    );
  }
}

// ── Tarjeta de item ────────────────────────────────────────────────
class _TarjetaItem extends StatefulWidget {
  final ItemCanje item;
  final int saldo;
  final List<CanjeActivo> canjesActivos;
  final String uid;
  const _TarjetaItem({required this.item, required this.saldo,
      required this.canjesActivos, required this.uid});
  @override
  State<_TarjetaItem> createState() => _TarjetaItemState();
}

class _TarjetaItemState extends State<_TarjetaItem> {
  bool _comprando = false;

  CanjeActivo? get _canjeActivo => widget.canjesActivos
      .where((c) => c.itemId == widget.item.id).firstOrNull;

  bool get _tieneActivo => _canjeActivo != null;
  bool get _puedeComprar => !_comprando && widget.saldo >= widget.item.costo &&
      (widget.item.esSiempreComprable || widget.item.tipo == TipoCanje.usoUnico || !_tieneActivo);

  Color get _col => widget.item.categoria.color;

  Future<void> _iniciarCanje() async {
    if (!_puedeComprar) return;

    // Caja Misteriosa — flujo especial
    if (widget.item.esCajaMisteriosa) {
      final confirmar = await _mostrarConfirmacion(
          extra: 'El resultado es completamente aleatorio y sorpresa. ¡Buena suerte!');
      if (!confirmar) return;
      setState(() => _comprando = true);
      try {
        final premio = await CanjeoService.canjearCajaMisteriosa(widget.uid);
        if (mounted) FluxToast.exito(context,
            '${premio.emoji} ¡Has obtenido: ${premio.nombre}!',
            title: '🎲 Caja abierta');
      } catch (e) {
        if (mounted) FluxToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _comprando = false);
      }
      return;
    }

    String? datoExtra;
    switch (widget.item.inputExtra) {
      case InputExtra.texto:
        datoExtra = await _pedirTexto();
        if (datoExtra == null) return;
      case InputExtra.emoji:
        datoExtra = await _pedirEmoji();
        if (datoExtra == null) return;
      case InputExtra.color:
        datoExtra = await _pedirColor();
        if (datoExtra == null) return;
      case InputExtra.ninguno:
        final ok = await _mostrarConfirmacion();
        if (!ok) return;
    }

    setState(() => _comprando = true);
    try {
      await CanjeoService.canjear(widget.uid, widget.item, datoExtra: datoExtra);
      if (mounted) FluxToast.exito(context,
          '${widget.item.emoji} ¡${widget.item.nombre} activado!');
    } catch (e) {
      if (mounted) FluxToast.error(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _comprando = false);
    }
  }

  Future<bool> _mostrarConfirmacion({String? extra}) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.item.emoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(widget.item.nombre, style: const TextStyle(
                color: _kTexto, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(extra ?? widget.item.descripcion,
                style: const TextStyle(color: _kMuted, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            _chipCoste(widget.item.costo),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar', style: TextStyle(color: _kMuted)))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: _kOro,
                    foregroundColor: _kBg, shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]),
          ]),
        ),
      ),
    ) ?? false;
  }

  Future<String?> _pedirTexto() async {
    final ctrl = TextEditingController();
    return showDialog<String>(context: context, builder: (_) => Dialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          Text(widget.item.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(widget.item.id == 'vitrina_trofeos'
              ? 'IDs separados por coma\n(ej: primera_reserva,flash_primera,bienvenido)'
              : 'Escribe tu título (máx. 28 caracteres)',
              style: const TextStyle(color: _kTexto, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          TextField(controller: ctrl, autofocus: true,
              maxLength: widget.item.id == 'vitrina_trofeos' ? 120 : 28,
              style: const TextStyle(color: _kTexto),
              decoration: _inputDec(widget.item.id == 'vitrina_trofeos'
                  ? 'primera_reserva,flash_primera,…' : 'Ej: Amante del café ☕')),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar', style: TextStyle(color: _kMuted)))),
            Expanded(child: FilledButton(
              onPressed: () { final t = ctrl.text.trim(); if (t.isNotEmpty) Navigator.pop(context, t); },
              style: FilledButton.styleFrom(backgroundColor: _kOro, foregroundColor: _kBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Aplicar', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ]),
        ],
      )),
    ));
  }

  Future<String?> _pedirEmoji() async {
    return showDialog<String>(context: context, builder: (_) => Dialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const Text('✍️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          const Text('Elige tu emoji firma', style: TextStyle(
              color: _kTexto, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Aparecerá al final de todas tus reseñas',
              style: TextStyle(color: _kMuted, fontSize: 12)),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: kEmojisFirma.map((e) =>
            GestureDetector(
              onTap: () => Navigator.pop(context, e),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: _kCard2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kBorde)),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
              ),
            ),
          ).toList()),
          const SizedBox(height: 12),
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: _kMuted))),
        ],
      )),
    ));
  }

  Future<String?> _pedirColor() async {
    return showDialog<String>(context: context, builder: (_) => Dialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const Text('🎨', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          const Text('Elige el color de tu nombre', style: TextStyle(
              color: _kTexto, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: kColoresNombre.entries.map((e) {
            final hex = '#${e.value.value.toRadixString(16).substring(2).toUpperCase()}';
            return GestureDetector(
              onTap: () => Navigator.pop(context, hex),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: e.value, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2))),
                const SizedBox(height: 4),
                Text(e.key, style: TextStyle(color: e.value, fontSize: 10,
                    fontWeight: FontWeight.w600)),
              ]),
            );
          }).toList()),
          const SizedBox(height: 12),
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: _kMuted))),
        ],
      )),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final activo = _tieneActivo;
    final sinSaldo = widget.saldo < widget.item.costo && !activo;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: activo ? _col.withValues(alpha: 0.5) : _kBorde,
          width: activo ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: _col.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _col.withValues(alpha: 0.25)),
            ),
            child: Center(child: Text(widget.item.emoji,
                style: const TextStyle(fontSize: 28))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(widget.item.nombre, style: const TextStyle(
                  color: _kTexto, fontSize: 14, fontWeight: FontWeight.bold))),
              if (activo) _chipActivo(),
            ]),
            const SizedBox(height: 4),
            Text(widget.item.descripcion, style: const TextStyle(
                color: _kMuted, fontSize: 12, height: 1.4)),
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _kCard2, borderRadius: BorderRadius.circular(6)),
                child: Text(widget.item.etiquetaDuracion,
                    style: const TextStyle(color: _kMuted, fontSize: 10)),
              ),
              const Spacer(),
              if (activo && _canjeActivo?.expiraAt != null)
                Text('Expira ${_formatExpira(_canjeActivo!.expiraAt!)}',
                    style: const TextStyle(color: _kMuted, fontSize: 10))
              else if (activo && _canjeActivo?.usosRestantes != null)
                Text('${_canjeActivo!.usosRestantes} usos restantes',
                    style: TextStyle(color: _col, fontSize: 10, fontWeight: FontWeight.w600))
              else
                _botonCanje(sinSaldo),
            ]),
          ])),
        ]),
      ),
    );
  }

  Widget _chipActivo() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _col.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _col.withValues(alpha: 0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_rounded, color: _col, size: 11),
      const SizedBox(width: 3),
      Text('Activo', style: TextStyle(color: _col, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );

  Widget _botonCanje(bool sinSaldo) => GestureDetector(
    onTap: _puedeComprar ? _iniciarCanje : null,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _puedeComprar ? _kOro : _kCard2,
        borderRadius: BorderRadius.circular(20),
        border: sinSaldo ? Border.all(color: _kBorde) : null,
      ),
      child: _comprando
          ? const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A0F23)))
          : _chipCoste(widget.item.costo, onBoton: true),
    ),
  );

  Widget _chipCoste(int costo, {bool onBoton = false}) => Row(
    mainAxisSize: MainAxisSize.min, children: [
      const Text('🪙', style: TextStyle(fontSize: 12)),
      const SizedBox(width: 4),
      Text('$costo', style: TextStyle(
          color: onBoton ? (_puedeComprar ? const Color(0xFF0A0F23) : _kMuted) : _kOro,
          fontWeight: FontWeight.bold, fontSize: 12)),
    ],
  );

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: _kMuted),
    filled: true, fillColor: _kCard2,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kBorde)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kBorde)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kOro)),
  );

  String _formatExpira(DateTime dt) {
    final d = dt.difference(DateTime.now()).inDays;
    if (d <= 0) return 'hoy';
    if (d == 1) return 'mañana';
    return 'en $d días';
  }
}

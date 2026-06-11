import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../domain/modelos/mesa.dart';
import '../providers/mesa_theme_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// FLOOR PLAN WIDGET — Plano visual interactivo de mesas para el TPV Bar
// ═══════════════════════════════════════════════════════════════════════════

class FloorPlanWidget extends StatefulWidget {
  final List<Mesa> mesas;
  final String empresaId;
  final String? mesaSeleccionadaId;
  final void Function(String mesaId) onMesaTap;
  final void Function(String mesaId, double newX, double newY)? onMesaMoved;
  final bool modoEdicion;

  const FloorPlanWidget({
    super.key,
    required this.mesas,
    required this.empresaId,
    required this.onMesaTap,
    this.mesaSeleccionadaId,
    this.onMesaMoved,
    this.modoEdicion = false,
  });

  @override
  State<FloorPlanWidget> createState() => _FloorPlanWidgetState();
}

class _FloorPlanWidgetState extends State<FloorPlanWidget> {
  final Map<String, Offset> _posOverride = {};
  // Overrides de tamaño durante drag (ancho/alto normalizados 0..1)
  final Map<String, double> _resizeW = {};
  final Map<String, double> _resizeH = {};

  // ── Rotar mesa rect: intercambia ancho/alto ────────────────────────────────
  Future<void> _rotarMesa(Mesa mesa) async {
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('mesas')
        .doc(mesa.id)
        .update({
      'mesa_ancho': mesa.mesaAlto,
      'mesa_alto':  mesa.mesaAncho,
    });
  }

  // ── Redimensionar mesa ────────────────────────────────────────────────────
  Future<void> _redimensionar(Mesa mesa, double factor) async {
    final Map<String, dynamic> update;
    if (mesa.forma == 'bar') {
      // Barra: solo cambia la dimensión LARGA (sea ancho o alto según rotación)
      if (mesa.mesaAncho >= mesa.mesaAlto) {
        // Horizontal: la longitud es mesa_ancho
        final nuevoAncho = (mesa.mesaAncho * factor).clamp(0.12, 0.85);
        update = {'mesa_ancho': nuevoAncho};
      } else {
        // Vertical (rotada): la longitud es mesa_alto
        final nuevoAlto = (mesa.mesaAlto * factor).clamp(0.12, 0.85);
        update = {'mesa_alto': nuevoAlto};
      }
    } else {
      final nuevoAncho = (mesa.mesaAncho * factor).clamp(0.08, 0.45);
      final nuevoAlto  = (mesa.mesaAlto  * factor).clamp(0.06, 0.40);
      update = {'mesa_ancho': nuevoAncho, 'mesa_alto': nuevoAlto};
    }
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('mesas')
        .doc(mesa.id)
        .update(update);
  }

  // ── Cambiar estado de mesa ─────────────────────────────────────────────
  Future<void> _mostrarMenuEstado(BuildContext ctx, Mesa mesa) async {
    final estados = [
      ('libre',     'Libre',     Colors.green),
      ('ocupada',   'Ocupada',   Colors.red),
      ('reservada', 'Reservada', Colors.amber),
    ];

    await showModalBottomSheet<void>(
      context: ctx,
      backgroundColor: const Color(0xFF1E2139),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              mesa.nombre.isNotEmpty ? mesa.nombre : 'Mesa ${mesa.numero}',
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const Divider(color: Color(0xFF2A2E45), height: 1),
          // ── Estado ──────────────────────────────────────────────────
          ...estados.map((e) => ListTile(
            leading: CircleAvatar(radius: 8, backgroundColor: e.$3),
            title: Text(e.$2, style: const TextStyle(color: Colors.white, fontSize: 14)),
            trailing: mesa.estado == e.$1
                ? const Icon(Icons.check, color: Color(0xFF00FFC8), size: 18)
                : null,
            onTap: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(widget.empresaId)
                  .collection('mesas')
                  .doc(mesa.id)
                  .update({
                'estado': e.$1,
                if (e.$1 == 'libre') ...{
                  'comanda_id': null,
                  'camarero_uid': null,
                  'fecha_apertura': null,
                },
              });
            },
          )),
          const Divider(color: Color(0xFF2A2E45), height: 1),
          // ── Tamaño y rotación ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.aspect_ratio, color: Colors.white54, size: 16),
                const SizedBox(width: 8),
                const Text('Tamaño y rotación',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                _MenuBtn(
                  icon: Icons.remove,
                  label: 'Encoger',
                  onTap: () { Navigator.pop(ctx); _redimensionar(mesa, 0.85); },
                ),
                const SizedBox(width: 8),
                _MenuBtn(
                  icon: Icons.add,
                  label: 'Agrandar',
                  onTap: () { Navigator.pop(ctx); _redimensionar(mesa, 1.18); },
                ),
                if (mesa.forma != 'circle') ...[
                  const SizedBox(width: 8),
                  _MenuBtn(
                    icon: Icons.rotate_90_degrees_cw_outlined,
                    label: 'Rotar',
                    onTap: () { Navigator.pop(ctx); _rotarMesa(mesa); },
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2E45), height: 1),
          // ── Editar nombre ────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: Color(0xFF00FFC8), size: 20),
            title: const Text('Editar nombre',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            onTap: () async {
              Navigator.pop(ctx);
              final ctrl = TextEditingController(
                  text: mesa.nombre.isNotEmpty ? mesa.nombre : 'Mesa ${mesa.numero}');
              final nuevoNombre = await showDialog<String>(
                context: ctx,
                builder: (_) => AlertDialog(
                  title: const Text('Nombre de la mesa'),
                  content: TextField(
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Ej: Terraza 1, Mesa VIP…',
                    ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancelar')),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
              );
              if (nuevoNombre != null && nuevoNombre.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('empresas')
                    .doc(widget.empresaId)
                    .collection('mesas')
                    .doc(mesa.id)
                    .update({'nombre': nuevoNombre});
              }
            },
          ),
          const Divider(color: Color(0xFF2A2E45), height: 1),
          // ── Eliminar ─────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
            title: const Text('Eliminar mesa',
                style: TextStyle(color: Colors.redAccent, fontSize: 14)),
            onTap: () async {
              Navigator.pop(ctx);
              final ok = await showDialog<bool>(
                context: ctx,
                builder: (_) => AlertDialog(
                  title: const Text('Eliminar mesa'),
                  content: Text('¿Seguro que quieres eliminar '
                      '"${mesa.nombre.isNotEmpty ? mesa.nombre : 'Mesa ${mesa.numero}'}"?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await FirebaseFirestore.instance
                    .collection('empresas')
                    .doc(widget.empresaId)
                    .collection('mesas')
                    .doc(mesa.id)
                    .delete();
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Sub-tickets: comandas abiertas por mesa
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('comandas')
          .where('estado', isEqualTo: 'abierta')
          .snapshots(),
      builder: (ctx, snapComandas) {
        // mesaId → número de comandas abiertas (sub-tickets)
        final subTickets = <String, int>{};
        for (final doc in snapComandas.data?.docs ?? []) {
          final data = doc.data() as Map<String, dynamic>;
          final mesaId = data['mesa_id'] as String?;
          if (mesaId != null) {
            subTickets[mesaId] = (subTickets[mesaId] ?? 0) + 1;
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final canvasW = constraints.maxWidth;
            final canvasH = constraints.maxHeight;
            final theme = context.watch<MesaThemeProvider>().temaActual;

            return Stack(
              children: [
                _GridBackground(width: canvasW, height: canvasH, fondoColor: theme.fondoApp),

                if (widget.mesas.isEmpty)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.table_restaurant, size: 48, color: Colors.white24),
                        SizedBox(height: 12),
                        Text('Sin mesas configuradas',
                            style: TextStyle(color: Colors.white38, fontSize: 14)),
                        SizedBox(height: 4),
                        Text('Pulsa + para añadir una mesa',
                            style: TextStyle(color: Colors.white24, fontSize: 12)),
                      ],
                    ),
                  ),

                for (final mesa in widget.mesas)
                  _buildMesaWidget(mesa, canvasW, canvasH, theme, subTickets),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMesaWidget(
      Mesa mesa, double canvasW, double canvasH, mesaTheme, Map<String, int> subTickets) {
    final override = _posOverride[mesa.id];
    final posX = override?.dx ?? mesa.posX;
    final posY = override?.dy ?? mesa.posY;

    // Usar override de tamaño si hay un drag activo
    final mesaAncho = _resizeW[mesa.id] ?? mesa.mesaAncho;
    final mesaAlto  = _resizeH[mesa.id] ?? mesa.mesaAlto;
    final left = (posX * canvasW).clamp(0.0, canvasW - mesaAncho * canvasW);
    final top  = (posY * canvasH).clamp(0.0, canvasH - mesaAlto  * canvasH);
    final w = (mesaAncho * canvasW).clamp(50.0, canvasW * 0.7);
    final h = (mesaAlto  * canvasH).clamp(36.0, canvasH * 0.6);
    final seleccionada = mesa.id == widget.mesaSeleccionadaId;

    // Color de fondo por estado usando el tema activo
    final Color colorEstado;
    final Color colorTexto;
    switch (mesa.estado) {
      case 'ocupada':
        colorEstado = mesaTheme.mesaOcupada;
        colorTexto  = mesaTheme.textoOcupada;
        break;
      case 'reservada':
        colorEstado = const Color(0xFFEF9F27);
        colorTexto  = Colors.white;
        break;
      default:
        colorEstado = mesaTheme.mesaLibre;
        colorTexto  = mesaTheme.textoLibre;
    }

    // Border radius según forma
    final BorderRadius borderRadius = switch (mesa.forma) {
      'circle'  => BorderRadius.circular(9999),
      'bar'     => BorderRadius.circular(5),
      _         => BorderRadius.circular(8), // 'rect' y defecto
    };

    // Sub-tickets para mesas de tipo barra
    final int numTickets = subTickets[mesa.id] ?? 0;
    final bool esBar = mesa.forma == 'bar';
    final List<Widget> subTicketWidgets = [];
    if (esBar && numTickets > 1) {
      final ticketW = (w / numTickets).clamp(40.0, 80.0);
      for (int i = 0; i < numTickets; i++) {
        subTicketWidgets.add(
          Positioned(
            left: left + i * (ticketW + 4),
            top: top + h + 6,
            child: GestureDetector(
              onTap: () => widget.onMesaTap(mesa.id),
              child: Container(
                width: ticketW,
                height: 28,
                decoration: BoxDecoration(
                  color: colorEstado.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: colorEstado, width: 1.2),
                ),
                child: Center(
                  child: Text(
                    'T${i + 1}',
                    style: TextStyle(
                      color: colorTexto,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    // ── Contenido de la mesa con controles de edición embebidos ─────────────
    final mesaWidget = GestureDetector(
      onTap: () => widget.onMesaTap(mesa.id),
      onLongPress: () => _mostrarMenuEstado(context, mesa),
      child: Stack(
        children: [
          Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.18),
              borderRadius: borderRadius,
              border: seleccionada
                  ? Border.all(color: Colors.white, width: 2.5)
                  : Border.all(color: colorEstado, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: colorEstado.withValues(alpha: seleccionada ? 0.5 : 0.25),
                  blurRadius: seleccionada ? 12 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: _MesaContent(mesa: mesa, colorTexto: colorTexto),
          ),
          // ── Badge de estado (siempre visible) ─────────────────────────
          Positioned(
            top: 3,
            right: 3,
            child: GestureDetector(
              onTap: () => _mostrarMenuEstado(context, mesa),
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: colorEstado,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26, width: 0.5),
                ),
              ),
            ),
          ),
          // ── Botones edición (solo en modoEdicion) ─────────────────────
          if (widget.modoEdicion)
            Positioned(
              bottom: 3,
              left: 3,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _EditBtn(
                    icon: Icons.remove,
                    tooltip: 'Encoger',
                    onTap: () => _redimensionar(mesa, 0.85),
                  ),
                  const SizedBox(width: 2),
                  _EditBtn(
                    icon: Icons.add,
                    tooltip: 'Agrandar',
                    onTap: () => _redimensionar(mesa, 1.18),
                  ),
                  if (mesa.forma != 'circle') ...[
                    const SizedBox(width: 2),
                    _EditBtn(
                      icon: Icons.rotate_90_degrees_cw_outlined,
                      tooltip: 'Rotar',
                      onTap: () => _rotarMesa(mesa),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );

    // ── En modo edición, mesa draggable; si no, directa ──────────────────────
    final Widget mesaPositioned = Positioned(
      left: left,
      top: top,
      child: widget.modoEdicion && widget.onMesaMoved != null
          ? Draggable<String>(
              data: mesa.id,
              feedback: Opacity(opacity: 0.75, child: mesaWidget),
              childWhenDragging: Opacity(opacity: 0.3, child: mesaWidget),
              onDragEnd: (details) {
                final RenderBox? canvasBox =
                    context.findRenderObject() as RenderBox?;
                if (canvasBox == null) return;
                final localPos = canvasBox.globalToLocal(details.offset);
                final newX = (localPos.dx / canvasW).clamp(0.0, 0.95);
                final newY = (localPos.dy / canvasH).clamp(0.0, 0.95);
                setState(() => _posOverride[mesa.id] = Offset(newX, newY));
                widget.onMesaMoved!(mesa.id, newX, newY);
              },
              child: mesaWidget,
            )
          : mesaWidget,
    );

    // ── Handles de redimensionado (solo en modoEdicion) ──────────────────────
    final List<Widget> resizeHandles = [];
    if (widget.modoEdicion) {
      resizeHandles.addAll([
        // Handle derecho (solo ancho)
        _ResizeHandle(
          left: left + w - 6,
          top: top + h / 2 - 6,
          cursor: SystemMouseCursors.resizeLeftRight,
          onPanUpdate: (dx, dy) {
            final nw = ((mesaAncho + dx / canvasW)).clamp(0.05, 0.75);
            setState(() => _resizeW[mesa.id] = nw);
          },
          onPanEnd: () => _saveResize(mesa, mesaAncho, mesaAlto),
        ),
        // Handle inferior (solo alto)
        _ResizeHandle(
          left: left + w / 2 - 6,
          top: top + h - 6,
          cursor: SystemMouseCursors.resizeUpDown,
          onPanUpdate: (dx, dy) {
            final nh = ((mesaAlto + dy / canvasH)).clamp(0.04, 0.65);
            setState(() => _resizeH[mesa.id] = nh);
          },
          onPanEnd: () => _saveResize(mesa, mesaAncho, mesaAlto),
        ),
        // Handle esquina inferior-derecha (ancho + alto)
        _ResizeHandle(
          left: left + w - 6,
          top: top + h - 6,
          cursor: SystemMouseCursors.resizeUpLeftDownRight,
          isCorner: true,
          onPanUpdate: (dx, dy) {
            final nw = ((mesaAncho + dx / canvasW)).clamp(0.05, 0.75);
            final nh = ((mesaAlto  + dy / canvasH)).clamp(0.04, 0.65);
            setState(() {
              _resizeW[mesa.id] = nw;
              _resizeH[mesa.id] = nh;
            });
          },
          onPanEnd: () => _saveResize(mesa, mesaAncho, mesaAlto),
        ),
      ]);
    }

    return Stack(
      children: [
        mesaPositioned,
        ...subTicketWidgets,
        ...resizeHandles,
      ],
    );
  }

  Future<void> _saveResize(Mesa mesa, double anchoActual, double altoActual) async {
    final nw = _resizeW[mesa.id] ?? anchoActual;
    final nh = _resizeH[mesa.id] ?? altoActual;
    _resizeW.remove(mesa.id);
    _resizeH.remove(mesa.id);
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('mesas')
        .doc(mesa.id)
        .update({'mesa_ancho': nw, 'mesa_alto': nh});
  }
}

// ── Handle de redimensionado ──────────────────────────────────────────────────
class _ResizeHandle extends StatelessWidget {
  final double left;
  final double top;
  final MouseCursor cursor;
  final bool isCorner;
  final void Function(double dx, double dy) onPanUpdate;
  final VoidCallback onPanEnd;

  const _ResizeHandle({
    required this.left,
    required this.top,
    required this.cursor,
    required this.onPanUpdate,
    required this.onPanEnd,
    this.isCorner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          onPanUpdate: (d) => onPanUpdate(d.delta.dx, d.delta.dy),
          onPanEnd: (_) => onPanEnd(),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isCorner ? Colors.orange : Colors.white,
              borderRadius: BorderRadius.circular(isCorner ? 3 : 2),
              border: Border.all(
                color: isCorner ? Colors.white : Colors.orange,
                width: 1.5,
              ),
              boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3)],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Botón de acción en menú bottom sheet ─────────────────────────────────────
class _MenuBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2E45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF00FFC8).withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF00FFC8)),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF00FFC8), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Botón de control de edición (en plano, modo edición) ─────────────────────
class _EditBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _EditBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 13, color: Colors.black),
        ),
      ),
    );
  }
}

// ── Contenido de la tarjeta de mesa ─────────────────────────────────────────
class _MesaContent extends StatelessWidget {
  final Mesa mesa;
  final Color colorTexto;

  const _MesaContent({required this.mesa, required this.colorTexto});

  @override
  Widget build(BuildContext context) {
    final nombreDisplay =
        mesa.nombre.isNotEmpty ? mesa.nombre : 'Mesa ${mesa.numero}';

    Widget? tercerLinea;
    if (mesa.esOcupada) {
      tercerLinea = const SizedBox.shrink();
    } else if ((mesa.comensales ?? 0) > 0) {
      tercerLinea = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people, size: 9, color: colorTexto.withValues(alpha: 0.7)),
          const SizedBox(width: 2),
          Text(
            '${mesa.comensales}',
            style: TextStyle(
                fontSize: 9,
                color: colorTexto.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          nombreDisplay,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colorTexto,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        if (mesa.zona.isNotEmpty)
          Text(
            mesa.zona,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorTexto.withValues(alpha: 0.7),
              fontSize: 9,
              height: 1.2,
            ),
          ),
        if (tercerLinea != null) ...[
          const SizedBox(height: 2),
          tercerLinea,
        ],
        if (mesa.esOcupada) ...[
          const SizedBox(height: 1),
          _ImporteComanda(mesa: mesa),
        ],
      ],
    );
  }
}

// ── Importe de la comanda (cargado desde Firestore) ──────────────────────────
class _ImporteComanda extends StatelessWidget {
  final Mesa mesa;

  const _ImporteComanda({required this.mesa});

  @override
  Widget build(BuildContext context) {
    if (mesa.comandaId == null || mesa.comandaId!.isEmpty) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<Object>(
      stream: null, // placeholder — el importe se muestra si viene en la mesa
      builder: (context, _) {
        return const SizedBox.shrink();
      },
    );
  }
}

// ── Importe inline como Text (se usa cuando el total viene como parámetro) ───
class FloorPlanMesaTotal extends StatelessWidget {
  final double total;

  const FloorPlanMesaTotal({super.key, required this.total});

  @override
  Widget build(BuildContext context) {
    return Text(
      NumberFormat.currency(symbol: '€', decimalDigits: 2).format(total),
      style: const TextStyle(
          fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
    );
  }
}

// ── Fondo con grid de puntos ──────────────────────────────────────────────────
class _GridBackground extends StatelessWidget {
  final double width;
  final double height;
  final Color fondoColor;

  const _GridBackground({
    required this.width,
    required this.height,
    required this.fondoColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _DotGridPainter(fondoColor: fondoColor),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color fondoColor;
  const _DotGridPainter({required this.fondoColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo con el color del tema
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = fondoColor,
    );

    // Grid de puntos cada 40px
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.fill;

    const step = 40.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.fondoColor != fondoColor;
}



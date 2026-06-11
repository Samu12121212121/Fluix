import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/modelos/mesa.dart';
import '../../features/tpv/pantallas/tpv_root_screen.dart';
import 'mesa_canvas_item.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Enums
// ═══════════════════════════════════════════════════════════════════════════

enum ModoPlano { edicion, servicio }

// ═══════════════════════════════════════════════════════════════════════════
// PlanoDeMesasScreen
// ═══════════════════════════════════════════════════════════════════════════

class PlanoDeMesasScreen extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  final bool esPropietario;

  const PlanoDeMesasScreen({
    super.key,
    required this.empresaId,
    this.esAdmin = false,
    this.esPropietario = false,
  });

  @override
  State<PlanoDeMesasScreen> createState() => _PlanoDeMesasScreenState();
}

class _PlanoDeMesasScreenState extends State<PlanoDeMesasScreen> {
  static const _prefKey = 'tpv_plano_modo';
  static const _bgColor = Color(0xFF12121F);
  static const _cian = Color(0xFF00FFC8);

  ModoPlano _modo = ModoPlano.servicio;
  String? _mesaSeleccionadaId;

  /// Posiciones locales mientras se edita (antes de guardar)
  final Map<String, Offset> _localPos = {};

  /// Mesas cargadas del StreamBuilder (actualizadas en build)
  List<Mesa> _mesas = [];

  /// Zonas disponibles
  List<String> _zonas = ['Salón'];

  /// Key del canvas para convertir coordenadas globales → locales
  final _canvasKey = GlobalKey();

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _cargarModo();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Future<void> _cargarModo() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    if (stored == 'edicion' && mounted) {
      setState(() => _modo = ModoPlano.edicion);
    }
  }

  Future<void> _cambiarModo(ModoPlano nuevoModo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, nuevoModo == ModoPlano.edicion ? 'edicion' : 'servicio');
    if (mounted) setState(() => _modo = nuevoModo);
  }

  // ── Guardar posiciones en Firestore ──────────────────────────────────────

  Future<void> _guardarPlano() async {
    if (_localPos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay cambios pendientes')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final entry in _localPos.entries) {
        final ref = FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('mesas')
            .doc(entry.key);
        batch.update(ref, {'pos_x': entry.value.dx, 'pos_y': entry.value.dy});
      }
      await batch.commit();
      if (mounted) {
        setState(() => _localPos.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Plano guardado'),
            backgroundColor: Color(0xFF1D9E75),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Crear mesa nueva ──────────────────────────────────────────────────────

  Future<void> _crearMesa(String forma, double posX, double posY) async {
    final col = FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('mesas');
    final numero = _mesas.length + 1;
    await col.add({
      'nombre': 'Mesa $numero',
      'zona': _zonas.isNotEmpty ? _zonas.first : 'Salón',
      'capacidad': 4,
      'estado': 'libre',
      'numero': numero,
      'pos_x': posX,
      'pos_y': posY,
      'mesa_ancho': forma == 'bar' ? 0.28 : 0.18,
      'mesa_alto': forma == 'bar' ? 0.09 : 0.14,
      'forma': forma,
    });
  }

  // ── Cuando se suelta un drag sobre el canvas ──────────────────────────────

  void _onCanvasDrop(PlanoCanvasDrag drag, DragTargetDetails<PlanoCanvasDrag> details) {
    final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.offset);
    final size = box.size;
    final nx = (local.dx / size.width).clamp(0.01, 0.92);
    final ny = (local.dy / size.height).clamp(0.01, 0.88);

    if (drag.mesaId != null) {
      // Mesa existente reposicionada
      setState(() => _localPos[drag.mesaId!] = Offset(nx, ny));
    } else {
      // Mesa nueva desde el panel
      _crearMesa(drag.forma, nx, ny);
    }
  }

  // ── Navegar al TPV con la mesa seleccionada ───────────────────────────────

  void _abrirMesaEnTpv(Mesa mesa) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TpvRootScreen(
          empresaId: widget.empresaId,
          esAdmin: widget.esAdmin,
          esPropietario: widget.esPropietario,
          mesaInicialId: mesa.id,
        ),
      ),
    );
  }

  // ── Actualizar propiedad de una mesa en Firestore ─────────────────────────

  Future<void> _actualizarMesa(String mesaId, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('mesas')
        .doc(mesaId)
        .update(data);
  }

  Future<void> _eliminarMesa(Mesa mesa) async {
    if (mesa.esOcupada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede eliminar una mesa ocupada')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar mesa'),
        content: Text('¿Eliminar "${mesa.nombre.isNotEmpty ? mesa.nombre : "Mesa ${mesa.numero}"}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('mesas')
        .doc(mesa.id)
        .delete();
    if (mounted) setState(() => _mesaSeleccionadaId = null);
  }

  // ── Añadir zona ───────────────────────────────────────────────────────────

  Future<void> _agregarZona() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nueva zona'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre de la zona'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    if (nombre != null && nombre.isNotEmpty && !_zonas.contains(nombre)) {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('zonas_tpv')
          .add({'nombre': nombre});
      if (mounted) setState(() => _zonas.add(nombre));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('mesas')
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _cian));
          }

          _mesas = snap.data!.docs
              .map((d) => Mesa.fromFirestore(d, empresaId: widget.empresaId))
              .toList();

          // Extraer zonas únicas
          final zonasFirestore = _mesas.map((m) => m.zona).where((z) => z.isNotEmpty).toSet().toList();
          if (zonasFirestore.isNotEmpty) {
            for (final z in zonasFirestore) {
              if (!_zonas.contains(z)) _zonas.add(z);
            }
          }

          final enEdicion = _modo == ModoPlano.edicion;

          return Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // ── Panel izquierdo (solo edición) ────────────────────
                    if (enEdicion) _PanelIzquierdo(
                      zonas: _zonas,
                      onAgregarZona: _agregarZona,
                    ),
                    // ── Canvas central ────────────────────────────────────
                    Expanded(
                      child: _buildCanvas(enEdicion),
                    ),
                    // ── Panel derecho (solo edición + mesa seleccionada) ──
                    if (enEdicion && _mesaSeleccionadaId != null)
                      _buildPanelPropiedades(),
                  ],
                ),
              ),
              // ── Barra inferior ────────────────────────────────────────
              _BarraContadores(mesas: _mesas),
            ],
          );
        },
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0D0D1A),
      foregroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 48,
      title: Row(
        children: [
          const SizedBox(width: 4),
          const Icon(Icons.table_restaurant, size: 18, color: _cian),
          const SizedBox(width: 8),
          const Text(
            'Plano del restaurante',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 16),
          // ── Toggle modo ──────────────────────────────────────────────
          _ModoToggle(
            modo: _modo,
            onChanged: _cambiarModo,
          ),
          const Spacer(),
          if (_modo == ModoPlano.edicion) ...[
            if (_localPos.isNotEmpty)
              FilledButton.icon(
                onPressed: _guardando ? null : _guardarPlano,
                icon: _guardando
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save, size: 14),
                label: const Text('Guardar', style: TextStyle(fontSize: 12)),
                style: FilledButton.styleFrom(
                  backgroundColor: _cian,
                  foregroundColor: Colors.black,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.settings, size: 18),
            onPressed: _mostrarAjustes,
            tooltip: 'Ajustes del plano',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ── Canvas central ────────────────────────────────────────────────────────

  Widget _buildCanvas(bool enEdicion) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cw = constraints.maxWidth;
        final ch = constraints.maxHeight;

        final canvasContent = Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Fondo grid puntos
            CustomPaint(
              size: Size(cw, ch),
              painter: _DotGridPainter(),
            ),
            if (_mesas.isEmpty)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.table_restaurant, size: 52, color: Colors.white12),
                    SizedBox(height: 12),
                    Text('Sin mesas',
                        style: TextStyle(color: Colors.white24, fontSize: 14)),
                    Text('Arrastra una forma desde el panel izquierdo',
                        style: TextStyle(color: Colors.white12, fontSize: 11)),
                  ],
                ),
              ),
            // Mesas posicionadas
            for (final mesa in _mesas)
              _buildMesaPositioned(mesa, cw, ch, enEdicion),
          ],
        );

        if (!enEdicion) {
          return SizedBox.expand(
            key: _canvasKey,
            child: canvasContent,
          );
        }

        // En modo edición: DragTarget sobre el canvas
        return DragTarget<PlanoCanvasDrag>(
          key: _canvasKey,
          onAcceptWithDetails: (details) => _onCanvasDrop(details.data, details),
          builder: (context, candidateData, rejectedData) {
            return Stack(
              children: [
                canvasContent,
                if (candidateData.isNotEmpty)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _cian.withValues(alpha: 0.4), width: 2),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMesaPositioned(Mesa mesa, double cw, double ch, bool enEdicion) {
    final pos = _localPos[mesa.id] ?? Offset(mesa.posX, mesa.posY);
    final w = (mesa.mesaAncho * cw).clamp(70.0, cw * 0.4);
    final h = (mesa.mesaAlto * ch).clamp(50.0, ch * 0.35);
    final left = (pos.dx * cw).clamp(0.0, cw - w);
    final top = (pos.dy * ch).clamp(0.0, ch - h);
    final seleccionada = mesa.id == _mesaSeleccionadaId;

    return Positioned(
      left: left,
      top: top,
      width: w,
      height: h,
      child: MesaCanvasItem(
        mesa: mesa,
        seleccionada: seleccionada,
        modoEdicion: enEdicion,
        onTap: () {
          if (enEdicion) {
            setState(() => _mesaSeleccionadaId =
                seleccionada ? null : mesa.id);
          } else {
            _abrirMesaEnTpv(mesa);
          }
        },
        onDropped: enEdicion
            ? (nx, ny) => setState(() => _localPos[mesa.id] = Offset(nx, ny))
            : null,
      ),
    );
  }

  // ── Panel propiedades (derecho) ───────────────────────────────────────────

  Widget _buildPanelPropiedades() {
    final mesa = _mesas.firstWhere(
      (m) => m.id == _mesaSeleccionadaId,
      orElse: () => _mesas.first,
    );
    return _PanelPropiedades(
      mesa: mesa,
      zonas: _zonas,
      onGuardar: (data) => _actualizarMesa(mesa.id, data),
      onEliminar: () => _eliminarMesa(mesa),
      onCerrar: () => setState(() => _mesaSeleccionadaId = null),
    );
  }

  // ── Ajustes ───────────────────────────────────────────────────────────────

  void _mostrarAjustes() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            leading: Icon(Icons.help_outline, color: Colors.white54),
            title: Text('Modo servicio: toca una mesa para abrirla en el TPV',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          const ListTile(
            leading: Icon(Icons.edit_location_alt, color: Colors.white54),
            title: Text('Modo edición: arrastra mesas, edita propiedades y guarda',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          const Divider(color: Color(0xFF2A2A3E)),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            title: const Text('Restablecer posiciones por defecto',
                style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              setState(() => _localPos.clear());
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _ModoToggle
// ═══════════════════════════════════════════════════════════════════════════

class _ModoToggle extends StatelessWidget {
  final ModoPlano modo;
  final ValueChanged<ModoPlano> onChanged;

  const _ModoToggle({required this.modo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segmento(
            label: 'Servicio',
            icono: Icons.table_restaurant,
            activo: modo == ModoPlano.servicio,
            onTap: () => onChanged(ModoPlano.servicio),
          ),
          _Segmento(
            label: 'Edición',
            icono: Icons.edit_location_alt,
            activo: modo == ModoPlano.edicion,
            onTap: () => onChanged(ModoPlano.edicion),
          ),
        ],
      ),
    );
  }
}

class _Segmento extends StatelessWidget {
  final String label;
  final IconData icono;
  final bool activo;
  final VoidCallback onTap;

  const _Segmento({
    required this.label,
    required this.icono,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const cian = Color(0xFF00FFC8);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: activo ? cian.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: activo ? cian.withValues(alpha: 0.6) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 12, color: activo ? cian : Colors.white38),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: activo ? cian : Colors.white38,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _PanelIzquierdo
// ═══════════════════════════════════════════════════════════════════════════

class _PanelIzquierdo extends StatelessWidget {
  final List<String> zonas;
  final VoidCallback onAgregarZona;

  const _PanelIzquierdo({required this.zonas, required this.onAgregarZona});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      color: const Color(0xFF1A1A2E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Añadir mesa ────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Text(
              'AÑADIR MESA',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: const [
                NuevaMesaDraggable(
                    forma: 'rect', icono: Icons.crop_square, etiqueta: 'Rectangular'),
                SizedBox(height: 6),
                NuevaMesaDraggable(
                    forma: 'circle', icono: Icons.circle_outlined, etiqueta: 'Redonda'),
                SizedBox(height: 6),
                NuevaMesaDraggable(
                    forma: 'bar', icono: Icons.horizontal_rule, etiqueta: 'Barra'),
              ],
            ),
          ),
          const Divider(color: Color(0xFF2A2A3E), height: 24),
          // ── Zonas ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'ZONAS',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 14, color: Color(0xFF00FFC8)),
                  onPressed: onAgregarZona,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: 'Nueva zona',
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: zonas.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3E),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    zonas[i],
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _PanelPropiedades
// ═══════════════════════════════════════════════════════════════════════════

class _PanelPropiedades extends StatefulWidget {
  final Mesa mesa;
  final List<String> zonas;
  final Future<void> Function(Map<String, dynamic> data) onGuardar;
  final VoidCallback onEliminar;
  final VoidCallback onCerrar;

  const _PanelPropiedades({
    required this.mesa,
    required this.zonas,
    required this.onGuardar,
    required this.onEliminar,
    required this.onCerrar,
  });

  @override
  State<_PanelPropiedades> createState() => _PanelPropiedadesState();
}

class _PanelPropiedadesState extends State<_PanelPropiedades> {
  late TextEditingController _nombreCtrl;
  late String _zona;
  late int _capacidad;
  late String _forma;
  late String _estado;

  @override
  void initState() {
    super.initState();
    _reset(widget.mesa);
  }

  @override
  void didUpdateWidget(_PanelPropiedades old) {
    super.didUpdateWidget(old);
    if (old.mesa.id != widget.mesa.id) _reset(widget.mesa);
  }

  void _reset(Mesa m) {
    _nombreCtrl = TextEditingController(text: m.nombre);
    _zona = m.zona.isNotEmpty ? m.zona : (widget.zonas.isNotEmpty ? widget.zonas.first : 'Salón');
    _capacidad = m.capacidad;
    _forma = m.forma;
    _estado = m.estado;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  void _guardar() {
    widget.onGuardar({
      'nombre': _nombreCtrl.text.trim(),
      'zona': _zona,
      'capacidad': _capacidad,
      'forma': _forma,
      'estado': _estado,
    });
  }

  @override
  Widget build(BuildContext context) {
    const divCol = Color(0xFF2A2A3E);
    const labelStyle = TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2);
    final zonasList = widget.zonas.isNotEmpty ? widget.zonas : ['Salón'];
    if (!zonasList.contains(_zona)) _zona = zonasList.first;

    return Container(
      width: 200,
      color: const Color(0xFF1A1A2E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text('PROPIEDADES',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14, color: Colors.white38),
                  onPressed: widget.onCerrar,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
          const Divider(color: divCol, height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NOMBRE', style: labelStyle),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _nombreCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _guardar(),
                  ),
                  const SizedBox(height: 12),
                  const Text('ZONA', style: labelStyle),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<String>(
                      value: _zona,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: const Color(0xFF2A2A3E),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      items: zonasList
                          .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() { _zona = v; _guardar(); });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('CAPACIDAD', style: labelStyle),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        color: Colors.white54,
                        onPressed: _capacidad > 1
                            ? () { setState(() => _capacidad--); _guardar(); }
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Expanded(
                        child: Text(
                          '$_capacidad',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        color: Colors.white54,
                        onPressed: _capacidad < 30
                            ? () { setState(() => _capacidad++); _guardar(); }
                            : null,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('FORMA', style: labelStyle),
                  const SizedBox(height: 4),
                  _SelectorForma(
                    valor: _forma,
                    onChanged: (v) { setState(() => _forma = v); _guardar(); },
                  ),
                  const SizedBox(height: 12),
                  const Text('ESTADO', style: labelStyle),
                  const SizedBox(height: 4),
                  _SelectorEstado(
                    valor: _estado,
                    onChanged: (v) { setState(() => _estado = v); _guardar(); },
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: divCol, height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 14),
                label: const Text('Eliminar mesa', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                  side: BorderSide(color: Colors.red.shade800),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: widget.onEliminar,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Selector de forma ─────────────────────────────────────────────────────────

class _SelectorForma extends StatelessWidget {
  final String valor;
  final ValueChanged<String> onChanged;

  const _SelectorForma({required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in const {
          'rect': Icons.crop_square,
          'circle': Icons.circle_outlined,
          'bar': Icons.horizontal_rule,
        }.entries)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: valor == entry.key
                      ? const Color(0xFF00FFC8).withValues(alpha: 0.2)
                      : const Color(0xFF2A2A3E),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: valor == entry.key
                        ? const Color(0xFF00FFC8)
                        : const Color(0xFF3A3A4E),
                  ),
                ),
                child: Icon(
                  entry.value,
                  size: 16,
                  color: valor == entry.key ? const Color(0xFF00FFC8) : Colors.white38,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Selector de estado ────────────────────────────────────────────────────────

class _SelectorEstado extends StatelessWidget {
  final String valor;
  final ValueChanged<String> onChanged;

  const _SelectorEstado({required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const opciones = {
      'libre': (Color(0xFF1D9E75), 'Libre'),
      'ocupada': (Color(0xFFE24B4A), 'Ocupada'),
      'reservada': (Color(0xFFEF9F27), 'Reservada'),
    };
    return Column(
      children: opciones.entries.map((e) {
        final activo = valor == e.key;
        return GestureDetector(
          onTap: () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: activo ? e.value.$1.withValues(alpha: 0.18) : const Color(0xFF2A2A3E),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: activo ? e.value.$1 : const Color(0xFF3A3A4E),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: e.value.$1,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  e.value.$2,
                  style: TextStyle(
                    color: activo ? e.value.$1 : Colors.white38,
                    fontSize: 12,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _BarraContadores
// ═══════════════════════════════════════════════════════════════════════════

class _BarraContadores extends StatelessWidget {
  final List<Mesa> mesas;

  const _BarraContadores({required this.mesas});

  @override
  Widget build(BuildContext context) {
    final total = mesas.length;
    final libres = mesas.where((m) => m.esLibre).length;
    final ocupadas = mesas.where((m) => m.esOcupada).length;
    final reservadas = mesas.where((m) => m.esReservada).length;

    return Container(
      height: 36,
      color: const Color(0xFF0D0D1A),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Contador(label: 'TOTAL', value: total, color: Colors.white54),
          const SizedBox(width: 24),
          _Contador(label: 'LIBRES', value: libres, color: const Color(0xFF1D9E75)),
          const SizedBox(width: 24),
          _Contador(label: 'OCUPADAS', value: ocupadas, color: const Color(0xFFE24B4A)),
          const SizedBox(width: 24),
          _Contador(label: 'RESERVADAS', value: reservadas, color: const Color(0xFFEF9F27)),
        ],
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Contador({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$value', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 1)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _DotGridPainter
// ═══════════════════════════════════════════════════════════════════════════

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF12121F),
    );
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    const step = 40.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}




import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/contenido_web_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB CARTA WEB — gestión de la carta del restaurante
// Colección: empresas/{id}/carta_web
// ═════════════════════════════════════════════════════════════════════════════

const _kCategoriasBar = [
  'Bebidas', 'Cervezas', 'Vinos', 'Cafés', 'Refrescos',
  'Tapas', 'Raciones', 'Montaditos', 'Bocadillos',
  'Entrantes', 'Principales', 'Pescados', 'Carnes',
  'Arroces', 'Ensaladas', 'Verduras', 'Postres',
  'Menú del día', 'Extras',
];

class TabCartaWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color? color;

  const TabCartaWeb({
    super.key,
    required this.empresaId,
    required this.svc,
    this.color,
  });

  @override
  State<TabCartaWeb> createState() => _TabCartaWebState();
}

class _TabCartaWebState extends State<TabCartaWeb> {
  String? _filtroCategoria;
  String _busqueda = '';
  final _buscadorCtrl = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _stream;

  Color get _color => widget.color ?? const Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    _stream = widget.svc.obtenerCartaWeb(widget.empresaId);
  }

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}',
              style: const TextStyle(color: Colors.red)));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final todos = snap.data ?? [];
        final categorias = todos
            .map((i) => i['categoria'] as String? ?? 'General')
            .toSet()
            .toList()..sort();
        final disponibles = todos.where((i) => i['disponible'] != false).length;

        final filtrados = todos.where((item) {
          if (_filtroCategoria != null &&
              (item['categoria'] ?? '') != _filtroCategoria) return false;
          if (_busqueda.isNotEmpty) {
            final q = _busqueda.toLowerCase();
            return ((item['nombre'] ?? '') as String).toLowerCase().contains(q) ||
                ((item['descripcion'] ?? '') as String).toLowerCase().contains(q);
          }
          return true;
        }).toList();

        // Agrupar por categoría para mostrar secciones
        final Map<String, List<Map<String, dynamic>>> porCategoria = {};
        for (final item in filtrados) {
          final cat = item['categoria'] as String? ?? 'General';
          porCategoria.putIfAbsent(cat, () => []).add(item);
        }
        final cats = porCategoria.keys.toList()..sort();

        return Column(children: [
          _buildHeader(todos.length, disponibles, categorias),
          const Divider(height: 1),
          Expanded(
            child: filtrados.isEmpty
                ? _buildVacio(todos.isEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: cats.fold<int>(0, (s, c) => s + 1 + (porCategoria[c]!.length)),
                    itemBuilder: (_, i) {
                      int idx = 0;
                      for (final cat in cats) {
                        if (i == idx) return _buildCatHeader(cat);
                        idx++;
                        final items = porCategoria[cat]!;
                        if (i < idx + items.length) {
                          return _buildItemCard(items[i - idx]);
                        }
                        idx += items.length;
                      }
                      return const SizedBox.shrink();
                    },
                  ),
          ),
        ]);
      },
    );
  }

  Widget _buildHeader(int total, int disponibles, List<String> categorias) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Carta', style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.w800, color: _color)),
            const Text('Gestiona los platos y bebidas de tu carta',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ]),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _abrirEditor(null),
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Añadir plato'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _color, foregroundColor: Colors.white,
              elevation: 0, minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _kpiCard(Icons.restaurant_menu_rounded, _color, '$total', 'Platos'),
          const SizedBox(width: 10),
          _kpiCard(Icons.category_outlined, const Color(0xFF7C3AED),
              '${categorias.length}', 'Categorías'),
          const SizedBox(width: 10),
          _kpiCard(Icons.check_circle_rounded, const Color(0xFF10B981),
              '$disponibles', 'Disponibles'),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _buscadorCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar plato…',
                  hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 17, color: Color(0xFF94A3B8)),
                  suffixIcon: _busqueda.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 15),
                          onPressed: () {
                            _buscadorCtrl.clear();
                            setState(() => _busqueda = '');
                          })
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _busqueda = v),
              ),
            ),
          ),
          if (categorias.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _filtroCategoria,
                  hint: const Text('Todas',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16, color: Color(0xFF64748B)),
                  items: [
                    const DropdownMenuItem(value: null,
                        child: Text('Todas', style: TextStyle(fontSize: 12))),
                    ...categorias.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: const TextStyle(fontSize: 12)))),
                  ],
                  onChanged: (v) => setState(() => _filtroCategoria = v),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _kpiCard(IconData icon, Color iconColor, String valor, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE8EDF2)),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(valor, style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A))),
            Text(label, style: const TextStyle(
                fontSize: 11, color: Color(0xFF64748B))),
          ]),
        ]),
      ),
    );
  }

  Widget _buildCatHeader(String categoria) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
      child: Text(categoria.toUpperCase(),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: _color, letterSpacing: .8)),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    final nombre = item['nombre'] as String? ?? '';
    final descripcion = item['descripcion'] as String? ?? '';
    final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
    final disponible = item['disponible'] as bool? ?? true;
    final id = item['id'] as String? ?? '';
    final imgUrl = item['imagen_url'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF2)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(children: [
        if (imgUrl.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
            child: Image.network(imgUrl, width: 64, height: 64, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        Expanded(
          child: InkWell(
            onTap: () => _abrirEditor(item),
            borderRadius: imgUrl.isEmpty
                ? const BorderRadius.only(
                    topLeft: Radius.circular(12), bottomLeft: Radius.circular(12))
                : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(nombre, style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: disponible
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8))),
                  ),
                  Text(precio == 0
                          ? 'Consultar'
                          : '${precio % 1 == 0 ? precio.toInt() : precio.toStringAsFixed(2)}€',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800,
                          color: disponible ? _color : const Color(0xFF94A3B8))),
                ]),
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(descripcion, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B))),
                ],
              ]),
            ),
          ),
        ),
        // Toggle disponible
        Switch(
          value: disponible,
          activeColor: const Color(0xFF10B981),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: id.isEmpty ? null : (v) async {
            await widget.svc.toggleDisponibleCartaWeb(widget.empresaId, id, v);
          },
        ),
        // Borrar
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              size: 18, color: Color(0xFFCBD5E1)),
          onPressed: id.isEmpty ? null : () => _confirmarBorrar(id, nombre),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 4),
      ]),
    );
  }

  Widget _buildVacio(bool sinDatos) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.restaurant_menu_rounded, size: 56,
          color: _color.withValues(alpha: 0.2)),
      const SizedBox(height: 16),
      Text(sinDatos ? 'La carta está vacía' : 'Sin resultados',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
              color: Color(0xFF334155))),
      const SizedBox(height: 6),
      const Text('Pulsa "Añadir plato" para empezar',
          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: () => _abrirEditor(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Añadir primer plato'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _color, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    ]));
  }

  Future<void> _confirmarBorrar(String id, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Eliminar "$nombre"',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: const Text('Se eliminará este plato de la carta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.svc.eliminarItemCartaWeb(widget.empresaId, id);
    }
  }

  void _abrirEditor(Map<String, dynamic>? item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditorItemCarta(
        item: item,
        color: _color,
        onGuardar: (data) async {
          await widget.svc.guardarItemCartaWeb(widget.empresaId, data);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Editor inline de ítem de carta
// ─────────────────────────────────────────────────────────────────────────────

class _EditorItemCarta extends StatefulWidget {
  final Map<String, dynamic>? item;
  final Color color;
  final Future<void> Function(Map<String, dynamic>) onGuardar;

  const _EditorItemCarta({this.item, required this.color, required this.onGuardar});

  @override
  State<_EditorItemCarta> createState() => _EditorItemCartaState();
}

class _EditorItemCartaState extends State<_EditorItemCarta> {
  final _nombreCtrl      = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _precioCtrl      = TextEditingController();
  final _categoriaCtrl   = TextEditingController();
  final _imagenCtrl      = TextEditingController();
  bool _disponible = true;
  bool _guardando  = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _nombreCtrl.text      = item['nombre'] as String? ?? '';
      _descripcionCtrl.text = item['descripcion'] as String? ?? '';
      final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
      _precioCtrl.text = precio == 0 ? '' : precio.toString();
      _disponible = item['disponible'] as bool? ?? true;
      _categoriaCtrl.text = item['categoria'] as String? ?? '';
      _imagenCtrl.text    = item['imagen_url'] as String? ?? '';
    }
    _categoriaCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    _categoriaCtrl.dispose();
    _imagenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Row(children: [
          Text(widget.item == null ? 'Nuevo plato' : 'Editar plato',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A))),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
        const SizedBox(height: 18),
        _field(_nombreCtrl, 'Nombre del plato', required: true),
        const SizedBox(height: 12),
        _field(_descripcionCtrl, 'Descripción (opcional)', maxLines: 2),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _field(_precioCtrl, 'Precio (€)',
                tipo: TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
          ),
          const SizedBox(width: 12),
          Expanded(child: _field(_categoriaCtrl, 'Categoría',
              hint: 'Bebidas, Tapas…')),
        ]),
        // Sugerencias de categoría
        if (_categoriaCtrl.text.isEmpty || _kCategoriasBar
            .any((c) => c.toLowerCase().contains(_categoriaCtrl.text.toLowerCase()))) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 4,
            children: _kCategoriasBar
                .where((c) {
                  final q = _categoriaCtrl.text.trim().toLowerCase();
                  return q.isEmpty || c.toLowerCase().contains(q);
                })
                .take(9)
                .map((c) => GestureDetector(
                  onTap: () {
                    _categoriaCtrl.text = c;
                    _categoriaCtrl.selection = TextSelection.fromPosition(
                        TextPosition(offset: c.length));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _categoriaCtrl.text == c
                          ? widget.color.withValues(alpha: 0.12)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _categoriaCtrl.text == c
                            ? widget.color
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(c, style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w500,
                        color: _categoriaCtrl.text == c
                            ? widget.color
                            : const Color(0xFF475569))),
                  ),
                ))
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        _field(_imagenCtrl, 'URL de imagen (opcional)',
            hint: 'https://…/foto-del-plato.jpg'),
        const SizedBox(height: 14),
        Row(children: [
          const Text('Disponible en carta',
              style: TextStyle(fontSize: 14, color: Color(0xFF334155))),
          const Spacer(),
          Switch(
            value: _disponible,
            activeColor: const Color(0xFF10B981),
            onChanged: (v) => setState(() => _disponible = v),
          ),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _guardando ? null : _guardar,
            style: FilledButton.styleFrom(
              backgroundColor: widget.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _guardando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(widget.item == null ? 'Añadir plato' : 'Guardar cambios',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {
    bool required = false, int maxLines = 1,
    TextInputType? tipo, List<TextInputFormatter>? inputFormatters,
    String? hint,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: tipo,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _guardando = true);
    try {
      final precio = double.tryParse(_precioCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final imgUrl = _imagenCtrl.text.trim();
      final data = <String, dynamic>{
        if (widget.item?['id'] != null) 'id': widget.item!['id'],
        'nombre':      nombre,
        'descripcion': _descripcionCtrl.text.trim(),
        'precio':      precio,
        'categoria':   _categoriaCtrl.text.trim(),
        'disponible':  _disponible,
        if (imgUrl.isNotEmpty) 'imagen_url': imgUrl,
        if (imgUrl.isEmpty) 'imagen_url': '',
        if (widget.item?['orden'] != null) 'orden': widget.item!['orden'],
      };
      await widget.onGuardar(data);
    } catch (_) {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

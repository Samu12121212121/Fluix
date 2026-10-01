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

// Muestra un bottom sheet con las categorías existentes en la carta y permite
// renombrarlas o eliminar todos los platos de una categoría.
Future<void> mostrarGestionCategorias(
    BuildContext context, String empresaId, Color color) async {
  final svc = ContenidoWebService();
  final snap = await svc.obtenerCartaWeb(empresaId).first;
  final cats = snap.map((p) => p['categoria'] as String? ?? '').toSet().toList()
    ..sort();
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => _GestionCategoriasSheet(
        empresaId: empresaId, categorias: cats, color: color, svc: svc),
  );
}

class _GestionCategoriasSheet extends StatefulWidget {
  final String empresaId;
  final List<String> categorias;
  final Color color;
  final ContenidoWebService svc;
  const _GestionCategoriasSheet(
      {required this.empresaId, required this.categorias,
       required this.color, required this.svc});
  @override State<_GestionCategoriasSheet> createState() => _GestionCategoriasSheetState();
}

class _GestionCategoriasSheetState extends State<_GestionCategoriasSheet> {
  late List<String> _cats;
  bool _modoAdd = false;
  final _addCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cats = List.from(widget.categorias);
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  Future<void> _renombrar(String vieja) async {
    final ctrl = TextEditingController(text: vieja);
    final nueva = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar categoría'),
        content: TextField(controller: ctrl, autofocus: true,
            decoration: const InputDecoration(labelText: 'Nuevo nombre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (nueva == null || nueva.isEmpty || nueva == vieja || !mounted) return;
    final items = await widget.svc.obtenerCartaWeb(widget.empresaId).first;
    for (final item in items) {
      if (item['categoria'] == vieja && item['id'] != null) {
        await widget.svc.guardarItemCartaWeb(widget.empresaId,
            {...item, 'categoria': nueva});
      }
    }
    if (mounted) setState(() {
      final i = _cats.indexOf(vieja);
      if (i >= 0) _cats[i] = nueva;
    });
  }

  void _confirmarNueva() {
    final nueva = _addCtrl.text.trim();
    if (nueva.isNotEmpty && !_cats.contains(nueva)) {
      setState(() { _cats.add(nueva); _cats.sort(); });
    }
    _addCtrl.clear();
    setState(() => _modoAdd = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Row(children: [
            Text('Categorías de la carta',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                    color: widget.color)),
            const Spacer(),
            if (!_modoAdd)
              TextButton.icon(
                onPressed: () => setState(() => _modoAdd = true),
                icon: Icon(Icons.add_rounded, size: 16, color: widget.color),
                label: Text('Nueva', style: TextStyle(color: widget.color, fontSize: 13)),
              ),
            IconButton(icon: const Icon(Icons.close, size: 18),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        if (_modoAdd) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _addCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Nombre de la categoría…',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: widget.color)),
                  ),
                  onSubmitted: (_) => _confirmarNueva(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _confirmarNueva,
                style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10)),
                child: const Text('Añadir'),
              ),
              TextButton(
                onPressed: () {
                  _addCtrl.clear();
                  setState(() => _modoAdd = false);
                },
                child: const Text('Cancelar',
                    style: TextStyle(color: Color(0xFF94A3B8))),
              ),
            ]),
          ),
        ],
        const Divider(height: 1),
        Container(
          padding: const EdgeInsets.all(10),
          color: const Color(0xFFF8F9FB),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 13,
                color: Color(0xFF64748B)),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Las categorías aparecen como opciones al crear platos. Renombrar una categoría actualiza todos sus platos.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ),
          ]),
        ),
        const Divider(height: 1),
        if (_cats.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Añade categorías con el botón "Nueva"',
                style: TextStyle(color: Color(0xFF94A3B8))),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _cats.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (_, i) => ListTile(
                leading: Icon(Icons.label_outline_rounded,
                    color: widget.color, size: 20),
                title: Text(_cats[i],
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18,
                      color: Color(0xFF94A3B8)),
                  onPressed: () => _renombrar(_cats[i]),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
      ]),
    );
  }
}

class TabCartaWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color? color;
  final String? seccionId;

  const TabCartaWeb({
    super.key,
    required this.empresaId,
    required this.svc,
    this.color,
    this.seccionId,
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

  // Sincroniza carta_web → contenido_web para webs que usan data-fluix-seccion
  void _sync() {
    final sid = widget.seccionId;
    if (sid != null && sid.isNotEmpty) {
      widget.svc.sincronizarCartaASeccion(widget.empresaId, sid);
    }
  }

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
          OutlinedButton.icon(
            onPressed: () => mostrarGestionCategorias(
                context, widget.empresaId, _color),
            icon: const Icon(Icons.label_outline_rounded, size: 14),
            label: const Text('Categorías'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7C3AED),
              side: const BorderSide(color: Color(0xFF7C3AED)),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
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
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(valor, style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A))),
            Text(label, style: const TextStyle(
                fontSize: 11, color: Color(0xFF64748B))),
          ])),
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

  static const _kAlergenoEmojis = {
    'gluten': '🌾', 'crustaceos': '🦐', 'huevos': '🥚',
    'pescado': '🐟', 'cacahuetes': '🥜', 'soja': '🫘',
    'leche': '🥛', 'frutos_secos': '🌰', 'apio': '🌿',
    'mostaza': '🟡', 'sesamo': '🫙', 'sulfitos': '🍷',
    'altramuces': '🌱', 'moluscos': '🐚',
    // legacy text variants
    'Gluten': '🌾', 'Huevos': '🥚', 'Lácteos': '🥛',
    'Pescado': '🐟', 'Crustáceos': '🦐',
  };

  Widget _buildItemCard(Map<String, dynamic> item) {
    final nombre = item['nombre'] as String? ?? '';
    final descripcion = item['descripcion'] as String? ?? '';
    final precio = (item['precio'] as num?)?.toDouble() ?? 0.0;
    final precioTexto = item['precio_texto'] as String? ?? '';
    final disponible = item['disponible'] as bool? ?? true;
    final id = item['id'] as String? ?? '';
    final imgUrl = item['imagen_url'] as String? ?? '';
    final alergenos = (item['alergenos'] as List?)?.cast<String>() ?? [];

    final precioDisplay = precioTexto.isNotEmpty
        ? precioTexto
        : precio == 0
            ? 'Consultar'
            : '${precio % 1 == 0 ? precio.toInt() : precio.toStringAsFixed(2)}€';

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
        // Thumbnail más grande
        if (imgUrl.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
            child: Image.network(imgUrl, width: 76, height: 76, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    width: 76, height: 76,
                    color: _color.withValues(alpha: 0.06),
                    child: Icon(Icons.image_outlined, size: 28,
                        color: _color.withValues(alpha: 0.3)))),
          )
        else
          Container(
            width: 6,
            decoration: BoxDecoration(
              color: disponible ? _color.withValues(alpha: 0.5)
                               : const Color(0xFFE2E8F0),
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12)),
            ),
          ),
        Expanded(
          child: InkWell(
            onTap: () => _abrirEditor(item),
            borderRadius: imgUrl.isEmpty ? BorderRadius.zero : BorderRadius.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(nombre, style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: disponible
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8))),
                  ),
                  const SizedBox(width: 6),
                  Text(precioDisplay,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800,
                          color: disponible ? _color : const Color(0xFF94A3B8))),
                ]),
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(descripcion, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
                // ── Alérgenos ──────────────────────────────────────────
                if (alergenos.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(spacing: 3, runSpacing: 2,
                    children: alergenos.take(6).map((a) {
                      final emoji = _kAlergenoEmojis[a] ?? '⚠';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: Text('$emoji ${a.length > 8 ? a.substring(0,7) : a}',
                            style: const TextStyle(fontSize: 9,
                                color: Color(0xFF9A3412))),
                      );
                    }).toList()),
                ],
              ]),
            ),
          ),
        ),
        // Acciones
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Switch(
            value: disponible,
            activeColor: const Color(0xFF10B981),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: id.isEmpty ? null : (v) async {
              await widget.svc.toggleDisponibleCartaWeb(widget.empresaId, id, v);
              _sync();
            },
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            // Duplicar
            GestureDetector(
              onTap: id.isEmpty ? null : () => _duplicar(item),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: Icon(Icons.copy_rounded, size: 15, color: Color(0xFFCBD5E1)),
              ),
            ),
            // Borrar
            GestureDetector(
              onTap: id.isEmpty ? null : () => _confirmarBorrar(id, nombre),
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.delete_outline_rounded, size: 15,
                    color: Color(0xFFCBD5E1)),
              ),
            ),
          ]),
        ]),
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

  Future<void> _duplicar(Map<String, dynamic> item) async {
    final copia = Map<String, dynamic>.from(item)
      ..remove('id')
      ..['nombre'] = '${item['nombre'] ?? 'Plato'} (copia)'
      ..['disponible'] = false;
    await widget.svc.guardarItemCartaWeb(widget.empresaId, copia);
    _sync();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Plato duplicado — aparece oculto, actívalo cuando esté listo'),
      backgroundColor: Color(0xFF10B981),
      duration: Duration(seconds: 3),
    ));
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
      _sync();
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
        empresaId: widget.empresaId,
        svc: widget.svc,
        onGuardar: (data) async {
          await widget.svc.guardarItemCartaWeb(widget.empresaId, data);
          _sync();
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
  final String empresaId;
  final ContenidoWebService svc;
  final Future<void> Function(Map<String, dynamic>) onGuardar;

  const _EditorItemCarta({
    this.item,
    required this.color,
    required this.empresaId,
    required this.svc,
    required this.onGuardar,
  });

  @override
  State<_EditorItemCarta> createState() => _EditorItemCartaState();
}

class _EditorItemCartaState extends State<_EditorItemCarta> {
  final _nombreCtrl      = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _precioTextoCtrl = TextEditingController();
  final _categoriaCtrl   = TextEditingController();
  final _imagenCtrl      = TextEditingController();
  bool _disponible  = true;
  bool _guardando   = false;
  bool _subiendoImg = false;
  final List<String> _alergenos = [];

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _nombreCtrl.text      = item['nombre'] as String? ?? '';
      _descripcionCtrl.text = item['descripcion'] as String? ?? '';
      _disponible = item['disponible'] as bool? ?? true;
      _categoriaCtrl.text   = item['categoria'] as String? ?? '';
      _imagenCtrl.text      = item['imagen_url'] as String? ?? '';
      _precioTextoCtrl.text = item['precio_texto'] as String? ?? '';
      final alerg = item['alergenos'];
      if (alerg is List) _alergenos.addAll(alerg.cast<String>());
    }
    _categoriaCtrl.addListener(() => setState(() {}));
    _imagenCtrl.addListener(() => setState(() {}));
    _precioTextoCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioTextoCtrl.dispose();
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
          Expanded(child: _field(_precioTextoCtrl, 'Precio',
              hint: 'ej: 4,50€  /  1,50€ / ud.')),
          const SizedBox(width: 8),
          Expanded(child: _field(_categoriaCtrl, 'Categoría',
              hint: 'Tapas, Carnes…')),
        ]),
        const SizedBox(height: 12),
        // ── Alérgenos ─────────────────────────────────────────────────────
        _buildAlergenos(),
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
        // ── Imagen ──────────────────────────────────────────────────────────
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Preview
          GestureDetector(
            onTap: _subirImagen,
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                image: _imagenCtrl.text.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(_imagenCtrl.text),
                        fit: BoxFit.cover,
                        onError: (_, __) {})
                    : null,
              ),
              child: _imagenCtrl.text.isEmpty
                  ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _subiendoImg
                          ? SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: widget.color))
                          : Icon(Icons.add_photo_alternate_rounded,
                              size: 24, color: widget.color.withValues(alpha: 0.5)),
                      if (!_subiendoImg) ...[
                        const SizedBox(height: 3),
                        Text('Foto', style: TextStyle(
                            fontSize: 10, color: widget.color.withValues(alpha: 0.5))),
                      ],
                    ])
                  : _subiendoImg
                      ? const Center(child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                      : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            _field(_imagenCtrl, 'URL de imagen',
                hint: 'Se rellena al subir foto'),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _subiendoImg ? null : _subirImagen,
                  icon: _subiendoImg
                      ? SizedBox(width: 13, height: 13,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: widget.color))
                      : const Icon(Icons.upload_rounded, size: 14),
                  label: Text(_subiendoImg ? 'Subiendo…' : 'Subir foto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.color,
                    side: BorderSide(color: widget.color.withValues(alpha: 0.4)),
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              if (_imagenCtrl.text.isNotEmpty) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: Color(0xFFCBD5E1)),
                  onPressed: () => setState(() => _imagenCtrl.text = ''),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ]),
          ])),
        ]),
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

  static const _kAlergenosOpciones = [
    ('gluten', '🌾 Gluten'),
    ('crustaceos', '🦐 Crustáceos'),
    ('huevos', '🥚 Huevos'),
    ('pescado', '🐟 Pescado'),
    ('cacahuetes', '🥜 Cacahuetes'),
    ('soja', '🫘 Soja'),
    ('leche', '🥛 Lácteos'),
    ('frutos_secos', '🌰 Frutos secos'),
    ('apio', '🌿 Apio'),
    ('mostaza', '🟡 Mostaza'),
    ('sesamo', '🫙 Sésamo'),
    ('sulfitos', '🍷 Sulfitos'),
    ('altramuces', '🌱 Altramuces'),
    ('moluscos', '🐚 Moluscos'),
  ];

  Widget _buildAlergenos() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Alérgenos', style: TextStyle(fontSize: 12,
          color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6,
        children: _kAlergenosOpciones.map(((String val, String label) a) {
          final sel = _alergenos.contains(a.$1);
          return GestureDetector(
            onTap: () => setState(() {
              sel ? _alergenos.remove(a.$1) : _alergenos.add(a.$1);
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: sel ? const Color(0xFFFFF7ED) : const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: sel ? const Color(0xFFFB923C) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(a.$2, style: TextStyle(
                  fontSize: 11,
                  color: sel ? const Color(0xFF9A3412) : const Color(0xFF64748B),
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            ),
          );
        }).toList()),
    ]);
  }

  Future<void> _subirImagen() async {
    setState(() => _subiendoImg = true);
    try {
      final itemId = widget.item?['id'] as String?
          ?? 'plato_${DateTime.now().millisecondsSinceEpoch}';
      // Sube a Storage y devuelve URL pública — sin tocar Firestore todavía
      final url = await widget.svc.subirImagenDesdeGaleria(
          widget.empresaId, 'web/carta/$itemId');
      if (url != null && mounted) setState(() => _imagenCtrl.text = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al subir imagen: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _subiendoImg = false);
    }
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) return;
    setState(() => _guardando = true);
    try {
      final imgUrl = _imagenCtrl.text.trim();
      final data = <String, dynamic>{
        if (widget.item?['id'] != null) 'id': widget.item!['id'],
        'nombre':       nombre,
        'descripcion':  _descripcionCtrl.text.trim(),
        'precio_texto': _precioTextoCtrl.text.trim(),
        'categoria':    _categoriaCtrl.text.trim(),
        'disponible':   _disponible,
        'alergenos':    List<String>.from(_alergenos),
        'imagen_url':   imgUrl,
        if (widget.item?['orden'] != null) 'orden': widget.item!['orden'],
      };
      await widget.onGuardar(data);
    } catch (_) {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

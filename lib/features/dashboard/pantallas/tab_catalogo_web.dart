import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB CATÁLOGO WEB — catálogo genérico, mismo estilo que Secciones
// Colección: empresas/{id}/catalogo_web
// Sync inmediato a la web: toggle/borrar/añadir → onSnapshot en el script
// ═════════════════════════════════════════════════════════════════════════════

class TabCatalogoWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color? color;
  final void Function(Map<String, dynamic>? item)? onAbrirEditor;

  const TabCatalogoWeb({
    super.key,
    required this.empresaId,
    required this.svc,
    this.color,
    this.onAbrirEditor,
  });

  @override
  State<TabCatalogoWeb> createState() => _TabCatalogoWebState();
}

class _TabCatalogoWebState extends State<TabCatalogoWeb> {
  bool _autoMigradoChecked = false;
  String _busqueda = '';
  String? _filtroCategoria;
  final _buscadorCtrl = TextEditingController();
  // Stream cacheado: no se recrea en cada setState, evita el parpadeo del buscador
  late final Stream<List<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.svc.obtenerCatalogoWeb(widget.empresaId);
  }

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    super.dispose();
  }

  /// Cuando el catálogo está vacío, migra automáticamente desde libros si los hay.
  Future<void> _checkAutoMigrar(List<Map<String, dynamic>> items) async {
    if (_autoMigradoChecked || items.isNotEmpty) return;
    _autoMigradoChecked = true;
    try {
      final libros = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('libros').limit(1).get();
      if (libros.docs.isEmpty) return;
      await widget.svc.migrarLibrosACatalogoWeb(widget.empresaId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.watch<AppConfigProvider>().colorPrimario;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
            const SizedBox(height: 12),
            const Text('Error al cargar el catálogo',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('${snap.error}', style: const TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center),
          ]));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final todos = snap.data ?? [];
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkAutoMigrar(todos));

        // Categorías únicas para el filtro
        final categorias = todos
            .map((i) => i['categoria'] as String? ?? '')
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()..sort();

        // Filtrado
        final filtrados = todos.where((item) {
          if (_filtroCategoria != null && item['categoria'] != _filtroCategoria) return false;
          if (_busqueda.isNotEmpty) {
            final q = _busqueda.toLowerCase();
            return (item['nombre'] ?? '').toLowerCase().contains(q) ||
                (item['campo_autor'] ?? '').toLowerCase().contains(q) ||
                (item['categoria'] ?? '').toLowerCase().contains(q);
          }
          return true;
        }).toList();

        final activos = todos.where((i) => i['activo'] as bool? ?? true).length;

        return Column(children: [
          // ── Header — KPIs ────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Catálogo',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A))),
                  const Text('Gestiona y organiza todos los ítems del catálogo',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ]),
                const Spacer(),
              ]),
              const SizedBox(height: 12),
              // KPI cards
              Row(children: [
                _kpiCard(Icons.grid_view_rounded, color,
                    '${todos.length}', 'Ítems totales'),
                const SizedBox(width: 10),
                _kpiCard(Icons.category_outlined, const Color(0xFF7C3AED),
                    '${categorias.length}', 'Categorías'),
                const SizedBox(width: 10),
                _kpiCard(Icons.check_circle_rounded, const Color(0xFF10B981),
                    '$activos', 'Disponibles'),
              ]),
              const SizedBox(height: 12),
              // Barra búsqueda + filtros + botón
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
                        hintText: 'Buscar por título, autor…',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 17, color: Color(0xFF94A3B8)),
                        suffixIcon: _busqueda.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear, size: 15),
                                onPressed: () { _buscadorCtrl.clear(); setState(() => _busqueda = ''); })
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
                        hint: const Text('Todas las categorías',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 16, color: Color(0xFF64748B)),
                        items: [
                          const DropdownMenuItem(value: null,
                              child: Text('Todas las categorías',
                                  style: TextStyle(fontSize: 12))),
                          ...categorias.map((c) => DropdownMenuItem(
                              value: c, child: Text(c, style: const TextStyle(fontSize: 12)))),
                        ],
                        onChanged: (v) => setState(() => _filtroCategoria = v),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _abrirEditor(null),
                  icon: const Icon(Icons.add_rounded, size: 15),
                  label: const Text('Añadir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color, foregroundColor: Colors.white,
                    elevation: 0, minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ]),
          ),
          const Divider(height: 1),
          // ── Lista/Grid ────────────────────────────────────────────────────────
          Expanded(
            child: filtrados.isEmpty
                ? _buildVacio(context, todos.isEmpty, color)
                : _buildLista(filtrados, color),

          ),
        ]);
      },
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
            Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A))),
            Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
          ]),
        ]),
      ),
    );
  }

  Widget _buildLista(List<Map<String, dynamic>> items, Color color) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: items.length,
      onReorder: (oldIdx, newIdx) async {
        if (newIdx > oldIdx) newIdx--;
        final lista = List<Map<String, dynamic>>.from(items);
        final item = lista.removeAt(oldIdx);
        lista.insert(newIdx, item);
        final batch = FirebaseFirestore.instance.batch();
        for (var i = 0; i < lista.length; i++) {
          final id = lista[i]['id'] as String?;
          if (id == null || id.isEmpty) continue;
          batch.update(FirebaseFirestore.instance
              .collection('empresas').doc(widget.empresaId)
              .collection('catalogo_web').doc(id), {'orden': i});
        }
        await batch.commit();
      },
      itemBuilder: (_, i) => _TarjetaItemCatalogo(
        key: ValueKey(items[i]['id'] ?? i),
        item: items[i], color: color,
        onEdit: () => _abrirEditor(items[i]),
        onToggle: (v) => widget.svc.toggleActivoItemCatalogo(
            widget.empresaId, items[i]['id'] as String, v),
        onDelete: () => _confirmarEliminar(items[i]),
      ),
    );
  }

  Widget _buildVacio(BuildContext context, bool totalmenteVacio, Color color) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08), shape: BoxShape.circle),
          child: Icon(Icons.grid_view_rounded,
              size: 34, color: color.withValues(alpha: 0.45)),
        ),
        const SizedBox(height: 16),
        Text(totalmenteVacio ? 'El catálogo está vacío' : 'Sin resultados',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: Color(0xFF334155))),
        const SizedBox(height: 6),
        const Text('Añade elementos y aparecerán en tu web automáticamente',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _abrirEditor(null),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Añadir primer elemento'),
          style: ElevatedButton.styleFrom(
            backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () async {
            await widget.svc.crearLibroEjemploNazari(widget.empresaId);
            await widget.svc.migrarLibrosACatalogoWeb(widget.empresaId);
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Ejemplo añadido al catálogo'),
                  backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
          },
          icon: Icon(Icons.auto_awesome_rounded, size: 14, color: color),
          label: Text('Generar ejemplo', style: TextStyle(color: color, fontSize: 12.5)),
        ),
      ]),
    );
  }

  void _abrirEditor(Map<String, dynamic>? item) {
    widget.onAbrirEditor?.call(item);
  }

  void _confirmarEliminar(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar elemento'),
        content: Text('¿Eliminar "${item['nombre'] ?? ''}"?\n\n'
            'Desaparecerá de la web inmediatamente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.svc.eliminarItemCatalogo(
                  widget.empresaId, item['id'] as String);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta — mismo estilo que _TarjetaSeccion ────────────────────────────────

class _TarjetaItemCatalogo extends StatelessWidget {
  final Map<String, dynamic> item;
  final Color color;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _TarjetaItemCatalogo({
    super.key,
    required this.item, required this.color,
    required this.onEdit, required this.onToggle, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final activo  = item['activo'] as bool? ?? true;
    final nombre  = item['nombre'] as String? ?? 'Sin nombre';
    final precio  = item['precio'] as String? ?? '';
    final cat     = item['categoria'] as String? ?? '';
    final autor   = item['campo_autor'] as String? ?? '';
    final stripe  = (item['stripe_link'] as String? ?? '').isNotEmpty;
    final img     = item['imagen_url'] as String? ?? '';

    final subtitle = [
      if (autor.isNotEmpty) autor,
      if (precio.isNotEmpty) precio,
      if (cat.isNotEmpty) cat,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF2)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(children: [
            // Icono / miniatura
            img.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(img, width: 40, height: 40, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _iconBox(color, activo)),
                  )
                : _iconBox(color, activo),
            const SizedBox(width: 12),
            // Texto
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(nombre,
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700,
                          color: activo ? const Color(0xFF0F172A) : const Color(0xFF94A3B8)),
                      overflow: TextOverflow.ellipsis),
                ),
                if (stripe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF635BFF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Stripe',
                        style: TextStyle(fontSize: 9, color: Color(0xFF635BFF),
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ])),
            // Controles — igual que en _TarjetaSeccion
            Switch(
              value: activo,
              onChanged: onToggle,
              activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined, color: color, size: 18),
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFE53E3E), size: 18),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
            ReorderableDragStartListener(
              index: 0, // el padre ReorderableListView maneja el índice real
              child: Icon(Icons.drag_handle_rounded,
                  color: const Color(0xFFCBD5E1), size: 20),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _iconBox(Color color, bool activo) => Container(
    width: 40, height: 40,
    decoration: BoxDecoration(
      color: color.withValues(alpha: activo ? 0.1 : 0.05),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Icon(Icons.grid_view_rounded,
        color: activo ? color : const Color(0xFFCBD5E1), size: 20),
  );
}

// (Editor de item integrado en pantalla_contenido_web.dart como _EditorCatalogoEmbebido)

class _PantallaEditorItemCatalogo extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Map<String, dynamic>? item;
  final Color color;

  const _PantallaEditorItemCatalogo({
    required this.empresaId, required this.svc,
    required this.color, this.item,
  });

  @override
  State<_PantallaEditorItemCatalogo> createState() =>
      _PantallaEditorItemCatalogoState();
}

class _PantallaEditorItemCatalogoState
    extends State<_PantallaEditorItemCatalogo> {
  final _nombreCtrl      = TextEditingController();
  final _slugCtrl        = TextEditingController();
  final _categoriaCtrl   = TextEditingController();
  final _tagCtrl         = TextEditingController();
  final _imagenCtrl      = TextEditingController();
  final _precioCtrl      = TextEditingController();
  final _precioDigCtrl   = TextEditingController();
  final _stripeLinkCtrl  = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _autorCtrl       = TextEditingController();
  final _isbnCtrl        = TextEditingController();
  final _paginasCtrl     = TextEditingController();
  final _formatoCtrl     = TextEditingController();
  final _dimensionesCtrl = TextEditingController();
  final _mesCtrl         = TextEditingController();
  int  _anio  = DateTime.now().year;
  bool _activo = true;
  bool _extraExpanded = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it != null) {
      _nombreCtrl.text      = it['nombre'] ?? '';
      _slugCtrl.text        = it['slug'] ?? '';
      _categoriaCtrl.text   = it['categoria'] ?? '';
      _tagCtrl.text         = it['tag'] ?? '';
      _imagenCtrl.text      = it['imagen_url'] ?? '';
      _precioCtrl.text      = it['precio'] ?? '';
      _precioDigCtrl.text   = it['precio_digital'] ?? '';
      _stripeLinkCtrl.text  = it['stripe_link'] ?? '';
      _descCtrl.text        = it['descripcion'] ?? '';
      _autorCtrl.text       = it['campo_autor'] ?? '';
      _isbnCtrl.text        = it['campo_isbn'] ?? '';
      _paginasCtrl.text     = it['campo_paginas'] ?? '';
      _formatoCtrl.text     = it['campo_formato'] ?? '';
      _dimensionesCtrl.text = it['campo_dimensiones'] ?? '';
      _mesCtrl.text         = it['campo_mes'] ?? '';
      _anio   = int.tryParse(it['campo_anio']?.toString() ?? '') ?? DateTime.now().year;
      _activo = it['activo'] as bool? ?? true;
    }
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _slugCtrl, _categoriaCtrl, _tagCtrl,
        _imagenCtrl, _precioCtrl, _precioDigCtrl, _stripeLinkCtrl, _descCtrl,
        _autorCtrl, _isbnCtrl, _paginasCtrl, _formatoCtrl, _dimensionesCtrl, _mesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(widget.item == null ? 'Nuevo elemento' : 'Editar elemento'),
        backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
        actions: [
          TextButton(
            onPressed: _guardando ? null : () => _guardar(context),
            child: Text(_guardando ? '…' : 'Guardar',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _card(Column(children: [
            _campo(_nombreCtrl, 'Nombre / Título *'),
            const Divider(height: 1),
            _campo(_slugCtrl, 'Slug URL', hint: 'titulo-sin-espacios'),
            const Divider(height: 1),
            _campo(_categoriaCtrl, 'Categoría / Tipo'),
            const Divider(height: 1),
            _campo(_tagCtrl, 'Badge (ej: Novedad, Recomendado)'),
            const Divider(height: 1),
            _campo(_imagenCtrl, 'URL imagen', hint: 'https://…/imagen.jpg'),
          ])),
          const SizedBox(height: 10),
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _campo(_precioCtrl, 'Precio (ej: 14,50 €)'),
            const Divider(height: 1),
            _campo(_precioDigCtrl, 'Precio digital / ebook (ej: 4,99 €)'),
            const Divider(height: 1),
            _campo(_stripeLinkCtrl, 'Link de pago Stripe',
                hint: 'https://buy.stripe.com/…'),
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 4),
              child: Row(children: [
                Icon(Icons.info_outline, size: 13, color: Colors.grey[400]),
                const SizedBox(width: 5),
                Expanded(child: Text(
                  'Con Stripe link el cliente verá un botón "Comprar" en la web.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                )),
              ]),
            ),
          ])),
          const SizedBox(height: 10),
          _card(TextFormField(
            controller: _descCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Descripción / sinopsis…',
              border: InputBorder.none, contentPadding: EdgeInsets.zero),
          )),
          const SizedBox(height: 10),
          // Datos adicionales colapsibles
          GestureDetector(
            onTap: () => setState(() => _extraExpanded = !_extraExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                Icon(Icons.tune_rounded, size: 16, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text('Datos adicionales (autor, ISBN, páginas…)',
                    style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600))),
                Icon(_extraExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18, color: color),
              ]),
            ),
          ),
          if (_extraExpanded) ...[
            const SizedBox(height: 4),
            _card(Column(children: [
              _campo(_autorCtrl, 'Autor / Responsable'),
              const Divider(height: 1),
              _campo(_isbnCtrl, 'ISBN / Referencia'),
              const Divider(height: 1),
              _campo(_paginasCtrl, 'Páginas / Unidades'),
              const Divider(height: 1),
              _campo(_formatoCtrl, 'Formato'),
              const Divider(height: 1),
              _campo(_dimensionesCtrl, 'Dimensiones'),
              const Divider(height: 1),
              _campo(_mesCtrl, 'Mes'),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  const SizedBox(width: 4),
                  const Text('Año', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _anio,
                    underline: const SizedBox(),
                    items: List.generate(30, (i) => DateTime.now().year - i + 2)
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) => setState(() => _anio = v ?? _anio),
                  ),
                ]),
              ),
            ])),
          ],
          const SizedBox(height: 10),
          _card(SwitchListTile(
            value: _activo,
            onChanged: (v) => setState(() => _activo = v),
            title: Text(_activo ? '✅ Visible en la web' : '⏸ Oculto en la web',
                style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              _activo
                  ? 'El elemento aparece en el catálogo de tu sitio web'
                  : 'No aparece en el catálogo de tu sitio web',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            contentPadding: EdgeInsets.zero,
            activeColor: color,
          )),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, {String? hint}) =>
      TextField(
        controller: ctrl,
        decoration: InputDecoration(
          hintText: hint ?? label, labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10)),
      );

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );

  Future<void> _guardar(BuildContext context) async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    final docId = widget.item?['id'] as String?;
    final data = <String, dynamic>{
      'nombre':        _nombreCtrl.text.trim(),
      'slug':          _slugCtrl.text.trim(),
      'categoria':     _categoriaCtrl.text.trim(),
      'tag':           _tagCtrl.text.trim(),
      'imagen_url':    _imagenCtrl.text.trim(),
      'precio':        _precioCtrl.text.trim(),
      'precio_digital': _precioDigCtrl.text.trim(),
      'stripe_link':   _stripeLinkCtrl.text.trim(),
      'descripcion':   _descCtrl.text.trim(),
      'activo':        _activo,
    };
    void opt(String k, String v) { if (v.isNotEmpty) data[k] = v; }
    opt('campo_autor',       _autorCtrl.text.trim());
    opt('campo_isbn',        _isbnCtrl.text.trim());
    opt('campo_paginas',     _paginasCtrl.text.trim());
    opt('campo_formato',     _formatoCtrl.text.trim());
    opt('campo_dimensiones', _dimensionesCtrl.text.trim());
    opt('campo_mes',         _mesCtrl.text.trim());
    data['campo_anio'] = _anio.toString();
    try {
      await widget.svc.guardarItemCatalogo(widget.empresaId, docId, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ Guardado — visible en la web en segundos'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

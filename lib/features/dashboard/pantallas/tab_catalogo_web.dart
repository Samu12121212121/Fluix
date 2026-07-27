import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB CATÁLOGO WEB — Gestión de Libros y Autores para la web
// ═════════════════════════════════════════════════════════════════════════════

class TabCatalogoWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;

  const TabCatalogoWeb({super.key, required this.empresaId, required this.svc});

  @override
  State<TabCatalogoWeb> createState() => _TabCatalogoWebState();
}

class _TabCatalogoWebState extends State<TabCatalogoWeb>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tab,
            labelColor: color,
            unselectedLabelColor: Colors.grey[500],
            indicatorColor: color,
            tabs: const [
              Tab(icon: Icon(Icons.menu_book, size: 18), text: 'Libros'),
              Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Autores'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _TabLibros(empresaId: widget.empresaId, svc: widget.svc, color: color),
              _TabAutores(empresaId: widget.empresaId, svc: widget.svc, color: color),
            ],
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB LIBROS
// ═════════════════════════════════════════════════════════════════════════════

class _TabLibros extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color color;
  const _TabLibros({required this.empresaId, required this.svc, required this.color});

  @override
  State<_TabLibros> createState() => _TabLibrosState();
}

class _TabLibrosState extends State<_TabLibros> {
  String _busqueda = '';
  final _buscadorCtrl = TextEditingController();

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.svc.obtenerLibros(widget.empresaId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final todos = snap.data ?? [];
        final filtrados = _busqueda.isEmpty ? todos : todos.where((l) {
          final q = _busqueda.toLowerCase();
          return (l['titulo'] ?? '').toLowerCase().contains(q) ||
              (l['autor'] ?? '').toLowerCase().contains(q) ||
              (l['genero'] ?? '').toLowerCase().contains(q);
        }).toList();

        return Stack(
          children: [
            Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(children: [
                    Expanded(child: TextField(
                      controller: _buscadorCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar por título, autor o género…',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _busqueda.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _buscadorCtrl.clear();
                                  setState(() => _busqueda = '');
                                })
                            : null,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _busqueda = v),
                    )),
                    const SizedBox(width: 8),
                    Text('${filtrados.length}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ]),
                ),
                Expanded(
                  child: filtrados.isEmpty
                      ? _buildVacio(context)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                          itemCount: filtrados.length,
                          itemBuilder: (_, i) => _TarjetaLibro(
                            libro: filtrados[i],
                            color: widget.color,
                            onEdit: () => _abrirEditor(context, filtrados[i]),
                            onToggle: (v) => widget.svc.toggleActivoLibro(
                                widget.empresaId, filtrados[i]['slug'] ?? filtrados[i]['id'], v),
                          ),
                        ),
                ),
              ],
            ),
            Positioned(
              right: 16, bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_nuevo_libro',
                onPressed: () => _abrirEditor(context, null),
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('Nuevo libro'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVacio(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.menu_book_outlined, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text(_busqueda.isNotEmpty ? 'Sin resultados' : 'Sin libros',
          style: TextStyle(color: Colors.grey[600], fontSize: 16)),
    ]),
  );

  void _abrirEditor(BuildContext context, Map<String, dynamic>? libro) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PantallaEditorLibro(
        empresaId: widget.empresaId, svc: widget.svc, libro: libro),
    ));
  }
}

// ── Tarjeta libro ─────────────────────────────────────────────────────────────

class _TarjetaLibro extends StatelessWidget {
  final Map<String, dynamic> libro;
  final Color color;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;

  const _TarjetaLibro({
    required this.libro, required this.color,
    required this.onEdit, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final activo = libro['activo'] as bool? ?? true;
    final img    = libro['imagen_url'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: img.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(img, width: 36, height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _portadaFallback()))
            : _portadaFallback(),
        title: Text(libro['titulo'] ?? 'Sin título',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(
          '${libro['autor'] ?? ''} · ${libro['genero'] ?? ''} · ${libro['anio'] ?? ''}',
          style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Switch(
            value: activo,
            onChanged: onToggle,
            activeThumbColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: color, size: 18),
            onPressed: onEdit,
          ),
        ]),
        onTap: onEdit,
      ),
    );
  }

  Widget _portadaFallback() => Container(
    width: 36, height: 50,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Icon(Icons.menu_book, color: color, size: 18),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB AUTORES
// ═════════════════════════════════════════════════════════════════════════════

class _TabAutores extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color color;
  const _TabAutores({required this.empresaId, required this.svc, required this.color});

  @override
  State<_TabAutores> createState() => _TabAutoresState();
}

class _TabAutoresState extends State<_TabAutores> {
  String _busqueda = '';
  final _buscadorCtrl = TextEditingController();

  @override
  void dispose() { _buscadorCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.svc.obtenerAutores(widget.empresaId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final todos = snap.data ?? [];
        final filtrados = _busqueda.isEmpty ? todos : todos.where((a) =>
            (a['nombre'] ?? '').toLowerCase().contains(_busqueda.toLowerCase())).toList();

        return Stack(
          children: [
            Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: TextField(
                    controller: _buscadorCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar autor…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _busqueda = v),
                  ),
                ),
                Expanded(
                  child: filtrados.isEmpty
                      ? Center(child: Text('Sin autores',
                          style: TextStyle(color: Colors.grey[500])))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                          itemCount: filtrados.length,
                          itemBuilder: (_, i) => _TarjetaAutor(
                            autor: filtrados[i],
                            color: widget.color,
                            onEdit: () => _abrirEditor(context, filtrados[i]),
                          ),
                        ),
                ),
              ],
            ),
            Positioned(
              right: 16, bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_nuevo_autor',
                onPressed: () => _abrirEditor(context, null),
                backgroundColor: widget.color,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.person_add),
                label: const Text('Nuevo autor'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _abrirEditor(BuildContext context, Map<String, dynamic>? autor) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _PantallaEditorAutor(
        empresaId: widget.empresaId, svc: widget.svc, autor: autor),
    ));
  }
}

class _TarjetaAutor extends StatelessWidget {
  final Map<String, dynamic> autor;
  final Color color;
  final VoidCallback onEdit;

  const _TarjetaAutor({required this.autor, required this.color, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final foto = autor['foto_url'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: foto.isNotEmpty
            ? CircleAvatar(
                backgroundImage: NetworkImage(foto),
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.1),
              )
            : CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.1),
                child: Text(
                  (autor['nombre'] as String? ?? '?').substring(0, 1).toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
        title: Text(autor['nombre'] ?? 'Sin nombre',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Text(
          '${autor['genero'] ?? ''} · ${autor['lugar'] ?? ''}',
          style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        trailing: IconButton(
          icon: Icon(Icons.edit_outlined, color: color, size: 18),
          onPressed: onEdit,
        ),
        onTap: onEdit,
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EDITOR LIBRO
// ═════════════════════════════════════════════════════════════════════════════

class _PantallaEditorLibro extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Map<String, dynamic>? libro;
  const _PantallaEditorLibro({required this.empresaId, required this.svc, this.libro});

  @override
  State<_PantallaEditorLibro> createState() => _PantallaEditorLibroState();
}

class _PantallaEditorLibroState extends State<_PantallaEditorLibro> {
  final _tituloCtrl   = TextEditingController();
  final _autorCtrl    = TextEditingController();
  final _generoCtrl   = TextEditingController();
  final _precioCtrl   = TextEditingController();
  final _coleccionCtrl = TextEditingController();
  final _isbnCtrl     = TextEditingController();
  final _sinopsisCtrl = TextEditingController();
  final _slugCtrl     = TextEditingController();
  int  _anio = DateTime.now().year;
  bool _activo = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (widget.libro != null) {
      final l = widget.libro!;
      _tituloCtrl.text    = l['titulo'] ?? '';
      _autorCtrl.text     = l['autor'] ?? '';
      _generoCtrl.text    = l['genero'] ?? '';
      _precioCtrl.text    = l['precio'] ?? '';
      _coleccionCtrl.text = l['coleccion'] ?? '';
      _isbnCtrl.text      = l['isbn'] ?? '';
      _sinopsisCtrl.text  = l['sinopsis'] ?? '';
      _slugCtrl.text      = l['slug'] ?? '';
      _anio   = (l['anio'] as num?)?.toInt() ?? DateTime.now().year;
      _activo = l['activo'] as bool? ?? true;
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose(); _autorCtrl.dispose(); _generoCtrl.dispose();
    _precioCtrl.dispose(); _coleccionCtrl.dispose(); _isbnCtrl.dispose();
    _sinopsisCtrl.dispose(); _slugCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(widget.libro == null ? 'Nuevo libro' : 'Editar libro'),
        backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
        actions: [
          TextButton(
            onPressed: _guardando ? null : () => _guardar(context),
            child: Text(_guardando ? '...' : 'Guardar',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _card(Column(children: [
            _campo(_tituloCtrl, 'Título *'),
            const Divider(height: 1),
            _campo(_autorCtrl, 'Autor/a'),
            const Divider(height: 1),
            _campo(_slugCtrl, 'Slug (URL del libro)',
                hint: 'nombre-del-libro-sin-espacios'),
            const Divider(height: 1),
            _campo(_generoCtrl, 'Género'),
            const Divider(height: 1),
            _campo(_coleccionCtrl, 'Colección'),
            const Divider(height: 1),
            _campo(_precioCtrl, 'Precio (ej: 14,00 €)'),
            const Divider(height: 1),
            _campo(_isbnCtrl, 'ISBN'),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                const SizedBox(width: 4,),
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
          const SizedBox(height: 10),
          _card(TextFormField(
            controller: _sinopsisCtrl,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Sinopsis del libro…',
              border: InputBorder.none, contentPadding: EdgeInsets.zero),
          )),
          const SizedBox(height: 10),
          _card(SwitchListTile(
            value: _activo,
            onChanged: (v) => setState(() => _activo = v),
            title: Text(_activo ? '✅ Visible en la web' : '⏸ Oculto en la web',
                style: const TextStyle(fontSize: 13)),
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
          hintText: hint ?? label,
          labelText: label,
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
    if (_tituloCtrl.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    final slug = _slugCtrl.text.trim().isNotEmpty
        ? _slugCtrl.text.trim()
        : widget.libro?['slug'] ?? '';
    final data = {
      'slug':       slug,
      'titulo':     _tituloCtrl.text.trim(),
      'autor':      _autorCtrl.text.trim(),
      'genero':     _generoCtrl.text.trim(),
      'precio':     _precioCtrl.text.trim(),
      'coleccion':  _coleccionCtrl.text.trim(),
      'isbn':       _isbnCtrl.text.trim(),
      'sinopsis':   _sinopsisCtrl.text.trim(),
      'anio':       _anio,
      'activo':     _activo,
    };
    try {
      await widget.svc.guardarLibro(widget.empresaId, slug, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Libro guardado'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
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

// ═════════════════════════════════════════════════════════════════════════════
// EDITOR AUTOR
// ═════════════════════════════════════════════════════════════════════════════

class _PantallaEditorAutor extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Map<String, dynamic>? autor;
  const _PantallaEditorAutor({required this.empresaId, required this.svc, this.autor});

  @override
  State<_PantallaEditorAutor> createState() => _PantallaEditorAutorState();
}

class _PantallaEditorAutorState extends State<_PantallaEditorAutor> {
  final _nombreCtrl = TextEditingController();
  final _generoCtrl = TextEditingController();
  final _lugarCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _bioCtrl    = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    if (widget.autor != null) {
      final a = widget.autor!;
      _nombreCtrl.text = a['nombre'] ?? '';
      _generoCtrl.text = a['genero'] ?? '';
      _lugarCtrl.text  = a['lugar'] ?? '';
      _descCtrl.text   = a['descripcion'] ?? '';
      _bioCtrl.text    = a['bio'] ?? '';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _generoCtrl.dispose(); _lugarCtrl.dispose();
    _descCtrl.dispose(); _bioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(widget.autor == null ? 'Nuevo autor' : 'Editar autor'),
        backgroundColor: color, foregroundColor: Colors.white, elevation: 0,
        actions: [
          TextButton(
            onPressed: _guardando ? null : () => _guardar(context),
            child: Text(_guardando ? '...' : 'Guardar',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _card(Column(children: [
            _campo(_nombreCtrl, 'Nombre completo *'),
            const Divider(height: 1),
            _campo(_generoCtrl, 'Género literario (ej: Narrativa, Poesía)'),
            const Divider(height: 1),
            _campo(_lugarCtrl, 'Lugar (ej: Granada · 1980)'),
            const Divider(height: 1),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Descripción corta (para el listado)',
                  border: InputBorder.none),
            ),
          ])),
          const SizedBox(height: 10),
          _card(TextField(
            controller: _bioCtrl,
            maxLines: 8,
            decoration: const InputDecoration(
                hintText: 'Biografía completa del autor…',
                border: InputBorder.none, contentPadding: EdgeInsets.zero),
          )),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label) =>
      TextField(controller: ctrl,
          decoration: InputDecoration(labelText: label, border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10)));

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
    final docId = widget.autor?['id'] as String?;
    final data = {
      'nombre':      _nombreCtrl.text.trim(),
      'genero':      _generoCtrl.text.trim(),
      'lugar':       _lugarCtrl.text.trim(),
      'descripcion': _descCtrl.text.trim(),
      'bio':         _bioCtrl.text.trim(),
      'activo':      true,
    };
    try {
      await widget.svc.guardarAutor(widget.empresaId, docId, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Autor guardado'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
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

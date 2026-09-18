import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB SELECCIÓN NAZARÍ — elige libros del catálogo existente
// Colección Firestore: empresas/{empresaId}/seleccion_nazari
// Cada item referencia un libro de empresas/{empresaId}/catalogo_web
// ═════════════════════════════════════════════════════════════════════════════

class TabSeleccionNazari extends StatelessWidget {
  final String empresaId;

  const TabSeleccionNazari({super.key, required this.empresaId});

  CollectionReference<Map<String, dynamic>> get _selCol =>
      FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('seleccion_nazari');

  CollectionReference<Map<String, dynamic>> get _catCol =>
      FirebaseFirestore.instance
          .collection('empresas')
          .doc(empresaId)
          .collection('catalogo_web');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _selCol.orderBy('orden').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];

          return Column(children: [
            _Header(col: _selCol, total: docs.length),
            Expanded(
              child: docs.isEmpty
                  ? _buildVacio(context)
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                      itemCount: docs.length,
                      onReorder: (oldIdx, newIdx) =>
                          _reordenar(docs, oldIdx, newIdx),
                      itemBuilder: (_, i) {
                        final d = docs[i];
                        return _TarjetaLibroSeleccion(
                          key: ValueKey(d.id),
                          doc: d,
                          col: _selCol,
                          onEditar: () => _abrirEditorNota(context, d),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirSelectorCatalogo(context),
        backgroundColor: const Color(0xFF6B1E2A),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Añadir a la Selección', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _reordenar(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      int oldIdx,
      int newIdx) async {
    if (newIdx > oldIdx) newIdx--;
    final batch = FirebaseFirestore.instance.batch();
    final lista = [...docs];
    final item = lista.removeAt(oldIdx);
    lista.insert(newIdx, item);
    for (var i = 0; i < lista.length; i++) {
      batch.update(lista[i].reference, {'orden': i});
    }
    await batch.commit();
  }

  /// Abre el picker de catálogo (solo para añadir nuevo)
  void _abrirSelectorCatalogo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectorDesdeCatalogo(
        selCol: _selCol,
        catCol: _catCol,
      ),
    );
  }

  /// Abre el editor de nota editorial (solo para items ya en la selección)
  void _abrirEditorNota(
      BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetEditarNota(col: _selCol, doc: doc),
    );
  }

  Widget _buildVacio(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.stars_rounded, size: 72, color: Colors.grey[200]),
        const SizedBox(height: 16),
        Text('La Selección Nazarí está vacía',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(
          'Elige libros de tu catálogo para destacarlos\n'
          'en esta sección de la web.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => _abrirSelectorCatalogo(context),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6B1E2A)),
          icon: const Icon(Icons.add),
          label: const Text('Añadir a la Selección'),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CABECERA
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final CollectionReference<Map<String, dynamic>> col;
  final int total;
  const _Header({required this.col, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(children: [
        const Icon(Icons.stars_rounded, size: 18, color: Color(0xFF6B1E2A)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('La Selección Nazarí',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            Text(
              '$total libro${total == 1 ? '' : 's'} seleccionado${total == 1 ? '' : 's'} · Arrastra para reordenar',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA LIBRO EN LA SELECCIÓN
// ─────────────────────────────────────────────────────────────────────────────

class _TarjetaLibroSeleccion extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final CollectionReference<Map<String, dynamic>> col;
  final VoidCallback onEditar;

  const _TarjetaLibroSeleccion({
    super.key,
    required this.doc,
    required this.col,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final activo = d['activo'] as bool? ?? true;
    final esLibroDelMes = d['es_libro_del_mes'] as bool? ?? false;
    final imagen = d['imagen'] as String? ?? '';
    final titulo = d['titulo'] as String? ?? '';
    final autor = d['autor'] as String? ?? '';
    final nota = d['nota_editorial'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esLibroDelMes
              ? const Color(0xFF6B1E2A).withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6, offset: const Offset(0, 1),
        )],
      ),
      child: InkWell(
        onTap: onEditar,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Portada
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: imagen.isNotEmpty
                  ? Image.network(imagen, width: 44, height: 64, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _portadaPlaceholder())
                  : _portadaPlaceholder(),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (esLibroDelMes)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B1E2A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('Libro del mes',
                          style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  if (!activo)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Oculto',
                          style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.w700)),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(titulo, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                Text(autor, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                if (nota.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(nota, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
                ],
              ]),
            ),

            // Acciones rápidas
            Column(children: [
              IconButton(
                icon: Icon(
                  esLibroDelMes ? Icons.star_rounded : Icons.star_border_rounded,
                  color: esLibroDelMes ? const Color(0xFF6B1E2A) : Colors.grey[400],
                  size: 20,
                ),
                tooltip: esLibroDelMes ? 'Quitar "Libro del mes"' : 'Marcar como "Libro del mes"',
                onPressed: () => _toggleLibroDelMes(esLibroDelMes),
              ),
              IconButton(
                icon: Icon(
                  activo ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                  color: activo ? const Color(0xFF10B981) : Colors.grey[400],
                  size: 20,
                ),
                tooltip: activo ? 'Ocultar en la web' : 'Mostrar en la web',
                onPressed: () => doc.reference.update({'activo': !activo}),
              ),
              const Icon(Icons.drag_handle_rounded, color: Color(0xFFCBD5E1), size: 20),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _toggleLibroDelMes(bool actual) async {
    final batch = FirebaseFirestore.instance.batch();
    final todos = await col.where('es_libro_del_mes', isEqualTo: true).get();
    for (final d in todos.docs) {
      batch.update(d.reference, {'es_libro_del_mes': false});
    }
    if (!actual) batch.update(doc.reference, {'es_libro_del_mes': true});
    await batch.commit();
  }

  Widget _portadaPlaceholder() {
    return Container(
      width: 44, height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF6B1E2A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.menu_book_rounded, size: 20, color: Color(0xFF6B1E2A)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SELECTOR DESDE CATÁLOGO — bottom sheet para elegir libros del catálogo
// ─────────────────────────────────────────────────────────────────────────────

class _SelectorDesdeCatalogo extends StatefulWidget {
  final CollectionReference<Map<String, dynamic>> selCol;
  final CollectionReference<Map<String, dynamic>> catCol;

  const _SelectorDesdeCatalogo({required this.selCol, required this.catCol});

  @override
  State<_SelectorDesdeCatalogo> createState() => _SelectorDesdeCatalogoState();
}

class _SelectorDesdeCatalogoState extends State<_SelectorDesdeCatalogo> {
  final _busqueda = TextEditingController();
  Set<String> _yaEnSeleccion = {};
  bool _cargando = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() => _query = _busqueda.text.toLowerCase()));
    _cargarYaSeleccionados();
  }

  Future<void> _cargarYaSeleccionados() async {
    final snap = await widget.selCol.get();
    if (!mounted) return;
    setState(() {
      _yaEnSeleccion = snap.docs
          .map((d) => d.data()['catalogo_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    });
  }

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _agregarLibro(Map<String, dynamic> item) async {
    if (_cargando) return;
    final catalogoId = item['id'] as String? ?? '';
    if (catalogoId.isEmpty || _yaEnSeleccion.contains(catalogoId)) return;

    setState(() => _cargando = true);
    try {
      final count = (await widget.selCol.count().get()).count ?? 0;
      // slug: si el item lo tiene explícito, usar ese; si no, el ID del doc
      final slug = (item['slug'] as String?)?.isNotEmpty == true
          ? item['slug'] as String
          : catalogoId;
      await widget.selCol.add({
        'catalogo_id':     catalogoId,
        'slug':            slug,
        'titulo':          item['nombre'] ?? item['titulo'] ?? '',
        'autor':           item['campo_autor'] ?? item['autor'] ?? '',
        'imagen':          item['imagen_url'] ?? item['imagen'] ?? '',
        'descripcion':     item['descripcion'] ?? item['sinopsis'] ?? '',
        'genero':          item['tag'] ?? item['genero'] ?? item['categoria'] ?? '',
        'precio':          item['precio'] ?? '',
        'stripe_link':     item['stripe_link'] ?? '',
        'nota_editorial':  '',
        'activo':          true,
        'es_libro_del_mes': false,
        'orden':           count,
        'fecha_creacion':  FieldValue.serverTimestamp(),
      });
      setState(() => _yaEnSeleccion.add(catalogoId));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Container(
            width: 40, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 14),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          // Título
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              const Icon(Icons.menu_book_rounded, color: Color(0xFF6B1E2A), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Selecciona un libro del catálogo',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _busqueda,
              decoration: InputDecoration(
                hintText: 'Buscar por título o autor…',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF6B1E2A), width: 1.5),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          // Lista de catálogo
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: widget.catCol.orderBy('orden').snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final todos = snap.data?.docs ?? [];
                final filtrados = _query.isEmpty
                    ? todos
                    : todos.where((d) {
                        final nombre = (d.data()['nombre'] ?? '').toString().toLowerCase();
                        final autor  = (d.data()['campo_autor'] ?? '').toString().toLowerCase();
                        return nombre.contains(_query) || autor.contains(_query);
                      }).toList();

                if (filtrados.isEmpty) {
                  return Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        _query.isEmpty ? 'El catálogo está vacío' : 'Sin resultados para "$_query"',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ]),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final doc  = filtrados[i];
                    final data = doc.data();
                    final id   = doc.id;
                    final yaEsta = _yaEnSeleccion.contains(id);

                    final titulo = data['nombre'] ?? data['titulo'] ?? 'Sin título';
                    final autor  = data['campo_autor'] ?? data['autor'] ?? '';
                    final imagen = data['imagen_url'] ?? data['imagen'] ?? '';
                    final tieneStripe = (data['stripe_link'] as String?)?.isNotEmpty == true;

                    return Container(
                      decoration: BoxDecoration(
                        color: yaEsta ? const Color(0xFFF8F9FB) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: yaEsta
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: imagen.isNotEmpty
                              ? Image.network(imagen, width: 36, height: 52, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _imgPh())
                              : _imgPh(),
                        ),
                        title: Text(titulo,
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: yaEsta ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                            )),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (autor.isNotEmpty)
                            Text(autor, style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                          if (!tieneStripe)
                            const Text('⚠️ Sin enlace Stripe',
                                style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B))),
                        ]),
                        trailing: yaEsta
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22)
                            : FilledButton(
                                onPressed: _cargando ? null : () => _agregarLibro({'id': id, ...data}),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF6B1E2A),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                child: const Text('Añadir'),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  Widget _imgPh() => Container(
    width: 36, height: 52,
    decoration: BoxDecoration(
      color: const Color(0xFF6B1E2A).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF6B1E2A)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET EDITAR NOTA — solo edita nota_editorial y flags, no los datos del libro
// ─────────────────────────────────────────────────────────────────────────────

class _SheetEditarNota extends StatefulWidget {
  final CollectionReference<Map<String, dynamic>> col;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _SheetEditarNota({required this.col, required this.doc});

  @override
  State<_SheetEditarNota> createState() => _SheetEditarNotaState();
}

class _SheetEditarNotaState extends State<_SheetEditarNota> {
  final _nota = TextEditingController();
  bool _activo        = true;
  bool _esLibroDelMes = false;
  bool _guardando     = false;

  @override
  void initState() {
    super.initState();
    final d = widget.doc.data();
    _nota.text     = d['nota_editorial'] ?? '';
    _activo        = d['activo']          ?? true;
    _esLibroDelMes = d['es_libro_del_mes'] ?? false;
  }

  @override
  void dispose() {
    _nota.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await widget.doc.reference.update({
        'nota_editorial':  _nota.text.trim(),
        'activo':          _activo,
        'es_libro_del_mes': _esLibroDelMes,
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _quitar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quitar de la Selección'),
        content: Text(
          '¿Quitar «${widget.doc.data()['titulo'] ?? 'este libro'}» de La Selección Nazarí?\n\n'
          'El libro seguirá en el catálogo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await widget.doc.reference.delete();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d      = widget.doc.data();
    final titulo = d['titulo'] as String? ?? 'Sin título';
    final autor  = d['autor'] as String? ?? '';
    final imagen = d['imagen'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.70,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          expand: false,
          builder: (_, ctrl) => ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Center(child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              )),

              // Header con info del libro (read-only)
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: imagen.isNotEmpty
                      ? Image.network(imagen, width: 52, height: 76, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _portadaPh())
                      : _portadaPh(),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A))),
                  if (autor.isNotEmpty)
                    Text(autor, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  const Text('Datos del catálogo · solo lectura',
                      style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
                ])),
                IconButton(
                  onPressed: _quitar,
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  tooltip: 'Quitar de la selección',
                ),
              ]),

              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 14),

              // Nota editorial
              const Text('Nota editorial',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
              const SizedBox(height: 5),
              TextField(
                controller: _nota,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Por qué Nazarí recomienda este libro, qué lo hace especial…',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF6B1E2A), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),

              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: SwitchListTile(
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                  title: const Text('Visible en la web', style: TextStyle(fontSize: 13)),
                  activeColor: const Color(0xFF10B981),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
                Expanded(child: SwitchListTile(
                  value: _esLibroDelMes,
                  onChanged: (v) => setState(() => _esLibroDelMes = v),
                  title: const Text('Libro del mes ★', style: TextStyle(fontSize: 13)),
                  activeColor: const Color(0xFF6B1E2A),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
              ]),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6B1E2A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _guardando
                      ? const SizedBox(height: 18, width: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar cambios',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _portadaPh() => Container(
    width: 52, height: 76,
    decoration: BoxDecoration(
      color: const Color(0xFF6B1E2A).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: const Icon(Icons.menu_book_rounded, size: 24, color: Color(0xFF6B1E2A)),
  );
}

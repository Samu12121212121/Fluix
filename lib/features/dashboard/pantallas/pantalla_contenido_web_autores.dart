part of 'pantalla_contenido_web.dart';

// ── Tab Autores Nazarí — CRUD completo ───────────────────────────────────────

class _AutoresNazariTab extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color color;
  const _AutoresNazariTab(
      {required this.empresaId, required this.svc, required this.color});
  @override
  State<_AutoresNazariTab> createState() => _AutoresNazariTabState();
}

class _AutoresNazariTabState extends State<_AutoresNazariTab>
    with AutomaticKeepAliveClientMixin {
  String  _busqueda    = '';
  String? _filtroGenero;
  String? _filtroRol;
  final   _ctrl        = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  // ── Abrir dialog de edición / creación ───────────────────────────────────
  Future<void> _abrirDialog([Map<String, dynamic>? autor]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _AutorDialog(autor: autor, color: widget.color),
    );
    if (result == null || !mounted) return;
    try {
      await widget.svc.guardarAutor(widget.empresaId, autor?['id'] as String?, result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── Eliminar autor ────────────────────────────────────────────────────────
  Future<void> _eliminar(Map<String, dynamic> autor) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar autor'),
        content: Text('¿Eliminar a "${autor['nombre']}"? Esta acción es irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.svc.eliminarAutor(widget.empresaId, autor['id'] as String);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── Toggle activo ──────────────────────────────────────────────────────────
  Future<void> _toggleActivo(Map<String, dynamic> autor) async {
    final nuevo = !(autor['activo'] as bool? ?? true);
    try {
      await widget.svc.guardarAutor(
          widget.empresaId, autor['id'] as String, {'activo': nuevo});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = widget.color;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.svc.obtenerAutores(widget.empresaId),
      builder: (context, snap) {
        final todos = snap.data ?? [];

        // Ordenar por prioridad ASC (fallback: orden editorial), luego nombre ASC
        int _prio(Map<String, dynamic> a) {
          final p = (a['prioridad'] as num? ?? 0).toInt();
          if (p != 0) return p;
          return (a['orden'] as num? ?? 9999).toInt();
        }
        final todosOrdenados = List<Map<String, dynamic>>.from(todos)
          ..sort((a, b) {
            final pa = _prio(a), pb = _prio(b);
            if (pa != pb) return pa.compareTo(pb);
            return (a['nombre'] as String? ?? '')
                .compareTo(b['nombre'] as String? ?? '');
          });

        // Dividir genero por "/" — dedup accent-insensitive
        final _genSeen = <String>{};
        final generos = todos.expand<String>((a) {
          final g = a['genero'] as String? ?? '';
          if (g.isEmpty) return <String>[];
          return g.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty);
        }).where((g) => _genSeen.add(_normCat(g))).toList()..sort();

        final filtrados = todosOrdenados.where((a) {
          if (_filtroRol != null && (a['rol'] as String? ?? 'autor') != _filtroRol) return false;
          if (_filtroGenero != null) {
            final cats =
                (a['genero'] as String? ?? '').split('/').map((s) => s.trim()).toList();
            if (!cats.any((c) => _normCat(c) == _normCat(_filtroGenero!))) return false;
          }
          if (_busqueda.isNotEmpty) {
            final q = _busqueda.toLowerCase();
            return (a['nombre'] ?? '').toLowerCase().contains(q) ||
                (a['descripcion'] ?? '').toLowerCase().contains(q) ||
                (a['bio'] ?? '').toLowerCase().contains(q);
          }
          return true;
        }).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _abrirDialog(),
            backgroundColor: c,
            icon: const Icon(Icons.person_add_rounded, color: Colors.white),
            label: const Text('Añadir autor',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          body: Column(children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                LayoutBuilder(builder: (_, bc) {
                  final isNarrow = bc.maxWidth < 560;

                  // ── Fila título + acciones ────────────────────────────
                  final titleRow = Row(children: [
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Autores', style: TextStyle(fontSize: 20,
                          fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
                      Text(snap.connectionState == ConnectionState.waiting
                          ? 'Cargando…'
                          : '${todos.length} autores · ${filtrados.length} visibles',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ])),
                    if (isNarrow)
                      // Móvil: acciones secundarias en popup
                      PopupMenuButton<String>(
                        tooltip: 'Más opciones',
                        icon: Icon(Icons.more_vert_rounded,
                            color: c.withValues(alpha: 0.7)),
                        onSelected: (v) async {
                          if (v == 'sync') {
                            await widget.svc.sincronizarGenerosAutores(widget.empresaId);
                          } else if (v == 'dedup') {
                            await widget.svc.dedupAutores(widget.empresaId);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'sync', child: Row(children: [
                            Icon(Icons.sync_rounded, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 10),
                            Text('Sync géneros'),
                          ])),
                          PopupMenuItem(value: 'dedup', child: Row(children: [
                            Icon(Icons.auto_fix_high_rounded, size: 16, color: Color(0xFFD97706)),
                            SizedBox(width: 10),
                            Text('Limpiar duplicados'),
                          ])),
                        ],
                      )
                    else ...[
                      _BtnSyncGeneros(empresaId: widget.empresaId, svc: widget.svc),
                      _BtnDedupAutores(empresaId: widget.empresaId, svc: widget.svc,
                          total: todos.length),
                      _BtnImportarAutoresNazari(empresaId: widget.empresaId, svc: widget.svc),
                    ],
                  ]);

                  // ── Campo búsqueda ────────────────────────────────────
                  final searchField = TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar autor…',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 17, color: Color(0xFF94A3B8)),
                      suffixIcon: _busqueda.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 15),
                              onPressed: () { _ctrl.clear(); setState(() => _busqueda = ''); })
                          : null,
                      filled: true, fillColor: const Color(0xFFF8F9FB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _busqueda = v),
                  );

                  // ── Dropdown rol ──────────────────────────────────────
                  final rolDropdown = Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _filtroRol,
                        hint: const Text('Rol',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 16, color: Color(0xFF64748B)),
                        items: const [
                          DropdownMenuItem(value: null,       child: Text('Todos',         style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'autor',    child: Text('Autores',        style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'autora',   child: Text('Autoras',        style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'ilustrador',   child: Text('Ilustradores',   style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'ilustradora',  child: Text('Ilustradoras',   style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'traductor',    child: Text('Traductores',    style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'traductora',   child: Text('Traductoras',    style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (v) => setState(() => _filtroRol = v),
                      ),
                    ),
                  );

                  // ── Dropdown género ───────────────────────────────────
                  final generoDropdown = generos.isNotEmpty
                      ? Container(
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _filtroGenero,
                              hint: const Text('Género',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 16, color: Color(0xFF64748B)),
                              items: [
                                const DropdownMenuItem(value: null,
                                    child: Text('Todos', style: TextStyle(fontSize: 12))),
                                ...generos.map((g) => DropdownMenuItem(
                                    value: g, child: Text(g, style: const TextStyle(fontSize: 12)))),
                              ],
                              onChanged: (v) => setState(() => _filtroGenero = v),
                            ),
                          ),
                        )
                      : null;

                  if (isNarrow) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      titleRow,
                      const SizedBox(height: 12),
                      searchField,
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: rolDropdown),
                        if (generoDropdown != null) ...[
                          const SizedBox(width: 8),
                          Expanded(child: generoDropdown),
                        ],
                      ]),
                    ]);
                  }

                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    titleRow,
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 8),
                      rolDropdown,
                      if (generoDropdown != null) ...[
                        const SizedBox(width: 8),
                        generoDropdown,
                      ],
                    ]),
                  ]);
                }),
              ]),
            ),
            const Divider(height: 1),
            // ── Lista ────────────────────────────────────────────────────
            Expanded(
              child: snap.connectionState == ConnectionState.waiting &&
                      todos.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : filtrados.isEmpty
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(Icons.person_rounded,
                              size: 48, color: c.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text('Sin autores',
                              style: TextStyle(fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155))),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _abrirDialog(),
                            icon: const Icon(Icons.person_add_rounded),
                            label: const Text('Añadir autor'),
                            style: FilledButton.styleFrom(
                                backgroundColor: c),
                          ),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                          itemCount: filtrados.length,
                          itemBuilder: (_, i) => _AutorCard(
                            autor: filtrados[i],
                            color: c,
                            empresaId: widget.empresaId,
                            onEditar: () => _abrirDialog(filtrados[i]),
                            onEliminar: () => _eliminar(filtrados[i]),
                            onToggleActivo: () => _toggleActivo(filtrados[i]),
                          ),
                        ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Tarjeta de autor ──────────────────────────────────────────────────────────

class _AutorCard extends StatelessWidget {
  final Map<String, dynamic> autor;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onToggleActivo;
  final String empresaId;

  const _AutorCard({
    required this.autor,
    required this.color,
    required this.onEditar,
    required this.onEliminar,
    required this.onToggleActivo,
    required this.empresaId,
  });

  Future<void> _cambiarRol(BuildContext context, String rolActual) async {
    const roles = {
      'autor': 'Autor', 'autora': 'Autora',
      'ilustrador': 'Ilustrador', 'ilustradora': 'Ilustradora',
      'traductor': 'Traductor', 'traductora': 'Traductora',
    };
    final id = autor['id'] as String?;
    if (id == null) return;
    final nuevoRol = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(0, 0, 0, 0),
      items: roles.entries.map((e) => PopupMenuItem(
        value: e.key,
        child: Row(children: [
          if (e.key == rolActual)
            const Icon(Icons.check_rounded, size: 14, color: Color(0xFF6B1E2A))
          else
            const SizedBox(width: 14),
          const SizedBox(width: 8),
          Text(e.value, style: TextStyle(
            fontSize: 13,
            fontWeight: e.key == rolActual ? FontWeight.w700 : FontWeight.normal,
          )),
        ]),
      )).toList(),
    );
    if (nuevoRol != null && nuevoRol != rolActual) {
      await FirebaseFirestore.instance
          .collection('empresas').doc(empresaId)
          .collection('autores').doc(id)
          .update({'rol': nuevoRol});
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = autor['nombre'] as String? ?? '';
    final genero = autor['genero'] as String? ?? '';
    final lugar  = autor['lugar']  as String? ?? '';
    final desc   = (autor['descripcion'] as String? ?? '').isNotEmpty
        ? autor['descripcion'] as String
        : (autor['bio'] as String? ?? '');
    final foto   = autor['foto_url'] as String?
        ?? autor['foto'] as String? ?? '';
    final activo = autor['activo'] as bool? ?? true;
    final rol    = autor['rol'] as String? ?? 'autor';
    const _rolLabels = {
      'autor': 'Autor', 'autora': 'Autora',
      'ilustrador': 'Ilustrador', 'ilustradora': 'Ilustradora',
      'traductor': 'Traductor', 'traductora': 'Traductora',
      'editor': 'Editor', 'editora': 'Editora',
    };
    final rolLabel = _rolLabels[rol] ?? rol;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: activo ? Colors.white : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: activo
                ? const Color(0xFFE8EDF2)
                : const Color(0xFFCBD5E1)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          // ── Avatar ──────────────────────────────────────────────────
          Opacity(
            opacity: activo ? 1.0 : 0.45,
            child: foto.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: foto,
                      width: 44, height: 56, fit: BoxFit.cover,
                      placeholder: (_, __) => _avatarBox(nombre),
                      errorWidget: (_, __, ___) => _avatarBox(nombre),
                    ),
                  )
                : _avatarBox(nombre),
          ),
          const SizedBox(width: 12),
          // ── Datos ────────────────────────────────────────────────────
          Expanded(
            child: Opacity(
              opacity: activo ? 1.0 : 0.55,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(nombre,
                      style: const TextStyle(fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis)),
                  if (!activo)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('Oculto',
                          style: TextStyle(fontSize: 9,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _cambiarRol(context, rol),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: (rol.startsWith('ilustrad')
                              ? Colors.purple
                              : rol.startsWith('traduc')
                                  ? Colors.orange
                                  : rol.startsWith('editor')
                                      ? Colors.teal
                                      : color)
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (rol.startsWith('ilustrad')
                                ? Colors.purple
                                : rol.startsWith('traduc')
                                    ? Colors.orange
                                    : rol.startsWith('editor')
                                        ? Colors.teal
                                        : color)
                                .withValues(alpha: 0.25),
                          )),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(rolLabel,
                            style: TextStyle(
                                fontSize: 9.5,
                                color: rol.startsWith('ilustrad')
                                    ? Colors.purple
                                    : rol.startsWith('traduc')
                                        ? Colors.orange
                                        : rol.startsWith('editor')
                                            ? Colors.teal
                                            : color,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 3),
                        Icon(Icons.arrow_drop_down_rounded, size: 12,
                            color: rol.startsWith('ilustrad')
                                ? Colors.purple.withValues(alpha: 0.6)
                                : rol.startsWith('traduc')
                                    ? Colors.orange.withValues(alpha: 0.6)
                                    : color.withValues(alpha: 0.6)),
                      ]),
                    ),
                  ),
                  if (genero.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(genero,
                          style: const TextStyle(fontSize: 9.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ]),
                if (lugar.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(lugar, style: const TextStyle(
                      fontSize: 11, color: Color(0xFF94A3B8))),
                ],
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  // Usar primera línea no vacía para el preview de la tarjeta
                  Text(
                    desc.split('\n').where((l) => l.trim().isNotEmpty).take(2).join(' '),
                    style: const TextStyle(
                        fontSize: 11.5, color: Color(0xFF64748B), height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ]),
            ),
          ),
          // ── Acciones ─────────────────────────────────────────────────
          Column(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_rounded, size: 18),
              color: const Color(0xFF475569),
              onPressed: onEditar,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: activo ? 'Desactivar (ocultar en web)' : 'Activar',
              icon: Icon(
                  activo
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 18),
              color: activo
                  ? const Color(0xFF94A3B8)
                  : color,
              onPressed: onToggleActivo,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: Colors.red.shade400,
              onPressed: onEliminar,
              visualDensity: VisualDensity.compact,
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _avatarBox(String nombre) {
    final letra = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
    return Container(
      width: 44, height: 56,
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Center(child: Text(letra,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
              color: color))),
    );
  }
}

// ── Dialog de edición / creación de autor ─────────────────────────────────────

class _AutorDialog extends StatefulWidget {
  final Map<String, dynamic>? autor;
  final Color color;
  const _AutorDialog({this.autor, required this.color});
  @override
  State<_AutorDialog> createState() => _AutorDialogState();
}

class _AutorDialogState extends State<_AutorDialog> {
  final _nombreCtrl    = TextEditingController();
  Set<String> _generosAutor = {};
  final _lugarCtrl     = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _fotoCtrl      = TextEditingController();
  final _prioridadCtrl = TextEditingController();
  final _picker        = ImagePicker();

  bool   _subiendoFoto = false;
  String _fotoPreview  = '';
  String _rol          = 'autor';

  static const _kEmpresaId = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

  @override
  void initState() {
    super.initState();
    final a = widget.autor;
    if (a != null) {
      _nombreCtrl.text    = a['nombre'] as String? ?? '';
      _generosAutor = (a['genero'] as String? ?? '').split('/')
          .map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
      _lugarCtrl.text     = a['lugar']  as String? ?? '';
      _descCtrl.text      = (a['descripcion'] as String? ?? '').isNotEmpty
          ? a['descripcion'] as String
          : (a['bio'] as String? ?? '');
      _fotoCtrl.text      = a['foto_url'] as String?
          ?? a['foto'] as String? ?? '';
      _fotoPreview        = _fotoCtrl.text;
      _rol                = a['rol'] as String? ?? 'autor';
      _prioridadCtrl.text = (a['prioridad'] as num? ?? 0).toString();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _lugarCtrl.dispose();  _descCtrl.dispose(); _fotoCtrl.dispose();
    _prioridadCtrl.dispose();
    super.dispose();
  }

  Future<void> _subirFoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600, maxHeight: 800, imageQuality: 88,
    );
    if (file == null || !mounted) return;

    setState(() => _subiendoFoto = true);
    try {
      final bytes = await file.readAsBytes();
      final ext   = file.name.split('.').last.toLowerCase();
      final nombre = _nombreCtrl.text.trim().replaceAll(' ', '_').toLowerCase();
      final ts    = DateTime.now().millisecondsSinceEpoch;
      final path  = 'empresas/$_kEmpresaId/autores/${nombre}_$ts.$ext';

      final ref = FirebaseStorage.instance.ref(path);
      await ref.putData(bytes, SettableMetadata(
          contentType: ext == 'png' ? 'image/png' : 'image/jpeg'));
      final url = await ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _fotoCtrl.text = url;
          _fotoPreview   = url;
          _subiendoFoto  = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _subiendoFoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error subiendo foto: $e'),
                backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.autor == null;
    return AlertDialog(
      title: Text(esNuevo ? 'Nuevo autor' : 'Editar autor',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Foto ──────────────────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              // Preview circular
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.color.withValues(alpha: 0.3)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _subiendoFoto
                    ? Center(child: SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: widget.color)))
                    : _fotoPreview.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _fotoPreview,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _iconPlaceholder(),
                          )
                        : _iconPlaceholder(),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(children: [
                // URL manual
                TextField(
                  controller: _fotoCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL de foto',
                    prefixIcon: Icon(Icons.link_rounded, size: 17),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _fotoPreview = v),
                ),
                const SizedBox(height: 6),
                // Botón subir archivo
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _subiendoFoto ? null : _subirFoto,
                    icon: _subiendoFoto
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload_rounded, size: 16),
                    label: Text(_subiendoFoto
                        ? 'Subiendo…'
                        : 'Subir desde archivo'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.color,
                      side: BorderSide(
                          color: widget.color.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ])),
            ]),
            const SizedBox(height: 12),
            // ── Datos ─────────────────────────────────────────────────
            _field(_nombreCtrl, 'Nombre *', Icons.person_rounded),
            const SizedBox(height: 10),
            // Rol — mismos 6 valores que los filtros de la web
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6, runSpacing: 4,
                children: [
                  for (final entry in const {
                    'autor':       'Autor',
                    'autora':      'Autora',
                    'ilustrador':  'Ilustrador',
                    'ilustradora': 'Ilustradora',
                    'traductor':   'Traductor',
                    'traductora':  'Traductora',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value, style: const TextStyle(fontSize: 11)),
                      selected: _rol == entry.key,
                      onSelected: (_) => setState(() => _rol = entry.key),
                      selectedColor: widget.color.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: _rol == entry.key ? widget.color : const Color(0xFF475569),
                        fontWeight: _rol == entry.key ? FontWeight.w700 : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: _rol == entry.key
                            ? widget.color.withValues(alpha: 0.5)
                            : const Color(0xFFE2E8F0),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _CategoriasSelector(
              seleccionadas: _generosAutor,
              onToggle: (cat) => setState(() {
                _generosAutor.contains(cat)
                    ? _generosAutor.remove(cat)
                    : _generosAutor.add(cat);
              }),
              color: widget.color,
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _field(
                  _lugarCtrl, 'Lugar', Icons.place_rounded)),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                child: _field(_prioridadCtrl, 'Prioridad', Icons.sort_rounded),
              ),
            ]),
            const SizedBox(height: 10),
            _field(_descCtrl, 'Biografía / descripción',
                Icons.article_rounded, maxLines: 6, multiline: true),
            const SizedBox(height: 10),
            const SizedBox(height: 4),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _subiendoFoto
              ? null
              : () {
                  if (_nombreCtrl.text.trim().isEmpty) return;
                  // Preservar saltos de línea internos — solo quitar espacios extremos
                  final bio = _descCtrl.text.trimRight();
                  final fotoUrl = _fotoCtrl.text.trim();
                  Navigator.pop(context, {
                    'nombre':      _nombreCtrl.text.trim(),
                    'rol':         _rol,
                    'genero':      _generosAutor.isEmpty ? ''
                                   : (_generosAutor.toList()..sort()).join(' / '),
                    'lugar':       _lugarCtrl.text.trim(),
                    'descripcion': bio,
                    'bio':         bio,
                    'foto_url':    fotoUrl,
                    'foto':        fotoUrl,  // campo que lee la web
                    'prioridad':   int.tryParse(_prioridadCtrl.text.trim()) ?? 0,
                    'activo':      widget.autor?['activo'] ?? true,
                    'eliminado':   false,
                  });
                },
          style: FilledButton.styleFrom(backgroundColor: widget.color),
          child: Text(esNuevo ? 'Crear' : 'Guardar'),
        ),
      ],
    );
  }

  Widget _iconPlaceholder() => Icon(Icons.person_rounded,
      size: 32, color: widget.color.withValues(alpha: 0.4));

  Widget _field(TextEditingController c, String label, IconData icon,
      {int maxLines = 1, bool multiline = false}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      minLines: 1,
      // En campo multilinea: Enter inserta salto de línea en lugar de enviar el formulario
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      textInputAction: multiline ? TextInputAction.newline : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 17),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}

// ── Botón deduplicación de autores ────────────────────────────────────────────

class _BtnDedupAutores extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final int total;

  const _BtnDedupAutores({
    required this.empresaId,
    required this.svc,
    required this.total,
  });

  @override
  State<_BtnDedupAutores> createState() => _BtnDedupAutoresState();
}

class _BtnDedupAutoresState extends State<_BtnDedupAutores> {
  bool _corriendo = false;

  Future<void> _dedup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar duplicados'),
        content: Text(
          'Hay ${widget.total} autores en Firestore.\n\n'
          'Esta operación buscará nombres repetidos y conservará '
          'el registro con más información (bio, foto, género).\n\n'
          '¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _corriendo = true);
    try {
      final deleted = await widget.svc.dedupAutores(widget.empresaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(deleted == 0
              ? '✅ Sin duplicados — los autores estaban limpios'
              : '✅ $deleted registros duplicados eliminados'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _corriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _corriendo ? null : _dedup,
      icon: _corriendo
          ? const SizedBox(
              width: 11, height: 11,
              child: CircularProgressIndicator(strokeWidth: 1.5))
          : const Icon(Icons.auto_fix_high_rounded,
              size: 13, color: Color(0xFFD97706)),
      label: Text(_corriendo ? '…' : 'Limpiar duplicados',
          style: const TextStyle(fontSize: 11, color: Color(0xFFD97706))),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
      ),
    );
  }
}

// ── Botón sincronizar géneros desde catálogo ──────────────────────────────────

class _BtnSyncGeneros extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  const _BtnSyncGeneros({required this.empresaId, required this.svc});
  @override
  State<_BtnSyncGeneros> createState() => _BtnSyncGenerosState();
}

class _BtnSyncGenerosState extends State<_BtnSyncGeneros> {
  bool _corriendo = false;

  Future<void> _sincronizar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sincronizar géneros'),
        content: const Text(
          'Lee las categorías de los libros del catálogo y rellena '
          'el campo Género de cada autor con todas las categorías que tienen sus libros.\n\n'
          '¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sincronizar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _corriendo = true);
    try {
      final n = await widget.svc.sincronizarGenerosAutores(widget.empresaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(n == 0
              ? 'Sin libros vinculados a autores — no hay géneros que sincronizar'
              : '✅ Géneros actualizados en $n autores'),
          backgroundColor: n == 0 ? null : Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _corriendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _corriendo ? null : _sincronizar,
      icon: _corriendo
          ? const SizedBox(
              width: 11, height: 11,
              child: CircularProgressIndicator(strokeWidth: 1.5))
          : const Icon(Icons.sync_rounded,
              size: 13, color: Color(0xFF10B981)),
      label: Text(_corriendo ? '…' : 'Sync géneros',
          style: const TextStyle(fontSize: 11, color: Color(0xFF10B981))),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
      ),
    );
  }
}

// ── Botón importación Autores Nazarí ─────────────────────────────────────────

class _BtnImportarAutoresNazari extends StatelessWidget {
  final String empresaId;
  final ContenidoWebService svc;

  const _BtnImportarAutoresNazari({required this.empresaId, required this.svc});

  void _mostrarInstrucciones(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar autores'),
        content: const Text(
          'Los autores se importan desde los ficheros de texto extraídos de la web.\n\n'
          'Ejecuta desde el terminal:\n\n'
          'cd functions\n'
          'node importar_autores_nazari.js\n\n'
          'Para ver el resultado sin subir nada:\n'
          'node importar_autores_nazari.js --dry-run\n\n'
          'Los autores aparecerán automáticamente aquí cuando estén en Firestore.',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _mostrarInstrucciones(context),
      icon: const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFF0EA5E9)),
      label: const Text('Importar autores',
          style: TextStyle(fontSize: 11, color: Color(0xFF0EA5E9))),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
      ),
    );
  }
}











import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// GESTIÓN DE CATEGORÍAS Y COLECCIONES DEL CATÁLOGO
// Abre un sheet con dos pestañas desde tab_catalogo_web.dart
//
// Firestore:
//   empresas/{empresaId}/categorias_catalogo   → géneros/temáticas
//   empresas/{empresaId}/colecciones_catalogo  → series editoriales
// ═════════════════════════════════════════════════════════════════════════════

void mostrarGestionCategorias(BuildContext context, String empresaId, Color color) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => _ClasificacionSheet(
        empresaId: empresaId,
        color: color,
        scrollController: scrollCtrl,
      ),
    ),
  );
}

// ── Sheet con tabs ────────────────────────────────────────────────────────────
class _ClasificacionSheet extends StatefulWidget {
  final String empresaId;
  final Color color;
  final ScrollController scrollController;

  const _ClasificacionSheet({
    required this.empresaId,
    required this.color,
    required this.scrollController,
  });

  @override
  State<_ClasificacionSheet> createState() => _ClasificacionSheetState();
}

class _ClasificacionSheetState extends State<_ClasificacionSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  String get _colActiva =>
      _tabCtrl.index == 0 ? 'categorias_catalogo' : 'colecciones_catalogo';

  String get _nombreTab => _tabCtrl.index == 0 ? 'categoría' : 'colección';

  @override
  Widget build(BuildContext context) {
    final color = widget.color;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // ── Cabecera ──────────────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Row(children: [
              Icon(Icons.tune_rounded, color: color, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Categorías y colecciones',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
              ),
              TextButton.icon(
                onPressed: () => _abrirEditor(context, null),
                icon: Icon(Icons.add_rounded, size: 16, color: color),
                label: Text('Nueva $_nombreTab',
                    style: TextStyle(color: color, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 6),
            TabBar(
              controller: _tabCtrl,
              labelColor: color,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: color,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: const [
                Tab(text: 'Categorías'),
                Tab(text: 'Colecciones'),
              ],
            ),
          ]),
        ),
        const Divider(height: 1),
        // ── Info banner ───────────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 13, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _tabCtrl.index == 0
                      ? 'Las categorías activas aparecen en el editor de libros y como filtros en la web.'
                      : 'Las colecciones activas aparecen en el editor de libros y agrupan el catálogo en la web.',
                  style: TextStyle(fontSize: 11.5, color: color),
                ),
              ),
            ]),
          ),
        ),
        const Divider(height: 1),
        // ── Tabs body ─────────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _ListaClasificacion(
                empresaId: widget.empresaId,
                coleccion: 'categorias_catalogo',
                color: color,
                scrollController: widget.scrollController,
                onEditar: (doc) => _abrirEditor(context, doc),
              ),
              _ListaClasificacion(
                empresaId: widget.empresaId,
                coleccion: 'colecciones_catalogo',
                color: color,
                scrollController: widget.scrollController,
                onEditar: (doc) => _abrirEditor(context, doc),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Future<void> _abrirEditor(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>>? doc) async {
    final col = FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection(_colActiva);

    final data = doc?.data();
    final nombreCtrl =
        TextEditingController(text: data?['nombre'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: data?['descripcion'] as String? ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          bool guardando = false;

          Future<void> guardar() async {
            final nombre = nombreCtrl.text.trim();
            if (nombre.isEmpty) return;
            setModal(() => guardando = true);
            try {
              final slug = _toSlug(nombre);
              if (doc == null) {
                final count = (await col.count().get()).count ?? 0;
                await col.add({
                  'nombre': nombre,
                  'slug': slug,
                  'descripcion': descCtrl.text.trim(),
                  'orden': count,
                  'activo': true,
                  'fecha_creacion': FieldValue.serverTimestamp(),
                });
              } else {
                await doc.reference.update({
                  'nombre': nombre,
                  'slug': slug,
                  'descripcion': descCtrl.text.trim(),
                });
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            } catch (_) {
              setModal(() => guardando = false);
            }
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20, right: 20, top: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              Text(
                doc == null
                    ? 'Nueva $_nombreTab'
                    : 'Editar $_nombreTab',
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nombreCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Nombre *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                onSubmitted: (_) => guardar(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Descripción (opcional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: guardando ? null : guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: guardando
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          doc == null ? 'Crear' : 'Guardar cambios',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 6),
            ]),
          );
        },
      ),
    );

    nombreCtrl.dispose();
    descCtrl.dispose();
  }
}

// ── Lista CRUD (reutilizada por ambas pestañas) ───────────────────────────────
class _ListaClasificacion extends StatefulWidget {
  final String empresaId;
  final String coleccion;
  final Color color;
  final ScrollController scrollController;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>>?) onEditar;

  const _ListaClasificacion({
    required this.empresaId,
    required this.coleccion,
    required this.color,
    required this.scrollController,
    required this.onEditar,
  });

  @override
  State<_ListaClasificacion> createState() => _ListaClasificacionState();
}

class _ListaClasificacionState extends State<_ListaClasificacion> {
  bool _migrationAttempted = false;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection(widget.coleccion);

  // Extrae valores únicos de los libros existentes y los importa una sola vez.
  Future<void> _migrarDesdeLibros() async {
    if (_migrationAttempted) return;
    _migrationAttempted = true;

    // Doble-check: si ya existen docs, no hacer nada
    final check = await _col.limit(1).get();
    if (check.docs.isNotEmpty) return;

    final libros = await FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('catalogo_web')
        .get();

    final Set<String> valores = {};

    for (final doc in libros.docs) {
      final d = doc.data();
      if (widget.coleccion == 'categorias_catalogo') {
        // Preferir array categorias; fallback a string categoria (separado por /)
        final cats = d['categorias'];
        if (cats is List && cats.isNotEmpty) {
          for (final c in cats) {
            final s = c.toString().trim();
            if (s.isNotEmpty) valores.add(s);
          }
        } else {
          for (final s in (d['categoria'] as String? ?? '').split('/')) {
            final t = s.trim();
            if (t.isNotEmpty) valores.add(t);
          }
        }
        // También campo tag como categoría secundaria
        final tag = (d['tag'] as String? ?? '').trim();
        if (tag.isNotEmpty) valores.add(tag);
      } else {
        // colecciones_catalogo
        final col = ((d['coleccion'] ?? d['campo_coleccion'] ?? '') as String)
            .trim();
        if (col.isNotEmpty) valores.add(col);
      }
    }

    if (valores.isEmpty) return;

    final sorted = valores.toList()..sort();
    // Firestore batch limit = 500; en la práctica habrá <50 categorías
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < sorted.length; i++) {
      final nombre = sorted[i];
      batch.set(_col.doc(), {
        'nombre': nombre,
        'slug': _toSlug(nombre),
        'descripcion': '',
        'orden': i,
        'activo': true,
        'fecha_creacion': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _col.orderBy('orden').snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          // Intentar auto-poblar desde los libros (solo una vez)
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _migrarDesdeLibros());
          return _buildVacio(context);
        }

        return ReorderableListView.builder(
          scrollController: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          itemCount: docs.length,
          onReorder: (oldIdx, newIdx) => _reordenar(docs, oldIdx, newIdx),
          itemBuilder: (_, i) {
            final d = docs[i];
            return _TarjetaItem(
              key: ValueKey(d.id),
              doc: d,
              color: widget.color,
              onEditar: () => widget.onEditar(d),
              onEliminar: () => _confirmarEliminar(context, d),
              onToggleActivo: (v) => d.reference.update({'activo': v}),
            );
          },
        );
      },
    );
  }

  Future<void> _reordenar(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      int oldIdx, int newIdx) async {
    if (newIdx > oldIdx) newIdx--;
    final reordenados = [...docs];
    final item = reordenados.removeAt(oldIdx);
    reordenados.insert(newIdx, item);
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < reordenados.length; i++) {
      batch.update(reordenados[i].reference, {'orden': i});
    }
    await batch.commit();
  }

  Future<void> _confirmarEliminar(BuildContext context,
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final nombre = doc.data()['nombre'] as String? ?? '';
    final esColeccion = widget.coleccion == 'colecciones_catalogo';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar ${esColeccion ? 'colección' : 'categoría'}'),
        content: Text(
            '¿Eliminar "$nombre"?\n\nLos libros que ya la tienen asignada conservarán el valor en sus datos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (ok == true) await doc.reference.delete();
  }

  Widget _buildVacio(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.label_outline_rounded, size: 44, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              widget.coleccion == 'categorias_catalogo'
                  ? 'Sin categorías'
                  : 'Sin colecciones',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            const Text('Importando desde los libros…',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ]),
        ),
      );
}

// ── Tarjeta individual ────────────────────────────────────────────────────────
class _TarjetaItem extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Color color;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final ValueChanged<bool> onToggleActivo;

  const _TarjetaItem({
    super.key,
    required this.doc,
    required this.color,
    required this.onEditar,
    required this.onEliminar,
    required this.onToggleActivo,
  });

  @override
  Widget build(BuildContext context) {
    final d = doc.data();
    final nombre = d['nombre'] as String? ?? '';
    final desc = d['descripcion'] as String? ?? '';
    final activo = d['activo'] as bool? ?? true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 5,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: activo
                ? color.withValues(alpha: 0.1)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(Icons.label_rounded,
              color: activo ? color : Colors.grey[400], size: 18),
        ),
        title: Text(nombre,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: activo
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8))),
        subtitle: desc.isNotEmpty
            ? Text(desc,
                style: TextStyle(
                    fontSize: 11,
                    color: activo
                        ? const Color(0xFF64748B)
                        : const Color(0xFFCBD5E1)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)
            : null,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Switch.adaptive(
            value: activo,
            onChanged: onToggleActivo,
            activeThumbColor: color,
            activeTrackColor: color.withValues(alpha: 0.35),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                size: 17, color: Color(0xFF64748B)),
            onSelected: (v) {
              if (v == 'editar') onEditar();
              if (v == 'eliminar') onEliminar();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'editar',
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 15),
                    SizedBox(width: 9),
                    Text('Editar'),
                  ])),
              PopupMenuItem(
                  value: 'eliminar',
                  child: Row(children: [
                    Icon(Icons.delete_rounded,
                        size: 15, color: Color(0xFFEF4444)),
                    SizedBox(width: 9),
                    Text('Eliminar',
                        style: TextStyle(color: Color(0xFFEF4444))),
                  ])),
            ],
          ),
          const Icon(Icons.drag_handle_rounded,
              color: Color(0xFFCBD5E1), size: 18),
          const SizedBox(width: 4),
        ]),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
String _toSlug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[áàâäã]'), 'a')
    .replaceAll(RegExp(r'[éèêë]'), 'e')
    .replaceAll(RegExp(r'[íìîï]'), 'i')
    .replaceAll(RegExp(r'[óòôöõ]'), 'o')
    .replaceAll(RegExp(r'[úùûü]'), 'u')
    .replaceAll('ñ', 'n')
    .replaceAll(RegExp(r'[^a-z0-9]'), '-')
    .replaceAll(RegExp(r'-+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

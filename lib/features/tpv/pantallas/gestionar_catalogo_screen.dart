import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class GestionarCatalogoScreen extends StatefulWidget {
  final String empresaId;
  const GestionarCatalogoScreen({super.key, required this.empresaId});

  @override
  State<GestionarCatalogoScreen> createState() => _GestionarCatalogoScreenState();
}

class _GestionarCatalogoScreenState extends State<GestionarCatalogoScreen> {
  final _searchCtrl = TextEditingController();
  String _busqueda = '';
  String _categoriaFiltro = 'Todos';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _eliminar(String docId, String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "$nombre"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('catalogo')
        .doc(docId)
        .delete();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Producto "$nombre" eliminado'),
            backgroundColor: Colors.red[700]),
      );
    }
  }

  Future<void> _toggleActivo(String docId, bool actual) async {
    await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('catalogo')
        .doc(docId)
        .update({'activo': !actual});
  }

  void _abrirEditar(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (_) => _DialogoEditarProducto(
        empresaId: widget.empresaId,
        docId: doc.id,
        data: doc.data() as Map<String, dynamic>,
      ),
    );
  }

  void _abrirNuevo() {
    showDialog(
      context: context,
      builder: (_) => _DialogoEditarProducto(
        empresaId: widget.empresaId,
        docId: null,
        data: const {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.inventory_2, size: 20),
          SizedBox(width: 8),
          Text('Gestionar catálogo', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Nuevo producto',
            onPressed: _abrirNuevo,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Buscador ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _busqueda = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _busqueda = '');
                        })
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Lista de productos ────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('empresas')
                  .doc(widget.empresaId)
                  .collection('catalogo')
                  .orderBy('nombre')
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snap.data!.docs;

                // Obtener categorías únicas para el filtro
                final cats = {'Todos', ...docs
                    .map((d) => (d.data() as Map<String, dynamic>)['categoria'] as String? ?? '')
                    .where((c) => c.isNotEmpty)}.toList();

                // Aplicar filtros
                if (_busqueda.isNotEmpty) {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return (data['nombre'] as String? ?? '')
                        .toLowerCase()
                        .contains(_busqueda);
                  }).toList();
                }
                if (_categoriaFiltro != 'Todos') {
                  docs = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return (data['categoria'] as String? ?? '') == _categoriaFiltro;
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _busqueda.isNotEmpty
                              ? 'Sin resultados para "$_busqueda"'
                              : 'Sin productos todavía',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _abrirNuevo,
                          icon: const Icon(Icons.add),
                          label: const Text('Añadir producto'),
                          style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF7B1FA2)),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // ── Filtro categorías ───────────────────────────────────
                    if (cats.length > 2)
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: cats.map((cat) {
                            final sel = _categoriaFiltro == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: FilterChip(
                                label: Text(cat,
                                    style: const TextStyle(fontSize: 12)),
                                selected: sel,
                                onSelected: (_) => setState(
                                    () => _categoriaFiltro = cat),
                                selectedColor: const Color(0xFF7B1FA2)
                                    .withValues(alpha: 0.15),
                                checkmarkColor: const Color(0xFF7B1FA2),
                                side: BorderSide(
                                    color: sel
                                        ? const Color(0xFF7B1FA2)
                                        : Colors.grey[300]!),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 4),

                    // ── Counter ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(children: [
                        Text('${docs.length} producto${docs.length != 1 ? 's' : ''}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                      ]),
                    ),

                    // ── Lista ────────────────────────────────────────────────
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                        itemCount: docs.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final doc = docs[i];
                          final data = doc.data() as Map<String, dynamic>;
                          return _ProductoItem(
                            docId: doc.id,
                            data: data,
                            onEditar: () => _abrirEditar(doc),
                            onEliminar: () => _eliminar(
                                doc.id, data['nombre'] as String? ?? ''),
                            onToggleActivo: () => _toggleActivo(
                                doc.id, data['activo'] as bool? ?? true),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNuevo,
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo producto'),
      ),
    );
  }
}

// ── Tarjeta de producto ───────────────────────────────────────────────────────

class _ProductoItem extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onToggleActivo;

  const _ProductoItem({
    required this.docId,
    required this.data,
    required this.onEditar,
    required this.onEliminar,
    required this.onToggleActivo,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = data['nombre'] as String? ?? '—';
    final categoria = data['categoria'] as String? ?? '';
    final precio = (data['precio'] as num?)?.toDouble() ?? 0;
    final iva = (data['iva_porcentaje'] as num?)?.toDouble() ?? 10;
    final activo = data['activo'] as bool? ?? true;
    final imgUrl = data['thumbnail_url'] as String? ?? data['imagen_url'] as String?;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: activo ? Colors.grey[200]! : Colors.grey[300]!),
      ),
      color: activo ? Colors.white : Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Imagen
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imgUrl != null
                  ? Image.network(imgUrl,
                      width: 52, height: 52, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _inicial(nombre, activo))
                  : _inicial(nombre, activo),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: activo ? Colors.black87 : Colors.grey)),
                  if (categoria.isNotEmpty)
                    Text(categoria,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text('€${precio.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Color(0xFF1565C0))),
                    const SizedBox(width: 8),
                    Text('IVA ${iva.toStringAsFixed(0)}%',
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey[500])),
                  ]),
                ],
              ),
            ),
            // Acciones
            Row(mainAxisSize: MainAxisSize.min, children: [
              // Activar / desactivar
              Tooltip(
                message: activo ? 'Desactivar' : 'Activar',
                child: InkWell(
                  onTap: onToggleActivo,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      activo
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: activo ? Colors.green : Colors.grey,
                    ),
                  ),
                ),
              ),
              // Editar
              Tooltip(
                message: 'Editar',
                child: InkWell(
                  onTap: onEditar,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.edit_outlined,
                        size: 20, color: Color(0xFF7B1FA2)),
                  ),
                ),
              ),
              // Eliminar
              Tooltip(
                message: 'Eliminar',
                child: InkWell(
                  onTap: onEliminar,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.delete_outline,
                        size: 20, color: Colors.red),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _inicial(String nombre, bool activo) {
    return Container(
      width: 52,
      height: 52,
      color: activo
          ? const Color(0xFF7B1FA2).withValues(alpha: 0.12)
          : Colors.grey[200],
      child: Center(
        child: Text(
          nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: activo
                ? const Color(0xFF7B1FA2).withValues(alpha: 0.7)
                : Colors.grey,
          ),
        ),
      ),
    );
  }
}

// ── Diálogo editar / crear producto ──────────────────────────────────────────

class _DialogoEditarProducto extends StatefulWidget {
  final String empresaId;
  final String? docId; // null = nuevo producto
  final Map<String, dynamic> data;

  const _DialogoEditarProducto({
    required this.empresaId,
    required this.docId,
    required this.data,
  });

  @override
  State<_DialogoEditarProducto> createState() =>
      _DialogoEditarProductoState();
}

class _DialogoEditarProductoState extends State<_DialogoEditarProducto> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _precioCtrl;
  late final TextEditingController _categoriaCtrl;
  late final TextEditingController _imagenCtrl;
  late double _iva;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(
        text: widget.data['nombre'] as String? ?? '');
    _precioCtrl = TextEditingController(
        text: (widget.data['precio'] as num?)?.toStringAsFixed(2) ?? '');
    _categoriaCtrl = TextEditingController(
        text: widget.data['categoria'] as String? ?? '');
    _imagenCtrl = TextEditingController(
        text: widget.data['imagen_url'] as String? ?? '');
    _iva = (widget.data['iva_porcentaje'] as num?)?.toDouble() ?? 10;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _categoriaCtrl.dispose();
    _imagenCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.isEmpty) return;
    final precio = double.tryParse(
            _precioCtrl.text.trim().replaceAll(',', '.')) ??
        0.0;

    setState(() => _guardando = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('catalogo');

      final imgUrl =
          _imagenCtrl.text.trim().isEmpty ? null : _imagenCtrl.text.trim();

      final payload = {
        'nombre': nombre,
        'precio': precio,
        'categoria': _categoriaCtrl.text.trim(),
        'iva_porcentaje': _iva,
        'activo': true,
        if (imgUrl != null) 'imagen_url': imgUrl,
        if (imgUrl != null) 'thumbnail_url': imgUrl,
      };

      if (widget.docId == null) {
        payload['creado'] = FieldValue.serverTimestamp();
        await ref.add(payload);
      } else {
        await ref.doc(widget.docId).update(payload);
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.docId == null;
    return AlertDialog(
      title: Row(children: [
        Icon(esNuevo ? Icons.add_shopping_cart : Icons.edit_outlined,
            color: const Color(0xFF7B1FA2)),
        const SizedBox(width: 8),
        Text(esNuevo ? 'Nuevo producto' : 'Editar producto'),
      ]),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_nombreCtrl, 'Nombre *', Icons.label_outline,
                  autofocus: true),
              const SizedBox(height: 12),
              _field(_precioCtrl, 'Precio (€) *', Icons.euro_outlined,
                  tipo: const TextInputType.numberWithOptions(decimal: true)),
              const SizedBox(height: 12),
              _field(_categoriaCtrl, 'Categoría', Icons.category_outlined,
                  hint: 'Ej: Bebidas, Tapas…'),
              const SizedBox(height: 12),
              _field(_imagenCtrl, 'URL de imagen (opcional)',
                  Icons.image_outlined,
                  hint: 'https://…'),
              const SizedBox(height: 12),
              // IVA selector
              Row(children: [
                const Icon(Icons.percent, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('IVA:', style: TextStyle(fontSize: 13)),
                const Spacer(),
                ...[0, 4, 10, 21].map((v) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text('$v%',
                        style: const TextStyle(fontSize: 11)),
                    selected: _iva == v.toDouble(),
                    onSelected: (_) =>
                        setState(() => _iva = v.toDouble()),
                    selectedColor:
                        const Color(0xFF7B1FA2).withValues(alpha: 0.2),
                    visualDensity: VisualDensity.compact,
                  ),
                )),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7B1FA2)),
          child: _guardando
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Text(esNuevo ? 'Crear' : 'Guardar'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? hint,
    TextInputType tipo = TextInputType.text,
    bool autofocus = false,
  }) {
    return TextField(
      controller: ctrl,
      autofocus: autofocus,
      keyboardType: tipo,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

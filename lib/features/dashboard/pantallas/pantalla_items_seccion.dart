import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA ITEMS GENÉRICOS — Lo que ve el cliente
// ═════════════════════════════════════════════════════════════════════════════

class PantallaItemsSeccion extends StatefulWidget {
  final String empresaId;
  final SeccionWeb seccion;
  final ContenidoWebService svc;

  const PantallaItemsSeccion({
    super.key,
    required this.empresaId,
    required this.seccion,
    required this.svc,
  });

  @override
  State<PantallaItemsSeccion> createState() => _PantallaItemsSeccionState();
}

class _PantallaItemsSeccionState extends State<PantallaItemsSeccion> {
  late List<Map<String, dynamic>> _items;
  late TextEditingController _nombreCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _editandoNombre = false;
  bool _guardando = false;
  String? _categoriaActiva; // null = vista de categorías
  String _query = '';

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(
      widget.seccion.contenido.items.map((e) => Map<String, dynamic>.from(e)),
    );
    _nombreCtrl = TextEditingController(text: widget.seccion.nombre);
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nombreCtrl.dispose();
    super.dispose();
  }

  // ── Guardar todo ──────────────────────────────────────────────────────────

  Future<void> _guardarItems() async {
    setState(() => _guardando = true);
    try {
      await widget.svc.guardarItemsGenericos(
          widget.empresaId, widget.seccion.id, _items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('¡Guardado! Cambios visibles en la web'),
          ]),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── Guardar nombre ────────────────────────────────────────────────────────

  Future<void> _guardarNombre() async {
    final nuevoNombre = _nombreCtrl.text.trim();
    if (nuevoNombre.isEmpty) return;
    setState(() => _editandoNombre = false);
    try {
      await widget.svc.actualizarNombreSeccion(
          widget.empresaId, widget.seccion.id, nuevoNombre);
    } catch (_) {}
  }

  // ── Añadir item ───────────────────────────────────────────────────────────

  void _anadirItem() {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() => _items.add({
      'id': id, 'titulo': '', 'autor': '', 'genero': '',
      'precio': '', 'imagen_url': '', 'slug': id, 'disponible': true,
    }));
    _editarItem(_items.length - 1);
  }

  // ── Eliminar item ─────────────────────────────────────────────────────────

  void _eliminarItem(int index) {
    final item = _items[index];
    final nombre = item['nombre'] ?? 'Sin nombre';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar item'),
        content: Text('¿Eliminar "$nombre"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _items.removeAt(index));
              Navigator.pop(ctx);
              _guardarItems();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ── Editar item (BottomSheet genérico) ─────────────────────────────────────

  void _editarItem(int index) {
    final item = Map<String, dynamic>.from(_items[index]);
    final controllers = <String, TextEditingController>{};

    // Crear controllers para cada campo
    for (final key in item.keys) {
      if (key == 'id' || key == 'disponible') continue;
      controllers[key] = TextEditingController(
        text: item[key]?.toString() ?? '',
      );
    }

    // Si es un item nuevo sin campos, añadir los básicos
    if (controllers.isEmpty) {
      controllers['titulo']     = TextEditingController();
      controllers['autor']      = TextEditingController();
      controllers['genero']     = TextEditingController();
      controllers['precio']     = TextEditingController();
      controllers['imagen_url'] = TextEditingController();
      controllers['slug']       = TextEditingController();
    }

    bool disponible = item['disponible'] as bool? ?? true;
    String? nuevoCampoNombre;
    final idCtrl = TextEditingController(text: item['id']?.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final color = context.read<AppConfigProvider>().colorPrimario;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    item['nombre']?.toString().isNotEmpty == true
                        ? 'Editar "${item['nombre']}"'
                        : 'Nuevo item',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),

                  // ── ID del item (para data-fluix-item) ──────────────────
                  TextField(
                    controller: idCtrl,
                    decoration: InputDecoration(
                      labelText: 'ID del item',
                      hintText: 'ej: croquetas, anchoas',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.tag, size: 18),
                      helperText: 'Usa este ID en data-fluix-item="..."',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: idCtrl.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ID copiado'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Disponible ──────────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.visibility, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text('Disponible',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      Switch(
                        value: disponible,
                        onChanged: (v) => setSheet(() => disponible = v),
                        activeThumbColor: color,
                      ),
                    ],
                  ),
                  const Divider(),

                  // ── Campos dinámicos ────────────────────────────────────
                  ...controllers.entries.map((e) {
                    final campo = e.key;
                    final ctrl = e.value;
                    final esImagen = ctrl.text.startsWith('http');
                    final esNumero = campo == 'precio' ||
                        double.tryParse(ctrl.text) != null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (esImagen && ctrl.text.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                ctrl.text,
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: ctrl,
                                  keyboardType: esNumero
                                      ? const TextInputType.numberWithOptions(
                                          decimal: true)
                                      : TextInputType.text,
                                  maxLines: campo == 'descripcion' ? 3 : 1,
                                  decoration: InputDecoration(
                                    labelText: _formatearNombreCampo(campo),
                                    border: const OutlineInputBorder(),
                                    suffixIcon: esImagen
                                        ? IconButton(
                                            icon: Icon(Icons.photo_camera,
                                                color: color),
                                            onPressed: () async {
                                              final url = await widget.svc
                                                  .subirImagenDesdeGaleria(
                                                      widget.empresaId,
                                                      'generico/${widget.seccion.id}');
                                              if (url != null) {
                                                setSheet(
                                                    () => ctrl.text = url);
                                              }
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              // Botón eliminar campo
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: Colors.red, size: 20),
                                onPressed: () {
                                  setSheet(() => controllers.remove(campo));
                                },
                                tooltip: 'Quitar campo',
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  // ── Añadir campo ────────────────────────────────────────
                  const Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Nuevo campo (ej: alergenos)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) => nuevoCampoNombre = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.add_circle, color: color, size: 32),
                        onPressed: () {
                          final campo = nuevoCampoNombre
                              ?.trim()
                              .toLowerCase()
                              .replaceAll(' ', '_');
                          if (campo == null || campo.isEmpty) return;
                          if (controllers.containsKey(campo)) return;
                          setSheet(() {
                            controllers[campo] = TextEditingController();
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Botón guardar ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final finalId = idCtrl.text.trim().isNotEmpty
                            ? idCtrl.text.trim()
                            : (item['id'] ??
                                DateTime.now()
                                    .millisecondsSinceEpoch
                                    .toString());
                        final resultado = <String, dynamic>{
                          'id': finalId,
                          'disponible': disponible,
                        };
                        for (final e in controllers.entries) {
                          final val = e.value.text.trim();
                          if (val.isEmpty) continue;
                          // Intentar parsear como número
                          final num? numVal = double.tryParse(val);
                          resultado[e.key] = numVal ?? val;
                        }
                        setState(() => _items[index] = resultado);
                        Navigator.pop(ctx);
                        _guardarItems();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Guardar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatearNombreCampo(String campo) {
    return campo
        .replaceAll('_', ' ')
        .split(' ')
        .map((p) => p.isNotEmpty
            ? '${p[0].toUpperCase()}${p.substring(1)}'
            : '')
        .join(' ');
  }

  // ── Mostrar HTML de ejemplo ────────────────────────────────────────────────

  void _mostrarHtmlEjemplo(BuildContext context) {
    final secId = widget.seccion.id;
    final buf = StringBuffer();
    buf.writeln('<section data-fluix-seccion="$secId">');
    buf.writeln('  <h2 data-fluix-titulo></h2>');
    buf.writeln();
    for (final item in _items) {
      final id = item['id'] ?? '???';
      buf.writeln('  <div data-fluix-item="$id">');
      for (final key in item.keys) {
        if (key == 'id' || key == 'disponible') continue;
        final valor = item[key];
        if (valor is String && valor.startsWith('http')) {
          buf.writeln('    <img data-fluix-campo="$key">');
        } else {
          buf.writeln('    <span data-fluix-campo="$key"></span>');
        }
      }
      buf.writeln('  </div>');
      buf.writeln();
    }
    buf.writeln('</section>');

    final html = buf.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(children: [
                Icon(Icons.code, color: Color(0xFF455A64)),
                SizedBox(width: 8),
                Text('HTML de ejemplo',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ]),
              const SizedBox(height: 8),
              Text(
                'Copia este HTML y pégalo en la web del cliente. '
                'El script rellenará los valores automáticamente.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: SelectableText(
                    html,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF9CDCFE),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'El HTML está listo para usar. El script lo rellenará automáticamente.',
                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        );
      },
    );
  }


  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    const tipoColor = Color(0xFF455A64);

    // Título del AppBar según el contexto
    String appBarTitle() {
      if (_categoriaActiva != null) return _categoriaActiva!;
      if (_editandoNombre) return '';
      return _nombreCtrl.text;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EE),
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: _categoriaActiva != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => setState(() { _categoriaActiva = null; _searchCtrl.clear(); }),
              )
            : null,
        title: _editandoNombre
            ? TextField(
                controller: _nombreCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Nombre de la sección',
                  hintStyle: TextStyle(color: Colors.white54),
                ),
                onSubmitted: (_) => _guardarNombre(),
              )
            : GestureDetector(
                onTap: _categoriaActiva == null
                    ? () => setState(() => _editandoNombre = true)
                    : null,
                child: Text(appBarTitle(), overflow: TextOverflow.ellipsis),
              ),
        actions: [
          if (_editandoNombre)
            IconButton(icon: const Icon(Icons.check), onPressed: _guardarNombre)
          else if (_categoriaActiva == null) ...[
            IconButton(
              icon: const Icon(Icons.code, size: 20),
              tooltip: 'Ver HTML',
              onPressed: () => _mostrarHtmlEjemplo(context),
            ),
            if (_guardando)
              const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _anadirItem,
        backgroundColor: color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
        elevation: 4,
      ),
      body: _items.isEmpty ? _buildVacio(color) : _buildCatalogo(color),
    );
  }

  // ── Estado vacío ──────────────────────────────────────────────────────────
  Widget _buildVacio(Color color) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 88, height: 88,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.07), shape: BoxShape.circle),
        child: Icon(Icons.menu_book_rounded, size: 44, color: color.withValues(alpha: 0.35)),
      ),
      const SizedBox(height: 18),
      Text('Sin entradas todavía',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
      const SizedBox(height: 6),
      Text('Pulsa + Añadir para crear la primera',
          style: TextStyle(color: Colors.grey[500], fontSize: 13)),
    ]),
  );

  // ── Agrupa items por genero/categoria ─────────────────────────────────────

  Map<String, List<Map<String, dynamic>>> _agruparPorCategoria() {
    final grupos = <String, List<Map<String, dynamic>>>{};
    for (final item in _items) {
      final cat = item['genero']?.toString().isNotEmpty == true
          ? item['genero'].toString()
          : item['categoria']?.toString().isNotEmpty == true
              ? item['categoria'].toString()
              : 'Sin categoría';
      grupos.putIfAbsent(cat, () => []).add(item);
    }
    return grupos;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VISTAS PRINCIPALES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCatalogo(Color color) {
    // Búsqueda activa → resultados flat
    if (_query.isNotEmpty) return _buildResultadosBusqueda(color);
    // Categoría seleccionada → fichas de esa categoría
    if (_categoriaActiva != null) return _buildVistaCategoria(color);
    // Por defecto → grid de tarjetas de categoría
    return _buildGridCategorias(color);
  }

  // ── Buscador + lógica de búsqueda ────────────────────────────────────────
  Widget _buildBarraBusqueda(Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Buscar por título, autor…',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: Colors.grey[400], size: 18),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    ),
  );

  Widget _buildResultadosBusqueda(Color color) {
    final q = _query;
    final hits = _items.where((item) {
      final t = (item['titulo'] ?? item['nombre'] ?? '').toString().toLowerCase();
      final a = (item['autor'] ?? '').toString().toLowerCase();
      return t.contains(q) || a.contains(q);
    }).toList();

    return Column(children: [
      _buildBarraBusqueda(color),
      const SizedBox(height: 8),
      Expanded(
        child: hits.isEmpty
            ? Center(child: Text('Sin resultados para "$_query"',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: hits.length,
                itemBuilder: (_, i) => _buildResultadoItem(hits[i], color),
              ),
      ),
    ]);
  }

  Widget _buildResultadoItem(Map<String, dynamic> item, Color color) {
    final titulo = (item['titulo']?.toString().isNotEmpty == true
        ? item['titulo'].toString() : item['nombre']?.toString() ?? '').trim();
    final autor   = item['autor']?.toString() ?? '';
    final genero  = item['genero']?.toString() ?? '';
    final imagen  = (item['imagen_url'] as String?)?.isNotEmpty == true
        ? item['imagen_url'] as String : item['imagen'] as String?;
    final idx     = _items.indexWhere((e) => e['id'] == item['id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: imagen != null && imagen.startsWith('http')
              ? Image.network(imagen, width: 40, height: 56, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _miniPlaceholder(color))
              : _miniPlaceholder(color),
        ),
        title: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Row(children: [
          if (autor.isNotEmpty) Flexible(child: Text(autor, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic))),
          if (genero.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(20)),
              child: Text(genero, style: TextStyle(fontSize: 9.5, color: color, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: color),
              onPressed: () { if (idx >= 0) _editarItem(idx); }),
          IconButton(icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
              onPressed: () { if (idx >= 0) _eliminarItem(idx); }),
        ]),
      ),
    );
  }

  Widget _miniPlaceholder(Color color) => Container(
    width: 40, height: 56,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Icon(Icons.menu_book_rounded, size: 18, color: color.withValues(alpha: 0.3)),
  );

  // ── Grid de categorías (vista home del catálogo) ──────────────────────────
  Widget _buildGridCategorias(Color color) {
    final grupos = _agruparPorCategoria();
    return Column(children: [
      _buildBarraBusqueda(color),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text('${_items.length} libros', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Container(width: 3, height: 3, decoration: BoxDecoration(color: Colors.grey[400], shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('${grupos.length} géneros', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 600 ? 3 : 2;
            final cardW = (constraints.maxWidth - 16 * 2 - (cols - 1) * 12) / cols;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              child: Wrap(
                spacing: 12,
                runSpacing: 14,
                children: grupos.entries.map((e) =>
                    _buildTarjetaCategoria(e.key, e.value, cardW, color)).toList(),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _buildTarjetaCategoria(String genero, List<Map<String, dynamic>> items,
      double w, Color color) {
    final coverH = w * 1.35;
    // Tomar las primeras 4 portadas disponibles
    final covers = items
        .map((i) => (i['imagen_url'] as String?)?.isNotEmpty == true
            ? i['imagen_url'] as String
            : i['imagen'] as String?)
        .where((u) => u != null && u.startsWith('http'))
        .take(4)
        .cast<String>()
        .toList();

    return GestureDetector(
      onTap: () => setState(() { _categoriaActiva = genero; _searchCtrl.clear(); }),
      child: SizedBox(
        width: w,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.09), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              // Fondo: mosaico de portadas o placeholder
              SizedBox(
                width: w, height: coverH,
                child: covers.isEmpty
                    ? Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.28)],
                          ),
                        ),
                        child: Icon(Icons.menu_book_rounded, size: w * 0.35, color: Colors.white.withValues(alpha: 0.5)),
                      )
                    : covers.length == 1
                        ? Image.network(covers[0], width: w, height: coverH, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _catPlaceholder(w, coverH, color))
                        : GridView.count(
                            crossAxisCount: 2,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                            childAspectRatio: (w / 2) / (coverH / 2),
                            children: [
                              for (int i = 0; i < 4; i++)
                                i < covers.length
                                    ? Image.network(covers[i], fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(color: color.withValues(alpha: 0.1)))
                                    : Container(color: color.withValues(alpha: 0.06)),
                            ],
                          ),
              ),
              // Gradiente inferior
              Positioned(
                left: 0, right: 0, bottom: 0, height: coverH * 0.65,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                    ),
                  ),
                ),
              ),
              // Texto sobre el gradiente
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(genero,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                            shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
                          )),
                      const SizedBox(height: 3),
                      Row(children: [
                        Text('${items.length} ${items.length == 1 ? "título" : "títulos"}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 0.8),
                          ),
                          child: const Text('Ver  ›', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _catPlaceholder(double w, double h, Color color) => Container(
    width: w, height: h,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.22)],
      ),
    ),
    child: Icon(Icons.menu_book_rounded, size: w * 0.3, color: Colors.white.withValues(alpha: 0.45)),
  );

  // ── Vista interior de una categoría ──────────────────────────────────────
  Widget _buildVistaCategoria(Color color) {
    final grupos = _agruparPorCategoria();
    final catItems = grupos[_categoriaActiva!] ?? [];
    return Column(children: [
      _buildBarraBusqueda(color),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Text('${catItems.length} ${catItems.length == 1 ? "título" : "títulos"}',
              style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          child: Wrap(
            spacing: 10, runSpacing: 12,
            children: catItems.map((item) => _buildFicha(item, color)).toList(),
          ),
        ),
      ),
    ]);
  }

  // ── Ficha individual de un item ───────────────────────────────────────────

  Widget _buildFicha(Map<String, dynamic> item, Color color) {
    final titulo = (item['titulo']?.toString().isNotEmpty == true
            ? item['titulo'].toString()
            : item['nombre']?.toString() ?? '')
        .trim();
    final autor      = item['autor']?.toString() ?? '';
    final precio     = item['precio'];
    final disponible = item['disponible'] as bool? ?? true;
    final imagen     = (item['imagen_url'] as String?)?.isNotEmpty == true
        ? item['imagen_url'] as String
        : item['imagen'] as String?;
    final idx = _items.indexWhere((e) => e['id'] == item['id']);

    String precioStr() {
      if (precio == null) return '';
      if (precio is num) return '${precio.toStringAsFixed(2)}€';
      final s = precio.toString();
      return s.contains('€') ? s : '$s€';
    }

    const cardW = 150.0;
    const coverH = 200.0;
    const infoH  = 108.0;

    Widget placeholder() => Container(
      width: cardW,
      height: coverH,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.06), color.withValues(alpha: 0.14)],
        ),
      ),
      child: Icon(Icons.menu_book_rounded, color: color.withValues(alpha: 0.3), size: 44),
    );

    return SizedBox(
      width: cardW,
      height: coverH + infoH,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: !disponible
              ? Border.all(color: Colors.orange.withValues(alpha: 0.5))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Portada (altura fija) ─────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: imagen != null && imagen.startsWith('http')
                  ? Image.network(
                      imagen,
                      width: cardW,
                      height: coverH,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => placeholder(),
                    )
                  : placeholder(),
            ),
            // ── Info (altura fija, botones siempre al fondo) ──────────────
            SizedBox(
              height: infoH,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo.isEmpty ? 'Sin título' : titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        height: 1.3,
                        color: disponible ? Colors.black87 : Colors.grey,
                        decoration: disponible ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    if (autor.isNotEmpty)
                      Text(
                        autor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    const Spacer(),
                    if (precioStr().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E5F5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          precioStr(),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6A1B9A),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () { if (idx >= 0) _editarItem(idx); },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Icon(Icons.edit_outlined, size: 14, color: color),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () { if (idx >= 0) _eliminarItem(idx); },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Icon(Icons.delete_outline, size: 14, color: Colors.red[400]),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}









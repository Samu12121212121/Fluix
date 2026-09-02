import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';
import 'pantalla_editor_blog.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB BLOG — listado principal con búsqueda, filtros y acciones
// ═════════════════════════════════════════════════════════════════════════════

class TabBlogWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;

  const TabBlogWeb({super.key, required this.empresaId, required this.svc});

  @override
  State<TabBlogWeb> createState() => _TabBlogWebState();
}

class _TabBlogWebState extends State<TabBlogWeb> {
  String _busqueda = '';
  EstadoBlog? _filtroEstado;
  String? _filtroCategoria;
  final _buscadorCtrl = TextEditingController();

  // Selección múltiple
  bool _modoSeleccion = false;
  final Set<String> _seleccionados = {};

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    super.dispose();
  }

  void _toggleSeleccion(String id) {
    setState(() {
      if (_seleccionados.contains(id)) {
        _seleccionados.remove(id);
      } else {
        _seleccionados.add(id);
      }
    });
  }

  void _salirModoSeleccion() =>
      setState(() { _modoSeleccion = false; _seleccionados.clear(); });

  Future<void> _accionLote(BuildContext context, String accion,
      List<EntradaBlog> todas) async {
    if (_seleccionados.isEmpty) return;
    final ids = _seleccionados.toList();
    _salirModoSeleccion();
    try {
      await widget.svc.accionEnLote(
        empresaId: widget.empresaId, ids: ids, accion: accion);
      if (context.mounted) {
        final label = accion == 'publicar' ? 'publicados'
            : accion == 'borrador' ? 'en borrador'
            : accion == 'eliminar' ? 'eliminados' : 'actualizados';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ ${ids.length} artículo(s) $label'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    return StreamBuilder<List<CategoriaBlog>>(
      stream: widget.svc.obtenerCategorias(widget.empresaId),
      builder: (context, catSnap) {
        final categorias = catSnap.data ?? [];

        return StreamBuilder<List<EntradaBlog>>(
          stream: widget.svc.obtenerBlog(widget.empresaId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final todas = snap.data ?? [];
            final entradas = _filtrar(todas);

            return Stack(
              children: [
                Column(
                  children: [
                    // ── Header con acciones ──────────────────────────────
                    if (_modoSeleccion)
                      _buildBarraSeleccion(context, todas, color)
                    else
                      _buildPageHeader(context, categorias, color),
                    if (!_modoSeleccion) _buildFiltros(color, categorias),
                    _buildKpis(todas, color),
                    Expanded(
                      child: entradas.isEmpty
                          ? _buildVacio(color)
                          : _buildLista(entradas, categorias, color),
                    ),
                  ],
                ),
                if (_modoSeleccion && _seleccionados.isNotEmpty)
                  Positioned(
                    left: 12, right: 12, bottom: 16,
                    child: _buildAccionesLote(context, todas, categorias, color),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  List<EntradaBlog> _filtrar(List<EntradaBlog> todas) {
    return todas.where((e) {
      if (_busqueda.isNotEmpty) {
        final q = _busqueda.toLowerCase();
        if (!e.titulo.toLowerCase().contains(q) &&
            !e.slug.toLowerCase().contains(q)) return false;
      }
      if (_filtroEstado != null && e.estado != _filtroEstado) return false;
      if (_filtroCategoria != null && e.categoriaId != _filtroCategoria) return false;
      return true;
    }).toList();
  }

  Widget _buildBarraSeleccion(
      BuildContext context, List<EntradaBlog> todas, Color color) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _salirModoSeleccion,
          visualDensity: VisualDensity.compact,
        ),
        Text(
          _seleccionados.isEmpty
              ? 'Selecciona artículos'
              : '${_seleccionados.length} seleccionado(s)',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() {
            if (_seleccionados.length == todas.length) {
              _seleccionados.clear();
            } else {
              _seleccionados.addAll(todas.map((e) => e.id));
            }
          }),
          child: Text(
            _seleccionados.length == todas.length ? 'Deselect. todo' : 'Sel. todo',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ]),
    );
  }

  Widget _buildAccionesLote(BuildContext context, List<EntradaBlog> todas,
      List<CategoriaBlog> categorias, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _LoteBtn(
                icon: Icons.public, label: 'Publicar',
                color: EstadoBlog.publicado.color,
                onTap: () => _accionLote(context, 'publicar', todas),
              ),
              const SizedBox(width: 8),
              _LoteBtn(
                icon: Icons.edit_note, label: 'Borrador',
                color: EstadoBlog.borrador.color,
                onTap: () => _accionLote(context, 'borrador', todas),
              ),
              if (categorias.isNotEmpty) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: 'Cambiar categoría',
                  onSelected: (catId) =>
                      _accionLote(context, 'categoria:$catId', todas),
                  itemBuilder: (_) => categorias.map((c) =>
                    PopupMenuItem(value: c.id, child: Text(c.nombre))).toList(),
                  child: _LoteBtn(
                    icon: Icons.category_outlined, label: 'Categoría',
                    color: Colors.blueGrey,
                    onTap: null,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              _LoteBtn(
                icon: Icons.delete_outline, label: 'Eliminar',
                color: Colors.red[400]!,
                onTap: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Eliminar seleccionados'),
                    content: Text(
                        '¿Eliminar ${_seleccionados.length} artículo(s)?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _accionLote(context, 'eliminar', todas);
                        },
                        child: const Text('Eliminar',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildPageHeader(BuildContext context, List<CategoriaBlog> categorias, Color color) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: TextField(
              controller: _buscadorCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar artículos...',
                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: Color(0xFF94A3B8)),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _buscadorCtrl.clear();
                          setState(() => _busqueda = '');
                        })
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8F9FB),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: color)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => _abrirCategorias(context, categorias, color),
            icon: const Icon(Icons.category_outlined, size: 15),
            label: const Text('Categorías'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF475569),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _abrirEditor(context, null, categorias, color),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Nuevo artículo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: () => _mostrarCodigoBlog(context, color),
            icon: const Icon(Icons.code_rounded,
                color: Color(0xFF94A3B8), size: 20),
            tooltip: 'Código del blog',
          ),
          IconButton(
            onPressed: () => setState(() => _modoSeleccion = true),
            icon: const Icon(Icons.checklist_rounded,
                color: Color(0xFF94A3B8), size: 20),
            tooltip: 'Selección múltiple',
          ),
        ]),
      ]),
    );
  }

  Widget _buildFiltros(Color color, List<CategoriaBlog> categorias) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chipFiltro(
              label: 'Todos',
              selected: _filtroEstado == null && _filtroCategoria == null,
              onTap: () => setState(() {
                _filtroEstado = null;
                _filtroCategoria = null;
              }),
              color: color,
            ),
            const SizedBox(width: 6),
            for (final estado in EstadoBlog.values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _chipFiltro(
                  label: estado.label,
                  selected: _filtroEstado == estado,
                  onTap: () => setState(() {
                    _filtroEstado = _filtroEstado == estado ? null : estado;
                    _filtroCategoria = null;
                  }),
                  color: estado.color,
                ),
              ),
            if (categorias.isNotEmpty) ...[
              Container(width: 1, height: 20, color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(horizontal: 4)),
              for (final cat in categorias)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _chipFiltro(
                    label: cat.nombre,
                    selected: _filtroCategoria == cat.id,
                    onTap: () => setState(() {
                      _filtroCategoria = _filtroCategoria == cat.id ? null : cat.id;
                      _filtroEstado = null;
                    }),
                    color: color,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chipFiltro({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            )),
      ),
    );
  }

  Widget _buildKpis(List<EntradaBlog> todas, Color color) {
    final pub = todas.where((e) => e.estado == EstadoBlog.publicado).length;
    final bor = todas.where((e) => e.estado == EstadoBlog.borrador).length;
    final pro = todas.where((e) => e.estado == EstadoBlog.programado).length;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        _kpi('Publicados', '$pub', EstadoBlog.publicado.color),
        _divV(),
        _kpi('Borradores', '$bor', EstadoBlog.borrador.color),
        _divV(),
        _kpi('Programados', '$pro', EstadoBlog.programado.color),
        _divV(),
        _kpi('Total', '${todas.length}', color),
      ]),
    );
  }

  Widget _kpi(String label, String valor, Color c) => Expanded(
        child: Column(children: [
          Text(valor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: c)),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ]),
      );

  Widget _divV() => Container(width: 1, height: 28, color: Colors.grey[200]);

  Widget _buildVacio(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _busqueda.isNotEmpty || _filtroEstado != null || _filtroCategoria != null
                ? 'Sin resultados'
                : 'Sin artículos de blog',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 6),
          Text(
            _busqueda.isNotEmpty
                ? 'Prueba con otro término de búsqueda'
                : 'Crea tu primer artículo para aparecer en la web',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLista(
      List<EntradaBlog> entradas, List<CategoriaBlog> categorias, Color color) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12, 10, 12, _modoSeleccion ? 90 : 120),
      itemCount: entradas.length,
      itemBuilder: (ctx, i) {
        final e = entradas[i];
        final cat = categorias.where((c) => c.id == e.categoriaId).firstOrNull;
        final seleccionado = _seleccionados.contains(e.id);
        return _TarjetaEntrada(
          entrada: e,
          categoria: cat,
          color: color,
          seleccionado: seleccionado,
          modoSeleccion: _modoSeleccion,
          onTap: _modoSeleccion
              ? () => _toggleSeleccion(e.id)
              : () => _abrirEditor(context, e, categorias, color),
          onToggle: (v) =>
              widget.svc.togglePublicarBlog(widget.empresaId, e.id, v),
          onEliminar: () => _confirmarEliminar(context, e),
          onDuplicar: () => _duplicar(context, e),
          onToggleDestacado: () => widget.svc.toggleDestacadoBlog(
              widget.empresaId, e.id, !e.destacado),
        );
      },
    );
  }

  void _abrirEditor(BuildContext context, EntradaBlog? entrada,
      List<CategoriaBlog> categorias, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaEditorBlog(
          empresaId: widget.empresaId,
          svc: widget.svc,
          entrada: entrada,
          categorias: categorias,
        ),
      ),
    );
  }

  void _mostrarCodigoBlog(BuildContext context, Color color) {
    final snippets = widget.svc.generarPlantillaBlog();
    final listado = snippets['listado']!;
    final articulo = snippets['articulo']!;

    void copiar(String texto, String etiqueta) {
      Clipboard.setData(ClipboardData(text: texto));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$etiqueta copiado'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, sc) => Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Icon(Icons.code_rounded, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Código del Blog',
                    style: TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 17, color: color)),
                const Text('Pega cada bloque una vez en tu web. '
                    'Los posts aparecen solos al publicarlos.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ])),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: ListView(controller: sc, padding: const EdgeInsets.all(16), children: [
            _buildSnippetCard(
              titulo: 'Bloque 1 — Lista de artículos',
              subtitulo: 'Pega donde quieras mostrar las tarjetas del blog',
              codigo: listado,
              color: color,
              onCopiar: () => copiar(listado, 'Bloque 1'),
            ),
            const SizedBox(height: 16),
            _buildSnippetCard(
              titulo: 'Bloque 2 — Artículo completo',
              subtitulo: 'Se activa automáticamente con ?post=slug en la URL',
              codigo: articulo,
              color: color,
              onCopiar: () => copiar(articulo, 'Bloque 2'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Text(
                '💡 Consejo: añade marked.js en el <head> para que el '
                'contenido Markdown se renderice como HTML.\n'
                '<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>',
                style: TextStyle(fontSize: 12, color: Color(0xFF166534),
                    fontFamily: 'monospace'),
              ),
            ),
          ])),
        ]),
      ),
    );
  }

  Widget _buildSnippetCard({
    required String titulo,
    required String subtitulo,
    required String codigo,
    required Color color,
    required VoidCallback onCopiar,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 6),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 13.5, color: Color(0xFF0F172A))),
              Text(subtitulo,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            ])),
            ElevatedButton.icon(
              onPressed: onCopiar,
              icon: const Icon(Icons.copy_rounded, size: 14),
              label: const Text('Copiar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(codigo,
                style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    height: 1.5)),
          ),
        ),
      ]),
    );
  }

  void _abrirCategorias(
      BuildContext context, List<CategoriaBlog> categorias, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PantallaCategoriasScreen(
          empresaId: widget.empresaId,
          svc: widget.svc,
          color: color,
        ),
      ),
    );
  }

  Future<void> _duplicar(BuildContext context, EntradaBlog entrada) async {
    try {
      await widget.svc.duplicarEntradaBlog(widget.empresaId, entrada);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Artículo duplicado como borrador'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _confirmarEliminar(BuildContext context, EntradaBlog entrada) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar artículo'),
        content: Text(
            '¿Eliminar "${entrada.titulo}"?\n\nEl artículo se marcará como eliminado y desaparecerá de la web.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.svc.eliminarEntradaBlog(widget.empresaId, entrada.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TARJETA de entrada en la lista
// ═════════════════════════════════════════════════════════════════════════════

class _TarjetaEntrada extends StatelessWidget {
  final EntradaBlog entrada;
  final CategoriaBlog? categoria;
  final Color color;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEliminar;
  final VoidCallback onDuplicar;
  final VoidCallback onToggleDestacado;
  final bool seleccionado;
  final bool modoSeleccion;

  const _TarjetaEntrada({
    required this.entrada,
    required this.categoria,
    required this.color,
    required this.onTap,
    required this.onToggle,
    required this.onEliminar,
    required this.onDuplicar,
    required this.onToggleDestacado,
    this.seleccionado = false,
    this.modoSeleccion = false,
  });

  @override
  Widget build(BuildContext context) {
    final estadoColor = entrada.estado.color;
    return GestureDetector(
      onLongPress: modoSeleccion ? null : onTap,
      child: _buildCard(estadoColor),
    );
  }

  Widget _buildCard(Color estadoColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: seleccionado ? color.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: seleccionado ? color : const Color(0xFFE2E8F0),
          width: seleccionado ? 2 : 1,
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: entrada.imagenUrl != null
                    ? CachedNetworkImage(imageUrl: entrada.imagenUrl!,
                        width: 56, height: 56, fit: BoxFit.cover,
                        errorWidget: (_, e, s) => _fallback())
                    : _fallback(),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      entrada.titulo.isEmpty ? 'Sin título' : entrada.titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Color(0xFF0F172A)),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge de estado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(entrada.estado.label,
                        style: TextStyle(
                            color: estadoColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 4),
                if (entrada.resumen.isNotEmpty)
                  Text(entrada.resumen,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF64748B), fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  Text(entrada.fechaFormateada,
                      style: const TextStyle(
                          color: Color(0xFF94A3B8), fontSize: 11)),
                  if (entrada.autor.isNotEmpty)
                    Text('· ${entrada.autor}',
                        style: const TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 11)),
                  if (categoria != null)
                    Text('· ${categoria!.nombre}',
                        style: TextStyle(color: color, fontSize: 11,
                            fontWeight: FontWeight.w500)),
                ]),
                if (entrada.etiquetas.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Wrap(spacing: 4, runSpacing: 3,
                    children: entrada.etiquetas.take(3).map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(t, style: TextStyle(fontSize: 10, color: color)),
                    )).toList(),
                  ),
                ],
              ])),
              // Controles (estrella + toggle o checkbox)
              if (modoSeleccion)
                Checkbox(
                  value: seleccionado,
                  onChanged: (_) => onTap(),
                  activeColor: color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                )
              else
                Column(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: Icon(
                      entrada.destacado
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: entrada.destacado
                          ? const Color(0xFFFFC107)
                          : const Color(0xFFCBD5E1),
                      size: 20,
                    ),
                    onPressed: onToggleDestacado,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  Switch(
                    value: entrada.estado == EstadoBlog.publicado,
                    onChanged: onToggle,
                    activeThumbColor: EstadoBlog.publicado.color,
                    activeTrackColor: EstadoBlog.publicado.color.withValues(alpha: 0.3),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ]),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Row(children: [
            Expanded(child: TextButton.icon(
              onPressed: onTap,
              icon: Icon(Icons.edit_outlined, size: 14, color: color),
              label: Text('Editar',
                  style: TextStyle(color: color, fontSize: 11.5,
                      fontWeight: FontWeight.w600)),
            )),
            Container(width: 1, height: 28, color: const Color(0xFFF1F5F9)),
            Expanded(child: TextButton.icon(
              onPressed: onDuplicar,
              icon: const Icon(Icons.copy_outlined, size: 14,
                  color: Color(0xFF64748B)),
              label: const Text('Duplicar',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
            )),
            Container(width: 1, height: 28, color: const Color(0xFFF1F5F9)),
            Expanded(child: TextButton.icon(
              onPressed: onEliminar,
              icon: const Icon(Icons.delete_outline_rounded, size: 14,
                  color: Colors.red),
              label: const Text('Eliminar',
                  style: TextStyle(color: Colors.red, fontSize: 11.5)),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _fallback() => Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.article, color: color, size: 22),
      );
} // fin _TarjetaEntrada

// ── Botón de acción en lote ───────────────────────────────────────────────────

class _LoteBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _LoteBtn({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12,
            fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// GESTIÓN DE CATEGORÍAS
// ═════════════════════════════════════════════════════════════════════════════

class _PantallaCategoriasScreen extends StatelessWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color color;

  const _PantallaCategoriasScreen({
    required this.empresaId,
    required this.svc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Categorías del blog'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_nueva_cat',
        onPressed: () => _abrirFormulario(context, null),
        backgroundColor: color,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoría'),
      ),
      body: StreamBuilder<List<CategoriaBlog>>(
        stream: svc.obtenerCategorias(empresaId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final cats = snap.data ?? [];
          if (cats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Sin categorías',
                      style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
            itemCount: cats.length,
            itemBuilder: (ctx, i) {
              final cat = cats[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6, offset: const Offset(0, 2))
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                        child: Text('${i + 1}',
                            style: TextStyle(color: color,
                                fontWeight: FontWeight.bold))),
                  ),
                  title: Text(cat.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('/${cat.slug}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: color, size: 20),
                        onPressed: () => _abrirFormulario(context, cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () => _eliminar(context, cat),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _abrirFormulario(BuildContext context, CategoriaBlog? cat) {
    final nombreCtrl = TextEditingController(text: cat?.nombre ?? '');
    final slugCtrl = TextEditingController(text: cat?.slug ?? '');
    bool slugManual = cat?.slug.isNotEmpty ?? false;

    nombreCtrl.addListener(() {
      if (!slugManual) {
        slugCtrl.text = nombreCtrl.text
            .toLowerCase()
            .replaceAll(RegExp(r'[áàä]'), 'a')
            .replaceAll(RegExp(r'[éèë]'), 'e')
            .replaceAll(RegExp(r'[íìï]'), 'i')
            .replaceAll(RegExp(r'[óòö]'), 'o')
            .replaceAll(RegExp(r'[úùü]'), 'u')
            .replaceAll('ñ', 'n')
            .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
            .trim()
            .replaceAll(RegExp(r'\s+'), '-');
      }
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 20, right: 20, top: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(cat == null ? 'Nueva categoría' : 'Editar categoría',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: slugCtrl,
              decoration: const InputDecoration(
                  labelText: 'Slug (URL)',
                  border: OutlineInputBorder(),
                  prefixText: '/blog/'),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9\-]')),
              ],
              onChanged: (_) => slugManual = true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final nombre = nombreCtrl.text.trim();
                  if (nombre.isEmpty) return;
                  final nueva = CategoriaBlog(
                    id: cat?.id ?? '',
                    nombre: nombre,
                    slug: slugCtrl.text.trim(),
                    orden: cat?.orden ?? 0,
                  );
                  await svc.guardarCategoria(empresaId, nueva);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(cat == null ? 'Crear' : 'Guardar'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _eliminar(BuildContext context, CategoriaBlog cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text(
            '¿Eliminar "${cat.nombre}"?\n\nNo se puede eliminar si tiene artículos asignados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await svc.eliminarCategoria(empresaId, cat.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('$e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

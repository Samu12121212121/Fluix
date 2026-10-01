import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import 'tab_categorias_nazari.dart';

// Normalización accent-insensitive para categorías (misma lógica que galería)
String _normCatCatalogo(String s) => s.toLowerCase()
    .replaceAll(RegExp(r'[àáâãäåā]'), 'a')
    .replaceAll(RegExp(r'[èéêëē]'), 'e')
    .replaceAll(RegExp(r'[ìíîïī]'), 'i')
    .replaceAll(RegExp(r'[òóôõöō]'), 'o')
    .replaceAll(RegExp(r'[ùúûüū]'), 'u')
    .replaceAll('ñ', 'n')
    .replaceAll('ç', 'c');

// ═════════════════════════════════════════════════════════════════════════════
// TAB CATÁLOGO WEB — catálogo genérico, mismo estilo que Secciones
// Colección: empresas/{id}/catalogo_web
// Sync inmediato a la web: toggle/borrar/añadir → onSnapshot en el script
// ═════════════════════════════════════════════════════════════════════════════

class TabCatalogoWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color? color;
  final String? seccionId;
  final void Function(Map<String, dynamic>? item)? onAbrirEditor;

  const TabCatalogoWeb({
    super.key,
    required this.empresaId,
    required this.svc,
    this.color,
    this.seccionId,
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
    _stream = widget.seccionId != null
        ? widget.svc.obtenerCatalogoWebSeccion(widget.empresaId, widget.seccionId!)
        : widget.svc.obtenerCatalogoWeb(widget.empresaId);
  }

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    super.dispose();
  }

  /// Migra libros→catalogo_web solo si catalogo_web está REALMENTE vacío.
  /// Verifica contra Firestore directamente para no confundir "cargando" con "vacío".
  Future<void> _checkAutoMigrar(List<Map<String, dynamic>> items) async {
    if (_autoMigradoChecked) return;
    _autoMigradoChecked = true;
    // Si el stream ya tiene datos, no hay nada que migrar
    if (items.isNotEmpty) return;
    try {
      // Verificar en Firestore directamente — el stream puede estar aún cargando
      final catSnap = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('catalogo_web').limit(1).get();
      if (catSnap.docs.isNotEmpty) return; // ya tiene datos, no migrar
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

        // Categorías únicas para el filtro — dedup accent-insensitive
        final _catSeen = <String>{};
        final categorias = todos.expand<String>((i) {
          final arr = i['categorias'];
          if (arr is List && arr.isNotEmpty) {
            return arr.map((e) => e.toString().trim()).where((s) => s.isNotEmpty);
          }
          return (i['categoria'] as String? ?? '').split('/')
              .map((s) => s.trim()).where((s) => s.isNotEmpty);
        }).where((c) => _catSeen.add(_normCatCatalogo(c))).toList()..sort();

        // Filtrado — comparación accent-insensitive
        final filtrados = todos.where((item) {
          if (_filtroCategoria != null) {
            final arr = item['categorias'];
            final cats = (arr is List && arr.isNotEmpty)
                ? arr.map((e) => e.toString().trim()).toList()
                : (item['categoria'] as String? ?? '').split('/').map((s) => s.trim()).toList();
            if (!cats.any((c) =>
                _normCatCatalogo(c) == _normCatCatalogo(_filtroCategoria!))) {
              return false;
            }
          }
          if (_busqueda.isNotEmpty) {
            final q = _busqueda.toLowerCase();
            return (item['nombre'] ?? '').toLowerCase().contains(q) ||
                (item['campo_autor'] ?? '').toLowerCase().contains(q) ||
                (item['categoria'] ?? '').toLowerCase().contains(q);
          }
          return true;
        }).toList();

        final activos    = todos.where((i) => i['activo'] as bool? ?? true).length;
        final conStripe  = todos.where((i) => (i['stripe_link'] as String? ?? '').isNotEmpty).length;
        // Umbral: si hay más de 80 ítems, probablemente hay duplicados
        final hayDuplicados = todos.length > 80;

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
                OutlinedButton.icon(
                  onPressed: () => mostrarGestionCategorias(
                      context, widget.empresaId, color),
                  icon: const Icon(Icons.label_outline_rounded, size: 14),
                  label: const Text('Categorías'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                if (hayDuplicados) ...[
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: () => _limpiarDuplicados(context),
                    icon: const Icon(Icons.cleaning_services_rounded,
                        size: 14, color: Color(0xFFDC2626)),
                    label: Text('Limpiar duplicados (${todos.length})',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w600)),
                  ),
                ],
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
              // Barra búsqueda + filtros + botón — adaptada a móvil/desktop
              LayoutBuilder(builder: (_, bc) {
                final isNarrow = bc.maxWidth < 560;

                // Widget reutilizable: barra de búsqueda
                final searchBar = Container(
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
                );

                // Widget reutilizable: filtro de categoría
                final categoryFilter = categorias.isNotEmpty
                    ? Container(
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
                            hint: Text(isNarrow ? 'Categoría' : 'Todas las categorías',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                                size: 16, color: Color(0xFF64748B)),
                            items: [
                              DropdownMenuItem(value: null,
                                  child: Text(isNarrow ? 'Todas' : 'Todas las categorías',
                                      style: const TextStyle(fontSize: 12))),
                              ...categorias.map((c) => DropdownMenuItem(
                                  value: c, child: Text(c, style: const TextStyle(fontSize: 12)))),
                            ],
                            onChanged: (v) => setState(() => _filtroCategoria = v),
                          ),
                        ),
                      )
                    : null;

                // Botón Añadir (siempre visible)
                final addBtn = ElevatedButton.icon(
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
                );

                // Acciones secundarias (Stripe y Sync) — en móvil van al popup
                final stripeActions = <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'stripe',
                    onTap: () => _abrirVincularStripe(todos),
                    child: Row(children: [
                      const Icon(Icons.credit_card_rounded, size: 16, color: Color(0xFF635BFF)),
                      const SizedBox(width: 10),
                      Text('Vincular Stripe${conStripe > 0 ? ' ($conStripe)' : ''}'),
                    ]),
                  ),
                  const PopupMenuItem<String>(
                    value: 'sync',
                    child: Row(children: [
                      Icon(Icons.sync_rounded, size: 16, color: Color(0xFF635BFF)),
                      SizedBox(width: 10),
                      Text('Auditar / Sincronizar Stripe'),
                    ]),
                  ),
                ];

                if (isNarrow) {
                  // ── MÓVIL: 2 filas ─────────────────────────────────────
                  return Column(children: [
                    Row(children: [
                      Expanded(child: searchBar),
                      const SizedBox(width: 8),
                      addBtn,
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      if (categoryFilter != null) ...[
                        Expanded(child: categoryFilter),
                        const SizedBox(width: 8),
                      ],
                      PopupMenuButton<String>(
                        tooltip: 'Más opciones',
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Color(0xFF635BFF)),
                        style: IconButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF635BFF)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          minimumSize: const Size(38, 38),
                        ),
                        onSelected: (v) {
                          if (v == 'sync') _abrirAuditarStripe();
                        },
                        itemBuilder: (_) => stripeActions,
                      ),
                    ]),
                  ]);
                }

                // ── DESKTOP: 1 fila ────────────────────────────────────
                return Row(children: [
                  Expanded(child: searchBar),
                  if (categoryFilter != null) ...[
                    const SizedBox(width: 8),
                    categoryFilter,
                  ],
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _abrirVincularStripe(todos),
                    icon: const Icon(Icons.credit_card_rounded, size: 14),
                    label: Text('Stripe${conStripe > 0 ? ' ($conStripe)' : ''}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF635BFF),
                      side: const BorderSide(color: Color(0xFF635BFF)),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Auditar / Sincronizar Stripe',
                    icon: const Icon(Icons.sync_rounded, size: 18),
                    color: const Color(0xFF635BFF),
                    style: IconButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF635BFF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(38, 38),
                    ),
                    onPressed: _abrirAuditarStripe,
                  ),
                  const SizedBox(width: 8),
                  addBtn,
                ]);
              }),
            ]),
          ),
          const Divider(height: 1),
          // ── Barra de acciones por categoría ──────────────────────────────────
          if (_filtroCategoria != null) ...[
            Container(
              color: color.withValues(alpha: 0.04),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(children: [
                Icon(Icons.category_outlined, size: 13, color: color),
                const SizedBox(width: 6),
                Expanded(child: Text(
                  '${filtrados.length} ítem${filtrados.length != 1 ? 's' : ''} en "$_filtroCategoria"',
                  style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
                )),
                _catAccionBtn('Ocultar todos', const Color(0xFFEF4444), () =>
                    _toggleCategoria(filtrados, false)),
                const SizedBox(width: 6),
                _catAccionBtn('Mostrar todos', const Color(0xFF10B981), () =>
                    _toggleCategoria(filtrados, true)),
              ]),
            ),
            const Divider(height: 1),
          ],
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

  Widget _catAccionBtn(String label, Color c, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.withValues(alpha: 0.25)),
          ),
          child: Text(label, style: TextStyle(
              fontSize: 11, color: c, fontWeight: FontWeight.w700)),
        ),
      );

  Future<void> _toggleCategoria(List<Map<String, dynamic>> items, bool visible) async {
    if (items.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final item in items) {
      final id = item['id'] as String?;
      if (id == null || id.isEmpty) continue;
      batch.update(
        FirebaseFirestore.instance
            .collection('empresas').doc(widget.empresaId)
            .collection('catalogo_web').doc(id),
        {'activo': visible},
      );
    }
    await batch.commit();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${items.length} ítems ${visible ? 'activados' : 'ocultados'}'),
      backgroundColor: visible ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      duration: const Duration(seconds: 2),
    ));
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
          const SizedBox(width: 8),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            ]),
          ),
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
        onLibroDelMes: () async {
          try {
            await widget.svc.toggleLibroDelMesCatalogo(
                widget.empresaId, items[i]['id'] as String,
                items[i]['es_libro_del_mes'] as bool? ?? false);
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating));
          }
        },
        onMasVendido: () async {
          try {
            await widget.svc.toggleMasVendidoCatalogo(
                widget.empresaId, items[i]['id'] as String,
                items[i]['es_mas_vendido'] as bool? ?? false);
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating));
          }
        },
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

  Future<void> _limpiarDuplicados(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar duplicados'),
        content: const Text(
            'Se eliminarán los documentos duplicados del catálogo, conservando '
            'el más completo de cada libro (el que tenga imagen, Stripe, etc.).\n\n'
            '¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpiar', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      final eliminados = await widget.svc.deduplicarCatalogoWeb(widget.empresaId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ $eliminados documentos duplicados eliminados'),
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

  void _abrirVincularStripe(List<Map<String, dynamic>> items) {
    final ctrls = <String, TextEditingController>{};
    for (final item in items) {
      final id = item['id'] as String? ?? '';
      if (id.isNotEmpty) {
        ctrls[id] = TextEditingController(text: item['stripe_link'] as String? ?? '');
      }
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _StripeLinksSheet(
        empresaId: widget.empresaId,
        svc: widget.svc,
        items: items,
        ctrls: ctrls,
      ),
    ).then((_) {
      for (final c in ctrls.values) c.dispose();
    });
  }

  void _abrirAuditarStripe() {
    showDialog<void>(
      context: context,
      builder: (_) => _StripeAuditDialog(empresaId: widget.empresaId),
    );
  }
}

// ── Bottom sheet para vincular Stripe links en bulk ───────────────────────────

class _StripeLinksSheet extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final List<Map<String, dynamic>> items;
  final Map<String, TextEditingController> ctrls;

  const _StripeLinksSheet({
    required this.empresaId, required this.svc,
    required this.items, required this.ctrls,
  });

  @override
  State<_StripeLinksSheet> createState() => _StripeLinksSheetState();
}

class _StripeLinksSheetState extends State<_StripeLinksSheet> {
  bool _guardando = false;
  bool _sincronizando = false;

  /// Lee los payment_link de la colección `libros` y rellena los controllers automáticamente.
  Future<void> _sincronizarDesdeLibros() async {
    setState(() => _sincronizando = true);
    try {
      final actualizados = await widget.svc.sincronizarLinksStripe(widget.empresaId);
      if (!mounted) return; // sheet cerrado durante la operación
      // Leer catalogo_web actualizado y refrescar controllers
      final snap = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('catalogo_web').get();
      if (!mounted) return; // verificar de nuevo tras segundo await
      for (final doc in snap.docs) {
        final link = doc.data()['stripe_link'] as String? ?? '';
        if (link.isNotEmpty && widget.ctrls.containsKey(doc.id)) {
          widget.ctrls[doc.id]!.text = link;
        }
      }
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ $actualizados libro${actualizados == 1 ? '' : 's'} sincronizado${actualizados == 1 ? '' : 's'} desde Stripe'),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final item in widget.items) {
        final id = item['id'] as String? ?? '';
        if (id.isEmpty) continue;
        final link = widget.ctrls[id]?.text.trim() ?? '';
        batch.update(
          FirebaseFirestore.instance
              .collection('empresas').doc(widget.empresaId)
              .collection('catalogo_web').doc(id),
          {'stripe_link': link, 'payment_link': link},
        );
      }
      await batch.commit();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Links de Stripe actualizados'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conStripe = widget.ctrls.values.where((c) => c.text.isNotEmpty).length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: const Color(0xFF635BFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.credit_card_rounded,
                  size: 18, color: Color(0xFF635BFF)),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Vincular con Stripe',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              Text('$conStripe de ${widget.items.length} con link',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ]),
          ]),
        ),
        const Divider(height: 1),
        ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final item = widget.items[i];
              final id   = item['id'] as String? ?? '';
              final ctrl = widget.ctrls[id];
              if (ctrl == null) return const SizedBox.shrink();
              return Row(children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    item['nombre'] as String? ?? 'Sin nombre',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                        color: Color(0xFF334155)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: ctrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'https://buy.stripe.com/…',
                        hintStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                      ),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: OutlinedButton.icon(
            onPressed: (_sincronizando || _guardando) ? null : _sincronizarDesdeLibros,
            icon: _sincronizando
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF635BFF)))
                : const Icon(Icons.sync_rounded, size: 16, color: Color(0xFF635BFF)),
            label: const Text('Sincronizar automáticamente desde libros',
                style: TextStyle(fontSize: 13, color: Color(0xFF635BFF))),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              side: const BorderSide(color: Color(0xFF635BFF)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF635BFF),
                foregroundColor: Colors.white, elevation: 0,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _guardando
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Guardar todos',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Dialog auditoría/sync Stripe ─────────────────────────────────────────────

class _StripeAuditDialog extends StatefulWidget {
  final String empresaId;
  const _StripeAuditDialog({required this.empresaId});
  @override
  State<_StripeAuditDialog> createState() => _StripeAuditDialogState();
}

class _StripeAuditDialogState extends State<_StripeAuditDialog> {
  bool _cargando = false;
  Map<String, dynamic>? _resultado;
  String? _error;
  String _modoSeleccionado = 'diagnostico';

  static const _modos = {
    'diagnostico':      'Solo diagnóstico',
    'limpiar':          'Archivar huérfanos',
    'crear_faltantes':  'Crear productos faltantes',
    'full':             'Limpiar + Crear faltantes',
  };

  Future<void> _ejecutar() async {
    setState(() { _cargando = true; _resultado = null; _error = null; });
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('auditarStripeCatalogo');
      final res = await fn.call({'modo': _modoSeleccionado});
      setState(() { _resultado = Map<String, dynamic>.from(res.data as Map); });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF635BFF);
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.sync_rounded, color: purple, size: 20),
        const SizedBox(width: 8),
        const Text('Auditar Stripe', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Selector de modo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Modo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B), letterSpacing: 0.5)),
              const SizedBox(height: 8),
              ..._modos.entries.map((e) => RadioListTile<String>(
                title: Text(e.value, style: const TextStyle(fontSize: 13)),
                value: e.key,
                groupValue: _modoSeleccionado,
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: purple,
                onChanged: _cargando ? null : (v) => setState(() => _modoSeleccionado = v!),
              )),
            ]),
          ),
          const SizedBox(height: 12),

          // Resultado
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(children: [
                CircularProgressIndicator(color: purple),
                SizedBox(height: 8),
                Text('Consultando Stripe y Firestore…', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ]),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: TextStyle(fontSize: 11, color: Colors.red.shade800))),
              ]),
            )
          else if (_resultado != null)
            _buildResultado(_resultado!, purple),
        ])),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        FilledButton.icon(
          onPressed: _cargando ? null : _ejecutar,
          icon: _cargando
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_arrow_rounded, size: 16),
          label: Text(_cargando ? 'Ejecutando…' : 'Ejecutar'),
          style: FilledButton.styleFrom(backgroundColor: purple),
        ),
      ],
    );
  }

  Widget _buildResultado(Map<String, dynamic> r, Color c) {
    final rows = <_KvRow>[
      _KvRow('Productos en Stripe',         '${r['stripe_total'] ?? 0}', null),
      _KvRow('  → Activos',                 '${r['stripe_activos'] ?? 0}', null),
      _KvRow('  → Sin metadata catálogo',   '${r['stripe_sin_meta'] ?? 0}',
          (r['stripe_sin_meta'] as int? ?? 0) > 0 ? Colors.orange : null),
      _KvRow('Huérfanos (no en catálogo)',  '${r['orphans'] ?? 0}',
          (r['orphans'] as int? ?? 0) > 0 ? Colors.red : null),
      _KvRow('Duplicados en Stripe',        '${r['duplicados'] ?? 0}',
          (r['duplicados'] as int? ?? 0) > 0 ? Colors.orange : null),
      _KvRow('Libros sin stripe_product',   '${r['catalogo_sin_stripe'] ?? 0}',
          (r['catalogo_sin_stripe'] as int? ?? 0) > 0 ? Colors.orange : null),
      _KvRow('Total en catálogo Fluix',     '${r['catalogo_total'] ?? 0}', null),
    ];

    if (r.containsKey('archivados'))
      rows.add(_KvRow('✅ Archivados en Stripe', '${r['archivados']}', Colors.green));
    if (r.containsKey('creados'))
      rows.add(_KvRow('✅ Creados en Stripe', '${r['creados']}', Colors.green));
    if (r.containsKey('errores') && (r['errores'] as int? ?? 0) > 0)
      rows.add(_KvRow('❌ Errores', '${r['errores']}', Colors.red));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows.map((row) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(row.label, style: TextStyle(fontSize: 12,
                color: row.color ?? const Color(0xFF475569)))),
            Text(row.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                color: row.color ?? const Color(0xFF0F172A))),
          ]),
        )).toList(),
      ),
    );
  }
}

class _KvRow {
  final String label, value;
  final Color? color;
  const _KvRow(this.label, this.value, this.color);
}

// ── Tarjeta — mismo estilo que _TarjetaSeccion ────────────────────────────────

class _TarjetaItemCatalogo extends StatelessWidget {
  final Map<String, dynamic> item;
  final Color color;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onLibroDelMes;
  final VoidCallback onMasVendido;

  const _TarjetaItemCatalogo({
    super.key,
    required this.item, required this.color,
    required this.onEdit, required this.onToggle, required this.onDelete,
    required this.onLibroDelMes, required this.onMasVendido,
  });

  @override
  Widget build(BuildContext context) {
    final activo      = item['activo'] as bool? ?? true;
    final nombre      = item['nombre'] as String? ?? 'Sin nombre';
    final precio      = item['precio']?.toString() ?? '';
    final cat         = item['categoria'] as String? ?? '';
    final autor       = item['campo_autor'] as String? ?? '';
    final stripeUrl   = item['stripe_link'] as String? ?? '';
    final stripe      = stripeUrl.isNotEmpty;
    final img         = item['imagen_url'] as String? ?? '';
    final esLibroMes  = item['es_libro_del_mes'] as bool? ?? false;
    final esMasVendido = item['es_mas_vendido']  as bool? ?? false;
    final pesoRaw     = item['campo_peso'] ?? item['peso'];
    final pesoStr     = pesoRaw != null && pesoRaw.toString().isNotEmpty
        ? '${pesoRaw}g' : '';

    final subtitle = [
      if (autor.isNotEmpty) autor,
      if (precio.isNotEmpty) precio,
      if (cat.isNotEmpty) cat,
      if (pesoStr.isNotEmpty) pesoStr,
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
        child: LayoutBuilder(builder: (_, bc) {
          // En pantallas estrechas los badges se ocultan: el botón ⭐ y el icono
          // de Stripe ya comunican el estado; los badges causarían overflow.
          final showBadges = bc.maxWidth > 420;
          return Padding(
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
                if (showBadges && esLibroMes) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B1E2A).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Libro del mes',
                        style: TextStyle(fontSize: 9, color: Color(0xFF6B1E2A),
                            fontWeight: FontWeight.w700)),
                  ),
                ],
                if (showBadges && esMasVendido) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Más vendido',
                        style: TextStyle(fontSize: 9, color: Color(0xFF10B981),
                            fontWeight: FontWeight.w700)),
                  ),
                ],
                if (showBadges && stripe) ...[
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
            // Controles
            if (stripe)
              Tooltip(
                message: 'Copiar link de pago',
                child: IconButton(
                  icon: const Icon(Icons.link_rounded, size: 16, color: Color(0xFF635BFF)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: stripeUrl));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Link copiado'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                ),
              ),
            IconButton(
              icon: Icon(
                esLibroMes ? Icons.star_rounded : Icons.star_border_rounded,
                color: esLibroMes ? const Color(0xFF6B1E2A) : Colors.grey[400],
                size: 20,
              ),
              tooltip: esLibroMes ? 'Quitar "Libro del mes"' : 'Marcar como "Libro del mes"',
              onPressed: onLibroDelMes,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: Icon(
                esMasVendido ? Icons.trending_up_rounded : Icons.trending_up_outlined,
                color: esMasVendido ? const Color(0xFF10B981) : Colors.grey[400],
                size: 20,
              ),
              tooltip: esMasVendido ? 'Quitar "Más vendido"' : 'Marcar como "Más vendido"',
              onPressed: onMasVendido,
              visualDensity: VisualDensity.compact,
            ),
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
        );
        }),
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

// ── Selector de autor ────────────────────────────────────────────────────────

class _AutorPickerSheet extends StatefulWidget {
  final List<Map<String, String>> docs;
  final Color color;
  const _AutorPickerSheet({required this.docs, required this.color});
  @override
  State<_AutorPickerSheet> createState() => _AutorPickerSheetState();
}

class _AutorPickerSheetState extends State<_AutorPickerSheet> {
  String _q = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtrados = _q.isEmpty
        ? widget.docs
        : widget.docs.where((a) =>
            (a['nombre'] ?? '').toLowerCase().contains(_q.toLowerCase())).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 36, height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Icon(Icons.person_search_rounded, size: 18, color: widget.color),
            const SizedBox(width: 8),
            const Text('Seleccionar autor',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar…',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true, fillColor: const Color(0xFFF8F9FB),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        const Divider(height: 1),
        ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5),
          child: ListView.builder(
            itemCount: filtrados.length,
            itemBuilder: (_, i) {
              final a = filtrados[i];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: widget.color.withValues(alpha: 0.12),
                  child: Text(
                    (a['nombre'] ?? '?').substring(0, 1).toUpperCase(),
                    style: TextStyle(fontSize: 12, color: widget.color,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(a['nombre'] ?? '', style: const TextStyle(fontSize: 13)),
                subtitle: Text(a['id'] ?? '',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                onTap: () => Navigator.pop(context, a),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
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
  String _autorId = '';        // campo_autor_id
  final _traductorCtrl   = TextEditingController();
  String _traductorId    = ''; // campo_traductor_id
  String _traductorGenero = '';
  final _ilustradorCtrl  = TextEditingController();
  String _ilustradorId   = ''; // campo_ilustrador_id
  String _ilustradorGenero = '';
  final _isbnCtrl        = TextEditingController();
  final _paginasCtrl     = TextEditingController();
  final _formatoCtrl     = TextEditingController();
  final _dimensionesCtrl = TextEditingController();
  final _mesCtrl         = TextEditingController();
  final _diaCtrl         = TextEditingController();
  final _pesoCtrl              = TextEditingController();
  final _coleccionCtrl         = TextEditingController();
  final _preventaEnvioCtrl     = TextEditingController();
  int  _anio  = DateTime.now().year;
  bool _activo = true;
  bool _preventa = false;
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
      _precioCtrl.text      = it['precio']?.toString() ?? '';
      _precioDigCtrl.text   = it['precio_digital']?.toString() ?? '';
      _stripeLinkCtrl.text  = it['stripe_link'] ?? '';
      _descCtrl.text        = it['descripcion'] ?? '';
      _autorCtrl.text       = it['campo_autor'] ?? '';
      _autorId              = it['campo_autor_id'] as String? ?? '';
      _traductorCtrl.text   = it['campo_traductor'] ?? '';
      _traductorId          = it['campo_traductor_id'] as String? ?? '';
      _traductorGenero      = it['campo_traductor_genero'] as String? ?? '';
      _ilustradorCtrl.text  = it['campo_ilustrador'] ?? '';
      _ilustradorId         = it['campo_ilustrador_id'] as String? ?? '';
      _ilustradorGenero     = it['campo_ilustrador_genero'] as String? ?? '';
      _isbnCtrl.text        = it['campo_isbn'] ?? '';
      _paginasCtrl.text     = it['campo_paginas'] ?? '';
      _formatoCtrl.text     = it['campo_formato'] ?? '';
      _dimensionesCtrl.text = it['campo_dimensiones'] ?? '';
      _mesCtrl.text         = it['campo_mes'] ?? '';
      _diaCtrl.text         = it['campo_dia']?.toString() ?? '';
      _pesoCtrl.text        = it['campo_peso']?.toString() ?? '';
      _coleccionCtrl.text   = it['campo_coleccion'] ?? it['coleccion'] ?? '';
      _anio      = int.tryParse(it['campo_anio']?.toString() ?? '') ?? DateTime.now().year;
      _activo    = it['activo'] as bool? ?? true;
      _preventa  = it['preventa'] as bool? ?? false;
      _preventaEnvioCtrl.text = it['preventa_envio_lejano']?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _slugCtrl, _categoriaCtrl, _tagCtrl,
        _imagenCtrl, _precioCtrl, _precioDigCtrl, _stripeLinkCtrl, _descCtrl,
        _autorCtrl, _traductorCtrl, _ilustradorCtrl,
        _isbnCtrl, _paginasCtrl, _formatoCtrl, _dimensionesCtrl,
        _mesCtrl, _diaCtrl, _pesoCtrl, _coleccionCtrl, _preventaEnvioCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
            appBar: FluixAppBar(titulo: widget.item == null ? 'Nuevo elemento' : 'Editar elemento', showLeading: true),
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
              _campoAutorConSelector(color),
              const Divider(height: 1),
              _campoConGenero(_traductorCtrl, 'Traductor/a', '_traductorGenero'),
              const Divider(height: 1),
              _campoConGenero(_ilustradorCtrl, 'Ilustrador/a', '_ilustradorGenero'),
              const Divider(height: 1),
              _campo(_coleccionCtrl, 'Colección editorial',
                  hint: 'Colección Arrayanes, Colección Daraxa…'),
              const Divider(height: 1),
              _campo(_isbnCtrl, 'ISBN / Referencia'),
              const Divider(height: 1),
              _campo(_paginasCtrl, 'Páginas / Unidades'),
              const Divider(height: 1),
              _campo(_formatoCtrl, 'Formato'),
              const Divider(height: 1),
              _campo(_dimensionesCtrl, 'Dimensiones'),
              const Divider(height: 1),
              _campo(_pesoCtrl, 'Peso (g)',
                  hint: 'ej. 320',
                  keyboardType: TextInputType.number),
              const Divider(height: 1),
              _campo(_mesCtrl, 'Mes de venta', hint: 'ej. Octubre'),
              const Divider(height: 1),
              _campo(_diaCtrl, 'Día de venta (opcional)',
                  hint: 'ej. 15',
                  keyboardType: TextInputType.number),
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
          const SizedBox(height: 8),
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SwitchListTile(
              value: _preventa,
              onChanged: (v) => setState(() => _preventa = v),
              title: Text(_preventa ? '🔖 En preventa' : '🔖 No es preventa',
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                _preventa
                    ? 'Envío gratis a España y Europa hasta publicación'
                    : 'El libro ya está disponible y se envía de inmediato',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              contentPadding: EdgeInsets.zero,
              activeColor: const Color(0xFFF59E0B),
            ),
            if (_preventa) ...[
              const Divider(height: 1),
              _campo(
                _preventaEnvioCtrl,
                'Precio envío lejano en preventa (€)',
                hint: 'ej. 20  (LATAM/Mundo — vacío = tarifa normal)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ])),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ── Selector de autor con ID garantizado ────────────────────────────────────

  Widget _campoAutorConSelector(Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: TextField(
          controller: _autorCtrl,
          decoration: InputDecoration(
            hintText: 'Autor / Responsable',
            labelText: _autorId.isNotEmpty
                ? 'Autor (ID vinculado ✓)'
                : 'Autor / Responsable',
            labelStyle: TextStyle(
              color: _autorId.isNotEmpty
                  ? const Color(0xFF10B981)
                  : Colors.grey,
              fontSize: 13,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (_) { if (_autorId.isNotEmpty) setState(() => _autorId = ''); },
        ),
      ),
      IconButton(
        tooltip: 'Seleccionar autor de la lista',
        icon: Icon(Icons.person_search_rounded,
            size: 20,
            color: _autorId.isNotEmpty ? const Color(0xFF10B981) : color),
        visualDensity: VisualDensity.compact,
        onPressed: () => _abrirSelectorAutor(color),
      ),
    ]);
  }

  Future<void> _abrirSelectorAutor(Color color) async {
    final snap = await FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('autores')
        .orderBy('nombre')
        .limit(300)
        .get();
    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AutorPickerSheet(
          docs: snap.docs.map((d) => {
                'id': d.id,
                'nombre': d.data()['nombre'] as String? ?? '',
              }).toList(),
          color: color),
    );
    if (result != null && mounted) {
      setState(() {
        _autorCtrl.text = result['nombre']!;
        _autorId        = result['id']!;
      });
    }
  }

  Widget _campo(TextEditingController ctrl, String label,
      {String? hint, TextInputType? keyboardType}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint ?? label, labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10)),
      );

  // Campo traductor/ilustrador con selector del catálogo de autores
  Widget _campoConGenero(TextEditingController ctrl, String label, String generoKey) {
    final esTraductor = generoKey == '_traductorGenero';
    final currentId     = esTraductor ? _traductorId     : _ilustradorId;
    final currentGenero = esTraductor ? _traductorGenero : _ilustradorGenero;
    void setGenero(String v) => setState(() {
      if (esTraductor) _traductorGenero = v; else _ilustradorGenero = v;
    });
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: label,
            labelText: currentId.isNotEmpty ? '$label (vinculado ✓)' : label,
            labelStyle: TextStyle(
              color: currentId.isNotEmpty ? const Color(0xFF10B981) : Colors.grey,
              fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10)),
          onChanged: (_) {
            if (currentId.isNotEmpty) setState(() {
              if (esTraductor) _traductorId = ''; else _ilustradorId = '';
            });
          },
        ),
      ),
      _GeneroChip(label: 'F', selected: currentGenero == 'f',
          onTap: () => setGenero(currentGenero == 'f' ? '' : 'f')),
      const SizedBox(width: 4),
      IconButton(
        tooltip: 'Seleccionar de la lista de autores',
        icon: Icon(Icons.person_search_rounded, size: 20,
            color: currentId.isNotEmpty ? const Color(0xFF10B981) : Colors.grey),
        visualDensity: VisualDensity.compact,
        onPressed: () => _abrirSelectorCredito(label, esTraductor),
      ),
    ]);
  }

  Future<void> _abrirSelectorCredito(String label, bool esTraductor) async {
    final snap = await FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('autores').orderBy('nombre').limit(300).get();
    if (!mounted) return;
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AutorPickerSheet(
        docs: snap.docs.map((d) => {'id': d.id, 'nombre': d.data()['nombre'] as String? ?? ''}).toList(),
        color: const Color(0xFF6366F1)),
    );
    if (result != null && mounted) {
      setState(() {
        final nombre = result['nombre']!;
        final id     = result['id']!;
        if (esTraductor) { _traductorCtrl.text = nombre; _traductorId = id; }
        else             { _ilustradorCtrl.text = nombre; _ilustradorId = id; }
      });
    }
  }

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
      'nombre':         _nombreCtrl.text.trim(),
      'titulo':         _nombreCtrl.text.trim(),      // alias canónico para web
      'slug':           _slugCtrl.text.trim(),
      'categoria':      _categoriaCtrl.text.trim(),
      'genero':         _categoriaCtrl.text.trim(),   // alias canónico para web
      'tag':            _tagCtrl.text.trim(),
      'imagen_url':     _imagenCtrl.text.trim(),
      'imagen':         _imagenCtrl.text.trim(),      // alias canónico para web
      'precio':         _precioCtrl.text.trim(),
      'precio_digital': _precioDigCtrl.text.trim(),
      'stripe_link':    _stripeLinkCtrl.text.trim(),
      'payment_link':   _stripeLinkCtrl.text.trim(),  // alias canónico para checkout
      'descripcion':    _descCtrl.text.trim(),
      'activo':         _activo,
    };
    void opt(String k, String v) { if (v.isNotEmpty) data[k] = v; }
    opt('campo_autor',       _autorCtrl.text.trim());
    opt('autor',             _autorCtrl.text.trim());   // alias canónico para web
    if (_autorId.isNotEmpty) data['campo_autor_id'] = _autorId;
    opt('campo_traductor',        _traductorCtrl.text.trim());
    opt('traductor',              _traductorCtrl.text.trim());
    if (_traductorId.isNotEmpty) data['campo_traductor_id'] = _traductorId;
    if (_traductorGenero.isNotEmpty) data['campo_traductor_genero'] = _traductorGenero;
    opt('campo_ilustrador',       _ilustradorCtrl.text.trim());
    opt('ilustrador',             _ilustradorCtrl.text.trim());
    if (_ilustradorId.isNotEmpty) data['campo_ilustrador_id'] = _ilustradorId;
    if (_ilustradorGenero.isNotEmpty) data['campo_ilustrador_genero'] = _ilustradorGenero;
    opt('campo_coleccion',   _coleccionCtrl.text.trim());
    opt('coleccion',         _coleccionCtrl.text.trim()); // alias canónico para web
    opt('campo_isbn',        _isbnCtrl.text.trim());
    opt('campo_paginas',     _paginasCtrl.text.trim());
    opt('campo_formato',     _formatoCtrl.text.trim());
    opt('campo_peso',        _pesoCtrl.text.trim());
    opt('peso',              _pesoCtrl.text.trim());    // alias raíz para web y envío
    opt('campo_dimensiones', _dimensionesCtrl.text.trim());
    opt('campo_mes',         _mesCtrl.text.trim());
    opt('campo_dia',         _diaCtrl.text.trim());
    data['campo_anio'] = _anio.toString();
    data['preventa']   = _preventa;
    if (_preventa) {
      final envioLejano = _preventaEnvioCtrl.text.trim();
      if (envioLejano.isNotEmpty) {
        data['preventa_envio_lejano'] = envioLejano;
      } else {
        data['preventa_envio_lejano'] = FieldValue.delete();
      }
    } else {
      data['preventa_envio_lejano'] = FieldValue.delete();
    }
    if (docId == null) data['guardado_en'] = FieldValue.serverTimestamp();
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

class _GeneroChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GeneroChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6366F1) : Colors.transparent,
          border: Border.all(color: selected ? const Color(0xFF6366F1) : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.grey)),
      ),
    );
  }
}

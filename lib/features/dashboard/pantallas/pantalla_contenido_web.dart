import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';
import 'tab_seo_web.dart';
import 'tab_config_web.dart';
import 'pantalla_items_seccion.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA PRINCIPAL — Gestión de Contenido Web
// ═════════════════════════════════════════════════════════════════════════════

class PantallaContenidoWeb extends StatefulWidget {
  final String empresaId;
  const PantallaContenidoWeb({super.key, required this.empresaId});

  @override
  State<PantallaContenidoWeb> createState() => _PantallaContenidoWebState();
}

class _PantallaContenidoWebState extends State<PantallaContenidoWeb>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final ContenidoWebService _svc = ContenidoWebService();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Contenido Web'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.web, size: 17), text: 'Secciones'),
            Tab(icon: Icon(Icons.search, size: 17), text: 'SEO'),
            Tab(icon: Icon(Icons.settings, size: 17), text: 'Config'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _TabSecciones(empresaId: widget.empresaId, svc: _svc, color: color),
          TabSeoWeb(empresaId: widget.empresaId, svc: _svc),
          TabConfigWeb(empresaId: widget.empresaId, svc: _svc),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB SECCIONES (lógica existente extraída a clase separada)
// ═════════════════════════════════════════════════════════════════════════════

class _TabSecciones extends StatelessWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color color;

  const _TabSecciones({
    required this.empresaId,
    required this.svc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SeccionWeb>>(
      stream: svc.obtenerSecciones(empresaId),
      builder: (context, snap) {
        final secciones = snap.data ?? [];
        return Stack(children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: _buildHeader(secciones, color)),
              if (secciones.isEmpty)
                SliverToBoxAdapter(child: _buildVacio(context, color))
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _TarjetaSeccion(
                      seccion: secciones[i],
                      empresaId: empresaId,
                      svc: svc,
                      color: color,
                    ),
                    childCount: secciones.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'fab_nueva_seccion',
              onPressed: () => _abrirEditor(context, null),
              backgroundColor: color,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nueva sección'),
            ),
          ),
        ]);
      },
    );
  }

  Widget _buildHeader(List<SeccionWeb> secciones, Color color) {
    final activas = secciones.where((s) => s.activa).length;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.web, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tu web en tiempo real',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(height: 3),
            Text(
              secciones.isEmpty
                  ? 'Sin secciones — añade la primera'
                  : '$activas de ${secciones.length} secciones activas',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        )),
      ]),
    );
  }

  Widget _buildVacio(BuildContext context, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(children: [
          Icon(Icons.web_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Sin secciones todavía',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            'Añade secciones para que se muestren en tu web',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _abrirEditor(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Crear primera sección'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ]),
      ),
    );
  }


  void _abrirEditor(BuildContext context, SeccionWeb? seccion) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaEditorSeccion(
          empresaId: empresaId,
          seccion: seccion,
          svc: svc,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TARJETA de cada sección en la lista principal
// ═════════════════════════════════════════════════════════════════════════════

class _TarjetaSeccion extends StatelessWidget {
  final SeccionWeb seccion;
  final String empresaId;
  final ContenidoWebService svc;
  final Color color;

  const _TarjetaSeccion({
    required this.seccion,
    required this.empresaId,
    required this.svc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tipoColor = seccion.tipo.color;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
        border: seccion.activa
            ? Border.all(color: tipoColor.withValues(alpha: 0.2))
            : null,
      ),
      child: Column(
        children: [
          // ── Cabecera ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tipoColor.withValues(alpha: seccion.activa ? 0.12 : 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(seccion.tipo.icono,
                    color: seccion.activa ? tipoColor : Colors.grey, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(seccion.nombre,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: seccion.activa ? Colors.black87 : Colors.grey)),
                  Text(seccion.tipo.nombre,
                      style: TextStyle(color: tipoColor, fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ],
              )),
              // Toggle activo/inactivo
              Switch(
                value: seccion.activa,
                onChanged: (v) async {
                  try {
                    await svc.toggleSeccion(empresaId, seccion.id, v);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(v
                            ? '✅ "${seccion.nombre}" activada en la web'
                            : '⏸ "${seccion.nombre}" desactivada'),
                        backgroundColor: v ? Colors.green : Colors.orange,
                        duration: const Duration(seconds: 2),
                      ));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: Colors.red,
                      ));
                    }
                  }
                },
                activeThumbColor: tipoColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ]),
          ),

          // ── Preview del contenido ─────────────────────────────────────
          if (seccion.activa) ...[
            const Divider(height: 1),
            _buildPreview(context, tipoColor),
          ],

          // ── Botones de acción ─────────────────────────────────────────
          const Divider(height: 1),
          Row(children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () {
                  if (seccion.tipo == TipoSeccion.generico) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PantallaItemsSeccion(
                          empresaId: empresaId,
                          seccion: seccion,
                          svc: svc,
                        ),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PantallaEditorSeccion(
                          empresaId: empresaId,
                          seccion: seccion,
                          svc: svc,
                        ),
                      ),
                    );
                  }
                },
                icon: Icon(Icons.edit, size: 16, color: tipoColor),
                label: Text('Editar', style: TextStyle(color: tipoColor, fontSize: 13)),
              ),
            ),
            Container(width: 1, height: 36, color: Colors.grey[200]),
            Expanded(
              child: TextButton.icon(
                onPressed: () => _confirmarEliminar(context),
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                label: const Text('Eliminar',
                    style: TextStyle(color: Colors.red, fontSize: 13)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context, Color tipoColor) {
    final c = seccion.contenido;
    Widget content;

    switch (seccion.tipo) {
      case TipoSeccion.texto:
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (c.titulo.isNotEmpty)
            Text(c.titulo,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          if (c.texto.isNotEmpty)
            Text(c.texto,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          if (c.imagenUrl != null && c.imagenUrl!.isNotEmpty)
            const Row(children: [
              Icon(Icons.image, size: 14, color: Colors.grey),
              SizedBox(width: 4),
              Text('Imagen adjunta', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ]),
        ]);

      case TipoSeccion.carta:
        final items = c.itemsCarta;
        content = items.isEmpty
            ? Text('Sin platos — pulsa Editar para añadir',
                style: TextStyle(color: Colors.grey[500], fontSize: 12))
            : Wrap(
                spacing: 6, runSpacing: 4,
                children: items.take(4).map((p) => Chip(
                  label: Text('${p.nombre} ${p.precio.toStringAsFixed(0)}€',
                      style: const TextStyle(fontSize: 11)),
                  backgroundColor: tipoColor.withValues(alpha: 0.08),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList()
                  ..addAll(items.length > 4
                      ? [Chip(
                          label: Text('+${items.length - 4} más',
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.grey[100],
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )]
                      : []),
              );

      case TipoSeccion.galeria:
        final imgs = c.imagenesGaleria;
        content = imgs.isEmpty
            ? Text('Sin fotos — pulsa Editar para añadir',
                style: TextStyle(color: Colors.grey[500], fontSize: 12))
            : Row(children: [
                ...imgs.take(4).map((img) => Container(
                  width: 52, height: 52,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                    image: DecorationImage(
                      image: NetworkImage(img.url),
                      fit: BoxFit.cover,
                    ),
                  ),
                )),
                if (imgs.length > 4)
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: tipoColor.withValues(alpha: 0.1),
                    ),
                    child: Center(child: Text('+${imgs.length - 4}',
                        style: TextStyle(color: tipoColor, fontWeight: FontWeight.bold))),
                  ),
              ]);

      case TipoSeccion.ofertas:
        final ofertas = c.ofertas.where((o) => o.activa).toList();
        content = ofertas.isEmpty
            ? Text('Sin ofertas activas — pulsa Editar para añadir',
                style: TextStyle(color: Colors.grey[500], fontSize: 12))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: ofertas.take(2).map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.local_offer, size: 14, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(o.titulo,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (o.precioOferta != null)
                      Text('${o.precioOferta!.toStringAsFixed(2)}€',
                          style: const TextStyle(color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                )).toList(),
              );

      case TipoSeccion.horarios:
        final hoy = [
          'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
        ][DateTime.now().weekday - 1];
        final horarioHoy = c.horarios.where((h) => h.dia == hoy).firstOrNull;
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (horarioHoy != null)
            Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: horarioHoy.cerrado ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                horarioHoy.cerrado
                    ? 'Hoy cerrado'
                    : 'Hoy: ${horarioHoy.apertura} – ${horarioHoy.cierre}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ]),
          Text('${c.horarios.length} días configurados',
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ]);

      case TipoSeccion.generico:
        final items = c.items;
        content = items.isEmpty
            ? Text('Sin items — pulsa Editar para añadir',
                style: TextStyle(color: Colors.grey[500], fontSize: 12))
            : Wrap(
                spacing: 6, runSpacing: 4,
                children: items.take(3).map((it) {
                  final nombre = it['nombre']?.toString() ?? '—';
                  final precio = it['precio'];
                  final label = precio != null ? '$nombre ${precio}€' : nombre;
                  return Chip(
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    backgroundColor: tipoColor.withValues(alpha: 0.08),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }).toList()
                  ..addAll(items.length > 3
                      ? [Chip(
                          label: Text('+${items.length - 3} más',
                              style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.grey[100],
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        )]
                      : []),
              );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: content,
    );
  }

  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        bool eliminando = false;
        return StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Eliminar sección'),
            ]),
            content: Text(
              '¿Eliminar "${seccion.nombre}"?\n\n'
              'El contenido desaparecerá de tu web inmediatamente y no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: eliminando ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: eliminando
                    ? null
                    : () async {
                        setDlg(() => eliminando = true);
                        try {
                          await svc.eliminarSeccion(empresaId, seccion.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('"${seccion.nombre}" eliminada'),
                                ]),
                                backgroundColor: Colors.red[700],
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          setDlg(() => eliminando = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text('❌ Error al eliminar: $e'),
                              backgroundColor: Colors.red,
                            ));
                          }
                        }
                      },
                child: eliminando
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Sí, eliminar'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA DE EDICIÓN — Formulario por tipo
// ═════════════════════════════════════════════════════════════════════════════

class PantallaEditorSeccion extends StatefulWidget {
  final String empresaId;
  final SeccionWeb? seccion; // null = nueva
  final ContenidoWebService svc;

  const PantallaEditorSeccion({
    super.key,
    required this.empresaId,
    required this.seccion,
    required this.svc,
  });

  @override
  State<PantallaEditorSeccion> createState() => _PantallaEditorSeccionState();
}

class _PantallaEditorSeccionState extends State<PantallaEditorSeccion> {
  late TipoSeccion _tipo;
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _idCtrl = TextEditingController(); // ID personalizado para genérico

  // ── Tipo TEXTO ────────────────────────────────────────────────────────────
  final _tituloCtrl = TextEditingController();
  final _textoCtrl  = TextEditingController();
  String? _imagenUrl;
  bool _subiendoImagen = false;

  // ── Tipo CARTA ────────────────────────────────────────────────────────────
  List<ItemCarta> _carta = [];

  // ── Tipo GALERIA ──────────────────────────────────────────────────────────
  List<ItemGaleria> _galeria = [];

  // ── Tipo OFERTAS ──────────────────────────────────────────────────────────
  List<ItemOferta> _ofertas = [];

  // ── Tipo HORARIOS ─────────────────────────────────────────────────────────
  List<ItemHorario> _horarios = [];

  bool _guardando = false;

  bool get _esNueva => widget.seccion == null;

  @override
  void initState() {
    super.initState();
    if (widget.seccion != null) {
      final s = widget.seccion!;
      _tipo = s.tipo;
      _nombreCtrl.text = s.nombre;
      _tituloCtrl.text = s.contenido.titulo;
      _textoCtrl.text  = s.contenido.texto;
      _imagenUrl = s.contenido.imagenUrl;
      _carta   = List.from(s.contenido.itemsCarta);
      _galeria = List.from(s.contenido.imagenesGaleria);
      _ofertas = List.from(s.contenido.ofertas);
      _horarios = s.contenido.horarios.isEmpty
          ? ItemHorario.porDefecto()
          : List.from(s.contenido.horarios);
    } else {
      _tipo = TipoSeccion.texto;
      _nombreCtrl.text = TipoSeccion.texto.nombre; // auto-fill inicial
      _horarios = ItemHorario.porDefecto();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose(); _tituloCtrl.dispose(); _textoCtrl.dispose(); _idCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    final tipoColor = _tipo.color;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(_esNueva ? 'Nueva sección' : 'Editar sección'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _guardando ? null : () => _guardar(context),
            child: Text(
              _guardando ? 'Guardando...' : 'Guardar',
              style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Selector de tipo (solo en nuevas secciones) ───────────────
            if (_esNueva) ...[
              _buildCard(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('¿Qué tipo de sección quieres añadir?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: TipoSeccion.values.map((t) {
                      final sel = t == _tipo;
                      return GestureDetector(
                        onTap: () => setState(() {
                          _tipo = t;
                          // Auto-rellenar nombre con el del tipo
                          _nombreCtrl.text = t.nombre;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: sel
                                ? t.color
                                : t.color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? t.color
                                  : t.color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(t.icono,
                                color: sel ? Colors.white : t.color, size: 16),
                            const SizedBox(width: 6),
                            Text(t.nombre,
                                style: TextStyle(
                                    color: sel ? Colors.white : t.color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  // Nombre editable (pre-rellenado con el tipo)
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la sección',
                      hintText: 'Se rellena automáticamente con el tipo',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.label_outline, color: _tipo.color),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Escribe un nombre' : null,
                  ),
                ],
              )),
              const SizedBox(height: 12),
            ] else ...[
              // Edición — mostrar tipo + nombre editable
              _buildCard(child: Column(children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tipoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_tipo.icono, color: tipoColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_tipo.nombre,
                          style: TextStyle(color: tipoColor,
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const Text('Tipo fijo — no se puede cambiar',
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  )),
                ]),
                const Divider(height: 16),
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la sección',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.label_outline),
                    isDense: true,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Escribe un nombre' : null,
                ),
              ])),
              const SizedBox(height: 12),
            ],

            // ── Editor específico por tipo ─────────────────────────────────
            _buildEditorPorTipo(context, tipoColor),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorPorTipo(BuildContext context, Color tipoColor) {
    switch (_tipo) {
      case TipoSeccion.texto:    return _buildEditorTexto(context, tipoColor);
      case TipoSeccion.carta:    return _buildEditorCarta(context, tipoColor);
      case TipoSeccion.galeria:  return _buildEditorGaleria(context, tipoColor);
      case TipoSeccion.ofertas:  return _buildEditorOfertas(context, tipoColor);
      case TipoSeccion.horarios: return _buildEditorHorarios(tipoColor);
      case TipoSeccion.generico: return _buildEditorGenericoInfo(tipoColor);
    }
  }

  // ── INFO GENÉRICO (solo informativo — la edición real es en PantallaItemsSeccion)
  Widget _buildEditorGenericoInfo(Color c) {
    return Column(children: [
      _buildCard(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, color: c, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text(
              'Sección genérica (Data-Fluix)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            )),
          ]),
          const SizedBox(height: 10),
          if (_esNueva) ...[
            TextFormField(
              controller: _idCtrl,
              decoration: InputDecoration(
                labelText: 'ID de la sección (slug)',
                hintText: 'ej: carta_entrantes, nuestros_vinos',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag, color: c),
                helperText: 'Este ID se usará en data-fluix-seccion="..."',
                helperMaxLines: 2,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
              ],
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Escribe un ID (solo minúsculas y _)' : null,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _esNueva
                ? 'Guarda esta sección y después pulsa "Editar" en la tarjeta para gestionar los items.'
                : 'Pulsa "Editar" en la tarjeta para gestionar los items.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Los items se sincronizan en tiempo real con la web del cliente '
            'mediante los atributos data-fluix-*.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      )),
    ]);
  }

  // ── EDITOR TEXTO ──────────────────────────────────────────────────────────
  Widget _buildEditorTexto(BuildContext context, Color c) {
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _tituloCtrl,
          decoration: const InputDecoration(
            labelText: 'Título',
            border: InputBorder.none,
          ),
        ),
        const Divider(height: 1),
        TextFormField(
          controller: _textoCtrl,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Texto / descripción',
            border: InputBorder.none,
            alignLabelWithHint: true,
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 8),
        // Imagen
        if (_imagenUrl != null && _imagenUrl!.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(_imagenUrl!, height: 160, width: double.infinity,
                fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextButton.icon(
              onPressed: () => _subirImagen(context, 'texto'),
              icon: Icon(Icons.swap_horiz, color: c),
              label: Text('Cambiar imagen', style: TextStyle(color: c)),
            )),
            TextButton.icon(
              onPressed: () => setState(() => _imagenUrl = null),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Quitar', style: TextStyle(color: Colors.red)),
            ),
          ]),
        ] else
          OutlinedButton.icon(
            onPressed: _subiendoImagen ? null : () => _subirImagen(context, 'texto'),
            icon: _subiendoImagen
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.add_photo_alternate, color: c),
            label: Text(_subiendoImagen ? 'Subiendo...' : 'Añadir imagen',
                style: TextStyle(color: c)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: c.withValues(alpha: 0.4))),
          ),
      ],
    ));
  }

  // ── EDITOR CARTA ──────────────────────────────────────────────────────────
  Widget _buildEditorCarta(BuildContext context, Color c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._carta.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return _buildCard(
            child: Column(children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: item.imagenUrl != null
                        ? null : c.withValues(alpha: 0.1),
                    image: item.imagenUrl != null
                        ? DecorationImage(
                            image: NetworkImage(item.imagenUrl!),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: item.imagenUrl == null
                      ? Icon(Icons.restaurant, color: c, size: 20)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nombre.isEmpty ? 'Nuevo plato' : item.nombre,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${item.precio.toStringAsFixed(2)}€',
                        style: TextStyle(color: c, fontWeight: FontWeight.w600)),
                  ],
                )),
                Switch(
                  value: item.disponible,
                  onChanged: (v) => setState(() {
                    _carta[i] = item.copyWith(disponible: v);
                  }),
                  activeThumbColor: c,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _editarItemCarta(context, i, c),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _carta.removeAt(i)),
                ),
              ]),
              if (!item.disponible)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('No disponible temporalmente',
                      style: TextStyle(color: Colors.orange, fontSize: 11)),
                ),
            ]),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _editarItemCarta(context, null, c),
            icon: Icon(Icons.add, color: c),
            label: Text('Añadir plato', style: TextStyle(color: c)),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: c.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ],
    );
  }

  // ── EDITOR GALERÍA ────────────────────────────────────────────────────────
  Widget _buildEditorGaleria(BuildContext context, Color c) {
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fotos de la galería',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        Text('Las fotos aparecen en tu web en tiempo real',
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
          ),
          itemCount: _galeria.length + 1,
          itemBuilder: (ctx, i) {
            if (i == _galeria.length) {
              // Botón añadir
              return GestureDetector(
                onTap: _subiendoImagen ? null : () => _subirFotoGaleria(context, c),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: c.withValues(alpha: 0.3), style: BorderStyle.solid),
                  ),
                  child: _subiendoImagen
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.add_photo_alternate, color: c, size: 28),
                          const SizedBox(height: 4),
                          Text('Añadir', style: TextStyle(color: c, fontSize: 11)),
                        ]),
                ),
              );
            }
            final img = _galeria[i];
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(img.url, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _galeria.removeAt(i)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text('${_galeria.length} foto(s)',
            style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    ));
  }

  // ── EDITOR OFERTAS ────────────────────────────────────────────────────────
  Widget _buildEditorOfertas(BuildContext context, Color c) {
    return Column(
      children: [
        ..._ofertas.asMap().entries.map((entry) {
          final i = entry.key;
          final o = entry.value;
          return _buildCard(child: Column(
            children: [
              Row(children: [
                if (o.imagenUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(o.imagenUrl!,
                        width: 56, height: 56, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.local_offer, color: c, size: 28),
                  ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.titulo.isEmpty ? 'Nueva oferta' : o.titulo,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Row(children: [
                      if (o.precioOriginal != null)
                        Text('${o.precioOriginal!.toStringAsFixed(2)}€ ',
                            style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey, fontSize: 12)),
                      if (o.precioOferta != null)
                        Text('${o.precioOferta!.toStringAsFixed(2)}€',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  ],
                )),
                Switch(
                  value: o.activa,
                  onChanged: (v) => setState(() {
                    _ofertas[i] = o.copyWith(activa: v);
                  }),
                  activeThumbColor: c,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _editarOferta(context, i, c),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _ofertas.removeAt(i)),
                ),
              ]),
            ],
          ));
        }),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _editarOferta(context, null, c),
            icon: Icon(Icons.add, color: c),
            label: Text('Añadir oferta', style: TextStyle(color: c)),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: c.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ],
    );
  }

  // ── EDITOR HORARIOS ───────────────────────────────────────────────────────
  Widget _buildEditorHorarios(Color c) {
    return _buildCard(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Horarios de apertura',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 12),
        ..._horarios.asMap().entries.map((entry) {
          final i = entry.key;
          final h = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              SizedBox(width: 84,
                child: Text(h.dia,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              if (h.cerrado)
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Cerrado',
                      style: TextStyle(color: Colors.red, fontSize: 12)),
                ))
              else ...[
                Expanded(child: GestureDetector(
                  onTap: () => _seleccionarHora(i, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(h.apertura,
                        style: TextStyle(color: c, fontWeight: FontWeight.w600,
                            fontSize: 13), textAlign: TextAlign.center),
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: TextStyle(color: Colors.grey[400])),
                ),
                Expanded(child: GestureDetector(
                  onTap: () => _seleccionarHora(i, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(h.cierre,
                        style: TextStyle(color: c, fontWeight: FontWeight.w600,
                            fontSize: 13), textAlign: TextAlign.center),
                  ),
                )),
              ],
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => setState(() {
                  _horarios[i] = h.copyWith(cerrado: !h.cerrado);
                }),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: h.cerrado
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    h.cerrado ? Icons.lock_open : Icons.lock,
                    color: h.cerrado ? Colors.green : Colors.red,
                    size: 18,
                  ),
                ),
              ),
            ]),
          );
        }),
      ],
    ));
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Future<void> _seleccionarHora(int idx, bool esApertura) async {
    final h = _horarios[idx];
    final parts = (esApertura ? h.apertura : h.cierre).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: int.tryParse(parts[1]) ?? 0,
      ),
    );
    if (picked == null) return;
    final str = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      _horarios[idx] = esApertura
          ? h.copyWith(apertura: str)
          : h.copyWith(cierre: str);
    });
  }

  Future<void> _subirImagen(BuildContext context, String carpeta) async {
    setState(() => _subiendoImagen = true);
    final url = await widget.svc.subirImagenDesdeGaleria(widget.empresaId, carpeta);
    if (mounted) {
      setState(() { _imagenUrl = url; _subiendoImagen = false; });
    }
  }

  Future<void> _subirFotoGaleria(BuildContext context, Color c) async {
    setState(() => _subiendoImagen = true);
    final url = await widget.svc.subirImagenDesdeGaleria(
        widget.empresaId, 'galeria');
    if (url != null && mounted) {
      setState(() {
        _galeria.add(ItemGaleria(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          url: url,
        ));
      });
    }
    if (mounted) setState(() => _subiendoImagen = false);
  }

  void _editarItemCarta(BuildContext context, int? idx, Color c) {
    final item        = idx != null ? _carta[idx] : null;
    final nombreCtrl  = TextEditingController(text: item?.nombre ?? '');
    final descCtrl    = TextEditingController(text: item?.descripcion ?? '');
    final precioCtrl  = TextEditingController(
        text: item != null ? item.precio.toStringAsFixed(2) : '');
    final catCtrl     = TextEditingController(text: item?.categoria ?? 'General');

    // Estado local del modal (imagen + spinner)
    String? imagenLocal = item?.imagenUrl;
    bool   subiendoImg  = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {

          Future<void> subirImg() async {
            setModalState(() => subiendoImg = true);
            final url = await widget.svc.subirImagenDesdeGaleria(
                widget.empresaId, 'carta/${widget.seccion?.id ?? 'items'}');
            if (url != null) imagenLocal = url;
            setModalState(() => subiendoImg = false);
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                left: 20, right: 20, top: 20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                // Handle
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),

                Text(idx == null ? 'Nuevo producto' : 'Editar producto',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),

                // ── IMAGEN ───────────────────────────────────────────────
                GestureDetector(
                  onTap: subiendoImg ? null : subirImg,
                  child: Container(
                    width: double.infinity, height: 160,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: imagenLocal != null
                              ? Colors.transparent
                              : c.withValues(alpha: 0.3),
                          style: BorderStyle.solid),
                      image: imagenLocal != null
                          ? DecorationImage(
                              image: NetworkImage(imagenLocal!),
                              fit: BoxFit.cover)
                          : null,
                    ),
                    child: subiendoImg
                        ? Center(child: CircularProgressIndicator(color: c))
                        : imagenLocal == null
                            ? Column(mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_outlined,
                                      color: c, size: 36),
                                  const SizedBox(height: 6),
                                  Text('Toca para añadir imagen\ndesde la galería',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: c, fontSize: 13)),
                                ])
                            : Align(
                                alignment: Alignment.topRight,
                                child: GestureDetector(
                                  onTap: () => setModalState(() => imagenLocal = null),
                                  child: Container(
                                    margin: const EdgeInsets.all(8),
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                  ),
                ),
                if (imagenLocal != null) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: subiendoImg ? null : subirImg,
                    child: Text('Cambiar imagen',
                        style: TextStyle(color: c, fontSize: 12,
                            decoration: TextDecoration.underline)),
                  ),
                ],
                const SizedBox(height: 14),

                // ── CAMPOS ───────────────────────────────────────────────
                TextField(controller: nombreCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nombre', border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(
                      controller: precioCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                          labelText: 'Precio (€)',
                          border: OutlineInputBorder()))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(
                      controller: catCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Categoría',
                          border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 16),

                // ── BOTÓN GUARDAR ────────────────────────────────────────
                SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final nombre = nombreCtrl.text.trim();
                      if (nombre.isEmpty) return;
                      final precio = double.tryParse(
                          precioCtrl.text.replaceAll(',', '.')) ?? 0.0;
                      final nuevo = ItemCarta(
                        id:          item?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        nombre:      nombre,
                        descripcion: descCtrl.text.trim(),
                        precio:      precio,
                        categoria:   catCtrl.text.trim().isEmpty
                            ? 'General' : catCtrl.text.trim(),
                        imagenUrl:   imagenLocal,
                        disponible:  item?.disponible ?? true,
                      );
                      setState(() {
                        if (idx != null) _carta[idx] = nuevo;
                        else _carta.add(nuevo);
                      });
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: c,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: Text(idx == null ? 'Añadir' : 'Guardar cambios'),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  void _editarOferta(BuildContext context, int? idx, Color c) {
    final o = idx != null ? _ofertas[idx] : null;
    final tituloCtrl = TextEditingController(text: o?.titulo ?? '');
    final descCtrl   = TextEditingController(text: o?.descripcion ?? '');
    final precOrigCtrl = TextEditingController(
        text: o?.precioOriginal?.toStringAsFixed(2) ?? '');
    final precOfCtrl = TextEditingController(
        text: o?.precioOferta?.toStringAsFixed(2) ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20, right: 20, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(idx == null ? 'Nueva oferta' : 'Editar oferta',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          TextField(controller: tituloCtrl,
              decoration: const InputDecoration(labelText: 'Título de la oferta',
                  border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: descCtrl, maxLines: 2,
              decoration: const InputDecoration(labelText: 'Descripción',
                  border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: precOrigCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                    labelText: 'Precio original (€)',
                    border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: precOfCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                    labelText: 'Precio oferta (€)',
                    border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final titulo = tituloCtrl.text.trim();
                if (titulo.isEmpty) return;
                final nuevo = ItemOferta(
                  id: o?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  titulo: titulo,
                  descripcion: descCtrl.text.trim(),
                  precioOriginal: double.tryParse(
                      precOrigCtrl.text.replaceAll(',', '.')),
                  precioOferta: double.tryParse(
                      precOfCtrl.text.replaceAll(',', '.')),
                  imagenUrl: o?.imagenUrl,
                  activa: o?.activa ?? true,
                );
                setState(() {
                  if (idx != null) _ofertas[idx] = nuevo;
                  else _ofertas.add(nuevo);
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: c, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(idx == null ? 'Añadir' : 'Guardar cambios'),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Future<void> _guardar(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final contenido = ContenidoSeccion(
      titulo: _tituloCtrl.text.trim(),
      texto:  _textoCtrl.text.trim(),
      imagenUrl: _imagenUrl,
      itemsCarta: _carta,
      imagenesGaleria: _galeria,
      ofertas: _ofertas,
      horarios: _horarios,
      items: widget.seccion?.contenido.items ?? [],
    );

    // Para genéricos nuevos, usar el ID personalizado
    String seccionId = widget.seccion?.id ?? '';
    if (_esNueva && _tipo == TipoSeccion.generico && _idCtrl.text.trim().isNotEmpty) {
      seccionId = _idCtrl.text.trim();
    }

    final seccion = SeccionWeb(
      id: seccionId,
      nombre: _nombreCtrl.text.trim(),
      descripcion: '',
      activa: widget.seccion?.activa ?? true,
      tipo: _tipo,
      contenido: contenido,
      fechaCreacion: widget.seccion?.fechaCreacion ?? DateTime.now(),
      fechaActualizacion: DateTime.now(),
    );

    try {
      await widget.svc.guardarSeccion(widget.empresaId, seccion);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('¡Guardado! Los cambios ya se ven en tu web'),
          ]),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ));
        Navigator.pop(context);
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

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}




















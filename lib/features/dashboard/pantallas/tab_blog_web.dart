import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB BLOG / NOTICIAS
// ═════════════════════════════════════════════════════════════════════════════

class TabBlogWeb extends StatelessWidget {
  final String empresaId;
  final ContenidoWebService svc;

  const TabBlogWeb({super.key, required this.empresaId, required this.svc});

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    return StreamBuilder<List<EntradaBlog>>(
      stream: svc.obtenerBlog(empresaId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final entradas = snap.data ?? [];

        return Stack(
          children: [
            entradas.isEmpty
                ? _buildVacio(context, color)
                : _buildLista(context, entradas, color),
            Positioned(
              right: 16, bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_nueva_entrada',
                onPressed: () => _abrirEditor(context, null, color),
                backgroundColor: color,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.edit_note),
                label: const Text('Nueva entrada'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVacio(BuildContext context, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Sin entradas de blog',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Crea noticias y artículos que aparecerán en tu web',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _abrirEditor(context, null, color),
            icon: const Icon(Icons.add),
            label: const Text('Crear primera entrada'),
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(
      BuildContext context, List<EntradaBlog> entradas, Color color) {
    final publicadas = entradas.where((e) => e.publicada).length;
    return Column(
      children: [
        // Stats bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            _kpi('Publicadas', '$publicadas', Colors.green),
            _divV(),
            _kpi('Borradores', '${entradas.length - publicadas}', Colors.orange),
            _divV(),
            _kpi('Total', '${entradas.length}', color),
          ]),
        ),
        const Divider(height: 1),
        // Lista
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: entradas.length,
            itemBuilder: (ctx, i) =>
                _TarjetaEntrada(
                  entrada: entradas[i],
                  color: color,
                  onTap: () => _abrirEditor(context, entradas[i], color),
                  onToggle: (v) =>
                      svc.togglePublicarBlog(empresaId, entradas[i].id, v),
                  onEliminar: () =>
                      svc.eliminarEntradaBlog(empresaId, entradas[i].id),
                ),
          ),
        ),
      ],
    );
  }

  Widget _kpi(String label, String valor, Color c) => Expanded(
        child: Column(children: [
          Text(valor,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: c)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      );

  Widget _divV() => Container(width: 1, height: 32, color: Colors.grey[200]);

  void _abrirEditor(BuildContext context, EntradaBlog? entrada, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PantallaEditorBlog(
          empresaId: empresaId,
          svc: svc,
          entrada: entrada,
        ),
      ),
    );
  }
}

// ── Tarjeta de entrada blog ───────────────────────────────────────────────────

class _TarjetaEntrada extends StatelessWidget {
  final EntradaBlog entrada;
  final Color color;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEliminar;

  const _TarjetaEntrada({
    required this.entrada,
    required this.color,
    required this.onTap,
    required this.onToggle,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: entrada.publicada
            ? Border.all(color: Colors.green.withValues(alpha: 0.2))
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          // Imagen + contenido
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: entrada.imagenUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      entrada.imagenUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagenFallback(),
                    ),
                  )
                : _imagenFallback(),
            title: Text(
              entrada.titulo.isEmpty ? 'Sin título' : entrada.titulo,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entrada.resumen.isNotEmpty)
                  Text(
                    entrada.resumen,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                const SizedBox(height: 4),
                Row(children: [
                  Text(
                    entrada.fechaFormateada,
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                  if (entrada.autor.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text('· ${entrada.autor}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                  ],
                  const SizedBox(width: 8),
                  Text('· ${entrada.tiempoLecturaMin} min lectura',
                      style:
                          TextStyle(color: Colors.grey[400], fontSize: 10)),
                  if (entrada.etiquetas.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Wrap(
                      spacing: 4,
                      children: entrada.etiquetas.take(2).map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(t,
                                style: TextStyle(
                                    fontSize: 9,
                                    color: color)),
                          )).toList(),
                    ),
                  ],
                ]),
              ],
            ),
            trailing: Switch(
              value: entrada.publicada,
              onChanged: onToggle,
              activeThumbColor: Colors.green,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onTap: onTap,
          ),
          const Divider(height: 1),
          Row(children: [
            Expanded(
              child: TextButton.icon(
                onPressed: onTap,
                icon: Icon(Icons.edit, size: 15, color: color),
                label: Text('Editar', style: TextStyle(color: color, fontSize: 12)),
              ),
            ),
            Container(width: 1, height: 30, color: Colors.grey[200]),
            Expanded(
              child: TextButton.icon(
                onPressed: () => _confirmarEliminar(context),
                icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                label: const Text('Eliminar',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _imagenFallback() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.article, color: color, size: 24),
      );

  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar entrada'),
        content: Text(
            '¿Eliminar "${entrada.titulo}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onEliminar();
            },
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// EDITOR DE ENTRADA BLOG con Markdown simple
// ═════════════════════════════════════════════════════════════════════════════

class _PantallaEditorBlog extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final EntradaBlog? entrada;

  const _PantallaEditorBlog(
      {required this.empresaId, required this.svc, this.entrada});

  @override
  State<_PantallaEditorBlog> createState() => _PantallaEditorBlogState();
}

class _PantallaEditorBlogState extends State<_PantallaEditorBlog> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _resumenCtrl = TextEditingController();
  final _contenidoCtrl = TextEditingController();
  final _autorCtrl = TextEditingController();
  final _etiquetasCtrl = TextEditingController();

  String? _imagenUrl;
  bool _publicada = false;
  bool _preview = false;
  bool _guardando = false;
  bool _subiendoImagen = false;

  @override
  void initState() {
    super.initState();
    if (widget.entrada != null) {
      final e = widget.entrada!;
      _tituloCtrl.text = e.titulo;
      _resumenCtrl.text = e.resumen;
      _contenidoCtrl.text = e.contenido;
      _autorCtrl.text = e.autor;
      _etiquetasCtrl.text = e.etiquetas.join(', ');
      _imagenUrl = e.imagenUrl;
      _publicada = e.publicada;
    }
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _resumenCtrl.dispose();
    _contenidoCtrl.dispose();
    _autorCtrl.dispose();
    _etiquetasCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(widget.entrada == null ? 'Nueva entrada' : 'Editar entrada'),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Toggle preview
          IconButton(
            icon: Icon(_preview ? Icons.edit : Icons.visibility),
            tooltip: _preview ? 'Editar' : 'Vista previa',
            onPressed: () => setState(() => _preview = !_preview),
          ),
          TextButton(
            onPressed: _guardando ? null : () => _guardar(context),
            child: Text(
              _guardando ? '...' : 'Guardar',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _preview
          ? _buildPreview()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Imagen destacada
                  _buildImagenDestacada(color),
                  const SizedBox(height: 12),

                  // Datos básicos
                  _buildCard(child: Column(children: [
                    TextFormField(
                      controller: _tituloCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Título de la entrada *',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.title)),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Obligatorio' : null,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Divider(height: 1),
                    TextFormField(
                      controller: _resumenCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Resumen / extracto',
                          border: InputBorder.none,
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.short_text)),
                    ),
                    const Divider(height: 1),
                    TextFormField(
                      controller: _autorCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Autor',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.person_outline)),
                    ),
                    const Divider(height: 1),
                    TextFormField(
                      controller: _etiquetasCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Etiquetas (separadas por coma)',
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.label_outline)),
                    ),
                  ])),
                  const SizedBox(height: 12),

                  // Editor de contenido con toolbar Markdown
                  _buildEditorContenido(color),
                  const SizedBox(height: 12),

                  // Publicar switch
                  _buildCard(
                    child: SwitchListTile(
                      value: _publicada,
                      onChanged: (v) => setState(() => _publicada = v),
                      activeThumbColor: Colors.green,
                      title: Text(
                        _publicada ? '✅ Publicada en tu web' : '📝 Borrador (no visible)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        _publicada
                            ? 'Los visitantes pueden leer esta entrada'
                            : 'Solo tú puedes ver este borrador',
                        style: const TextStyle(fontSize: 11),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildImagenDestacada(Color color) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Imagen destacada',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_imagenUrl != null && _imagenUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(_imagenUrl!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: TextButton.icon(
                onPressed: () => _subirImagen(),
                icon: Icon(Icons.swap_horiz, color: color),
                label: Text('Cambiar', style: TextStyle(color: color)),
              )),
              TextButton.icon(
                onPressed: () => setState(() => _imagenUrl = null),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label:
                    const Text('Quitar', style: TextStyle(color: Colors.red)),
              ),
            ]),
          ] else
            OutlinedButton.icon(
              onPressed: _subiendoImagen ? null : _subirImagen,
              icon: _subiendoImagen
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.add_photo_alternate, color: color),
              label: Text(
                  _subiendoImagen ? 'Subiendo...' : 'Añadir imagen destacada',
                  style: TextStyle(color: color)),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color.withValues(alpha: 0.4))),
            ),
        ],
      ),
    );
  }

  Widget _buildEditorContenido(Color color) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('Contenido',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _preview = true),
              icon: Icon(Icons.visibility_outlined, size: 14, color: color),
              label: Text('Preview', style: TextStyle(color: color, fontSize: 12)),
            ),
          ]),
          // Toolbar Markdown
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _toolbarBtn('H1', '# '),
                _toolbarBtn('H2', '## '),
                _toolbarBtn('B', '**texto**'),
                _toolbarBtn('I', '_texto_'),
                _toolbarBtn('🔗', '[texto](url)'),
                _toolbarBtn('•', '\n- '),
                _toolbarBtn('—', '\n---\n'),
                _toolbarBtn('💬', '\n> '),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 6),
          TextFormField(
            controller: _contenidoCtrl,
            maxLines: null,
            minLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '# Escribe tu artículo aquí...\n\nSoporta Markdown básico:\n**negrita**, _cursiva_, # Encabezado\n\n[enlace](url) · - lista',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _toolbarBtn(String label, String insertar) => InkWell(
        onTap: () {
          final ctrl = _contenidoCtrl;
          final sel = ctrl.selection;
          if (!sel.isValid) {
            ctrl.text = ctrl.text + insertar;
            ctrl.selection = TextSelection.collapsed(
                offset: ctrl.text.length);
          } else {
            final text = ctrl.text;
            final antes = text.substring(0, sel.start);
            final despues = text.substring(sel.end);
            ctrl.text = antes + insertar + despues;
            ctrl.selection = TextSelection.collapsed(
                offset: sel.start + insertar.length);
          }
          setState(() {});
        },
        child: Container(
          margin: const EdgeInsets.only(right: 4, bottom: 4),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      );

  Widget _buildPreview() {
    final lines = _contenidoCtrl.text.split('\n');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_imagenUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(_imagenUrl!,
                  width: double.infinity, height: 200, fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          Text(_tituloCtrl.text.isEmpty ? 'Sin título' : _tituloCtrl.text,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold)),
          if (_autorCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Por ${_autorCtrl.text}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
          const SizedBox(height: 16),
          ...lines.map((line) => _renderLinea(line)),
        ],
      ),
    );
  }

  Widget _renderLinea(String line) {
    if (line.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(line.substring(2),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      );
    }
    if (line.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(line.substring(3),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      );
    }
    if (line.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Text(line.substring(4),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );
    }
    if (line.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: const Border(left: BorderSide(color: Colors.blue, width: 3)),
          color: Colors.blue.withValues(alpha: 0.05),
        ),
        child: Text(line.substring(2),
            style: const TextStyle(
                fontStyle: FontStyle.italic, color: Colors.blue)),
      );
    }
    if (line.startsWith('- ') || line.startsWith('* ')) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('• ',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: _renderInline(line.substring(2))),
        ]),
      );
    }
    if (line.trim() == '---' || line.trim() == '___') {
      return const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider());
    }
    if (line.isEmpty) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: _renderInline(line),
    );
  }

  Widget _renderInline(String text) {
    // Bold **...**
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|_(.+?)_|\[(.+?)\]\((.+?)\)');
    int last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      if (m.group(1) != null) {
        spans.add(TextSpan(
            text: m.group(1),
            style: const TextStyle(fontWeight: FontWeight.bold)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
            text: m.group(2),
            style: const TextStyle(fontStyle: FontStyle.italic)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
            text: m.group(3),
            style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline)));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return RichText(
        text: TextSpan(
            children: spans,
            style: const TextStyle(
                color: Colors.black87, fontSize: 14, height: 1.6)));
  }

  Future<void> _subirImagen() async {
    setState(() => _subiendoImagen = true);
    final url = await widget.svc
        .subirImagenDesdeGaleria(widget.empresaId, 'blog');
    if (mounted) setState(() {
      _imagenUrl = url;
      _subiendoImagen = false;
    });
  }

  Future<void> _guardar(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final etiquetas = _etiquetasCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final entrada = EntradaBlog(
      id: widget.entrada?.id ?? '',
      titulo: _tituloCtrl.text.trim(),
      resumen: _resumenCtrl.text.trim(),
      contenido: _contenidoCtrl.text,
      imagenUrl: _imagenUrl,
      publicada: _publicada,
      fechaPublicacion: widget.entrada?.fechaPublicacion ?? DateTime.now(),
      etiquetas: etiquetas,
      autor: _autorCtrl.text.trim(),
    );

    try {
      await widget.svc.guardarEntradaBlog(widget.empresaId, entrada);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('✅ Entrada guardada'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _buildCard({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: child,
      );
}


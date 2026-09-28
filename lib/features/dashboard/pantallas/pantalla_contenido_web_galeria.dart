part of 'pantalla_contenido_web.dart';

class _TabGaleriaWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Color color;

  const _TabGaleriaWeb({required this.empresaId, required this.svc, required this.color});

  @override
  State<_TabGaleriaWeb> createState() => _TabGaleriaWebState();
}

class _TabGaleriaWebState extends State<_TabGaleriaWeb> {
  List<Map<String, dynamic>> _imagenes = [];
  bool _cargando = false;
  bool _subiendo = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final imgs = await widget.svc.obtenerGaleria(widget.empresaId);
      if (mounted) setState(() { _imagenes = imgs; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _subirImagen() async {
    setState(() => _subiendo = true);
    try {
      final url = await widget.svc.subirImagenDesdeGaleria(widget.empresaId, 'web/galeria');
      if (url != null && mounted) {
        await widget.svc.agregarAGaleria(widget.empresaId, url);
        await _cargar();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.photo_library_rounded, color: widget.color, size: 18)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Galería', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
            Text('${_imagenes.length} imagen${_imagenes.length != 1 ? 'es' : ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ]),
          const Spacer(),
          FilledButton.icon(
            onPressed: _subiendo ? null : _subirImagen,
            icon: _subiendo
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_rounded, size: 16),
            label: const Text('Subir imagen', style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: widget.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            ),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(child: _cargando
          ? Center(child: CircularProgressIndicator(color: widget.color))
          : _imagenes.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 72, height: 72,
                      decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.08), shape: BoxShape.circle),
                      child: Icon(Icons.photo_library_outlined, size: 34, color: widget.color.withValues(alpha: 0.45))),
                  const SizedBox(height: 16),
                  const Text('Sin imágenes todavía', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                  const SizedBox(height: 6),
                  const Text('Sube imágenes para usarlas en tu web', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _subirImagen,
                    icon: const Icon(Icons.upload_rounded, size: 16),
                    label: const Text('Subir primera imagen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.color, foregroundColor: Colors.white,
                      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ]))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
                  ),
                  itemCount: _imagenes.length,
                  itemBuilder: (_, i) {
                    final img = _imagenes[i];
                    final url = img['url'] as String? ?? '';
                    return Stack(children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          image: url.isNotEmpty ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
                        ),
                        child: url.isEmpty ? Center(child: Icon(Icons.image_outlined, color: Colors.grey[300], size: 32)) : null,
                      ),
                      Positioned(top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () async {
                            await widget.svc.eliminarDeGaleria(widget.empresaId, img['id'] as String? ?? '');
                            await _cargar();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.close, size: 12, color: Colors.white),
                          ),
                        )),
                    ]);
                  },
                )),
    ]);
  }
}

// ─── Eventos embebidos (sin Scaffold) ────────────────────────────────────────

class _EmbeddedEventos extends StatelessWidget {
  final String empresaId;
  final SeccionWeb seccion;
  final ContenidoWebService svc;
  final VoidCallback onCerrar;
  final Color color;

  const _EmbeddedEventos({
    required this.empresaId,
    required this.seccion,
    required this.svc,
    required this.onCerrar,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TabEventosWeb(empresaId: empresaId, svc: svc);
  }
}

// ─── Editor catálogo embebido (sin Scaffold propio) ──────────────────────────

class _EditorCatalogoEmbebido extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  final Map<String, dynamic>? item;
  final Color color;
  final VoidCallback? onGuardado;
  final VoidCallback? onCancelar;

  const _EditorCatalogoEmbebido({
    required this.empresaId, required this.svc, required this.color,
    this.item, this.onGuardado, this.onCancelar,
  });

  @override
  State<_EditorCatalogoEmbebido> createState() => _EditorCatalogoEmbebidoState();
}

class _EditorCatalogoEmbebidoState extends State<_EditorCatalogoEmbebido> {
  final _nombreCtrl      = TextEditingController();
  final _slugCtrl        = TextEditingController();
  Set<String> _categorias = {};
  final _coleccionCtrl   = TextEditingController();
  final _tagCtrl         = TextEditingController();
  final _precioCtrl      = TextEditingController();
  final _precioDigCtrl   = TextEditingController();
  final _stripeLinkCtrl  = TextEditingController();
  final _descCtrl        = TextEditingController();
  final _isbnCtrl        = TextEditingController();
  final _paginasCtrl     = TextEditingController();
  final _formatoCtrl     = TextEditingController();
  final _dimensionesCtrl = TextEditingController();
  final _pesoCtrl        = TextEditingController();
  final _mesCtrl         = TextEditingController();
  int    _anio  = DateTime.now().year;
  bool   _activo = true;
  bool   _extraExpanded = false;
  bool   _guardando = false;
  bool   _subiendoImg = false;
  String? _imagenUrl;
  String? _autorId;
  String? _autorNombre;
  final _traductorCtrl  = TextEditingController();
  String  _traductorId  = '';
  String  _traductorGen = ''; // 'f' = femenino
  final _ilustradorCtrl = TextEditingController();
  String  _ilustradorId  = '';
  String  _ilustradorGen = '';

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    if (it != null) {
      _nombreCtrl.text      = it['nombre'] ?? '';
      _slugCtrl.text        = it['slug'] ?? '';
      final catArr = it['categorias'];
      if (catArr is List && catArr.isNotEmpty) {
        _categorias = catArr.map((e) => e.toString()).where((s) => s.isNotEmpty).toSet();
      } else {
        _categorias = (it['categoria'] as String? ?? '').split('/')
            .map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
      }
      _coleccionCtrl.text   = it['coleccion'] ?? it['campo_coleccion'] ?? '';
      _tagCtrl.text         = it['tag'] ?? '';
      _imagenUrl            = it['imagen_url'] as String?;
      _precioCtrl.text      = it['precio'] ?? '';
      _precioDigCtrl.text   = it['precio_digital'] ?? '';
      _stripeLinkCtrl.text  = it['stripe_link'] ?? '';
      _descCtrl.text        = it['descripcion'] ?? '';
      _autorNombre          = (it['campo_autor'] as String?)?.isNotEmpty == true
                                ? it['campo_autor'] as String : null;
      _autorId              = it['campo_autor_id'] as String?;
      _traductorCtrl.text   = it['campo_traductor'] as String? ?? '';
      _traductorId          = it['campo_traductor_id'] as String? ?? '';
      _traductorGen         = it['campo_traductor_genero'] as String? ?? '';
      _ilustradorCtrl.text  = it['campo_ilustrador'] as String? ?? '';
      _ilustradorId         = it['campo_ilustrador_id'] as String? ?? '';
      _ilustradorGen        = it['campo_ilustrador_genero'] as String? ?? '';
      _isbnCtrl.text        = it['campo_isbn'] ?? '';
      _paginasCtrl.text     = it['campo_paginas'] ?? '';
      _formatoCtrl.text     = it['campo_formato'] ?? '';
      _dimensionesCtrl.text = it['campo_dimensiones'] ?? '';
      _pesoCtrl.text        = it['campo_peso']?.toString() ?? '';
      _mesCtrl.text         = it['campo_mes'] ?? '';
      _anio   = int.tryParse(it['campo_anio']?.toString() ?? '') ?? DateTime.now().year;
      _activo = it['activo'] as bool? ?? true;
    }
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _slugCtrl, _coleccionCtrl, _tagCtrl,
        _precioCtrl, _precioDigCtrl, _stripeLinkCtrl, _descCtrl,
        _traductorCtrl, _ilustradorCtrl,
        _isbnCtrl, _paginasCtrl, _formatoCtrl, _dimensionesCtrl, _pesoCtrl, _mesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _subirImagen() async {
    setState(() => _subiendoImg = true);
    try {
      final url = await widget.svc.subirImagenDesdeGaleria(
          widget.empresaId, 'catalogo_web');
      if (!mounted) return;
      if (url != null) {
        setState(() => _imagenUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Imagen subida correctamente'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se seleccionó ninguna imagen'),
          behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al subir: $e'),
        backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _subiendoImg = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return Column(children: [
      // Mini-appbar del editor (sin Scaffold propio)
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: widget.onCancelar,
          ),
          const SizedBox(width: 4),
          Text(
            widget.item == null ? 'Nuevo elemento' : 'Editar elemento',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A)),
          ),
          const Spacer(),
          TextButton(
            onPressed: _guardando ? null : () => _guardar(context),
            child: _guardando
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Guardar', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: _guardando ? null : () => _guardar(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white,
              elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            ),
            child: const Text('Publicar en web'),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _card(Column(children: [
              _campo(_nombreCtrl, 'Nombre / Título *'),
              const Divider(height: 1),
              _campo(_slugCtrl, 'Slug URL', hint: 'titulo-sin-espacios'),
              const Divider(height: 1),
              _CategoriasSelector(
                seleccionadas: _categorias,
                onToggle: (cat) => setState(() {
                  _categorias.contains(cat) ? _categorias.remove(cat) : _categorias.add(cat);
                }),
                color: color,
              ),
              const Divider(height: 1),
              _ColeccionSelector(ctrl: _coleccionCtrl, color: color),
              const Divider(height: 1),
              _campo(_tagCtrl, 'Badge (ej: Novedad, Recomendado)'),
              const Divider(height: 1),
              // Imagen — subida desde archivos
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  // Preview
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _imagenUrl != null && _imagenUrl!.isNotEmpty
                        ? Image.network(_imagenUrl!, width: 56, height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imgFallback(color))
                        : _imgFallback(color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_imagenUrl != null ? 'Imagen seleccionada' : 'Sin imagen',
                        style: TextStyle(fontSize: 13,
                            color: _imagenUrl != null ? const Color(0xFF0F172A) : Colors.grey[400])),
                    const SizedBox(height: 6),
                    Row(children: [
                      OutlinedButton.icon(
                        onPressed: _subiendoImg ? null : _subirImagen,
                        icon: _subiendoImg
                            ? const SizedBox(width: 12, height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.upload_rounded, size: 14),
                        label: Text(_imagenUrl != null ? 'Cambiar imagen' : 'Subir imagen',
                            style: const TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color, side: BorderSide(color: color),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      if (_imagenUrl != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setState(() => _imagenUrl = null),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            minimumSize: Size.zero,
                          ),
                          child: const Text('Quitar', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ]),
                  ])),
                ]),
              ),
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
                // Selector de autor vinculado a colección autores
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: widget.svc.obtenerAutores(widget.empresaId),
                  builder: (_, snap) {
                    final autores = snap.data ?? [];
                    final ids = <String>{};
                    final uniq = autores.where((a) {
                      final id = a['id']?.toString() ?? '';
                      return id.isNotEmpty && ids.add(id);
                    }).toList();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        Text('Autor', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _abrirSelectorAutor(context, uniq),
                            child: Row(children: [
                              Expanded(child: Text(
                                _autorNombre ?? 'Sin autor vinculado',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _autorNombre != null
                                      ? const Color(0xFF0F172A) : Colors.grey[400],
                                ),
                                overflow: TextOverflow.ellipsis,
                              )),
                              Icon(Icons.search_rounded, size: 16,
                                  color: widget.color.withValues(alpha: 0.5)),
                            ]),
                          ),
                        ),
                        if (_autorNombre != null)
                          GestureDetector(
                            onTap: () => setState(() { _autorId = null; _autorNombre = null; }),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(Icons.clear_rounded, size: 15, color: Colors.grey[400]),
                            ),
                          ),
                      ]),
                    );
                  },
                ),
                const Divider(height: 1),
                _campoCredito(_traductorCtrl, 'Traductor/a', true),
                const Divider(height: 1),
                _campoCredito(_ilustradorCtrl, 'Ilustrador/a', false),
                const Divider(height: 1),
                _campo(_isbnCtrl, 'ISBN / Referencia'),
                const Divider(height: 1),
                _campo(_paginasCtrl, 'Páginas / Unidades'),
                const Divider(height: 1),
                _campo(_formatoCtrl, 'Formato'),
                const Divider(height: 1),
                _campo(_dimensionesCtrl, 'Dimensiones'),
                const Divider(height: 1),
                _campo(_pesoCtrl, 'Peso (g)', hint: 'ej. 320'),
                const Divider(height: 1),
                _campo(_mesCtrl, 'Mes'),
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
                _activo ? 'Aparece en el catálogo de tu sitio web'
                        : 'No aparece en el catálogo de tu sitio web',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              contentPadding: EdgeInsets.zero,
              activeColor: color,
            )),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ]);
  }

  // Campo traductor/ilustrador con mismo picker que el autor
  Widget _campoCredito(TextEditingController ctrl, String label, bool esTraductor) {
    final gen    = esTraductor ? _traductorGen    : _ilustradorGen;
    final id     = esTraductor ? _traductorId     : _ilustradorId;
    final nombre = ctrl.text.isNotEmpty ? ctrl.text : null;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: widget.svc.obtenerAutores(widget.empresaId),
      builder: (_, snap) {
        final autores = snap.data ?? [];
        final ids = <String>{};
        final uniq = autores.where((a) {
          final aid = a['id']?.toString() ?? '';
          return aid.isNotEmpty && ids.add(aid);
        }).toList();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _abrirSelectorCredito(context, uniq, esTraductor),
                child: Row(children: [
                  Expanded(child: Text(
                    nombre ?? 'Sin $label vinculado/a',
                    style: TextStyle(
                      fontSize: 13,
                      color: nombre != null
                          ? (id.isNotEmpty ? const Color(0xFF10B981) : const Color(0xFF0F172A))
                          : Colors.grey[400]),
                    overflow: TextOverflow.ellipsis,
                  )),
                  Icon(Icons.search_rounded, size: 16,
                      color: widget.color.withValues(alpha: 0.5)),
                ]),
              ),
            ),
            // Chip F para género femenino
            GestureDetector(
              onTap: () => setState(() {
                if (esTraductor) _traductorGen = gen == 'f' ? '' : 'f';
                else _ilustradorGen = gen == 'f' ? '' : 'f';
              }),
              child: Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: gen == 'f' ? const Color(0xFF6366F1) : Colors.transparent,
                  border: Border.all(color: gen == 'f' ? const Color(0xFF6366F1) : Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4)),
                child: Text('F', style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: gen == 'f' ? Colors.white : Colors.grey)),
              ),
            ),
            if (nombre != null)
              GestureDetector(
                onTap: () => setState(() {
                  ctrl.clear();
                  if (esTraductor) { _traductorId = ''; _traductorGen = ''; }
                  else             { _ilustradorId = ''; _ilustradorGen = ''; }
                }),
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.clear_rounded, size: 15, color: Colors.grey[400]),
                ),
              ),
          ]),
        );
      },
    );
  }

  Future<void> _abrirSelectorCredito(
      BuildContext context,
      List<Map<String, dynamic>> autores,
      bool esTraductor) async {
    final ctrl = TextEditingController();
    final result = await showModalBottomSheet<Map<String, String?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final q = ctrl.text.toLowerCase();
          final filtrados = q.isEmpty
              ? autores
              : autores.where((a) =>
                  (a['nombre']?.toString() ?? '').toLowerCase().contains(q)).toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(esTraductor ? 'Seleccionar traductor/a' : 'Seleccionar ilustrador/a',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: ctrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () { ctrl.clear(); setModal(() {}); })
                          : null,
                      filled: true, fillColor: const Color(0xFFF8F9FB),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: widget.color)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (_) => setModal(() {}),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  ListTile(
                    leading: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
                    title: Text('— Sin ${esTraductor ? "traductor/a" : "ilustrador/a"} —',
                        style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    onTap: () => Navigator.pop(ctx, <String, String?>{'id': null, 'nombre': null}),
                  ),
                  ...filtrados.map((a) {
                    final aid    = a['id']?.toString() ?? '';
                    final nombre = a['nombre']?.toString() ?? '';
                    final sel    = esTraductor ? _traductorId == aid : _ilustradorId == aid;
                    return ListTile(
                      leading: Icon(Icons.check_circle_outline_rounded, size: 18,
                          color: sel ? widget.color : Colors.grey[300]),
                      title: Text(nombre, style: TextStyle(fontSize: 13,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal)),
                      selected: sel,
                      selectedTileColor: widget.color.withValues(alpha: 0.06),
                      onTap: () => Navigator.pop(ctx, <String, String?>{'id': aid, 'nombre': nombre}),
                    );
                  }),
                  if (filtrados.isEmpty)
                    Padding(padding: const EdgeInsets.all(24),
                      child: Center(child: Text('Sin resultados para "${ctrl.text}"',
                          style: const TextStyle(color: Colors.grey, fontSize: 13)))),
                ],
              )),
            ]),
          );
        },
      ),
    );
    ctrl.dispose();
    if (result != null && mounted) {
      setState(() {
        final nombre = result['nombre'];
        final aid    = result['id'];
        if (esTraductor) {
          _traductorCtrl.text = nombre ?? '';
          _traductorId        = aid ?? '';
        } else {
          _ilustradorCtrl.text = nombre ?? '';
          _ilustradorId        = aid ?? '';
        }
      });
    }
  }

  Widget _imgFallback(Color color) => Container(
    width: 56, height: 72,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
    child: Icon(Icons.image_outlined, color: color.withValues(alpha: 0.4), size: 24),
  );

  Widget _campo(TextEditingController ctrl, String label, {String? hint}) =>
      TextField(controller: ctrl,
        decoration: InputDecoration(
          hintText: hint ?? label, labelText: label,
          border: InputBorder.none,
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

  Future<void> _abrirSelectorAutor(
      BuildContext context, List<Map<String, dynamic>> autores) async {
    final ctrl = TextEditingController();
    final result = await showModalBottomSheet<Map<String, String?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final q = ctrl.text.toLowerCase();
          final filtrados = q.isEmpty
              ? autores
              : autores.where((a) =>
                  (a['nombre']?.toString() ?? '').toLowerCase().contains(q)).toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Seleccionar autor',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar autor…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: ctrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () { ctrl.clear(); setModal(() {}); })
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
                          borderSide: BorderSide(color: widget.color)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (_) => setModal(() {}),
                  ),
                ]),
              ),
              const Divider(height: 1),
              Expanded(child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  ListTile(
                    leading: Icon(Icons.close_rounded, size: 18, color: Colors.grey[400]),
                    title: const Text('— Sin autor vinculado —',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    selected: _autorId == null,
                    selectedTileColor: widget.color.withValues(alpha: 0.06),
                    onTap: () => Navigator.pop(ctx, <String, String?>{'id': null, 'nombre': null}),
                  ),
                  ...filtrados.map((a) {
                    final id = a['id']?.toString() ?? '';
                    final nombre = a['nombre']?.toString() ?? '';
                    return ListTile(
                      leading: Icon(Icons.check_circle_outline_rounded,
                          size: 18,
                          color: _autorId == id ? widget.color : Colors.grey[300]),
                      title: Text(nombre,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _autorId == id
                                ? FontWeight.w600 : FontWeight.normal,
                          )),
                      selected: _autorId == id,
                      selectedTileColor: widget.color.withValues(alpha: 0.06),
                      onTap: () => Navigator.pop(ctx, <String, String?>{'id': id, 'nombre': nombre}),
                    );
                  }),
                  if (filtrados.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(
                        'Sin resultados para "${ctrl.text}"',
                        style: const TextStyle(color: Colors.grey, fontSize: 13))),
                    ),
                ],
              )),
            ]),
          );
        },
      ),
    );
    ctrl.dispose();
    // Aplicar resultado después de que el modal haya cerrado completamente
    if (result != null && mounted) {
      setState(() {
        _autorId     = result['id'];
        _autorNombre = result['nombre'];
      });
    }
  }

  Future<void> _guardar(BuildContext context) async {
    if (_nombreCtrl.text.trim().isEmpty) return;
    setState(() => _guardando = true);
    final docId = widget.item?['id'] as String?;
    final data = <String, dynamic>{
      'nombre':         _nombreCtrl.text.trim(),
      'slug':           _slugCtrl.text.trim(),
      'categorias':     (_categorias.toList()..sort()),
      'categoria':      _categorias.isEmpty ? '' : (_categorias.toList()..sort()).join(' / '),
      'coleccion':      _coleccionCtrl.text.trim(),
      'campo_coleccion': _coleccionCtrl.text.trim(),
      'tag':            _tagCtrl.text.trim(),
      'imagen_url':     _imagenUrl ?? '',
      'precio':         _precioCtrl.text.trim(),
      'precio_digital': _precioDigCtrl.text.trim(),
      'stripe_link':    _stripeLinkCtrl.text.trim(),
      'descripcion':    _descCtrl.text.trim(),
      'activo':         _activo,
      'campo_anio':     _anio.toString(),
    };
    void opt(String k, String v) { if (v.isNotEmpty) data[k] = v; }
    if (_autorNombre != null && _autorNombre!.isNotEmpty) data['campo_autor'] = _autorNombre!;
    if (_autorId != null) data['campo_autor_id'] = _autorId!;
    opt('campo_traductor',  _traductorCtrl.text.trim());
    opt('traductor',        _traductorCtrl.text.trim());
    if (_traductorId.isNotEmpty) data['campo_traductor_id'] = _traductorId;
    if (_traductorGen.isNotEmpty) data['campo_traductor_genero'] = _traductorGen;
    opt('campo_ilustrador', _ilustradorCtrl.text.trim());
    opt('ilustrador',       _ilustradorCtrl.text.trim());
    if (_ilustradorId.isNotEmpty) data['campo_ilustrador_id'] = _ilustradorId;
    if (_ilustradorGen.isNotEmpty) data['campo_ilustrador_genero'] = _ilustradorGen;
    opt('campo_isbn',        _isbnCtrl.text.trim());
    opt('campo_paginas',     _paginasCtrl.text.trim());
    opt('campo_formato',     _formatoCtrl.text.trim());
    opt('campo_dimensiones', _dimensionesCtrl.text.trim());
    opt('campo_peso',        _pesoCtrl.text.trim());
    opt('peso',              _pesoCtrl.text.trim());
    opt('campo_mes',         _mesCtrl.text.trim());
    try {
      await widget.svc.guardarItemCatalogo(widget.empresaId, docId, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Guardado — visible en la web en segundos'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
        widget.onGuardado?.call();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

// ── Selector de Colección editorial ──────────────────────────────────────────

const _kColecciones = [
  'Colección Arrayanes',
  'Colección Daraxa',
  'Colección Mexuar',
  'Colección Partal',
  'Colección Cadí',
  'Colección Thule',
  'Colección Nenúfar',
  'Colección Medina',
  'Colección Cuarto Dorado',
  'Clásicos Ilustrados',
];

class _ColeccionSelector extends StatefulWidget {
  final TextEditingController ctrl;
  final Color color;
  const _ColeccionSelector({required this.ctrl, required this.color});
  @override
  State<_ColeccionSelector> createState() => _ColeccionSelectorState();
}

class _ColeccionSelectorState extends State<_ColeccionSelector> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    final seleccionada = widget.ctrl.text.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Colección', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 6),
        TextField(
          controller: widget.ctrl,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'ej. Colección Arrayanes',
            hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.color.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.color),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
            suffixIcon: seleccionada.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 15),
                    onPressed: () { widget.ctrl.clear(); setState(() {}); })
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _kColecciones.map((col) {
              final sel = seleccionada == col;
              return GestureDetector(
                onTap: () { widget.ctrl.text = col; setState(() {}); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? widget.color.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sel ? widget.color : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    col.replaceFirst('Colección ', ''),
                    style: TextStyle(
                      fontSize: 11,
                      color: sel ? widget.color : const Color(0xFF64748B),
                      fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ── Normalización de acentos para comparación de categorías ──────────────────
// Permite que "Poesia" y "Poesía" cuenten como la misma categoría.
String _normCat(String s) => s.toLowerCase()
    .replaceAll(RegExp(r'[àáâãäåā]'), 'a')
    .replaceAll(RegExp(r'[èéêëē]'), 'e')
    .replaceAll(RegExp(r'[ìíîïī]'), 'i')
    .replaceAll(RegExp(r'[òóôõöō]'), 'o')
    .replaceAll(RegExp(r'[ùúûüū]'), 'u')
    .replaceAll('ñ', 'n')
    .replaceAll('ç', 'c');

// ── Categorías predefinidas Nazarí ────────────────────────────────────────────

const _kCategorias = [
  'Relato',
  'Microrrelato',
  'Infantil',
  'Juvenil',
  'Novela histórica',
  'Novela negra',
  'Ciencia ficción',
  'Fantasía',
  'Romántica',
  'Poesía',
  'Divulgación',
  'Opinión y crítica social',
  'Teatro',
];

class _CategoriasSelector extends StatefulWidget {
  final Set<String> seleccionadas;
  final ValueChanged<String> onToggle;
  final Color color;

  const _CategoriasSelector({
    required this.seleccionadas,
    required this.onToggle,
    required this.color,
  });

  @override
  State<_CategoriasSelector> createState() => _CategoriasSelectorState();
}

class _CategoriasSelectorState extends State<_CategoriasSelector> {
  bool _modoAdd = false;
  final _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  // Devuelve el valor EXACTO almacenado en seleccionadas que coincide
  // accent-insensitivamente con [cat], o null si no existe.
  String? _matchExistente(String cat) => widget.seleccionadas
      .where((s) => _normCat(s) == _normCat(cat))
      .firstOrNull;

  void _toggle(String cat) {
    final existente = _matchExistente(cat);
    // Si ya existe (con o sin tilde), pasamos el valor exacto para que el padre
    // lo encuentre con contains() y lo elimine correctamente.
    widget.onToggle(existente ?? cat);
  }

  void _confirmarNueva() {
    final nueva = _addCtrl.text.trim();
    if (nueva.isNotEmpty && _matchExistente(nueva) == null) {
      widget.onToggle(nueva);
    }
    _addCtrl.clear();
    setState(() => _modoAdd = false);
  }

  @override
  Widget build(BuildContext context) {
    // Categorías extras en seleccionadas que no están en _kCategorias
    final extras = widget.seleccionadas
        .where((s) => !_kCategorias.any((k) => _normCat(k) == _normCat(s)))
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Categorías', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...[..._kCategorias, ...extras].map((cat) {
              final sel = _matchExistente(cat) != null;
              return GestureDetector(
                onTap: () => _toggle(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sel
                        ? widget.color.withValues(alpha: 0.12)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? widget.color : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(cat, style: TextStyle(
                    fontSize: 12,
                    color: sel ? widget.color : const Color(0xFF64748B),
                    fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  )),
                ),
              );
            }),
            // Chip "+" para añadir categoría personalizada
            if (!_modoAdd)
              GestureDetector(
                onTap: () => setState(() => _modoAdd = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: widget.color.withValues(alpha: 0.45)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_rounded, size: 13, color: widget.color),
                    const SizedBox(width: 3),
                    Text('Nueva',
                        style: TextStyle(fontSize: 12, color: widget.color)),
                  ]),
                ),
              )
            else
              SizedBox(
                width: 160,
                height: 32,
                child: TextField(
                  controller: _addCtrl,
                  autofocus: true,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Nombre de categoría…',
                    hintStyle: const TextStyle(
                        fontSize: 11, color: Color(0xFFCBD5E1)),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: widget.color)),
                    suffixIcon: GestureDetector(
                      onTap: _confirmarNueva,
                      child: Icon(Icons.check_rounded,
                          size: 15, color: widget.color),
                    ),
                  ),
                  onSubmitted: (_) => _confirmarNueva(),
                ),
              ),
          ],
        ),
        if (widget.seleccionadas.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Selecciona al menos una categoría',
                style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          ),
      ]),
    );
  }
}


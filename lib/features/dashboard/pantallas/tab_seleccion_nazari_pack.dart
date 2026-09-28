import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

// ═════════════════════════════════════════════════════════════════════════════
// PANEL PACK — creación y gestión del pack mensual de La Selección Nazarí
// Datos en empresas/{EID}/configuracion/pack_seleccion
// Libros del pack: seleccion_nazari donde en_pack == true
// ═════════════════════════════════════════════════════════════════════════════

class PanelPackSeleccion extends StatefulWidget {
  final String empresaId;
  const PanelPackSeleccion({super.key, required this.empresaId});
  @override
  State<PanelPackSeleccion> createState() => _PanelPackSeleccionState();
}

class _PanelPackSeleccionState extends State<PanelPackSeleccion> {
  bool _expandido = false;
  bool _generando = false;

  DocumentReference<Map<String, dynamic>> get _packRef =>
      FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('configuracion').doc('pack_seleccion');

  CollectionReference<Map<String, dynamic>> get _selCol =>
      FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('seleccion_nazari');

  Future<void> _setActivo(bool v) async {
    await _packRef.set({'activo': v}, SetOptions(merge: true));
  }

  Future<void> _setDescuento(int v) async {
    await _packRef.set({'descuento_porcentaje': v}, SetOptions(merge: true));
  }

  Future<void> _setDescripcion(String v) async {
    await _packRef.set({'descripcion': v}, SetOptions(merge: true));
  }

  // URL v2 Cloud Run — mismo hash que crearCheckoutNazari
  static const _kFnUrl =
      'https://crearlinkpacknazari-ys4cz4fdnq-ew.a.run.app';

  Future<void> _generarLink(BuildContext context, List<QueryDocumentSnapshot<Map<String, dynamic>>> libros) async {
    if (libros.isEmpty) return;
    setState(() => _generando = true);
    try {
      // Obtener token de Firebase Auth
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay sesión activa');
      final token = await user.getIdToken();

      final response = await http.post(
        Uri.parse(_kFnUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: '{}',
      ).timeout(const Duration(seconds: 120));

      // Mostrar respuesta completa para diagnóstico
      final body = response.body;
      final contentType = response.headers['content-type'] ?? '';

      if (!contentType.contains('json')) {
        // Respuesta no-JSON: función no desplegada o URL incorrecta
        final preview = body.length > 200 ? body.substring(0, 200) : body;
        throw Exception('HTTP ${response.statusCode} — Respuesta no JSON:\n$preview');
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['url'] != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Link de pago generado y guardado'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
        ));
      } else {
        throw Exception('${response.statusCode}: ${data['error'] ?? body}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ));
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _packRef.snapshots(),
      builder: (_, snapCfg) {
        final cfg     = snapCfg.data?.data() ?? <String, dynamic>{};
        final activo  = cfg['activo']  as bool? ?? false;
        final descPct = (cfg['descuento_porcentaje'] as num?)?.toInt() ?? 50;
        final desc    = cfg['descripcion'] as String? ?? '';
        final link    = cfg['stripe_link'] as String? ?? '';
        final precioOriginal = cfg['precio_original'] as String? ?? '';
        final precioFinal    = cfg['precio_pack']     as String? ?? '';

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _selCol.where('en_pack', isEqualTo: true).snapshots(),
          builder: (_, snapLibros) {
            final libros = snapLibros.data?.docs ?? [];

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: activo
                      ? const Color(0xFFD4A017).withValues(alpha: 0.6)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6, offset: const Offset(0, 1),
                )],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _expandido = !_expandido),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // ── Cabecera ──
                    Row(children: [
                      Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4A017).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.local_offer_rounded, size: 15, color: Color(0xFFD4A017)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Pack La Selección Nazarí',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                        Text(
                          activo
                              ? '${libros.length} libro${libros.length == 1 ? "" : "s"}'
                                '${precioFinal.isNotEmpty ? " · $precioFinal" : ""}'
                                ' · ${descPct}% dto · Activo'
                              : libros.isEmpty
                                  ? 'Sin libros — añade libros con el icono 🛍'
                                  : '${libros.length} libro${libros.length == 1 ? "" : "s"} · Inactivo',
                          style: TextStyle(
                            fontSize: 11,
                            color: activo ? const Color(0xFFD4A017) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ])),
                      Switch(
                        value: activo,
                        activeColor: const Color(0xFFD4A017),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (v) => _setActivo(v),
                      ),
                      Icon(_expandido ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          size: 18, color: const Color(0xFF94A3B8)),
                    ]),

                    if (_expandido) ...[
                      const Divider(height: 20),

                      // ── Libros del pack ──
                      Row(children: [
                        const Icon(Icons.shopping_bag_rounded, size: 14, color: Color(0xFFD4A017)),
                        const SizedBox(width: 6),
                        Text('Libros en el pack (${libros.length})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: Color(0xFF475569))),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _abrirBuscadorLibros(context),
                          icon: const Icon(Icons.add, size: 14),
                          label: const Text('Agregar', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF6B1E2A),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      if (libros.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(children: [
                            Icon(Icons.info_outline, size: 14, color: Color(0xFF94A3B8)),
                            SizedBox(width: 6),
                            Expanded(child: Text(
                              'Pulsa "Agregar" para añadir libros al pack, o usa el icono 🛍 en cada libro de la selección.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            )),
                          ]),
                        )
                      else
                        Column(
                          children: libros.map((doc) {
                            final d = doc.data();
                            return _LibroPackRow(
                              titulo: d['titulo'] as String? ?? 'Sin título',
                              autor: d['autor'] as String? ?? '',
                              imagen: d['imagen'] as String? ?? '',
                              precio: d['precio'] as String? ?? '',
                              onQuitar: () => doc.reference.update({'en_pack': false}),
                            );
                          }).toList(),
                        ),

                      const Divider(height: 20),

                      // ── Cálculo de precio ──
                      if (libros.isNotEmpty) ...[
                        _PrecioCalculado(
                          libros: libros,
                          descuentoPct: descPct,
                          onDescuentoChanged: _setDescuento,
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ── Descripción ──
                      _DescripcionField(value: desc, onSave: _setDescripcion),
                      const SizedBox(height: 12),

                      // ── Link generado ──
                      if (link.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 6),
                            Expanded(child: Text(link,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF15803D)))),
                            GestureDetector(
                              onTap: () => Clipboard.setData(ClipboardData(text: link)),
                              child: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF64748B)),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // ── Botón generar link ──
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (_generando || libros.isEmpty)
                              ? null
                              : () => _generarLink(context, libros),
                          icon: _generando
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.link_rounded, size: 16),
                          label: Text(
                            link.isNotEmpty ? 'Regenerar link de pago' : 'Generar link de pago en Stripe',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6B1E2A),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      if (libros.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text('Añade al menos 1 libro para generar el link',
                              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                        ),
                      const SizedBox(height: 4),
                    ],
                  ]),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _abrirBuscadorLibros(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BuscadorLibrosPack(
        empresaId: widget.empresaId,
        selCol: _selCol,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILA de libro en el pack
// ─────────────────────────────────────────────────────────────────────────────

class _LibroPackRow extends StatelessWidget {
  final String titulo, autor, imagen, precio;
  final VoidCallback onQuitar;
  const _LibroPackRow({
    required this.titulo, required this.autor,
    required this.imagen, required this.precio,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD4A017).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: imagen.isNotEmpty
              ? Image.network(imagen, width: 30, height: 44, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _ph())
              : _ph(),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (autor.isNotEmpty)
            Text(autor, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
        ])),
        if (precio.isNotEmpty)
          Text(precio, style: const TextStyle(fontSize: 11, color: Color(0xFF6B1E2A),
              fontWeight: FontWeight.w600)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onQuitar,
          child: const Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFFD4A017)),
        ),
      ]),
    );
  }

  Widget _ph() => Container(
    width: 30, height: 44,
    decoration: BoxDecoration(
      color: const Color(0xFFD4A017).withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CÁLCULO DE PRECIO en vivo
// ─────────────────────────────────────────────────────────────────────────────

class _PrecioCalculado extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> libros;
  final int descuentoPct;
  final void Function(int) onDescuentoChanged;

  const _PrecioCalculado({
    required this.libros,
    required this.descuentoPct,
    required this.onDescuentoChanged,
  });

  double _parsePrecio(String s) {
    final raw = s.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(raw) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    double total = 0;
    for (final doc in libros) {
      total += _parsePrecio(doc.data()['precio'] as String? ?? '');
    }
    final pack = total * (1 - descuentoPct / 100);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Precio original:', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
          Text('${total.toStringAsFixed(2).replaceAll('.', ',')} €',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8),
                  decoration: TextDecoration.lineThrough)),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          const Text('Descuento:', style: TextStyle(fontSize: 11.5, color: Color(0xFF475569))),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: descuentoPct,
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A)),
            items: [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60].map((n) =>
                DropdownMenuItem(value: n, child: Text('$n%'))).toList(),
            onChanged: (v) { if (v != null) onDescuentoChanged(v); },
          ),
        ]),
        const Divider(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Precio del pack:', style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
          Text('${pack.toStringAsFixed(2).replaceAll('.', ',')} €',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: Color(0xFF6B1E2A))),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CAMPO DESCRIPCIÓN inline (guarda con debounce al perder foco)
// ─────────────────────────────────────────────────────────────────────────────

class _DescripcionField extends StatefulWidget {
  final String value;
  final Future<void> Function(String) onSave;
  const _DescripcionField({required this.value, required this.onSave});
  @override
  State<_DescripcionField> createState() => _DescripcionFieldState();
}

class _DescripcionFieldState extends State<_DescripcionField> {
  late final TextEditingController _ctrl;
  @override
  void initState() { super.initState(); _ctrl = TextEditingController(text: widget.value); }
  @override
  void didUpdateWidget(_DescripcionField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && _ctrl.text != widget.value) _ctrl.text = widget.value;
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      maxLines: 2,
      onSubmitted: (v) => widget.onSave(v.trim()),
      onEditingComplete: () => widget.onSave(_ctrl.text.trim()),
      decoration: InputDecoration(
        hintText: 'Descripción del pack para la web…',
        hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
        labelText: 'Descripción (opcional)',
        labelStyle: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF6B1E2A), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
        suffixIcon: IconButton(
          icon: const Icon(Icons.check_rounded, size: 16),
          onPressed: () => widget.onSave(_ctrl.text.trim()),
          tooltip: 'Guardar',
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUSCADOR DE LIBROS para el pack — busca en catalogo_web
// ─────────────────────────────────────────────────────────────────────────────

class _BuscadorLibrosPack extends StatefulWidget {
  final String empresaId;
  final CollectionReference<Map<String, dynamic>> selCol;
  const _BuscadorLibrosPack({required this.empresaId, required this.selCol});
  @override
  State<_BuscadorLibrosPack> createState() => _BuscadorLibrosPackState();
}

class _BuscadorLibrosPackState extends State<_BuscadorLibrosPack> {
  final _busqueda = TextEditingController();
  String _query = '';
  Set<String> _yaEnPack = {};
  bool _cargando = false;

  CollectionReference<Map<String, dynamic>> get _catCol =>
      FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('catalogo_web');

  @override
  void initState() {
    super.initState();
    _busqueda.addListener(() => setState(() => _query = _busqueda.text.toLowerCase()));
    _cargarYaEnPack();
  }

  Future<void> _cargarYaEnPack() async {
    final snap = await widget.selCol.where('en_pack', isEqualTo: true).get();
    if (!mounted) return;
    setState(() {
      _yaEnPack = snap.docs
          .map((d) => d.data()['catalogo_id'] as String? ?? d.id)
          .where((id) => id.isNotEmpty)
          .toSet();
    });
  }

  @override
  void dispose() { _busqueda.dispose(); super.dispose(); }

  Future<void> _agregarAlPack(String catalogoId, Map<String, dynamic> data) async {
    if (_cargando || _yaEnPack.contains(catalogoId)) return;
    setState(() => _cargando = true);
    try {
      // Buscar si ya existe en seleccion_nazari
      final existing = await widget.selCol
          .where('catalogo_id', isEqualTo: catalogoId).limit(1).get();

      if (existing.docs.isNotEmpty) {
        await existing.docs.first.reference.update({'en_pack': true});
      } else {
        final count = (await widget.selCol.count().get()).count ?? 0;
        await widget.selCol.add({
          'catalogo_id':     catalogoId,
          'slug':            data['slug'] ?? catalogoId,
          'titulo':          data['nombre'] ?? data['titulo'] ?? '',
          'autor':           data['campo_autor'] ?? data['autor'] ?? '',
          'imagen':          data['imagen_url'] ?? data['imagen'] ?? '',
          'precio':          data['precio'] ?? '',
          'genero':          data['tag'] ?? data['genero'] ?? '',
          'nota_editorial':  '',
          'activo':          true,
          'es_libro_del_mes': false,
          'en_pack':         true,
          'orden':           count,
          'fecha_creacion':  FieldValue.serverTimestamp(),
        });
      }
      setState(() => _yaEnPack.add(catalogoId));
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
          Container(
            width: 40, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 14),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              const Icon(Icons.shopping_bag_rounded, color: Color(0xFFD4A017), size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Agregar libros al pack',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)))),
              IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: _busqueda,
              decoration: InputDecoration(
                hintText: 'Buscar por título o autor…',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                filled: true, fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFD4A017), width: 1.5)),
                isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _catCol.limit(300).snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Filtros client-side: activo + búsqueda
                final todos = (snap.data?.docs ?? []).where((d) {
                  return d.data()['activo'] != false;
                }).toList();
                final filtrados = _query.isEmpty ? todos : todos.where((d) {
                  final n = (d.data()['nombre'] ?? d.data()['titulo'] ?? '').toString().toLowerCase();
                  final a = (d.data()['campo_autor'] ?? d.data()['autor'] ?? '').toString().toLowerCase();
                  return n.contains(_query) || a.contains(_query);
                }).toList();

                if (filtrados.isEmpty) {
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(_query.isEmpty ? 'El catálogo está vacío' : 'Sin resultados',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                  ]));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final doc   = filtrados[i];
                    final data  = doc.data();
                    final id    = doc.id;
                    final yaEsta = _yaEnPack.contains(id);
                    final titulo = data['nombre'] ?? data['titulo'] ?? '';
                    final autor  = data['campo_autor'] ?? data['autor'] ?? '';
                    final imagen = data['imagen_url'] ?? data['imagen'] ?? '';
                    final precio = data['precio'] as String? ?? '';

                    return Container(
                      decoration: BoxDecoration(
                        color: yaEsta ? const Color(0xFFFFFBF0) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: yaEsta
                              ? const Color(0xFFD4A017).withValues(alpha: 0.4)
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
                        title: Text(titulo, style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: yaEsta ? const Color(0xFF92400E) : const Color(0xFF0F172A),
                        )),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (autor.isNotEmpty)
                            Text(autor, style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                          if (precio.isNotEmpty)
                            Text(precio, style: const TextStyle(fontSize: 11, color: Color(0xFF6B1E2A),
                                fontWeight: FontWeight.w500)),
                        ]),
                        trailing: yaEsta
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFFD4A017), size: 22)
                            : FilledButton(
                                onPressed: _cargando ? null : () => _agregarAlPack(id, data),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4A017),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                child: const Text('+ Pack'),
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
      color: const Color(0xFFD4A017).withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(4),
    ),
  );
}

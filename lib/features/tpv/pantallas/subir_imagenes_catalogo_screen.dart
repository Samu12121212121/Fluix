import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Subida masiva de imágenes al catálogo
// ─────────────────────────────────────────────────────────────────────────────

class SubirImagenesCatalogoScreen extends StatefulWidget {
  final String empresaId;
  const SubirImagenesCatalogoScreen({super.key, required this.empresaId});

  @override
  State<SubirImagenesCatalogoScreen> createState() =>
      _SubirImagenesCatalogoScreenState();
}

class _SubirImagenesCatalogoScreenState
    extends State<SubirImagenesCatalogoScreen> {
  // Estado general
  List<_ImagenItem> _items = [];
  List<_ProductoInfo> _productos = [];
  bool _cargandoProductos = true;

  // Progreso subida
  bool _subiendo = false;
  int _subidos = 0;
  int _omitidos = 0;
  int _errores = 0;

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  // ── Carga todos los productos del catálogo para hacer matching ────────────

  Future<void> _cargarProductos() async {
    final snap = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(widget.empresaId)
        .collection('catalogo')
        .get();
    final prods = snap.docs.map((d) {
      final data = d.data();
      return _ProductoInfo(
        id: d.id,
        nombre: data['nombre'] as String? ?? '',
        imagenUrl: data['imagen_url'] as String?,
      );
    }).toList();
    setState(() {
      _productos = prods;
      _cargandoProductos = false;
    });
  }

  // ── Seleccionar archivos con FilePicker ───────────────────────────────────

  Future<void> _seleccionarImagenes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final nuevos = result.files
        .where((f) => f.bytes != null)
        .map((f) {
      final nombreBase = _nombreSinExtension(f.name);
      final coincidencia = _encontrarProducto(nombreBase);
      return _ImagenItem(
        filename: f.name,
        bytes: f.bytes!,
        nombreBase: nombreBase,
        productoIdAsignado: coincidencia?.id,
        productoNombreAsignado: coincidencia?.nombre,
      );
    }).toList();

    setState(() => _items = [..._items, ...nuevos]);
  }

  // ── Normalización y matching ──────────────────────────────────────────────

  String _normalizar(String s) =>
      s.toLowerCase()
          .replaceAll(RegExp(r'[-_\s]+'), ' ')
          .replaceAll(RegExp(r'[^a-záéíóúüñ0-9 ]'), '')
          .trim();

  String _nombreSinExtension(String filename) {
    final idx = filename.lastIndexOf('.');
    return idx >= 0 ? filename.substring(0, idx) : filename;
  }

  _ProductoInfo? _encontrarProducto(String nombreArchivo) {
    final normFile = _normalizar(nombreArchivo);
    // Coincidencia exacta primero
    for (final p in _productos) {
      if (_normalizar(p.nombre) == normFile) return p;
    }
    // Contención: el nombre del archivo contiene el nombre del producto
    _ProductoInfo? mejor;
    int mejorLen = 0;
    for (final p in _productos) {
      final normProd = _normalizar(p.nombre);
      if (normFile.contains(normProd) && normProd.length > mejorLen) {
        mejor = p;
        mejorLen = normProd.length;
      }
    }
    if (mejor != null) return mejor;
    // Contención inversa: nombre del producto contiene el nombre del archivo
    for (final p in _productos) {
      final normProd = _normalizar(p.nombre);
      if (normProd.contains(normFile) && normFile.length > 3) return p;
    }
    return null;
  }

  // ── Cambiar asignación manual ─────────────────────────────────────────────

  Future<void> _cambiarAsignacion(int idx) async {
    final resultado = await showDialog<_ProductoInfo?>(
      context: context,
      builder: (_) => _DialogoSeleccionarProducto(
        productos: _productos,
        seleccionado: _items[idx].productoIdAsignado,
      ),
    );
    if (resultado == null) return;
    setState(() {
      _items[idx] = _items[idx].copyWith(
        productoIdAsignado: resultado.id,
        productoNombreAsignado: resultado.nombre,
      );
    });
  }

  void _eliminar(int idx) => setState(() => _items.removeAt(idx));

  // ── Subir todas las imágenes ──────────────────────────────────────────────

  Future<void> _subirTodo() async {
    final asignados = _items.where((i) => i.productoIdAsignado != null).toList();
    if (asignados.isEmpty) return;

    setState(() {
      _subiendo = true;
      _subidos = 0;
      _omitidos = _items.where((i) => i.productoIdAsignado == null).length;
      _errores = 0;
    });

    for (final item in asignados) {
      try {
        final ext = item.filename.contains('.')
            ? item.filename.substring(item.filename.lastIndexOf('.'))
            : '.jpg';
        final storagePath =
            'empresas/${widget.empresaId}/catalogo_imagenes/${item.productoIdAsignado}$ext';

        // Subir a Firebase Storage
        final ref = FirebaseStorage.instance.ref(storagePath);
        await ref.putData(
          item.bytes,
          SettableMetadata(contentType: _mimeType(ext)),
        );
        final url = await ref.getDownloadURL();

        // Actualizar Firestore
        await FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('catalogo')
            .doc(item.productoIdAsignado)
            .update({'imagen_url': url, 'thumbnail_url': url});

        setState(() => _subidos++);
      } catch (e) {
        setState(() => _errores++);
        debugPrint('Error subiendo ${item.filename}: $e');
      }
    }

    setState(() => _subiendo = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '✅ $_subidos subidas · $_omitidos sin asignar · $_errores errores'),
        backgroundColor: _errores > 0 ? Colors.orange : Colors.green,
        duration: const Duration(seconds: 4),
      ));
      _cargarProductos();
    }
  }

  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      case '.avif':
        return 'image/avif';
      default:
        return 'image/jpeg';
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sinAsignar = _items.where((i) => i.productoIdAsignado == null).length;
    final conAsignar = _items.where((i) => i.productoIdAsignado != null).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(children: [
          Icon(Icons.image_outlined, size: 20),
          SizedBox(width: 8),
          Text('Subir imágenes al catálogo',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        actions: [
          if (_items.isNotEmpty && !_subiendo)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: conAsignar > 0 ? _subirTodo : null,
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF7B1FA2)),
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text('Subir $conAsignar'),
              ),
            ),
        ],
      ),
      body: _cargandoProductos
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Banner info ────────────────────────────────────────────
                if (_items.isEmpty)
                  Expanded(child: _buildEstadoVacio())
                else ...[
                  // ── Resumen ──────────────────────────────────────────────
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(children: [
                      _badge('$conAsignar asignadas', Colors.green),
                      const SizedBox(width: 8),
                      if (sinAsignar > 0)
                        _badge('$sinAsignar sin producto', Colors.orange),
                      const Spacer(),
                      if (_subiendo)
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                    ]),
                  ),
                  // ── Lista ────────────────────────────────────────────────
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _buildItemCard(i),
                    ),
                  ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _subiendo ? null : _seleccionarImagenes,
        backgroundColor: const Color(0xFF7B1FA2),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Añadir imágenes'),
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined,
                size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Selecciona las imágenes de tu carpeta',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'La app intentará asignar cada imagen al producto '
              'cuyo nombre coincida con el nombre del archivo.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _seleccionarImagenes,
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7B1FA2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14)),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Abrir carpeta',
                  style: TextStyle(fontSize: 15)),
            ),
            const SizedBox(height: 12),
            Text(
              'Formatos: JPG, PNG, WEBP, AVIF',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int i) {
    final item = _items[i];
    final asignado = item.productoIdAsignado != null;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: asignado ? Colors.green[200]! : Colors.orange[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Miniatura
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                item.bytes,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.filename,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _cambiarAsignacion(i),
                    child: Row(children: [
                      Icon(
                        asignado
                            ? Icons.link
                            : Icons.link_off,
                        size: 14,
                        color: asignado ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          asignado
                              ? item.productoNombreAsignado!
                              : 'Sin producto — toca para asignar',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: asignado
                                  ? Colors.black87
                                  : Colors.orange[700]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            // Acciones
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  size: 18, color: Color(0xFF7B1FA2)),
              onPressed: () => _cambiarAsignacion(i),
              tooltip: 'Cambiar producto',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
              onPressed: () => _eliminar(i),
              tooltip: 'Quitar',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Modelo interno ────────────────────────────────────────────────────────────

class _ImagenItem {
  final String filename;
  final Uint8List bytes;
  final String nombreBase;
  final String? productoIdAsignado;
  final String? productoNombreAsignado;

  const _ImagenItem({
    required this.filename,
    required this.bytes,
    required this.nombreBase,
    this.productoIdAsignado,
    this.productoNombreAsignado,
  });

  _ImagenItem copyWith({String? productoIdAsignado, String? productoNombreAsignado}) {
    return _ImagenItem(
      filename: filename,
      bytes: bytes,
      nombreBase: nombreBase,
      productoIdAsignado: productoIdAsignado ?? this.productoIdAsignado,
      productoNombreAsignado:
          productoNombreAsignado ?? this.productoNombreAsignado,
    );
  }
}

class _ProductoInfo {
  final String id;
  final String nombre;
  final String? imagenUrl;
  const _ProductoInfo(
      {required this.id, required this.nombre, this.imagenUrl});
}

// ── Diálogo selector de producto ──────────────────────────────────────────────

class _DialogoSeleccionarProducto extends StatefulWidget {
  final List<_ProductoInfo> productos;
  final String? seleccionado;

  const _DialogoSeleccionarProducto(
      {required this.productos, this.seleccionado});

  @override
  State<_DialogoSeleccionarProducto> createState() =>
      _DialogoSeleccionarProductoState();
}

class _DialogoSeleccionarProductoState
    extends State<_DialogoSeleccionarProducto> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final filtrados = widget.productos.where((p) {
      if (_filtro.isEmpty) return true;
      return p.nombre.toLowerCase().contains(_filtro.toLowerCase());
    }).toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));

    return AlertDialog(
      title: const Text('Asignar a producto'),
      content: SizedBox(
        width: 340,
        height: 400,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _filtro = v),
              decoration: const InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtrados.length,
                itemBuilder: (_, i) {
                  final p = filtrados[i];
                  final sel = p.id == widget.seleccionado;
                  return ListTile(
                    dense: true,
                    selected: sel,
                    selectedTileColor: const Color(0xFF7B1FA2).withValues(alpha: 0.1),
                    title: Text(p.nombre,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
                    trailing: p.imagenUrl != null
                        ? const Icon(Icons.image, size: 16, color: Colors.green)
                        : null,
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
      ],
    );
  }
}

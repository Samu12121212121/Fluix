import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/catalogo_csv_parser.dart';
import '../../../services/biblioteca_imagenes_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
// IMPORTADOR DEL CATÁLOGO — wizard multi-paso
// Ruta: empresas/{empresaId}/catalogo  (mismo que PedidosService._productos)
// ─────────────────────────────────────────────────────────────────────────────

class ImportarCatalogoCsvScreen extends StatefulWidget {
  final String empresaId;

  const ImportarCatalogoCsvScreen({super.key, required this.empresaId});

  @override
  State<ImportarCatalogoCsvScreen> createState() =>
      _ImportarCatalogoCsvScreenState();
}

class _ImportarCatalogoCsvScreenState
    extends State<ImportarCatalogoCsvScreen> {
  static const _color = Color(0xFF1565C0);

  int _paso = 0;
  // 0 = Instrucciones
  // 1 = Cargando archivo
  // 2 = Preview + asignación de imágenes
  // 3 = Importando
  // 4 = Resultado

  ResultadoParseoProductos? _parseo;
  String _nombreFichero = '';

  // Imágenes seleccionadas: índice fila → url
  final Map<int, String?> _imagenesAsignadas = {};

  // Opciones
  bool _omitirDuplicados = true; // si existe el mismo SKU, omitir
  bool _sobreescribir = false;   // si existe, actualizar precio/desc

  // Resultados
  int _importados = 0;
  int _omitidos = 0;
  int _errores = 0;

  // Biblioteca de imágenes compartidas
  List<ImagenComun> _biblioteca = [];

  @override
  void initState() {
    super.initState();
    _cargarBiblioteca();
  }

  Future<void> _cargarBiblioteca() async {
    final imgs = await BibliotecaImagenesService().cargarTodas();
    if (mounted) setState(() { _biblioteca = imgs; });
  }

  // ── PASO 1: Seleccionar fichero ───────────────────────────────────────────

  Future<void> _seleccionarFichero() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt', 'tsv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _nombreFichero = file.name;
      _parseo = CatalogoCsvParser.parsear(file.bytes!);
      // Autoasignar imágenes
      _imagenesAsignadas.clear();
      for (int i = 0; i < _parseo!.filas.length; i++) {
        final fila = _parseo!.filas[i];
        final match = BibliotecaImagenesService().autoMatch(fila.nombre, _biblioteca);
        if (match != null) _imagenesAsignadas[i] = match.imagenUrl;
      }
      _paso = 2;
    });
  }

  // ── PASO 3: Importar ──────────────────────────────────────────────────────

  Future<void> _importar() async {
    if (_parseo == null) return;
    setState(() { _paso = 3; _importados = 0; _omitidos = 0; _errores = 0; });

    final db = FirebaseFirestore.instance;
    final ref = db.collection('empresas').doc(widget.empresaId).collection('catalogo');

    // Cargar SKUs y nombres existentes para detectar duplicados
    final existentes = await ref.get();
    final skusExistentes = <String, String>{}; // sku → docId
    final nombresExistentes = <String, String>{}; // nombre_lower → docId
    for (final doc in existentes.docs) {
      final d = doc.data();
      if (d['sku'] != null && (d['sku'] as String).isNotEmpty) {
        skusExistentes[d['sku'] as String] = doc.id;
      }
      if (d['nombre'] != null) {
        nombresExistentes[(d['nombre'] as String).toLowerCase()] = doc.id;
      }
    }

    final filasValidas = _parseo!.filas.where((f) => f.esValido).toList();
    int procesadas = 0;

    for (int i = 0; i < filasValidas.length; i++) {
      final fila = filasValidas[i];
      if (mounted) setState(() {});

      try {
        // Detectar duplicado
        String? docIdExistente;
        if (fila.sku != null && skusExistentes.containsKey(fila.sku)) {
          docIdExistente = skusExistentes[fila.sku];
        } else if (nombresExistentes.containsKey(fila.nombre.toLowerCase())) {
          docIdExistente = nombresExistentes[fila.nombre.toLowerCase()];
        }

        if (docIdExistente != null && _omitirDuplicados && !_sobreescribir) {
          _omitidos++;
          continue;
        }

        final imagenUrl = _imagenesAsignadas[_parseo!.filas.indexOf(fila)] ??
            _imagenesAsignadas[i];

        final data = <String, dynamic>{
          'nombre': fila.nombre,
          'categoria': fila.categoria,
          'precio': fila.precio,
          'activo': true,
          'empresa_id': widget.empresaId,
          'variantes': [],
          'etiquetas': [],
          'tiene_variantes': false,
          'iva_porcentaje': fila.ivaPorcentaje,
          if (fila.descripcion != null) 'descripcion': fila.descripcion,
          if (fila.sku != null) 'sku': fila.sku,
          if (fila.codigoBarras != null) 'codigo_barras': fila.codigoBarras,
          if (fila.stock != null) 'stock': fila.stock,
          if (fila.coste != null) 'coste': fila.coste,
          if (imagenUrl != null) 'imagen_url': imagenUrl,
        };

        if (docIdExistente != null && _sobreescribir) {
          await ref.doc(docIdExistente).update(data);
        } else if (docIdExistente == null) {
          data['fecha_creacion'] = FieldValue.serverTimestamp();
          await ref.add(data);
        } else {
          _omitidos++;
          continue;
        }
        _importados++;
      } catch (e) {
        _errores++;
        debugPrint('Error importando fila ${fila.fila}: $e');
      }
    }

    if (mounted) setState(() => _paso = 4);
  }

  // ── Descargar plantilla CSV ───────────────────────────────────────────────

  Future<void> _descargarPlantilla() async {
    final csv = CatalogoCsvParser.generarPlantilla();
    final bytes = Uint8List.fromList(utf8.encode(csv));
    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: 'text/csv', name: 'plantilla_catalogo.csv')],
      subject: 'Plantilla CSV Catálogo',
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Importar Catálogo CSV',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: _color,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_paso + 1) / 5,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _buildPaso(),
      ),
    );
  }

  Widget _buildPaso() {
    switch (_paso) {
      case 0: return _pasoInstrucciones();
      case 1: return const Center(child: CircularProgressIndicator());
      case 2: return _pasoPreview();
      case 3: return _pasoImportando();
      case 4: return _pasoResultado();
      default: return _pasoInstrucciones();
    }
  }

  // ── PASO 0: Instrucciones ─────────────────────────────────────────────────

  Widget _pasoInstrucciones() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _tarjetaInfo(
          icono: Icons.upload_file,
          color: _color,
          titulo: '¿Cómo funciona?',
          texto:
              'Sube un archivo CSV con los productos de tu empresa y los importaremos al catálogo. '
              'Funciona con Excel, Google Sheets, Glop, AGORA, ICG, o cualquier TPV externo.',
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Columnas reconocidas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                _filaColumna('nombre', 'OBLIGATORIO — Nombre del producto', true),
                _filaColumna('precio', 'OBLIGATORIO — Precio de venta (ej: 1.50)', true),
                _filaColumna('categoria', 'Familia/Grupo del producto', false),
                _filaColumna('descripcion', 'Descripción o detalle', false),
                _filaColumna('iva', 'Porcentaje IVA (21, 10, 4, 0)', false),
                _filaColumna('sku', 'Código interno / referencia', false),
                _filaColumna('codigo_barras', 'EAN13 / código de barras', false),
                _filaColumna('stock', 'Cantidad en stock', false),
                const SizedBox(height: 10),
                Text(
                  'Los nombres de columna no necesitan ser exactos. '
                  'El sistema detecta variantes como "Precio Venta", "PVP", "Price", "Artículo", etc.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFFF3E5F5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: const Icon(Icons.auto_awesome, color: Color(0xFF7B1FA2)),
            title: const Text('Asignación automática de fotos',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7B1FA2))),
            subtitle: const Text(
              'Detectamos automáticamente el tipo de producto (cerveza, café, pizza…) '
              'y le asignamos una foto de la biblioteca compartida. Puedes cambiarla después.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _descargarPlantilla,
          icon: const Icon(Icons.download),
          label: const Text('Descargar plantilla CSV de ejemplo'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _color,
            side: const BorderSide(color: Color(0xFF1565C0)),
            padding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _seleccionarFichero,
            icon: const Icon(Icons.folder_open),
            label: const Text('Seleccionar archivo CSV',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: _color,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _filaColumna(String campo, String desc, bool obligatorio) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: obligatorio
                  ? const Color(0xFF1565C0).withValues(alpha: 0.12)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(campo,
                style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: obligatorio ? _color : Colors.grey[700])),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  // ── PASO 2: Preview + imágenes ────────────────────────────────────────────

  Widget _pasoPreview() {
    final parseo = _parseo!;
    final filasValidas = parseo.filas.where((f) => f.esValido).toList();
    final filasError = parseo.filas.where((f) => !f.esValido).toList();

    return Column(
      children: [
        // Resumen
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _chipResumen('${filasValidas.length} listos', Colors.green),
              const SizedBox(width: 8),
              if (filasError.isNotEmpty)
                _chipResumen('${filasError.length} con error', Colors.red),
              const Spacer(),
              Text(_nombreFichero,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        // Opciones
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: _switchOpcion(
                  'Omitir duplicados',
                  'Si el producto ya existe (mismo SKU o nombre), se salta',
                  _omitirDuplicados,
                  (v) => setState(() {
                    _omitirDuplicados = v;
                    if (v) _sobreescribir = false;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _switchOpcion(
                  'Actualizar existentes',
                  'Si el producto ya existe, actualiza precio y descripción',
                  _sobreescribir,
                  (v) => setState(() {
                    _sobreescribir = v;
                    if (v) _omitirDuplicados = false;
                  }),
                ),
              ),
            ],
          ),
        ),
        // Lista de productos
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: parseo.filas.length,
            itemBuilder: (_, i) => _tarjetaProductoPreview(i, parseo.filas[i]),
          ),
        ),
        // Botón importar
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: filasValidas.isNotEmpty ? _importar : null,
              icon: const Icon(Icons.cloud_upload),
              label: Text(
                'Importar ${filasValidas.length} productos',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green[700],
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tarjetaProductoPreview(int idx, ProductoCsvFila fila) {
    final imgUrl = _imagenesAsignadas[idx];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: fila.esValido ? Colors.transparent : Colors.red[200]!,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: GestureDetector(
          onTap: fila.esValido ? () => _mostrarSelectorImagen(idx) : null,
          child: Stack(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: imgUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imgUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.broken_image, color: Colors.grey),
                      )
                    : Icon(Icons.add_photo_alternate,
                        color: Colors.grey[400], size: 28),
              ),
              if (imgUrl != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                        color: Colors.blue[700],
                        borderRadius: BorderRadius.circular(4)),
                    child:
                        const Icon(Icons.edit, size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          fila.nombre,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: fila.esValido ? Colors.black87 : Colors.red,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: fila.esValido
            ? Text(
                '${fila.categoria} · ${fila.precio.toStringAsFixed(2)} € · IVA ${fila.ivaPorcentaje.toInt()}%'
                '${fila.sku != null ? ' · ${fila.sku}' : ''}',
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                fila.errores.join(', '),
                style:
                    const TextStyle(fontSize: 11, color: Colors.red),
              ),
        trailing: fila.esValido
            ? Icon(Icons.check_circle, color: Colors.green[600], size: 18)
            : const Icon(Icons.error_outline, color: Colors.red, size: 18),
      ),
    );
  }

  void _mostrarSelectorImagen(int idx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SelectorImagenBiblioteca(
        biblioteca: _biblioteca,
        urlActual: _imagenesAsignadas[idx],
        onSeleccionada: (url) {
          setState(() => _imagenesAsignadas[idx] = url);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ── PASO 3: Importando ────────────────────────────────────────────────────

  Widget _pasoImportando() {
    final total = _parseo!.filasValidas;
    final procesadas = _importados + _omitidos + _errores;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text('Importando productos...',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('$procesadas / $total',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1565C0))),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: total > 0 ? procesadas / total : 0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Text('✅ $_importados importados · ⏭ $_omitidos omitidos · ❌ $_errores errores',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ── PASO 4: Resultado ─────────────────────────────────────────────────────

  Widget _pasoResultado() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: Colors.green[50], shape: BoxShape.circle),
              child: Icon(Icons.check_circle, color: Colors.green[700], size: 48),
            ),
            const SizedBox(height: 24),
            const Text('¡Importación completada!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _filaResultado('✅ Productos importados', '$_importados', Colors.green[700]!),
            if (_omitidos > 0)
              _filaResultado('⏭ Omitidos (duplicados)', '$_omitidos', Colors.orange[700]!),
            if (_errores > 0)
              _filaResultado('❌ Errores', '$_errores', Colors.red[700]!),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _paso = 0;
                      _parseo = null;
                      _imagenesAsignadas.clear();
                    }),
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Importar otro'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.all(14),
                      side: const BorderSide(color: Color(0xFF1565C0)),
                      foregroundColor: _color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check),
                    label: const Text('Ver catálogo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _color,
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaResultado(String label, String valor, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 12),
          Text(valor,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _tarjetaInfo({
    required IconData icono,
    required Color color,
    required String titulo,
    required String texto,
  }) {
    return Card(
      color: color.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 14)),
              const SizedBox(height: 4),
              Text(texto, style: TextStyle(color: Colors.grey[700], fontSize: 13, height: 1.4)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _chipResumen(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _switchOpcion(
      String titulo, String subtitulo, bool value, ValueChanged<bool> onChanged) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  Text(subtitulo,
                      style: TextStyle(color: Colors.grey[500], fontSize: 10)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: _color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SELECTOR DE IMAGEN DE BIBLIOTECA
// ─────────────────────────────────────────────────────────────────────────────

class _SelectorImagenBiblioteca extends StatefulWidget {
  final List<ImagenComun> biblioteca;
  final String? urlActual;
  final ValueChanged<String?> onSeleccionada;

  const _SelectorImagenBiblioteca({
    required this.biblioteca,
    this.urlActual,
    required this.onSeleccionada,
  });

  @override
  State<_SelectorImagenBiblioteca> createState() =>
      _SelectorImagenBibliotecaState();
}

class _SelectorImagenBibliotecaState
    extends State<_SelectorImagenBiblioteca> {
  String _busqueda = '';
  String? _categoriaFiltro;

  List<ImagenComun> get _filtradas {
    var lista = widget.biblioteca;
    if (_categoriaFiltro != null) {
      lista = lista.where((i) => i.categoria == _categoriaFiltro).toList();
    }
    if (_busqueda.isNotEmpty) {
      final q = _busqueda.toLowerCase();
      lista = lista
          .where((i) =>
              i.nombre.toLowerCase().contains(q) ||
              i.tags.any((t) => t.contains(q)))
          .toList();
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final categorias = widget.biblioteca.map((i) => i.categoria).toSet().toList()..sort();

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          const Text('Biblioteca de imágenes compartidas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar imagen…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),
          const SizedBox(height: 8),
          // Filtro por categoría
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chipCategoria('Todas', null),
                ...categorias.map((c) => _chipCategoria(c, c)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Grid de imágenes
          Expanded(
            child: GridView.builder(
              controller: ctrl,
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.75,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _filtradas.length,
              itemBuilder: (_, i) {
                final img = _filtradas[i];
                final seleccionada = widget.urlActual == img.imagenUrl;
                return GestureDetector(
                  onTap: () => widget.onSeleccionada(img.imagenUrl),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: seleccionada
                            ? const Color(0xFF1565C0)
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: img.imagenUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: Colors.grey[200]),
                            errorWidget: (_, __, ___) =>
                                Container(color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image)),
                          ),
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 4),
                              color: Colors.black54,
                              child: Text(
                                img.nombre,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10,
                                    fontWeight: FontWeight.w600),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (seleccionada)
                            const Positioned(
                              top: 4, right: 4,
                              child: Icon(Icons.check_circle,
                                  color: Color(0xFF1565C0), size: 24),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Quitar imagen
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextButton.icon(
              onPressed: () => widget.onSeleccionada(null),
              icon: const Icon(Icons.no_photography_outlined, color: Colors.grey),
              label: const Text('Sin imagen',
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipCategoria(String label, String? value) {
    final sel = _categoriaFiltro == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _categoriaFiltro = value),
        child: Chip(
          label: Text(label, style: TextStyle(
              fontSize: 12, color: sel ? Colors.white : Colors.grey[700])),
          backgroundColor: sel ? const Color(0xFF1565C0) : Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 4),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}







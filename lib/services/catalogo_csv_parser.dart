import 'dart:typed_data';
import 'package:csv/csv.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO: Fila de producto parseada desde CSV
// ─────────────────────────────────────────────────────────────────────────────

class ProductoCsvFila {
  final int fila;           // número de fila en el CSV (1-based)
  final String nombre;
  final String categoria;
  final double precio;
  final String? descripcion;
  final double ivaPorcentaje;
  final String? sku;
  final String? codigoBarras;
  final int? stock;
  final List<String> errores;
  final bool esValido;

  const ProductoCsvFila({
    required this.fila,
    required this.nombre,
    required this.categoria,
    required this.precio,
    this.descripcion,
    this.ivaPorcentaje = 21,
    this.sku,
    this.codigoBarras,
    this.stock,
    required this.errores,
    required this.esValido,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULTADO del parseo
// ─────────────────────────────────────────────────────────────────────────────

class ResultadoParseoProductos {
  final List<String> columnas;          // cabeceras detectadas
  final List<ProductoCsvFila> filas;    // filas parseadas
  final Map<String, int> mapeoColumnas; // nombre_campo → índice columna
  final int totalFilas;
  final int filasValidas;
  final int filasConError;
  final String separador;

  const ResultadoParseoProductos({
    required this.columnas,
    required this.filas,
    required this.mapeoColumnas,
    required this.totalFilas,
    required this.filasValidas,
    required this.filasConError,
    required this.separador,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PARSER
// ─────────────────────────────────────────────────────────────────────────────

class CatalogoCsvParser {
  /// Columnas reconocidas → posibles nombres de cabecera (lowercase)
  static const Map<String, List<String>> _aliasColumnas = {
    'nombre':        ['nombre', 'name', 'producto', 'article', 'articulo', 'descripcion_producto', 'product_name'],
    'categoria':     ['categoria', 'category', 'familia', 'family', 'grupo', 'group', 'tipo', 'type'],
    'precio':        ['precio', 'price', 'pvp', 'importe', 'precio_venta', 'sale_price', 'precio_uni', 'precio_unitario'],
    'descripcion':   ['descripcion', 'description', 'detalle', 'detail', 'obs', 'observaciones', 'notas'],
    'iva':           ['iva', 'vat', 'tax', 'impuesto', 'tipo_iva', 'iva_%', '%iva', 'porcentaje_iva'],
    'sku':           ['sku', 'referencia', 'ref', 'codigo', 'code', 'id_producto', 'product_id', 'cod_interno'],
    'codigo_barras': ['codigo_barras', 'barcode', 'ean', 'ean13', 'ean8', 'upc', 'gtin'],
    'stock':         ['stock', 'cantidad', 'quantity', 'existencias', 'inventory', 'disponible'],
  };

  /// Detecta el separador más probable del CSV
  static String _detectarSeparador(String contenido) {
    final muestra = contenido.length > 5000 ? contenido.substring(0, 5000) : contenido;
    final cuentas = {
      ',':  muestra.split(',').length - 1,
      ';':  muestra.split(';').length - 1,
      '\t': muestra.split('\t').length - 1,
      '|':  muestra.split('|').length - 1,
    };
    return cuentas.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Normaliza texto para comparar
  static String _norm(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'[\s_-]+'), '_');

  /// Intenta asignar cabeceras a campos conocidos
  static Map<String, int> _detectarMapeo(List<String> cabeceras) {
    final mapeo = <String, int>{};
    for (int i = 0; i < cabeceras.length; i++) {
      final cab = _norm(cabeceras[i]);
      for (final entry in _aliasColumnas.entries) {
        if (mapeo.containsKey(entry.key)) continue;
        if (entry.value.any((alias) => cab == alias || cab.contains(alias))) {
          mapeo[entry.key] = i;
          break;
        }
      }
    }
    return mapeo;
  }

  /// Parsea el CSV y devuelve el resultado completo
  static ResultadoParseoProductos parsear(Uint8List bytes) {
    // Detectar encoding (UTF-8 con BOM o sin BOM)
    String contenido;
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      contenido = String.fromCharCodes(bytes.sublist(3));
    } else {
      contenido = String.fromCharCodes(bytes);
    }

    final separador = _detectarSeparador(contenido);
    final converter = CsvToListConverter(
      fieldDelimiter: separador,
      eol: '\n',
      shouldParseNumbers: false,
    );

    List<List<dynamic>> filasCsv;
    try {
      filasCsv = converter.convert(contenido);
    } catch (_) {
      // Fallback: split manual
      filasCsv = contenido
          .split('\n')
          .map((l) => l.split(separador).cast<dynamic>().toList())
          .toList();
    }

    if (filasCsv.isEmpty) {
      return ResultadoParseoProductos(
        columnas: [], filas: [], mapeoColumnas: {},
        totalFilas: 0, filasValidas: 0, filasConError: 0, separador: separador,
      );
    }

    // Cabeceras (primera fila)
    final cabeceras = filasCsv.first.map((e) => e.toString().trim()).toList();
    final mapeo = _detectarMapeo(cabeceras);
    final filasData = filasCsv.skip(1).toList();

    final filasParsed = <ProductoCsvFila>[];
    int filasValidas = 0;
    int filasConError = 0;

    for (int i = 0; i < filasData.length; i++) {
      final row = filasData[i];
      if (row.every((c) => c.toString().trim().isEmpty)) continue; // skip empty rows

      String _get(String campo) {
        final idx = mapeo[campo];
        if (idx == null || idx >= row.length) return '';
        return row[idx].toString().trim();
      }

      final errores = <String>[];

      // Nombre (obligatorio)
      final nombre = _get('nombre');
      if (nombre.isEmpty) errores.add('Nombre requerido');

      // Precio (obligatorio)
      final precioStr = _get('precio').replaceAll(',', '.').replaceAll('€', '').trim();
      final precio = double.tryParse(precioStr) ?? -1;
      if (precio < 0) errores.add('Precio inválido: "${_get('precio')}"');

      // Opcionales
      final categoria = _get('categoria').isEmpty ? 'General' : _get('categoria');
      final descripcion = _get('descripcion').isEmpty ? null : _get('descripcion');
      final ivaStr = _get('iva').replaceAll('%', '').replaceAll(',', '.').trim();
      final iva = double.tryParse(ivaStr) ?? 21.0;
      final sku = _get('sku').isEmpty ? null : _get('sku');
      final cb = _get('codigo_barras').isEmpty ? null : _get('codigo_barras');
      final stockStr = _get('stock').replaceAll(',', '').trim();
      final stock = int.tryParse(stockStr);

      final esValido = errores.isEmpty;
      if (esValido) {
        filasValidas++;
      } else {
        filasConError++;
      }

      filasParsed.add(ProductoCsvFila(
        fila: i + 2, // 1-based, +1 por cabecera
        nombre: nombre.isEmpty ? '(sin nombre)' : nombre,
        categoria: categoria,
        precio: precio < 0 ? 0 : precio,
        descripcion: descripcion,
        ivaPorcentaje: iva,
        sku: sku,
        codigoBarras: cb,
        stock: stock,
        errores: errores,
        esValido: esValido,
      ));
    }

    return ResultadoParseoProductos(
      columnas: cabeceras,
      filas: filasParsed,
      mapeoColumnas: mapeo,
      totalFilas: filasParsed.length,
      filasValidas: filasValidas,
      filasConError: filasConError,
      separador: separador,
    );
  }

  // ── Genera CSV de plantilla ─────────────────────────────────────────────────
  static String generarPlantilla() {
    const lineas = [
      'nombre,categoria,precio,descripcion,iva,sku,codigo_barras,stock',
      'Coca-Cola 33cl,Bebidas,1.50,Refresco de cola,10,COCA33,5449000000996,100',
      'Cerveza Estrella 33cl,Bebidas,2.00,Cerveza nacional,10,CERV33,8410793504039,200',
      'Café solo,Cafetería,1.20,Café espresso,10,CAFE01,,',
      'Jamón serrano,Tapas,3.50,Ración de jamón ibérico,10,JAM01,,50',
    ];
    return lineas.join('\n');
  }
}


import 'dart:typed_data';
import 'package:csv/csv.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CSV UNIVERSAL — válido para todos los tipos de negocio
//
// OBLIGATORIOS:  nombre, precio
// OPCIONALES:    todo lo demás (se ignora si está vacío)
//
// Sectores cubiertos con aliases:
//   Restaurante/Bar  → alergenos, destino (cocina|barra)
//   Peluquería       → duracion_minutos, tipo=servicio
//   Tienda retail    → codigo_barras, stock, coste, precio_web
//   Editorial        → autor, isbn, coleccion, paginas, ano_publicacion, idioma, formato
//   Estética/spa     → duracion_minutos, tipo=servicio
//   Farmacia         → codigo_barras, sku, stock, principio_activo
//   Cualquier otro   → cualquier columna no reconocida → atributos_extra
// ─────────────────────────────────────────────────────────────────────────────

class ProductoCsvFila {
  final int fila;
  final String nombre;
  final String categoria;
  final double precio;
  final String tipo;           // 'producto' | 'servicio'
  final String? descripcion;
  final double ivaPorcentaje;
  final String? sku;
  final String? codigoBarras;
  final int? stock;
  final double? coste;
  final double? precioWeb;
  final int? duracionMinutos;
  final bool activo;
  final bool destacado;
  final String? destino;       // 'cocina' | 'barra'
  final List<String> alergenos;
  final List<String> etiquetas;
  final Map<String, String> atributosExtra; // autor, isbn, paginas, idioma, etc.
  final List<String> errores;
  final bool esValido;

  const ProductoCsvFila({
    required this.fila,
    required this.nombre,
    required this.categoria,
    required this.precio,
    this.tipo = 'producto',
    this.descripcion,
    this.ivaPorcentaje = 21,
    this.sku,
    this.codigoBarras,
    this.stock,
    this.coste,
    this.precioWeb,
    this.duracionMinutos,
    this.activo = true,
    this.destacado = false,
    this.destino,
    this.alergenos = const [],
    this.etiquetas = const [],
    this.atributosExtra = const {},
    required this.errores,
    required this.esValido,
  });
}

class ResultadoParseoProductos {
  final List<String> columnas;
  final List<ProductoCsvFila> filas;
  final Map<String, int> mapeoColumnas;
  final int totalFilas;
  final int filasValidas;
  final int filasConError;
  final String separador;
  final List<String> columnasExtra; // columnas no reconocidas → atributos_extra

  const ResultadoParseoProductos({
    required this.columnas,
    required this.filas,
    required this.mapeoColumnas,
    required this.totalFilas,
    required this.filasValidas,
    required this.filasConError,
    required this.separador,
    this.columnasExtra = const [],
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PARSER UNIVERSAL
// ─────────────────────────────────────────────────────────────────────────────

class CatalogoCsvParser {

  // Campos estándar con todos sus aliases posibles (minúsculas normalizadas)
  static const Map<String, List<String>> _aliasColumnas = {
    // ── OBLIGATORIOS ──────────────────────────────────────────────────────
    'nombre': [
      'nombre', 'name', 'titulo', 'title', 'producto', 'articulo',
      'article', 'descripcion_producto', 'product_name', 'item',
    ],
    'precio': [
      'precio', 'price', 'pvp', 'importe', 'precio_venta', 'sale_price',
      'precio_uni', 'precio_unitario', 'pvp_venta', 'precio_publico',
    ],
    // ── TIPOLOGÍA ─────────────────────────────────────────────────────────
    'tipo': [
      'tipo', 'type', 'clase', 'modalidad',
    ],
    'categoria': [
      'categoria', 'category', 'familia', 'family', 'grupo', 'group',
      'seccion', 'section', 'genero', 'genre', 'coleccion_catalogo',
      'linea', 'line', 'departamento',
    ],
    'iva': [
      'iva', 'vat', 'tax', 'impuesto', 'tipo_iva', 'iva_%', '%iva',
      'porcentaje_iva', 'iva_porcentaje',
    ],
    'activo': [
      'activo', 'active', 'disponible', 'available', 'publicado',
      'habilitado', 'enabled', 'visible',
    ],
    'destacado': [
      'destacado', 'featured', 'oferta', 'especial', 'novedad',
    ],
    // ── DESCRIPCIÓN ───────────────────────────────────────────────────────
    'descripcion': [
      'descripcion', 'description', 'detalle', 'detail', 'obs',
      'observaciones', 'notas', 'sinopsis', 'synopsis', 'resumen',
      'summary', 'texto',
    ],
    // ── IDENTIFICACIÓN ────────────────────────────────────────────────────
    'sku': [
      'sku', 'referencia', 'ref', 'codigo', 'code', 'id_producto',
      'product_id', 'cod_interno', 'referencia_interna', 'ref_interna',
      'articulo_id',
    ],
    'codigo_barras': [
      'codigo_barras', 'barcode', 'ean', 'ean13', 'ean8', 'upc', 'gtin',
      'isbn', 'isbn13', 'isbn10', 'issn', 'codigo_producto',
    ],
    // ── INVENTARIO / PRECIOS ──────────────────────────────────────────────
    'stock': [
      'stock', 'cantidad', 'quantity', 'existencias', 'inventory',
      'unidades', 'units', 'disponibilidad', 'ejemplares',
    ],
    'coste': [
      'coste', 'costo', 'cost', 'precio_coste', 'precio_compra',
      'coste_unitario', 'purchase_price', 'precio_neto', 'net_price',
      'precio_proveedor',
    ],
    'precio_web': [
      'precio_web', 'web_price', 'precio_online', 'online_price',
      'precio_ecommerce', 'precio_tienda',
    ],
    // ── SERVICIOS ─────────────────────────────────────────────────────────
    'duracion_minutos': [
      'duracion_minutos', 'duracion', 'duration', 'minutos', 'minutes',
      'tiempo', 'time', 'duracion_min', 'tiempo_servicio',
    ],
    // ── RESTAURACIÓN ─────────────────────────────────────────────────────
    'destino': [
      'destino', 'destination', 'impresora', 'printer', 'zona',
      'area', 'seccion_tpv',
    ],
    'alergenos': [
      'alergenos', 'alergeno', 'alergen', 'allergens', 'allergen',
      'alergias', 'allergies',
    ],
    // ── ETIQUETAS ─────────────────────────────────────────────────────────
    'etiquetas': [
      'etiquetas', 'tags', 'labels', 'marcas', 'atributos',
      'keywords', 'palabras_clave',
    ],
  };

  // Campos que van a atributos_extra (sectoriales conocidos)
  // Se guardan tal cual en el mapa extra, con su nombre normalizado
  static const Set<String> _camposExtra = {
    // Editorial / libros
    'autor', 'autores', 'author', 'authors', 'escritor',
    'coleccion', 'serie', 'collection', 'series',
    'paginas', 'pagina', 'pages', 'num_paginas',
    'ano', 'año', 'ano_publicacion', 'year', 'fecha_publicacion',
    'ano_edicion', 'edicion', 'edition',
    'idioma', 'language', 'lengua',
    'formato', 'format', 'encuadernacion', 'binding',
    'editorial_nombre', 'publisher', 'sello',
    'traductor', 'translator', 'ilustrador', 'illustrator',
    // Farmacia / salud
    'principio_activo', 'active_ingredient', 'laboratorio', 'laboratory',
    'presentacion', 'presentation', 'cn', 'nregistro',
    // Moda / ropa
    'talla', 'size', 'color', 'colour', 'material', 'tejido', 'fabric',
    'temporada', 'season', 'genero_ropa', 'coleccion_moda',
    // Alimentación / supermercado
    'marca', 'brand', 'peso', 'weight', 'volumen', 'volume',
    'calorias', 'calories', 'pais_origen', 'origin', 'proveedor',
    'fecha_caducidad', 'expiry',
    // Hostelería / menú
    'ingredientes', 'ingredients', 'receta', 'recipe',
    // General
    'modelo', 'model', 'fabricante', 'manufacturer', 'garantia',
    'warranty', 'origen', 'dimensiones', 'dimensions', 'peso_kg',
  };

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

  static String _norm(String s) =>
      s.toLowerCase().trim()
          .replaceAll(RegExp(r'[\s\-]+'), '_')
          .replaceAll(RegExp(r'[áàä]'), 'a')
          .replaceAll(RegExp(r'[éèë]'), 'e')
          .replaceAll(RegExp(r'[íìï]'), 'i')
          .replaceAll(RegExp(r'[óòö]'), 'o')
          .replaceAll(RegExp(r'[úùü]'), 'u')
          .replaceAll('ñ', 'n')
          .replaceAll(RegExp(r'[^a-z0-9_]'), '');

  static Map<String, int> _detectarMapeo(List<String> cabeceras) {
    final mapeo = <String, int>{};
    for (int i = 0; i < cabeceras.length; i++) {
      final cab = _norm(cabeceras[i]);
      for (final entry in _aliasColumnas.entries) {
        if (mapeo.containsKey(entry.key)) continue;
        if (entry.value.any((alias) => cab == _norm(alias))) {
          mapeo[entry.key] = i;
          break;
        }
      }
    }
    return mapeo;
  }

  /// Columnas no reconocidas como estándar ni como extra conocido
  static List<String> _columnasNoReconocidas(
      List<String> cabeceras, Map<String, int> mapeo) {
    final usadas = mapeo.values.toSet();
    final extras = <String>[];
    for (int i = 0; i < cabeceras.length; i++) {
      if (usadas.contains(i)) continue;
      extras.add(cabeceras[i]);
    }
    return extras;
  }

  static List<String> _parsearLista(String raw) {
    if (raw.isEmpty) return [];
    final sep = raw.contains(';') ? ';' : ',';
    return raw.split(sep).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  static ResultadoParseoProductos parsear(Uint8List bytes) {
    String contenido;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      contenido = String.fromCharCodes(bytes.sublist(3));
    } else {
      contenido = String.fromCharCodes(bytes);
    }

    final separador = _detectarSeparador(contenido);
    final converter = CsvToListConverter(
      fieldDelimiter: separador, eol: '\n', shouldParseNumbers: false,
    );

    List<List<dynamic>> filasCsv;
    try {
      filasCsv = converter.convert(contenido.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));
    } catch (_) {
      filasCsv = contenido
          .split('\n')
          .map((l) => l.split(separador).cast<dynamic>().toList())
          .toList();
    }

    if (filasCsv.isEmpty) {
      return const ResultadoParseoProductos(
        columnas: [], filas: [], mapeoColumnas: {},
        totalFilas: 0, filasValidas: 0, filasConError: 0, separador: ',',
      );
    }

    final cabeceras = filasCsv.first.map((e) => e.toString().trim()).toList();
    final mapeo = _detectarMapeo(cabeceras);
    final columnasExtra = _columnasNoReconocidas(cabeceras, mapeo);
    final filasData = filasCsv.skip(1).toList();

    final filasParsed = <ProductoCsvFila>[];
    int filasValidas = 0;
    int filasConError = 0;

    for (int i = 0; i < filasData.length; i++) {
      final row = filasData[i];
      if (row.every((c) => c.toString().trim().isEmpty)) continue;

      String get(String campo) {
        final idx = mapeo[campo];
        if (idx == null || idx >= row.length) return '';
        return row[idx].toString().trim();
      }

      final errores = <String>[];

      // ── OBLIGATORIOS ──────────────────────────────────────────────────────
      final nombre = get('nombre');
      if (nombre.isEmpty) errores.add('Falta el nombre');

      final precioStr = get('precio').replaceAll(',', '.').replaceAll('€', '').trim();
      final precio = double.tryParse(precioStr) ?? -1;
      if (precio < 0) errores.add('Precio inválido: "${get('precio')}"');

      // ── TIPOLOGÍA ─────────────────────────────────────────────────────────
      final tipoRaw = get('tipo').toLowerCase();
      final tipo = tipoRaw == 'servicio' ? 'servicio' : 'producto';

      final categoria = get('categoria').isEmpty ? 'General' : get('categoria');

      final ivaStr = get('iva').replaceAll('%', '').replaceAll(',', '.').trim();
      final iva = double.tryParse(ivaStr) ?? 21.0;
      if (ivaStr.isNotEmpty && ![0.0, 4.0, 10.0, 21.0].contains(iva)) {
        errores.add('IVA debe ser 0, 4, 10 o 21 (recibido: $ivaStr)');
      }

      final activoRaw = get('activo').toLowerCase();
      final activo = activoRaw != 'false' && activoRaw != 'no' && activoRaw != '0';

      final destacadoRaw = get('destacado').toLowerCase();
      final destacado =
          destacadoRaw == 'true' || destacadoRaw == 'si' || destacadoRaw == '1';

      // ── OPCIONALES ────────────────────────────────────────────────────────
      final descripcion = get('descripcion').isEmpty ? null : get('descripcion');
      final sku = get('sku').isEmpty ? null : get('sku');
      final cb = get('codigo_barras').isEmpty ? null : get('codigo_barras');

      final stockStr = get('stock').replaceAll('.', '').replaceAll(',', '').trim();
      final stock = stockStr.isEmpty ? null : int.tryParse(stockStr);

      final costeStr = get('coste').replaceAll(',', '.').replaceAll('€', '').trim();
      final coste = costeStr.isEmpty ? null : double.tryParse(costeStr);

      final precioWebStr =
          get('precio_web').replaceAll(',', '.').replaceAll('€', '').trim();
      final precioWeb = precioWebStr.isEmpty ? null : double.tryParse(precioWebStr);

      final durStr = get('duracion_minutos').replaceAll(',', '').trim();
      final duracion = durStr.isEmpty ? null : int.tryParse(durStr);

      final destinoRaw = get('destino').toLowerCase();
      final destino = destinoRaw.isEmpty ? null :
          (destinoRaw.contains('barra') ? 'barra' : 'cocina');

      final alergenos = _parsearLista(get('alergenos'));
      final etiquetas = _parsearLista(get('etiquetas'));

      // ── ATRIBUTOS EXTRA (sectoriales + columnas libres) ───────────────────
      final extra = <String, String>{};

      // Columnas "extra conocidas" (editorial, farmacia, moda…)
      for (int j = 0; j < cabeceras.length; j++) {
        if (mapeo.values.contains(j)) continue; // ya mapeado a campo estándar
        final cab = cabeceras[j];
        final cNorm = _norm(cab);
        if (_camposExtra.contains(cNorm) || columnasExtra.contains(cab)) {
          final val = j < row.length ? row[j].toString().trim() : '';
          if (val.isNotEmpty) extra[cNorm] = val;
        }
      }

      final esValido = errores.isEmpty;
      esValido ? filasValidas++ : filasConError++;

      filasParsed.add(ProductoCsvFila(
        fila: i + 2,
        nombre: nombre.isEmpty ? '(sin nombre)' : nombre,
        categoria: categoria,
        precio: precio < 0 ? 0 : precio,
        tipo: tipo,
        descripcion: descripcion,
        ivaPorcentaje: iva,
        sku: sku,
        codigoBarras: cb,
        stock: stock,
        coste: coste,
        precioWeb: precioWeb,
        duracionMinutos: duracion,
        activo: activo,
        destacado: destacado,
        destino: destino,
        alergenos: alergenos,
        etiquetas: etiquetas,
        atributosExtra: extra,
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
      columnasExtra: columnasExtra,
    );
  }

  // ── Plantillas por sector ───────────────────────────────────────────────────

  /// Plantilla base universal (campos más comunes)
  static String generarPlantilla() {
    const lineas = [
      'nombre,categoria,precio,tipo,iva_porcentaje,descripcion,sku,codigo_barras,stock,coste,precio_web,duracion_minutos,activo,destacado,alergenos,etiquetas,destino',
      'Coca-Cola 33cl,Bebidas,1.50,producto,10,Refresco de cola,COCA33,5449000000996,100,0.60,,,true,false,,sin_gluten,barra',
      'Café solo,Cafetería,1.20,producto,10,Café espresso,CAFE01,,,0.30,,,true,false,,,cocina',
      'Corte de cabello,Cabello,25.00,servicio,21,Corte y peinado,COR001,,,,, 45,true,false,,,',
    ];
    return lineas.join('\n');
  }

  /// Plantilla para editorial / librería
  static String generarPlantillaEditorial() {
    const lineas = [
      'nombre,autor,categoria,precio,iva_porcentaje,isbn,descripcion,paginas,ano_publicacion,idioma,formato,coleccion,stock,sku,activo',
      'El nombre de la rosa,Umberto Eco,Novela histórica,18.95,4,9788435014243,Un monje investiga una serie de crímenes en una abadía medieval,680,1980,Español,Tapa blanda,Narrativa Contemporánea,50,NAZ001,true',
      'Rayuela,Julio Cortázar,Literatura latinoamericana,16.50,4,9788437604947,Una de las obras más importantes del boom latinoamericano,600,1963,Español,Tapa blanda,Clásicos,30,NAZ002,true',
      'Cien años de soledad,Gabriel García Márquez,Realismo mágico,17.90,4,9788437604930,La saga de la familia Buendía,432,1967,Español,Tapa dura,Premio Nobel,25,NAZ003,true',
    ];
    return lineas.join('\n');
  }

  /// Plantilla para restaurante / bar
  static String generarPlantillaRestaurante() {
    const lineas = [
      'nombre,categoria,precio,tipo,iva_porcentaje,descripcion,sku,alergenos,activo,destacado,destino',
      'Paella valenciana,Arroces,14.50,producto,10,Paella con pollo y verduras (2 personas),PAE001,gluten;marisco,true,true,cocina',
      'Cerveza Estrella,Bebidas,2.50,producto,10,Cerveza nacional 33cl,CER001,,true,false,barra',
      'Café con leche,Cafetería,1.80,producto,10,Café con leche entera,CAF001,,true,false,barra',
      'Chuletón 500g,Carnes,22.00,producto,10,Chuletón de buey madurado 500g,CHU001,,true,true,cocina',
    ];
    return lineas.join('\n');
  }

  /// Plantilla para peluquería / estética
  static String generarPlantillaPeluqueria() {
    const lineas = [
      'nombre,categoria,precio,tipo,iva_porcentaje,descripcion,sku,duracion_minutos,activo',
      'Corte de cabello mujer,Cortes,35.00,servicio,21,Corte y secado incluido,COR001,60,true',
      'Coloración completa,Color,65.00,servicio,21,Tinte + lavado + secado,COL001,120,true',
      'Manicura completa,Uñas,25.00,servicio,21,Limado, cutículas y esmalte,MAN001,45,true',
      'Tratamiento hidratante,Tratamientos,40.00,servicio,21,Mascarilla + secado,TRA001,60,true',
    ];
    return lineas.join('\n');
  }

  /// Plantilla para tienda retail / moda
  static String generarPlantillaTienda() {
    const lineas = [
      'nombre,categoria,precio,tipo,iva_porcentaje,descripcion,sku,codigo_barras,stock,coste,precio_web,marca,talla,color,material,activo',
      'Camiseta básica blanca,Camisetas,19.95,producto,21,Camiseta 100% algodón orgánico,CAM001,8412345000001,50,8.00,17.95,Zara,M,Blanco,Algodón,true',
      'Vaquero slim fit azul,Pantalones,59.95,producto,21,Vaquero de corte slim,VAQ001,8412345000002,30,22.00,54.95,H&M,42,Azul,Denim,true',
    ];
    return lineas.join('\n');
  }

  /// Plantilla para farmacia / parafarmacia
  static String generarPlantillaFarmacia() {
    const lineas = [
      'nombre,categoria,precio,tipo,iva_porcentaje,descripcion,sku,codigo_barras,stock,coste,cn,laboratorio,principio_activo,activo',
      'Ibuprofeno 600mg 20 comp,Analgésicos,4.50,producto,4,Antiinflamatorio no esteroideo,IBU600,8470003479001,100,2.10,347900,Kern Pharma,Ibuprofeno,true',
      'Crema hidratante facial,Cosmética,12.95,producto,21,Crema hidratante para piel seca,COS001,8412345001001,50,5.50,,,Nivea,,true',
    ];
    return lineas.join('\n');
  }
}

import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';
import 'catalogo_csv_parser.dart';

// ── MODELOS DE VALIDACIÓN ─────────────────────────────────────────────────────

class FilaImportacion {
  final int numero;
  final Map<String, String> datos;
  final List<String> errores;
  bool valida;

  FilaImportacion({
    required this.numero,
    required this.datos,
    List<String>? errores,
    this.valida = true,
  }) : errores = errores ?? [];
}

class ResultadoImportacion {
  final int importados;
  final int errores;
  final List<FilaImportacion> filasConError;

  const ResultadoImportacion({
    required this.importados,
    required this.errores,
    required this.filasConError,
  });
}

// ── SERVICIO ──────────────────────────────────────────────────────────────────

class ImportacionCatalogoService {
  final _db = FirebaseFirestore.instance;

  // ── PLANTILLA CSV ─────────────────────────────────────────────────────────

  /// Plantilla universal — solo nombre y precio son obligatorios.
  String generarPlantillaCsv() {
    const converter = ListToCsvConverter();
    final filas = [
      [
        'nombre',         // OBLIGATORIO
        'precio',         // OBLIGATORIO
        'tipo',           // producto | servicio  (default: producto)
        'categoria',      // (default: General)
        'iva_porcentaje', // 0 / 4 / 10 / 21      (default: 21)
        'descripcion',
        'sku',
        'codigo_barras',  // también acepta: isbn, ean, barcode
        'stock',
        'coste',
        'precio_web',
        'duracion_minutos',
        'activo',         // true | false          (default: true)
        'destacado',      // true | false          (default: false)
        'alergenos',      // separados por ; ej: gluten;leche
        'etiquetas',      // separados por ; ej: vegano;sin_gluten
        'destino',        // cocina | barra  (solo restaurantes)
      ],
      // Producto normal (tienda/restaurante)
      ['Café con leche', '1.80', 'producto', 'Bebidas', '10',
       'Café con leche entera', 'CAF001', '', '', '0.30', '', '', 'true', 'false', '', '', 'barra'],
      // Servicio (peluquería/estética)
      ['Corte de cabello', '25.00', 'servicio', 'Cabello', '21',
       'Corte y peinado', 'COR001', '', '', '', '', '45', 'true', 'false', '', '', ''],
      // Producto con código de barras (retail)
      ['Camiseta blanca M', '19.95', 'producto', 'Ropa', '21',
       'Camiseta algodón 100%', 'CAM001', '8412345678901', '50', '8.00', '17.95', '', 'true', 'false', '', '', ''],
      // Libro (editorial) — isbn en columna codigo_barras; autor va como columna extra
      ['El nombre de la rosa', '18.95', 'producto', 'Novela histórica', '4',
       'Un monje investiga crímenes en una abadía', 'NAZ001', '9788435014243', '30', '', '', '', 'true', 'true', '', '', ''],
    ];
    return converter.convert(filas);
  }

  // ── PARSEAR CSV ───────────────────────────────────────────────────────────

  List<FilaImportacion> parsearCsv(String contenido) {
    final bytes = Uint8List.fromList(contenido.codeUnits);
    final resultado = CatalogoCsvParser.parsear(bytes);
    return resultado.filas.map((f) {
      final datos = <String, String>{
        'nombre':             f.nombre,
        'precio':             f.precio.toString(),
        'tipo':               f.tipo,
        'categoria':          f.categoria,
        'iva_porcentaje':     f.ivaPorcentaje.toString(),
        'descripcion':        f.descripcion ?? '',
        'sku':                f.sku ?? '',
        'codigo_barras':      f.codigoBarras ?? '',
        'stock':              f.stock?.toString() ?? '',
        'coste':              f.coste?.toString() ?? '',
        'precio_web':         f.precioWeb?.toString() ?? '',
        'duracion_minutos':   f.duracionMinutos?.toString() ?? '',
        'activo':             f.activo.toString(),
        'destacado':          f.destacado.toString(),
        'alergenos':          f.alergenos.join(';'),
        'etiquetas':          f.etiquetas.join(';'),
        'destino':            f.destino ?? '',
        ..._extraComoStrings(f.atributosExtra),
      };
      return FilaImportacion(
        numero: f.fila,
        datos: datos,
        errores: List<String>.from(f.errores),
        valida: f.esValido,
      );
    }).toList();
  }

  Map<String, String> _extraComoStrings(Map<String, dynamic> extra) =>
      extra.map((k, v) => MapEntry(k, v.toString()));

  // ── VALIDAR ───────────────────────────────────────────────────────────────

  List<FilaImportacion> validar(
      List<FilaImportacion> filas, Set<String> skusExistentes) {
    final skusEnImportacion = <String>{};

    for (final fila in filas) {
      // El parser ya validó nombre y precio; solo revalidamos duplicados de SKU
      final sku = fila.datos['sku'] ?? '';
      if (sku.isNotEmpty) {
        if (skusExistentes.contains(sku)) {
          fila.errores.add('SKU "$sku" ya existe en el catálogo');
          fila.valida = false;
        } else if (skusEnImportacion.contains(sku)) {
          fila.errores.add('SKU "$sku" duplicado en el CSV');
          fila.valida = false;
        } else {
          skusEnImportacion.add(sku);
        }
      }
    }

    return filas;
  }

  // ── IMPORTAR ──────────────────────────────────────────────────────────────

  /// Importa en batches de 500. Devuelve el resultado.
  /// [onProgreso] recibe un valor 0.0-1.0.
  Future<ResultadoImportacion> importar({
    required String empresaId,
    required List<FilaImportacion> filas,
    bool reemplazar = false,
    ValueChanged<double>? onProgreso,
  }) async {
    final validas = filas.where((f) => f.valida).toList();
    final conError = filas.where((f) => !f.valida).toList();

    if (reemplazar) {
      // Eliminar todos los productos existentes
      await _eliminarCatalogo(empresaId);
    }

    // Obtener/crear categorías existentes
    final categoriasExistentes = await _obtenerCategorias(empresaId);

    int importados = 0;
    const batchSize = 500;

    for (int inicio = 0; inicio < validas.length; inicio += batchSize) {
      final lote =
          validas.sublist(inicio, (inicio + batchSize).clamp(0, validas.length));
      final batch = _db.batch();

      for (final fila in lote) {
        final ref = _db
            .collection('empresas')
            .doc(empresaId)
            .collection('catalogo')
            .doc();

        String? _d(String k) {
          final v = fila.datos[k]?.trim();
          return (v == null || v.isEmpty) ? null : v;
        }

        final nombre    = fila.datos['nombre']!;
        final categoria = _d('categoria') ?? 'General';
        final precio    = double.parse(fila.datos['precio']!.replaceAll(',', '.'));
        final iva       = double.tryParse(fila.datos['iva_porcentaje'] ?? '') ?? 21;
        final activo    = (fila.datos['activo'] ?? 'true').toLowerCase() != 'false';
        final destacado = (fila.datos['destacado'] ?? 'false').toLowerCase() == 'true';

        final duracion    = int.tryParse(fila.datos['duracion_minutos'] ?? '');
        final stockVal    = int.tryParse(fila.datos['stock'] ?? '');
        final costeVal    = double.tryParse(fila.datos['coste']?.replaceAll(',', '.') ?? '');
        final precioWebVal= double.tryParse(fila.datos['precio_web']?.replaceAll(',', '.') ?? '');

        final destinoRaw  = _d('destino')?.toLowerCase();
        final destino     = (destinoRaw == 'barra' || destinoRaw == 'cocina') ? destinoRaw : null;

        List<String> _lista(String k) =>
            (fila.datos[k] ?? '').split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

        final alergenos = _lista('alergenos');
        final etiquetas = _lista('etiquetas');

        // Atributos extra: cualquier clave no estándar que esté en datos
        final camposEstandar = {
          'nombre', 'precio', 'tipo', 'categoria', 'iva_porcentaje', 'descripcion',
          'sku', 'codigo_barras', 'stock', 'coste', 'precio_web', 'duracion_minutos',
          'activo', 'destacado', 'alergenos', 'etiquetas', 'destino',
        };
        final atributosExtra = <String, dynamic>{};
        if (costeVal != null) atributosExtra['coste'] = costeVal;
        for (final entry in fila.datos.entries) {
          if (!camposEstandar.contains(entry.key) && entry.value.isNotEmpty) {
            atributosExtra[entry.key] = entry.value;
          }
        }

        if (!categoriasExistentes.contains(categoria)) {
          categoriasExistentes.add(categoria);
        }

        final productoData = Producto(
          id: ref.id,
          empresaId: empresaId,
          nombre: nombre,
          descripcion: _d('descripcion'),
          categoria: categoria,
          precio: precio,
          ivaPorcentaje: iva,
          duracionMinutos: duracion,
          sku: _d('sku'),
          codigoBarras: _d('codigo_barras'),
          stock: stockVal,
          activo: activo,
          destacado: destacado,
          destino: destino,
          precioWeb: precioWebVal,
          alergenos: alergenos,
          etiquetas: etiquetas,
          atributosExtra: atributosExtra,
          variantes: const [],
          fechaCreacion: DateTime.now(),
        ).toFirestore();

        batch.set(ref, productoData);
      }

      await batch.commit();
      importados += lote.length;
      onProgreso?.call(importados / validas.length);
    }

    return ResultadoImportacion(
      importados: importados,
      errores: conError.length,
      filasConError: conError,
    );
  }

  // ── GENERAR CSV DE ERRORES ────────────────────────────────────────────────

  String generarCsvErrores(List<FilaImportacion> filasConError) {
    const converter = ListToCsvConverter();
    final filas = [
      ['fila', 'nombre', 'categoria', 'precio', 'errores'],
      ...filasConError.map((f) => [
            f.numero.toString(),
            f.datos['nombre'] ?? '',
            f.datos['categoria'] ?? '',
            f.datos['precio'] ?? '',
            f.errores.join('; '),
          ]),
    ];
    return converter.convert(filas);
  }

  // ── PRIVADOS ──────────────────────────────────────────────────────────────

  Future<void> _eliminarCatalogo(String empresaId) async {
    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('catalogo')
        .get();

    const batchSize = 500;
    for (int i = 0; i < snap.docs.length; i += batchSize) {
      final batch = _db.batch();
      final lote = snap.docs.sublist(
          i, (i + batchSize).clamp(0, snap.docs.length));
      for (final doc in lote) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  Future<Set<String>> _obtenerCategorias(String empresaId) async {
    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('catalogo')
        .get();
    return snap.docs
        .map((d) => (d.data()['categoria'] as String?) ?? 'General')
        .toSet();
  }

  Future<Set<String>> obtenerSkusExistentes(String empresaId) async {
    final snap = await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('catalogo')
        .get();
    return snap.docs
        .map((d) => (d.data()['sku'] as String?) ?? '')
        .where((s) => s.isNotEmpty)
        .toSet();
  }
}




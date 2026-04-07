import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:planeag_flutter/domain/modelos/pedido.dart';

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

  /// Genera el contenido CSV de la plantilla de ejemplo.
  String generarPlantillaCsv() {
    const converter = ListToCsvConverter();
    final filas = [
      // Cabecera
      [
        'nombre',
        'tipo',
        'categoria',
        'precio',
        'iva_porcentaje',
        'duracion_minutos',
        'descripcion',
        'sku',
        'codigo_barras',
        'activo',
      ],
      // Ejemplos
      ['Café con leche', 'producto', 'Bebidas', '1.80', '10', '', 'Café con leche entera', 'CAF001', '', 'true'],
      ['Corte de cabello', 'servicio', 'Cabello', '25.00', '21', '45', 'Corte y lavado incluido', 'COR001', '', 'true'],
      ['Chuletón 500g', 'producto', 'Carnes', '18.50', '10', '', 'Chuletón de buey 500g', 'CHU001', '8412345678901', 'true'],
      ['Masaje relajante', 'servicio', 'Masajes', '50.00', '21', '60', 'Masaje corporal completo', 'MAS001', '', 'true'],
    ];
    return converter.convert(filas);
  }

  // ── PARSEAR CSV ───────────────────────────────────────────────────────────

  List<FilaImportacion> parsearCsv(String contenido) {
    const converter = CsvToListConverter(eol: '\n', fieldDelimiter: ',');
    List<List<dynamic>> filas;
    try {
      filas = converter.convert(contenido.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));
    } catch (e) {
      throw Exception('Error al parsear CSV: $e');
    }

    if (filas.isEmpty) return [];

    // Primera fila = cabeceras
    final cabeceras = filas.first
        .map((c) => c.toString().trim().toLowerCase())
        .toList();

    return filas
        .skip(1)
        .toList()
        .asMap()
        .entries
        .where((e) => e.value.any((c) => c.toString().trim().isNotEmpty))
        .map((e) {
          final fila = e.value;
          final datos = <String, String>{};
          for (int i = 0; i < cabeceras.length; i++) {
            datos[cabeceras[i]] = i < fila.length ? fila[i].toString().trim() : '';
          }
          return FilaImportacion(numero: e.key + 2, datos: datos);
        })
        .toList();
  }

  // ── VALIDAR ───────────────────────────────────────────────────────────────

  List<FilaImportacion> validar(
      List<FilaImportacion> filas, Set<String> skusExistentes) {
    final skusEnImportacion = <String>{};

    for (final fila in filas) {
      final errores = <String>[];

      // nombre obligatorio
      if ((fila.datos['nombre'] ?? '').isEmpty) {
        errores.add('Nombre vacío');
      }

      // tipo
      final tipo = fila.datos['tipo']?.toLowerCase() ?? '';
      if (tipo.isNotEmpty && tipo != 'producto' && tipo != 'servicio') {
        errores.add('Tipo debe ser "producto" o "servicio"');
      }

      // precio
      final precioStr = fila.datos['precio'] ?? '';
      final precio = double.tryParse(precioStr.replaceAll(',', '.'));
      if (precioStr.isEmpty) {
        errores.add('Precio vacío');
      } else if (precio == null || precio < 0) {
        errores.add('Precio inválido: $precioStr');
      }

      // iva_porcentaje
      final ivaStr = fila.datos['iva_porcentaje'] ?? '';
      if (ivaStr.isNotEmpty) {
        final iva = double.tryParse(ivaStr);
        if (iva == null || ![0.0, 4.0, 10.0, 21.0].contains(iva)) {
          errores.add('IVA debe ser 0, 4, 10 o 21. Valor: $ivaStr');
        }
      }

      // duracion_minutos (solo para servicios)
      final duracionStr = fila.datos['duracion_minutos'] ?? '';
      if (duracionStr.isNotEmpty) {
        final dur = int.tryParse(duracionStr);
        if (dur == null || dur < 0) {
          errores.add('Duración inválida: $duracionStr');
        }
      }

      // SKU duplicado
      final sku = fila.datos['sku'] ?? '';
      if (sku.isNotEmpty) {
        if (skusExistentes.contains(sku)) {
          errores.add('SKU "$sku" ya existe en el catálogo');
        }
        if (skusEnImportacion.contains(sku)) {
          errores.add('SKU "$sku" duplicado en el CSV');
        } else {
          skusEnImportacion.add(sku);
        }
      }

      fila.errores
        ..clear()
        ..addAll(errores);
      fila.valida = errores.isEmpty;
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

        final nombre = fila.datos['nombre']!;
        final categoria =
            fila.datos['categoria']?.trim().isEmpty == true ||
                    fila.datos['categoria'] == null
                ? 'General'
                : fila.datos['categoria']!.trim();
        final precio =
            double.parse(fila.datos['precio']!.replaceAll(',', '.'));
        final iva = double.tryParse(fila.datos['iva_porcentaje'] ?? '') ?? 21;
        final duracion = int.tryParse(fila.datos['duracion_minutos'] ?? '');
        final sku = fila.datos['sku']?.trim().isEmpty == true
            ? null
            : fila.datos['sku']?.trim();
        final codigoBarras =
            fila.datos['codigo_barras']?.trim().isEmpty == true
                ? null
                : fila.datos['codigo_barras']?.trim();
        final activo =
            (fila.datos['activo'] ?? 'true').toLowerCase() != 'false';
        final descripcion = fila.datos['descripcion']?.trim().isEmpty == true
            ? null
            : fila.datos['descripcion']?.trim();

        // Crear categoría si no existe
        if (!categoriasExistentes.contains(categoria)) {
          categoriasExistentes.add(categoria);
        }

        final productoData = Producto(
          id: ref.id,
          empresaId: empresaId,
          nombre: nombre,
          descripcion: descripcion,
          categoria: categoria,
          precio: precio,
          ivaPorcentaje: iva,
          duracionMinutos: duracion,
          sku: sku,
          codigoBarras: codigoBarras,
          activo: activo,
          variantes: const [],
          etiquetas: const [],
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




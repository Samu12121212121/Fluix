import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/modelos/producto.dart';

/// Sincroniza automáticamente productos del catálogo de pedidos
/// con secciones web que tienen [catalogo_sync: true].
///
/// Flujo:
///   1. Al guardar un producto en pedidos, llamar a [sincronizarProducto].
///   2. El servicio busca secciones web con campo [catalogo_sync == true].
///   3. Añade o actualiza el item del producto en [contenido.items].
///   4. Los cambios se reflejan automáticamente en la web (script Hostinger).
class CatalogoWebSyncService {
  final _db = FirebaseFirestore.instance;

  // Activa la sincronización para una sección (llámalo desde Ajustes Web)
  Future<void> activarSincronizacion(String empresaId, String seccionId) async {
    await _db
        .collection('empresas').doc(empresaId)
        .collection('contenido_web').doc(seccionId)
        .update({
      'catalogo_sync': true,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  // Desactiva la sincronización de una sección
  Future<void> desactivarSincronizacion(String empresaId, String seccionId) async {
    await _db
        .collection('empresas').doc(empresaId)
        .collection('contenido_web').doc(seccionId)
        .update({
      'catalogo_sync': false,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  /// Sincroniza un producto con todas las secciones web vinculadas al catálogo.
  /// Llámalo después de crear/actualizar un producto en pedidos.
  Future<void> sincronizarProducto(String empresaId, Producto producto) async {
    try {
      final snap = await _db
          .collection('empresas').doc(empresaId)
          .collection('contenido_web')
          .where('catalogo_sync', isEqualTo: true)
          .get();

      if (snap.docs.isEmpty) return;

      for (final secDoc in snap.docs) {
        final data     = secDoc.data();
        final contenido = data['contenido'] as Map<String, dynamic>? ?? {};
        var items      = List<Map<String, dynamic>>.from(
            (contenido['items'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map)));

        final itemData = _productoToItem(producto);
        final idx      = items.indexWhere(
            (i) => i['producto_id'] == producto.id || i['nombre'] == producto.nombre);

        if (idx >= 0) {
          items[idx] = itemData;
        } else {
          items.add(itemData);
        }

        // Ordenar por categoría y nombre
        items.sort((a, b) {
          final catCmp = (a['categoria'] as String? ?? '')
              .compareTo(b['categoria'] as String? ?? '');
          if (catCmp != 0) return catCmp;
          return (a['nombre'] as String? ?? '')
              .compareTo(b['nombre'] as String? ?? '');
        });

        await _db
            .collection('empresas').doc(empresaId)
            .collection('contenido_web').doc(secDoc.id)
            .update({
          'contenido.items': items,
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // No interrumpir el flujo de guardado si falla la sincronización web
      debugPrint('⚠️ CatalogoWebSync: error sincronizando ${producto.id}: $e');
    }
  }

  /// Elimina un producto de todas las secciones web vinculadas.
  Future<void> eliminarProductoDeWeb(String empresaId, String productoId) async {
    try {
      final snap = await _db
          .collection('empresas').doc(empresaId)
          .collection('contenido_web')
          .where('catalogo_sync', isEqualTo: true)
          .get();

      for (final secDoc in snap.docs) {
        final data     = secDoc.data();
        final contenido = data['contenido'] as Map<String, dynamic>? ?? {};
        final items    = List<Map<String, dynamic>>.from(
            (contenido['items'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map)));

        final sinProducto = items.where((i) => i['producto_id'] != productoId).toList();
        if (sinProducto.length == items.length) continue;

        await _db
            .collection('empresas').doc(empresaId)
            .collection('contenido_web').doc(secDoc.id)
            .update({
          'contenido.items': sinProducto,
          'fecha_actualizacion': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('⚠️ CatalogoWebSync: error eliminando $productoId de web: $e');
    }
  }

  /// Importación masiva: sincroniza TODO el catálogo a una sección web.
  Future<void> importarCatalogoCompleto(
      String empresaId, String seccionId, List<Producto> productos) async {
    final items = productos
        .where((p) => p.activo)
        .map(_productoToItem)
        .toList();

    items.sort((a, b) {
      final catCmp = (a['categoria'] as String? ?? '')
          .compareTo(b['categoria'] as String? ?? '');
      if (catCmp != 0) return catCmp;
      return (a['nombre'] as String? ?? '')
          .compareTo(b['nombre'] as String? ?? '');
    });

    await _db
        .collection('empresas').doc(empresaId)
        .collection('contenido_web').doc(seccionId)
        .update({
      'contenido.items': items,
      'catalogo_sync': true,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  // Convierte un Producto al formato de item de sección web
  Map<String, dynamic> _productoToItem(Producto p) => {
    'producto_id': p.id,
    'nombre':      p.nombre,
    'descripcion': p.descripcion ?? '',
    'precio':      p.precio?.toStringAsFixed(2) ?? '',
    'imagen':      p.imagenUrl ?? '',
    'categoria':   p.categoria ?? 'General',
    'activo':      p.activo,
    'destacado':   p.destacado,
    'sku':         p.sku ?? '',
  };
}

void debugPrint(String s) => print(s);

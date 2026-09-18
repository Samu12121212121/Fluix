import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../domain/modelos/blog_post.dart';

// ═══════════════════════════════════════════════════════════════════════════
// BLOG SERVICE — repositorio multi-tenant
// Firestore path: empresas/{empresaId}/blog/{postId}
//                 empresas/{empresaId}/blog_categorias/{catId}
// ═══════════════════════════════════════════════════════════════════════════

class BlogService {
  static final BlogService _i = BlogService._();
  factory BlogService() => _i;
  BlogService._();

  final _fs  = FirebaseFirestore.instance;
  final _st  = FirebaseStorage.instance;
  final _pic = ImagePicker();

  // ── Colecciones ───────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _blogCol(String eId) =>
      _fs.collection('empresas').doc(eId).collection('blog');

  CollectionReference<Map<String, dynamic>> _catCol(String eId) =>
      _fs.collection('empresas').doc(eId).collection('blog_categorias');

  // ═════════════════════════════════════════════════════════════════════════
  // POSTS — LECTURA
  // ═════════════════════════════════════════════════════════════════════════

  /// Stream paginado de posts (no carga toda la colección).
  Stream<List<BlogPost>> listarBlogs(
    String empresaId, {
    EstadoBlog? estado,
    String? categoriaId,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) {
    var q = _blogCol(empresaId)
        .where('eliminado', isEqualTo: false)
        .orderBy('fecha_publicacion', descending: true)
        .limit(limit);

    if (estado != null) q = q.where('estado', isEqualTo: estado.valor);
    if (categoriaId != null) q = q.where('categoria_id', isEqualTo: categoriaId);
    if (startAfter != null) q = q.startAfterDocument(startAfter);

    return q.snapshots().map(
        (s) => s.docs.map(BlogPost.fromFirestore).toList());
  }

  Future<BlogPost?> obtenerBlog(String empresaId, String id) async {
    final doc = await _blogCol(empresaId).doc(id).get();
    return doc.exists ? BlogPost.fromFirestore(doc) : null;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // POSTS — ESCRITURA
  // ═════════════════════════════════════════════════════════════════════════

  Future<String> guardar(String empresaId, BlogPost post) async {
    final data = post.toFirestore();
    if (post.id.isEmpty) {
      final ref = await _blogCol(empresaId).add(data);
      return ref.id;
    } else {
      await _blogCol(empresaId).doc(post.id).set(data, SetOptions(merge: true));
      return post.id;
    }
  }

  /// Soft-delete: solo marca `eliminado: true`.
  Future<void> eliminar(String empresaId, String id) async {
    await _blogCol(empresaId).doc(id).update({
      'eliminado':        true,
      'fecha_eliminacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cambiarEstado(String empresaId, String id, EstadoBlog nuevoEstado) async {
    await _blogCol(empresaId).doc(id).update({
      'estado':              nuevoEstado.valor,
      'fecha_actualizacion': FieldValue.serverTimestamp(),
    });
  }

  /// Duplica un post — regenera slug y resetea estado a borrador.
  Future<String> duplicar(String empresaId, String id) async {
    final original = await obtenerBlog(empresaId, id);
    if (original == null) throw Exception('Post no encontrado');

    final baseSlug = '${original.slug}-copia';
    final slug = await _slugUnico(empresaId, baseSlug);

    final copia = original.copyWith(
      slug:  slug,
      titulo: '${original.titulo} (copia)',
      estado: EstadoBlog.borrador,
    );

    final ref = await _blogCol(empresaId).add({
      ...copia.toFirestore(),
      'fecha_creacion': FieldValue.serverTimestamp(),
      'visitas': 0,
    });
    return ref.id;
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SLUG
  // ═════════════════════════════════════════════════════════════════════════

  Future<bool> slugDisponible(String empresaId, String slug, {String? exceptId}) async {
    var q = _blogCol(empresaId)
        .where('slug', isEqualTo: slug)
        .where('eliminado', isEqualTo: false)
        .limit(1);
    final snap = await q.get();
    if (snap.docs.isEmpty) return true;
    if (exceptId != null && snap.docs.first.id == exceptId) return true;
    return false;
  }

  Future<String> _slugUnico(String empresaId, String base) async {
    if (await slugDisponible(empresaId, base)) return base;
    for (var i = 2; i < 20; i++) {
      final candidate = '$base-$i';
      if (await slugDisponible(empresaId, candidate)) return candidate;
    }
    return '$base-${DateTime.now().millisecondsSinceEpoch}';
  }

  // ═════════════════════════════════════════════════════════════════════════
  // CATEGORÍAS
  // ═════════════════════════════════════════════════════════════════════════

  Stream<List<BlogCategoria>> listarCategorias(String empresaId) =>
      _catCol(empresaId)
          .where('eliminado', isEqualTo: false)
          .orderBy('orden')
          .snapshots()
          .map((s) => s.docs.map(BlogCategoria.fromFirestore).toList());

  Future<void> guardarCategoria(String empresaId, BlogCategoria cat) async {
    final data = cat.toFirestore();
    if (cat.id.isEmpty) {
      await _catCol(empresaId).add(data);
    } else {
      await _catCol(empresaId).doc(cat.id).set(data, SetOptions(merge: true));
    }
  }

  /// Devuelve true si la categoría tiene posts asociados (no borrados).
  Future<bool> categoriaEnUso(String empresaId, String catId) async {
    final snap = await _blogCol(empresaId)
        .where('categoria_id', isEqualTo: catId)
        .where('eliminado', isEqualTo: false)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> eliminarCategoria(String empresaId, String catId) async {
    if (await categoriaEnUso(empresaId, catId)) {
      throw Exception('No se puede eliminar: hay artículos en esta categoría');
    }
    await _catCol(empresaId).doc(catId).update({'eliminado': true});
  }

  // ═════════════════════════════════════════════════════════════════════════
  // IMAGEN DESTACADA
  // ═════════════════════════════════════════════════════════════════════════

  Future<({String url, String? thumbnail})> subirImagenDestacada(
      String empresaId, String postId) async {
    final picked = await _pic.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked == null) throw Exception('Sin imagen seleccionada');

    final bytes = await picked.readAsBytes();

    // Comprimir y generar thumbnail antes de subir
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('No se pudo leer la imagen');

    final original = img.encodeJpg(img.copyResize(decoded, width: 1200), quality: 85);
    final thumbDecoded = img.copyResize(decoded, width: 400, height: 267);
    final thumb = img.encodeJpg(thumbDecoded, quality: 75);

    final ts = DateTime.now().millisecondsSinceEpoch;
    final basePath = 'empresas/$empresaId/blog/$postId';

    final origRef  = _st.ref().child('$basePath/imagen_$ts.jpg');
    final thumbRef = _st.ref().child('$basePath/thumb_$ts.jpg');

    await origRef.putData(Uint8List.fromList(original),
        SettableMetadata(contentType: 'image/jpeg'));
    await thumbRef.putData(Uint8List.fromList(thumb),
        SettableMetadata(contentType: 'image/jpeg'));

    final url   = await origRef.getDownloadURL();
    final tUrl  = await thumbRef.getDownloadURL();
    return (url: url, thumbnail: tUrl);
  }

  Future<void> subirImagenDesdeRuta(File file, String path) async {
    await _st.ref().child(path).putFile(file);
  }
}

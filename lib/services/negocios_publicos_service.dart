import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/negocio_publico_model.dart';

/// Servicio para gestionar negocios públicos en la colección `negocios_publicos`.
/// Solo accesible por el propietario de la plataforma.
class NegociosPublicosService {
  static final NegociosPublicosService _instance = NegociosPublicosService._();
  factory NegociosPublicosService() => _instance;
  NegociosPublicosService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Stream de todos los negocios públicos
  Stream<List<NegocioPublico>> obtenerTodos() {
    return _db
        .collection('negocios_publicos')
        .orderBy('nombre')
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => NegocioPublico.fromJson(doc.id, doc.data()))
        .toList());
  }

  /// Stream de negocios por categoría
  Stream<List<NegocioPublico>> obtenerPorCategoria(CategoriaNegocio categoria) {
    return _db
        .collection('negocios_publicos')
        .where('categoria', isEqualTo: categoria.name)
        .where('activo', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((doc) => NegocioPublico.fromJson(doc.id, doc.data()))
        .toList());
  }

  /// Obtener un negocio por ID
  Future<NegocioPublico?> obtenerPorId(String id) async {
    final doc = await _db.collection('negocios_publicos').doc(id).get();
    if (!doc.exists) return null;
    return NegocioPublico.fromJson(doc.id, doc.data()!);
  }

  /// Crear un nuevo negocio público
  Future<String> crear(NegocioPublico negocio) async {
    final docRef = await _db
        .collection('negocios_publicos')
        .add(negocio.toJson()..remove('id'));
    return docRef.id;
  }

  /// Actualizar un negocio existente
  /// USA set() con merge:true, NO update()
  /// Motivo: update() falla si un campo no existía antes en el documento.
  Future<void> actualizar(NegocioPublico negocio) async {
    await _db
        .collection('negocios_publicos')
        .doc(negocio.id)
        .set(negocio.toJson()..remove('id'), SetOptions(merge: true));
  }

  /// Eliminar un negocio
  Future<void> eliminar(String id) async {
    await _db.collection('negocios_publicos').doc(id).delete();
  }

  /// Subir foto de negocio a Firebase Storage.
  /// En Windows y Web usa putData (bytes) porque putFile no funciona
  /// correctamente con el SDK de Firebase C++ para desktop.
  Future<String> subirFoto(String negocioId, File archivo) async {
    final extension = archivo.path.split('.').last;
    final ref = _storage.ref('negocios_publicos/$negocioId/foto.$extension');

    // En Windows putFile falla con "User not authorized" por un bug del SDK.
    // Usar putData con bytes funciona correctamente en todas las plataformas.
    final bytes = await archivo.readAsBytes();
    final metadata = SettableMetadata(
      contentType: _contentTypeDesdeExtension(extension),
    );
    await ref.putData(bytes, metadata);

    final url = await ref.getDownloadURL();
    await _db.collection('negocios_publicos').doc(negocioId).update({
      'fotoUrl': url,
    });
    return url;
  }

  /// Subir foto desde bytes (para web y Windows)
  Future<String> subirFotoBytes(String negocioId, Uint8List bytes, String nombreArchivo) async {
    final extension = nombreArchivo.split('.').last;
    final ref = _storage.ref('negocios_publicos/$negocioId/foto.$extension');
    final metadata = SettableMetadata(
      contentType: _contentTypeDesdeExtension(extension),
    );
    await ref.putData(bytes, metadata);

    final url = await ref.getDownloadURL();
    await _db.collection('negocios_publicos').doc(negocioId).update({
      'fotoUrl': url,
    });
    return url;
  }

  /// Subir foto secundaria desde File (móvil/desktop)
  Future<String> subirFotoSecundaria(String negocioId, File archivo) async {
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
    final extension = archivo.path.split('.').last;
    final ref = _storage.ref('negocios_publicos/$negocioId/foto_secundaria.$extension');
    final bytes = await archivo.readAsBytes();
    final metadata = SettableMetadata(
      contentType: _contentTypeDesdeExtension(extension),
    );
    await ref.putData(bytes, metadata);
    final url = await ref.getDownloadURL();
    await _db.collection('negocios_publicos').doc(negocioId).update({
      'fotoSecundariaUrl': url,
    });
    return url;
  }

  /// Subir foto secundaria desde bytes (web)
  Future<String> subirFotoSecundariaBytes(
      String negocioId, Uint8List bytes, String nombreArchivo) async {
    final extension = nombreArchivo.split('.').last;
    final ref = _storage.ref('negocios_publicos/$negocioId/foto_secundaria.$extension');
    final metadata = SettableMetadata(
      contentType: _contentTypeDesdeExtension(extension),
    );
    await ref.putData(bytes, metadata);
    final url = await ref.getDownloadURL();
    await _db.collection('negocios_publicos').doc(negocioId).update({
      'fotoSecundariaUrl': url,
    });
    return url;
  }

  String _contentTypeDesdeExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'webp': return 'image/webp';
      case 'gif':  return 'image/gif';
      default:     return 'image/jpeg';
    }
  }

  /// Actualizar solo la foto de un negocio
  Future<void> actualizarFoto(String negocioId, String fotoUrl) async {
    await _db.collection('negocios_publicos').doc(negocioId).update({
      'fotoUrl': fotoUrl,
    });
  }

  /// Seed inicial con los negocios de Guadalajara
  Future<void> seedNegociosGuadalajara() async {
    debugPrint('🌱 Iniciando seed de negocios de Guadalajara...');

    final batch = _db.batch();

    // ── RESTAURANTES ──────────────────────────────────────────────────────────
    final restaurantes = [
      NegocioPublico(
        id: 'restaurante_dama_juana',
        nombre: 'Restaurante Dama Juana',
        categoria: CategoriaNegocio.restaurantes,
        ratingGoogle: 4.7,
        descripcion: 'Cocina moderna española, carnes premium, arroces y platos elaborados.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'summer_guadalajara',
        nombre: 'Summer',
        categoria: CategoriaNegocio.restaurantes,
        ratingGoogle: 4.1,
        descripcion: 'Tapas, cenas, copas y ambiente moderno de terraza. Muy popular entre gente joven.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'botanico_guadalajara',
        nombre: 'Botánico',
        categoria: CategoriaNegocio.restaurantes,
        ratingGoogle: 4.5,
        descripcion: 'Brunch, cocina moderna, café y ambiente "instagrameable".',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'casa_palomo',
        nombre: 'Casa Palomo',
        categoria: CategoriaNegocio.restaurantes,
        ratingGoogle: 4.6,
        descripcion: 'Cocina castellana tradicional y carnes. De los clásicos más famosos de Guadalajara.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'biosfera_guadalajara',
        nombre: 'Biosfera Guadalajara',
        categoria: CategoriaNegocio.restaurantes,
        ratingGoogle: 4.4,
        descripcion: 'Cocina internacional, sushi y experiencia premium.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'restaurante_davalos',
        nombre: 'Restaurante Dávalos',
        categoria: CategoriaNegocio.restaurantes,
        ratingGoogle: 4.3,
        descripcion: 'Menú español tradicional, tapas y comidas de grupo. Muy conocido en el centro.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'puerta_gayola',
        nombre: 'Puerta Gayola',
        categoria: CategoriaNegocio.restaurantes,
        ratingGoogle: 4.1,
        descripcion: 'Tapas, raciones y cañas. Uno de los bares/restaurantes más populares de la ciudad.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'giovani_fratelli',
        nombre: 'Ristorante Trattoria Giovani Fratelli',
        categoria: CategoriaNegocio.restaurantes,
        ratingGoogle: 4.7,
        descripcion: 'Cocina italiana, pizzas artesanales y pasta fresca.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'la_duquesa',
        nombre: 'Restaurante La Duquesa',
        categoria: CategoriaNegocio.restaurantes,
        ratingGoogle: 4.3,
        descripcion: 'Cocina mediterránea, carnes y celebraciones.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'casa_victoria',
        nombre: 'Casa Victoria Restaurante',
        categoria: CategoriaNegocio.restaurantes,
        ratingGoogle: 4.8,
        descripcion: 'Cocina mediterránea moderna y tapas gourmet.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
    ];

    // ── ESTÉTICAS ─────────────────────────────────────────────────────────────
    final esteticas = [
      NegocioPublico(
        id: 'estetica_belen',
        nombre: 'Estética Belén',
        categoria: CategoriaNegocio.esteticas,
        ratingGoogle: 5.0,
        descripcion: 'Tratamientos faciales, depilación y estética integral.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'beauty_by_patricia',
        nombre: 'Beauty by Patricia',
        categoria: CategoriaNegocio.esteticas,
        ratingGoogle: 4.9,
        descripcion: 'Uñas, maquillaje y estética facial.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'ic_belleza_pro',
        nombre: 'IC Belleza Pro',
        categoria: CategoriaNegocio.esteticas,
        ratingGoogle: 4.8,
        descripcion: 'Belleza avanzada y tratamientos corporales.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'aesthetic_center_alba',
        nombre: 'Aesthetic Center Alba',
        categoria: CategoriaNegocio.esteticas,
        ratingGoogle: 4.8,
        descripcion: 'Estética facial y corporal.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'centro_venus',
        nombre: 'Centro Venus',
        categoria: CategoriaNegocio.esteticas,
        ratingGoogle: 4.7,
        descripcion: 'Depilación y tratamientos faciales.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'natura_belleza',
        nombre: 'Natura Belleza',
        categoria: CategoriaNegocio.esteticas,
        ratingGoogle: 4.6,
        descripcion: 'Cosmética natural y bienestar.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'beauty_concept',
        nombre: 'Beauty Concept',
        categoria: CategoriaNegocio.esteticas,
        ratingGoogle: 4.7,
        descripcion: 'Manicura y estética premium.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'stylo_estetica',
        nombre: 'Stylo Estética',
        categoria: CategoriaNegocio.esteticas,
        ratingGoogle: 4.5,
        descripcion: 'Estética integral y tratamientos corporales.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'elena_beauty_center',
        nombre: 'Elena Beauty Center',
        categoria: CategoriaNegocio.esteticas,
        ratingGoogle: 4.6,
        descripcion: 'Skincare y belleza facial.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'luxury_beauty_studio',
        nombre: 'Luxury Beauty Studio',
        categoria: CategoriaNegocio.esteticas,
        ratingGoogle: 4.7,
        descripcion: 'Estética avanzada y maquillaje.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
    ];

    // ── PELUQUERÍAS ───────────────────────────────────────────────────────────
    final peluquerias = [
      NegocioPublico(
        id: 'alberto_hair_beauty',
        nombre: 'Alberto hair & beauty',
        categoria: CategoriaNegocio.peluquerias,
        ratingGoogle: 4.8,
        descripcion: 'Coloración, cortes modernos y tratamientos capilares premium.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'aurelia_estilistas',
        nombre: 'Aurelia Estilistas | Peluquería en Guadalajara',
        categoria: CategoriaNegocio.peluquerias,
        ratingGoogle: 4.9,
        descripcion: 'Mechas, balayage y estilismo femenino.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'vanessa_fernandez',
        nombre: 'Vanessa Fernández Peluqueros',
        categoria: CategoriaNegocio.peluquerias,
        ratingGoogle: 4.7,
        descripcion: 'Peluquería profesional, color y tratamientos de hidratación.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'la_pelu_de_roci',
        nombre: 'La pelu de Roci',
        categoria: CategoriaNegocio.peluquerias,
        ratingGoogle: 4.9,
        descripcion: 'Cortes modernos, peinados y atención personalizada.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'peluqueria_dellas',
        nombre: 'Peluquería D\'Ellas',
        categoria: CategoriaNegocio.peluquerias,
        ratingGoogle: 4.4,
        descripcion: 'Peluquería femenina y estética integral.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'blu_estilistas',
        nombre: 'Blu Estilistas',
        categoria: CategoriaNegocio.peluquerias,
        ratingGoogle: 4.7,
        descripcion: 'Coloración, cortes y peluquería de tendencia.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'la_pelu',
        nombre: 'La Pelu',
        categoria: CategoriaNegocio.peluquerias,
        ratingGoogle: 4.8,
        descripcion: 'Peluquería personalizada y tratamientos capilares.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'golden_estilistas',
        nombre: 'Golden Estilistas',
        categoria: CategoriaNegocio.peluquerias,
        ratingGoogle: 4.8,
        descripcion: 'Peluquería y estética profesional.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'rb_peluqueros',
        nombre: 'R & B Peluqueros',
        categoria: CategoriaNegocio.peluquerias,
        ratingGoogle: 4.9,
        descripcion: 'Estilismo y peluquería moderna.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'os_peluquerias_marios',
        nombre: 'O\'S Peluquerias Mario\'s',
        categoria: CategoriaNegocio.peluquerias,
        ratingGoogle: 4.7,
        descripcion: 'Cortes, color y productos capilares premium.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
    ];

    // ── TATUAJES ──────────────────────────────────────────────────────────────
    final tatuajes = [
      NegocioPublico(
        id: 'studio_madrid_tattoo',
        nombre: 'Studio Madrid Tattoo',
        categoria: CategoriaNegocio.tatuajes,
        ratingGoogle: 5.0,
        descripcion: 'Realismo, blackwork y tatuajes personalizados.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'studio_8_tattoo',
        nombre: 'Studio 8 - Tattoo and Piercing Studio',
        categoria: CategoriaNegocio.tatuajes,
        ratingGoogle: 4.9,
        descripcion: 'Tatuajes personalizados, piercing y fine line.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'la_boheme_tattoo',
        nombre: 'La Boheme Tattoo Studio',
        categoria: CategoriaNegocio.tatuajes,
        ratingGoogle: 5.0,
        descripcion: 'Tatuajes artísticos y tinta personalizada.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'estudio_checa',
        nombre: 'Estudio Checa',
        categoria: CategoriaNegocio.tatuajes,
        ratingGoogle: 4.8,
        descripcion: 'Blackwork, lettering y tatuaje tradicional.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'la_tinta_mona',
        nombre: 'La Tinta Mona Tattoo',
        categoria: CategoriaNegocio.tatuajes,
        ratingGoogle: 5.0,
        descripcion: 'Fine line, minimalista y diseños personalizados.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'magistral_tattoo',
        nombre: 'Magistral Tattoo',
        categoria: CategoriaNegocio.tatuajes,
        ratingGoogle: 4.8,
        descripcion: 'Realismo, color y cover up.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'ink_brotherhood',
        nombre: 'Ink Brotherhood Tattoo',
        categoria: CategoriaNegocio.tatuajes,
        ratingGoogle: 4.8,
        descripcion: 'Black & grey y tatuajes urbanos.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'dark_rose_tattoo',
        nombre: 'Dark Rose Tattoo',
        categoria: CategoriaNegocio.tatuajes,
        ratingGoogle: 4.7,
        descripcion: 'Neotradicional y color.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'old_skull_tattoo',
        nombre: 'Old Skull Tattoo',
        categoria: CategoriaNegocio.tatuajes,
        ratingGoogle: 4.7,
        descripcion: 'Old school y lettering.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
      NegocioPublico(
        id: 'black_moon_tattoo',
        nombre: 'Black Moon Tattoo',
        categoria: CategoriaNegocio.tatuajes,
        ratingGoogle: 4.6,
        descripcion: 'Fine line y diseños personalizados.',
        activo: true,
        empresaIdVinculada: '',
        direccion: 'Guadalajara, España',
      ),
    ];

    for (final negocio in [...restaurantes, ...esteticas, ...peluquerias, ...tatuajes]) {
      final docRef = _db.collection('negocios_publicos').doc(negocio.id);
      batch.set(docRef, negocio.toJson()..remove('id'), SetOptions(merge: true));
    }

    await batch.commit();
    debugPrint('✅ Seed completado: ${restaurantes.length + esteticas.length + peluquerias.length + tatuajes.length} negocios creados');
  }

  /// Eliminar todos los negocios (para reset)
  Future<void> eliminarTodos() async {
    final snap = await _db.collection('negocios_publicos').get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    debugPrint('🗑️ Todos los negocios públicos eliminados');
  }
}
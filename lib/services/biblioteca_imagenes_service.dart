import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO
// ─────────────────────────────────────────────────────────────────────────────

class ImagenComun {
  final String id;
  final String nombre;
  final String imagenUrl;
  final String categoria;
  final List<String> tags;

  const ImagenComun({
    required this.id,
    required this.nombre,
    required this.imagenUrl,
    required this.categoria,
    required this.tags,
  });

  factory ImagenComun.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ImagenComun(
      id: doc.id,
      nombre: d['nombre'] ?? '',
      imagenUrl: d['imagen_url'] ?? '',
      categoria: d['categoria'] ?? 'General',
      tags: List<String>.from(d['tags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'imagen_url': imagenUrl,
    'categoria': categoria,
    'tags': tags,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICIO
// ─────────────────────────────────────────────────────────────────────────────

class BibliotecaImagenesService {
  static final BibliotecaImagenesService _i = BibliotecaImagenesService._();
  factory BibliotecaImagenesService() => _i;
  BibliotecaImagenesService._();

  final _db = FirebaseFirestore.instance;

  static const List<Map<String, dynamic>> _estaticas = [
    {'id':'coca_cola','nombre':'Coca-Cola','imagen_url':'https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=400&h=400&fit=crop','categoria':'Bebidas','tags':['coca cola','coca-cola','refresco','cola','coke']},
    {'id':'cerveza','nombre':'Cerveza','imagen_url':'https://images.unsplash.com/photo-1608270586620-248524c67de9?w=400&h=400&fit=crop','categoria':'Bebidas','tags':['cerveza','beer','caña','mahou','estrella','cruzcampo']},
    {'id':'cafe','nombre':'Café','imagen_url':'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=400&h=400&fit=crop','categoria':'Cafetería','tags':['cafe','café','coffee','espresso','cortado','solo','con leche']},
    {'id':'agua','nombre':'Agua','imagen_url':'https://images.unsplash.com/photo-1548839140-29a749e1cf4d?w=400&h=400&fit=crop','categoria':'Bebidas','tags':['agua','water','mineral']},
    {'id':'vino_tinto','nombre':'Vino Tinto','imagen_url':'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=400&h=400&fit=crop','categoria':'Bebidas','tags':['vino','vino tinto','wine','rioja','ribera']},
    {'id':'vino_blanco','nombre':'Vino Blanco','imagen_url':'https://images.unsplash.com/photo-1560148218-1a83060f7b32?w=400&h=400&fit=crop','categoria':'Bebidas','tags':['vino blanco','white wine','albariño','verdejo']},
    {'id':'jamon','nombre':'Jamón','imagen_url':'https://images.unsplash.com/photo-1615361200141-f45040f367be?w=400&h=400&fit=crop','categoria':'Tapas','tags':['jamon','jamón','serrano','iberico','ham']},
    {'id':'pizza','nombre':'Pizza','imagen_url':'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=400&h=400&fit=crop','categoria':'Comida','tags':['pizza','margarita','napolitana']},
    {'id':'hamburguesa','nombre':'Hamburguesa','imagen_url':'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&h=400&fit=crop','categoria':'Comida','tags':['hamburguesa','burger']},
    {'id':'tortilla','nombre':'Tortilla Española','imagen_url':'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=400&h=400&fit=crop','categoria':'Tapas','tags':['tortilla','tortilla española','tortilla patatas']},
    {'id':'patatas_bravas','nombre':'Patatas Bravas','imagen_url':'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=400&h=400&fit=crop','categoria':'Tapas','tags':['patatas bravas','bravas','fritas','patatas']},
    {'id':'tostada','nombre':'Tostada','imagen_url':'https://images.unsplash.com/photo-1586444248902-2f64eddc13df?w=400&h=400&fit=crop','categoria':'Desayunos','tags':['tostada','toast','pan tostado']},
    {'id':'zumo_naranja','nombre':'Zumo Naranja','imagen_url':'https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=400&h=400&fit=crop','categoria':'Bebidas','tags':['zumo','naranja','juice','orange juice','zumo naranja']},
    {'id':'fanta','nombre':'Fanta / Naranjada','imagen_url':'https://images.unsplash.com/photo-1625772452859-1c03d884bf2b?w=400&h=400&fit=crop','categoria':'Bebidas','tags':['fanta','naranjada','fanta naranja']},
    {'id':'limonada','nombre':'Limonada / Sprite','imagen_url':'https://images.unsplash.com/photo-1657355979428-8d1df38157a5?w=400&h=400&fit=crop','categoria':'Bebidas','tags':['limonada','sprite','limón','fanta limon','7up']},
    {'id':'sandwich','nombre':'Sándwich','imagen_url':'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=400&h=400&fit=crop','categoria':'Bocadillos','tags':['sandwich','bocadillo','montado']},
    {'id':'aceitunas','nombre':'Aceitunas','imagen_url':'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?w=400&h=400&fit=crop','categoria':'Tapas','tags':['aceitunas','olives','aceituna']},
    {'id':'helado','nombre':'Helado','imagen_url':'https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=400&h=400&fit=crop','categoria':'Postres','tags':['helado','ice cream','polo']},
    {'id':'tarta','nombre':'Tarta / Pastel','imagen_url':'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=400&h=400&fit=crop','categoria':'Postres','tags':['tarta','cake','pastel','flan']},
    {'id':'te','nombre':'Té / Infusión','imagen_url':'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=400&h=400&fit=crop','categoria':'Cafetería','tags':['te','té','tea','infusion','infusión']},
  ];

  List<ImagenComun> get estaticas => _estaticas.map((m) => ImagenComun(
    id: m['id'] as String,
    nombre: m['nombre'] as String,
    imagenUrl: m['imagen_url'] as String,
    categoria: m['categoria'] as String,
    tags: List<String>.from(m['tags'] as List),
  )).toList();

  Future<List<ImagenComun>> cargarTodas() async {
    try {
      final snap = await _db.collection('biblioteca_imagenes_comunes').get();
      if (snap.docs.isNotEmpty) return snap.docs.map(ImagenComun.fromFirestore).toList();
    } catch (_) {}
    return estaticas;
  }

  Stream<List<ImagenComun>> stream() => _db
      .collection('biblioteca_imagenes_comunes')
      .snapshots()
      .map((s) => s.docs.isNotEmpty
          ? s.docs.map(ImagenComun.fromFirestore).toList()
          : estaticas);

  ImagenComun? autoMatch(String nombreProducto, List<ImagenComun> biblioteca) {
    final q = nombreProducto.toLowerCase().trim();
    if (q.isEmpty) return null;
    for (final img in biblioteca) {
      if (img.nombre.toLowerCase() == q) return img;
      if (img.tags.any((t) => q == t || q.contains(t) || t.contains(q))) return img;
    }
    for (final img in biblioteca) {
      if (img.tags.any((t) => _dice(q, t) > 0.65)) return img;
    }
    return null;
  }

  double _dice(String a, String b) {
    if (a == b) return 1.0;
    if (a.length < 2 || b.length < 2) return 0.0;
    final bA = <String>{for (int i = 0; i < a.length - 1; i++) a.substring(i, i + 2)};
    final bB = <String>{for (int i = 0; i < b.length - 1; i++) b.substring(i, i + 2)};
    return 2 * bA.intersection(bB).length / (bA.length + bB.length);
  }

  Future<void> poblarDesdeListaEstatica() async {
    final batch = _db.batch();
    for (final m in _estaticas) {
      batch.set(_db.collection('biblioteca_imagenes_comunes').doc(m['id'] as String), {
        'nombre': m['nombre'], 'imagen_url': m['imagen_url'],
        'categoria': m['categoria'], 'tags': m['tags'],
      });
    }
    await batch.commit();
  }
}


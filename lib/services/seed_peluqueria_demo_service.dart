import 'package:cloud_firestore/cloud_firestore.dart';

/// Crea o actualiza todos los datos demo de "Peluquería Fluix Demo"
/// en Firestore: negocio_publico, empresa + subcollections.
class SeedPeluqueriaDemoService {
  static const _empresaId = 'peluqueria_fluix_demo';
  final _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // PUNTO DE ENTRADA
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> seedTodo() async {
    final negocioId = await _upsertNegocio();
    await Future.wait([
      _seedEmpleados(),
      _seedServicios(),
      _seedValoraciones(),
      _seedProductos(),
    ]);
    await _seedFlashSlots(negocioId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NEGOCIO PÚBLICO
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _upsertNegocio() async {
    final col = _db.collection('negocios_publicos');
    final snap = await col.where('nombre', isEqualTo: 'Peluquería Fluix Demo').limit(1).get();

    final data = {
      'nombre': 'Peluquería Fluix Demo',
      'categoria': 'peluquerias',
      'empresaIdVinculada': _empresaId,
      'activo': true,
      'destacado': true,
      'descripcion':
          'Peluquería premium en el corazón de Guadalajara. Especialistas en coloración, cortes modernos y tratamientos capilares con productos de alta gama. Más de 10 años de experiencia y más de 500 clientas satisfechas.',
      'descripcionCorta':
          'Tu peluquería de confianza. Coloración, cortes y tratamientos premium.',
      'tagline': 'Donde el estilo se convierte en arte ✨',
      'fotoUrl':
          'https://images.unsplash.com/photo-1560066984-138daef929d0?w=800&q=80',
      'fotoSecundariaUrl':
          'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=800&q=80',
      'fotosGaleria': [
        'https://images.unsplash.com/photo-1560066984-138daef929d0?w=600&q=80',
        'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=600&q=80',
        'https://images.unsplash.com/photo-1605497788044-5a32c7078486?w=600&q=80',
        'https://images.unsplash.com/photo-1519735777090-ec97162dc266?w=600&q=80',
        'https://images.unsplash.com/photo-1562322140-8baeececf3df?w=600&q=80',
        'https://images.unsplash.com/photo-1595476108010-b4d1f102b1b1?w=600&q=80',
        'https://images.unsplash.com/photo-1580618672591-eb180b1a973f?w=600&q=80',
        'https://images.unsplash.com/photo-1634449571010-02389ed0f9b0?w=600&q=80',
        'https://images.unsplash.com/photo-1582095133179-bfd08e2fb6b8?w=600&q=80',
      ],
      'telefono': '+34 949 123 456',
      'whatsapp': '+34 649 123 456',
      'email': 'info@peluqueriafluixdemo.es',
      'website': 'www.peluqueriafluixdemo.es',
      'instagram': '@peluqueriafluixdemo',
      'facebook': 'Peluquería Fluix Demo',
      'direccion': 'Calle Mayor, 15, 19001 Guadalajara',
      'localidad': 'Guadalajara',
      'provincia': 'Guadalajara',
      'codigoPostal': '19001',
      'latitud': 40.6338,
      'longitud': -3.1661,
      'ratingGoogle': 4.8,
      'ratingFluix': 4.9,
      'numResenas': 127,
      'nivelPrecio': '€€',
      'precioMedio': '35',
      'horario': {
        'Lunes': {'cerrado': true},
        'Martes': {
          'apertura': '09:30',
          'cierre': '14:00',
          'apertura_tarde': '16:30',
          'cierre_tarde': '20:00',
        },
        'Miércoles': {
          'apertura': '09:30',
          'cierre': '14:00',
          'apertura_tarde': '16:30',
          'cierre_tarde': '20:00',
        },
        'Jueves': {
          'apertura': '09:30',
          'cierre': '14:00',
          'apertura_tarde': '16:30',
          'cierre_tarde': '20:00',
        },
        'Viernes': {
          'apertura': '09:30',
          'cierre': '14:00',
          'apertura_tarde': '16:30',
          'cierre_tarde': '20:00',
        },
        'Sábado': {'apertura': '09:00', 'cierre': '20:00'},
        'Domingo': {'cerrado': true},
      },
      'serviciosDestacados': [
        'Corte de cabello',
        'Coloración',
        'Mechas balayage',
        'Tratamiento hidratante',
        'Peinado y recogido',
      ],
      'especialidades': ['Balayage', 'Coloración avanzada', 'Recogidos de novia'],
      'caracteristicas': [
        'Productos L\'Oréal Professional',
        'Ambiente exclusivo',
        'Parking cercano',
        'WiFi gratuito',
        'Pago con tarjeta',
      ],
      'aceptaTarjeta': true,
      'tieneWifi': true,
      'tieneParking': true,
      'reservasOnlineActivas': true,
      'textoBotonReserva': 'Pedir cita',
      'mostrarEquipo': true,
      'permitirElegirProfesional': true,
      'mostrarAgenda': true,
      'permitirResenas': true,
      'mostrarResenasFluix': true,
      'mostrarResenasGoogle': true,
      'pagosOnline': false,
      'metodosPago': ['Efectivo', 'Tarjeta', 'Bizum'],
      'antelacionMinHoras': 2,
      'antelacionMaxDias': 30,
      'instruccionesReserva':
          'Por favor, cancela con al menos 24h de antelación si no puedes asistir. Gracias.',
      'terminosYCondiciones':
          '1. RESERVAS\n'
          'Las citas deben confirmarse con al menos 2 horas de antelación. Para cancelaciones, rogamos avisar con un mínimo de 24 horas.\n\n'
          '2. PAGOS\n'
          'Aceptamos efectivo, tarjeta de débito/crédito y Bizum. No se aceptan cheques.\n\n'
          '3. RETRASOS\n'
          'Si el cliente llega con más de 15 minutos de retraso, el salón se reserva el derecho de reagendar la cita.\n\n'
          '4. GARANTÍA DE SATISFACCIÓN\n'
          'Si no estás satisfecha con el servicio, comunícanoslo antes de abandonar el salón. Haremos todo lo posible para resolverlo.\n\n'
          '5. PRIVACIDAD\n'
          'Tus datos personales serán tratados conforme al RGPD y solo se usarán para la gestión de citas y comunicaciones del salón.',
      'textoBienvenida':
          '¡Bienvenida a Peluquería Fluix Demo! Aquí encontrarás los mejores tratamientos capilares de la ciudad.',
      'seccionesVisibles': {
        'servicios': true,
        'resenas': true,
        'productos': true,
        'equipo': true,
        'galeria': true,
        'ofertas': true,
        'politicas': true,
      },
      'colorPrincipal': '#A855F7',
      'colorSecundario': '#EC4899',
      'urlPublica': 'peluqueria-fluix-demo',
      'tituloSeo': 'Peluquería Fluix Demo — Guadalajara',
      'descripcionSeo':
          'Peluquería premium en Guadalajara. Coloración, cortes, tratamientos capilares y peinados de novia.',
      'palabrasClave': [
        'peluquería',
        'Guadalajara',
        'balayage',
        'coloración',
        'corte cabello',
      ],
    };

    if (snap.docs.isNotEmpty) {
      final id = snap.docs.first.id;
      await col.doc(id).update(data);
      return id;
    } else {
      final ref = await col.add(data);
      return ref.id;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMPLEADOS  →  empresas/peluqueria_fluix_demo/empleados
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _seedEmpleados() async {
    final col = _db.collection('empresas').doc(_empresaId).collection('empleados');

    final empleados = [
      {
        'id': 'emp_demo_1',
        'nombre': 'Sara González',
        'nombre_completo': 'Sara González Morales',
        'cargo': 'Directora & Estilista Senior',
        'puesto': 'Directora & Estilista Senior',
        'bio_publica':
            'Con más de 12 años de experiencia, Sara es especialista en técnicas de coloración avanzada y recogidos de novia. Formada en las mejores escuelas de Europa, aporta creatividad y precisión a cada servicio.',
        'especialidades': ['Balayage', 'Coloración avanzada', 'Recogidos de novia', 'Corte femenino'],
        'visible_publico': true,
        'activo': true,
        'avatar_url': null,
      },
      {
        'id': 'emp_demo_2',
        'nombre': 'Lucía Pérez',
        'nombre_completo': 'Lucía Pérez Navarro',
        'cargo': 'Estilista',
        'puesto': 'Estilista',
        'bio_publica':
            'Lucía destaca por su dominio de los cortes modernos y las técnicas de degradado. Fan de las tendencias actuales, siempre está al día de las últimas novedades del sector.',
        'especialidades': ['Cortes modernos', 'Degradados', 'Mechas', 'Peinados'],
        'visible_publico': true,
        'activo': true,
        'avatar_url': null,
      },
      {
        'id': 'emp_demo_3',
        'nombre': 'Marta Torres',
        'nombre_completo': 'Marta Torres Ruiz',
        'cargo': 'Colorista especialista',
        'puesto': 'Colorista especialista',
        'bio_publica':
            'Marta es la experta en color del equipo. Especializada en técnicas de mechas, tintes y tratamientos de corrección de color, consigue resultados naturales y duraderos.',
        'especialidades': ['Mechas california', 'Tintes', 'Corrección de color', 'Tratamientos'],
        'visible_publico': true,
        'activo': true,
        'avatar_url': null,
      },
    ];

    final batch = _db.batch();
    for (final e in empleados) {
      final id = e['id'] as String;
      batch.set(col.doc(id), e, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SERVICIOS  →  empresas/peluqueria_fluix_demo/servicios
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _seedServicios() async {
    final col = _db.collection('empresas').doc(_empresaId).collection('servicios');

    final servicios = [
      {
        'id': 'svc_demo_1',
        'nombre': 'Corte de cabello mujer',
        'descripcion': 'Corte personalizado con lavado, mascarilla y secado. Incluye consulta de estilo.',
        'categoria': 'Cortes',
        'precio': 28.0,
        'duracion': 45,
        'activo': true,
        'imagen_url': 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=300&q=80',
      },
      {
        'id': 'svc_demo_2',
        'nombre': 'Corte de cabello hombre',
        'descripcion': 'Corte clásico o moderno con lavado y secado incluido.',
        'categoria': 'Cortes',
        'precio': 16.0,
        'duracion': 30,
        'activo': true,
        'imagen_url': null,
      },
      {
        'id': 'svc_demo_3',
        'nombre': 'Coloración completa',
        'descripcion': 'Tinte de color uniforme en toda la cabellera. Incluye lavado, tratamiento y secado.',
        'categoria': 'Color',
        'precio': 58.0,
        'duracion': 90,
        'activo': true,
        'imagen_url': 'https://images.unsplash.com/photo-1605497788044-5a32c7078486?w=300&q=80',
      },
      {
        'id': 'svc_demo_4',
        'nombre': 'Mechas balayage',
        'descripcion': 'Técnica de coloración a mano alzada para un efecto solar y natural. El favorito de nuestras clientas.',
        'categoria': 'Color',
        'precio': 90.0,
        'duracion': 150,
        'activo': true,
        'imagen_url': 'https://images.unsplash.com/photo-1519735777090-ec97162dc266?w=300&q=80',
      },
      {
        'id': 'svc_demo_5',
        'nombre': 'Tinte de raíces',
        'descripcion': 'Retoque de raíces para mantener el color uniforme. Rápido y efectivo.',
        'categoria': 'Color',
        'precio': 38.0,
        'duracion': 60,
        'activo': true,
        'imagen_url': null,
      },
      {
        'id': 'svc_demo_6',
        'nombre': 'Tratamiento hidratante',
        'descripcion': 'Mascarilla nutritiva de alta concentración. Ideal para cabellos secos o con puntas abiertas.',
        'categoria': 'Tratamientos',
        'precio': 22.0,
        'duracion': 30,
        'activo': true,
        'imagen_url': null,
      },
      {
        'id': 'svc_demo_7',
        'nombre': 'Keratina brasileña',
        'descripcion': 'Alisado semipermanente con keratina que elimina el frizz y aporta brillo extraordinario por meses.',
        'categoria': 'Tratamientos',
        'precio': 72.0,
        'duracion': 120,
        'activo': true,
        'imagen_url': 'https://images.unsplash.com/photo-1580618672591-eb180b1a973f?w=300&q=80',
      },
      {
        'id': 'svc_demo_8',
        'nombre': 'Peinado suelto',
        'descripcion': 'Peinado profesional para eventos o el día a día. Ondas, liso o rizado según tu preferencia.',
        'categoria': 'Peinados',
        'precio': 22.0,
        'duracion': 30,
        'activo': true,
        'imagen_url': null,
      },
      {
        'id': 'svc_demo_9',
        'nombre': 'Recogido de novia',
        'descripcion': 'Recogido especial para tu gran día. Incluye prueba previa y fijación de larga duración.',
        'categoria': 'Peinados',
        'precio': 55.0,
        'duracion': 90,
        'activo': true,
        'imagen_url': 'https://images.unsplash.com/photo-1562322140-8baeececf3df?w=300&q=80',
      },
    ];

    final batch = _db.batch();
    for (final s in servicios) {
      final id = s['id'] as String;
      batch.set(col.doc(id), s, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VALORACIONES  →  empresas/peluqueria_fluix_demo/valoraciones
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _seedValoraciones() async {
    final col = _db.collection('empresas').doc(_empresaId).collection('valoraciones');

    final ahora = DateTime.now();

    final valoraciones = [
      // ── Fluix ──
      {
        'id': 'val_demo_f1',
        'autor': 'Ana García',
        'texto': 'Llevo más de tres años viniendo y siempre salgo encantada. El mejor salón de Guadalajara sin ninguna duda. Sara es una artista.',
        'estrellas': 5,
        'origen': 'fluix',
        'servicio': 'Mechas balayage',
        'verificado': true,
        'destacada': true,
        'respuesta': '¡Gracias Ana! Es un placer tenerte como clienta. Hasta la próxima 💜',
        'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 3))),
      },
      {
        'id': 'val_demo_f2',
        'autor': 'María López',
        'texto': 'Pedí cita por Fluix y fue rapidísimo. El balayage que me hicieron es exactamente lo que quería. Resultado increíble y muy natural.',
        'estrellas': 5,
        'origen': 'fluix',
        'servicio': 'Mechas balayage',
        'verificado': true,
        'destacada': false,
        'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 10))),
      },
      {
        'id': 'val_demo_f3',
        'autor': 'Carmen Ruiz',
        'texto': 'Me hice la keratina brasileña y llevo 4 meses sin frizz. Una pasada. El salón es precioso y el equipo encantador.',
        'estrellas': 5,
        'origen': 'fluix',
        'servicio': 'Keratina brasileña',
        'verificado': true,
        'destacada': false,
        'respuesta': '¡Qué alegría, Carmen! La keratina es nuestra especialidad. Te esperamos pronto 🙌',
        'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 18))),
      },
      {
        'id': 'val_demo_f4',
        'autor': 'Patricia Sánchez',
        'texto': 'Vine para un recogido de novia y quedé espectacular. El día de mi boda recibí mil halagos. Muy recomendado.',
        'estrellas': 5,
        'origen': 'fluix',
        'servicio': 'Recogido de novia',
        'verificado': true,
        'destacada': false,
        'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 35))),
      },
      {
        'id': 'val_demo_f5',
        'autor': 'Elena Fernández',
        'texto': 'Muy contenta con mi coloración completa. El precio es justo para la calidad. Ambiente muy agradable.',
        'estrellas': 4,
        'origen': 'fluix',
        'servicio': 'Coloración completa',
        'verificado': false,
        'destacada': false,
        'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 50))),
      },
      {
        'id': 'val_demo_f6',
        'autor': 'Laura Martínez',
        'texto': 'Muy profesionales y atentas. El corte me encantó. Repetiré seguro.',
        'estrellas': 4,
        'origen': 'fluix',
        'servicio': 'Corte de cabello mujer',
        'verificado': false,
        'destacada': false,
        'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 70))),
      },
      // ── Google ──
      {
        'id': 'val_demo_g1',
        'autor': 'Isabella Torres',
        'texto': 'Espectacular. Me han cambiado el look por completo. El balayage es absolutamente natural y precioso.',
        'estrellas': 5,
        'origen': 'google',
        'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 7))),
      },
      {
        'id': 'val_demo_g2',
        'autor': 'Rosa Jiménez',
        'texto': 'Profesionalidad y calidad garantizadas. Llevo años siendo clienta y no cambiaría de peluquería.',
        'estrellas': 5,
        'origen': 'google',
        'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 14))),
      },
      {
        'id': 'val_demo_g3',
        'autor': 'Nuria Castillo',
        'texto': 'Muy buen trabajo. El ambiente es acogedor y el personal muy amable. Los precios son razonables.',
        'estrellas': 4,
        'origen': 'google',
        'fecha': Timestamp.fromDate(ahora.subtract(const Duration(days: 22))),
      },
    ];

    final batch = _db.batch();
    for (final v in valoraciones) {
      final id = v['id'] as String;
      batch.set(col.doc(id), v, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRODUCTOS  →  empresas/peluqueria_fluix_demo/productos
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _seedProductos() async {
    final col = _db.collection('empresas').doc(_empresaId).collection('productos');

    final productos = [
      {
        'id': 'prod_demo_1',
        'nombre': 'Champú Hydra Repair L\'Oréal Professional',
        'descripcion': 'Champú hidratante para cabellos secos o dañados. Fórmula con aceite de argán.',
        'precio': 18.90,
        'precio_promo': null,
        'imagen_url': 'https://images.unsplash.com/photo-1620916566398-39f1143ab7be?w=400&q=80',
        'activo': true,
        'destacado': true,
      },
      {
        'id': 'prod_demo_2',
        'nombre': 'Mascarilla Olaplex No.3',
        'descripcion': 'Tratamiento reparador de uso semanal. Regenera los enlaces del cabello desde dentro.',
        'precio': 29.90,
        'precio_promo': null,
        'imagen_url': 'https://images.unsplash.com/photo-1556228720-195a672e8a03?w=400&q=80',
        'activo': true,
        'destacado': true,
      },
      {
        'id': 'prod_demo_3',
        'nombre': 'Sérum Anti-Rotura Kérastase',
        'descripcion': 'Sérum concentrado que reduce la rotura del cabello hasta un 93%.',
        'precio': 28.00,
        'precio_promo': 19.90,
        'imagen_url': null,
        'activo': true,
        'destacado': false,
      },
      {
        'id': 'prod_demo_4',
        'nombre': 'Spray Termoprotector 230°',
        'descripcion': 'Protege el cabello del calor de planchas y secadores. Fijación ligera.',
        'precio': 15.50,
        'precio_promo': null,
        'imagen_url': null,
        'activo': true,
        'destacado': false,
      },
      {
        'id': 'prod_demo_5',
        'nombre': 'Aceite de Argán Puro',
        'descripcion': 'Aceite 100% puro marroquí para dar brillo, suavidad y nutrición al cabello.',
        'precio': 21.90,
        'precio_promo': null,
        'imagen_url': 'https://images.unsplash.com/photo-1608248543803-ba4f8c70ae0b?w=400&q=80',
        'activo': true,
        'destacado': false,
      },
      {
        'id': 'prod_demo_6',
        'nombre': 'Laca de Fijación Extrafuerte',
        'descripcion': 'Laca profesional con fijación extrafuerte para recogidos y peinados duraderos.',
        'precio': 11.50,
        'precio_promo': null,
        'imagen_url': null,
        'activo': true,
        'destacado': false,
      },
    ];

    final batch = _db.batch();
    for (final p in productos) {
      final id = p['id'] as String;
      batch.set(col.doc(id), p, SetOptions(merge: true));
    }
    await batch.commit();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FLASH SLOTS  →  negocios_publicos/{negocioId}/flash_slots
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _seedFlashSlots(String negocioId) async {
    final col = _db.collection('negocios_publicos').doc(negocioId).collection('flash_slots');
    final ahora = DateTime.now();

    final slots = [
      {
        'id': 'flash_demo_1',
        'negocioId': negocioId,
        'negocioNombre': 'Peluquería Fluix Demo',
        'negocioFotoUrl':
            'https://images.unsplash.com/photo-1560066984-138daef929d0?w=400&q=80',
        'servicio': 'Corte + Secado exprés',
        'precio': 18.0,
        'precioOriginal': 35.0,
        'huecosTotales': 4,
        'huecosReservados': 1,
        'estado': 'activo',
        'activo': true,
        'fecha_hora_expiracion':
            Timestamp.fromDate(ahora.add(const Duration(hours: 28))),
        'fechaFin': Timestamp.fromDate(ahora.add(const Duration(hours: 28))),
      },
      {
        'id': 'flash_demo_2',
        'negocioId': negocioId,
        'negocioNombre': 'Peluquería Fluix Demo',
        'negocioFotoUrl':
            'https://images.unsplash.com/photo-1605497788044-5a32c7078486?w=400&q=80',
        'servicio': 'Tinte de raíces Flash',
        'precio': 28.0,
        'precioOriginal': 38.0,
        'huecosTotales': 3,
        'huecosReservados': 1,
        'estado': 'activo',
        'activo': true,
        'fecha_hora_expiracion':
            Timestamp.fromDate(ahora.add(const Duration(hours: 50))),
        'fechaFin': Timestamp.fromDate(ahora.add(const Duration(hours: 50))),
      },
    ];

    final batch = _db.batch();
    for (final s in slots) {
      final id = s['id'] as String;
      batch.set(col.doc(id), s, SetOptions(merge: true));
    }
    await batch.commit();
  }
}

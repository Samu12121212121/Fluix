import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

/// Script para agregar negocios de prueba al catálogo B2C
/// 
/// IMPORTANTE: Modifica el valor de EMPRESA_ID_VINCULADA con tu empresa real
/// 
/// Para ejecutar:
/// dart run lib/scripts/seed_negocios_prueba.dart

const String EMPRESA_ID_VINCULADA = 'TU_EMPRESA_ID_AQUI'; // ⚠️ CAMBIAR ESTO

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (EMPRESA_ID_VINCULADA == 'TU_EMPRESA_ID_AQUI') {
    print('❌ ERROR: Debes cambiar EMPRESA_ID_VINCULADA por tu empresa real');
    print('   Busca en Firestore > empresas > copia un ID de empresa existente');
    return;
  }

  print('🚀 Iniciando seed de negocios de prueba...\n');

  final negociosPrueba = [
    // ═══════════════════════════════════════════════════════════════════
    // RESTAURANTES - TOP 10 GUADALAJARA (ESPAÑA)
    // ═══════════════════════════════════════════════════════════════════
    {
      'nombre': 'Restaurante Dama Juana',
      'categoria': 'restaurantes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Cocina moderna española, carnes premium, arroces y platos elaborados. Uno de los restaurantes más valorados de Guadalajara.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 000 000',
      'ratingGoogle': 4.7,
    },
    {
      'nombre': 'Summer',
      'categoria': 'restaurantes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Tapas, cenas, copas y ambiente moderno de terraza. Muy popular entre gente joven. Perfecto para cualquier ocasión.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 000 001',
      'ratingGoogle': 4.1,
    },
    {
      'nombre': 'Botánico',
      'categoria': 'restaurantes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Brunch, cocina moderna, café y ambiente "instagrameable". Muy conocido en Guadalajara por su estilo único.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 000 002',
      'ratingGoogle': 4.5,
    },
    {
      'nombre': 'Casa Palomo',
      'categoria': 'restaurantes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Cocina castellana tradicional y carnes. De los clásicos más famosos de Guadalajara. Tradición y calidad garantizadas.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 000 003',
      'ratingGoogle': 4.6,
    },
    {
      'nombre': 'Biosfera Guadalajara',
      'categoria': 'restaurantes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Cocina internacional, sushi y experiencia premium. Ambiente sofisticado para los más exigentes.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 000 004',
      'ratingGoogle': 4.4,
    },
    {
      'nombre': 'Restaurante Dávalos',
      'categoria': 'restaurantes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Menú español tradicional, tapas y comidas de grupo. Muy conocido en el centro de Guadalajara.',
      'direccion': 'Centro, Guadalajara, España',
      'telefono': '+34 949 000 005',
      'ratingGoogle': 4.3,
    },
    {
      'nombre': 'Puerta Gayola',
      'categoria': 'restaurantes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Tapas, raciones y cañas. Uno de los bares/restaurantes más populares de la ciudad. Ambiente auténtico.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 000 006',
      'ratingGoogle': 4.1,
    },
    {
      'nombre': 'Ristorante Trattoria Giovani Fratelli',
      'categoria': 'restaurantes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Cocina italiana, pizzas artesanales y pasta fresca. Auténtica trattoria italiana en el corazón de Guadalajara.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 000 007',
      'ratingGoogle': 4.7,
    },
    {
      'nombre': 'Restaurante La Duquesa',
      'categoria': 'restaurantes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Cocina mediterránea, carnes y celebraciones. Espacio ideal para eventos especiales y comidas familiares.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 000 008',
      'ratingGoogle': 4.3,
    },
    {
      'nombre': 'Casa Victoria Restaurante',
      'categoria': 'restaurantes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Cocina mediterránea moderna y tapas gourmet. Experiencia culinaria de alta calidad.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 000 009',
      'ratingGoogle': 4.8,
    },

    // ═══════════════════════════════════════════════════════════════════
    // ESTÉTICAS - TOP 10 GUADALAJARA (ESPAÑA)
    // ═══════════════════════════════════════════════════════════════════
    {
      'nombre': 'Estética Belén',
      'categoria': 'esteticas',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Tratamientos faciales, depilación y estética integral. Excelencia en cada servicio con más de 100 reseñas perfectas.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 100 000',
      'ratingGoogle': 5.0,
    },
    {
      'nombre': 'Beauty by Patricia',
      'categoria': 'esteticas',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Uñas, maquillaje y estética facial. Centro especializado en belleza con atención personalizada.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 100 001',
      'ratingGoogle': 4.9,
    },
    {
      'nombre': 'IC Belleza Pro',
      'categoria': 'esteticas',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Belleza avanzada y tratamientos corporales. Tecnología de última generación para resultados visibles.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 100 002',
      'ratingGoogle': 4.8,
    },
    {
      'nombre': 'Aesthetic Center Alba',
      'categoria': 'esteticas',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Estética facial y corporal. Centro especializado en tratamientos profesionales de belleza.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 100 003',
      'ratingGoogle': 4.8,
    },
    {
      'nombre': 'Centro Venus',
      'categoria': 'esteticas',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Depilación y tratamientos faciales. Profesionales expertos en cuidado de la piel.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 100 004',
      'ratingGoogle': 4.7,
    },
    {
      'nombre': 'Natura Belleza',
      'categoria': 'esteticas',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Cosmética natural y bienestar. Tratamientos ecológicos y respetuosos con tu piel.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 100 005',
      'ratingGoogle': 4.6,
    },
    {
      'nombre': 'Beauty Concept',
      'categoria': 'esteticas',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Manicura y estética premium. El lugar perfecto para cuidar tus manos y tu belleza.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 100 006',
      'ratingGoogle': 4.7,
    },
    {
      'nombre': 'Stylo Estética',
      'categoria': 'esteticas',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Estética integral y tratamientos corporales. Soluciones completas para tu bienestar.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 100 007',
      'ratingGoogle': 4.5,
    },
    {
      'nombre': 'Elena Beauty Center',
      'categoria': 'esteticas',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Skincare y belleza facial. Expertos en el cuidado de tu rostro.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 100 008',
      'ratingGoogle': 4.6,
    },
    {
      'nombre': 'Luxury Beauty Studio',
      'categoria': 'esteticas',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Estética avanzada y maquillaje. Experiencia de lujo en tratamientos de belleza.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 100 009',
      'ratingGoogle': 4.7,
    },

    // ═══════════════════════════════════════════════════════════════════
    // PELUQUERÍAS - TOP 10 GUADALAJARA (ESPAÑA)
    // ═══════════════════════════════════════════════════════════════════
    {
      'nombre': 'Alberto hair & beauty',
      'categoria': 'peluquerias',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Coloración, cortes modernos y tratamientos capilares premium. Referencia en Guadalajara con casi 300 reseñas.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 200 000',
      'ratingGoogle': 4.8,
    },
    {
      'nombre': 'Aurelia Estilistas',
      'categoria': 'peluquerias',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Mechas, balayage y estilismo femenino. Especialistas en técnicas de coloración avanzada.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 200 001',
      'ratingGoogle': 4.9,
    },
    {
      'nombre': 'Vanessa Fernández Peluqueros',
      'categoria': 'peluquerias',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Peluquería profesional, color y tratamientos de hidratación. Más de 300 clientes satisfechas.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 200 002',
      'ratingGoogle': 4.7,
    },
    {
      'nombre': 'La pelu de Roci',
      'categoria': 'peluquerias',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Cortes modernos, peinados y atención personalizada. Ambiente cercano y profesional.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 200 003',
      'ratingGoogle': 4.9,
    },
    {
      'nombre': 'Peluquería D\'Ellas',
      'categoria': 'peluquerias',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Peluquería femenina y estética integral. Tu salón de confianza en Guadalajara.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 200 004',
      'ratingGoogle': 4.4,
    },
    {
      'nombre': 'Blu Estilistas',
      'categoria': 'peluquerias',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Coloración, cortes y peluquería de tendencia. Estilo y vanguardia en cada servicio.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 200 005',
      'ratingGoogle': 4.7,
    },
    {
      'nombre': 'La Pelu',
      'categoria': 'peluquerias',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Peluquería personalizada y tratamientos capilares. Atención exclusiva para cada cliente.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 200 006',
      'ratingGoogle': 4.8,
    },
    {
      'nombre': 'Golden Estilistas',
      'categoria': 'peluquerias',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Peluquería y estética profesional. Calidad y experiencia en cada corte.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 200 007',
      'ratingGoogle': 4.8,
    },
    {
      'nombre': 'R & B Peluqueros',
      'categoria': 'peluquerias',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Estilismo y peluquería moderna. Innovación y creatividad en el cuidado del cabello.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 200 008',
      'ratingGoogle': 4.9,
    },
    {
      'nombre': 'O\'S Peluquerias Mario\'s',
      'categoria': 'peluquerias',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Cortes, color y productos capilares premium. Profesionalidad y productos de la más alta calidad.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 200 009',
      'ratingGoogle': 4.7,
    },

    // ═══════════════════════════════════════════════════════════════════
    // SALONES DE TATUAJES - TOP 10 GUADALAJARA (ESPAÑA)
    // ═══════════════════════════════════════════════════════════════════
    {
      'nombre': 'Studio Madrid Tattoo',
      'categoria': 'tatuajes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Realismo, blackwork y tatuajes personalizados. Más de 700 reseñas perfectas. Los mejores tatuadores.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 300 000',
      'ratingGoogle': 5.0,
    },
    {
      'nombre': 'Studio 8 - Tattoo and Piercing Studio',
      'categoria': 'tatuajes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Tatuajes personalizados, piercing y fine line. Estudio profesional con más de 700 reseñas.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 300 001',
      'ratingGoogle': 4.9,
    },
    {
      'nombre': 'La Boheme Tattoo Studio',
      'categoria': 'tatuajes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Tatuajes artísticos y tinta personalizada. Arte en la piel con profesionales experimentados.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 300 002',
      'ratingGoogle': 5.0,
    },
    {
      'nombre': 'Estudio Checa',
      'categoria': 'tatuajes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Blackwork, lettering y tatuaje tradicional. Estilo único y calidad garantizada.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 300 003',
      'ratingGoogle': 4.8,
    },
    {
      'nombre': 'La Tinta Mona Tattoo',
      'categoria': 'tatuajes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Fine line, minimalista y diseños personalizados. Especialistas en tatuajes delicados y detallados.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 300 004',
      'ratingGoogle': 5.0,
    },
    {
      'nombre': 'Magistral Tattoo',
      'categoria': 'tatuajes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Realismo, color y cover up. Muy recomendado por su calidad y profesionalidad.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 300 005',
      'ratingGoogle': 4.9,
    },
    {
      'nombre': 'Ink Brotherhood Tattoo',
      'categoria': 'tatuajes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Black & grey y tatuajes urbanos. Estilo underground y diseños impactantes.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 300 006',
      'ratingGoogle': 4.8,
    },
    {
      'nombre': 'Dark Rose Tattoo',
      'categoria': 'tatuajes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Neotradicional y color. Tatuajes vibrantes con técnicas modernas.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 300 007',
      'ratingGoogle': 4.7,
    },
    {
      'nombre': 'Old Skull Tattoo',
      'categoria': 'tatuajes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Old school y lettering. Tatuajes clásicos con estilo atemporal.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 300 008',
      'ratingGoogle': 4.7,
    },
    {
      'nombre': 'Black Moon Tattoo',
      'categoria': 'tatuajes',
      'empresaIdVinculada': EMPRESA_ID_VINCULADA,
      'activo': true,
      'descripcion': 'Fine line y diseños personalizados. Tatuajes únicos con atención al detalle.',
      'direccion': 'Guadalajara, España',
      'telefono': '+34 949 300 009',
      'ratingGoogle': 4.6,
    },
  ];

  final firestore = FirebaseFirestore.instance;
  int contador = 0;

  for (var negocio in negociosPrueba) {
    try {
      await firestore.collection('negocios_publicos').add(negocio);
      contador++;
      print('✅ ${negocio['nombre']} agregado');
    } catch (e) {
      print('❌ Error agregando ${negocio['nombre']}: $e');
    }
  }

  print('\n🎉 Seed completado: $contador/${negociosPrueba.length} negocios agregados');
  print('\nAhora puedes:');
  print('1. Ejecutar la app: flutter run');
  print('2. Registrarte como usuario final');
  print('3. Explorar los negocios por categorías');
  print('4. Hacer una reserva de prueba');
}



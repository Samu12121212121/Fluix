// functions/scripts/importar_negocios_guadalajara.ts
//
// Importa los 170 negocios de Guadalajara a negocios_publicos en Firestore.
// Cada negocio obtiene sus servicios en la subcolección `servicios`.
// Es seguro de ejecutar varias veces: usa setMerge para no machacar datos.
//
// Uso:
//   cd functions
//   npx ts-node --project scripts/tsconfig.scripts.json scripts/importar_negocios_guadalajara.ts

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';

// ── Firebase Admin ──────────────────────────────────────────────────────────
const saPath = path.resolve(__dirname, '..', 'serviceAccountKey.json');
if (!fs.existsSync(saPath)) {
  console.error('❌ No se encontró serviceAccountKey.json');
  process.exit(1);
}
admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });
const db = admin.firestore();

// ── Mapeo tipo_negocio → CategoriaNegocio ───────────────────────────────────
const CATEGORIA_MAP: Record<string, string> = {
  'Peluquería':               'peluquerias',
  'Barbería':                 'barberias',
  'Estética':                 'esteticas',
  'Uñas':                     'esteticas',
  'Restaurante':              'restaurantes',
  'Bar':                      'restaurantes',
  'Cafetería':                'cafeterias',
  'Carnicería':               'carnicerias',
  'Tatuajes':                 'tatuajes',
  'Librería':                 'tiendas',
  'Cómics y juegos':          'tiendas',
  'Impresión 3D':             'tiendas',
  'Floristería':              'tiendas',
  'Panadería y pastelería':   'tiendas',
  'Moda':                     'tiendas',
  'Regalos y manualidades':   'tiendas',
  'Gourmet y alimentación':   'tiendas',
  'Juguetería':               'tiendas',
  'Mascotas':                 'tiendas',
};

// ── URLs de negocios (del fichero negocios_guadalajara_webs.txt) ─────────────
const URLS_NEGOCIOS: Record<string, { web?: string; instagram?: string; facebook?: string }> = {
  'Alberto Hair & Beauty':              { web: 'https://albertohairbeauty.es' },
  "La Pelu de Roci":                   { web: 'https://la-pelu-de-roci.ueniweb.com' },
  "O'S Peluquerías Mario's":           { web: 'https://mariospeluqueros.com' },
  'Aurelia Estilistas':                 { facebook: 'https://www.facebook.com/aureliaestilistas' },
  'Blu Estilistas':                     { instagram: 'https://www.instagram.com/blu.estilistas/' },
  'R & B Peluqueros':                   { instagram: 'https://www.instagram.com/ryb_peluqueros_guadalajara/' },
  'Vanessa Fernández Peluqueros':       { facebook: 'https://www.facebook.com/p/Vanessa-Fern%C3%A1ndez-Peluqueros-100063872100396/' },
  'Beauty by Patricia':                 { web: 'https://beautyguadalajara.es' },
  'Belén Nogueras Estética':            { web: 'https://belennoguerasestetica.es' },
  'IC Belleza Pro':                     { web: 'https://icbellezapro.sedinfo.es' },
  'Magistral Tattoo Studio':            { web: 'https://magistraltattoo.com' },
  'Studio 8 - Tattoo and Piercing Studio': { web: 'https://www.nuevostudio8.com' },
  'Studio Madrid Tattoo':               { web: 'https://www.studiomadridtattoo.es' },
  'La Bohème Tattoo Studio':            { instagram: 'https://www.instagram.com/la_boheme_tattoo_studio/' },
  'Biosfera Guadalajara':               { web: 'https://biosferaguadalajara.com' },
  'Botánico Guadalajara':               { web: 'https://botanicoguadalajara.es' },
  'Casa Palomo':                        { web: 'https://www.casapalomo.es' },
  'Restaurante Casa Víctor':            { web: 'https://casavictorguadalajara.es' },
  'Restaurante Dama Juana':             { web: 'https://damajuanaguadalajara.com' },
  'Restaurante Dávalos':                { web: 'http://www.restaurantedavalos.es' },
  'Restaurante La Duquesa':             { web: 'https://grupolino.com' },
  'Summer':                             { web: 'https://sites.google.com/view/summerguadalajara' },
};

// ── Taglines por tipo de negocio ────────────────────────────────────────────
const TAGLINE_MAP: Record<string, string> = {
  'Peluquería':             'Tu estilo, nuestra pasión',
  'Barbería':               'El arte del afeitado y el corte masculino',
  'Estética':               'Belleza y bienestar para ti',
  'Uñas':                   'Diseño y cuidado de uñas profesional',
  'Restaurante':            'Cocina con sabor, experiencias con alma',
  'Bar':                    'Tapas, raciones y buen ambiente',
  'Cafetería':              'El mejor café y desayunos de la ciudad',
  'Carnicería':             'Carne de calidad, trato cercano',
  'Tatuajes':               'Tu piel como lienzo',
  'Librería':               'Libros para todos los gustos',
  'Cómics y juegos':        'Diversión en papel y tablero',
  'Impresión 3D':           'Del diseño a la realidad',
  'Floristería':            'Flores frescas para cada momento',
  'Panadería y pastelería': 'Hecho con amor y masa madre',
  'Moda':                   'Moda con personalidad',
  'Regalos y manualidades': 'Regalos únicos y manualidades creativas',
  'Gourmet y alimentación': 'Sabores auténticos de la Alcarria',
  'Juguetería':             'Juguetes para todas las edades',
  'Mascotas':               'Todo para tu mascota',
};

// ── Tipos (servicios, menús, productos) ─────────────────────────────────────
interface ServicioCSV {
  nombreServicio: string;
  descripcion: string;
  categoria: string;
  tipo: string;
  precio?: number;
  desde?: number;
  duracionMin?: number;
  publico: string;
}

interface NegocioData {
  nombre: string;
  tipoNegocio: string;
  servicios: ServicioCSV[];
}

// ── Parsear CSV ──────────────────────────────────────────────────────────────
function parsearCSV(contenido: string): Map<string, NegocioData> {
  const lineas = contenido.split('\n').slice(1); // Skip header
  const negocios = new Map<string, NegocioData>();

  for (const linea of lineas) {
    if (!linea.trim()) continue;

    // Handle quoted fields
    const campos: string[] = [];
    let dentroComillas = false;
    let campo = '';
    for (let i = 0; i < linea.length; i++) {
      const c = linea[i];
      if (c === '"') {
        dentroComillas = !dentroComillas;
      } else if (c === ',' && !dentroComillas) {
        campos.push(campo.trim());
        campo = '';
      } else {
        campo += c;
      }
    }
    campos.push(campo.trim());

    if (campos.length < 2) continue;

    const [negocio, tipoNegocio, nombreServicio, descripcion, categoria,
           tipo, precioStr, desdeStr, duracionStr, publico] = campos;

    if (!negocio) continue;

    if (!negocios.has(negocio)) {
      negocios.set(negocio, { nombre: negocio, tipoNegocio, servicios: [] });
    }

    if (nombreServicio) {
      negocios.get(negocio)!.servicios.push({
        nombreServicio,
        descripcion: descripcion || '',
        categoria:   categoria || '',
        tipo:        tipo || 'servicio',
        precio:      precioStr ? parseFloat(precioStr) : undefined,
        desde:       desdeStr ? parseFloat(desdeStr) : undefined,
        duracionMin: duracionStr ? parseInt(duracionStr) : undefined,
        publico:     publico || 'Todos',
      });
    }
  }

  return negocios;
}

// ── Normalizar nombre → ID seguro ────────────────────────────────────────────
function nombreAId(nombre: string): string {
  return nombre
    .toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '')
    .substring(0, 60);
}

// ── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const csvPath = path.resolve(
    'C:/Users/Samu/Downloads/fluix_servicios_guadalajara (1).csv'
  );

  if (!fs.existsSync(csvPath)) {
    console.error(`❌ No se encontró el CSV en: ${csvPath}`);
    process.exit(1);
  }

  const contenido = fs.readFileSync(csvPath, 'utf-8');
  const negocios  = parsearCSV(contenido);

  console.log(`\n📋 Negocios en CSV: ${negocios.size}`);
  console.log('🚀 Importando a Firestore...\n');

  let creados  = 0;
  let errores  = 0;
  const BATCH_SIZE = 20;

  const entries = Array.from(negocios.values());

  for (let i = 0; i < entries.length; i += BATCH_SIZE) {
    const lote = entries.slice(i, i + BATCH_SIZE);

    for (const neg of lote) {
      const docId   = nombreAId(neg.nombre);
      const docRef  = db.collection('negocios_publicos').doc(docId);
      const urls    = URLS_NEGOCIOS[neg.nombre] ?? {};
      const cat     = CATEGORIA_MAP[neg.tipoNegocio] ?? 'tiendas';
      const tagline = TAGLINE_MAP[neg.tipoNegocio] ?? '';

      // Servicios destacados (primeros 6 nombres únicos)
      const serviciosDestacados = [...new Set(
        neg.servicios.map(s => s.nombreServicio)
      )].slice(0, 6);

      const docData: Record<string, unknown> = {
        nombre:              neg.nombre,
        categoria:           cat,
        activo:              true,
        tagline:             tagline,
        empresaIdVinculada:  '',
        serviciosDestacados,
        fuenteDatos:         'guadalajara_import_2026',
        importadoEn:         admin.firestore.FieldValue.serverTimestamp(),
      };

      if (urls.web)       docData.web = docData.website = urls.web;
      if (urls.instagram) docData.instagram = urls.instagram;
      if (urls.facebook)  docData.facebook  = urls.facebook;

      try {
        // setMerge: no sobreescribe campos existentes como fotoUrl, ratingGoogle, etc.
        await docRef.set(docData, { merge: true });

        // Subcollección servicios
        const serviciosBatch = db.batch();
        for (const sv of neg.servicios) {
          const svId  = nombreAId(sv.nombreServicio);
          const svRef = docRef.collection('servicios').doc(svId);
          const svDoc: Record<string, unknown> = {
            nombre:      sv.nombreServicio,
            descripcion: sv.descripcion,
            categoria:   sv.categoria,
            tipo:        sv.tipo,
            publico:     sv.publico,
            activo:      true,
          };
          if (sv.precio !== undefined) svDoc.precio = sv.precio;
          if (sv.desde  !== undefined) svDoc.desde  = sv.desde;
          if (sv.duracionMin !== undefined) svDoc.duracionMin = sv.duracionMin;
          serviciosBatch.set(svRef, svDoc, { merge: true });
        }
        await serviciosBatch.commit();

        creados++;
        console.log(`  [${creados}] ✓ ${neg.nombre}  (${cat})  — ${neg.servicios.length} servicios`);
      } catch (e) {
        errores++;
        console.error(`  ✗ ${neg.nombre}: ${e}`);
      }
    }

    // Pequeña pausa entre lotes para no saturar Firestore
    if (i + BATCH_SIZE < entries.length) {
      await new Promise(r => setTimeout(r, 500));
    }
  }

  console.log(`\n${'─'.repeat(55)}`);
  console.log(`✅ Creados/actualizados : ${creados}`);
  console.log(`❌ Errores             : ${errores}`);
  console.log(`${'─'.repeat(55)}`);
  console.log('\nLos negocios ya deberían aparecer en la pantalla Explorar.');
  console.log('Recuerda subir las imágenes descargadas a Firebase Storage');
  console.log('y actualizar el campo fotoUrl de cada documento.\n');

  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });

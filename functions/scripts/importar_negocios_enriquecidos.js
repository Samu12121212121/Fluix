/**
 * IMPORTAR NEGOCIOS ENRIQUECIDOS → negocios_publicos
 *
 * Fusiona los 3 lotes enriquecidos en Firestore.
 * Si el documento ya existe, hace MERGE (no sobreescribe campos que ya tengan valor).
 * Si no existe, lo crea con activo:false para revisión manual antes de publicar.
 *
 * Ejecutar: node scripts/importar_negocios_enriquecidos.js
 * Requisitos: serviceAccountKey.json en functions/
 */

const admin = require('firebase-admin');
const path  = require('path');
const fs    = require('fs');

const serviceAccount = require('../serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// ── Categorías válidas del modelo Flutter ─────────────────────────────────
const CATEGORIAS_VALIDAS = new Set([
  'general','restaurantes','esteticas','peluquerias','barberias',
  'cafeterias','carnicerias','fruterias','tatuajes','clinicas',
  'gimnasios','hoteles','tiendas',
]);

function normalizarCategoria(cat) {
  if (!cat) return 'general';
  const c = cat.toLowerCase().trim();
  if (CATEGORIAS_VALIDAS.has(c)) return c;
  // Alias comunes
  const alias = {
    'restaurante': 'restaurantes', 'peluqueria': 'peluquerias',
    'barberia': 'barberias', 'estetica': 'esteticas',
    'cafeteria': 'cafeterias', 'carniceria': 'carnicerias',
    'fruteria': 'fruterias', 'tatuaje': 'tatuajes',
    'clinica': 'clinicas', 'gimnasio': 'gimnasios',
    'hotel': 'hoteles', 'tienda': 'tiendas',
  };
  return alias[c] ?? 'general';
}

async function importarLote(rutaArchivo) {
  const nombre = path.basename(rutaArchivo);
  if (!fs.existsSync(rutaArchivo)) {
    console.warn(`⚠️  No encontrado: ${rutaArchivo}`);
    return { creados: 0, actualizados: 0, errores: 0 };
  }

  const negocios = JSON.parse(fs.readFileSync(rutaArchivo, 'utf8'));
  console.log(`\n📂 ${nombre} — ${negocios.length} negocios`);

  let creados = 0, actualizados = 0, errores = 0;
  const BATCH_SIZE = 400;
  let batch = db.batch();
  let ops = 0;

  for (const n of negocios) {
    if (!n.id || !n.nombre) { errores++; continue; }

    const ref = db.collection('negocios_publicos').doc(n.id);
    const snap = await ref.get();

    // Construir objeto solo con campos presentes y no vacíos
    const datos = {};
    if (n.nombre)     datos.nombre     = n.nombre;
    if (n.categoria)  datos.categoria  = normalizarCategoria(n.categoria);
    if (n.descripcion) datos.descripcion = n.descripcion;
    if (n.telefono)   datos.telefono   = n.telefono;
    if (n.direccion)  datos.direccion  = n.direccion;
    if (n.web)        datos.web        = n.web;
    if (n.instagram)  datos.instagram  = n.instagram;
    if (n.fotoUrl)    datos.fotoUrl    = n.fotoUrl;
    if (typeof n.ratingGoogle === 'number') datos.ratingGoogle = n.ratingGoogle;

    if (snap.exists) {
      // MERGE: solo actualiza campos que NO existen ya (no machaca datos buenos)
      const existente = snap.data();
      const patch = {};
      for (const [k, v] of Object.entries(datos)) {
        if (!existente[k]) patch[k] = v; // solo rellena huecos
      }
      if (Object.keys(patch).length > 0) {
        batch.update(ref, patch);
        actualizados++;
      }
    } else {
      // Nuevo: crear con activo:false para revisión
      batch.set(ref, { ...datos, activo: false, empresaIdVinculada: '' });
      creados++;
    }

    ops++;
    if (ops >= BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
      process.stdout.write('.');
    }
  }

  if (ops > 0) await batch.commit();

  console.log(`\n  ✅ Creados: ${creados} | Actualizados (merge): ${actualizados} | Errores: ${errores}`);
  return { creados, actualizados, errores };
}

async function main() {
  console.log('🚀 Importando negocios enriquecidos → Firestore\n');

  const base = path.join(__dirname, '..');
  const lotes = [
    path.join(base, 'datos_enriquecidos_lote1.json'),
    path.join(base, 'datos_enriquecidos_lote2.json'),
    path.join(base, 'datos_enriquecidos_lote3.json'),
  ];

  let totalCreados = 0, totalActualizados = 0, totalErrores = 0;

  for (const lote of lotes) {
    const r = await importarLote(lote);
    totalCreados    += r.creados;
    totalActualizados += r.actualizados;
    totalErrores    += r.errores;
  }

  console.log('\n═══════════════════════════════════');
  console.log(`TOTAL  Creados: ${totalCreados} | Actualizados: ${totalActualizados} | Errores: ${totalErrores}`);
  console.log('Los negocios NUEVOS se crean con activo:false — actívalos desde la consola de Firestore.');
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });

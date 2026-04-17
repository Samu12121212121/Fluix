/**
 * Script para inicializar la estructura de Firestore necesaria para Google Reviews.
 *
 * Crea los documentos que espera google_reviews_service.dart:
 *   - empresas/{id}/configuracion/google_reviews
 *   - empresas/{id}/estadisticas/resumen
 *   - empresas/{id}/valoraciones (colección vacía, se llena al sincronizar)
 *
 * Uso:
 *   node seed_google_reviews.js
 *   node seed_google_reviews.js --empresaId=TU_ID
 *   node seed_google_reviews.js --empresaId=TU_ID --apiKey=TU_API_KEY --placeId=TU_PLACE_ID
 */

const admin = require("firebase-admin");

// Inicializar Firebase Admin (usa credenciales por defecto o service account)
if (!admin.apps.length) {
  try {
    const serviceAccount = require("./credentials.json");
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
  } catch (e) {
    admin.initializeApp(); // Usa GOOGLE_APPLICATION_CREDENTIALS
  }
}

const db = admin.firestore();

// ── Parsear argumentos ──────────────────────────────────────────────────────
const args = process.argv.slice(2);
function getArg(name) {
  const found = args.find((a) => a.startsWith(`--${name}=`));
  return found ? found.split("=").slice(1).join("=") : null;
}

const EMPRESA_ID_ARG = getArg("empresaId");
const API_KEY_ARG = getArg("apiKey") || "";
const PLACE_ID_ARG = getArg("placeId") || "";

// Empresa principal por defecto
const EMPRESA_DEFAULT = "TUz8GOnQ6OX8ejiov7c5GM9LFPl2";

async function seedGoogleReviews(empresaId) {
  console.log(`\n🔧 Inicializando Google Reviews para empresa: ${empresaId}`);

  const empresaRef = db.collection("empresas").doc(empresaId);

  // 1. Verificar que la empresa existe
  const empresaDoc = await empresaRef.get();
  if (!empresaDoc.exists) {
    console.log(`⚠️  El documento empresas/${empresaId} NO existe. Creándolo como placeholder...`);
    await empresaRef.set(
      {
        nombre: "Empresa pendiente de configurar",
        creado: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    console.log(`✅ Documento empresas/${empresaId} creado.`);
  } else {
    console.log(`✅ Empresa encontrada: ${empresaDoc.data().nombre || empresaId}`);
  }

  // 2. Crear configuracion/google_reviews
  const configRef = empresaRef.collection("configuracion").doc("google_reviews");
  const configDoc = await configRef.get();
  if (configDoc.exists) {
    console.log(`ℹ️  configuracion/google_reviews ya existe — se actualizará con merge`);
  }
  await configRef.set(
    {
      api_key: API_KEY_ARG || (configDoc.exists ? configDoc.data().api_key || "" : ""),
      place_id: PLACE_ID_ARG || (configDoc.exists ? configDoc.data().place_id || "" : ""),
      actualizado: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`✅ empresas/${empresaId}/configuracion/google_reviews → OK`);

  // 3. Crear estadisticas/resumen
  const resumenRef = empresaRef.collection("estadisticas").doc("resumen");
  const resumenDoc = await resumenRef.get();
  if (resumenDoc.exists) {
    console.log(`ℹ️  estadisticas/resumen ya existe — se actualizará con merge`);
  }
  await resumenRef.set(
    {
      rating_google: resumenDoc.exists ? (resumenDoc.data().rating_google ?? 0) : 0,
      total_resenas_google: resumenDoc.exists ? (resumenDoc.data().total_resenas_google ?? 0) : 0,
      total_valoraciones: resumenDoc.exists ? (resumenDoc.data().total_valoraciones ?? 0) : 0,
      suma_calificaciones: resumenDoc.exists ? (resumenDoc.data().suma_calificaciones ?? 0) : 0,
      valoracion_promedio: resumenDoc.exists ? (resumenDoc.data().valoracion_promedio ?? 0) : 0,
      ultima_sync_google: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`✅ empresas/${empresaId}/estadisticas/resumen → OK`);

  // 4. Verificar que la colección valoraciones es accesible (crear un doc placeholder si está vacía)
  const valoracionesSnap = await empresaRef.collection("valoraciones").limit(1).get();
  if (valoracionesSnap.empty) {
    console.log(`ℹ️  Colección valoraciones vacía — se creará al sincronizar con Google o añadir manualmente`);
  } else {
    console.log(`✅ valoraciones ya tiene ${valoracionesSnap.size}+ documentos`);
  }

  // 5. Crear rating_historial (para el gráfico de evolución)
  const historialRef = empresaRef.collection("estadisticas").doc("rating_historial");
  const historialDoc = await historialRef.get();
  if (!historialDoc.exists) {
    await historialRef.set({
      creado: admin.firestore.FieldValue.serverTimestamp(),
      meses: {},
    });
    console.log(`✅ empresas/${empresaId}/estadisticas/rating_historial → creado`);
  } else {
    console.log(`✅ estadisticas/rating_historial ya existe`);
  }

  console.log(`\n🎉 Estructura de Google Reviews lista para empresa ${empresaId}`);
  console.log(`\n📝 Siguiente paso:`);
  if (!API_KEY_ARG && !(configDoc.exists && configDoc.data().api_key)) {
    console.log(`   Configura tu API Key y Place ID desde la app, o ejecuta:`);
    console.log(`   node seed_google_reviews.js --empresaId=${empresaId} --apiKey=TU_API_KEY --placeId=TU_PLACE_ID`);
  } else {
    console.log(`   Sincroniza desde la app o ejecuta la sincronización manual.`);
  }
}

async function main() {
  try {
    if (EMPRESA_ID_ARG) {
      await seedGoogleReviews(EMPRESA_ID_ARG);
    } else {
      console.log(`ℹ️  Sin --empresaId, usando empresa por defecto: ${EMPRESA_DEFAULT}`);
      await seedGoogleReviews(EMPRESA_DEFAULT);
    }
    console.log("\n✅ Script completado.");
  } catch (err) {
    console.error("\n❌ Error:", err.message || err);
  }
  process.exit(0);
}

main();


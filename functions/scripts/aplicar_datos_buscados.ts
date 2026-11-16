// functions/scripts/aplicar_datos_buscados.ts
//
// Lee el JSON generado por buscar_datos_negocios.py y actualiza negocios_publicos.
// Usa setMerge para no sobreescribir datos ya existentes de calidad.
//
// Uso:
//   cd functions
//   npx ts-node --project scripts/tsconfig.scripts.json --transpileOnly scripts/aplicar_datos_buscados.ts

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';

const saPath = path.resolve(__dirname, '..', 'serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });
const db = admin.firestore();

const JSON_PATH = 'C:/Users/Samu/Desktop/datos_negocios_encontrados.json';

const CAMPOS_ACTUALIZAR = [
  'telefono', 'direccion', 'web', 'website', 'ratingGoogle',
  'latitud', 'longitud', 'descripcion', 'instagram', 'facebook',
  'googleMapsUrl',
];

async function main() {
  if (!fs.existsSync(JSON_PATH)) {
    console.error('❌ No existe el JSON de datos buscados. Ejecuta primero buscar_datos_negocios.py');
    process.exit(1);
  }

  const datos: any[] = JSON.parse(fs.readFileSync(JSON_PATH, 'utf-8'));
  console.log(`\n📋 Aplicando ${datos.length} negocios a Firestore...\n`);

  let actualizados = 0;
  let sinCambios   = 0;

  for (const neg of datos) {
    const docId  = neg.id;
    const docRef = db.collection('negocios_publicos').doc(docId);

    // Solo incluir campos con valor real
    const update: Record<string, any> = {};
    for (const campo of CAMPOS_ACTUALIZAR) {
      if (neg[campo] !== undefined && neg[campo] !== null && neg[campo] !== '') {
        update[campo] = neg[campo];
        if (campo === 'web') update['website'] = neg[campo];
      }
    }

    if (Object.keys(update).length === 0) {
      sinCambios++;
      continue;
    }

    await docRef.set(update, { merge: true });
    actualizados++;

    const campos = Object.keys(update).join(', ');
    console.log(`  ✓ ${neg.nombre.substring(0, 45).padEnd(45)} → ${campos}`);
  }

  console.log(`\n${'─'.repeat(60)}`);
  console.log(`✅ Actualizados: ${actualizados}`);
  console.log(`   Sin cambios : ${sinCambios}`);
  console.log(`${'─'.repeat(60)}\n`);

  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });

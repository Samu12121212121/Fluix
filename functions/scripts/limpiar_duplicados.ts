// functions/scripts/limpiar_duplicados.ts
//
// Detecta documentos duplicados en negocios_publicos (mismo nombre),
// fusiona los datos del menos completo en el más completo y borra el sobrante.
//
// Uso:
//   cd functions
//   npx ts-node --project scripts/tsconfig.scripts.json --transpileOnly scripts/limpiar_duplicados.ts

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';

const saPath = path.resolve(__dirname, '..', 'serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });
const db = admin.firestore();

// Campos de "calidad" para decidir qué doc conservar
const CAMPOS_CALIDAD = [
  'fotoUrl', 'descripcion', 'direccion', 'telefono', 'ratingGoogle',
  'web', 'instagram', 'facebook', 'latitud', 'horario',
  'serviciosDestacados', 'fotosGaleria',
];

function contarCampos(data: Record<string, any>): number {
  return CAMPOS_CALIDAD.filter(c => data[c] != null && data[c] !== '').length;
}

function normalizar(nombre: string): string {
  return nombre
    .toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

async function main() {
  const snap = await db.collection('negocios_publicos').get();
  const docs = snap.docs;

  console.log(`\nTotal documentos: ${docs.length}`);

  // Agrupar por nombre normalizado
  const grupos = new Map<string, typeof docs>();
  for (const doc of docs) {
    const nombre = (doc.data().nombre as string) ?? doc.id;
    const key    = normalizar(nombre);
    if (!grupos.has(key)) grupos.set(key, []);
    grupos.get(key)!.push(doc);
  }

  const duplicados = [...grupos.entries()].filter(([, g]) => g.length > 1);
  console.log(`Grupos duplicados: ${duplicados.length}\n`);

  if (duplicados.length === 0) {
    console.log('No hay duplicados.');
    process.exit(0);
  }

  let borrados = 0;
  let fusionados = 0;

  for (const [key, grupo] of duplicados) {
    console.log(`\n  "${grupo[0].data().nombre}" (${grupo.length} docs)`);
    grupo.forEach(d => {
      const puntos = contarCampos(d.data());
      console.log(`    ${d.id.padEnd(50)} ${puntos} campos`);
    });

    // El más completo es el que conservamos
    grupo.sort((a, b) => contarCampos(b.data()) - contarCampos(a.data()));
    const keeper  = grupo[0];
    const restos  = grupo.slice(1);

    const keeperData = keeper.data();

    // Fusionar campos que faltan en el keeper desde los otros docs
    const mergeData: Record<string, any> = {};
    for (const dup of restos) {
      for (const campo of CAMPOS_CALIDAD) {
        const val = dup.data()[campo];
        if (val != null && val !== '' && (keeperData[campo] == null || keeperData[campo] === '')) {
          mergeData[campo] = val;
        }
      }
      // También fusionar serviciosDestacados si el keeper tiene menos
      const keeperSvs: string[] = keeperData.serviciosDestacados ?? [];
      const dupSvs:    string[] = dup.data().serviciosDestacados ?? [];
      const merged = [...new Set([...keeperSvs, ...dupSvs])];
      if (merged.length > keeperSvs.length) mergeData.serviciosDestacados = merged;
    }

    if (Object.keys(mergeData).length > 0) {
      await keeper.ref.set(mergeData, { merge: true });
      fusionados++;
      console.log(`    -> Fusionado: ${Object.keys(mergeData).join(', ')}`);
    }

    // Borrar los duplicados
    for (const dup of restos) {
      await dup.ref.delete();
      borrados++;
      console.log(`    -> Borrado: ${dup.id}`);
    }
  }

  console.log(`\n${'─'.repeat(55)}`);
  console.log(`Duplicados borrados : ${borrados}`);
  console.log(`Datos fusionados    : ${fusionados} documentos enriquecidos`);
  console.log(`Documentos finales  : ${docs.length - borrados}`);
  console.log(`${'─'.repeat(55)}\n`);

  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });

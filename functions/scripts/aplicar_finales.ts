import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';
admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(__dirname, '..', 'serviceAccountKey.json'))) });
const db = admin.firestore();

const CAMPOS = ['descripcion', 'telefono', 'direccion', 'ratingGoogle', 'web', 'website', 'instagram', 'latitud', 'longitud'];

async function main() {
  const items: any[] = JSON.parse(fs.readFileSync('C:/Users/Samu/Desktop/datos_finales_firestore.json', 'utf-8'));
  console.log(`Aplicando ${items.length} negocios...\n`);

  let ok = 0;
  for (const item of items) {
    const update: Record<string, any> = {};
    for (const campo of CAMPOS) {
      if (item[campo] != null && item[campo] !== '') update[campo] = item[campo];
    }
    if (Object.keys(update).length === 0) continue;
    await db.collection('negocios_publicos').doc(item.id).set(update, { merge: true });
    ok++;
    if (ok % 20 === 0) console.log(`  ${ok}/${items.length}...`);
  }

  console.log(`\nActualizados: ${ok}`);

  // Análisis final
  const snap = await db.collection('negocios_publicos').get();
  const docs = snap.docs.map(d => d.data());
  const f = (campo: string) => docs.filter(d => d[campo]).length;
  console.log(`\nEstado final (${snap.size} docs):`);
  console.log(`  fotoUrl      : ${f('fotoUrl')} / ${snap.size}`);
  console.log(`  descripcion  : ${f('descripcion')} / ${snap.size}`);
  console.log(`  telefono     : ${f('telefono')} / ${snap.size}`);
  console.log(`  direccion    : ${f('direccion')} / ${snap.size}`);
  console.log(`  ratingGoogle : ${f('ratingGoogle')} / ${snap.size}`);
  console.log(`  web          : ${f('web')} / ${snap.size}`);
  console.log(`  latitud      : ${f('latitud')} / ${snap.size}`);
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';
admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(__dirname, '..', 'serviceAccountKey.json'))) });
const db = admin.firestore();

const LOTES = [
  path.resolve(__dirname, '..', 'datos_agente_lote1.json'),
  path.resolve(__dirname, '..', 'datos_agente_lote2.json'),
  path.resolve(__dirname, '..', 'datos_agente_lote3.json'),
];

const CAMPOS = ['telefono','direccion','ratingGoogle','web','website','instagram','facebook','latitud','longitud','googleMapsUrl'];

async function main() {
  let todos: any[] = [];
  for (const lote of LOTES) {
    if (fs.existsSync(lote)) {
      const items = JSON.parse(fs.readFileSync(lote, 'utf-8'));
      todos = todos.concat(items);
      console.log(`  Leido ${path.basename(lote)}: ${items.length} entradas`);
    } else {
      console.warn(`  AVISO: no existe ${path.basename(lote)}`);
    }
  }

  console.log(`\nTotal entradas: ${todos.length}`);
  let aplicados = 0;
  let sinDatos  = 0;

  for (const item of todos) {
    const update: Record<string, any> = {};
    for (const c of CAMPOS) {
      if (item[c] != null && item[c] !== '') update[c] = item[c];
      if (c === 'web' && item[c]) update['website'] = item[c];
    }
    if (Object.keys(update).length === 0) { sinDatos++; continue; }

    await db.collection('negocios_publicos').doc(item.id).set(update, { merge: true });
    aplicados++;
  }

  console.log(`Aplicados a Firestore : ${aplicados}`);
  console.log(`Sin datos (solo id)   : ${sinDatos}`);

  // Estado final
  const snap = await db.collection('negocios_publicos').get();
  const docs = snap.docs.map(d => d.data());
  const f = (c: string) => docs.filter((d: any) => d[c]).length;
  const pct = (n: number) => `(${Math.round(n/snap.size*100)}%)`;

  console.log(`\nESTADO FINAL — ${snap.size} negocios`);
  console.log('─'.repeat(42));
  console.log(`  descripcion  : ${f('descripcion').toString().padStart(3)} / ${snap.size}  ${pct(f('descripcion'))}`);
  console.log(`  telefono     : ${f('telefono').toString().padStart(3)} / ${snap.size}  ${pct(f('telefono'))}`);
  console.log(`  direccion    : ${f('direccion').toString().padStart(3)} / ${snap.size}  ${pct(f('direccion'))}`);
  console.log(`  ratingGoogle : ${f('ratingGoogle').toString().padStart(3)} / ${snap.size}  ${pct(f('ratingGoogle'))}`);
  console.log(`  fotoUrl      : ${f('fotoUrl').toString().padStart(3)} / ${snap.size}  ${pct(f('fotoUrl'))}`);
  console.log(`  web          : ${f('web').toString().padStart(3)} / ${snap.size}  ${pct(f('web'))}`);
  console.log(`  latitud      : ${f('latitud').toString().padStart(3)} / ${snap.size}  ${pct(f('latitud'))}`);

  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });

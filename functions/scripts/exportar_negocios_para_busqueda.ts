import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';

admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(__dirname, '..', 'serviceAccountKey.json'))) });

async function main() {
  const snap = await admin.firestore().collection('negocios_publicos')
    .where('fuenteDatos', '==', 'guadalajara_import_2026')
    .get();
  const negocios = snap.docs.map(d => ({
    id: d.id,
    nombre: d.data().nombre,
    categoria: d.data().categoria,
    web: d.data().web || d.data().website || '',
    instagram: d.data().instagram || '',
    facebook: d.data().facebook || '',
  }));
  const out = 'C:/Users/Samu/Desktop/negocios_a_buscar.json';
  fs.writeFileSync(out, JSON.stringify(negocios, null, 2), 'utf-8');
  console.log(`Exportados ${negocios.length} negocios a ${out}`);
  process.exit(0);
}
main().catch(e => { console.error(e); process.exit(1); });

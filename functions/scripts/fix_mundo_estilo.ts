import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';
admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(__dirname, '..', 'serviceAccountKey.json'))) });
const bucket = admin.storage().bucket('planeaapp-4bea4.firebasestorage.app');
const db = admin.firestore();

async function main() {
  const svDir = 'C:/Users/Samu/Desktop/Negocios_Guadalajara_Imagenes/Mundo_Estilo_Elegance/Servicios';
  const imgs = fs.readdirSync(svDir).filter(f => /\.(jpg|png|webp)$/i.test(f)).sort();
  if (!imgs.length) { console.log('Sin imagenes'); process.exit(0); }

  const localPath   = path.join(svDir, imgs[0]);
  const storagePath = 'negocios_publicos/mundo_estilo_elegance/sitio/sitio_01.jpg';
  await bucket.file(storagePath).save(fs.readFileSync(localPath), {
    metadata: { contentType: 'image/jpeg' }, public: true, resumable: false,
  });
  const url = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
  await db.collection('negocios_publicos').doc('mundo_estilo_elegance').set({ fotoUrl: url }, { merge: true });
  console.log('OK:', url);

  // Estado final
  const snap = await db.collection('negocios_publicos').get();
  const docs = snap.docs.map(d => d.data());
  const f = (c: string) => docs.filter((d: any) => d[c]).length;
  console.log(`\nESTADO FINAL — ${snap.size} negocios`);
  console.log(`  fotoUrl      : ${f('fotoUrl')} / ${snap.size}`);
  console.log(`  fotosGaleria : ${f('fotosGaleria')} / ${snap.size}`);
  console.log(`  descripcion  : ${f('descripcion')} / ${snap.size}`);
  console.log(`  telefono     : ${f('telefono')} / ${snap.size}`);
  console.log(`  direccion    : ${f('direccion')} / ${snap.size}`);
  console.log(`  ratingGoogle : ${f('ratingGoogle')} / ${snap.size}`);
  console.log(`  web          : ${f('web')} / ${snap.size}`);
  process.exit(0);
}
main().catch(e => { console.error(e.message); process.exit(1); });

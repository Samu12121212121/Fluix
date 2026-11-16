import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';

const saPath = path.resolve(__dirname, '..', 'serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });
const bucket = admin.storage().bucket('planeaapp-4bea4.firebasestorage.app');
const db     = admin.firestore();

async function main() {
  const localImg    = 'C:/Users/Samu/Desktop/Negocios_Guadalajara_Imagenes/Biosfera_Guadalajara/Sitio/Biosfera_Guadalajara_Sitio_01.jpg';
  const storagePath = 'negocios_publicos/biosfera_guadalajara/sitio/sitio_01.jpg';

  if (!fs.existsSync(localImg)) {
    console.error('No existe:', localImg);
    process.exit(1);
  }

  console.log('Subiendo imagen de prueba...');
  const file = bucket.file(storagePath);
  await file.save(fs.readFileSync(localImg), {
    metadata: { contentType: 'image/jpeg' },
    public: true,
    resumable: false,
  });

  const url = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
  console.log('URL:', url);

  await db.collection('negocios_publicos').doc('biosfera_guadalajara')
    .set({ fotoUrl: url }, { merge: true });
  console.log('Firestore actualizado OK');
  process.exit(0);
}
main().catch(e => { console.error('ERROR:', e.message); process.exit(1); });

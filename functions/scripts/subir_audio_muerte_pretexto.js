const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');

const SA_KEY    = path.join(__dirname, '../serviceAccountKey.json');
const AUDIO_SRC = 'C:\\Users\\Samu\\Downloads\\28-10-urjc-susana-collado-medicina-y-literatura.mp3 (1).mpeg';
const EMPRESA_ID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BUCKET    = 'planeaapp-4bea4.firebasestorage.app';

admin.initializeApp({
  credential: admin.credential.cert(require(SA_KEY)),
  storageBucket: BUCKET,
});

const db      = admin.firestore();
const storage = admin.storage().bucket();

async function main() {
  // 1. Subir el audio
  const destPath = `empresas/${EMPRESA_ID}/blog/audios/28-10-urjc-susana-collado-medicina-y-literatura.mp3`;
  console.log('Subiendo audio…');
  await storage.upload(AUDIO_SRC, {
    destination: destPath,
    metadata: { contentType: 'audio/mpeg' },
  });
  const [url] = await storage.file(destPath).getSignedUrl({
    action: 'read',
    expires: '03-01-2500',
  });
  // URL pública permanente (sin firma)
  const publicUrl = `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(destPath)}?alt=media`;
  console.log('URL:', publicUrl);

  // 2. Buscar la entrada "muerte como pretexto"
  const snap = await db
    .collection('empresas').doc(EMPRESA_ID)
    .collection('blog')
    .get();

  const matches = snap.docs.filter(d => {
    const titulo = (d.data().titulo || '').toLowerCase();
    return titulo.includes('muerte') && titulo.includes('pretexto');
  });

  if (matches.length === 0) {
    console.log('\nNo encontré ninguna entrada con "muerte" y "pretexto" en el título.');
    console.log('Entradas disponibles:');
    snap.docs.slice(0, 20).forEach(d => console.log(' -', d.data().titulo));
    console.log('\nURL del audio lista para pegar manualmente:', publicUrl);
    return;
  }

  for (const doc of matches) {
    console.log(`\nActualizando: "${doc.data().titulo}" (${doc.id})`);
    await doc.ref.update({ audio_url: publicUrl });
    console.log('✓ audio_url guardado');
  }
}

main().catch(e => { console.error(e); process.exit(1); });

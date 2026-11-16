import * as admin from 'firebase-admin';
import * as path from 'path';
admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(__dirname, '..', 'serviceAccountKey.json'))) });

admin.firestore().collection('negocios_publicos').get().then(snap => {
  const groups: Record<string, string[]> = {};
  for (const d of snap.docs) {
    const nombre = ((d.data().nombre as string) || '').trim();
    const key = nombre.toLowerCase().replace(/[^a-z0-9]/g, '');
    if (!groups[key]) groups[key] = [];
    groups[key].push(`${d.id} [${d.data().fuenteDatos || 'legacy'}]`);
  }
  const dups = Object.entries(groups).filter(([, g]) => g.length > 1);
  console.log(`Total docs: ${snap.size}`);
  console.log(`Duplicados: ${dups.length}`);
  dups.forEach(([, g]) => { console.log('  ' + g.join('\n    ')); });
  process.exit(0);
});

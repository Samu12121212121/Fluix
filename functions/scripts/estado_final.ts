import * as admin from 'firebase-admin';
import * as path from 'path';
admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(__dirname, '..', 'serviceAccountKey.json'))) });
const db = admin.firestore();

const KEEPERS = ['giovani_fratelli','la_duquesa','la_tinta_mona','peluqueria_dellas',
                 'studio_8_tattoo','summer_guadalajara','vanessa_fernandez'];

// Descripciones para los keepers que puedan faltar
const DESC_KEEPERS: Record<string,string> = {
  'giovani_fratelli':    'Ristorante italiano con reserva de mesa y servicio a domicilio. Atención personalizada en Guadalajara.',
  'la_duquesa':          'Restaurante con reserva de mesa, salón privado y desayunos y brunch. Atención personalizada en Guadalajara.',
  'la_tinta_mona':       'Estudio de tatuajes especializado en fine line, sketch, microrrealismo y lettering personalizado. Guadalajara.',
  'peluqueria_dellas':   'Peluquería especializada en corte de flequillo, mechas ombré, tratamiento de keratina y limpieza facial. Guadalajara.',
  'studio_8_tattoo':     'Estudio de tatuajes y piercing con blackwork, realismo, línea fina, color y joyería de alta calidad. Guadalajara.',
  'summer_guadalajara':  'Restaurante con reserva de mesa, paellas y arroces por encargo y comida para llevar. Guadalajara.',
  'vanessa_fernandez':   'Peluquería especializada en alisado de keratina, extensiones de cabello y depilación con hilo. Guadalajara.',
};

async function main() {
  // Aplicar descripciones a keepers si les faltan
  for (const id of KEEPERS) {
    const snap = await db.collection('negocios_publicos').doc(id).get();
    const data = snap.data() || {};
    if (!data.descripcion && DESC_KEEPERS[id]) {
      await snap.ref.set({ descripcion: DESC_KEEPERS[id] }, { merge: true });
      console.log(`Descripcion aplicada a: ${id}`);
    }
  }

  // Estado global
  const snap = await db.collection('negocios_publicos').get();
  const docs = snap.docs.map(d => d.data());
  const f = (c: string) => docs.filter((d: any) => d[c]).length;

  console.log(`\nESTADO FINAL — ${snap.size} negocios en Firestore`);
  console.log('─'.repeat(40));
  console.log(`  descripcion  : ${f('descripcion')} / ${snap.size}  ${pct(f('descripcion'), snap.size)}`);
  console.log(`  telefono     : ${f('telefono')} / ${snap.size}  ${pct(f('telefono'), snap.size)}`);
  console.log(`  direccion    : ${f('direccion')} / ${snap.size}  ${pct(f('direccion'), snap.size)}`);
  console.log(`  ratingGoogle : ${f('ratingGoogle')} / ${snap.size}  ${pct(f('ratingGoogle'), snap.size)}`);
  console.log(`  fotoUrl      : ${f('fotoUrl')} / ${snap.size}  ${pct(f('fotoUrl'), snap.size)}`);
  console.log(`  web          : ${f('web')} / ${snap.size}  ${pct(f('web'), snap.size)}`);
  console.log(`  latitud      : ${f('latitud')} / ${snap.size}  ${pct(f('latitud'), snap.size)}`);
  console.log(`  activo       : ${f('activo')} / ${snap.size}  ${pct(f('activo'), snap.size)}`);
  process.exit(0);
}

const pct = (n: number, t: number) => `(${Math.round(n/t*100)}%)`;
main().catch(e => { console.error(e); process.exit(1); });

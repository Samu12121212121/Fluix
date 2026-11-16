import * as admin from 'firebase-admin';
import * as path from 'path';
admin.initializeApp({ credential: admin.credential.cert(require(path.resolve(__dirname, '..', 'serviceAccountKey.json'))) });
const db = admin.firestore();

// Pares: [keeper (más datos), borrar]
const PARES = [
  { keeper: 'giovani_fratelli',         borrar: 'ristorante_trattoria_giovani_fratelli' },
  { keeper: 'la_duquesa',               borrar: 'restaurante_la_duquesa' },
  { keeper: 'la_tinta_mona',            borrar: 'la_tinta_mona_tattoo' },
  { keeper: 'peluqueria_dellas',        borrar: 'peluqueria_d_ellas' },
  { keeper: 'studio_8_tattoo',          borrar: 'studio_8_tattoo_and_piercing_studio' },
  { keeper: 'summer_guadalajara',       borrar: 'summer' },
  { keeper: 'vanessa_fernandez',        borrar: 'vanessa_fernandez_peluqueros' },
];

const MERGE_CAMPOS = [
  'descripcion', 'direccion', 'telefono', 'web', 'website', 'instagram',
  'facebook', 'ratingGoogle', 'latitud', 'longitud', 'tagline',
  'serviciosDestacados', 'fotosGaleria',
];

async function main() {
  for (const { keeper, borrar } of PARES) {
    const [keepSnap, borrarSnap] = await Promise.all([
      db.collection('negocios_publicos').doc(keeper).get(),
      db.collection('negocios_publicos').doc(borrar).get(),
    ]);

    if (!keepSnap.exists || !borrarSnap.exists) {
      console.log(`  SKIP ${keeper}/${borrar} — uno no existe`);
      continue;
    }

    const keepData  = keepSnap.data()!;
    const borrarData = borrarSnap.data()!;

    // Fusionar campos que faltan en keeper
    const merge: Record<string, any> = {};
    for (const campo of MERGE_CAMPOS) {
      const val = borrarData[campo];
      if (val != null && val !== '' && (keepData[campo] == null || keepData[campo] === '')) {
        merge[campo] = val;
      }
    }
    // Unir serviciosDestacados
    const kSvs: string[] = keepData.serviciosDestacados ?? [];
    const bSvs: string[] = borrarData.serviciosDestacados ?? [];
    const merged = [...new Set([...kSvs, ...bSvs])];
    if (merged.length > kSvs.length) merge.serviciosDestacados = merged;

    if (Object.keys(merge).length > 0) {
      await keepSnap.ref.set(merge, { merge: true });
    }
    await borrarSnap.ref.delete();

    const camposMerge = Object.keys(merge).join(', ') || 'ninguno';
    console.log(`  [OK] Keeper: ${keeper.padEnd(35)} | Borrado: ${borrar.padEnd(45)} | Fusionados: ${camposMerge}`);
  }

  const finalSnap = await db.collection('negocios_publicos').get();
  console.log(`\nDocumentos finales: ${finalSnap.size}`);
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });

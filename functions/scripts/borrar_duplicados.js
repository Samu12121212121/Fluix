/**
 * borrar_duplicados.js — ESCRIBE en Firestore (borra 39 docs)
 */

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

// IDs generados por listar_duplicados_a_eliminar.js,
// con los 2 erróneos excluidos manualmente:
const IDS_EXCLUIR = new Set([
  'dulce-lopez-en-la-trinchera-de-los-libros', // su "keeper" ya tiene eliminado:true
  'torcuato-romero-el-tablero-de-ajedrez',      // es el bueno de los 3 Torcuato
]);

async function main() {
  const todos = require('./ids_a_eliminar.json');
  const ids = todos.filter(id => !IDS_EXCLUIR.has(id));

  console.log(`\nTotal en JSON: ${todos.length}`);
  console.log(`Excluidos (protegidos): ${todos.length - ids.length}`);
  console.log(`A borrar: ${ids.length}\n`);

  let ok = 0, err = 0;
  for (const id of ids) {
    try {
      await db.collection('empresas').doc(EID).collection('blog').doc(id).delete();
      console.log(`  ✓ borrado: ${id}`);
      ok++;
    } catch (e) {
      console.error(`  ✗ error  : ${id} → ${e.message}`);
      err++;
    }
  }

  console.log(`\n══════════════════════════════════`);
  console.log(` Borrados: ${ok}  Errores: ${err}`);
  console.log(`══════════════════════════════════\n`);
}

main().catch(e => { console.error(e); process.exit(1); });

/**
 * listar_duplicados_a_eliminar.js — SOLO LECTURA
 * Lista los IDs de la primera importación (estado vacío) que son
 * duplicados del mismo título con estado:publicado.
 */

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();
const EID = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

function norm(s) {
  if (!s) return '';
  return s.normalize('NFD').replace(/[̀-ͯ]/g, '')
    .toLowerCase().replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
}

async function main() {
  const snap = await db.collection('empresas').doc(EID).collection('blog')
    .where('tipo', '==', 'entrevista').get();
  const docs = snap.docs.map(d => ({ id: d.id, ...d.data() }));

  // Agrupar por título normalizado
  const grupos = {};
  docs.forEach(p => {
    const k = norm(p.titulo || '');
    if (!k) return;
    (grupos[k] = grupos[k] || []).push(p);
  });

  const aDuplicar = Object.values(grupos).filter(a => a.length > 1);

  const aEliminar = [];
  const conservar = [];

  aDuplicar.forEach(arr => {
    // Preferir el que tiene estado:'publicado'; si no, el más reciente
    const conEstado = arr.filter(p => p.estado === 'publicado');
    const sinEstado = arr.filter(p => p.estado !== 'publicado');

    let keeper, losers;
    if (conEstado.length >= 1) {
      keeper = conEstado[0];
      losers = [...sinEstado, ...conEstado.slice(1)];
    } else {
      // Todos sin estado: conservar el de slug más corto
      arr.sort((a, b) => (a.slug||a.id).length - (b.slug||b.id).length);
      keeper = arr[0];
      losers = arr.slice(1);
    }
    conservar.push(keeper);
    aEliminar.push(...losers);
  });

  console.log('\n══════════════════════════════════════════════════════════');
  console.log(` DUPLICADOS: ${aDuplicar.length} grupos → ${aEliminar.length} docs a eliminar`);
  console.log('══════════════════════════════════════════════════════════\n');

  aEliminar.forEach((p, i) => {
    console.log(`${String(i+1).padStart(2,'0')}. ELIMINAR  id="${p.id}"`);
    console.log(`    título : ${(p.titulo||'').substring(0,70)}`);
    console.log(`    estado : ${p.estado||'(vacío)'} | eliminado: ${p.eliminado||false}`);
    // Buscar el keeper con mismo título
    const k = norm(p.titulo || '');
    const keeper = conservar.find(c => norm(c.titulo||'') === k);
    if (keeper) console.log(`    MANTENER: id="${keeper.id}" | estado: ${keeper.estado}`);
    console.log('');
  });

  console.log('══════════════════════════════════════════════════════════');
  console.log(' Para ejecutar el borrado, revisar y confirmar primero.');
  console.log(' No se ha modificado nada.');
  console.log('══════════════════════════════════════════════════════════\n');

  // Exportar IDs como JSON para el script de borrado
  const ids = aEliminar.map(p => p.id);
  const fs = require('fs');
  fs.writeFileSync(
    require('path').join(__dirname, 'ids_a_eliminar.json'),
    JSON.stringify(ids, null, 2)
  );
  console.log(`ids_a_eliminar.json guardado con ${ids.length} IDs.\n`);
}

main().catch(e => { console.error(e); process.exit(1); });

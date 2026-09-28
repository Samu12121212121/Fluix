/**
 * aplicar_fusiones_blog.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Lee duplicados_blog.json y ejecuta las fusiones en Firestore.
 *
 * Modos de operación (se pueden combinar):
 *   --borrar-pruebas     Elimina los 4 docs del grupo "noticia-de-prueba"
 *   --aplicar-fusiones   Escribe el documento fusionado en el ID canónico
 *                        y elimina los redundantes para todos los demás grupos
 *   --todo               Equivale a --borrar-pruebas + --aplicar-fusiones
 *
 * Sin --confirmar solo muestra el plan (dry-run implícito).
 * Con --confirmar pide "CONFIRMAR" en consola antes de escribir.
 *
 * Uso:
 *   cd functions
 *   node scripts/aplicar_fusiones_blog.js --empresa=0PoomHYDUJf5w8tDFRLhFi9iURF3 --todo
 *   node scripts/aplicar_fusiones_blog.js --empresa=0PoomHYDUJf5w8tDFRLhFi9iURF3 --todo --confirmar
 *   node scripts/aplicar_fusiones_blog.js --empresa=0PoomHYDUJf5w8tDFRLhFi9iURF3 --aplicar-fusiones --confirmar --input=duplicados_blog.json
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin    = require('firebase-admin');
const fs       = require('fs');
const path     = require('path');
const readline = require('readline');

// ── CLI args ──────────────────────────────────────────────────────────────────
const args = Object.fromEntries(
  process.argv.slice(2)
    .filter(a => a.startsWith('--'))
    .map(a => {
      const [k, ...v] = a.slice(2).split('=');
      return [k, v.length ? v.join('=') : true];
    })
);

const EID              = args['empresa'];
const CONFIRMAR        = args['confirmar'] === true || args['confirmar'] === 'true';
const MODO_PRUEBAS     = args['borrar-pruebas'] === true || args['todo'] === true;
const MODO_FUSIONES    = args['aplicar-fusiones'] === true || args['todo'] === true;
const IN_FILE          = args['input'] || 'duplicados_blog.json';

if (!EID) {
  console.error('❌  Falta --empresa=<empresaId>');
  console.error('   Ejemplo: node scripts/aplicar_fusiones_blog.js --empresa=0PoomHYDUJf5w8tDFRLhFi9iURF3 --todo --confirmar');
  process.exit(1);
}
if (!MODO_PRUEBAS && !MODO_FUSIONES) {
  console.error('❌  Indica al menos un modo: --borrar-pruebas | --aplicar-fusiones | --todo');
  process.exit(1);
}

// ── Firebase ──────────────────────────────────────────────────────────────────
const saPath = path.resolve(__dirname, '../serviceAccountKey.json');
if (!fs.existsSync(saPath)) {
  console.error('❌  No se encontró serviceAccountKey.json en functions/');
  process.exit(1);
}
const sa = require(saPath);
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

// ── Helpers ───────────────────────────────────────────────────────────────────

// IDs sintéticos que NO deben usarse como ID canónico en Firestore
function esSintetico(id) {
  return (
    /^(static|noticia|entrevista)-?\d/.test(id) ||
    /^nazari_wp_/.test(id)
  );
}

// Elige el ID canónico óptimo dentro de un grupo: prefiere slug sobre sintético
function elegirCanonicoReal(grupo) {
  const todos = [grupo.id_canonico, ...grupo.docs_a_eliminar];
  const slug  = todos.find(id => !esSintetico(id));
  return slug || grupo.id_canonico;
}

// IDs a eliminar dado el canónico real
function calcularAEliminar(grupo, canonicoReal) {
  const todos = [grupo.id_canonico, ...grupo.docs_a_eliminar];
  return todos.filter(id => id !== canonicoReal);
}

// Convierte fecha_publicacion string "YYYY-MM-DD" a Timestamp de Firestore
function prepararDoc(docObj) {
  const d = { ...docObj };
  if (typeof d.fecha_publicacion === 'string' && d.fecha_publicacion.match(/^\d{4}-\d{2}-\d{2}$/)) {
    d.fecha_publicacion = admin.firestore.Timestamp.fromDate(
      new Date(d.fecha_publicacion + 'T12:00:00Z')
    );
  }
  // Quitar campos de tracking interno del doc escrito (quedan en el JSON de auditoría)
  delete d._ids_originales;
  return d;
}

// Confirmación interactiva
function pedirConfirmacion(msg) {
  return new Promise(resolve => {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(msg, ans => { rl.close(); resolve(ans.trim() === 'CONFIRMAR'); });
  });
}

// Commit en lotes de máximo 400 operaciones
async function commitLotes(ops) {
  const LOTE = 400;
  for (let i = 0; i < ops.length; i += LOTE) {
    const batch = db.batch();
    ops.slice(i, i + LOTE).forEach(op => {
      if (op.type === 'set')    batch.set(op.ref, op.data);
      if (op.type === 'delete') batch.delete(op.ref);
    });
    await batch.commit();
    process.stdout.write(`  … ${Math.min(i + LOTE, ops.length)}/${ops.length} operaciones\r`);
  }
  console.log('');
}

const SEP  = '─'.repeat(72);
const SEP2 = '═'.repeat(72);

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  // 1. Leer JSON de detección
  const inPath = path.resolve(process.cwd(), IN_FILE);
  if (!fs.existsSync(inPath)) {
    console.error(`❌  No se encontró: ${inPath}`);
    console.error('   Ejecuta primero: node scripts/detectar_duplicados_blog.js --empresa=... --dry-run');
    process.exit(1);
  }
  const deteccion = JSON.parse(fs.readFileSync(inPath, 'utf8'));
  const grupos    = deteccion.grupos || [];

  console.log(`\n🔧 Aplicar fusiones — empresas/blog`);
  console.log(`   Empresa     : ${EID}`);
  console.log(`   Entrada     : ${inPath}`);
  console.log(`   Grupos total: ${grupos.length}`);
  console.log(`   Modos       : ${[MODO_PRUEBAS && 'borrar-pruebas', MODO_FUSIONES && 'aplicar-fusiones'].filter(Boolean).join(' + ')}`);
  console.log(`   Confirmar   : ${CONFIRMAR ? 'SÍ — escribirá en Firestore' : 'NO — solo muestra el plan'}\n`);

  // 2. Separar grupos de prueba del resto
  const CLAVE_PRUEBA = 'noticia-de-prueba';
  const grupoPrueba  = grupos.find(g => g.clave === CLAVE_PRUEBA);
  const gruposFusion = grupos.filter(g => g.clave !== CLAVE_PRUEBA);

  const colRef = db.collection('empresas').doc(EID).collection('blog');

  // ── PLAN: borrar pruebas ─────────────────────────────────────────────────
  const opsBorrar = [];
  if (MODO_PRUEBAS) {
    console.log(SEP2);
    console.log('🗑  BORRAR PRUEBAS');
    console.log(SEP2);
    if (!grupoPrueba) {
      console.log(`   No se encontró el grupo "${CLAVE_PRUEBA}" en el JSON.\n`);
    } else {
      const todosIds = [grupoPrueba.id_canonico, ...grupoPrueba.docs_a_eliminar];
      console.log(`   Grupo: "${CLAVE_PRUEBA}"  →  ${todosIds.length} documentos a eliminar:`);
      todosIds.forEach(id => {
        console.log(`     🗑  ${id}`);
        opsBorrar.push({ type: 'delete', ref: colRef.doc(id) });
      });
      console.log('');
    }
  }

  // ── PLAN: fusiones ───────────────────────────────────────────────────────
  const opsFusion = [];
  if (MODO_FUSIONES) {
    console.log(SEP2);
    console.log('📦 FUSIONES A APLICAR');
    console.log(SEP2);

    for (const grupo of gruposFusion) {
      const canonicoReal = elegirCanonicoReal(grupo);
      const aEliminar    = calcularAEliminar(grupo, canonicoReal);
      const docFusion    = prepararDoc(grupo.documento_fusionado);

      // Corregir slug en el doc si el canónico real difiere del id_canonico original
      if (canonicoReal !== grupo.id_canonico && !docFusion.slug) {
        docFusion.slug = canonicoReal;
      }

      const cambioId = canonicoReal !== grupo.id_canonico
        ? `  ⚠️  ID corregido: ${grupo.id_canonico} → ${canonicoReal}`
        : '';

      console.log(`\n  "${grupo.clave}"${cambioId}`);
      console.log(`     ✅ escribir en : ${canonicoReal}`);
      aEliminar.forEach(id => console.log(`     🗑  eliminar    : ${id}`));

      opsFusion.push({ type: 'set',    ref: colRef.doc(canonicoReal), data: docFusion });
      aEliminar.forEach(id =>
        opsFusion.push({ type: 'delete', ref: colRef.doc(id) })
      );
    }
    console.log('');
  }

  // ── Resumen ──────────────────────────────────────────────────────────────
  const totalOps = opsBorrar.length + opsFusion.length;
  console.log(SEP);
  console.log(`📊 RESUMEN DEL PLAN`);
  console.log(SEP);
  if (MODO_PRUEBAS)  console.log(`   Docs a eliminar (pruebas) : ${opsBorrar.length}`);
  if (MODO_FUSIONES) {
    const escrituras  = opsFusion.filter(o => o.type === 'set').length;
    const eliminacion = opsFusion.filter(o => o.type === 'delete').length;
    console.log(`   Docs a escribir (fusion)  : ${escrituras}`);
    console.log(`   Docs a eliminar (fusion)  : ${eliminacion}`);
  }
  console.log(`   Total operaciones Firestore: ${totalOps}`);
  console.log('');

  if (totalOps === 0) {
    console.log('ℹ️  Nada que hacer.\n');
    process.exit(0);
  }

  // ── Ejecución ────────────────────────────────────────────────────────────
  if (!CONFIRMAR) {
    console.log('ℹ️  Modo vista previa. Añade --confirmar para ejecutar los cambios.\n');
    process.exit(0);
  }

  console.log('⚠️  Esta operación modificará Firestore de forma irreversible.');
  const ok = await pedirConfirmacion('   Escribe CONFIRMAR para continuar: ');
  if (!ok) {
    console.log('\n   Cancelado.\n');
    process.exit(0);
  }

  console.log('');

  if (opsBorrar.length > 0) {
    console.log(`🗑  Eliminando docs de prueba (${opsBorrar.length})…`);
    await commitLotes(opsBorrar);
    console.log(`   ✅ Eliminados.`);
  }

  if (opsFusion.length > 0) {
    console.log(`📦 Aplicando fusiones (${opsFusion.length} operaciones)…`);
    await commitLotes(opsFusion);
    console.log(`   ✅ Fusiones aplicadas.`);
  }

  console.log(`\n✅ Completado. Colección blog actualizada.\n`);
  process.exit(0);
}

main().catch(e => { console.error('❌', e.message || e); process.exit(1); });

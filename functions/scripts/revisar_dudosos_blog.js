/**
 * revisar_dudosos_blog.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Lee el JSON generado por detectar_duplicados_blog.js, carga los documentos
 * completos desde Firestore y produce una comparación campo a campo de cada
 * grupo marcado como dudoso.
 *
 * Para cada grupo muestra:
 *   · Todos los campos presentes en cualquiera de los docs
 *   · Estado por campo: IGUAL | DISTINTO | SOLO EN UNO
 *   · El valor de cada doc (truncado a 120 chars en consola)
 *   · Qué elegiría la fusión automática y por qué
 *
 * Solo lectura. No escribe ni modifica nada en Firestore.
 *
 * Uso:
 *   cd functions
 *   node scripts/revisar_dudosos_blog.js --empresa=0PoomHYDUJf5w8tDFRLhFi9iURF3 --dry-run
 *   node scripts/revisar_dudosos_blog.js --empresa=0PoomHYDUJf5w8tDFRLhFi9iURF3 --dry-run --input=duplicados_blog.json --output=revision_dudosos.json
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');

// ── CLI args ──────────────────────────────────────────────────────────────────
const args = Object.fromEntries(
  process.argv.slice(2)
    .filter(a => a.startsWith('--'))
    .map(a => {
      const [k, ...v] = a.slice(2).split('=');
      return [k, v.length ? v.join('=') : true];
    })
);

const EID      = args['empresa'];
const DRY_RUN  = args['dry-run'] === true || args['dry-run'] === 'true';
const IN_FILE  = args['input']  || 'duplicados_blog.json';
const OUT_FILE = args['output'] || 'revision_dudosos.json';

if (!EID) {
  console.error('❌  Falta --empresa=<empresaId>');
  process.exit(1);
}
if (!DRY_RUN) {
  console.error('❌  Este script solo opera en modo --dry-run.');
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
const TRUNC = 120;

function repr(v) {
  if (v === undefined) return '‹campo ausente›';
  if (v === null)      return 'null';
  if (typeof v === 'object' && typeof v.toDate === 'function') {
    return v.toDate().toISOString().split('T')[0];
  }
  if (Array.isArray(v)) {
    if (v.length === 0) return '[]';
    return `[${v.length} items: ${v.slice(0, 3).map(x => JSON.stringify(x)).join(', ')}${v.length > 3 ? '…' : ''}]`;
  }
  if (typeof v === 'object') {
    const s = JSON.stringify(v);
    return s.length > TRUNC ? s.substring(0, TRUNC) + '…' : s;
  }
  const s = String(v);
  return s.length > TRUNC ? s.substring(0, TRUNC) + '…' : s;
}

function igual(a, b) {
  if (a === b) return true;
  if (a === undefined || b === undefined) return false;
  // Timestamps: comparar como string ISO
  const ra = repr(a), rb = repr(b);
  return ra === rb;
}

// Campos a ignorar en la comparación (metadatos de auditoría, no contenido)
const IGNORAR = new Set(['guardado_en', 'actualizado_en', '_fusionado', '_ids_originales', '_fuentes']);

// Orden preferido de campos para mostrarlos primero
const ORDEN = [
  'titulo', 'slug', 'tipo', 'fecha_publicacion', 'estado', 'publicada', 'eliminado',
  'autor', 'resumen', 'imagen_url', 'url_externa', 'contenido',
  'categoria_id', 'etiquetas', 'visitas', 'wp_id', 'seo',
  '_importado', '_fuente',
];

function ordenarCampos(campos) {
  const enOrden = ORDEN.filter(c => campos.includes(c));
  const resto   = campos.filter(c => !ORDEN.includes(c)).sort();
  return [...enOrden, ...resto];
}

function elegirFusion(vals) {
  // Igual lógica que detectar_duplicados_blog: primer valor no vacío del más completo
  // Aquí: retornar el valor no-undefined/null/"" con mayor longitud de representación
  const candidatos = vals.filter(v => v !== undefined && v !== null && v !== '');
  if (candidatos.length === 0) return { valor: '', motivo: 'todos vacíos' };
  // Para arrays: el más largo
  if (Array.isArray(candidatos[0])) {
    const longest = candidatos.reduce((a, b) => b.length > a.length ? b : a);
    return { valor: longest, motivo: `array más largo (${longest.length} items)` };
  }
  // Para strings: el más largo
  if (typeof candidatos[0] === 'string') {
    const longest = candidatos.reduce((a, b) => b.length > a.length ? b : a);
    return { valor: longest, motivo: `cadena más larga (${longest.length} chars)` };
  }
  // Para objetos, booleanos, números: primer no vacío
  return { valor: candidatos[0], motivo: 'primer valor no vacío' };
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  // 1. Leer JSON de detección
  const inPath = path.resolve(process.cwd(), IN_FILE);
  if (!fs.existsSync(inPath)) {
    console.error(`❌  No se encontró el archivo de entrada: ${inPath}`);
    console.error('   Ejecuta primero: node scripts/detectar_duplicados_blog.js --empresa=... --dry-run');
    process.exit(1);
  }
  const deteccion = JSON.parse(fs.readFileSync(inPath, 'utf8'));
  const dudosos   = deteccion.casos_dudosos || [];

  console.log(`\n🔬 Revisión campo a campo — casos dudosos`);
  console.log(`   Empresa   : ${EID}`);
  console.log(`   Entrada   : ${inPath}`);
  console.log(`   Dudosos   : ${dudosos.length}`);
  console.log(`   Modo      : DRY-RUN (solo lectura)\n`);

  if (dudosos.length === 0) {
    console.log('✅  No hay casos dudosos que revisar.\n');
    process.exit(0);
  }

  // 2. Recopilar todos los IDs que necesitamos
  const todosIds = [...new Set(dudosos.flatMap(g => g.docs_actuales.map(d => d.id)))];
  console.log(`📥 Cargando ${todosIds.length} documentos desde Firestore…`);

  const colRef = db.collection('empresas').doc(EID).collection('blog');
  const snapMap = {};
  // Leer en paralelo en lotes de 10
  const LOTE = 10;
  for (let i = 0; i < todosIds.length; i += LOTE) {
    const lote = todosIds.slice(i, i + LOTE);
    await Promise.all(lote.map(async id => {
      const snap = await colRef.doc(id).get();
      snapMap[id] = snap.exists ? snap.data() : null;
    }));
  }
  console.log(`   Cargados: ${Object.values(snapMap).filter(Boolean).length}/${todosIds.length}\n`);

  // 3. Comparar campo a campo para cada grupo dudoso
  const resultados = [];
  const SEP  = '─'.repeat(80);
  const SEP2 = '═'.repeat(80);

  for (let gi = 0; gi < dudosos.length; gi++) {
    const grupo = dudosos[gi];
    console.log(`${SEP2}`);
    console.log(`DUDOSO ${gi + 1}/${dudosos.length}: "${grupo.clave}"  (${grupo.tipo_clave})`);
    console.log(`${SEP2}`);
    console.log(`Conflictos detectados: ${grupo.conflictos.join(' | ')}`);
    console.log('');

    // Obtener datos completos
    const docsDatos = grupo.docs_actuales.map(d => ({
      id:   d.id,
      data: snapMap[d.id] || {},
    }));

    const labels = docsDatos.map(d => d.id.length > 30 ? d.id.substring(0, 27) + '…' : d.id);

    // Encabezado de tabla
    const COL0 = 26, COL1 = 12, COLn = Math.max(28, Math.floor((80 - COL0 - COL1) / docsDatos.length));
    const header = 'CAMPO'.padEnd(COL0) + 'ESTADO'.padEnd(COL1) + labels.map(l => l.padEnd(COLn)).join('');
    console.log(header);
    console.log(SEP);

    // Recopilar todos los campos de todos los docs
    const todosCampos = new Set();
    for (const d of docsDatos) Object.keys(d.data).forEach(k => todosCampos.add(k));
    const camposOrdenados = ordenarCampos([...todosCampos].filter(c => !IGNORAR.has(c)));

    const camposComparados = [];

    for (const campo of camposOrdenados) {
      const vals = docsDatos.map(d => d.data[campo]);

      // Estado
      const presentes = vals.filter(v => v !== undefined);
      let estado;
      if (presentes.length === 0) continue;
      if (presentes.length < vals.length) {
        estado = 'SOLO_EN_UNO';
      } else if (vals.every((v, _, arr) => igual(v, arr[0]))) {
        estado = 'IGUAL';
      } else {
        estado = 'DISTINTO';
      }

      const fusion = estado !== 'IGUAL' ? elegirFusion(vals) : null;

      // Imprimir fila
      const estadoLabel = estado === 'IGUAL' ? '✅ igual' : estado === 'DISTINTO' ? '⚡ DISTINTO' : '⚠️  solo1';
      const cols = vals.map(v => repr(v).padEnd(COLn).substring(0, COLn));
      console.log(campo.padEnd(COL0) + estadoLabel.padEnd(COL1 + 2) + cols.join(''));

      if (estado !== 'IGUAL') {
        if (fusion) {
          const fusStr = repr(fusion.valor);
          console.log(' '.repeat(COL0) + `   ↳ fusión elegiría: ${fusStr.substring(0, 60)}  [${fusion.motivo}]`);
        }
      }

      camposComparados.push({
        campo,
        estado,
        valores:        Object.fromEntries(docsDatos.map((d, i) => [d.id, d.data[campo]])),
        fusion_elegiria: fusion?.valor,
        fusion_motivo:   fusion?.motivo || 'todos iguales',
      });
    }

    console.log('');
    console.log(`ID canónico sugerido   : ${grupo.id_canonico}`);
    console.log(`IDs a eliminar         : ${grupo.docs_a_eliminar.join(', ')}`);
    console.log('');

    resultados.push({
      clave:            grupo.clave,
      tipo_clave:       grupo.tipo_clave,
      conflictos:       grupo.conflictos,
      id_canonico:      grupo.id_canonico,
      docs_a_eliminar:  grupo.docs_a_eliminar,
      docs_ids:         docsDatos.map(d => d.id),
      campos:           camposComparados,
    });
  }

  // 4. Guardar JSON
  const outPath = path.resolve(process.cwd(), OUT_FILE);
  const salida = {
    generado:     new Date().toISOString(),
    empresa_id:   EID,
    modo:         'dry-run',
    total_dudosos: dudosos.length,
    grupos:        resultados,
  };
  fs.writeFileSync(outPath, JSON.stringify(salida, null, 2), 'utf8');
  console.log(SEP2);
  console.log(`💾 JSON guardado en: ${outPath}`);
  console.log('⚠️  DRY-RUN — Firestore no fue modificado.\n');
  process.exit(0);
}

main().catch(e => { console.error('❌', e.message || e); process.exit(1); });

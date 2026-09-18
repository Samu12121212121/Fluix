/**
 * detectar_duplicados_blog.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Detecta documentos duplicados en empresas/{empresaId}/blog y propone
 * un documento FUSIONADO por grupo (toma los mejores campos de cada duplicado).
 *
 * Estrategia de agrupación (en orden de prioridad):
 *  1. Mismo campo `slug` (exacto)
 *  2. Mismo título normalizado + tipo (para docs sin slug)
 *
 * Para cada grupo genera:
 *  - id_canonico        : ID de Firestore a usar (preferible slug)
 *  - docs_a_eliminar    : IDs que quedarían redundantes tras la fusión
 *  - documento_fusionado: campos combinados de todos los duplicados
 *  - es_dudoso          : true si hay conflictos de contenido sin resolver
 *
 * EN --dry-run NO realiza ninguna escritura, modificación ni borrado en Firestore.
 *
 * Uso:
 *   cd functions
 *   node scripts/detectar_duplicados_blog.js --empresa=0PoomHYDUJf5w8tDFRLhFi9iURF3 --dry-run
 *   node scripts/detectar_duplicados_blog.js --empresa=0PoomHYDUJf5w8tDFRLhFi9iURF3 --dry-run --output=duplicados.json
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
const OUT_FILE = args['output'] || null;

if (!EID) {
  console.error('❌  Falta --empresa=<empresaId>');
  console.error('   Ejemplo: node scripts/detectar_duplicados_blog.js --empresa=0PoomHYDUJf5w8tDFRLhFi9iURF3 --dry-run');
  process.exit(1);
}

if (!DRY_RUN) {
  console.error('❌  Este script solo opera en modo --dry-run. No implementa escritura ni borrado.');
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
function normalizar(str) {
  if (!str) return '';
  return str
    .toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function fechaIso(fp) {
  if (!fp) return '';
  if (typeof fp.toDate === 'function') return fp.toDate().toISOString().split('T')[0];
  return String(fp).substring(0, 10);
}

// Prefiere IDs tipo slug sobre IDs sintéticos (static-N, noticia-N, etc.)
function esIdSintetico(id) {
  return /^(static|noticia|entrevista)-?\d/.test(id);
}

// Score de completitud: cuántos campos útiles tiene el doc
function score(data) {
  let s = 0;
  if (data.eliminado !== undefined)              s += 5;
  if (data.resumen?.trim())                      s += 5;
  if (data.imagen_url?.trim())                   s += 5;
  if (data.autor?.trim())                        s += 3;
  if (data.url_externa?.trim())                  s += 3;
  if (data.contenido?.trim())                    s += 3;
  if (data.categoria_id)                         s += 2;
  if (data.seo && typeof data.seo === 'object')  s += 2;
  if (data._importado)                           s += 2;
  if (data.wp_id)                                s += 1;
  if (data.estado)                               s += 1;
  if (Array.isArray(data.etiquetas) && data.etiquetas.length) s += 1;
  return s;
}

// Elige el mejor valor no vacío entre múltiples docs, en orden de score desc.
function mejorCampo(docs, campo) {
  for (const d of docs) {
    const v = d.data[campo];
    if (v !== undefined && v !== null && v !== '') return v;
  }
  return undefined;
}

// Fusiona los campos de varios docs en un único objeto
function fusionar(docs) {
  // Ordenar de mayor a menor score para que mejorCampo prefiera los más completos
  const sorted = [...docs].sort((a, b) => score(b.data) - score(a.data));

  // Título más largo (más descriptivo)
  const titulo = sorted
    .map(d => d.data.titulo || '')
    .reduce((a, b) => b.length > a.length ? b : a, '');

  // Resumen más largo
  const resumen = sorted
    .map(d => d.data.resumen || '')
    .reduce((a, b) => b.length > a.length ? b : a, '');

  // Etiquetas fusionadas y deduplicadas
  const etiquetas = [...new Set(
    sorted.flatMap(d => Array.isArray(d.data.etiquetas) ? d.data.etiquetas : [])
  )];

  // Fecha: preferir Timestamp; si no, string
  let fecha_publicacion = null;
  for (const d of sorted) {
    const fp = d.data.fecha_publicacion;
    if (fp) { fecha_publicacion = fechaIso(fp); break; }
  }

  return {
    titulo,
    slug:              mejorCampo(sorted, 'slug')        || '',
    resumen,
    contenido:         mejorCampo(sorted, 'contenido')   || '',
    autor:             mejorCampo(sorted, 'autor')        || '',
    imagen_url:        mejorCampo(sorted, 'imagen_url')   || '',
    url_externa:       mejorCampo(sorted, 'url_externa')  || '',
    tipo:              mejorCampo(sorted, 'tipo')         || '',
    categoria_id:      mejorCampo(sorted, 'categoria_id')|| '',
    estado:            mejorCampo(sorted, 'estado')       || 'publicado',
    publicada:         true,
    eliminado:         false,
    fecha_publicacion,
    etiquetas,
    visitas:           Math.max(...sorted.map(d => d.data.visitas || 0)),
    seo:               mejorCampo(sorted, 'seo')          || { meta_title: '', meta_description: '', keywords: [] },
    wp_id:             mejorCampo(sorted, 'wp_id')        || null,
    _fusionado:        true,
    _fuentes:          [...new Set(sorted.map(d => d.data._fuente).filter(Boolean))],
    _ids_originales:   sorted.map(d => d.id),
  };
}

// Conflictos de contenido que merecen revisión humana
function detectarConflictos(docs) {
  const conflictos = [];
  const resumenes = docs.map(d => normalizar(d.data.resumen || '').substring(0, 80)).filter(Boolean);
  const resumenesUnicos = [...new Set(resumenes)];
  if (resumenesUnicos.length > 1) {
    conflictos.push('Resúmenes distintos entre duplicados — la fusión toma el más largo');
  }
  const titulos = [...new Set(docs.map(d => normalizar(d.data.titulo || '')))];
  if (titulos.length > 1) {
    conflictos.push('Títulos distintos entre duplicados — la fusión toma el más largo');
  }
  const tipos = [...new Set(docs.map(d => d.data.tipo).filter(Boolean))];
  if (tipos.length > 1) {
    conflictos.push(`Tipos distintos: [${tipos.join(', ')}] — revisar cuál es correcto`);
  }
  return conflictos;
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n🔍 Detector + fusionador de duplicados — empresas/blog');
  console.log(`   Empresa : ${EID}`);
  console.log(`   Modo    : DRY-RUN (solo lectura, sin cambios en Firestore)`);
  if (OUT_FILE) console.log(`   Salida  : ${OUT_FILE}`);
  console.log('');

  console.log('📥 Cargando documentos…');
  const snap = await db
    .collection('empresas').doc(EID)
    .collection('blog')
    .get();

  const docs = snap.docs.map(d => ({ id: d.id, data: d.data() }));
  console.log(`   Total documentos leídos: ${docs.length}\n`);

  if (docs.length === 0) {
    console.log('ℹ️  Colección vacía.\n');
    process.exit(0);
  }

  // ── Agrupar ───────────────────────────────────────────────────────────────
  const porSlug   = new Map();
  const sinSlug   = [];

  for (const doc of docs) {
    const slug = doc.data.slug?.trim();
    if (slug) {
      if (!porSlug.has(slug)) porSlug.set(slug, []);
      porSlug.get(slug).push(doc);
    } else {
      sinSlug.push(doc);
    }
  }

  const porTitulo = new Map();
  for (const doc of sinSlug) {
    const clave = normalizar(doc.data.titulo) + '|' + (doc.data.tipo || '');
    if (!porTitulo.has(clave)) porTitulo.set(clave, []);
    porTitulo.get(clave).push(doc);
  }

  // ── Procesar grupos ───────────────────────────────────────────────────────
  const grupos       = [];
  const casosDudosos = [];
  let   soloUnicos   = 0;

  function procesarGrupo(clave, tipoClave, grupoDoc) {
    if (grupoDoc.length === 1) { soloUnicos++; return; }

    const sorted    = [...grupoDoc].sort((a, b) => score(b.data) - score(a.data));
    const fusionado = fusionar(grupoDoc);
    const conflictos = detectarConflictos(grupoDoc);

    // ID canónico: preferir slug sobre ID sintético
    const candidatoId = sorted.find(d => !esIdSintetico(d.id))?.id ?? sorted[0].id;
    const aEliminar   = sorted.filter(d => d.id !== candidatoId).map(d => d.id);

    // Es dudoso si hay conflictos de contenido que la fusión automática no resuelve bien
    const esDudoso = conflictos.length > 0;

    const grupo = {
      clave,
      tipo_clave:          tipoClave,
      total_docs:          grupoDoc.length,
      id_canonico:         candidatoId,
      docs_a_eliminar:     aEliminar,
      es_dudoso:           esDudoso,
      conflictos,
      docs_actuales:       sorted.map(d => ({
        id:               d.id,
        slug:             d.data.slug || null,
        titulo:           d.data.titulo || '',
        tipo:             d.data.tipo || '',
        fecha:            fechaIso(d.data.fecha_publicacion),
        resumen_preview:  (d.data.resumen || '').substring(0, 80),
        tiene_imagen:     !!(d.data.imagen_url?.trim()),
        tiene_url_ext:    !!(d.data.url_externa?.trim()),
        tiene_eliminado:  d.data.eliminado !== undefined,
        fuente:           d.data._fuente || (d.data.wp_id ? 'wp_import' : '—'),
        score:            score(d.data),
      })),
      documento_fusionado: fusionado,
    };

    grupos.push(grupo);
    if (esDudoso) casosDudosos.push(grupo);
  }

  for (const [slug, g] of porSlug)   procesarGrupo(slug, 'slug', g);
  for (const [clave, g] of porTitulo) procesarGrupo(clave, 'titulo_tipo', g);

  const totalEliminar = grupos.reduce((n, g) => n + g.docs_a_eliminar.length, 0);

  // ── Informe consola ───────────────────────────────────────────────────────
  const SEP  = '─'.repeat(72);
  const SEP2 = '═'.repeat(72);

  console.log(SEP);
  console.log('📊  RESUMEN');
  console.log(SEP);
  console.log(`  Total docs leídos        : ${docs.length}`);
  console.log(`  Grupos con duplicados    : ${grupos.length}`);
  console.log(`  Docs a fusionar/eliminar : ${totalEliminar}`);
  console.log(`  Docs únicos (sin dup)    : ${soloUnicos}`);
  console.log(`  Casos dudosos (conflicto): ${casosDudosos.length}`);
  console.log('');

  if (grupos.length === 0) {
    console.log('✅ No se encontraron duplicados.\n');
  } else {
    console.log('📋  GRUPOS — propuesta de fusión');
    console.log(SEP);

    for (let i = 0; i < grupos.length; i++) {
      const g   = grupos[i];
      const tag = g.es_dudoso ? '  ⚠️  DUDOSO' : '';
      console.log(`\n[${i + 1}/${grupos.length}]  ${g.tipo_clave === 'slug' ? '🔑 slug' : '📝 título'}: "${g.clave}"${tag}`);
      for (const d of g.docs_actuales) {
        const mark = d.id === g.id_canonico ? '✅ CANONICAL' : '🗑  eliminar ';
        console.log(`   ${mark}  ${d.id}  (score ${d.score}, fuente: ${d.fuente})`);
        console.log(`             imagen=${d.tiene_imagen ? 'sí' : 'no'}  url_ext=${d.tiene_url_ext ? 'sí' : 'no'}  eliminado_field=${d.tiene_eliminado ? 'sí' : 'no'}`);
      }
      const f = g.documento_fusionado;
      console.log(`   📦 FUSIÓN → imagen=${!!f.imagen_url ? 'sí' : 'no'}  resumen=${f.resumen.length > 0 ? f.resumen.length + ' chars' : 'vacío'}  url_ext=${!!f.url_externa ? 'sí' : 'no'}`);
      if (g.conflictos.length) {
        for (const c of g.conflictos) console.log(`   ⚠️  ${c}`);
      }
    }

    if (casosDudosos.length) {
      console.log(`\n${SEP2}`);
      console.log(`⚠️   CASOS DUDOSOS — requieren revisión manual antes de ejecutar (${casosDudosos.length})`);
      console.log(SEP2);
      for (const g of casosDudosos) {
        console.log(`\n  "${g.clave}"`);
        for (const c of g.conflictos) console.log(`    · ${c}`);
      }
    }
  }

  // ── JSON de salida ────────────────────────────────────────────────────────
  const salida = {
    generado:   new Date().toISOString(),
    empresa_id: EID,
    modo:       'dry-run',
    resumen: {
      total_docs:       docs.length,
      grupos_duplicados: grupos.length,
      docs_a_eliminar:  totalEliminar,
      docs_unicos:      soloUnicos,
      casos_dudosos:    casosDudosos.length,
    },
    grupos,
    casos_dudosos: casosDudosos,
  };

  const outPath = OUT_FILE
    ? path.resolve(process.cwd(), OUT_FILE)
    : path.resolve(__dirname, '../duplicados_blog.json');

  fs.writeFileSync(outPath, JSON.stringify(salida, null, 2), 'utf8');
  console.log(`\n💾 JSON guardado en: ${outPath}`);
  console.log('⚠️  DRY-RUN completado — Firestore no fue modificado.\n');
  process.exit(0);
}

main().catch(e => { console.error('❌', e.message || e); process.exit(1); });

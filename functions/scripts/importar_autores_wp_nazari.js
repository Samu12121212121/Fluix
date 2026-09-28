/**
 * importar_autores_wp_nazari.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Obtiene los autores del WordPress de Editorial Nazarí y crea en Firestore
 * los que aún no existen (comparando por slug/nombre normalizado).
 *
 * El WP tiene +300 autores; Firestore tenía 246 al importar el HTML estático.
 * Este script cierra esa brecha usando la API REST de WP como fuente de verdad.
 *
 * Uso:
 *   cd functions
 *   node scripts/importar_autores_wp_nazari.js --descubrir  ← muestra todos los post types WP
 *   node scripts/importar_autores_wp_nazari.js              ← diagnóstico
 *   node scripts/importar_autores_wp_nazari.js --importar   ← crea faltantes
 *   node scripts/importar_autores_wp_nazari.js --actualizar ← también sobreescribe los sin bio/foto
 *
 * Campos que se guardan en Firestore (colección autores):
 *   nombre, slug, bio, descripcion, foto_url, genero, lugar
 *   activo, eliminado, _fuente:'wp', _wp_id, _importado_en
 * ─────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin = require('firebase-admin');
const https  = require('https');
const sa     = require('../serviceAccountKey.json');

if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const EID        = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const WP_BASE    = 'https://www.editorialnazari.com/wp-json/wp/v2';
const WP_ROOT    = 'https://www.editorialnazari.com/wp-json';
const IMPORTAR   = process.argv.includes('--importar');
const ACTUALIZAR = process.argv.includes('--actualizar');
const DESCUBRIR  = process.argv.includes('--descubrir');

// ── HTTPS GET → JSON ──────────────────────────────────────────────────────────
function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'NazariImporter/1.0' } }, res => {
      let raw = '';
      res.on('data', c => raw += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(raw) }); }
        catch (e) { resolve({ status: res.statusCode, body: null }); }
      });
    }).on('error', reject);
  });
}

// ── Limpia HTML de WP ─────────────────────────────────────────────────────────
function limpiarHtml(html = '') {
  return html
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>').replace(/&#8217;/g, '’').replace(/&#8220;/g, '«')
    .replace(/&#8221;/g, '»').replace(/&#8230;/g, '…')
    .trim();
}

// ── Normaliza nombre para comparación ────────────────────────────────────────
function norm(s = '') {
  return s.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').trim();
}

// ── Descubre todos los post types y rutas disponibles en WP ──────────────────
async function descubrirWP() {
  console.log('\n🔍 Descubriendo endpoints del WP de Nazarí...\n');

  // 1. Post types registrados
  console.log('── Post types (wp/v2/types) ──');
  const { status: st, body: types } = await fetchJson(`${WP_BASE}/types`);
  if (st === 200 && types) {
    Object.entries(types).forEach(([slug, info]) => {
      console.log(`   ${slug.padEnd(25)} → "${info.name}" (rest_base: ${info.rest_base || slug})`);
    });
  } else {
    console.log(`   ❌ No disponible (status ${st})`);
  }

  // 2. Rutas del namespace wp/v2
  console.log('\n── Rutas wp/v2 (primeros 30) ──');
  const { status: st2, body: ns } = await fetchJson(`${WP_BASE}?_fields=routes`);
  if (st2 === 200 && ns?.routes) {
    Object.keys(ns.routes).slice(0, 30).forEach(r => console.log(`   ${r}`));
  } else {
    console.log(`   ❌ No disponible (status ${st2})`);
  }

  // 3. Probar slugs relacionados con autores
  console.log('\n── Prueba manual de slugs ──');
  const slugs = ['autores','autor','escritores','author','authors','people','person','bio','colaboradores','contributors'];
  for (const s of slugs) {
    const { status } = await fetchJson(`${WP_BASE}/${s}?per_page=1`);
    const emoji = status === 200 ? '✅' : status === 401 ? '🔒' : '❌';
    console.log(`   ${emoji} /${s.padEnd(20)} status ${status}`);
  }

  console.log('\n💡 Usa el slug con ✅ como --endpoint=<slug> o dile al script cuál es.\n');
}

// ── Detecta el endpoint correcto para autores ─────────────────────────────────
async function detectarEndpoint() {
  // Primero intentar via /types para obtener el rest_base oficial
  const { status, body: types } = await fetchJson(`${WP_BASE}/types`);
  if (status === 200 && types) {
    const palabrasClave = ['autor', 'author', 'escritor', 'writer', 'people', 'person', 'colabor', 'bio'];
    for (const [slug, info] of Object.entries(types)) {
      const hayMatch = palabrasClave.some(p =>
        slug.toLowerCase().includes(p) ||
        (info.name || '').toLowerCase().includes(p) ||
        (info.rest_base || '').toLowerCase().includes(p)
      );
      if (hayMatch) {
        const restBase = info.rest_base || slug;
        console.log(`   ✅ Endpoint detectado via /types: /${restBase} ("${info.name}")`);
        return restBase;
      }
    }
  }

  // Fallback: probar slugs comunes directamente
  const candidatos = ['autores','autor','escritores','author','authors','people','person','bio','colaboradores'];
  for (const cpt of candidatos) {
    const { status: s, body } = await fetchJson(`${WP_BASE}/${cpt}?per_page=1`);
    if (s === 200 && Array.isArray(body)) {
      console.log(`   ✅ Endpoint detectado: /${cpt}`);
      return cpt;
    }
  }

  // Último recurso: usuarios WP
  const { status: su, body: ub } = await fetchJson(`${WP_BASE}/users?per_page=1`);
  if (su === 200 && Array.isArray(ub) && ub.length > 0) {
    console.log(`   ✅ Endpoint detectado: /users (WP users)`);
    return 'users';
  }
  return null;
}

// ── Descarga todos los autores de WP (paginado) ───────────────────────────────
async function fetchAutoresWP(endpoint) {
  const autores = [];
  let page = 1;
  let totalPages = 1;

  console.log(`📡 Descargando autores de WP (/${endpoint})...`);
  while (page <= totalPages) {
    const url = `${WP_BASE}/${endpoint}?per_page=100&page=${page}&_embed&_fields=id,slug,title,content,excerpt,featured_media,_links,_embedded`;
    const { status, body } = await fetchJson(url);

    if (status !== 200 || !Array.isArray(body)) {
      if (page === 1) throw new Error(`WP devolvió status ${status} en /${endpoint}`);
      break;
    }

    autores.push(...body);
    // WP devuelve X-WP-TotalPages en la primera respuesta, pero no tenemos headers aquí.
    // Si devolvió menos de 100 registros, es la última página.
    if (body.length < 100) break;
    page++;
  }

  console.log(`   → ${autores.length} autores obtenidos del WP\n`);
  return autores;
}

// ── Extrae los campos útiles de un item de WP ─────────────────────────────────
function parsearAutorWP(item, esUsers = false) {
  let nombre, slug, bio, descripcion, foto_url;

  if (esUsers) {
    // Endpoint /users
    nombre     = limpiarHtml(item.name || '');
    slug       = item.slug || '';
    bio        = limpiarHtml(item.description || '');
    descripcion = '';
    foto_url   = item.avatar_urls?.['96'] || item.avatar_urls?.['48'] || null;
    // Evitar gravatars genéricos
    if (foto_url && foto_url.includes('gravatar.com') && foto_url.includes('d=mm')) foto_url = null;
  } else {
    // Custom post type
    nombre     = limpiarHtml(item.title?.rendered || '');
    slug       = item.slug || '';
    bio        = limpiarHtml(item.content?.rendered || '');
    descripcion = limpiarHtml(item.excerpt?.rendered || '').substring(0, 500);

    // Imagen destacada embebida
    const media = item._embedded?.['wp:featuredmedia'];
    foto_url = media?.[0]?.source_url || null;
    // Si la imagen destacada no está embebida, intentar con la media de links
    if (!foto_url && item._embedded?.['wp:term']) {
      foto_url = null; // no disponible sin request extra
    }
  }

  return { nombre: nombre.trim(), slug, bio, descripcion, foto_url, _wp_id: item.id };
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function run() {
  console.log('\n👥 Importar autores WP → Firestore (Editorial Nazarí)\n');

  // 1. Detectar endpoint
  console.log('🔍 Detectando endpoint de autores en WP...');
  const endpoint = await detectarEndpoint();
  if (!endpoint) {
    console.error('❌ No se encontró endpoint de autores en WP.');
    console.error('   Prueba acceder manualmente a: https://www.editorialnazari.com/wp-json/wp/v2/');
    process.exit(1);
  }
  const esUsers = endpoint === 'users';

  // 2. Descargar WP
  const wpAutores = await fetchAutoresWP(endpoint);
  if (wpAutores.length === 0) {
    console.error('❌ WP no devolvió autores.');
    process.exit(1);
  }

  // Parsear y filtrar los que tienen nombre
  const wpParsed = wpAutores
    .map(a => parsearAutorWP(a, esUsers))
    .filter(a => a.nombre.length > 1);

  // Construir mapa WP por nombre normalizado
  const wpMap = new Map(); // norm(nombre) → parsed
  for (const a of wpParsed) {
    wpMap.set(norm(a.nombre), a);
    // También indexar por slug por si el nombre varía levemente
    if (a.slug) wpMap.set(a.slug, a);
  }

  // 3. Leer Firestore
  console.log('🔥 Leyendo autores de Firestore...');
  const col   = db.collection('empresas').doc(EID).collection('autores');
  const snap  = await col.get();
  const fsMap = new Map(); // norm(nombre) → {id, data}
  for (const doc of snap.docs) {
    const d = doc.data();
    if (d.nombre) fsMap.set(norm(d.nombre), { id: doc.id, data: d });
    if (d.slug)   fsMap.set(d.slug, { id: doc.id, data: d });
  }
  console.log(`   → ${snap.size} autores en Firestore\n`);

  // 4. Clasificar
  const crear    = []; // en WP, NO en Firestore
  const rellenar = []; // en ambos, pero Firestore sin bio/foto → rellenar con WP

  for (const [normNombre, wpA] of wpMap) {
    if (normNombre === wpA.slug && wpMap.has(norm(wpA.nombre))) continue; // evitar duplicar por slug y nombre
    if (normNombre !== norm(wpA.nombre)) continue; // solo procesar la entrada por nombre, no por slug

    if (!fsMap.has(normNombre)) {
      // No existe por nombre; comprobar por slug
      const porSlug = wpA.slug && fsMap.has(wpA.slug);
      if (!porSlug) crear.push(wpA);
    } else if (ACTUALIZAR) {
      const fs = fsMap.get(normNombre);
      const sinBio  = !fs.data.bio || fs.data.bio.length < 10;
      const sinFoto = !fs.data.foto_url && !fs.data.foto;
      if ((sinBio && wpA.bio) || (sinFoto && wpA.foto_url)) {
        rellenar.push({ fsId: fs.id, fsData: fs.data, wp: wpA });
      }
    }
  }

  console.log('📊 Resumen:');
  console.log(`   Autores en WP:       ${wpParsed.length}`);
  console.log(`   En Firestore:        ${snap.size}`);
  console.log(`   Faltan en FS:        ${crear.length}`);
  if (ACTUALIZAR) console.log(`   En FS sin bio/foto:  ${rellenar.length}`);
  console.log();

  if (crear.length === 0 && rellenar.length === 0) {
    console.log('✅ Firestore está al día con el WP.\n');
    process.exit(0);
  }

  if (crear.length > 0) {
    console.log('📋 Autores que faltan en Firestore (primeros 40):');
    crear.slice(0, 40).forEach((a, i) => {
      const foto = a.foto_url ? '🖼' : '  ';
      const bio  = a.bio ? `bio(${a.bio.length}c)` : 'sin bio';
      console.log(`  ${String(i+1).padStart(3)}. ${foto} ${a.nombre}  [${bio}]`);
    });
    if (crear.length > 40) console.log(`  ... y ${crear.length - 40} más`);
    console.log();
  }

  if (!IMPORTAR && !ACTUALIZAR) {
    console.log('💡 Ejecuta con --importar para crearlos en Firestore.');
    console.log('   Añade --actualizar también para rellenar bio/foto en los existentes sin datos.\n');
    process.exit(0);
  }

  const ahora = admin.firestore.Timestamp.now();
  const LOTE  = 450;
  let batch = db.batch();
  let cnt   = 0;
  let cntCreate = 0;
  let cntUpdate = 0;

  async function flushBatch() {
    if (cnt === 0) return;
    await batch.commit();
    batch = db.batch();
    cnt   = 0;
  }

  // 5. Crear los que faltan
  if (IMPORTAR && crear.length > 0) {
    console.log(`📥 Creando ${crear.length} autores nuevos...`);
    for (const a of crear) {
      const slugBase = norm(a.nombre).replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '');
      const docId    = `wp_${slugBase}_${Date.now().toString(36)}`;
      batch.set(col.doc(docId), {
        nombre:        a.nombre,
        slug:          a.slug || slugBase,
        bio:           a.bio || '',
        descripcion:   a.descripcion || '',
        foto_url:      a.foto_url || null,
        foto:          null,
        genero:        '',
        lugar:         '',
        activo:        true,
        eliminado:     false,
        _fuente:       'wp',
        _wp_id:        a._wp_id || null,
        _importado_en: ahora,
      });
      cnt++;
      cntCreate++;
      if (cnt >= LOTE) await flushBatch();
    }
    await flushBatch();
    console.log(`   ✅ ${cntCreate} autores creados.`);
  }

  // 6. Rellenar bio/foto en los existentes (solo con --actualizar)
  if (ACTUALIZAR && rellenar.length > 0) {
    console.log(`\n🔄 Rellenando bio/foto en ${rellenar.length} autores existentes...`);
    for (const { fsId, fsData, wp } of rellenar) {
      const update = { _actualizado_en: ahora };
      if ((!fsData.bio || fsData.bio.length < 10) && wp.bio) update.bio = wp.bio;
      if (!fsData.descripcion && wp.descripcion) update.descripcion = wp.descripcion;
      if (!fsData.foto_url && !fsData.foto && wp.foto_url) update.foto_url = wp.foto_url;
      if (wp._wp_id) update._wp_id = wp._wp_id;
      batch.update(col.doc(fsId), update);
      cnt++;
      cntUpdate++;
      if (cnt >= LOTE) await flushBatch();
    }
    await flushBatch();
    console.log(`   ✅ ${cntUpdate} autores actualizados.`);
  }

  console.log(`\n🎉 Listo. Creados: ${cntCreate} | Actualizados: ${cntUpdate}\n`);
  process.exit(0);
}

run().catch(e => { console.error('❌', e.message); process.exit(1); });

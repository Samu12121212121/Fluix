/**
 * subir_fotos_autores_completo.js
 * ──────────────────────────────────────────────────────────────────────────────
 * Sube TODAS las fotos de autores (autor1.webp…autor233.webp) a Firebase Storage
 * y actualiza foto_url en Firestore.
 *
 * Mapeo en dos fases:
 *   Fase 1 (imágenes 1-158): usa autores-data.js — mapping exacto nombre↔imagen.
 *   Fase 2 (imágenes 159+): asigna en orden a autores de Firestore sin foto_url,
 *     ordenados por `orden` ASC (que sigue el orden de la web WordPress).
 *
 * Uso:
 *   cd functions
 *   node scripts/subir_fotos_autores_completo.js --dry-run   ← ver mapeo sin subir
 *   node scripts/subir_fotos_autores_completo.js             ← subir fotos nuevas
 *   node scripts/subir_fotos_autores_completo.js --forzar    ← re-sube aunque ya tenga foto_url
 *
 * Requiere: serviceAccountKey.json en functions/
 * ──────────────────────────────────────────────────────────────────────────────
 */

'use strict';

const admin  = require('firebase-admin');
const fs     = require('fs');
const path   = require('path');
const os     = require('os');
const vm     = require('vm');
const crypto = require('crypto');
const { execSync } = require('child_process');

const DRY_RUN = process.argv.includes('--dry-run');
const FORZAR  = process.argv.includes('--forzar');
const EID     = '0PoomHYDUJf5w8tDFRLhFi9iURF3';
const BUCKET  = 'planeaapp-4bea4.firebasestorage.app';
const HTML_DIR = path.join(os.homedir(), 'Desktop', 'imagenes_nazari', 'html_nazari');
const IMG_DIR  = path.join(HTML_DIR, 'img');

// ── Firebase init ─────────────────────────────────────────────────────────────
if (!DRY_RUN) {
  const saPath = path.join(__dirname, '..', 'serviceAccountKey.json');
  if (!fs.existsSync(saPath)) {
    console.error('❌ Se necesita serviceAccountKey.json en functions/');
    process.exit(1);
  }
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(require(saPath)),
      storageBucket: BUCKET,
    });
  }
}

const db     = !DRY_RUN ? admin.firestore() : null;
const bucket = !DRY_RUN ? admin.storage().bucket() : null;

// ── Utilidades ────────────────────────────────────────────────────────────────
function toSlug(nombre) {
  return nombre.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

// ── Cargar autores-data.js (fuente de las 155 imágenes conocidas) ─────────────
function loadAutoresData() {
  const filePath = path.join(HTML_DIR, 'autores-data.js');
  let code;
  if (fs.existsSync(filePath)) {
    code = fs.readFileSync(filePath, 'utf8');
  } else {
    console.log('  ℹ️  autores-data.js no encontrado, recuperando desde git...');
    try {
      code = execSync('git show HEAD:autores-data.js', { cwd: HTML_DIR }).toString();
      console.log('  ✅ Recuperado desde git\n');
    } catch (e) {
      console.error('❌ No se pudo recuperar autores-data.js:', e.message);
      process.exit(1);
    }
  }
  code = code.replace(/^const\s+/gm, 'var ').replace(/^let\s+/gm, 'var ');
  const ctx = {};
  vm.runInNewContext(code, ctx);
  return ctx['AUTORES'] || [];
}

// ── Sube un archivo local a Storage y devuelve URL con token ─────────────────
async function subirArchivo(localPath, storagePath) {
  const token = crypto.randomUUID();
  const file  = bucket.file(storagePath);
  const ext   = path.extname(localPath).toLowerCase();
  const mime  = ext === '.webp' ? 'image/webp' : ext === '.png' ? 'image/png' : 'image/jpeg';

  await file.save(fs.readFileSync(localPath), {
    metadata: {
      contentType: mime,
      metadata: { firebaseStorageDownloadTokens: token },
    },
  });

  const encoded = encodeURIComponent(storagePath).replace(/%2F/g, '%2F');
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encoded}?alt=media&token=${token}`;
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`\n📸 ${DRY_RUN ? '[DRY-RUN] ' : ''}Subiendo fotos de autores — fase completa\n`);

  // ── 1. Cargar autores-data.js → mapeo foto→docId ─────────────────────────
  const autoresStatic = loadAutoresData();
  const staticMapFoto = new Map(); // 'img/autor1.webp' → { nombre, docId }
  for (const a of autoresStatic) {
    const fotoKey = (a.foto || '').trim();
    if (!fotoKey || !fotoKey.startsWith('img/')) continue;
    const docId = `naz-${toSlug(a.nombre)}`;
    staticMapFoto.set(fotoKey, { nombre: a.nombre, docId });
  }
  console.log(`   autores-data.js: ${autoresStatic.length} autores, ${staticMapFoto.size} con foto mapeada`);

  // ── 2. Leer autores de Firestore ─────────────────────────────────────────
  let fsAutores = [];
  if (!DRY_RUN) {
    const col  = db.collection('empresas').doc(EID).collection('autores');
    const snap = await col.get();
    for (const doc of snap.docs) {
      fsAutores.push({ docId: doc.id, ...doc.data() });
    }
  } else {
    // En dry-run simulamos con los datos del script de importación
    // cargando las listas conocidas
    const staticNames = autoresStatic.map(a => ({ nombre: a.nombre, orden: a.id || 999 }));
    // AUTORES_NUEVOS y EXTRA_AUTORES hardcodeados para el dry-run
    const AUTORES_NUEVOS_NOMBRES = [
      'José María García Linares', 'Miha Mazzini',
      'Miguel Ángel Ulecia Martínez', 'Juan Naveros Sánchez',
    ];
    const EXTRA_AUTORES_NOMBRES = [
      'Pedro Cantero y Esteban Ruiz Ballesteros','David Cidoncha','Mercedes Maroto Márquez',
      'Federico Zurita Martínez','María Alcázar Rodríguez','Elisa de Armas','Enrique Palomo Atance',
      'Sofía Pérez Martínez','Francisco Manuel Miranda',
      'Ruth Gómez','David Vegue','Óscar Borona','Francisco Javier Fernández Espinosa',
      'Juan Antonio Trillo López','Carmen M. León Lopa','Enrique J. Vercher García',
      'Francisco Rojas Santos','Xánath Caraza','Eduardo Calvo','Héctor Pose',
      'Carmen Gijón Herrera','Ismael Contreras Carmona','Guillermo Rubio Martín',
      'Víctor Espuny','Saúl Roas Deus','Pedro Blanco Naveros','Slavko Zupcic',
      'Juan José Cuenca López','Jón Sigurður Eyjólfsson','Jordi Navarro Fisas',
      'Lucía Marín','Antonio Cobos Ruz','María Belén Adarve Ramírez',
      'Francisco Castilla Torres','Dori Hernández Montalbán','Consuelo de la Torre',
      'Juan José Castro Martín','Francisco Beltrán Sánchez','Alicia María Expósito',
      'Julia Martínez Sánchez','Teresa Martín Estévez','Francisco Urbano',
      'Guillermo Gómez Muñoz','Fermín López Costero',
      'Pilar Quirosa-Cheyrouze','Cristina Gálvez','Jone Miren Asteinza',
      'Francisco Gil Craviotto','Sandra Clavel','Santi Pérez Isasi','Ángel Olgoso',
      'Salvador Pérez Dueñas','Emilio Ballesteros','Fernando de Villena',
      'Antonio Espinosa Úbeda','José Luis López Enamorado','Mar de los Ríos',
      'Miguel Ángel Malo','Antonio Fernández Ferrer','José Loma','Félix Delgado Ropero',
      'Carmen Hernández Montalbán','Cristina León Lopa','Sergi G. Oset',
      'Paz Monserrat Revillo','Juan Carlos Garvayo','Reza Emilio Juma',
      'Carmina Moreno Arenas','Juan Carlos Friebe','Emilio Rodríguez Linares, Linarett',
      'Francisco J. Martínez-López','Luis López-Quiñones Ruiz','Ángel Fábregas García',
      'Encarni Barragán Sánchez','Pedro Ruiz-Cabello Fernández','José R. Reyes',
      'Borja Angosto Rubio','José Luis Gärtner','Beatriz Alonso Aranzábal',
      'José Antonio Santano','Juan Torres Colomera','Jorge Pastor','Giancarlo Remorini',
      'Félix Terrones',
      'Josefina Martos Peregrín','Francisco Morales Lomas','Carlos Almira Picazo',
      'José Zamora Linares','Vitaliano de la Cruz','Gabriel T. Rojo','Carolina Molina',
      'Marina Tapia','Fernando Morales Núñez','Doceat','Carlos de la Fé',
    ];
    let orden = 500;
    for (const nombre of EXTRA_AUTORES_NOMBRES) {
      fsAutores.push({ docId: `naz-${toSlug(nombre)}`, nombre, foto_url: '', orden: orden++, foto: '' });
    }
    orden = 600;
    for (const nombre of AUTORES_NUEVOS_NOMBRES) {
      fsAutores.push({ docId: `naz-${toSlug(nombre)}`, nombre, foto_url: '', orden: orden++, foto: '' });
    }
    for (const a of staticNames) {
      fsAutores.push({ docId: `naz-${toSlug(a.nombre)}`, nombre: a.nombre, foto_url: '', orden: a.orden, foto: '' });
    }
  }
  console.log(`   Autores en Firestore: ${fsAutores.length}\n`);

  // ── 3. Enumerar imágenes disponibles en img/ ─────────────────────────────
  const imgFiles = fs.readdirSync(IMG_DIR)
    .filter(f => /^autor\d+\.(webp|jpg|jpeg|png)$/i.test(f))
    .sort((a, b) => {
      const na = parseInt(a.replace(/\D/g, ''), 10);
      const nb = parseInt(b.replace(/\D/g, ''), 10);
      return na - nb;
    });
  console.log(`   Imágenes autor*.webp encontradas: ${imgFiles.length}\n`);

  // ── 4. FASE 1: imágenes con mapeo exacto en autores-data.js ─────────────
  const asignacionesFase1 = []; // { fotoFile, nombre, docId }
  const docIdsConFoto1    = new Set();
  const imgUsadasFase1    = new Set();

  for (const imgFile of imgFiles) {
    const key = `img/${imgFile}`;
    if (!staticMapFoto.has(key)) continue;
    const { nombre, docId } = staticMapFoto.get(key);
    asignacionesFase1.push({ fotoFile: imgFile, nombre, docId });
    docIdsConFoto1.add(docId);
    imgUsadasFase1.add(imgFile);
  }
  console.log(`   Fase 1 (autores-data.js): ${asignacionesFase1.length} imágenes mapeadas\n`);

  // ── 5. FASE 2: imágenes sin mapeo → autores sin foto_url, por orden WP ──
  // Construir mapa docId → foto_url actual de Firestore
  const fsMap = new Map();
  for (const a of fsAutores) fsMap.set(a.docId, a);

  // Autores sin foto_url, ordenados por `orden` ASC (orden de importación WP)
  const sinFoto = fsAutores
    .filter(a => {
      if (docIdsConFoto1.has(a.docId)) return false; // ya tiene foto de fase 1
      const fotoUrl = a.foto_url || a.foto || '';
      if (FORZAR) return true;
      return !fotoUrl || fotoUrl.startsWith('img/');
    })
    .sort((a, b) => {
      const oa = (a.orden ?? a.prioridad ?? 999);
      const ob = (b.orden ?? b.prioridad ?? 999);
      return oa - ob;
    });

  // Imágenes sobrantes de fase 1 (las que no estaban en autores-data.js)
  const imgsFase2 = imgFiles.filter(f => !imgUsadasFase1.has(f));

  const asignacionesFase2 = [];
  const limite = Math.min(imgsFase2.length, sinFoto.length);
  for (let i = 0; i < limite; i++) {
    asignacionesFase2.push({
      fotoFile: imgsFase2[i],
      nombre:   sinFoto[i].nombre,
      docId:    sinFoto[i].docId,
    });
  }

  if (imgsFase2.length > sinFoto.length) {
    console.log(`  ⚠️  Hay ${imgsFase2.length} imágenes extra pero solo ${sinFoto.length} autores sin foto — ${imgsFase2.length - sinFoto.length} imágenes NO asignadas`);
  } else if (imgsFase2.length < sinFoto.length) {
    console.log(`  ⚠️  Hay ${sinFoto.length - imgsFase2.length} autores sin foto y sin imagen disponible — quedarán sin foto`);
  }

  console.log(`   Fase 2 (imágenes extras): ${asignacionesFase2.length} imágenes asignadas\n`);

  // ── 6. Mostrar plan completo ──────────────────────────────────────────────
  const todas = [...asignacionesFase1, ...asignacionesFase2];

  if (DRY_RUN) {
    console.log('═'.repeat(80));
    console.log('PLAN DE SUBIDA — Fase 1 (autores-data.js):');
    console.log('═'.repeat(80));
    for (const a of asignacionesFase1) {
      const existe = fs.existsSync(path.join(IMG_DIR, a.fotoFile));
      console.log(`  ${existe ? '✅' : '❌'} ${a.fotoFile.padEnd(20)} → ${a.nombre} [${a.docId}]`);
    }

    console.log('\n' + '═'.repeat(80));
    console.log('PLAN DE SUBIDA — Fase 2 (imágenes extra, orden WP):');
    console.log('═'.repeat(80));
    for (const a of asignacionesFase2) {
      const existe = fs.existsSync(path.join(IMG_DIR, a.fotoFile));
      console.log(`  ${existe ? '✅' : '❌'} ${a.fotoFile.padEnd(20)} → ${a.nombre} [${a.docId}]`);
    }

    // Autores sin imagen asignada
    const docIdsAsignados = new Set(todas.map(a => a.docId));
    const sinImagen = sinFoto.filter(a => !docIdsAsignados.has(a.docId));
    if (sinImagen.length > 0) {
      console.log('\n' + '═'.repeat(80));
      console.log('AUTORES SIN IMAGEN ASIGNADA:');
      console.log('═'.repeat(80));
      for (const a of sinImagen) {
        console.log(`  ⚠️  ${a.nombre} [${a.docId}] orden=${a.orden}`);
      }
    }

    console.log(`\n📊 Resumen:`);
    console.log(`   Fase 1: ${asignacionesFase1.length} imágenes (mapeo exacto)`);
    console.log(`   Fase 2: ${asignacionesFase2.length} imágenes (orden WP)`);
    console.log(`   Total:  ${todas.length} imágenes a subir`);
    console.log('\n[DRY-RUN] Nada fue subido. Revisa el plan y ejecuta sin --dry-run para subir.\n');
    return;
  }

  // ── 7. Subir fotos ────────────────────────────────────────────────────────
  const col = db.collection('empresas').doc(EID).collection('autores');
  let subidas = 0, saltadas = 0, errores = 0;

  for (const asig of todas) {
    const localPath = path.join(IMG_DIR, asig.fotoFile);
    if (!fs.existsSync(localPath)) {
      console.log(`  ⚠️  No existe: ${asig.fotoFile} (${asig.nombre})`);
      continue;
    }

    // Saltar si ya tiene foto_url real y no estamos forzando
    if (!FORZAR) {
      const fsData = fsMap.get(asig.docId);
      if (fsData) {
        const fotoUrl = fsData.foto_url || fsData.foto || '';
        if (fotoUrl && fotoUrl.startsWith('https://firebasestorage')) {
          saltadas++;
          continue;
        }
      }
    }

    const ext         = path.extname(asig.fotoFile);
    const storagePath = `empresas/${EID}/autores/${asig.docId}${ext}`;

    try {
      await sleep(200);
      const url = await subirArchivo(localPath, storagePath);
      await col.doc(asig.docId).set({ foto_url: url, foto: url }, { merge: true });
      console.log(`  ✅ ${asig.nombre} ← ${asig.fotoFile}`);
      subidas++;
    } catch (e) {
      console.log(`  ❌ ${asig.nombre}: ${e.message}`);
      errores++;
    }
  }

  console.log('\n══════════════════════════════════════════');
  console.log(`  Subidas:        ${subidas}`);
  console.log(`  Ya tenían foto: ${saltadas}`);
  console.log(`  Errores:        ${errores}`);
  if (subidas > 0) {
    console.log(`\n✅ Fotos en Storage: gs://${BUCKET}/empresas/${EID}/autores/`);
    console.log('   Los foto_url en Firestore apuntan ahora a Storage.');
    console.log('   Fluix y la web mostrarán las fotos automáticamente.');
  }
  process.exit(0);
}

main().catch(e => { console.error('\n❌', e.message || e); process.exit(1); });

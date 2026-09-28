/**
 * importar_autores_nazari.js
 * ──────────────────────────────────────────────────────────────────────────
 * Sube los 251 autores de Editorial Nazarí a Firestore (colección `autores`).
 *
 * Fuentes:
 *   1. autores-data.js (html_nazari) — 155 autores con bio completa, foto, género
 *   2. EXTRA_AUTORES (hardcoded abajo) — 86 nombres restantes (páginas 5-7 web)
 *
 * Uso:
 *   cd functions
 *   node importar_autores_nazari.js
 *   node importar_autores_nazari.js --dry-run   (solo muestra, no escribe)
 *
 * Requiere: serviceAccountKey.json en functions/ (o firebase login)
 * ──────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const fs    = require('fs');
const path  = require('path');
const os    = require('os');
const vm    = require('vm');

const DRY_RUN    = process.argv.includes('--dry-run');
const HTML_DIR   = path.join(os.homedir(), 'Desktop', 'imagenes_nazari', 'html_nazari');
const EID        = '0PoomHYDUJf5w8tDFRLhFi9iURF3';

// ── Credenciales ─────────────────────────────────────────────────────────────
if (!DRY_RUN) {
  const saPath = path.join(__dirname, 'serviceAccountKey.json');
  if (fs.existsSync(saPath)) {
    const sa = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(sa) });
  } else {
    function getRefreshToken() {
      const candidates = [
        path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
        path.join(process.env.APPDATA || '', 'Roaming', 'configstore', 'firebase-tools.json'),
        path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
      ];
      for (const p of candidates) {
        try { const d = JSON.parse(fs.readFileSync(p, 'utf8')); const rt = d?.tokens?.refresh_token; if (rt) return rt; } catch (_) {}
      }
      return null;
    }
    const rt = getRefreshToken();
    if (!rt) { console.error('❌ No se encontró serviceAccountKey.json ni token de Firebase CLI.'); process.exit(1); }
    admin.initializeApp({ credential: admin.credential.refreshToken({ type: 'authorized_user', client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com', client_secret: 'j9iVZfS8ywKVtZdp0to4vn1p', refresh_token: rt }), projectId: 'planeaapp-4bea4' });
  }
}

// ── Cargar autores-data.js ────────────────────────────────────────────────────
function loadAutoresData() {
  const filePath = path.join(HTML_DIR, 'autores-data.js');
  if (!fs.existsSync(filePath)) {
    console.warn(`  ⚠️  No encontrado: ${filePath}`);
    return [];
  }
  let code = fs.readFileSync(filePath, 'utf8');
  code = code.replace(/^const\s+/gm, 'var ').replace(/^let\s+/gm, 'var ');
  const ctx = {};
  vm.runInNewContext(code, ctx);
  return ctx['AUTORES'] || [];
}

// ── 4 autores de página 3 de la web no incluidos en ninguna fuente ───────────
const AUTORES_NUEVOS = [
  {
    nombre: 'José María García Linares',
    bio: 'Nacido en Melilla en 1977, es filólogo y doctor por la Universidad de Granada, donde enseña en la Ciudad Autónoma de Melilla. Ha publicado numerosos poemarios —«Palabra iluminada» (2018), «Cántico» (2020)— junto con ediciones críticas y ensayos sobre literatura española. También ejerce la crítica literaria en publicaciones como Ideal y Quimera.',
    descripcion: 'Filólogo, poeta y crítico literario. Doctor por la Universidad de Granada, nacido en Melilla (1977).',
    genero: 'Poesía', lugar: 'Melilla',
  },
  {
    nombre: 'Miha Mazzini',
    bio: 'Nacido en 1961, es uno de los autores eslovenos más importantes y premiados, con gran éxito de ventas. Trabaja como guionista y director de cine, siendo miembro de la Academia Europea de Cine. Sus obras superan los 30 títulos traducidos a 11 idiomas. Entre sus galardones destacan el Premio Pájaro de Oro, la nominación al Premio Literario IMPAC Dublin y el Premio Kresnik por su novela autobiográfica Infancia (2016). Web: www.mihamazzini.com.',
    descripcion: 'Uno de los autores eslovenos más premiados. Guionista y miembro de la Academia Europea de Cine.',
    genero: 'Narrativa', lugar: 'Eslovenia',
  },
  {
    nombre: 'Miguel Ángel Ulecia Martínez',
    bio: 'Nacido en Tetuán en 1953, es doctor en Cardiología y Máster en Salud Pública por la Universidad de Granada. Pasó más de cuarenta años como cardiólogo en hospitales granadinos y como profesor universitario. Fue Presidente de la Sociedad Científica Andaluza de Cardiología (2006-2012) y fundó la Fundación Andaluza del Corazón en 2010. Su obra literaria, iniciada en 2012, incluye la trilogía de novela histórica sobre el Maristán Nazarí.',
    descripcion: 'Doctor en Cardiología y novelista histórico. Nacido en Tetuán (1953), residente en Granada.',
    genero: 'Narrativa', lugar: 'Granada',
  },
  {
    nombre: 'Juan Naveros Sánchez',
    bio: 'Nacido en Castillo de Tajarja (Granada), es doctor en Filología Hispánica por la Universidad de Granada. Trabajó como profesor de lengua y literatura en institutos de enseñanza secundaria de Andalucía. Es autor de libros de investigación histórico-literaria, recopilador de cuentos populares y colaborador en revistas especializadas. Su obra abarca la investigación sobre figuras literarias españolas y la novela histórica.',
    descripcion: 'Doctor en Filología Hispánica por la UGR. Investigador literario e historiador nacido en Castillo de Tajarja (Granada).',
    genero: 'Narrativa', lugar: 'Granada',
  },
];

// ── 86 autores que faltan en autores-data.js (páginas 5-7 de la web) ─────────
const EXTRA_AUTORES = [
  // Páginas 1-2 (nuevos en WordPress no incluidos en autores-data.js)
  'Pedro Cantero y Esteban Ruiz Ballesteros','David Cidoncha','Mercedes Maroto Márquez',
  'Federico Zurita Martínez','María Alcázar Rodríguez','Elisa de Armas','Enrique Palomo Atance',
  'Sofía Pérez Martínez','Francisco Manuel Miranda',
  // Página 5 (entradas 6-40)
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
  // Página 6
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
  // Página 7
  'Josefina Martos Peregrín','Francisco Morales Lomas','Carlos Almira Picazo',
  'José Zamora Linares','Vitaliano de la Cruz','Gabriel T. Rojo','Carolina Molina',
  'Marina Tapia','Fernando Morales Núñez','Doceat','Carlos de la Fé',
];

// ── Slug para docId ───────────────────────────────────────────────────────────
function toSlug(nombre) {
  return nombre.toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log(`🚀 ${DRY_RUN ? '[DRY-RUN] ' : ''}Importando autores a Firestore...\n`);

  // 1. Cargar los 155 del static JS
  const staticData = loadAutoresData();
  console.log(`  📄 autores-data.js: ${staticData.length} autores cargados`);

  // 2. Construir lista completa, deduplicar por nombre
  const vistosNombre = new Set();
  const allAutores = [];

  for (const a of staticData) {
    const key = (a.nombre || '').toLowerCase().trim();
    if (!key || vistosNombre.has(key)) continue;
    vistosNombre.add(key);
    allAutores.push({
      nombre:      a.nombre || '',
      bio:         a.bio || a.descripcion || '',
      descripcion: a.descripcion || (a.bio ? a.bio.substring(0, 180) + (a.bio.length > 180 ? '…' : '') : ''),
      genero:      a.genero || '',
      lugar:       a.lugar || '',
      foto:        a.foto || a.foto_url || '',
      busqueda:    a.busqueda || a.nombre || '',
      activo:      true,
      orden:       a.id || 999,
    });
  }

  // Nuevos autores (con bio completa, procedentes de scraping manual de la web)
  let nuevosAdded = 0;
  for (const a of AUTORES_NUEVOS) {
    const key = a.nombre.toLowerCase().trim();
    if (vistosNombre.has(key)) continue;
    vistosNombre.add(key);
    allAutores.push({
      nombre:      a.nombre,
      bio:         a.bio || '',
      descripcion: a.descripcion || (a.bio ? a.bio.substring(0, 180) + '…' : ''),
      genero:      a.genero || '',
      lugar:       a.lugar || '',
      foto:        '',
      busqueda:    a.nombre,
      activo:      true,
      orden:       600 + nuevosAdded,
    });
    nuevosAdded++;
  }
  if (nuevosAdded > 0) console.log(`  🆕 ${nuevosAdded} autores nuevos (con bio) añadidos`);

  let extraAdded = 0;
  for (const nombre of EXTRA_AUTORES) {
    const key = nombre.toLowerCase().trim();
    if (vistosNombre.has(key)) continue;
    vistosNombre.add(key);
    allAutores.push({
      nombre, bio: '', descripcion: '', genero: '', lugar: '',
      foto: '', busqueda: nombre, activo: true, orden: 500 + extraAdded,
    });
    extraAdded++;
  }

  console.log(`  🌐 ${extraAdded} autores extra (sin bio) añadidos`);
  console.log(`\n  ✅ Total autores únicos: ${allAutores.length}\n`);

  if (DRY_RUN) {
    allAutores.forEach(a => console.log(`  • ${a.nombre} [${a.genero || '—'}]`));
    console.log('\n[DRY-RUN] No se escribió nada.');
    return;
  }

  // 3. Subir a Firestore colección `autores`
  const db     = admin.firestore();
  const colRef = db.collection('empresas').doc(EID).collection('autores');

  const existSnap = await colRef.get();
  const existentes = new Set(existSnap.docs.map(d => d.id));
  console.log(`  ℹ️  Autores ya en Firestore: ${existentes.size}`);

  let batch   = db.batch();
  let cnt     = 0;
  let subidos = 0;
  let actualizados = 0;

  for (let i = 0; i < allAutores.length; i++) {
    const a     = allAutores[i];
    const docId = `naz-${toSlug(a.nombre)}`;
    const data  = { ...a, fecha_actualizacion: admin.firestore.FieldValue.serverTimestamp() };
    if (!existentes.has(docId)) data.fecha_creacion = admin.firestore.FieldValue.serverTimestamp();

    batch.set(colRef.doc(docId), data, { merge: true });
    existentes.has(docId) ? actualizados++ : subidos++;
    cnt++;

    if (cnt === 400) {
      await batch.commit();
      batch = db.batch();
      cnt   = 0;
      console.log(`  ⏳ Lote enviado…`);
    }
  }
  if (cnt > 0) await batch.commit();

  console.log(`\n✅ Completado:`);
  console.log(`   Nuevos:       ${subidos}`);
  console.log(`   Actualizados: ${actualizados}`);
  console.log(`\nDestino: empresas/${EID}/autores`);
  process.exit(0);
}

main().catch(err => { console.error('❌', err.message || err); process.exit(1); });

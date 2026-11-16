// functions/scripts/subir_imagenes_negocios.ts
//
// Sube todas las imágenes descargadas a Firebase Storage y actualiza Firestore:
//   fotoUrl          ← primera imagen de Sitio/
//   fotoSecundariaUrl← segunda imagen de Sitio/
//   fotosGaleria     ← todas las imágenes de Sitio/ + Adicionales/
//   servicios/{id}.fotoUrl ← primera imagen de Servicios/ que coincide con el nombre
//
// Uso:
//   cd functions
//   npx ts-node --project scripts/tsconfig.scripts.json --transpileOnly scripts/subir_imagenes_negocios.ts

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';

const saPath = path.resolve(__dirname, '..', 'serviceAccountKey.json');
admin.initializeApp({ credential: admin.credential.cert(require(saPath)) });

const db      = admin.firestore();
const storage = admin.storage();
const bucket  = storage.bucket('planeaapp-4bea4.firebasestorage.app');

const IMAGENES_DIR = 'C:/Users/Samu/Desktop/Negocios_Guadalajara_Imagenes';
const MIME: Record<string, string> = {
  '.jpg':  'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png':  'image/png',
  '.webp': 'image/webp',
  '.gif':  'image/gif',
};

// Convierte nombre de carpeta → posible doc ID en Firestore
function folderToId(folderName: string): string {
  return folderName
    .toLowerCase()
    .normalize('NFD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');
}

// Sube un archivo y devuelve la URL pública
async function subirArchivo(localPath: string, storagePath: string): Promise<string> {
  const ext  = path.extname(localPath).toLowerCase();
  const mime = MIME[ext] ?? 'image/jpeg';
  const file = bucket.file(storagePath);
  await file.save(fs.readFileSync(localPath), {
    metadata: { contentType: mime },
    public: true,
    resumable: false,
  });
  return `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
}

// Lista archivos de imagen en una carpeta, ordenados por nombre
function listarImagenes(dir: string): string[] {
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir)
    .filter(f => Object.keys(MIME).includes(path.extname(f).toLowerCase()))
    .sort()
    .map(f => path.join(dir, f));
}

// Busca el docId real en Firestore fuzzy-matching el nombre de carpeta
const _docCache: Map<string, string | null> = new Map();
async function resolverDocId(folderName: string): Promise<string | null> {
  if (_docCache.has(folderName)) return _docCache.get(folderName)!;

  const candidato = folderToId(folderName);

  // Intento 1: doc directo por ID
  const directo = await db.collection('negocios_publicos').doc(candidato).get();
  if (directo.exists) { _docCache.set(folderName, candidato); return candidato; }

  // Intento 2: buscar por nombre normalizado
  const snap = await db.collection('negocios_publicos').get();
  for (const d of snap.docs) {
    const nombre = (d.data().nombre as string) ?? '';
    const normNombre = folderToId(nombre);
    // Comprueba si el folder name está contenido o viceversa
    if (normNombre === candidato ||
        normNombre.includes(candidato) ||
        candidato.includes(normNombre)) {
      _docCache.set(folderName, d.id);
      return d.id;
    }
  }

  _docCache.set(folderName, null);
  return null;
}

async function procesarNegocio(negDir: string): Promise<void> {
  const folderName = path.basename(negDir);
  const docId = await resolverDocId(folderName);

  if (!docId) {
    console.log(`  [SKIP] ${folderName} — no encontrado en Firestore`);
    return;
  }

  const storagePrefijo = `negocios_publicos/${docId}`;
  const updateDoc: Record<string, any> = {};
  const galeria: string[] = [];

  // ── SITIO ──────────────────────────────────────────────────────────────────
  const sitioDir     = path.join(negDir, 'Sitio');
  const sitioImgs    = listarImagenes(sitioDir);

  for (let i = 0; i < sitioImgs.length; i++) {
    const local      = sitioImgs[i];
    const ext        = path.extname(local);
    const storagePath= `${storagePrefijo}/sitio/sitio_${String(i + 1).padStart(2, '0')}${ext}`;
    const url        = await subirArchivo(local, storagePath);

    if (i === 0) updateDoc['fotoUrl']           = url;
    if (i === 1) updateDoc['fotoSecundariaUrl'] = url;
    galeria.push(url);
    process.stdout.write('.');
  }

  // ── ADICIONALES ────────────────────────────────────────────────────────────
  const adicDir  = path.join(negDir, 'Adicionales');
  const adicImgs = listarImagenes(adicDir);
  for (let i = 0; i < adicImgs.length; i++) {
    const local       = adicImgs[i];
    const ext         = path.extname(local);
    const storagePath = `${storagePrefijo}/adicionales/adicional_${String(i + 1).padStart(2, '0')}${ext}`;
    const url         = await subirArchivo(local, storagePath);
    galeria.push(url);
    process.stdout.write('.');
  }

  if (galeria.length > 0) updateDoc['fotosGaleria'] = galeria;

  // ── SERVICIOS ──────────────────────────────────────────────────────────────
  const serviciosDir  = path.join(negDir, 'Servicios');
  const serviciosImgs = listarImagenes(serviciosDir);

  if (serviciosImgs.length > 0) {
    // Obtener servicios existentes del negocio
    const svsSnap = await db.collection('negocios_publicos').doc(docId).collection('servicios').get();

    // Si hay servicios, asignar imágenes en orden
    // Si no, guardar como galeria_servicios en el doc principal
    if (!svsSnap.empty) {
      const svDocs = svsSnap.docs;
      const svBatch = db.batch();
      for (let i = 0; i < Math.min(serviciosImgs.length, svDocs.length); i++) {
        const local       = serviciosImgs[i];
        const ext         = path.extname(local);
        const storagePath = `${storagePrefijo}/servicios/servicio_${String(i + 1).padStart(2, '0')}${ext}`;
        const url         = await subirArchivo(local, storagePath);
        svBatch.set(svDocs[i].ref, { fotoUrl: url }, { merge: true });
        // También añadir a galería general
        galeria.push(url);
        process.stdout.write('.');
      }
      await svBatch.commit();
      updateDoc['fotosGaleria'] = galeria; // actualizar con servicios añadidos
    } else {
      // Sin subcollección de servicios: guardar como galeriaServicios
      const galeriaServs: string[] = [];
      for (let i = 0; i < serviciosImgs.length; i++) {
        const local       = serviciosImgs[i];
        const ext         = path.extname(local);
        const storagePath = `${storagePrefijo}/servicios/servicio_${String(i + 1).padStart(2, '0')}${ext}`;
        const url         = await subirArchivo(local, storagePath);
        galeriaServs.push(url);
        galeria.push(url);
        process.stdout.write('.');
      }
      updateDoc['galeriaServicios'] = galeriaServs;
      updateDoc['fotosGaleria']     = galeria;
    }
  }

  // ── Actualizar Firestore ───────────────────────────────────────────────────
  if (Object.keys(updateDoc).length > 0) {
    await db.collection('negocios_publicos').doc(docId).set(updateDoc, { merge: true });
  }

  const totalSubidas = sitioImgs.length + adicImgs.length + serviciosImgs.length;
  console.log(` [${docId}] ${totalSubidas} imgs (sitio:${sitioImgs.length} adic:${adicImgs.length} svs:${serviciosImgs.length})`);
}

async function main() {
  if (!fs.existsSync(IMAGENES_DIR)) {
    console.error(`No existe la carpeta: ${IMAGENES_DIR}`);
    process.exit(1);
  }

  const negocios = fs.readdirSync(IMAGENES_DIR)
    .map(n => path.join(IMAGENES_DIR, n))
    .filter(p => fs.statSync(p).isDirectory());

  // Filtrar los que tienen imágenes
  const conImagenes = negocios.filter(negDir => {
    const cats = ['Sitio', 'Servicios', 'Adicionales'];
    return cats.some(c => listarImagenes(path.join(negDir, c)).length > 0);
  });

  console.log(`\nNegocios con imagenes: ${conImagenes.length}`);
  console.log(`Bucket: ${bucket.name}\n`);

  let procesados = 0;
  for (const negDir of conImagenes) {
    process.stdout.write(`[${++procesados}/${conImagenes.length}] ${path.basename(negDir)} `);
    try {
      await procesarNegocio(negDir);
    } catch (e) {
      console.log(` ERROR: ${e}`);
    }
  }

  // Estado final
  const snap = await db.collection('negocios_publicos').get();
  const docs = snap.docs.map(d => d.data());
  const conFoto    = docs.filter((d: any) => d.fotoUrl).length;
  const conGaleria = docs.filter((d: any) => d.fotosGaleria?.length > 0).length;

  console.log(`\n${'─'.repeat(50)}`);
  console.log(`fotoUrl      : ${conFoto} / ${snap.size}`);
  console.log(`fotosGaleria : ${conGaleria} / ${snap.size}`);
  console.log(`${'─'.repeat(50)}`);

  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });

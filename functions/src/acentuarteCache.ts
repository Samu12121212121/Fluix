/**
 * acentuarteCache.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Igual que nazariCache.ts pero para Editorial Acentuarte.
 *
 * Flujo:
 *   Fluix edita algo → Firestore trigger → CF lee colección completa
 *   → genera window.__DATA__ → sube a Storage (cache/acentuarte-data.js)
 *   → web lo carga gratis sin consultas a Firestore
 *
 * URL pública resultante:
 *   https://storage.googleapis.com/planeaapp-4bea4.firebasestorage.app/cache/acentuarte-data.js
 * ─────────────────────────────────────────────────────────────────────────────
 */

import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

const db     = admin.firestore();
const REGION = "europe-west1";
const EID    = "pU4wGaElcyoDR5dA0YNO";
const BUCKET = "planeaapp-4bea4.firebasestorage.app";
const FILE   = "cache/acentuarte-data.js";

// ── Helpers ───────────────────────────────────────────────────────────────────

async function uploadCache(content: string): Promise<void> {
  const file = admin.storage().bucket(BUCKET).file(FILE);
  await file.save(content, {
    contentType: "application/javascript; charset=utf-8",
    metadata: { cacheControl: "public, max-age=3600, s-maxage=3600" },
  });
  logger.info(`✅ ${FILE} subido (${Math.round(content.length / 1024)} KB)`);
}

function serDoc(data: FirebaseFirestore.DocumentData, id: string): Record<string, unknown> {
  const out: Record<string, unknown> = { id, ...data };
  for (const [k, v] of Object.entries(out)) {
    if (v && typeof v === "object" && "toDate" in (v as object)) {
      out[k] = (v as admin.firestore.Timestamp).toDate().toISOString();
    }
  }
  return out;
}

function tsMs(v: unknown): number {
  if (!v) return 0;
  if (typeof (v as any).toDate === "function") return (v as any).toDate().getTime();
  if (typeof v === "object" && (v as any).seconds) return (v as any).seconds * 1000;
  const t = new Date(String(v)).getTime();
  return isNaN(t) ? 0 : t;
}

// ── Regeneración completa ──────────────────────────────────────────────────────

async function regenerar(): Promise<Record<string, number>> {
  const [libSnap, autSnap, blogSnap] = await Promise.all([
    db.collection("empresas").doc(EID).collection("catalogo_web").get(),
    db.collection("empresas").doc(EID).collection("autores").get(),
    db.collection("empresas").doc(EID).collection("blog").get(),
  ]);

  // ── Libros ─────────────────────────────────────────────────────────────────
  const booksRaw = libSnap.docs
    .map(d => serDoc(d.data(), d.id))
    .filter(l => l.activo !== false && l.eliminado !== true)
    .sort((a, b) => {
      const ta = String(a.titulo ?? a.nombre ?? "");
      const tb = String(b.titulo ?? b.nombre ?? "");
      return ta.localeCompare(tb, "es");
    });

  const books = booksRaw.map(l => ({
    id:             l.slug ?? l.id,
    name:           l.titulo ?? l.nombre ?? "",
    author:         l.autor  ?? l.campo_autor ?? "",
    image:          l.imagen ?? l.imagen_url  ?? "",
    desc:           l.sinopsis ?? l.descripcion ?? "",
    isbn:           l.isbn ?? l.isbn13 ?? "",
    precio:         l.precio ?? "",
    genero:         l.genero ?? l.categoria ?? "",
    coleccion:      l.coleccion ?? l.campo_coleccion ?? "",
    encuadernacion: l.encuadernacion ?? "",
    formato:        l.formato ?? "",
    slug:           l.slug ?? l.id,
  }));

  // ── Autores ────────────────────────────────────────────────────────────────
  const autoresRaw = autSnap.docs
    .map(d => serDoc(d.data(), d.id))
    .filter(a => a.activo !== false && a.eliminado !== true)
    .sort((a, b) => String(a.nombre ?? "").localeCompare(String(b.nombre ?? ""), "es"));

  const authors = autoresRaw.map(a => {
    const pubs = books
      .map((b, i) => ({ b, i }))
      .filter(x => x.b.author === String(a.nombre ?? ""))
      .map(x => ({ name: x.b.name, image: x.b.image, bookIndex: x.i }));
    return {
      id:           a.slug ?? a.id,
      name:         a.nombre ?? "",
      image:        a.foto_url ?? a.imagen ?? "",
      bio:          a.bio ?? a.descripcion ?? "",
      publications: pubs,
      interviews:   (a.entrevistas as unknown[]) ?? [],
      role:         a.rol ?? "",
    };
  });

  // ── Blog ───────────────────────────────────────────────────────────────────
  const blogAll = blogSnap.docs
    .map(d => serDoc(d.data(), d.id))
    .filter(p => p.eliminado !== true && (p.publicada === true || p.estado === "publicado"))
    .sort((a, b) => tsMs(b.fecha_publicacion) - tsMs(a.fecha_publicacion));

  const mapBlog = (e: Record<string, unknown>) => ({
    id:      e.slug ?? e.id,
    titulo:  e.titulo ?? "",
    imagen:  e.imagen_url ?? e.imagen ?? "",
    resumen: e.resumen ?? e.descripcion ?? "",
    fecha:   e.fecha_publicacion ?? null,
    autor:   e.autor ?? "",
    slug:    e.slug ?? e.id,
  });

  const tipo = (e: Record<string, unknown>) => String(e.tipo ?? "").toLowerCase();
  const noticias    = blogAll.filter(e => tipo(e) === "noticia"    || tipo(e) === "noticias").map(mapBlog);
  const entrevistas = blogAll.filter(e => tipo(e) === "entrevista" || tipo(e) === "entrevistas").map(mapBlog);

  // ── Payload window.__DATA__ ────────────────────────────────────────────────
  const payload = { books, authors, noticias, entrevistas };
  const js = `// Acentuarte cache — ${new Date().toISOString()}\nwindow.__DATA__ = ${JSON.stringify(payload)};\n`;

  await uploadCache(js);
  return {
    libros: books.length,
    autores: authors.length,
    noticias: noticias.length,
    entrevistas: entrevistas.length,
  };
}

// ── Triggers ──────────────────────────────────────────────────────────────────

export const onAcentuarteCatalogoCambio = onDocumentWritten(
  { document: `empresas/${EID}/catalogo_web/{docId}`, region: REGION },
  async () => { await regenerar(); }
);

export const onAcentuarteAutoresCambio = onDocumentWritten(
  { document: `empresas/${EID}/autores/{docId}`, region: REGION },
  async () => { await regenerar(); }
);

export const onAcentuarteBlogCambio = onDocumentWritten(
  { document: `empresas/${EID}/blog/{docId}`, region: REGION },
  async () => { await regenerar(); }
);

// ── HTTP: fuerza regeneración manual (llamar tras deploy o importación) ────────
// Uso: GET https://.../regenerarCacheAcentuarte?key=<CACHE_REGEN_KEY>
export const regenerarCacheAcentuarte = onRequest(
  { region: REGION, cors: false },
  async (req, res) => {
    const apiKey = req.query.key as string | undefined;
    if (!apiKey || apiKey !== process.env.CACHE_REGEN_KEY) {
      res.status(401).json({ error: "No autorizado" });
      return;
    }
    const counts = await regenerar();
    logger.info("✅ regenerarCacheAcentuarte manual", counts);
    res.json({ ok: true, counts });
  }
);

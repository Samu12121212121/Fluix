/**
 * nazariMigracion.ts
 * Cloud Functions para importar contenido histórico de Editorial Nazarí
 * desde el archivo maestro (master.json en Storage) a Firestore bajo demanda.
 *
 * Exports:
 *   buscarArchivoNazari          — busca items en el archivo histórico
 *   importarContenidoNazari      — importa un item concreto a Firestore
 *   migrarDatosNazariDesdeWeb    — migra libros→catalogo_web + entrevistas prensa→blog
 */

import * as admin from "firebase-admin";
import * as path from "path";
import * as crypto from "crypto";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { verificarAuthYEmpresa } from "./utils/authGuard";
import fetch from "node-fetch";

const REGION          = "europe-west1";
const BUCKET          = "planeaapp-4bea4.firebasestorage.app";
const MASTER_PATH     = "nazari/migracion/master.json";
const STORAGE_PREFIX  = "nazari/migracion";
const EID_NAZARI      = "0PoomHYDUJf5w8tDFRLhFi9iURF3";
const CACHE_TTL_MS    = 10 * 60 * 1000; // 10 min — warm instance reusa el master

// ── Tipos ─────────────────────────────────────────────────────────────────────

interface ImagenEntry {
  wp_url:      string;
  fluix_url:   string | null;
  descargada:  boolean;
}

interface ArchivoItem {
  wp_id:               number;
  fluix_id:            string | null;
  importado_en_fluix:  boolean;
  tipo:                string;
  titulo:              string;
  slug:                string;
  fecha:               string;
  fecha_modificado?:   string;
  url_original?:       string;
  extracto?:           string;
  contenido_html?:     string;
  categorias?:         string[];
  etiquetas?:          string[];
  autor?:              string;
  autor_wp_id?:        number;
  imagen_principal:    ImagenEntry | null;
  imagenes_contenido:  ImagenEntry[];
  seo?:                { meta_title: string; meta_description: string; og_image: string };
  // Libros
  isbn?:               string;
  sinopsis?:           string;
  paginas?:            string;
  encuadernacion?:     string;
  anio_publicacion?:   string;
  // Libros (campos adicionales)
  precio?:             string;
  // Autores
  nombre?:             string;
  descripcion?:        string;
  avatar_url?:         string;
}

interface MasterJson {
  _meta:        { fuente: string; extraido_en: string; stats: Record<string, number> };
  noticias:     ArchivoItem[];
  entrevistas:  ArchivoItem[];
  autores:      ArchivoItem[];
  libros:       ArchivoItem[];
}

// ── Caché de master.json en memoria ──────────────────────────────────────────

let _masterCache: MasterJson | null = null;
let _masterTs    = 0;

async function getMaster(): Promise<MasterJson> {
  if (_masterCache && Date.now() - _masterTs < CACHE_TTL_MS) return _masterCache;

  const [buffer] = await admin.storage().bucket(BUCKET).file(MASTER_PATH).download();
  _masterCache   = JSON.parse(buffer.toString("utf8")) as MasterJson;
  _masterTs      = Date.now();
  return _masterCache;
}

function coleccionDeTipo(master: MasterJson, tipo: string): ArchivoItem[] {
  return (master as unknown as Record<string, ArchivoItem[]>)[tipo] ?? [];
}

// ── Migración de imagen individual (para importación on-demand) ───────────────

const MIME_MAP: Record<string, string> = {
  jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png",
  gif: "image/gif",  webp: "image/webp", svg: "image/svg+xml", avif: "image/avif",
};

async function migrarImagenInline(img: ImagenEntry, tipo: string, slug: string): Promise<string | null> {
  if (img.descargada && img.fluix_url) return img.fluix_url;

  const basename  = path.basename(img.wp_url.split("?")[0]);
  const hash      = crypto.createHash("md5").update(img.wp_url).digest("hex").slice(0, 8);
  const safSlug   = (slug ?? "sin-slug").slice(0, 60).replace(/[^a-z0-9_-]/gi, "-");
  const filePath  = `${STORAGE_PREFIX}/${tipo}/${safSlug}/${hash}_${basename}`;
  const ext       = path.extname(basename).slice(1).toLowerCase();
  const mime      = MIME_MAP[ext] ?? "image/jpeg";

  try {
    const res = await fetch(img.wp_url, { headers: { "User-Agent": "Fluix-WP-Migrator/1.0" } });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const buf  = Buffer.from(await res.arrayBuffer());
    const file = admin.storage().bucket(BUCKET).file(filePath);
    await file.save(buf, { metadata: { contentType: mime, cacheControl: "public, max-age=31536000" } });
    await file.makePublic();
    return file.publicUrl();
  } catch (err) {
    console.warn(`[nazariMigracion] imagen fallida: ${(err as Error).message} — ${img.wp_url}`);
    return null;
  }
}

/** Asegura que todas las imágenes del item tienen fluix_url y devuelve el mapa wp→fluix */
async function resolverImagenes(item: ArchivoItem): Promise<Map<string, string>> {
  const sustituciones = new Map<string, string>();

  if (item.imagen_principal && !item.imagen_principal.descargada) {
    const url = await migrarImagenInline(item.imagen_principal, item.tipo, item.slug);
    if (url) sustituciones.set(item.imagen_principal.wp_url, url);
  } else if (item.imagen_principal?.fluix_url) {
    sustituciones.set(item.imagen_principal.wp_url, item.imagen_principal.fluix_url);
  }

  for (const imgEntry of item.imagenes_contenido ?? []) {
    if (!imgEntry.descargada) {
      const url = await migrarImagenInline(imgEntry, item.tipo, item.slug);
      if (url) sustituciones.set(imgEntry.wp_url, url);
    } else if (imgEntry.fluix_url) {
      sustituciones.set(imgEntry.wp_url, imgEntry.fluix_url);
    }
  }

  return sustituciones;
}

// Extrae la primera URL de YouTube/Vimeo del HTML de WordPress
function extraerVideoUrl(html: string): string | null {
  const ytMatch = html.match(/(?:youtube\.com\/(?:watch\?v=|embed\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})/);
  if (ytMatch) return `https://www.youtube.com/watch?v=${ytMatch[1]}`;
  const vimeoMatch = html.match(/vimeo\.com\/(\d+)/);
  if (vimeoMatch) return `https://vimeo.com/${vimeoMatch[1]}`;
  return null;
}

// Convierte thumbnail de YouTube a URL de imagen de portada
function ytThumb(videoUrl: string): string | null {
  const m = videoUrl.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})/);
  return m ? `https://img.youtube.com/vi/${m[1]}/hqdefault.jpg` : null;
}

// Auto-enlaza frases de "podéis ver el vídeo aquí" al videoUrl
const _PATRONES_VIDEO = [
  "podéis ver el vídeo aquí",
  "podeis ver el video aqui",
  "podéis ver el video aquí",
  "ver el vídeo aquí",
  "ver el video aquí",
  "ver el video aqui",
  "(ver vídeo)",
  "(ver video)",
  "ver el vídeo",
  "ver el video",
];
function autoLinkVideo(html: string, videoUrl: string): string {
  let result = html;
  for (const patron of _PATRONES_VIDEO) {
    const re = new RegExp(patron.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "gi");
    result = result.replace(re, (matched) =>
      `<a href="${videoUrl}" target="_blank" rel="noopener">${matched}</a>`
    );
  }
  return result;
}

function sustituirUrls(html: string, mapa: Map<string, string>): string {
  let result = html;
  for (const [wpUrl, fluixUrl] of mapa) {
    const escaped = wpUrl.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    result = result.replace(new RegExp(escaped, "g"), fluixUrl);
  }
  return result;
}

// ── Construcción de documentos Firestore por tipo ────────────────────────────

function buildDocBlog(item: ArchivoItem, susts: Map<string, string>, ahora: admin.firestore.Timestamp) {
  const imgUrl = item.imagen_principal?.fluix_url
    ?? susts.get(item.imagen_principal?.wp_url ?? "")
    ?? null;

  // Extraer contenido con URLs de imágenes sustituidas
  const contenidoBase = sustituirUrls(item.contenido_html ?? "", susts);

  // Extraer URL de vídeo embebido (YouTube/Vimeo) del contenido WordPress
  const videoUrl = extraerVideoUrl(contenidoBase) ?? null;

  // Auto-enlazar frases de "podéis ver el vídeo aquí"
  const contenidoFinal = videoUrl ? autoLinkVideo(contenidoBase, videoUrl) : contenidoBase;

  // Si no hay imagen principal pero sí hay vídeo de YouTube, usar su thumbnail
  const imagenFinal = imgUrl ?? (videoUrl ? ytThumb(videoUrl) : null);

  return {
    // IDs y control
    wp_id:             item.wp_id,
    slug:              item.slug,
    tipo:              item.tipo,                  // 'noticia' | 'entrevista' | 'blog'
    categoria_id:      item.tipo === "entrevista" ? "Entrevistas" : "Noticias",

    // Contenido
    titulo:            item.titulo            ?? "",
    resumen:           item.extracto          ?? "",
    contenido:         contenidoFinal,
    contenido_html:    contenidoFinal,
    autor:             item.autor             ?? "",
    etiquetas:         item.etiquetas         ?? [],
    categorias:        item.categorias        ?? [],

    // Media
    imagen_url:        imagenFinal,
    ...(videoUrl ? { video_url: videoUrl } : {}),

    // SEO
    seo: {
      meta_title:       item.seo?.meta_title       ?? item.titulo ?? "",
      meta_description: item.seo?.meta_description ?? item.extracto ?? "",
      keywords:         [],
      og_image:         item.seo?.og_image         ?? imgUrl ?? "",
    },

    // Fechas
    fecha_publicacion: item.fecha ? admin.firestore.Timestamp.fromDate(new Date(item.fecha)) : ahora,

    // Estado
    estado:            "publicado",
    publicada:         true,
    destacado:         false,
    visitas:           0,
    eliminado:         false,

    // Procedencia
    _importado:        true,
    _fuente:           "wp_migracion",
    _importado_en:     ahora,
    url_original:      item.url_original ?? "",
  };
}

function buildDocAutor(item: ArchivoItem, susts: Map<string, string>, ahora: admin.firestore.Timestamp) {
  const fotoUrl = item.imagen_principal?.fluix_url
    ?? susts.get(item.imagen_principal?.wp_url ?? "")
    ?? item.avatar_url
    ?? null;

  return {
    wp_id:         item.wp_id,
    nombre:        item.nombre        ?? item.titulo ?? "",
    slug:          item.slug          ?? "",
    descripcion:   item.descripcion   ?? "",
    bio:           sustituirUrls(item.contenido_html ?? "", susts),
    foto_url:      fotoUrl,
    genero:        "",
    lugar:         "",
    activo:        true,
    eliminado:     false,
    _importado:    true,
    _fuente:       "wp_migracion",
    _importado_en: ahora,
  };
}

function buildDocLibro(item: ArchivoItem, susts: Map<string, string>, ahora: admin.firestore.Timestamp) {
  const imgUrl = item.imagen_principal?.fluix_url
    ?? susts.get(item.imagen_principal?.wp_url ?? "")
    ?? null;

  return {
    wp_id:         item.wp_id,
    slug:          item.slug           ?? "",
    titulo:        item.titulo         ?? "",
    sinopsis:      item.sinopsis        ?? item.extracto ?? "",
    contenido:     sustituirUrls(item.contenido_html ?? "", susts),
    isbn:          item.isbn            ?? "",
    precio:        item.precio ?? "",
    paginas:       item.paginas         ?? 0,
    encuadernacion: item.encuadernacion ?? "",
    anio:          item.anio_publicacion ?? "",
    categorias:    item.categorias      ?? [],
    imagen_url:    imgUrl,
    activo:        true,
    eliminado:     false,
    _importado:    true,
    _fuente:       "wp_migracion",
    _importado_en: ahora,
  };
}

function buildDoc(item: ArchivoItem, susts: Map<string, string>): Record<string, unknown> {
  const ahora = admin.firestore.Timestamp.now();
  switch (item.tipo) {
    case "autor":       return buildDocAutor(item, susts, ahora);
    case "libro":       return buildDocLibro(item, susts, ahora);
    default:            return buildDocBlog(item, susts, ahora);  // noticia | entrevista | blog
  }
}

function coleccionFirestore(tipo: string): string {
  if (tipo === "autor")  return "autores";
  if (tipo === "libro")  return "catalogo_web";
  return "blog";
}

/** ID del documento en Firestore — idempotente: mismo wp_id siempre produce el mismo docId */
function docId(tipo: string, wp_id: number): string {
  return `nazari_wp_${tipo}_${wp_id}`;
}

// ═════════════════════════════════════════════════════════════════════════════
// Cloud Function 1: buscarArchivoNazari
// Busca en master.json sin importar. Devuelve metadatos + flag importado.
// ═════════════════════════════════════════════════════════════════════════════

export const buscarArchivoNazari = onCall(
  { region: REGION, timeoutSeconds: 30, memory: "512MiB" },
  async (request) => {
    await verificarAuthYEmpresa(request, EID_NAZARI);

    const { tipo = "noticias", query = "", pagina = 1, por_pagina = 20 } =
      (request.data ?? {}) as { tipo?: string; query?: string; pagina?: number; por_pagina?: number };

    const validTipos = ["noticias", "entrevistas", "autores", "libros"];
    if (!validTipos.includes(tipo)) {
      throw new HttpsError("invalid-argument", `tipo debe ser uno de: ${validTipos.join(", ")}`);
    }

    let master: MasterJson;
    try {
      master = await getMaster();
    } catch {
      throw new HttpsError("not-found", "El archivo maestro no está disponible. Ejecuta el extractor primero.");
    }

    const coleccion = coleccionDeTipo(master, tipo);

    // Filtro por texto (título o slug)
    const q = query.trim().toLowerCase();
    const filtrados = q
      ? coleccion.filter(item =>
          (item.titulo ?? "").toLowerCase().includes(q) ||
          (item.slug ?? "").toLowerCase().includes(q) ||
          (item.nombre ?? "").toLowerCase().includes(q)
        )
      : coleccion;

    // Paginación
    const total   = filtrados.length;
    const inicio  = (pagina - 1) * por_pagina;
    const pagina_ = filtrados.slice(inicio, inicio + por_pagina);

    // Devolver solo metadatos (sin contenido_html completo)
    const items = pagina_.map(item => ({
      wp_id:              item.wp_id,
      tipo:               item.tipo,
      titulo:             item.titulo   ?? item.nombre ?? "",
      slug:               item.slug     ?? "",
      fecha:              item.fecha    ?? "",
      autor:              item.autor    ?? "",
      imagen_url:         item.imagen_principal?.fluix_url ?? item.imagen_principal?.wp_url ?? null,
      importado_en_fluix: item.importado_en_fluix,
      fluix_id:           item.fluix_id,
    }));

    return { ok: true, tipo, total, pagina, hay_mas: inicio + por_pagina < total, items };
  }
);

// ═════════════════════════════════════════════════════════════════════════════
// Cloud Function 2: importarContenidoNazari
// Importa un item concreto del archivo histórico a Firestore.
// Idempotente: llamadas repetidas con el mismo wp_id retornan el existente.
// ═════════════════════════════════════════════════════════════════════════════

export const importarContenidoNazari = onCall(
  { region: REGION, timeoutSeconds: 120, memory: "512MiB" },
  async (request) => {
    await verificarAuthYEmpresa(request, EID_NAZARI);

    const { tipo, wp_id } = (request.data ?? {}) as { tipo?: string; wp_id?: number };

    if (!tipo || wp_id == null) {
      throw new HttpsError("invalid-argument", "Se requieren: tipo y wp_id");
    }
    const validTipos = ["noticias", "entrevistas", "autores", "libros"];
    if (!validTipos.includes(tipo)) {
      throw new HttpsError("invalid-argument", `tipo inválido: ${tipo}`);
    }

    const db = admin.firestore();
    const tipoSingular = tipo.endsWith("s") ? tipo.slice(0, -1) : tipo;  // noticias→noticia, autores→autor
    const colFS        = coleccionFirestore(tipoSingular);
    const fDocId       = docId(tipoSingular, wp_id);
    const docRef       = db.collection(`empresas/${EID_NAZARI}/${colFS}`).doc(fDocId);

    // ── Idempotencia: si ya existe, devolver el documento existente ────────────
    const existing = await docRef.get();
    if (existing.exists) {
      return { ok: true, ya_existia: true, fluix_id: fDocId, data: existing.data() };
    }

    // ── Leer el item del archivo maestro ──────────────────────────────────────
    let master: MasterJson;
    try {
      master = await getMaster();
    } catch {
      throw new HttpsError("not-found", "El archivo maestro no está disponible.");
    }

    const item = coleccionDeTipo(master, tipo).find(i => i.wp_id === wp_id);
    if (!item) {
      throw new HttpsError("not-found", `No se encontró wp_id=${wp_id} en el archivo de ${tipo}.`);
    }

    // ── Migrar imágenes pendientes ─────────────────────────────────────────────
    const sustituciones = await resolverImagenes(item);

    // ── Construir y guardar el documento ──────────────────────────────────────
    const docData = buildDoc({ ...item, tipo: tipoSingular }, sustituciones);
    await docRef.set({ ...docData, fluix_id: fDocId });

    return { ok: true, ya_existia: false, fluix_id: fDocId, data: docData };
  }
);

// ═════════════════════════════════════════════════════════════════════════════
// Cloud Function 3: migrarDatosNazariDesdeWeb
// Migra datos estáticos de la web de Nazarí a Firestore en un solo paso:
//   - libros → catalogo_web  (lee colección `libros` existente)
//   - entrevistas de prensa  (llama WordPress REST API, categoría 77)
//
// data: { tipo: 'libros' | 'entrevistas' | 'todo' }
// ═════════════════════════════════════════════════════════════════════════════

export const migrarDatosNazariDesdeWeb = onCall(
  { region: REGION, timeoutSeconds: 300, memory: "512MiB" },
  async (request) => {
    await verificarAuthYEmpresa(request, EID_NAZARI);

    const tipo = ((request.data ?? {}) as { tipo?: string }).tipo ?? "todo";
    if (!["libros", "entrevistas", "todo"].includes(tipo)) {
      throw new HttpsError("invalid-argument", `tipo inválido: ${tipo}`);
    }

    const db   = admin.firestore();
    const base = `empresas/${EID_NAZARI}`;
    let libros = 0, entrevistas = 0, errores = 0;

    // ── 1. Libros: colección `libros` → `catalogo_web` ────────────────────────
    if (tipo === "libros" || tipo === "todo") {
      try {
        const snap = await db.collection(`${base}/libros`).get();
        let orden  = 0;
        const batch = db.batch();
        for (const d of snap.docs) {
          const l = d.data();
          const ref = db.collection(`${base}/catalogo_web`).doc(d.id);
          batch.set(ref, {
            nombre:            l.titulo ?? l.nombre ?? "",
            descripcion:       l.sinopsis ?? l.descripcion ?? "",
            precio:            l.precio ?? "",
            precio_digital:    l.precioEbook ?? "",
            imagen_url:        l.imagen_url ?? "",
            activo:            l.activo ?? true,
            orden:             orden++,
            slug:              l.slug ?? d.id,
            tag:               l.tag ?? "",
            categoria:         l.genero ?? "",
            campo_autor:       l.autor ?? "",
            campo_isbn:        l.isbn ?? "",
            campo_paginas:     String(l.paginas ?? ""),
            campo_formato:     l.formato ?? "",
            campo_dimensiones: l.dimensiones ?? "",
            campo_anio:        String(l.anio ?? ""),
            campo_mes:         l.mes ?? "",
            origen:            "libros",
            guardado_en:       admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
          libros++;
          // commit en lotes de 400
          if (libros % 400 === 0) { await batch.commit(); }
        }
        await batch.commit();
      } catch (e: any) {
        console.error("Error migrando libros:", e.message);
        errores++;
      }
    }

    // ── 2. Entrevistas de prensa: WordPress API cat=77 → `blog` ──────────────
    if (tipo === "entrevistas" || tipo === "todo") {
      try {
        const WP_BASE = "https://www.editorialnazari.com/wp-json/wp/v2/posts"
          + "?categories=77&per_page=100&_fields=id,slug,title,excerpt,date,yoast_head_json&orderby=date&order=desc";

        let pagina = 1;
        let hayMas = true;

        while (hayMas) {
          let posts: any[] = [];
          try {
            const resp = await fetch(`${WP_BASE}&page=${pagina}`, {
              headers: { "User-Agent": "FluixCRM/1.0" },
            });
            if (!resp.ok) { hayMas = false; break; }
            posts = await resp.json() as any[];
            if (!Array.isArray(posts) || posts.length === 0) { hayMas = false; break; }
          } catch { hayMas = false; break; }

          const blogsCol = db.collection(`${base}/blog`);
          for (const p of posts) {
            const slug   = p.slug as string;
            const titulo = (p.title?.rendered as string ?? "").replace(/&#[0-9]+;/g, c => String.fromCharCode(parseInt(c.slice(2, -1))));
            const resumen = (p.excerpt?.rendered as string ?? "")
              .replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim().slice(0, 400);
            const imagenUrl: string = p.yoast_head_json?.og_image?.[0]?.url ?? "";
            const fecha  = new Date(p.date as string);

            try {
              const ref  = blogsCol.doc(slug);
              const snap = await ref.get();
              if (!snap.exists) {
                await ref.set({
                  titulo,
                  slug,
                  tipo:              "entrevista",
                  publicada:         true,
                  url_externa:       `https://www.editorialnazari.com/${slug}/`,
                  fecha_publicacion: admin.firestore.Timestamp.fromDate(fecha),
                  resumen,
                  imagen_url:        imagenUrl,
                  autor:             "",
                  wp_id:             p.id ?? null,
                  guardado_en:       admin.firestore.FieldValue.serverTimestamp(),
                });
                entrevistas++;
              }
            } catch { errores++; }
          }

          hayMas = posts.length === 100;
          pagina++;
          if (pagina > 10) break; // seguridad: máx 1000 entrevistas
        }
      } catch (e: any) {
        console.error("Error importando entrevistas:", e.message);
        errores++;
      }
    }

    return { ok: true, tipo, libros, entrevistas, errores };
  }
);

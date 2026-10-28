/**
 * nazariCache.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Regenera automáticamente los archivos JS de caché en Firebase Storage
 * cuando cambia cualquier colección pública de Editorial Nazarí en Firestore.
 *
 * Flujo:
 *   Fluix edita algo → Firestore trigger → CF lee colección completa
 *   → genera JS → sube a Storage (cache/*.js) → web lo carga gratis
 *
 * URLs públicas resultantes:
 *   https://storage.googleapis.com/planeaapp-4bea4.firebasestorage.app/cache/catalogo-data.js
 *   https://storage.googleapis.com/planeaapp-4bea4.firebasestorage.app/cache/autores-data.js
 *   https://storage.googleapis.com/planeaapp-4bea4.firebasestorage.app/cache/blog-data.js
 *   https://storage.googleapis.com/planeaapp-4bea4.firebasestorage.app/cache/eventos-data.js
 *   https://storage.googleapis.com/planeaapp-4bea4.firebasestorage.app/cache/seleccion-data.js
 * ─────────────────────────────────────────────────────────────────────────────
 */

import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/v2";

const db     = admin.firestore();
const REGION = "europe-west1";
const EID    = "0PoomHYDUJf5w8tDFRLhFi9iURF3";
const BUCKET = "planeaapp-4bea4.firebasestorage.app";

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Sube un string JS a Firebase Storage como archivo público */
async function uploadCache(filename: string, content: string): Promise<void> {
  const bucket = admin.storage().bucket(BUCKET);
  const file   = bucket.file(`cache/${filename}`);
  await file.save(content, {
    contentType: "application/javascript; charset=utf-8",
    metadata: { cacheControl: "public, max-age=86400, s-maxage=86400" }, // 24h browser + CDN cache
  });
  logger.info(`✅ cache/${filename} subido (${Math.round(content.length / 1024)} KB)`);
}

/** Serializa un doc de Firestore a JSON plano (convierte Timestamps a strings) */
function serDoc(data: FirebaseFirestore.DocumentData, id: string): Record<string, unknown> {
  const out: Record<string, unknown> = { id, ...data };
  for (const [k, v] of Object.entries(out)) {
    if (v && typeof v === "object" && "toDate" in (v as object)) {
      out[k] = (v as admin.firestore.Timestamp).toDate().toISOString();
    }
  }
  return out;
}

// ── 1. CATÁLOGO ───────────────────────────────────────────────────────────────
export const onCatalogoWebCambio = onDocumentWritten(
  { document: `empresas/${EID}/catalogo_web/{docId}`, region: REGION },
  async () => {
    const snap = await db.collection("empresas").doc(EID).collection("catalogo_web").get();
    const libros = snap.docs
      .map(d => serDoc(d.data(), d.id))
      .filter(l => l.activo !== false && l.eliminado !== true)
      .sort((a, b) => ((a.orden as number) ?? 9999) - ((b.orden as number) ?? 9999));

    // Variable global LIBROS para compatibilidad con código web existente
    const js = `// Catálogo Nazarí — generado ${new Date().toISOString()}\nvar LIBROS = ${JSON.stringify(libros)};\n`;
    await uploadCache("catalogo-data.js", js);
  }
);

// ── 2. AUTORES ────────────────────────────────────────────────────────────────

async function _regenerarAutores(): Promise<void> {
  const snap = await db.collection("empresas").doc(EID).collection("autores").get();
  const autores = snap.docs
    .map(d => serDoc(d.data(), d.id))
    .filter(a => a.activo !== false && a.eliminado !== true)
    .sort((a, b) => {
      const prio = (x: Record<string, unknown>) => {
        const p = typeof x.prioridad === 'number' ? x.prioridad : 0;
        if (p !== 0) return p;
        return typeof x.orden === 'number' ? x.orden : 9999;
      };
      const pa = prio(a), pb = prio(b);
      if (pa !== pb) return pa - pb;
      return String(a.nombre ?? "").localeCompare(String(b.nombre ?? ""), "es");
    });
  const js = `// Autores Nazarí — generado ${new Date().toISOString()}\nvar AUTORES = ${JSON.stringify(autores)};\n`;
  await uploadCache("autores-data.js", js);
}

// Cambios en datos de autor (nombre, bio, foto, activo…)
// Se salta si solo cambió prioridad — el reorder lo gestiona onOrdenAutoresCambio
export const onAutoresCambio = onDocumentWritten(
  { document: `empresas/${EID}/autores/{docId}`, region: REGION },
  async (event) => {
    if (event.data?.before?.exists && event.data?.after?.exists) {
      const b = event.data.before.data()!;
      const a = event.data.after.data()!;
      const contentFields = ['nombre','bio','descripcion','foto_url','foto','activo','rol','genero','lugar','eliminado','orden'];
      const contentChanged = contentFields.some(k => b[k] !== a[k]);
      if (!contentChanged) return;
    }
    await _regenerarAutores();
  }
);

// Reorder drag & drop — un solo write desde la app, una sola invocación de CF
export const onOrdenAutoresCambio = onDocumentWritten(
  { document: `empresas/${EID}/configuracion/orden_autores`, region: REGION },
  async () => _regenerarAutores()
);

// ── 3. BLOG ───────────────────────────────────────────────────────────────────
// Convierte cualquier valor fecha (Timestamp, string, número) a ms desde epoch
function _tsMs(v: unknown): number {
  if (!v) return 0;
  if (typeof (v as any).toDate === "function") return (v as any).toDate().getTime();
  if (typeof v === "object" && (v as any).seconds) return (v as any).seconds * 1000;
  const t = new Date(String(v)).getTime();
  return isNaN(t) ? 0 : t;
}

export const onBlogCambio = onDocumentWritten(
  { document: `empresas/${EID}/blog/{docId}`, region: REGION },
  async () => {
    const snap = await db.collection("empresas").doc(EID).collection("blog").get();
    const posts = snap.docs
      .map(d => serDoc(d.data(), d.id))
      .filter(p => {
        if (p.eliminado === true || p.estado === "eliminado") return false;
        return p.estado === "publicado" || p.publicada === true;
      })
      .sort((a, b) => _tsMs(b.fecha_publicacion) - _tsMs(a.fecha_publicacion));

    // Variable global BLOG_POSTS para la web
    const js = `// Blog Nazarí — generado ${new Date().toISOString()}\nvar BLOG_POSTS = ${JSON.stringify(posts)};\n`;
    await uploadCache("blog-data.js", js);
  }
);

// ── 4. EVENTOS ────────────────────────────────────────────────────────────────
export const onEventosCambio = onDocumentWritten(
  { document: `empresas/${EID}/eventos/{docId}`, region: REGION },
  async () => {
    const snap = await db.collection("empresas").doc(EID).collection("eventos").get();
    const eventos = snap.docs
      .map(d => serDoc(d.data(), d.id))
      .filter(e => e.activo !== false && e.eliminado !== true)
      .sort((a, b) => {
        const fa = new Date(String(a.fecha ?? "")).getTime() || 0;
        const fb = new Date(String(b.fecha ?? "")).getTime() || 0;
        return fb - fa; // más recientes primero
      });

    // Variable global EVENTOS para compatibilidad
    const js = `// Eventos Nazarí — generado ${new Date().toISOString()}\nvar EVENTOS = ${JSON.stringify(eventos)};\n`;
    await uploadCache("eventos-data.js", js);
  }
);

// ── 5. SELECCIÓN NAZARÍ ───────────────────────────────────────────────────────
export const onSeleccionCambio = onDocumentWritten(
  { document: `empresas/${EID}/seleccion_nazari/{docId}`, region: REGION },
  async () => _regenerarSeleccion()
);

export const onPackSeleccionCambio = onDocumentWritten(
  { document: `empresas/${EID}/configuracion/pack_seleccion`, region: REGION },
  async () => _regenerarSeleccion()
);

async function _regenerarSeleccion(): Promise<void> {
  const [selSnap, packDoc] = await Promise.all([
    db.collection("empresas").doc(EID).collection("seleccion_nazari").get(),
    db.collection("empresas").doc(EID).collection("configuracion").doc("pack_seleccion").get(),
  ]);

  const docs = selSnap.docs
    .map(d => serDoc(d.data(), d.id))
    .filter(d => d.activo !== false && d.eliminado !== true)
    .sort((a, b) => ((a.orden as number) ?? 9999) - ((b.orden as number) ?? 9999));

  const pack = packDoc.exists ? serDoc(packDoc.data()!, packDoc.id) : {};

  const js = `// Selección Nazarí — generado ${new Date().toISOString()}\nwindow._NAZ_SEL_CACHE = ${JSON.stringify({ t: Date.now(), docs, pack })};\n`;
  await uploadCache("seleccion-data.js", js);
}

// ── 6. CONFIGURACIÓN DE PAGOS ─────────────────────────────────────────────────
export const onPagosConfigCambio = onDocumentWritten(
  { document: `empresas/${EID}/configuracion/pagos`, region: REGION },
  async (event) => {
    const data = (event.data?.after?.data() ?? {}) as Record<string, unknown>;
    const cfg = {
      acepta_tarjeta:       data.acepta_tarjeta       ?? true,
      acepta_bizum:         data.acepta_bizum          ?? false,
      bizum_numero:         data.bizum_numero          ?? "",
      acepta_transferencia: data.acepta_transferencia  ?? false,
      transferencia_iban:   data.transferencia_iban    ?? "",
      transferencia_titular: data.transferencia_titular ?? "",
      acepta_paypal:        data.acepta_paypal         ?? false,
    };
    const js = `// Pagos Nazarí — generado ${new Date().toISOString()}\nvar PAGO_CONFIG = ${JSON.stringify(cfg)};\n`;
    await uploadCache("pago-config.js", js);
    logger.info("✅ pago-config.js regenerado");
  }
);

// ── HTTP: fuerza regeneración de todos los cachés (llamar tras deploy) ─────────
export const regenerarCacheNazari = onRequest(
  { region: REGION, cors: false },
  async (req, res) => {
    const apiKey = req.query.key as string | undefined;
    if (!apiKey || apiKey !== process.env.CACHE_REGEN_KEY) {
      res.status(401).json({ error: "No autorizado" });
      return;
    }
    const [catSnap, autSnap, blogSnap, evSnap, pagosDoc] = await Promise.all([
      db.collection("empresas").doc(EID).collection("catalogo_web").get(),
      db.collection("empresas").doc(EID).collection("autores").get(),
      db.collection("empresas").doc(EID).collection("blog").get(),
      db.collection("empresas").doc(EID).collection("eventos").get(),
      db.collection("empresas").doc(EID).collection("configuracion").doc("pagos").get(),
    ]);

    // Catálogo
    const libros = catSnap.docs
      .map(d => serDoc(d.data(), d.id))
      .filter(l => l.activo !== false && l.eliminado !== true)
      .sort((a, b) => ((a.orden as number) ?? 9999) - ((b.orden as number) ?? 9999));

    // Autores
    const prio = (x: Record<string, unknown>) => {
      const p = typeof x.prioridad === 'number' ? x.prioridad : 0;
      if (p !== 0) return p;
      return typeof x.orden === 'number' ? x.orden : 9999;
    };
    const autores = autSnap.docs
      .map(d => serDoc(d.data(), d.id))
      .filter(a => a.activo !== false && a.eliminado !== true)
      .sort((a, b) => {
        const pa = prio(a), pb = prio(b);
        if (pa !== pb) return pa - pb;
        return String(a.nombre ?? "").localeCompare(String(b.nombre ?? ""), "es");
      });

    // Blog — fecha DESC
    const posts = blogSnap.docs
      .map(d => serDoc(d.data(), d.id))
      .filter(p => {
        if (p.eliminado === true || p.estado === "eliminado") return false;
        return p.estado === "publicado" || p.publicada === true;
      })
      .sort((a, b) => {
        const fa = a.fecha_publicacion ? new Date(String(a.fecha_publicacion)).getTime() : 0;
        const fb = b.fecha_publicacion ? new Date(String(b.fecha_publicacion)).getTime() : 0;
        return fb - fa;
      });

    // Eventos — fecha DESC
    const eventos = evSnap.docs
      .map(d => serDoc(d.data(), d.id))
      .filter(e => e.activo !== false && e.eliminado !== true)
      .sort((a, b) => {
        const fa = new Date(String(a.fecha ?? "")).getTime() || 0;
        const fb = new Date(String(b.fecha ?? "")).getTime() || 0;
        return fb - fa;
      });

    // Pago config
    const pd = (pagosDoc.exists ? pagosDoc.data()! : {}) as Record<string, unknown>;
    const pagosCfg = {
      acepta_tarjeta:        pd.acepta_tarjeta        ?? true,
      acepta_bizum:          pd.acepta_bizum           ?? false,
      bizum_numero:          pd.bizum_numero           ?? "",
      acepta_transferencia:  pd.acepta_transferencia   ?? false,
      transferencia_iban:    pd.transferencia_iban     ?? "",
      transferencia_titular: pd.transferencia_titular  ?? "",
      acepta_paypal:         pd.acepta_paypal          ?? false,
    };

    await Promise.all([
      uploadCache("catalogo-data.js", `// Catálogo Nazarí — generado ${new Date().toISOString()}\nvar LIBROS = ${JSON.stringify(libros)};\n`),
      uploadCache("autores-data.js",  `// Autores Nazarí — generado ${new Date().toISOString()}\nvar AUTORES = ${JSON.stringify(autores)};\n`),
      uploadCache("blog-data.js",     `// Blog Nazarí — generado ${new Date().toISOString()}\nvar BLOG_POSTS = ${JSON.stringify(posts)};\n`),
      uploadCache("eventos-data.js",  `// Eventos Nazarí — generado ${new Date().toISOString()}\nvar EVENTOS = ${JSON.stringify(eventos)};\n`),
      uploadCache("pago-config.js",   `// Pagos Nazarí — generado ${new Date().toISOString()}\nvar PAGO_CONFIG = ${JSON.stringify(pagosCfg)};\n`),
      _regenerarSeleccion(),
    ]);

    logger.info("✅ regenerarCacheNazari — todos los cachés regenerados");
    res.json({
      ok: true,
      counts: { libros: libros.length, autores: autores.length, posts: posts.length, eventos: eventos.length },
    });
  }
);

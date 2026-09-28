import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";

const REGION = "europe-west1";
const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════════════════════
// Markdown → HTML (sin dependencias externas)
// Convierte los elementos más comunes de Markdown para renderizado server-side.
// ═══════════════════════════════════════════════════════════════════════════════

function markdownToHtml(md: string): string {
  if (!md) return "";

  // Separar bloques de código antes de procesar para no tocar su contenido
  const codeBlocks: string[] = [];
  let html = md.replace(/```([\s\S]*?)```/g, (_, code) => {
    codeBlocks.push(`<pre><code>${escHtml(code.trim())}</code></pre>`);
    return `%%CODEBLOCK_${codeBlocks.length - 1}%%`;
  });

  // Inline code
  html = html.replace(/`([^`\n]+)`/g, (_, c) => `<code>${escHtml(c)}</code>`);

  // Headings
  html = html.replace(/^###### (.+)$/gm, "<h6>$1</h6>");
  html = html.replace(/^##### (.+)$/gm, "<h5>$1</h5>");
  html = html.replace(/^#### (.+)$/gm, "<h4>$1</h4>");
  html = html.replace(/^### (.+)$/gm, "<h3>$1</h3>");
  html = html.replace(/^## (.+)$/gm, "<h2>$1</h2>");
  html = html.replace(/^# (.+)$/gm, "<h1>$1</h1>");

  // Blockquotes
  html = html.replace(/^> (.+)$/gm, "<blockquote>$1</blockquote>");
  // Colapsar blockquotes consecutivos
  html = html.replace(/<\/blockquote>\n<blockquote>/g, "\n");

  // Listas desordenadas
  html = html.replace(/^[-*] (.+)$/gm, "<li>$1</li>");
  html = html.replace(/(<li>[\s\S]+?<\/li>\n?)(?!<li>)/g, "<ul>$&</ul>");

  // Listas ordenadas
  html = html.replace(/^\d+\. (.+)$/gm, "<li>$1</li>");

  // Bold e italic (orden importa)
  html = html.replace(/\*\*\*(.+?)\*\*\*/g, "<strong><em>$1</em></strong>");
  html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
  html = html.replace(/\*(.+?)\*/g, "<em>$1</em>");
  html = html.replace(/__(.+?)__/g, "<strong>$1</strong>");
  html = html.replace(/_(.+?)_/g, "<em>$1</em>");

  // Imágenes (antes que links)
  html = html.replace(
    /!\[([^\]]*)\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g,
    '<img src="$2" alt="$1" style="max-width:100%;height:auto;border-radius:8px;margin:12px 0">'
  );

  // Links
  html = html.replace(
    /\[([^\]]+)\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g,
    '<a href="$2" rel="noopener">$1</a>'
  );

  // Líneas horizontales
  html = html.replace(/^(-{3,}|\*{3,})$/gm, "<hr>");

  // Párrafos (bloques separados por línea en blanco)
  const bloques = html.split(/\n{2,}/);
  html = bloques.map((b) => {
    b = b.trim();
    if (!b) return "";
    if (/^<(h[1-6]|ul|ol|li|blockquote|pre|hr)/.test(b)) return b;
    if (/%%CODEBLOCK_\d+%%/.test(b)) return b;
    return `<p>${b.replace(/\n/g, "<br>")}</p>`;
  }).join("\n");

  // Restaurar bloques de código
  codeBlocks.forEach((block, i) => {
    html = html.replace(`%%CODEBLOCK_${i}%%`, block);
  });

  return html;
}

function escHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// ─── Helper: construir JSON-LD Article para schema.org ───────────────────────

function buildJsonLd(entry: FirebaseFirestore.DocumentData, empresaData: FirebaseFirestore.DocumentData, baseUrl: string) {
  return {
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    "headline": entry.titulo ?? "",
    "description": entry.resumen ?? "",
    "image": entry.imagen_url ?? "",
    "datePublished": entry.fecha_publicacion ?? "",
    "dateModified": entry.fecha_actualizacion ?? entry.fecha_publicacion ?? "",
    "author": {
      "@type": "Person",
      "name": entry.autor || empresaData.nombre || "",
    },
    "publisher": {
      "@type": "Organization",
      "name": empresaData.nombre ?? "",
      "logo": { "@type": "ImageObject", "url": empresaData.logo_url ?? "" },
    },
    "mainEntityOfPage": {
      "@type": "WebPage",
      "@id": `${baseUrl}/blog/${entry.slug}`,
    },
  };
}

// ═══════════════════════════════════════════════════════════════════════════════
// GET /getBlogEntry?empresaId=xxx&slug=yyy
//
// Devuelve una entrada de blog publicada en JSON listo para consumir
// desde PHP/WordPress server-side:
//   - titulo, slug, resumen, contenido_html, imagen_url, autor
//   - fecha_publicacion (ISO string)
//   - seo_title, seo_description, seo_keywords (array)
//   - json_ld (schema.org Article object)
//   - etiquetas (array), categoria (nombre legible)
// ═══════════════════════════════════════════════════════════════════════════════

export const getBlogEntry = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    // Solo GET
    if (req.method !== "GET") {
      res.status(405).json({ error: "Método no permitido" });
      return;
    }

    const empresaId = (req.query.empresaId as string | undefined)?.trim();
    const slug      = (req.query.slug      as string | undefined)?.trim();
    const baseUrl   = ((req.query.base     as string | undefined) ?? "").replace(/\/$/, "");

    if (!empresaId || !slug) {
      res.status(400).json({ error: "Parámetros requeridos: empresaId, slug" });
      return;
    }

    try {
      // 1. Buscar la entrada por slug
      const snap = await db
        .collection("empresas").doc(empresaId)
        .collection("blog")
        .where("slug", "==", slug)
        .where("estado", "==", "publicado")
        .where("eliminado", "==", false)
        .limit(1)
        .get();

      if (snap.empty) {
        res.status(404).json({ error: "Entrada no encontrada o no publicada" });
        return;
      }

      const doc    = snap.docs[0];
      const entry  = doc.data();
      const seo    = (entry.seo as Record<string, unknown>) ?? {};

      // 2. Datos de la empresa (para schema.org y SEO fallback)
      const empresaDoc = await db.collection("empresas").doc(empresaId).get();
      const empresa    = empresaDoc.data() ?? {};

      // 3. Nombre de la categoría
      let categoriaNombre = "";
      if (entry.categoria_id) {
        try {
          const catDoc = await db
            .collection("empresas").doc(empresaId)
            .collection("blog_categorias")
            .doc(entry.categoria_id as string)
            .get();
          categoriaNombre = (catDoc.data()?.nombre as string) ?? "";
        } catch (_) { /* opcional */ }
      }

      // 4. Incrementar contador de visitas (fire-and-forget)
      doc.ref.update({
        visitas: admin.firestore.FieldValue.increment(1),
      }).catch(() => {});

      // 5. Construir respuesta
      const seoTitle = (seo.meta_title as string) || (entry.titulo as string) || "";
      const seoDesc  = (seo.meta_description as string) || (entry.resumen as string) || "";
      const seoKw    = (seo.keywords as string[]) ?? [];

      const contenidoHtml = markdownToHtml(entry.contenido as string ?? "");
      const jsonLd        = buildJsonLd(entry, empresa, baseUrl);

      // Headers de caché: 15 min en CDN, revalidar en background
      res.set("Cache-Control", "public, max-age=900, stale-while-revalidate=3600");
      res.set("Content-Type", "application/json; charset=utf-8");

      res.status(200).json({
        ok: true,
        entrada: {
          id:                doc.id,
          titulo:            entry.titulo     ?? "",
          slug:              entry.slug       ?? "",
          resumen:           entry.resumen    ?? "",
          contenido_md:      entry.contenido  ?? "",
          contenido_html:    contenidoHtml,
          imagen_url:        entry.imagen_url ?? null,
          autor:             entry.autor      ?? "",
          fecha_publicacion: entry.fecha_publicacion ?? null,
          etiquetas:         (entry.etiquetas as string[]) ?? [],
          categoria:         categoriaNombre,
          destacado:         entry.destacado  ?? false,
          visitas:           (entry.visitas as number ?? 0) + 1,
          seo: {
            title:       seoTitle,
            description: seoDesc,
            keywords:    seoKw,
            og_image:    entry.imagen_url ?? null,
            canonical:   baseUrl ? `${baseUrl}/blog/${entry.slug}` : null,
          },
          json_ld: jsonLd,
        },
      });
    } catch (err) {
      console.error("getBlogEntry error:", err);
      res.status(500).json({ error: "Error interno del servidor" });
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// GET /getBlogLista?empresaId=xxx[&limit=10][&pagina=1][&categoria=slug]
//
// Devuelve la lista de entradas publicadas para la página de índice del blog.
// Soporta paginación por cursor (cursor=docId del último elemento).
// ═══════════════════════════════════════════════════════════════════════════════

export const getBlogLista = onRequest(
  { region: REGION, cors: true },
  async (req, res) => {
    if (req.method !== "GET") {
      res.status(405).json({ error: "Método no permitido" });
      return;
    }

    const empresaId = (req.query.empresaId as string | undefined)?.trim();
    const limit     = Math.min(Number(req.query.limit ?? 10), 50);
    const cursor    = req.query.cursor as string | undefined;
    const categoria = req.query.categoria as string | undefined;
    const baseUrl   = ((req.query.base as string | undefined) ?? "").replace(/\/$/, "");

    if (!empresaId) {
      res.status(400).json({ error: "Parámetro requerido: empresaId" });
      return;
    }

    try {
      let query: FirebaseFirestore.Query = db
        .collection("empresas").doc(empresaId)
        .collection("blog")
        .where("estado", "==", "publicado")
        .where("eliminado", "==", false)
        .orderBy("fecha_publicacion", "desc")
        .limit(limit + 1); // +1 para saber si hay más

      if (categoria) {
        // Filtrar por slug de categoría: primero resolver el ID
        const catSnap = await db
          .collection("empresas").doc(empresaId)
          .collection("blog_categorias")
          .where("slug", "==", categoria)
          .limit(1)
          .get();
        if (!catSnap.empty) {
          query = (query as FirebaseFirestore.Query).where("categoria_id", "==", catSnap.docs[0].id);
        }
      }

      if (cursor) {
        const cursorDoc = await db
          .collection("empresas").doc(empresaId)
          .collection("blog").doc(cursor).get();
        if (cursorDoc.exists) {
          query = query.startAfter(cursorDoc);
        }
      }

      const snap = await query.get();
      const hayMas = snap.docs.length > limit;
      const docs   = hayMas ? snap.docs.slice(0, limit) : snap.docs;

      const entradas = docs.map((doc) => {
        const e = doc.data();
        const seo = (e.seo as Record<string, unknown>) ?? {};
        return {
          id:                doc.id,
          titulo:            e.titulo     ?? "",
          slug:              e.slug       ?? "",
          resumen:           e.resumen    ?? "",
          imagen_url:        e.imagen_url ?? null,
          autor:             e.autor      ?? "",
          fecha_publicacion: e.fecha_publicacion ?? null,
          etiquetas:         (e.etiquetas as string[]) ?? [],
          destacado:         e.destacado  ?? false,
          visitas:           e.visitas    ?? 0,
          tiempo_lectura_min: Math.ceil(((e.contenido as string) ?? "").split(" ").length / 200) || 1,
          url:               baseUrl ? `${baseUrl}/blog/${e.slug}` : null,
          seo: {
            title:       (seo.meta_title as string) || (e.titulo as string) || "",
            description: (seo.meta_description as string) || (e.resumen as string) || "",
            og_image:    e.imagen_url ?? null,
          },
        };
      });

      res.set("Cache-Control", "public, max-age=300, stale-while-revalidate=900");
      res.set("Content-Type", "application/json; charset=utf-8");

      res.status(200).json({
        ok:       true,
        entradas,
        total:    entradas.length,
        hay_mas:  hayMas,
        cursor_siguiente: hayMas ? docs[docs.length - 1].id : null,
      });
    } catch (err) {
      console.error("getBlogLista error:", err);
      res.status(500).json({ error: "Error interno del servidor" });
    }
  }
);

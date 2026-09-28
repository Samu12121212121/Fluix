import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import fetch from "node-fetch";

const REGION = "europe-west1";

interface CdnConfig {
  base_url?: string;
  cloudflare_zone?: string;
  cloudflare_token?: string;
  agenda_path?: string;
  evento_path?: string;
  blog_path?: string;
  catalogo_path?: string;
  libro_path?: string;
}

async function getCdnConfig(empresaId: string): Promise<CdnConfig | null> {
  const doc = await admin.firestore()
    .collection("empresas").doc(empresaId)
    .collection("config_web").doc("cdn_config")
    .get();
  return doc.exists ? (doc.data() as CdnConfig) : null;
}

async function purgeUrls(cfg: CdnConfig, urls: string[]) {
  if (!cfg.cloudflare_token || !cfg.cloudflare_zone || !cfg.base_url) return;
  const paths = urls.map((u) => cfg.base_url + u);
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/zones/${cfg.cloudflare_zone}/purge_cache`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${cfg.cloudflare_token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ files: paths }),
    }
  );
  const data = (await res.json()) as { success: boolean; errors?: unknown[] };
  if (!data.success) console.error("Cloudflare purge error:", data.errors);
  else console.log("CDN purgado:", paths.join(", "));
}

export const purgeEventoCdn = onDocumentWritten(
  { document: "empresas/{empresaId}/eventos/{eventoId}", region: REGION },
  async (event) => {
    const { empresaId, eventoId } = event.params;
    const cfg = await getCdnConfig(empresaId);
    if (!cfg) return;
    const eventoPath = cfg.evento_path ?? "/evento.html";
    await purgeUrls(cfg, [
      cfg.agenda_path ?? "/agenda",
      `${eventoPath}?evento=${eventoId}`,
    ]);
  }
);

export const purgeBlogCdn = onDocumentWritten(
  { document: "empresas/{empresaId}/blog/{postId}", region: REGION },
  async (event) => {
    const { empresaId, postId } = event.params;
    const cfg = await getCdnConfig(empresaId);
    if (!cfg) return;
    const after = event.data?.after.data();
    const slug = after?.slug ?? postId;
    const blogPath = cfg.blog_path ?? "/blog";
    await purgeUrls(cfg, [
      blogPath,
      `${blogPath}?post=${slug}`,
    ]);
  }
);

export const purgeCatalogoCdn = onDocumentWritten(
  { document: "empresas/{empresaId}/catalogo_web/{itemId}", region: REGION },
  async (event) => {
    const { empresaId, itemId } = event.params;
    const cfg = await getCdnConfig(empresaId);
    if (!cfg) return;
    const libroPath = cfg.libro_path ?? "/libro.html";
    await purgeUrls(cfg, [
      cfg.catalogo_path ?? "/libros",
      `${libroPath}?item=${itemId}`,
    ]);
  }
);

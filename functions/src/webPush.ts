import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

const REGION = "europe-west1";

async function getSuscriptores(empresaId: string): Promise<string[]> {
  const snap = await admin.firestore()
    .collection("empresas").doc(empresaId)
    .collection("suscriptores_web")
    .where("activo", "==", true)
    .get();
  return snap.docs
    .map((d) => d.data().token as string)
    .filter(Boolean);
}

async function enviarPush(tokens: string[], titulo: string, body: string, icono?: string) {
  if (!tokens.length) return;
  const chunks: string[][] = [];
  for (let i = 0; i < tokens.length; i += 500) chunks.push(tokens.slice(i, i + 500));
  for (const chunk of chunks) {
    await admin.messaging().sendEachForMulticast({
      tokens: chunk,
      notification: { title: titulo, body, imageUrl: icono },
      webpush: {
        notification: { title: titulo, body, icon: icono ?? "/favicon.ico" },
      },
    });
  }
}

// Nuevo evento publicado → push a suscriptores
export const pushNuevoEvento = onDocumentWritten(
  { document: "empresas/{empresaId}/eventos/{eventoId}", region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
    if (!after) return;
    // Solo si pasa a activo=true por primera vez
    if (!after.activo || (before?.activo === true)) return;
    const tokens = await getSuscriptores(event.params.empresaId);
    await enviarPush(
      tokens,
      after.titulo ?? "Nuevo evento",
      after.subtitulo ?? after.descripcion ?? "Consulta la agenda para más detalles.",
      after.imagen_url
    );
  }
);

// Nueva entrada de blog publicada → push a suscriptores
export const pushNuevoPost = onDocumentWritten(
  { document: "empresas/{empresaId}/blog/{postId}", region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
    if (!after) return;
    if (!after.publicada || (before?.publicada === true)) return;
    const tokens = await getSuscriptores(event.params.empresaId);
    await enviarPush(
      tokens,
      after.titulo ?? "Nueva publicación",
      after.resumen ?? "Hay contenido nuevo en nuestro blog.",
      after.imagen_url
    );
  }
);

// Nuevo libro / item de catálogo activo → push a suscriptores
export const pushNuevoCatalogo = onDocumentWritten(
  { document: "empresas/{empresaId}/catalogo_web/{itemId}", region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
    if (!after) return;
    if (!after.activo || (before?.activo === true)) return;
    const tokens = await getSuscriptores(event.params.empresaId);
    await enviarPush(
      tokens,
      after.nombre ?? "Nueva incorporación",
      after.descripcion ?? "Hay novedades en el catálogo.",
      after.imagen_url
    );
  }
);

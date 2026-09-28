import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

// ═══════════════════════════════════════════════════════════════════════════════
// SCHEDULER: Publicar posts programados
//
// Ejecuta cada 15 minutos. Busca entradas de blog con:
//   - estado == "programado"
//   - fecha_publicacion <= ahora
// Y las cambia a estado "publicado" con publicada: true.
//
// Firestore: empresas/{empresaId}/blog/{entradaId}
// ═══════════════════════════════════════════════════════════════════════════════

const REGION = "europe-west1";

export const publicarPostsProgramados = onSchedule(
  {
    schedule: "every 15 minutes",
    region: REGION,
    timeoutSeconds: 300,
    memory: "256MiB",
  },
  async () => {
    const db = admin.firestore();
    const ahora = admin.firestore.Timestamp.now();

    logger.info("⏰ Scheduler publicarPostsProgramados — ejecutando", {
      ahora: ahora.toDate().toISOString(),
    });

    try {
      // Buscar todas las empresas (solo las que tienen blog activo)
      const empresasSnap = await db.collection("empresas").get();

      let totalPublicados = 0;

      for (const empresaDoc of empresasSnap.docs) {
        const empresaId = empresaDoc.id;

        // Buscar posts programados cuya fecha ya pasó
        const postsSnap = await db
          .collection("empresas")
          .doc(empresaId)
          .collection("blog")
          .where("estado", "==", "programado")
          .where("eliminado", "==", false)
          .where("fecha_publicacion", "<=", ahora)
          .get();

        if (postsSnap.empty) continue;

        logger.info(
          `📋 Empresa ${empresaId}: ${postsSnap.size} post(s) programados para publicar`
        );

        const batch = db.batch();

        for (const postDoc of postsSnap.docs) {
          batch.update(postDoc.ref, {
            estado: "publicado",
            publicada: true,
            fecha_publicado_real: ahora,
          });

          logger.info(`✅ Publicando: ${postDoc.id} — "${postDoc.data().titulo}"`);
          totalPublicados++;
        }

        await batch.commit();
      }

      logger.info(`✅ Scheduler completado — ${totalPublicados} post(s) publicados`);
    } catch (error) {
      logger.error("❌ Error en publicarPostsProgramados:", error);
      throw error;
    }
  }
);

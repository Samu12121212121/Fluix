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

// ── Desactivar preventa cuando la fecha de publicación ha pasado ──────────────
// Se ejecuta diariamente. Busca libros con preventa:true cuyo campo_anio/campo_mes ya pasó
// y les pone preventa:false para que dejen de aparecer como "en preventa" en la web.
export const desactivarPreventaPasada = onSchedule(
  { schedule: "every 24 hours", region: REGION, timeoutSeconds: 120, memory: "256MiB" },
  async () => {
    const db = admin.firestore();
    const hoy = new Date();
    const anioHoy = hoy.getFullYear();
    const mesHoy  = hoy.getMonth() + 1; // 1-12
    const MESES: Record<string, number> = {
      enero:1, ene:1, febrero:2, feb:2, marzo:3, mar:3, abril:4, abr:4,
      mayo:5, may:5, junio:6, jun:6, julio:7, jul:7, agosto:8, ago:8,
      septiembre:9, sep:9, octubre:10, oct:10, noviembre:11, nov:11, diciembre:12, dic:12,
    };
    const parseMes = (m: string) => {
      const n = parseInt(m); if (!isNaN(n) && n >= 1 && n <= 12) return n;
      return MESES[(m || "").toLowerCase().trim()] || 0;
    };

    const empresasSnap = await db.collection("empresas").get();
    let total = 0;

    for (const emp of empresasSnap.docs) {
      const snap = await db.collection("empresas").doc(emp.id)
        .collection("catalogo_web").where("preventa", "==", true).get();
      if (snap.empty) continue;

      const batch = db.batch();
      for (const doc of snap.docs) {
        const d = doc.data();
        const anio = parseInt(d.campo_anio || d.anio || "") || 0;
        if (!anio) continue;
        const mes = parseMes(d.campo_mes || d.mes || "");
        const pasado = mes
          ? (anio < anioHoy || (anio === anioHoy && mes < mesHoy))
          : anio < anioHoy;
        if (pasado) {
          batch.update(doc.ref, { preventa: false });
          total++;
          logger.info(`📦 Preventa desactivada: ${doc.id} (${emp.id})`);
        }
      }
      await batch.commit();
    }
    logger.info(`✅ desactivarPreventaPasada — ${total} libro(s) actualizados`);
  }
);

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

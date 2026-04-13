/**
 * GMB Snapshots — historial de rating mensual y KPIs
 * Cada sync guarda un snapshot del rating calculado sobre las reseñas en Firestore
 */

import * as admin from "firebase-admin";

// Guard: el módulo puede cargarse antes de que index.ts llame initializeApp()
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

/**
 * guardarSnapshotMensual
 * Calcula el rating medio de las reseñas almacenadas en Firestore
 * y guarda/actualiza el snapshot del mes actual.
 * Se llama desde gmbRespuestas.sincronizarResenasEmpresa después de cada sync.
 */
export async function guardarSnapshotMensual(
  empresaId: string
): Promise<void> {
  try {
    const ahora = new Date();
    const mesKey = `${ahora.getFullYear()}-${String(ahora.getMonth() + 1).padStart(2, "0")}`;

    // Calcular rating medio sobre todas las reseñas en Firestore
    const resenasSanp = await db
      .collection("empresas")
      .doc(empresaId)
      .collection("valoraciones")
      .get();

    const totalEnFirestore = resenasSanp.size;
    if (totalEnFirestore === 0) return;

    const sumaRatings = resenasSanp.docs.reduce(
      (s, d) => s + ((d.data().calificacion as number) ?? 5),
      0
    );
    const ratingMedio = totalEnFirestore > 0 ? sumaRatings / totalEnFirestore : 0;

    // Contar reseñas nuevas este mes
    const inicioMes = new Date(ahora.getFullYear(), ahora.getMonth(), 1);
    const nuevasMes = resenasSanp.docs.filter((d) => {
      const fecha = d.data().fecha;
      if (!fecha) return false;
      const fechaDate =
        fecha instanceof admin.firestore.Timestamp
          ? fecha.toDate()
          : new Date(fecha);
      return fechaDate >= inicioMes;
    }).length;

    // Solo un snapshot por mes (sobrescribe el anterior del mismo mes)
    await db
      .collection("empresas")
      .doc(empresaId)
      .collection("rating_historial")
      .doc(mesKey)
      .set({
        mes: mesKey,
        ratingMedio: Math.round(ratingMedio * 100) / 100,
        totalResenasEnFirestore: totalEnFirestore,
        resenasNuevasMes: nuevasMes,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log(
      `📸 Snapshot mensual guardado: ${empresaId} — ${mesKey} — rating ${ratingMedio.toFixed(2)}`
    );
  } catch (err) {
    console.error(`❌ Error guardando snapshot mensual para ${empresaId}:`, err);
  }
}


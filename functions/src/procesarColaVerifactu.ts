import * as admin from "firebase-admin";
import { onSchedule } from "firebase-functions/v2/scheduler";

// ═══════════════════════════════════════════════════════════════════════════════
// PROCESADOR DE COLA VERIFACTU — Scheduled cada 15 min
// Lee documentos en estado "pendiente" de col. cola_verifactu y los reintenta.
// Máx. 3 intentos por registro. Tras el 3º → estado "error" permanente.
// ═══════════════════════════════════════════════════════════════════════════════

const REGION = "europe-west1";
const MAX_INTENTOS = 3;
const MAX_POR_CICLO = 20; // No sobrecargar AEAT en un solo ciclo

export const procesarColaVerifactu = onSchedule(
  { schedule: "every 15 minutes", region: REGION, timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    const db = admin.firestore();

    // Leer hasta MAX_POR_CICLO registros pendientes
    const snap = await db
      .collectionGroup("cola_verifactu")
      .where("estado", "==", "pendiente")
      .where("intentos", "<", MAX_INTENTOS)
      .orderBy("intentos")
      .orderBy("creado_en")
      .limit(MAX_POR_CICLO)
      .get();

    if (snap.empty) {
      console.log("✅ Cola Verifactu vacía.");
      return;
    }

    console.log(`🔄 Cola Verifactu: ${snap.docs.length} registros pendientes`);

    for (const doc of snap.docs) {
      const data = doc.data();
      const empresaId: string = data.empresa_id;
      const facturaId: string = data.factura_id;
      const xmlFirmado: string | undefined = data.xml_firmado;
      const xmlSinFirmar: string | undefined = data.xml_sin_firmar;

      if (!empresaId || !facturaId) {
        console.warn(`⚠️  Registro ${doc.id} sin empresa_id o factura_id — saltando`);
        await doc.ref.update({ estado: "error", error: "Datos incompletos" });
        continue;
      }

      // Marcar como "procesando" para evitar doble procesamiento
      await doc.ref.update({
        estado: "procesando",
        intentos: admin.firestore.FieldValue.increment(1),
        ultimo_intento: admin.firestore.FieldValue.serverTimestamp(),
      });

      try {
        // Si ya tiene XML firmado, remitir directamente
        // Si no, necesita firmarse primero
        let xmlParaEnviar = xmlFirmado;

        if (!xmlParaEnviar && xmlSinFirmar) {
          // XML sin firmar: la firma XAdES requiere certificado y se hace desde cliente.
          // Marcar error para que el usuario reintente manualmente desde la app.
          throw new Error("XML sin firmar — requiere reintento desde cliente");
        }

        if (!xmlParaEnviar) {
          throw new Error("No hay XML disponible para enviar");
        }

        // Enviar SOAP a AEAT
        const { enviarSOAPInterno } = await import("./remitirVerifactu");
        const respuesta = await enviarSOAPInterno(
          empresaId,
          facturaId,
          xmlParaEnviar
        );

        // Actualizar cola y factura con resultado
        await doc.ref.update({
          estado: respuesta.estado,
          csv: respuesta.csv ?? null,
          error: respuesta.descripcionError ?? null,
          procesado_en: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`✅ ${facturaId}: ${respuesta.estado}${respuesta.csv ? ` (CSV: ${respuesta.csv})` : ""}`);
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        const intentos: number = (data.intentos ?? 0) + 1;
        const agotado = intentos >= MAX_INTENTOS;

        await doc.ref.update({
          estado: agotado ? "error" : "pendiente",
          error: msg,
        });

        if (agotado) {
          // Propagar error a la factura
          await db
            .collection("empresas").doc(empresaId)
            .collection("facturas").doc(facturaId)
            .update({
              "verifactu.estado": "error",
              "verifactu.ultimoError": `Cola agotada tras ${MAX_INTENTOS} intentos: ${msg}`,
              "verifactu.fechaUltimoEnvio": admin.firestore.FieldValue.serverTimestamp(),
            })
            .catch(() => {}); // No bloquear si falla
        }

        console.error(`❌ ${facturaId}: ${msg}${agotado ? " [AGOTADO]" : " [reintentará]"}`);
      }
    }
  }
);

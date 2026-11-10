import * as admin from "firebase-admin";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";

const REGION = "europe-west1";

/**
 * Trigger: cuando un usuario actualiza nivel_jerarquico o departamento_id,
 * actualiza sus Firebase Custom Claims para que las Firestore Rules
 * puedan verificar permisos sin consultas extra.
 *
 * Claims resultantes:
 *   nivel_jerarquico  — número (1=director, mayor=menor autoridad)
 *   departamento_id   — string
 *   empresa_id        — string
 *   rol_empresa_id    — string
 */
export const actualizarClaimsEmpleado = onDocumentUpdated(
  { document: "usuarios/{uid}", region: REGION },
  async (event) => {
    const before = event.data?.before.data();
    const after  = event.data?.after.data();
    if (!before || !after) return;

    const nivelCambio  = before.nivel_jerarquico !== after.nivel_jerarquico;
    const deptCambio   = before.departamento_id  !== after.departamento_id;
    const empresaCambio= before.empresa_id       !== after.empresa_id;
    const rolCambio    = before.rol_empresa_id   !== after.rol_empresa_id;

    if (!nivelCambio && !deptCambio && !empresaCambio && !rolCambio) return;

    const uid = event.params.uid;

    const claims: Record<string, unknown> = {
      empresa_id:        after.empresa_id        ?? null,
      nivel_jerarquico:  after.nivel_jerarquico  ?? null,
      departamento_id:   after.departamento_id   ?? null,
      rol_empresa_id:    after.rol_empresa_id     ?? null,
    };

    try {
      await admin.auth().setCustomUserClaims(uid, claims);
      await admin.firestore()
        .collection("usuarios").doc(uid)
        .update({ claims_actualizados_at: admin.firestore.FieldValue.serverTimestamp() });
    } catch (err) {
      console.error(`[actualizarClaimsEmpleado] uid=${uid}`, err);
    }
  }
);

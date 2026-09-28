/**
 * crearEmpleado.ts
 * Cloud Function que crea un empleado directamente:
 *   1. Crea usuario en Firebase Auth con contraseña temporal
 *   2. Crea documento en /usuarios con empresa, rol y módulos
 *   3. Envía email de bienvenida con las credenciales
 *
 * Llamada desde Flutter:
 *   FirebaseFunctions.instanceFor(region:'europe-west1')
 *     .httpsCallable('crearEmpleadoConCredenciales')
 *     .call({email, nombre, rol, empresaId, empresaNombre})
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { enviarBienvenidaEmpleado } from "./resend_service";

const REGION = "europe-west1";

function generarPasswordTemporal(): string {
  const chars = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
  let pass = "";
  for (let i = 0; i < 10; i++) {
    pass += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return pass;
}

export const crearEmpleadoConCredenciales = onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Debes estar autenticado.");
    }

    const { email, nombre, rol, empresaId, empresaNombre } = request.data as {
      email?: string;
      nombre?: string;
      rol?: string;
      empresaId?: string;
      empresaNombre?: string;
    };

    if (!email || !nombre || !empresaId || !empresaNombre) {
      throw new HttpsError("invalid-argument", "Faltan datos obligatorios (email, nombre, empresaId, empresaNombre).");
    }

    const emailNorm  = email.trim().toLowerCase();
    const rolFinal   = rol === "admin" ? "admin" : "staff";
    const tempPass   = generarPasswordTemporal();

    // 1. Crear usuario en Firebase Auth
    let uid: string;
    try {
      const rec = await admin.auth().createUser({
        email:       emailNorm,
        password:    tempPass,
        displayName: nombre.trim(),
      });
      uid = rec.uid;
    } catch (e: any) {
      if (e.code === "auth/email-already-exists") {
        throw new HttpsError("already-exists", "Ya existe un usuario con ese email.");
      }
      console.error("❌ Error creando Auth user:", e);
      throw new HttpsError("internal", "No se pudo crear el usuario.");
    }

    // 2. Crear documento en Firestore /usuarios
    await admin.firestore().collection("usuarios").doc(uid).set({
      nombre:                   nombre.trim(),
      correo:                   emailNorm,
      empresa_id:               empresaId,
      rol:                      rolFinal,
      activo:                   true,
      fecha_creacion:           admin.firestore.FieldValue.serverTimestamp(),
      invitado_por:             request.auth.uid,
      requiere_cambio_password: true,
    });

    // 3. Enviar email de bienvenida con credenciales
    try {
      await enviarBienvenidaEmpleado({
        to:           emailNorm,
        nombre:       nombre.trim(),
        empresaNombre,
        tempPassword: tempPass,
      });
    } catch (emailErr) {
      console.warn("⚠️ Usuario creado pero fallo al enviar email:", emailErr);
      // No lanzamos error — el usuario ya existe y el admin tiene la contraseña
    }

    console.log(`✅ Empleado creado: ${emailNorm} (uid=${uid}, rol=${rolFinal})`);
    return { exito: true, uid, tempPassword: tempPass };
  }
);

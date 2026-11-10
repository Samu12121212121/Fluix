import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as crypto from "crypto";

// ─────────────────────────────────────────────────────────────────────────────
// SMS OTP via Twilio — firma electrónica avanzada (eIDAS art. 26)
//
// enviarOtpSms(empleadoId, docId) → genera OTP, envía SMS, guarda hash
// verificarOtpSms(empleadoId, docId, codigo) → verifica código
// ─────────────────────────────────────────────────────────────────────────────

const TWILIO_SID    = process.env.TWILIO_ACCOUNT_SID ?? "";
const TWILIO_TOKEN  = process.env.TWILIO_AUTH_TOKEN  ?? "";
const TWILIO_FROM   = process.env.TWILIO_FROM_NUMBER ?? "+14326662498";

const OTP_TTL_MIN   = 10;
const OTP_MAX_INT   = 3;

function generarOtp(): string {
  return (100000 + (crypto.randomInt(0, 900000))).toString();
}

function hashOtp(codigo: string, empleadoId: string, docId: string): string {
  return crypto.createHash("sha256")
    .update(`${codigo}:${empleadoId}:${docId}`)
    .digest("hex");
}

async function enviarSmsTwilio(to: string, body: string): Promise<void> {
  const url = `https://api.twilio.com/2010-04-01/Accounts/${TWILIO_SID}/Messages.json`;
  const params = new URLSearchParams({ From: TWILIO_FROM, To: to, Body: body });
  const res = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: "Basic " + Buffer.from(`${TWILIO_SID}:${TWILIO_TOKEN}`).toString("base64"),
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: params.toString(),
  });
  const data = await res.json() as { status?: string; error_message?: string; sid?: string };
  if (!res.ok || data.error_message) {
    throw new HttpsError("internal", `Twilio error: ${data.error_message ?? res.status}`);
  }
}

function normalizarTelefono(tel: string): string {
  const t = tel.trim().replace(/\s+/g, "");
  if (t.startsWith("+")) return t;
  if (t.startsWith("00")) return "+" + t.slice(2);
  if (t.length === 9) return "+34" + t;   // España sin prefijo
  return t;
}

// ── ENVIAR OTP ────────────────────────────────────────────────────────────────

export const enviarOtpSms = onCall({ region: "europe-west1" }, async (req) => {
  const { empleadoId, docId } = req.data as {
    empleadoId: string;
    docId: string;
  };

  if (!empleadoId || !docId) {
    throw new HttpsError("invalid-argument", "empleadoId y docId son obligatorios");
  }

  // Leer teléfono del empleado
  const userSnap = await admin.firestore().collection("usuarios").doc(empleadoId).get();
  if (!userSnap.exists) throw new HttpsError("not-found", "Empleado no encontrado");
  const telefono = ((userSnap.data()?.telefono as string) ?? "").trim();
  if (!telefono) throw new HttpsError("failed-precondition", "El empleado no tiene teléfono registrado");

  // Verificar que el documento existe y está pendiente de firma
  const docSnap = await admin.firestore()
    .collection("usuarios").doc(empleadoId)
    .collection("documentos").doc(docId).get();
  if (!docSnap.exists) throw new HttpsError("not-found", "Documento no encontrado");

  const codigo = generarOtp();
  const hash   = hashOtp(codigo, empleadoId, docId);
  const expira = new Date(Date.now() + OTP_TTL_MIN * 60 * 1000);
  const telNorm = normalizarTelefono(telefono);
  const docNombre = (docSnap.data()?.nombre as string) ?? "documento";

  // Guardar OTP hasheado en Firestore
  await admin.firestore()
    .collection("usuarios").doc(empleadoId)
    .collection("otps_firma").doc(docId)
    .set({
      hash,
      expira_en: admin.firestore.Timestamp.fromDate(expira),
      intentos: 0,
      metodo: "twilio_sms",
      creado_en: admin.firestore.FieldValue.serverTimestamp(),
    });

  // Enviar SMS via Twilio
  const mensaje = `Fluix: Tu código para firmar "${docNombre}" es ${codigo}. Caduca en ${OTP_TTL_MIN} min. No lo compartas.`;
  await enviarSmsTwilio(telNorm, mensaje);

  return {
    ok: true,
    telefonoParcial: telNorm.slice(0, -4).replace(/\d/g, "*") + telNorm.slice(-4),
  };
});

// ── VERIFICAR OTP ─────────────────────────────────────────────────────────────

export const verificarOtpSms = onCall({ region: "europe-west1" }, async (req) => {
  const { empleadoId, docId, codigo } = req.data as {
    empleadoId: string;
    docId: string;
    codigo: string;
  };

  if (!empleadoId || !docId || !codigo) {
    throw new HttpsError("invalid-argument", "Faltan parámetros");
  }

  const otpRef = admin.firestore()
    .collection("usuarios").doc(empleadoId)
    .collection("otps_firma").doc(docId);

  const snap = await otpRef.get();
  if (!snap.exists) throw new HttpsError("not-found", "No hay OTP activo para este documento");

  const data = snap.data()!;
  const expira = (data.expira_en as admin.firestore.Timestamp).toDate();
  const intentos = (data.intentos as number) ?? 0;

  if (new Date() > expira) {
    await otpRef.delete();
    throw new HttpsError("deadline-exceeded", "El código ha caducado. Solicita uno nuevo.");
  }

  if (intentos >= OTP_MAX_INT) {
    await otpRef.delete();
    throw new HttpsError("resource-exhausted", "Demasiados intentos. Solicita un nuevo código.");
  }

  const hashIngresado = hashOtp(codigo, empleadoId, docId);
  if (hashIngresado !== data.hash) {
    await otpRef.update({ intentos: admin.firestore.FieldValue.increment(1) });
    throw new HttpsError("unauthenticated", `Código incorrecto. Intentos restantes: ${OTP_MAX_INT - intentos - 1}`);
  }

  // Código correcto → eliminar OTP
  await otpRef.delete();
  return { ok: true };
});

/**
 * GMB Tokens — gestión de tokens OAuth2 para Google Business Profile API
 * Los tokens se guardan cifrados en Secret Manager (nunca en Firestore en claro)
 */

import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import fetch from "node-fetch";
import { verificarAuth, verificarAuthYEmpresa } from "./utils/authGuard";

const REGION = "europe-west1";
// Guard: el módulo puede cargarse antes de que index.ts llame initializeApp()
if (!admin.apps.length) admin.initializeApp();
const db = admin.firestore();

// ── Secret Manager helpers ────────────────────────────────────────────────────

async function storeSecret(secretId: string, value: string): Promise<void> {
  const { SecretManagerServiceClient } = await import(
    "@google-cloud/secret-manager"
  );
  const client = new SecretManagerServiceClient();
  const project =
    process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";
  const name = `projects/${project}/secrets/${secretId}`;

  try {
    await client.addSecretVersion({
      parent: name,
      payload: { data: Buffer.from(value, "utf8") },
    });
  } catch {
    // Secret no existe aún → crearlo
    await client.createSecret({
      parent: `projects/${project}`,
      secretId,
      secret: { replication: { automatic: {} } },
    });
    await client.addSecretVersion({
      parent: name,
      payload: { data: Buffer.from(value, "utf8") },
    });
  }
}

async function getSecret(secretId: string): Promise<string> {
  const { SecretManagerServiceClient } = await import(
    "@google-cloud/secret-manager"
  );
  const client = new SecretManagerServiceClient();
  const project =
    process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";
  const [version] = await client.accessSecretVersion({
    name: `projects/${project}/secrets/${secretId}/versions/latest`,
  });
  return version.payload?.data?.toString() ?? "";
}

// ── Token helpers (exportado para uso en otras funciones) ────────────────────

export interface GmbTokens {
  access_token: string;
  refresh_token: string;
  expires_at: number;
}

export async function getGmbTokens(empresaId: string): Promise<GmbTokens> {
  const raw = await getSecret(`gmb_token_${empresaId}`);
  return JSON.parse(raw) as GmbTokens;
}

/**
 * Devuelve un access_token válido, refrescándolo si ha expirado.
 * Exportado para uso en gmbRespuestas y gmbSnapshots.
 */
export async function getValidGmbAccessToken(
  empresaId: string
): Promise<string> {
  const tokens = await getGmbTokens(empresaId);

  // Si caduca en menos de 2 minutos, refrescar
  if (tokens.expires_at > Date.now() + 120_000) {
    return tokens.access_token;
  }

  const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID ?? "";
  const clientSecret = process.env.GOOGLE_OAUTH_CLIENT_SECRET ?? "";

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      refresh_token: tokens.refresh_token,
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: "refresh_token",
    }).toString(),
  });

  const data = (await res.json()) as Record<string, string>;
  if (!data.access_token) {
    throw new Error(`Error refrescando token GMB: ${JSON.stringify(data)}`);
  }

  const newTokens: GmbTokens = {
    ...tokens,
    access_token: data.access_token,
    expires_at: Date.now() + parseInt(data.expires_in ?? "3600") * 1000,
  };

  await storeSecret(`gmb_token_${empresaId}`, JSON.stringify(newTokens));
  console.log(`🔄 Token GMB refrescado para empresa ${empresaId}`);
  return data.access_token;
}

// ── Cloud Functions ───────────────────────────────────────────────────────────

/**
 * storeGmbToken
 * Recibe el serverAuthCode del cliente Flutter, lo intercambia por tokens
 * y los guarda cifrados en Secret Manager.
 */
export const storeGmbToken = onCall(
  { region: REGION },
  async (request) => {
    const { empresaId, serverAuthCode } = request.data as {
      empresaId: string;
      serverAuthCode: string;
    };

    // ── AUTH GUARD ──
    await verificarAuthYEmpresa(request, empresaId);

    if (!empresaId || !serverAuthCode) {
      throw new HttpsError(
        "invalid-argument",
        "empresaId y serverAuthCode son requeridos"
      );
    }

    const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID ?? "";
    const clientSecret = process.env.GOOGLE_OAUTH_CLIENT_SECRET ?? "";

    if (!clientId || !clientSecret) {
      throw new HttpsError(
        "internal",
        "Credenciales OAuth no configuradas en el servidor"
      );
    }

    // Intercambiar código por tokens
    const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        code: serverAuthCode,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: "postmessage",
        grant_type: "authorization_code",
      }).toString(),
    });

    const tokenData = (await tokenRes.json()) as Record<string, string>;
    if (!tokenData.access_token) {
      console.error("Error intercambiando code:", tokenData);
      throw new HttpsError(
        "internal",
        `Error obteniendo tokens de Google: ${tokenData.error_description ?? tokenData.error ?? "unknown"}`
      );
    }

    const tokens: GmbTokens = {
      access_token: tokenData.access_token,
      refresh_token: tokenData.refresh_token ?? "",
      expires_at:
        Date.now() + parseInt(tokenData.expires_in ?? "3600") * 1000,
    };

    // Guardar en Secret Manager
    await storeSecret(`gmb_token_${empresaId}`, JSON.stringify(tokens));
    console.log(`✅ Tokens GMB guardados en Secret Manager para ${empresaId}`);

    // Marcar como conectado en Firestore (sin tokens en claro)
    await db
      .collection("empresas")
      .doc(empresaId)
      .collection("configuracion")
      .doc("gmb_config")
      .set(
        {
          conectado: true,
          conectado_at: admin.firestore.FieldValue.serverTimestamp(),
          token_guardado: true,
        },
        { merge: true }
      );

    return { success: true };
  }
);

/**
 * obtenerFichasNegocio
 * Lista todas las fichas de Google Business Profile del usuario.
 */
export const obtenerFichasNegocio = onCall(
  { region: REGION },
  async (request) => {
    // ── AUTH GUARD ──
    verificarAuth(request);

    const { empresaId } = request.data as { empresaId: string };
    if (!empresaId) {
      throw new HttpsError("invalid-argument", "empresaId es requerido");
    }

    const accessToken = await getValidGmbAccessToken(empresaId);

    // Obtener cuentas de Business Profile
    const accountsRes = await fetch(
      "https://mybusinessaccountmanagement.googleapis.com/v1/accounts",
      { headers: { Authorization: `Bearer ${accessToken}` } }
    );

    const accountsData = (await accountsRes.json()) as {
      accounts?: Array<{ name: string; accountName: string }>;
      error?: { message: string };
    };

    if (accountsData.error) {
      throw new HttpsError("internal", accountsData.error.message);
    }

    const accounts = accountsData.accounts ?? [];
    const fichas: Array<{
      accountId: string;
      locationId: string;
      nombre: string;
      direccion: string;
    }> = [];

    for (const account of accounts) {
      const accountId = account.name; // "accounts/XXXXXXXX"
      const locRes = await fetch(
        `https://mybusinessbusinessinformation.googleapis.com/v1/${accountId}/locations?readMask=name,title,storefrontAddress`,
        { headers: { Authorization: `Bearer ${accessToken}` } }
      );

      const locData = (await locRes.json()) as {
        locations?: Array<{
          name: string;
          title: string;
          storefrontAddress?: { addressLines?: string[] };
        }>;
      };

      for (const loc of locData.locations ?? []) {
        fichas.push({
          accountId,
          locationId: loc.name, // "locations/XXXXXXXX"
          nombre: loc.title ?? account.accountName ?? "Sin nombre",
          direccion:
            loc.storefrontAddress?.addressLines?.join(", ") ?? "",
        });
      }
    }

    return { fichas };
  }
);

/**
 * guardarFichaSeleccionada
 * Guarda el accountId y locationId en Firestore una vez el empresario elige su ficha.
 */
export const guardarFichaSeleccionada = onCall(
  { region: REGION },
  async (request) => {
    const {
      empresaId,
      accountId,
      locationId,
      nombreFicha,
      direccionFicha,
    } = request.data as {
      empresaId: string;
      accountId: string;
      locationId: string;
      nombreFicha: string;
      direccionFicha: string;
    };

    // ── AUTH GUARD ──
    await verificarAuthYEmpresa(request, empresaId);

    if (!empresaId || !accountId || !locationId) {
      throw new HttpsError(
        "invalid-argument",
        "empresaId, accountId y locationId son requeridos"
      );
    }

    await db
      .collection("empresas")
      .doc(empresaId)
      .collection("configuracion")
      .doc("gmb_config")
      .set(
        {
          conectado: true,
          account_id: accountId,
          location_id: locationId,
          nombre_ficha: nombreFicha ?? "",
          direccion_ficha: direccionFicha ?? "",
          ultima_sync: null,
          configurado_at: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

    console.log(
      `✅ Ficha seleccionada: ${nombreFicha} (${locationId}) para empresa ${empresaId}`
    );
    return { success: true };
  }
);

/**
 * desconectarGoogleBusiness
 * Desconecta la cuenta de Google Business Profile.
 */
export const desconectarGoogleBusiness = onCall(
  { region: REGION },
  async (request) => {
    const { empresaId } = request.data as { empresaId: string };

    // ── AUTH GUARD ──
    await verificarAuthYEmpresa(request, empresaId);

    if (!empresaId) {
      throw new HttpsError("invalid-argument", "empresaId es requerido");
    }

    await db
      .collection("empresas")
      .doc(empresaId)
      .collection("configuracion")
      .doc("gmb_config")
      .set(
        {
          conectado: false,
          desconectado_at: admin.firestore.FieldValue.serverTimestamp(),
          account_id: admin.firestore.FieldValue.delete(),
          location_id: admin.firestore.FieldValue.delete(),
        },
        { merge: true }
      );

    console.log(`🔌 Empresa ${empresaId} desconectada de Google Business`);
    return { success: true };
  }
);


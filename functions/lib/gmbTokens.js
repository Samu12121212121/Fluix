"use strict";
/**
 * GMB Tokens — gestión de tokens OAuth2 para Google Business Profile API
 * Los tokens se guardan cifrados en Secret Manager (nunca en Firestore en claro)
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.desconectarGoogleBusiness = exports.guardarFichaSeleccionada = exports.obtenerFichasNegocio = exports.storeGmbToken = void 0;
exports.getGmbTokens = getGmbTokens;
exports.getValidGmbAccessToken = getValidGmbAccessToken;
const admin = require("firebase-admin");
const https_1 = require("firebase-functions/v2/https");
const node_fetch_1 = require("node-fetch");
const authGuard_1 = require("./utils/authGuard");
const REGION = "europe-west1";
// Guard: el módulo puede cargarse antes de que index.ts llame initializeApp()
if (!admin.apps.length)
    admin.initializeApp();
const db = admin.firestore();
// ── Secret Manager helpers ────────────────────────────────────────────────────
async function storeSecret(secretId, value) {
    const { SecretManagerServiceClient } = await Promise.resolve().then(() => require("@google-cloud/secret-manager"));
    const client = new SecretManagerServiceClient();
    const project = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";
    const name = `projects/${project}/secrets/${secretId}`;
    try {
        await client.addSecretVersion({
            parent: name,
            payload: { data: Buffer.from(value, "utf8") },
        });
    }
    catch (_a) {
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
async function getSecret(secretId) {
    var _a, _b, _c;
    const { SecretManagerServiceClient } = await Promise.resolve().then(() => require("@google-cloud/secret-manager"));
    const client = new SecretManagerServiceClient();
    const project = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "";
    const [version] = await client.accessSecretVersion({
        name: `projects/${project}/secrets/${secretId}/versions/latest`,
    });
    return (_c = (_b = (_a = version.payload) === null || _a === void 0 ? void 0 : _a.data) === null || _b === void 0 ? void 0 : _b.toString()) !== null && _c !== void 0 ? _c : "";
}
async function getGmbTokens(empresaId) {
    const raw = await getSecret(`gmb_token_${empresaId}`);
    return JSON.parse(raw);
}
/**
 * Devuelve un access_token válido, refrescándolo si ha expirado.
 * Exportado para uso en gmbRespuestas y gmbSnapshots.
 */
async function getValidGmbAccessToken(empresaId) {
    var _a, _b, _c;
    const tokens = await getGmbTokens(empresaId);
    // Si caduca en menos de 2 minutos, refrescar
    if (tokens.expires_at > Date.now() + 120000) {
        return tokens.access_token;
    }
    const clientId = (_a = process.env.GOOGLE_OAUTH_CLIENT_ID) !== null && _a !== void 0 ? _a : "";
    const clientSecret = (_b = process.env.GOOGLE_OAUTH_CLIENT_SECRET) !== null && _b !== void 0 ? _b : "";
    const res = await (0, node_fetch_1.default)("https://oauth2.googleapis.com/token", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
            refresh_token: tokens.refresh_token,
            client_id: clientId,
            client_secret: clientSecret,
            grant_type: "refresh_token",
        }).toString(),
    });
    const data = (await res.json());
    if (!data.access_token) {
        throw new Error(`Error refrescando token GMB: ${JSON.stringify(data)}`);
    }
    const newTokens = Object.assign(Object.assign({}, tokens), { access_token: data.access_token, expires_at: Date.now() + parseInt((_c = data.expires_in) !== null && _c !== void 0 ? _c : "3600") * 1000 });
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
exports.storeGmbToken = (0, https_1.onCall)({ region: REGION }, async (request) => {
    var _a, _b, _c, _d, _e, _f;
    const { empresaId, serverAuthCode } = request.data;
    // ── AUTH GUARD ──
    await (0, authGuard_1.verificarAuthYEmpresa)(request, empresaId);
    if (!empresaId || !serverAuthCode) {
        throw new https_1.HttpsError("invalid-argument", "empresaId y serverAuthCode son requeridos");
    }
    const clientId = (_a = process.env.GOOGLE_OAUTH_CLIENT_ID) !== null && _a !== void 0 ? _a : "";
    const clientSecret = (_b = process.env.GOOGLE_OAUTH_CLIENT_SECRET) !== null && _b !== void 0 ? _b : "";
    if (!clientId || !clientSecret) {
        throw new https_1.HttpsError("internal", "Credenciales OAuth no configuradas en el servidor");
    }
    // Intercambiar código por tokens
    const tokenRes = await (0, node_fetch_1.default)("https://oauth2.googleapis.com/token", {
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
    const tokenData = (await tokenRes.json());
    if (!tokenData.access_token) {
        console.error("Error intercambiando code:", tokenData);
        throw new https_1.HttpsError("internal", `Error obteniendo tokens de Google: ${(_d = (_c = tokenData.error_description) !== null && _c !== void 0 ? _c : tokenData.error) !== null && _d !== void 0 ? _d : "unknown"}`);
    }
    const tokens = {
        access_token: tokenData.access_token,
        refresh_token: (_e = tokenData.refresh_token) !== null && _e !== void 0 ? _e : "",
        expires_at: Date.now() + parseInt((_f = tokenData.expires_in) !== null && _f !== void 0 ? _f : "3600") * 1000,
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
        .set({
        conectado: true,
        conectado_at: admin.firestore.FieldValue.serverTimestamp(),
        token_guardado: true,
    }, { merge: true });
    return { success: true };
});
/**
 * obtenerFichasNegocio
 * Lista todas las fichas de Google Business Profile del usuario.
 */
exports.obtenerFichasNegocio = (0, https_1.onCall)({ region: REGION }, async (request) => {
    var _a, _b, _c, _d, _e, _f, _g;
    // ── AUTH GUARD ──
    (0, authGuard_1.verificarAuth)(request);
    const { empresaId } = request.data;
    if (!empresaId) {
        throw new https_1.HttpsError("invalid-argument", "empresaId es requerido");
    }
    const accessToken = await getValidGmbAccessToken(empresaId);
    // Obtener cuentas de Business Profile
    const accountsRes = await (0, node_fetch_1.default)("https://mybusinessaccountmanagement.googleapis.com/v1/accounts", { headers: { Authorization: `Bearer ${accessToken}` } });
    const accountsData = (await accountsRes.json());
    if (accountsData.error) {
        throw new https_1.HttpsError("internal", accountsData.error.message);
    }
    const accounts = (_a = accountsData.accounts) !== null && _a !== void 0 ? _a : [];
    const fichas = [];
    for (const account of accounts) {
        const accountId = account.name; // "accounts/XXXXXXXX"
        const locRes = await (0, node_fetch_1.default)(`https://mybusinessbusinessinformation.googleapis.com/v1/${accountId}/locations?readMask=name,title,storefrontAddress`, { headers: { Authorization: `Bearer ${accessToken}` } });
        const locData = (await locRes.json());
        for (const loc of (_b = locData.locations) !== null && _b !== void 0 ? _b : []) {
            fichas.push({
                accountId,
                locationId: loc.name, // "locations/XXXXXXXX"
                nombre: (_d = (_c = loc.title) !== null && _c !== void 0 ? _c : account.accountName) !== null && _d !== void 0 ? _d : "Sin nombre",
                direccion: (_g = (_f = (_e = loc.storefrontAddress) === null || _e === void 0 ? void 0 : _e.addressLines) === null || _f === void 0 ? void 0 : _f.join(", ")) !== null && _g !== void 0 ? _g : "",
            });
        }
    }
    return { fichas };
});
/**
 * guardarFichaSeleccionada
 * Guarda el accountId y locationId en Firestore una vez el empresario elige su ficha.
 */
exports.guardarFichaSeleccionada = (0, https_1.onCall)({ region: REGION }, async (request) => {
    const { empresaId, accountId, locationId, nombreFicha, direccionFicha, } = request.data;
    // ── AUTH GUARD ──
    await (0, authGuard_1.verificarAuthYEmpresa)(request, empresaId);
    if (!empresaId || !accountId || !locationId) {
        throw new https_1.HttpsError("invalid-argument", "empresaId, accountId y locationId son requeridos");
    }
    await db
        .collection("empresas")
        .doc(empresaId)
        .collection("configuracion")
        .doc("gmb_config")
        .set({
        conectado: true,
        account_id: accountId,
        location_id: locationId,
        nombre_ficha: nombreFicha !== null && nombreFicha !== void 0 ? nombreFicha : "",
        direccion_ficha: direccionFicha !== null && direccionFicha !== void 0 ? direccionFicha : "",
        ultima_sync: null,
        configurado_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log(`✅ Ficha seleccionada: ${nombreFicha} (${locationId}) para empresa ${empresaId}`);
    return { success: true };
});
/**
 * desconectarGoogleBusiness
 * Desconecta la cuenta de Google Business Profile.
 */
exports.desconectarGoogleBusiness = (0, https_1.onCall)({ region: REGION }, async (request) => {
    const { empresaId } = request.data;
    // ── AUTH GUARD ──
    await (0, authGuard_1.verificarAuthYEmpresa)(request, empresaId);
    if (!empresaId) {
        throw new https_1.HttpsError("invalid-argument", "empresaId es requerido");
    }
    await db
        .collection("empresas")
        .doc(empresaId)
        .collection("configuracion")
        .doc("gmb_config")
        .set({
        conectado: false,
        desconectado_at: admin.firestore.FieldValue.serverTimestamp(),
        account_id: admin.firestore.FieldValue.delete(),
        location_id: admin.firestore.FieldValue.delete(),
    }, { merge: true });
    console.log(`🔌 Empresa ${empresaId} desconectada de Google Business`);
    return { success: true };
});
//# sourceMappingURL=gmbTokens.js.map
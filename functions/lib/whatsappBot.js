"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cambiarEstadoChatBot = exports.enviarMensajeAdminWhatsApp = exports.enviarPlantillaWhatsApp = exports.whatsappWebhook = void 0;
const admin = require("firebase-admin");
const https_1 = require("firebase-functions/v2/https");
const sdk_1 = require("@anthropic-ai/sdk");
const node_fetch_1 = require("node-fetch");
const REGION = "europe-west1";
const db = admin.firestore();
// ═══════════════════════════════════════════════════════════════════════════════
// MEJORA 2 — Rate limiting por teléfono + por empresa
// ═══════════════════════════════════════════════════════════════════════════════
async function checkRateLimit(telefono, empresaId) {
    const ahora = Date.now();
    const ventanaMin = 60 * 1000;
    const limiteMin = 10;
    const limiteDia = 1000;
    const hoy = new Date().toISOString().split("T")[0];
    // ── Por teléfono (ventana 1 min) ────────────────────────────────────────
    const refTel = db.collection("rate_limits_whatsapp").doc(telefono);
    let bloqueadoTel = false;
    await db.runTransaction(async (tx) => {
        var _a, _b;
        const snap = await tx.get(refTel);
        const data = (_a = snap.data()) !== null && _a !== void 0 ? _a : { mensajes: [] };
        const recientes = ((_b = data.mensajes) !== null && _b !== void 0 ? _b : []).filter((t) => ahora - t < ventanaMin);
        if (recientes.length >= limiteMin) {
            bloqueadoTel = true;
            return;
        }
        recientes.push(ahora);
        tx.set(refTel, { mensajes: recientes }, { merge: true });
    });
    if (bloqueadoTel) {
        console.warn(`[RATE LIMIT tel] ${telefono} bloqueado`);
        return false;
    }
    // ── Por empresa (día) ───────────────────────────────────────────────────
    const refEmp = db.collection("rate_limits_whatsapp_empresa").doc(`${empresaId}_${hoy}`);
    let bloqueadoEmp = false;
    await db.runTransaction(async (tx) => {
        var _a;
        const snap = await tx.get(refEmp);
        const data = (_a = snap.data()) !== null && _a !== void 0 ? _a : { total: 0 };
        if (data.total >= limiteDia) {
            bloqueadoEmp = true;
            return;
        }
        tx.set(refEmp, { total: admin.firestore.FieldValue.increment(1) }, { merge: true });
    });
    if (bloqueadoEmp) {
        console.warn(`[RATE LIMIT empresa] ${empresaId} superó ${limiteDia} msgs/día`);
        return false;
    }
    return true;
}
// ═══════════════════════════════════════════════════════════════════════════════
// MEJORA 7 — Webhook con configuración optimizada de instancias
// ═══════════════════════════════════════════════════════════════════════════════
exports.whatsappWebhook = (0, https_1.onRequest)({
    region: REGION,
    maxInstances: 100,
    minInstances: 0,
    concurrency: 80,
    memory: "512MiB",
    timeoutSeconds: 30,
    cors: true,
}, async (req, res) => {
    var _a, _b, _c, _d, _e, _f, _g, _h, _j, _k, _l, _m, _o, _p;
    // ── GET: Verificación de Meta ──────────────────────────────────────────
    if (req.method === "GET") {
        const mode = req.query["hub.mode"];
        const token = req.query["hub.verify_token"];
        const challenge = req.query["hub.challenge"];
        if (mode === "subscribe" && token) {
            const snap = await db.collectionGroup("whatsapp_bot")
                .where("verify_token", "==", token).limit(1).get();
            if (!snap.empty) {
                console.log("✅ WhatsApp webhook verificado");
                res.status(200).send(challenge);
                return;
            }
        }
        res.status(403).send("Forbidden");
        return;
    }
    // ── POST: Mensaje entrante ─────────────────────────────────────────────
    if (req.method === "POST") {
        try {
            const body = req.body;
            const value = (_d = (_c = (_b = (_a = body === null || body === void 0 ? void 0 : body.entry) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.changes) === null || _c === void 0 ? void 0 : _c[0]) === null || _d === void 0 ? void 0 : _d.value;
            if (!(value === null || value === void 0 ? void 0 : value.messages) || value.messages.length === 0) {
                res.status(200).send("OK");
                return;
            }
            const message = value.messages[0];
            const phoneNumberId = (_e = value.metadata) === null || _e === void 0 ? void 0 : _e.phone_number_id;
            const contactName = (_j = (_h = (_g = (_f = value.contacts) === null || _f === void 0 ? void 0 : _f[0]) === null || _g === void 0 ? void 0 : _g.profile) === null || _h === void 0 ? void 0 : _h.name) !== null && _j !== void 0 ? _j : "Cliente";
            const clientePhone = message.from;
            if (!phoneNumberId) {
                res.status(200).send("OK");
                return;
            }
            // ── MEJORA 3: Detectar tipo de mensaje ──────────────────────────
            let mensajeUsuario = "";
            let tipoMensaje = "text";
            if ((_k = message.text) === null || _k === void 0 ? void 0 : _k.body) {
                mensajeUsuario = message.text.body;
                tipoMensaje = "text";
            }
            else if (message.image) {
                mensajeUsuario = `[El cliente ha enviado una imagen${message.image.caption ? `: ${message.image.caption}` : ""}]`;
                tipoMensaje = "image";
            }
            else if (message.audio) {
                mensajeUsuario = "[El cliente ha enviado un audio. Pídele que escriba el mensaje, por favor.]";
                tipoMensaje = "audio";
            }
            else if (message.location) {
                mensajeUsuario = `[El cliente ha compartido su ubicación: lat ${message.location.latitude}, lng ${message.location.longitude}]`;
                tipoMensaje = "location";
            }
            else if (message.document) {
                mensajeUsuario = `[El cliente ha enviado un documento: ${(_l = message.document.filename) !== null && _l !== void 0 ? _l : "sin nombre"}]`;
                tipoMensaje = "document";
            }
            else {
                console.log("ℹ️ Tipo de mensaje no soportado:", JSON.stringify(Object.keys(message)));
                res.status(200).send("OK");
                return;
            }
            const configSnap = await db.collectionGroup("whatsapp_bot")
                .where("phone_number_id", "==", phoneNumberId)
                .where("activo", "==", true).limit(1).get();
            if (configSnap.empty) {
                res.status(200).send("OK");
                return;
            }
            const configDoc = configSnap.docs[0];
            const config = configDoc.data();
            const empresaId = configDoc.ref.parent.parent.parent.id;
            procesarMensajeBot({
                empresaId, mensaje: mensajeUsuario, tipoMensaje,
                telefonoCliente: clientePhone, nombreCliente: contactName,
                phoneNumberId, accessToken: config.access_token,
                instruccionesBot: (_m = config.instrucciones_bot) !== null && _m !== void 0 ? _m : "",
                nombreNegocio: (_o = config.nombre_negocio) !== null && _o !== void 0 ? _o : "Negocio",
                sector: (_p = config.sector) !== null && _p !== void 0 ? _p : "",
                derivarSiNoSabe: config.derivar_si_no_sabe !== false,
            }).catch((err) => console.error("❌ Error procesando mensaje:", err));
            res.status(200).send("OK");
        }
        catch (err) {
            console.error("❌ Error en webhook:", err);
            res.status(200).send("OK");
        }
        return;
    }
    res.status(405).send("Method Not Allowed");
});
async function procesarMensajeBot(params) {
    var _a, _b, _c;
    const { empresaId, mensaje, tipoMensaje, telefonoCliente, nombreCliente, phoneNumberId, accessToken, instruccionesBot, nombreNegocio, sector, derivarSiNoSabe, } = params;
    // ── MEJORA 2: Rate limit ────────────────────────────────────────────────
    if (!await checkRateLimit(telefonoCliente, empresaId))
        return;
    const chatsRef = db.collection("empresas").doc(empresaId).collection("chats_bot");
    const now = admin.firestore.Timestamp.now();
    // ── Buscar o crear chat ─────────────────────────────────────────────────
    const chatSnap = await chatsRef
        .where("cliente_telefono", "==", telefonoCliente)
        .where("estado", "in", ["activo", "derivado"])
        .orderBy("fecha_ultimo_mensaje", "desc")
        .limit(1).get();
    let chatRef;
    if (chatSnap.empty) {
        chatRef = chatsRef.doc();
        await chatRef.set({
            cliente_nombre: nombreCliente,
            cliente_telefono: telefonoCliente,
            estado: "activo",
            fecha_creacion: now,
            fecha_ultimo_mensaje: now,
            mensajes_sin_leer: 0,
            total_mensajes: 0,
        });
    }
    else {
        chatRef = chatSnap.docs[0].ref;
    }
    // Guardar mensaje del cliente (con tipo)
    await chatRef.collection("mensajes").add({
        texto: mensaje, tipo_mensaje: tipoMensaje,
        es_bot: false, timestamp: now, nombre: nombreCliente,
    });
    // ── MEJORA 1: Si chat derivado → NO llamar a Claude ────────────────────
    const chatData = (await chatRef.get()).data();
    if ((chatData === null || chatData === void 0 ? void 0 : chatData.estado) === "derivado") {
        await chatRef.update({
            fecha_ultimo_mensaje: now,
            total_mensajes: admin.firestore.FieldValue.increment(1),
            mensajes_sin_leer: admin.firestore.FieldValue.increment(1),
        });
        await notificarAdminMensaje(empresaId, nombreCliente, mensaje, chatRef.id);
        return;
    }
    // ── MEJORA 1: Cargar historial (últimos 10 msgs) ────────────────────────
    const historialSnap = await chatRef.collection("mensajes")
        .orderBy("timestamp", "desc").limit(11).get();
    // Revertir orden y excluir el mensaje recién guardado (último en desc = primero)
    const historial = historialSnap.docs
        .reverse()
        .slice(0, -1) // quitar el que acabamos de escribir
        .map((d) => {
        const data = d.data();
        return {
            role: data.es_bot ? "assistant" : "user",
            content: data.texto,
        };
    });
    // ── Servicios de la empresa para contexto ──────────────────────────────
    let serviciosTexto = "";
    try {
        const sSnap = await db.collection("empresas").doc(empresaId)
            .collection("servicios").limit(20).get();
        if (!sSnap.empty) {
            serviciosTexto = sSnap.docs.map((d) => {
                const s = d.data();
                return `- ${s.nombre}${s.precio ? ` (${s.precio}€)` : ""}${s.duracion ? ` ${s.duracion}min` : ""}`;
            }).join("\n");
        }
    }
    catch (_) { /* sin servicios */ }
    const systemPrompt = `Eres el asistente de WhatsApp de "${nombreNegocio}", un negocio de ${sector || "servicios"}.

${instruccionesBot || "Responde siempre en español, de forma breve y amable."}

${serviciosTexto ? `Servicios disponibles:\n${serviciosTexto}` : ""}

Reglas:
- Responde SIEMPRE en español.
- Sé breve y directo (máximo 2-3 frases).
- Si el cliente quiere hacer un pedido y confirma los productos, usa la herramienta crear_pedido.
- Si el cliente quiere una reserva, recoge: nombre, servicio y fecha/hora.
- Si no puedes resolver algo, responde EXACTAMENTE: "Te paso con el equipo."
- NO inventes información que no tengas.
- Usa emojis con moderación.`;
    // ── MEJORA 5: Tool para crear pedidos ──────────────────────────────────
    const tools = [{
            name: "crear_pedido",
            description: "Crea un pedido cuando el cliente confirma lo que quiere. Úsala solo cuando tengas al menos los items.",
            input_schema: {
                type: "object",
                properties: {
                    items: {
                        type: "array",
                        items: {
                            type: "object",
                            properties: {
                                nombre: { type: "string", description: "Nombre del producto" },
                                cantidad: { type: "number", description: "Cantidad pedida" },
                                precio_estimado: { type: "number", description: "Precio unitario estimado" },
                            },
                            required: ["nombre", "cantidad"],
                        },
                    },
                    direccion_entrega: { type: "string" },
                    hora_entrega: { type: "string" },
                    notas: { type: "string" },
                },
                required: ["items"],
            },
        }];
    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
        console.error("❌ ANTHROPIC_API_KEY no configurada");
        return;
    }
    const anthropic = new sdk_1.default({ apiKey });
    // MEJORA 1: historial + mensaje actual
    const response = await anthropic.messages.create({
        model: "claude-sonnet-4-20250514",
        max_tokens: 500,
        system: systemPrompt,
        tools,
        messages: [...historial, { role: "user", content: mensaje }],
    });
    // ── MEJORA 5: Procesar respuesta con posible tool_use ──────────────────
    let respuestaBot = "";
    for (const block of response.content) {
        if (block.type === "text") {
            respuestaBot = block.text;
        }
        else if (block.type === "tool_use" && block.name === "crear_pedido") {
            const input = block.input;
            const totalEstimado = input.items.reduce((s, i) => { var _a; return s + ((_a = i.precio_estimado) !== null && _a !== void 0 ? _a : 0) * i.cantidad; }, 0);
            await db.collection("empresas").doc(empresaId)
                .collection("pedidos_whatsapp").add({
                cliente_nombre: nombreCliente,
                cliente_telefono: telefonoCliente,
                items: input.items,
                direccion_entrega: (_a = input.direccion_entrega) !== null && _a !== void 0 ? _a : null,
                hora_entrega: (_b = input.hora_entrega) !== null && _b !== void 0 ? _b : null,
                notas: (_c = input.notas) !== null && _c !== void 0 ? _c : null,
                total_estimado: totalEstimado,
                estado: "nuevo",
                chat_id: chatRef.id,
                fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
            });
            await notificarAdminPedido(empresaId, nombreCliente, input.items, totalEstimado);
            respuestaBot = "✅ ¡Perfecto! Tu pedido ha quedado registrado. Nuestro equipo lo confirmará en breve. ¿Necesitas algo más?";
        }
    }
    if (!respuestaBot) {
        console.warn("⚠️ Sin respuesta de Claude");
        return;
    }
    const quiereDerivar = derivarSiNoSabe &&
        respuestaBot.toLowerCase().includes("te paso con el equipo");
    await chatRef.collection("mensajes").add({
        texto: respuestaBot, tipo_mensaje: "text",
        es_bot: true, timestamp: admin.firestore.Timestamp.now(), nombre: nombreNegocio,
    });
    await chatRef.update(Object.assign({ fecha_ultimo_mensaje: admin.firestore.Timestamp.now(), total_mensajes: admin.firestore.FieldValue.increment(2) }, (quiereDerivar ? { estado: "derivado" } : {})));
    await enviarMensajeWhatsApp(phoneNumberId, accessToken, telefonoCliente, respuestaBot);
}
// ═══════════════════════════════════════════════════════════════════════════════
// HELPERS NOTIFICACIONES ADMIN
// ═══════════════════════════════════════════════════════════════════════════════
async function notificarAdminMensaje(empresaId, nombreCliente, mensaje, chatId) {
    try {
        await db.collection("notificaciones").doc(empresaId).collection("items").add({
            titulo: `💬 Mensaje de ${nombreCliente}`,
            cuerpo: mensaje.substring(0, 100),
            tipo: "whatsapp_mensaje",
            modulo_destino: "whatsapp",
            entidad_id: chatId,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            leida: false,
        });
    }
    catch (e) {
        console.error("❌ Error notificando admin:", e);
    }
}
async function notificarAdminPedido(empresaId, nombreCliente, items, totalEstimado) {
    try {
        const resumen = items.map((i) => `${i.cantidad}x ${i.nombre}`).join(", ");
        await db.collection("notificaciones").doc(empresaId).collection("items").add({
            titulo: `🛒 Nuevo pedido de ${nombreCliente}`,
            cuerpo: `${resumen}${totalEstimado > 0 ? ` — ~${totalEstimado.toFixed(2)}€` : ""}`,
            tipo: "whatsapp_pedido",
            modulo_destino: "whatsapp",
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            leida: false,
        });
    }
    catch (e) {
        console.error("❌ Error notificando pedido:", e);
    }
}
// ═══════════════════════════════════════════════════════════════════════════════
// ENVIAR MENSAJE VIA WHATSAPP CLOUD API
// ═══════════════════════════════════════════════════════════════════════════════
async function enviarMensajeWhatsApp(phoneNumberId, accessToken, to, text) {
    const resp = await (0, node_fetch_1.default)(`https://graph.facebook.com/v19.0/${phoneNumberId}/messages`, {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            messaging_product: "whatsapp",
            recipient_type: "individual",
            to, type: "text", text: { body: text },
        }),
    });
    if (!resp.ok) {
        console.error(`❌ Error enviando WhatsApp: ${resp.status} — ${await resp.text()}`);
    }
    else {
        console.log(`✅ Mensaje enviado a ${to}`);
    }
}
// ═══════════════════════════════════════════════════════════════════════════════
// MEJORA 6 — Plantillas HSM para mensajes proactivos
// Plantillas iniciales en Meta Business: confirmacion_reserva, recordatorio_cita, pedido_listo
// ═══════════════════════════════════════════════════════════════════════════════
exports.enviarPlantillaWhatsApp = (0, https_1.onCall)({ region: REGION }, async (req) => {
    var _a, _b, _c;
    if (!req.auth)
        throw new https_1.HttpsError("unauthenticated", "Debes estar autenticado");
    const { empresaId, telefono, plantilla, variables } = req.data;
    if (!empresaId || !telefono || !plantilla) {
        throw new https_1.HttpsError("invalid-argument", "Faltan parámetros: empresaId, telefono, plantilla");
    }
    const configDoc = await db.collection("empresas").doc(empresaId)
        .collection("configuracion").doc("whatsapp_bot").get();
    if (!configDoc.exists) {
        throw new https_1.HttpsError("not-found", "Configuración WhatsApp no encontrada");
    }
    const { phone_number_id, access_token } = configDoc.data();
    const body = {
        messaging_product: "whatsapp",
        to: telefono,
        type: "template",
        template: {
            name: plantilla,
            language: { code: "es" },
            components: (variables === null || variables === void 0 ? void 0 : variables.length) > 0 ? [{
                    type: "body",
                    parameters: variables.map((v) => ({ type: "text", text: v })),
                }] : [],
        },
    };
    const resp = await (0, node_fetch_1.default)(`https://graph.facebook.com/v19.0/${phone_number_id}/messages`, {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${access_token}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
    });
    if (!resp.ok) {
        const errText = await resp.text();
        throw new https_1.HttpsError("internal", `Error al enviar plantilla: ${errText}`);
    }
    const data = await resp.json();
    return { ok: true, message_id: (_c = (_b = (_a = data.messages) === null || _a === void 0 ? void 0 : _a[0]) === null || _b === void 0 ? void 0 : _b.id) !== null && _c !== void 0 ? _c : null };
});
// ═══════════════════════════════════════════════════════════════════════════════
// ENVIAR MENSAJE MANUAL DEL ADMIN (chat derivado)
// ═══════════════════════════════════════════════════════════════════════════════
exports.enviarMensajeAdminWhatsApp = (0, https_1.onCall)({ region: REGION }, async (req) => {
    if (!req.auth)
        throw new https_1.HttpsError("unauthenticated", "Debes estar autenticado");
    const { empresaId, telefonoCliente, chatId, texto } = req.data;
    if (!empresaId || !telefonoCliente || !chatId || !texto) {
        throw new https_1.HttpsError("invalid-argument", "Faltan parámetros");
    }
    // Cargar config WhatsApp
    const configDoc = await db.collection("empresas").doc(empresaId)
        .collection("configuracion").doc("whatsapp_bot").get();
    if (!configDoc.exists)
        throw new https_1.HttpsError("not-found", "Config WhatsApp no encontrada");
    const { phone_number_id, access_token } = configDoc.data();
    const now = admin.firestore.Timestamp.now();
    // Guardar en Firestore
    await db.collection("empresas").doc(empresaId)
        .collection("chats_bot").doc(chatId)
        .collection("mensajes").add({
        texto, tipo_mensaje: "text",
        es_bot: false, es_admin: true,
        timestamp: now, uid_admin: req.auth.uid,
    });
    await db.collection("empresas").doc(empresaId)
        .collection("chats_bot").doc(chatId)
        .update({ fecha_ultimo_mensaje: now });
    await enviarMensajeWhatsApp(phone_number_id, access_token, telefonoCliente, texto);
    return { ok: true };
});
// ═══════════════════════════════════════════════════════════════════════════════
// MARCAR CHAT COMO DERIVADO / ACTIVO / RESUELTO
// ═══════════════════════════════════════════════════════════════════════════════
exports.cambiarEstadoChatBot = (0, https_1.onCall)({ region: REGION }, async (req) => {
    if (!req.auth)
        throw new https_1.HttpsError("unauthenticated", "Debes estar autenticado");
    const { empresaId, chatId, estado } = req.data;
    if (!empresaId || !chatId || !estado) {
        throw new https_1.HttpsError("invalid-argument", "Faltan parámetros");
    }
    await db.collection("empresas").doc(empresaId)
        .collection("chats_bot").doc(chatId)
        .update({
        estado,
        fecha_cambio_estado: admin.firestore.FieldValue.serverTimestamp(),
        uid_gestionado_por: req.auth.uid,
    });
    return { ok: true };
});
//# sourceMappingURL=whatsappBot.js.map
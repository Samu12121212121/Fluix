import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import Anthropic from "@anthropic-ai/sdk";
import fetch from "node-fetch";

const REGION = "europe-west1";
const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════════════════════
// WHATSAPP WEBHOOK — recibe todos los mensajes de todas las empresas
// ═══════════════════════════════════════════════════════════════════════════════

export const whatsappWebhook = onRequest(
  { region: REGION, maxInstances: 20 },
  async (req, res) => {
    // ── GET: Verificación de Meta ──────────────────────────────────────────
    if (req.method === "GET") {
      const mode = req.query["hub.mode"];
      const token = req.query["hub.verify_token"];
      const challenge = req.query["hub.challenge"];

      if (mode === "subscribe" && token) {
        // Buscar la empresa cuyo verify_token coincida
        const snap = await db.collectionGroup("whatsapp_bot")
          .where("verify_token", "==", token)
          .limit(1)
          .get();

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
        const entry = body?.entry?.[0];
        const changes = entry?.changes?.[0];
        const value = changes?.value;

        // Solo procesar mensajes (no status updates, etc.)
        if (!value?.messages || value.messages.length === 0) {
          res.status(200).send("OK");
          return;
        }

        const message = value.messages[0];
        const phoneNumberId = value.metadata?.phone_number_id;
        const contactName = value.contacts?.[0]?.profile?.name ?? "Cliente";
        const clientePhone = message.from; // formato: 34612345678

        if (!phoneNumberId) {
          console.warn("⚠️ Mensaje sin phone_number_id");
          res.status(200).send("OK");
          return;
        }

        // Solo texto por ahora
        const textoMensaje = message.text?.body;
        if (!textoMensaje) {
          console.log("ℹ️ Mensaje no es texto, ignorado");
          res.status(200).send("OK");
          return;
        }

        // Buscar empresa por phone_number_id
        const configSnap = await db.collectionGroup("whatsapp_bot")
          .where("phone_number_id", "==", phoneNumberId)
          .where("activo", "==", true)
          .limit(1)
          .get();

        if (configSnap.empty) {
          console.warn(`⚠️ No hay empresa para phone_number_id=${phoneNumberId}`);
          res.status(200).send("OK");
          return;
        }

        const configDoc = configSnap.docs[0];
        const config = configDoc.data();
        // El empresaId está en la ruta: empresas/{empresaId}/configuracion/whatsapp_bot
        const empresaId = configDoc.ref.parent.parent!.parent.id;

        // Procesar en background para responder rápido a Meta (< 5s)
        procesarMensajeBot({
          empresaId,
          mensaje: textoMensaje,
          telefonoCliente: clientePhone,
          nombreCliente: contactName,
          phoneNumberId,
          accessToken: config.access_token,
          instruccionesBot: config.instrucciones_bot ?? "",
          nombreNegocio: config.nombre_negocio ?? "Negocio",
          sector: config.sector ?? "",
          derivarSiNoSabe: config.derivar_si_no_sabe !== false,
        }).catch((err) => console.error("❌ Error procesando mensaje:", err));

        res.status(200).send("OK");
      } catch (err) {
        console.error("❌ Error en webhook:", err);
        res.status(200).send("OK"); // Siempre 200 para que Meta no reintente
      }
      return;
    }

    res.status(405).send("Method Not Allowed");
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// PROCESAR MENSAJE CON IA + RESPONDER
// ═══════════════════════════════════════════════════════════════════════════════

interface MensajeBotParams {
  empresaId: string;
  mensaje: string;
  telefonoCliente: string;
  nombreCliente: string;
  phoneNumberId: string;
  accessToken: string;
  instruccionesBot: string;
  nombreNegocio: string;
  sector: string;
  derivarSiNoSabe: boolean;
}

async function procesarMensajeBot(params: MensajeBotParams): Promise<void> {
  const {
    empresaId, mensaje, telefonoCliente, nombreCliente,
    phoneNumberId, accessToken, instruccionesBot,
    nombreNegocio, sector, derivarSiNoSabe,
  } = params;

  const chatsRef = db.collection("empresas").doc(empresaId).collection("chats_bot");
  const now = admin.firestore.Timestamp.now();

  // ── Buscar o crear chat ────────────────────────────────────────────────
  let chatSnap = await chatsRef
    .where("cliente_telefono", "==", telefonoCliente)
    .where("estado", "in", ["activo", "derivado"])
    .orderBy("fecha_ultimo_mensaje", "desc")
    .limit(1)
    .get();

  let chatRef: admin.firestore.DocumentReference;

  if (chatSnap.empty) {
    chatRef = chatsRef.doc();
    await chatRef.set({
      cliente_nombre: nombreCliente,
      cliente_telefono: telefonoCliente,
      estado: "activo",
      fecha_creacion: now,
      fecha_ultimo_mensaje: now,
      total_mensajes: 0,
    });
  } else {
    chatRef = chatSnap.docs[0].ref;
  }

  // Guardar mensaje del cliente
  await chatRef.collection("mensajes").add({
    texto: mensaje,
    es_bot: false,
    timestamp: now,
    nombre: nombreCliente,
  });

  // Si el chat está derivado, no responder con bot
  const chatData = (await chatRef.get()).data();
  if (chatData?.estado === "derivado") {
    await chatRef.update({
      fecha_ultimo_mensaje: now,
      total_mensajes: admin.firestore.FieldValue.increment(1),
    });
    return;
  }

  // ── Cargar historial reciente para contexto ─────────────────────────────
  const historialSnap = await chatRef.collection("mensajes")
    .orderBy("timestamp", "desc")
    .limit(10)
    .get();

  const historial = historialSnap.docs
    .reverse()
    .map((d) => {
      const data = d.data();
      return {
        role: data.es_bot ? "assistant" as const : "user" as const,
        content: data.texto as string,
      };
    });

  // ── Cargar servicios de la empresa para contexto ────────────────────────
  let serviciosTexto = "";
  try {
    const serviciosSnap = await db.collection("empresas").doc(empresaId)
      .collection("servicios").limit(20).get();
    if (!serviciosSnap.empty) {
      serviciosTexto = serviciosSnap.docs.map((d) => {
        const s = d.data();
        return `- ${s.nombre}${s.precio ? ` (${s.precio}€)` : ""}${s.duracion ? ` ${s.duracion}min` : ""}`;
      }).join("\n");
    }
  } catch (_) { /* sin servicios */ }

  // ── System prompt ──────────────────────────────────────────────────────
  const systemPrompt = `Eres el asistente de WhatsApp de "${nombreNegocio}", un negocio de ${sector || "servicios"}.

${instruccionesBot || "Responde siempre en español, de forma breve y amable."}

${serviciosTexto ? `Servicios disponibles:\n${serviciosTexto}` : ""}

Reglas:
- Responde SIEMPRE en español.
- Se breve y directo (máximo 2-3 frases).
- Si el cliente quiere hacer una reserva, recoge: nombre, servicio y fecha/hora deseada.
- Si no puedes resolver algo, responde EXACTAMENTE: "Te paso con el equipo."
- NO inventes información que no tengas.
- Usa emojis con moderación.`;

  // ── Llamar a Claude ────────────────────────────────────────────────────
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (!apiKey) {
    console.error("❌ ANTHROPIC_API_KEY no configurada");
    return;
  }

  const anthropic = new Anthropic({ apiKey });

  const response = await anthropic.messages.create({
    model: "claude-sonnet-4-20250514",
    max_tokens: 300,
    system: systemPrompt,
    messages: historial,
  });

  const respuestaBot = response.content[0].type === "text"
    ? response.content[0].text
    : "";

  if (!respuestaBot) return;

  // ── Detectar derivación ────────────────────────────────────────────────
  const quiereDerivar = derivarSiNoSabe &&
    respuestaBot.toLowerCase().includes("te paso con el equipo");

  // Guardar respuesta del bot
  await chatRef.collection("mensajes").add({
    texto: respuestaBot,
    es_bot: true,
    timestamp: admin.firestore.Timestamp.now(),
    nombre: nombreNegocio,
  });

  // Actualizar chat
  await chatRef.update({
    fecha_ultimo_mensaje: admin.firestore.Timestamp.now(),
    total_mensajes: admin.firestore.FieldValue.increment(2),
    ...(quiereDerivar ? { estado: "derivado" } : {}),
  });

  // ── Enviar respuesta por WhatsApp ──────────────────────────────────────
  await enviarMensajeWhatsApp(phoneNumberId, accessToken, telefonoCliente, respuestaBot);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENVIAR MENSAJE VIA WHATSAPP CLOUD API
// ═══════════════════════════════════════════════════════════════════════════════

async function enviarMensajeWhatsApp(
  phoneNumberId: string,
  accessToken: string,
  to: string,
  text: string,
): Promise<void> {
  const url = `https://graph.facebook.com/v19.0/${phoneNumberId}/messages`;

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      messaging_product: "whatsapp",
      recipient_type: "individual",
      to,
      type: "text",
      text: { body: text },
    }),
  });

  if (!resp.ok) {
    const errBody = await resp.text();
    console.error(`❌ Error enviando WhatsApp: ${resp.status} — ${errBody}`);
  } else {
    console.log(`✅ Mensaje enviado a ${to}`);
  }
}


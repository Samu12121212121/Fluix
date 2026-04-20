# 🤖 Guía Completa — Bot de WhatsApp FluixCRM

> **Versión:** 2.0 | **Última actualización:** Abril 2026  
> **Compatible con:** WhatsApp Business API & Twilio

---

## 📋 Índice

1. [Introducción](#introducción)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Acceso desde la App](#acceso-desde-la-app)
4. [Configuración Inicial](#configuración-inicial)
5. [Respuestas Automáticas](#respuestas-automáticas)
6. [Motor de Intenciones](#motor-de-intenciones)
7. [Modo Agente](#modo-agente)
8. [Integración con WhatsApp Real](#integración-con-whatsapp-real)
9. [Cloud Functions](#cloud-functions)
10. [Estructura Firestore](#estructura-firestore)
11. [Plantillas por Negocio](#plantillas-por-negocio)
12. [Notificaciones y Alertas](#notificaciones-y-alertas)
13. [Analytics del Bot](#analytics-del-bot)
14. [Solución de Problemas](#solución-de-problemas)
15. [Buenas Prácticas](#buenas-prácticas)

---

## 🎯 Introducción

### ¿Qué es el Bot de WhatsApp?

El Bot de WhatsApp de FluixCRM es un sistema de automatización de mensajería que permite:

- ✅ **Responder automáticamente** a preguntas frecuentes
- ✅ **Guiar reservas y citas** sin intervención humana
- ✅ **Mostrar servicios y productos** del catálogo
- ✅ **Gestionar pedidos** para hostelería/comercio
- ✅ **Derivar a agente humano** cuando sea necesario
- ✅ **Integrar con el CRM** para registrar leads y clientes

### ¿Por qué usarlo?

| Beneficio | Impacto |
|-----------|---------|
| Atención 24/7 | Responde incluso fuera de horario |
| Reducción de carga | 70% menos consultas manuales |
| Velocidad | Respuesta instantánea (<1 segundo) |
| Consistencia | Misma calidad de respuesta siempre |
| Trazabilidad | Todo queda registrado en Firestore |

---

## 🏗️ Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENTE (WhatsApp)                        │
└──────────────────────────────┬──────────────────────────────────┘
                               │ Mensaje entrante
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                   WhatsApp Business API / Twilio                 │
│                     (Webhook → Cloud Functions)                  │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CLOUD FUNCTION: webhookWhatsApp               │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  Validar    │→ │  Buscar/    │→ │  Procesar con Motor     │  │
│  │  Mensaje    │  │  Crear Chat │  │  de Respuestas          │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────┘
                               │
          ┌────────────────────┼────────────────────┐
          ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ CAPA 1:         │  │ CAPA 2:         │  │ CAPA 3:         │
│ Palabras Clave  │  │ Intenciones IA  │  │ Fallback        │
│ (bot_respuestas)│  │ (detectIntent)  │  │ (config/bot)    │
└─────────────────┘  └─────────────────┘  └─────────────────┘
          │                    │                    │
          └────────────────────┼────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                         FIRESTORE                                │
│  empresas/{id}/chats/{chatId}/mensajes/{msgId}                  │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    RESPUESTA AL CLIENTE                          │
│                  (via WhatsApp API / Twilio)                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📱 Acceso desde la App

### Ruta de navegación

```
Dashboard Principal
    └── 💬 WhatsApp (menú inferior)
            ├── 📬 Chats (conversaciones activas)
            ├── 🤖 Bot (configuración y respuestas)
            └── ⚙️ Configuración (ajustes generales)
```

### Pantallas principales

| Pantalla | Función |
|----------|---------|
| **Lista de Chats** | Ver todas las conversaciones activas |
| **Chat Individual** | Leer mensajes y responder como agente |
| **Respuestas Bot** | Gestionar palabras clave y respuestas |
| **Configuración Bot** | Activar/desactivar, mensajes por defecto |

---

## ⚙️ Configuración Inicial

### Paso 1: Inicializar el Bot

1. Abre **WhatsApp → 🤖 Bot**
2. Pulsa **"Ver conversaciones del bot"**
3. Menú **⋮ → "Inicializar bot con datos de prueba"**

Esto crea automáticamente:
- ✅ 5 respuestas automáticas básicas
- ✅ 3 conversaciones de ejemplo
- ✅ Configuración por defecto

### Paso 2: Configurar el Bot

Menú **⋮ → "Configurar bot"**

| Campo | Descripción | Ejemplo |
|-------|-------------|---------|
| **Bot activo** | Habilita el bot | ✅ Activado |
| **Respuesta automática** | Responde sin intervención | ✅ Activado |
| **Mensaje bienvenida** | Primer mensaje al cliente | "¡Hola! Soy el asistente de [Negocio] 👋" |
| **Mensaje fallback** | Cuando no entiende | "No entendí tu mensaje. Te comunico con un agente." |
| **Horario del negocio** | Información de horarios | "Lunes a Sábado 9:00-20:00" |
| **Teléfono contacto** | Para emergencias | "+34 600 123 456" |

### Paso 3: Probar el Bot

1. Desde la lista de chats, pulsa **"+ Nuevo chat de prueba"**
2. Simula mensajes del cliente escribiendo en el campo inferior
3. Observa cómo responde el bot automáticamente

---

## 💬 Respuestas Automáticas

### Cómo funcionan

Las respuestas automáticas se activan cuando el mensaje del cliente contiene **cualquiera** de las palabras clave configuradas.

```
Cliente escribe: "Hola, ¿cuánto cuesta un corte?"
                      ↓
Sistema detecta: "cuánto cuesta" → coincide con ["precio", "coste", "cuánto cuesta"]
                      ↓
Bot responde con la respuesta configurada para esa palabra clave
```

### Crear una respuesta automática

1. Ve a **WhatsApp → 🤖 Bot → Pestaña "Respuestas Bot"**
2. Pulsa el botón **"+"**
3. Rellena:
   - **Palabras clave**: separadas por comas
   - **Respuesta del bot**: el texto que responderá
4. Pulsa **"Guardar"**

### Respuestas por defecto recomendadas

| Palabras clave | Respuesta sugerida |
|----------------|-------------------|
| `hola, buenos días, buenas tardes, buenas` | ¡Hola! 👋 ¿En qué puedo ayudarte hoy? |
| `gracias, muchas gracias, genial` | ¡De nada! 😊 ¿Necesitas algo más? |
| `adiós, hasta luego, bye, chao` | ¡Hasta pronto! 👋 Gracias por contactarnos. |
| `agente, persona, humano, hablar con alguien` | Perfecto, te paso con un agente. Un momento... 🙋 |
| `horario, abierto, cerrado, cuándo abren` | 📅 Nuestro horario es: [HORARIO]. ¿Puedo ayudarte en algo más? |
| `precio, coste, cuánto, tarifa, vale` | 💰 Te paso nuestra lista de precios: [ENLACE o LISTA] |

---

## 🧠 Motor de Intenciones

El bot tiene un sistema de 3 capas para procesar mensajes:

### Capa 1: Palabras Clave (Exactas)

- Busca coincidencias exactas en `bot_respuestas`
- Es la más rápida y precisa
- Prioridad máxima

### Capa 2: Detección de Intención

Cuando no hay coincidencia exacta, el bot analiza el mensaje:

| Intención detectada | Acción |
|--------------------|--------|
| `reservar_cita` | Muestra guía para reservar |
| `ver_servicios` | Lista servicios de Firestore |
| `ver_productos` | Lista productos/catálogo |
| `consultar_horario` | Muestra horario configurado |
| `hacer_pedido` | Inicia flujo de pedido |
| `pedir_informacion` | Muestra perfil del negocio |
| `hablar_agente` | Notifica al agente humano |

### Capa 3: Fallback

Si ninguna capa anterior funciona:
- Envía el mensaje fallback configurado
- Marca el chat como "pendiente de agente"
- Opcionalmente envía notificación push al dueño

---

## 👤 Modo Agente

### Cuándo usarlo

- Consultas complejas que el bot no puede manejar
- Confirmación de reservas/pedidos
- Reclamaciones o quejas
- Negociaciones o descuentos

### Cómo activarlo

1. Abre la conversación desde la lista de chats
2. Activa el **toggle 👤** en la esquina superior derecha
3. Escribe tu respuesta manualmente
4. El mensaje aparece marcado como **"Agente"** (icono morado)

### Indicadores visuales

| Icono | Tipo de mensaje |
|-------|-----------------|
| 🤖 (verde) | Respuesta automática del bot |
| 👤 (morado) | Respuesta manual del agente |
| 👤 (gris) | Mensaje del cliente |

---

## 🔗 Integración con WhatsApp Real

### Opción A: WhatsApp Business API (Meta)

**Requisitos:**
- Cuenta de Meta Business verificada
- Número de teléfono dedicado
- Dominio verificado

**Pasos:**

1. **Crear App en Meta for Developers**
   ```
   https://developers.facebook.com/apps/
   → Crear app → Tipo "Business"
   ```

2. **Añadir producto WhatsApp**
   ```
   Dashboard de la app → Añadir producto → WhatsApp
   ```

3. **Obtener credenciales**
   - `Phone Number ID`: ID del número de WhatsApp
   - `Access Token`: Token de acceso permanente
   - `Webhook Verify Token`: Token personalizado

4. **Configurar Webhook**
   ```
   URL: https://europe-west1-planeaapp-4bea4.cloudfunctions.net/webhookWhatsApp
   Verify Token: [tu_token_secreto]
   Suscripciones: messages, messaging_postbacks
   ```

5. **Variables de entorno (Cloud Functions)**
   ```bash
   firebase functions:config:set whatsapp.phone_id="XXXX" \
     whatsapp.token="XXXX" \
     whatsapp.verify_token="XXXX"
   ```

### Opción B: Twilio WhatsApp Sandbox

**Ideal para:** Pruebas y desarrollos pequeños

1. **Crear cuenta Twilio**
   ```
   https://www.twilio.com/try-twilio
   ```

2. **Activar Sandbox**
   ```
   Console → Messaging → Try WhatsApp
   ```

3. **Unirse al Sandbox**
   - El cliente envía: `join [código-sandbox]`
   - Al número: `+1 415 523 8886`

4. **Configurar Webhook**
   ```
   When a message comes in:
   https://europe-west1-planeaapp-4bea4.cloudfunctions.net/webhookTwilio
   Method: POST
   ```

5. **Credenciales**
   ```bash
   firebase functions:config:set twilio.account_sid="XXXX" \
     twilio.auth_token="XXXX" \
     twilio.whatsapp_number="+14155238886"
   ```

---

## ☁️ Cloud Functions

### Función principal: `webhookWhatsApp`

```typescript
// functions/src/whatsapp/webhook.ts

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

export const webhookWhatsApp = functions
  .region('europe-west1')
  .https.onRequest(async (req, res) => {
    
    // Verificación del webhook (GET)
    if (req.method === 'GET') {
      const mode = req.query['hub.mode'];
      const token = req.query['hub.verify_token'];
      const challenge = req.query['hub.challenge'];
      
      if (mode === 'subscribe' && token === functions.config().whatsapp.verify_token) {
        res.status(200).send(challenge);
        return;
      }
      res.status(403).send('Forbidden');
      return;
    }
    
    // Procesar mensaje entrante (POST)
    try {
      const body = req.body;
      const entry = body.entry?.[0];
      const changes = entry?.changes?.[0];
      const message = changes?.value?.messages?.[0];
      
      if (!message) {
        res.status(200).send('OK');
        return;
      }
      
      const from = message.from; // Número del cliente
      const text = message.text?.body || '';
      const empresaId = await getEmpresaIdByPhone(changes.value.metadata.phone_number_id);
      
      // Buscar o crear chat
      const chatRef = await findOrCreateChat(empresaId, from);
      
      // Guardar mensaje del cliente
      await chatRef.collection('mensajes').add({
        autor: 'cliente',
        mensaje: text,
        fecha: admin.firestore.FieldValue.serverTimestamp(),
        leido: false,
      });
      
      // Procesar con el motor del bot
      const respuesta = await procesarMensaje(empresaId, text);
      
      // Guardar respuesta del bot
      await chatRef.collection('mensajes').add({
        autor: 'bot',
        mensaje: respuesta.texto,
        fecha: admin.firestore.FieldValue.serverTimestamp(),
        intent_detectado: respuesta.intent,
      });
      
      // Enviar respuesta por WhatsApp
      await enviarMensajeWhatsApp(from, respuesta.texto);
      
      res.status(200).send('OK');
    } catch (error) {
      console.error('Error webhook:', error);
      res.status(500).send('Error');
    }
  });
```

### Función: `procesarMensaje`

```typescript
async function procesarMensaje(empresaId: string, texto: string): Promise<{texto: string, intent: string}> {
  const db = admin.firestore();
  const textoLower = texto.toLowerCase().trim();
  
  // CAPA 1: Buscar en respuestas configuradas
  const respuestasSnap = await db
    .collection('empresas')
    .doc(empresaId)
    .collection('bot_respuestas')
    .where('activa', '==', true)
    .get();
  
  for (const doc of respuestasSnap.docs) {
    const data = doc.data();
    const palabras = data.palabras_clave || [];
    
    for (const palabra of palabras) {
      if (textoLower.includes(palabra.toLowerCase())) {
        return {
          texto: data.respuesta,
          intent: `keyword:${palabra}`,
        };
      }
    }
  }
  
  // CAPA 2: Detectar intención
  const intent = detectarIntencion(textoLower);
  if (intent) {
    const respuestaIntent = await generarRespuestaIntent(empresaId, intent);
    return {
      texto: respuestaIntent,
      intent: intent,
    };
  }
  
  // CAPA 3: Fallback
  const config = await db
    .collection('empresas')
    .doc(empresaId)
    .collection('configuracion')
    .doc('bot')
    .get();
  
  const fallback = config.data()?.mensaje_fallback || 
    'Lo siento, no entendí tu mensaje. Un agente te atenderá pronto.';
  
  return {
    texto: fallback,
    intent: 'fallback',
  };
}
```

---

## 📁 Estructura Firestore

```
empresas/
└── {empresaId}/
    ├── configuracion/
    │   └── bot                          # Configuración del bot
    │       ├── activo: boolean
    │       ├── respuesta_automatica: boolean
    │       ├── mensaje_bienvenida: string
    │       ├── mensaje_fallback: string
    │       ├── horario_texto: string
    │       ├── telefono_contacto: string
    │       └── updated_at: timestamp
    │
    ├── bot_respuestas/                  # Respuestas automáticas
    │   └── {respuestaId}
    │       ├── palabras_clave: string[]
    │       ├── respuesta: string
    │       ├── activa: boolean
    │       ├── prioridad: number
    │       └── created_at: timestamp
    │
    └── chats/                           # Conversaciones
        └── {chatId}
            ├── cliente_nombre: string
            ├── telefono: string
            ├── canal: "whatsapp" | "web" | "instagram"
            ├── estado: "activo" | "pendiente" | "cerrado"
            ├── modo_agente: boolean
            ├── ultimo_mensaje: timestamp
            ├── mensajes_sin_leer: number
            ├── created_at: timestamp
            │
            └── mensajes/                # Mensajes del chat
                └── {mensajeId}
                    ├── autor: "cliente" | "bot" | "agente"
                    ├── mensaje: string
                    ├── fecha: timestamp
                    ├── leido: boolean
                    ├── intent_detectado: string?
                    └── multimedia: {tipo, url}?
```

---

## 🏪 Plantillas por Negocio

### 🏥 Peluquería / Estética

```
PALABRAS: precio, coste, cuánto cuesta, tarifa
RESPUESTA:
💇 Nuestros precios:
• Corte caballero: 15€
• Corte señora: 25€
• Tinte: desde 45€
• Mechas: desde 65€
• Peinado: 30€

¿Quieres pedir cita? Dime qué día y hora prefieres 📅
```

```
PALABRAS: cita, reservar, hora, disponibilidad
RESPUESTA:
📅 Para reservar tu cita necesito:
1️⃣ ¿Qué servicio quieres?
2️⃣ ¿Qué día prefieres?
3️⃣ ¿Mañana o tarde?

¡Te confirmo enseguida! ✨
```

### 🍕 Restaurante / Hostelería

```
PALABRAS: carta, menú, menu, qué tienen
RESPUESTA:
🍽️ Puedes ver nuestra carta completa en:
www.restaurante.com/carta

📱 También puedes pedir por WhatsApp:
Solo dime qué platos quieres y te lo preparamos para recoger o envío a domicilio.
```

```
PALABRAS: reserva mesa, reservar mesa, cena, comida para
RESPUESTA:
🍽️ ¡Perfecto! Para reservar mesa necesito:
• 👥 Número de personas
• 📅 Fecha y hora
• 📝 Nombre para la reserva

¿Me lo confirmas?
```

```
PALABRAS: delivery, domicilio, para llevar, envío
RESPUESTA:
🛵 ¡Hacemos envío a domicilio!
⏱️ Tiempo estimado: 30-45 minutos
💰 Envío gratis a partir de 20€

Dime qué quieres pedir y tu dirección 📍
```

### 💆 Spa / Centro de Bienestar

```
PALABRAS: masaje, tratamiento, spa, relajante
RESPUESTA:
💆 Nuestros tratamientos estrella:

• Masaje relajante 60min — 50€
• Masaje deportivo 60min — 55€
• Facial hidratante — 45€
• Circuito spa — 35€
• Pack pareja 90min — 120€

¿Te reservo uno? Dime día y hora preferida 😊
```

### 🏪 Comercio / Tienda

```
PALABRAS: stock, disponible, tenéis, tienen
RESPUESTA:
📦 Para consultar disponibilidad, dime:
• Qué producto buscas
• Talla o tamaño (si aplica)
• Color preferido

Te confirmo en unos minutos ⏱️
```

```
PALABRAS: envío, cuándo llega, shipping
RESPUESTA:
🚚 Información de envíos:
• Envío estándar: 3-5 días (4,95€)
• Envío express: 24-48h (7,95€)
• Gratis a partir de 50€

¿Quieres realizar un pedido?
```

### 🏋️ Gimnasio / Centro Deportivo

```
PALABRAS: matrícula, precio, cuota, mensual
RESPUESTA:
🏋️ Nuestras tarifas:

• Cuota mensual: 35€/mes
• Trimestral: 90€ (30€/mes)
• Anual: 300€ (25€/mes)

✅ Sin matrícula ni permanencia
🎁 Primera clase GRATIS

¿Quieres venir a probar?
```

---

## 🔔 Notificaciones y Alertas

### Configurar notificaciones push

```typescript
// Enviar notificación cuando el bot no puede responder
async function notificarAgente(empresaId: string, chatId: string, mensaje: string) {
  const empresaDoc = await admin.firestore()
    .collection('empresas')
    .doc(empresaId)
    .get();
  
  const fcmToken = empresaDoc.data()?.fcm_token;
  
  if (fcmToken) {
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: '💬 Nuevo mensaje pendiente',
        body: mensaje.substring(0, 100),
      },
      data: {
        type: 'chat_pendiente',
        chatId: chatId,
      },
    });
  }
}
```

### Alertas por email

```typescript
// Resumen diario de conversaciones
exports.resumenDiarioChats = functions
  .region('europe-west1')
  .pubsub.schedule('0 9 * * *')  // 9:00 AM todos los días
  .timeZone('Europe/Madrid')
  .onRun(async (context) => {
    // Enviar email con resumen de chats del día anterior
  });
```

---

## 📊 Analytics del Bot

### Métricas a trackear

| Métrica | Descripción |
|---------|-------------|
| `mensajes_recibidos` | Total de mensajes entrantes |
| `respuestas_automaticas` | Mensajes respondidos por el bot |
| `escalados_agente` | Mensajes que requirieron intervención |
| `tiempo_respuesta` | Tiempo medio de respuesta del bot |
| `tasa_resolucion` | % de conversaciones cerradas sin agente |
| `intenciones_detectadas` | Distribución de intenciones |

### Dashboard de estadísticas

```dart
// Widget para mostrar stats del bot en el dashboard
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('empresas')
    .doc(empresaId)
    .collection('chats')
    .where('canal', isEqualTo: 'whatsapp')
    .snapshots(),
  builder: (context, snapshot) {
    final chats = snapshot.data?.docs ?? [];
    final activos = chats.where((c) => c['estado'] == 'activo').length;
    final pendientes = chats.where((c) => c['estado'] == 'pendiente').length;
    
    return Row(
      children: [
        _StatCard('Chats activos', activos, Colors.green),
        _StatCard('Pendientes', pendientes, Colors.orange),
        _StatCard('Total', chats.length, Colors.blue),
      ],
    );
  },
);
```

---

## 🔧 Solución de Problemas

### El bot no responde

1. **Verificar que el bot está activo**
   ```
   Dashboard → WhatsApp → Config → "Bot activo" ✅
   ```

2. **Comprobar Cloud Functions**
   ```bash
   firebase functions:log --only webhookWhatsApp
   ```

3. **Verificar webhook en Meta**
   ```
   Meta Business → WhatsApp → Configuración → Webhook → Estado
   ```

### Respuestas incorrectas

1. **Revisar palabras clave**
   - Asegúrate de que las palabras clave son específicas
   - Evita palabras muy genéricas como "sí", "no", "ok"

2. **Prioridad de respuestas**
   - Configura prioridad más alta para respuestas importantes
   - Las respuestas con prioridad mayor se evalúan primero

### Mensajes duplicados

1. **Verificar idempotencia**
   - Guarda el `message_id` de WhatsApp
   - Ignora mensajes ya procesados

2. **Timeout del webhook**
   - Responde `200 OK` inmediatamente
   - Procesa el mensaje en background

---

## 💡 Buenas Prácticas

### Contenido de las respuestas

- ✅ **Sé conciso**: WhatsApp no es email
- ✅ **Usa emojis**: 👋 🎉 ✅ ❌ hacen el mensaje más amigable
- ✅ **Incluye CTAs**: "¿Quieres reservar?", "Dime tu dirección"
- ✅ **Ofrece alternativas**: Si el bot no entiende, da opciones
- ✅ **Personaliza**: Usa el nombre del cliente cuando sea posible

### Palabras clave

- ✅ **Añade variantes**: "precio", "coste", "cuánto", "vale"
- ✅ **Incluye errores comunes**: "presio", "cuamto"
- ✅ **Usa frases completas**: "cuánto cuesta", "qué precio tiene"
- ❌ **Evita palabras genéricas**: "hola" solo, "sí", "no"

### Configuración

- ✅ **Mensaje de bienvenida personalizado** con nombre del negocio
- ✅ **Fallback útil**: "No entendí. Escribe AYUDA para ver opciones."
- ✅ **Horario actualizado**: Especialmente festivos y vacaciones
- ✅ **Revisa chats diariamente**: Mejora respuestas según patrones

### Seguridad

- ✅ **No pidas datos sensibles** por WhatsApp (tarjetas, contraseñas)
- ✅ **Valida números de teléfono** antes de guardar
- ✅ **Configura rate limiting** para evitar spam
- ✅ **Registra logs** de todas las interacciones

---

## ✅ Checklist de Implementación

### Configuración inicial
- [ ] Inicializar bot desde la app
- [ ] Configurar mensaje de bienvenida
- [ ] Configurar mensaje fallback
- [ ] Establecer horario del negocio
- [ ] Añadir teléfono de contacto

### Respuestas automáticas
- [ ] Crear respuesta de saludo
- [ ] Crear respuesta de despedida
- [ ] Crear respuesta de precios/servicios
- [ ] Crear respuesta para reservas/citas
- [ ] Crear respuesta para escalar a agente

### Integración
- [ ] Configurar WhatsApp Business API o Twilio
- [ ] Desplegar Cloud Functions
- [ ] Verificar webhook funcional
- [ ] Probar envío/recepción de mensajes

### Optimización
- [ ] Revisar conversaciones reales
- [ ] Ajustar palabras clave
- [ ] Mejorar respuestas según feedback
- [ ] Activar notificaciones push
- [ ] Configurar analytics

---

## 📚 Referencias

- [WhatsApp Business API Documentation](https://developers.facebook.com/docs/whatsapp)
- [Twilio WhatsApp API](https://www.twilio.com/docs/whatsapp)
- [Firebase Cloud Functions](https://firebase.google.com/docs/functions)
- [FluixCRM - Documentación Técnica](./ARCHITECTURE_FISCAL.txt)

---

*Documentación generada para FluixCRM / PlaneaGuada — Abril 2026*


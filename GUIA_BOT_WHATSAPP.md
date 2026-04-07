# 🤖 Guía de Implementación — Bot WhatsApp

## ¿Qué es y para qué sirve?

El Bot WhatsApp permite que tus clientes interactúen automáticamente con el negocio
a través de mensajes. Responde a preguntas frecuentes, muestra servicios y productos,
guía reservas y pedidos — **sin que el negocio tenga que estar pendiente**.

---

## 📱 Cómo acceder desde la app

```
Dashboard → WhatsApp (menú inferior) → Pestaña 🤖 Bot
```

Desde ahí tienes dos opciones:
- **"Ver conversaciones del bot"** → lista de todos los chats activos
- **"Configurar respuestas automáticas"** → gestiona las respuestas por palabras clave

---

## 🚀 Paso 1: Inicializar el bot por primera vez

1. Entra en **WhatsApp → 🤖 Bot**
2. Pulsa **"Ver conversaciones del bot"**
3. En la pantalla de chats, pulsa el menú **⋮** (arriba a la derecha)
4. Selecciona **"Inicializar bot con datos de prueba"**

Esto crea automáticamente:
- ✅ 5 respuestas automáticas por defecto (saludo, despedida, gracias, pago, agente)
- ✅ 3 conversaciones de ejemplo para ver cómo funciona
- ✅ Configuración por defecto del bot

---

## ⚙️ Paso 2: Configurar el bot para tu negocio

1. Pulsa el menú **⋮ → "Configurar bot"**
2. Rellena los campos:

| Campo | Ejemplo |
|---|---|
| **Mensaje de bienvenida** | "¡Hola! Soy el asistente de Peluquería Carmen 👋" |
| **Mensaje fallback** | "No entendí tu mensaje. Te paso con un agente." |
| **Horario del negocio** | "Lunes a Sábado de 9:00 a 20:00" |
| **Teléfono de contacto** | "+34 949 123 456" |

3. Activa **"Bot activo"** y **"Respuesta automática"**
4. Pulsa **"Guardar configuración"**

---

## 💬 Paso 3: Añadir respuestas automáticas personalizadas

Las respuestas automáticas se basan en **palabras clave** que escribe el cliente.

### Cómo añadir una respuesta:

1. Ve a **WhatsApp → 🤖 Bot → "Ver conversaciones"**
2. En la pantalla de chats, selecciona la pestaña **"🤖 Respuestas Bot"**
3. Pulsa el botón **"+"** (esquina inferior derecha)
4. Rellena:
   - **Palabras clave**: las palabras que activan esta respuesta (separadas por comas)
   - **Respuesta del bot**: el texto que responde el bot

### Ejemplos por tipo de negocio:

#### 🏥 Peluquería / Estética
```
Palabras clave: precio, coste, cuánto cuesta, tarifa
Respuesta: 💇 Nuestros precios:
• Corte dama: 28€
• Tinte: desde 45€
• Mechas: desde 65€
¿Quieres pedir cita?
```

```
Palabras clave: cita, reservar, hora disponible
Respuesta: 📅 Para pedir cita dime:
1. ¿Qué servicio quieres?
2. ¿Qué día prefieres?
3. ¿Mañana o tarde?
```

#### 🍕 Restaurante / Cafetería
```
Palabras clave: carta, menú, menu, qué tienen, qué hay
Respuesta: 🍽️ Puedes ver nuestra carta en:
www.mirestaurante.com/carta
¿Quieres pedir para llevar o tienes alguna pregunta?
```

```
Palabras clave: reserva mesa, reservar, cena, comida
Respuesta: 🍽️ Para reservar mesa necesito:
• Número de personas
• Día y hora
• Nombre

¿Me lo confirmas?
```

```
Palabras clave: para llevar, takeaway, delivery, domicilio
Respuesta: 🛵 Hacemos pedidos para llevar.
Tiempo estimado: 30-45 min.
¿Qué quieres pedir? Dime los platos y la dirección 📍
```

#### 💆 Centro de masajes / Spa
```
Palabras clave: masaje, tratamiento, relajante, facial
Respuesta: 💆 Nuestros tratamientos:
• Masaje relajante 60min — 45€
• Masaje deportivo 60min — 50€
• Facial completo — 55€
• Pack pareja 90min — 95€

¿Te reservo uno? 😊
```

#### 🏪 Tienda / Comercio
```
Palabras clave: stock, disponible, tenéis, tienen
Respuesta: 📦 Para consultar disponibilidad de un producto
dime el artículo que buscas y te lo confirmo en breve.
```

```
Palabras clave: envío, entrega, shipping, cuándo llega
Respuesta: 🚚 Hacemos envíos en 24-48h laborables.
Envío gratis a partir de 50€.
¿Quieres realizar un pedido?
```

---

## 🧠 Cómo funciona el motor del bot (3 capas)

```
Cliente escribe un mensaje
        ↓
┌─────────────────────────────────────────┐
│  CAPA 1: Palabras clave                 │
│  ¿Contiene alguna palabra configurada?  │
│  SÍ → Responde automáticamente         │
└──────────────────────┬──────────────────┘
                       │ NO
                       ↓
┌─────────────────────────────────────────┐
│  CAPA 2: Detección de intención        │
│  • "reservar" → guía de reserva        │
│  • "servicios" → lista de Firestore    │
│  • "horario" → horario configurado     │
│  • "pedido" → catálogo de productos    │
│  • "información" → perfil empresa      │
└──────────────────────┬──────────────────┘
                       │ No reconocido
                       ↓
┌─────────────────────────────────────────┐
│  CAPA 3: Mensaje fallback              │
│  "No entendí, te paso con un agente"   │
└─────────────────────────────────────────┘
```

---

## 👤 Modo Agente — cuándo tomarlo tú

Cuando el bot no sea suficiente, puedes responder tú manualmente:

1. Abre la conversación desde la lista de chats
2. Activa el **toggle** en la esquina superior derecha (icono 👤)
3. Escribe tu respuesta — aparecerá con el icono de **Agente** en morado
4. El cliente ve exactamente lo que escribes

> 💡 **Consejo**: usa el modo agente para confirmar reservas concretas
> o resolver dudas que el bot no puede manejar.

---

## 📲 Paso 4: Integrar con WhatsApp real (WhatsApp Business API)

Para que el bot funcione en WhatsApp real (no solo en simulación):

### Opción A: WhatsApp Business API (Meta)
Requiere cuenta verificada de Meta Business.

1. Ve a [business.facebook.com](https://business.facebook.com)
2. Crea una app de tipo **Business**
3. Añade el producto **WhatsApp**
4. Obtén tu **Phone Number ID** y **Access Token**
5. Configura el **webhook** apuntando a tu Cloud Function:
   ```
   https://europe-west1-planeaapp-4bea4.cloudfunctions.net/webhookWhatsApp
   ```

### Opción B: Twilio WhatsApp (más fácil para empezar)
1. Crea cuenta en [twilio.com](https://twilio.com)
2. Activa el **Sandbox de WhatsApp**
3. El cliente envía "join [código]" al número de Twilio
4. Configura el webhook de Twilio apuntando a tu función

### Cloud Function necesaria (ya preparada en `/functions`):
```typescript
// Se activa cuando llega un mensaje de WhatsApp
exports.webhookWhatsApp = functions.https.onRequest(async (req, res) => {
  const { from, body } = req.body.entry[0].changes[0].value.messages[0];
  
  // Busca o crea el chat en Firestore
  // Llama al motor del bot
  // Envía la respuesta via WhatsApp API
});
```

---

## 📊 Qué datos se guardan en Firestore

```
empresas/{empresaId}/
├── chats/{chatId}                    ← cada conversación
│   ├── cliente_nombre: "María García"
│   ├── telefono: "+34 612 345 678"
│   ├── canal: "whatsapp"
│   ├── estado: "activo"
│   ├── ultimo_mensaje: Timestamp
│   └── mensajes_sin_leer: 2
│   └── mensajes/{mensajeId}         ← cada mensaje
│       ├── autor: "cliente" | "bot" | "agente"
│       ├── mensaje: "Hola, quiero una cita"
│       ├── fecha: Timestamp
│       └── intent_detectado: "reservar_cita"
│
├── bot_respuestas/{id}              ← respuestas por palabras clave
│   ├── palabras_clave: ["hola", "buenas"]
│   ├── respuesta: "¡Hola! ¿En qué puedo ayudarte?"
│   └── activa: true
│
└── configuracion/bot                ← config del bot
    ├── activo: true
    ├── mensaje_bienvenida: "¡Hola!..."
    ├── mensaje_fallback: "No entendí..."
    ├── horario_texto: "L-V 10:00-18:00"
    └── respuesta_automatica: true
```

---

## ✅ Checklist para cada negocio nuevo

- [ ] Inicializar bot desde la app (menú ⋮ → Inicializar)
- [ ] Configurar mensaje de bienvenida personalizado
- [ ] Configurar horario correcto del negocio
- [ ] Añadir al menos 5 respuestas automáticas
- [ ] Probar el bot simulando mensajes desde la app
- [ ] (Opcional) Conectar WhatsApp Business API
- [ ] Activar notificaciones push para nuevos mensajes

---

## 💡 Consejos

- **Sé específico** en las palabras clave: mejor "cita mañana" que solo "mañana"
- **Añade variantes** de cada palabra: "precio, coste, cuánto, tarifa, vale"
- **Usa emojis** en las respuestas — WhatsApp los muestra perfectamente ✅
- **El fallback** debe dar una alternativa: teléfono o decir que avisas en X minutos
- **Revisa los chats diariamente** al principio para mejorar las respuestas

---

*Generado automáticamente por PlaneaGuada CRM — v1.0*


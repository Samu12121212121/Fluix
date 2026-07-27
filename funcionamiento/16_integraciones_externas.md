# Integraciones Externas

## Google My Business (GMB)

### Qué hace
Conecta la app con el perfil de Google Business del negocio para gestionar reseñas de Google, responder a reviews desde la app y ver métricas de visibilidad en Google Maps.

### Archivos
| Archivo | Rol |
|---------|-----|
| `features/dashboard/pantallas/conectar_google_business_screen.dart` | OAuth2 para conectar cuenta |
| `features/dashboard/pantallas/configurar_google_reviews_screen.dart` | Config de respuestas |
| `features/dashboard/widgets/kpis_rating_widget.dart` | KPIs de valoraciones |
| `features/dashboard/widgets/grafico_evolucion_rating_widget.dart` | Evolución del rating |
| `features/dashboard/widgets/estado_respuesta_widget.dart` | Estado de respuestas pendientes |
| `services/gmb_auth_service.dart` | OAuth2 tokens |
| `services/google_reviews_service.dart` | CRUD de reviews |
| `functions/src/gmbTokens.ts` | Gestión de tokens OAuth2 |
| `functions/src/gmbRespuestas.ts` | Envío de respuestas a GMB |
| `functions/src/gmbSnapshots.ts` | Snapshots periódicos de métricas |

### Flujo
1. El propietario conecta su cuenta Google en `conectar_google_business_screen.dart`
2. `gmbTokens` almacena los tokens OAuth2 en Firestore
3. `gmbSnapshots` hace snapshots diarios de métricas (visitas, clics, llamadas)
4. Las reviews nuevas de Google se muestran en el dashboard
5. El propietario puede responder desde la app → `gmbRespuestas` envía la respuesta via Google Business Profile API

---

## WhatsApp Business API

### Qué hace
Bot de WhatsApp que recibe pedidos, envía confirmaciones de reserva y responde automáticamente a preguntas frecuentes.

### Archivos
| Archivo | Rol |
|---------|-----|
| `features/pedidos/pantallas/` — configurar bot | Configuración desde la app |
| `services/chatbot_service.dart` | Lógica del chatbot en Flutter |
| `domain/modelos/bot_chat.dart` | Modelo de conversación |
| `functions/src/whatsappBot.ts` | Lógica del bot |
| `functions/src/fiscal/prompts/` | (No relacionado con WhatsApp) |

### Webhook: `whatsappWebhook`
- Meta envía mensajes recibidos a este endpoint HTTP
- El bot analiza el mensaje y genera respuesta automática
- Si el cliente escribe "pedido", inicia el flujo de creación de pedido
- Los pedidos creados por WhatsApp tienen `origen: 'whatsapp'`

### Mensajes automáticos enviados
- Confirmación de reserva (con fecha y hora)
- Confirmación de pedido (con número y total)
- Recordatorio de cita 24h antes
- Respuesta a preguntas frecuentes (horarios, precios, ubicación)

---

## Stripe (Pagos)

### Qué hace
Gestión de suscripciones de pago de los negocios que usan Fluix.

### Archivos
| Archivo | Rol |
|---------|-----|
| `services/stripe_service.dart` | Cliente Stripe en Flutter |
| `features/perfil/pantallas/pantalla_configuracion_pagos.dart` | Gestión de método de pago |
| `functions/src/` — stripeWebhook | Webhook de Stripe |

### Flujo
1. El negocio selecciona plan y método de pago
2. Stripe crea `Customer` + `Subscription`
3. `stripeWebhook` recibe eventos:
   - `invoice.payment_succeeded` → actualiza `estado: ACTIVA`
   - `invoice.payment_failed` → alerta al propietario
   - `customer.subscription.deleted` → `estado: VENCIDA`

---

## Google Document AI + Claude API (OCR)

### Qué hace
Extrae automáticamente los datos de facturas de proveedores subidas en PDF: proveedor, número, fecha, líneas, IVA, total.

### Flujo
```
Usuario sube PDF a Firebase Storage
    ↓
Trigger: processInvoice (Cloud Function)
    ↓
ocrPreprocessor.ts → mejora calidad de imagen
    ↓
Google Document AI → extrae texto y estructura del documento
    ↓
Claude API (invoiceExtractionV4.ts) → interpreta el texto y devuelve JSON estructurado
    ↓
invoice_result_screen.dart → muestra resultado para que el usuario confirme o corrija
    ↓
Se guarda en empresas/{empresaId}/facturas_recibidas
```

### Por qué se usa Claude además de Document AI
Document AI extrae texto, pero Claude interpreta el contexto: distingue entre NIF del proveedor y NIF del receptor, identifica el tipo de IVA correcto para cada línea, detecta facturas en varios idiomas, etc.

---

## WordPress

### Qué hace
Integración con webs WordPress del negocio para publicar contenido (blog, páginas) desde la app de Fluix.

### Archivos
| Archivo | Rol |
|---------|-----|
| `services/wordpress_service.dart` | Cliente REST API de WordPress |
| `models/wordpress_data.dart` | Modelos de datos WordPress |
| `features/dashboard/pantallas/tab_blog_web.dart` | Tab de gestión del blog |
| `models/seccion_web.dart` | Modelo de sección web |

---

## Firebase Cloud Messaging (Notificaciones Push)

### Archivos
| Archivo | Rol |
|---------|-----|
| `services/notificaciones_service.dart` | Gestión FCM en Flutter |
| `services/cliente_notificaciones_service.dart` | Push para clientes finales |
| `features/perfil/pantallas/pantalla_sonidos_notificacion.dart` | Config de sonidos |

### Tipos de notificaciones
| Tipo | Cuándo |
|------|--------|
| Nueva reserva | Al recibir reserva online |
| Reserva confirmada | Al confirmar al cliente |
| Nuevo pedido | Al recibir pedido |
| Tarea asignada | Al asignar tarea a empleado |
| Tarea vencida | Cuando vence una tarea |
| Vacaciones aprobadas | Al aprobar/rechazar |
| Flash slot nuevo | Al crear promoción |
| Trofeo desbloqueado | Al desbloquear logro |

### Tokens FCM
- Se guardan en `usuarios/{uid}/fcmTokens` (array, un token por dispositivo)
- Las Cloud Functions leen este array para enviar notificaciones a todos los dispositivos del usuario

---

## Resend (Email transaccional)

### Qué hace
Servicio de email transaccional para: confirmaciones de reserva, envío de facturas, nóminas, recordatorios.

### Archivos
| Archivo | Rol |
|---------|-----|
| `functions/src/resend_service.ts` | Cliente Resend |
| `functions/src/email_service.ts` | Templates HTML de emails |
| `services/email_service.dart` | Invocación desde Flutter |

### Emails enviados
- Confirmación de reserva al cliente
- Recordatorio 24h antes de la cita
- Factura en PDF adjunta
- Nómina mensual al empleado
- Invitación a empleado
- Reset de contraseña
- Finiquito en PDF

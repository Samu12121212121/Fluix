#  Documentación Completa de Notificaciones — Fluix CRM

## Índice
1. [Arquitectura General](#arquitectura)
2. [Canales de Notificación](#canales)
3. [Notificaciones por Módulo](#modulos)
4. [Notificaciones Programadas (Cron)](#cron)
5. [Notificaciones In-App (Cliente Final)](#inapp-cliente)
6. [Flujo Técnico](#flujo)

---

## 1. Arquitectura General {#arquitectura}

```
Evento Firestore → Cloud Function → FCM Push → App (empresa)
                               └──→ Bandeja In-App (notificaciones/{empresaId}/items)
                               └──→ Email Resend (si aplica)
```

**Destinos según el tipo de notificación:**
| Destino | Descripción |
|---|---|
| **FCM Push (empresa)** | Llega a todos los dispositivos registrados de la empresa (`empresas/{id}/dispositivos`) |
| **FCM Push (empleado)** | Llega solo al token del empleado asignado |
| **FCM Push (cliente)** | Llega al token FCM del cliente final (app explorar) |
| **Bandeja In-App** | Documento en `notificaciones/{empresaId}/items` |
| **Email (Resend)** | Se envía via servicio Resend a email_notificaciones del negocio o al cliente |

---

## 2. Canales de Notificación (Android) {#canales}

| Canal ID | Nombre | Prioridad | Uso |
|---|---|---|---|
| `fluixcrm_canal_principal` | Fluix CRM | HIGH | Reservas, pedidos, tareas generales |
| `fluixcrm_resenas_negativas` | Reseñas Negativas | MAX | Valoraciones ≤ umbral configurado |
| `fluixcrm_fiscal` | Fiscal | HIGH | Alertas de certificados, vencimientos |
| `fluix_general` | General | DEFAULT | Mensajes de contacto web |

---

## 3. Notificaciones por Módulo {#modulos}

###  Módulo RESERVAS

#### 3.1 Nueva Reserva creada
- **Trigger**: Documento creado en `empresas/{empresaId}/reservas/{reservaId}`
- **Cloud Function**: `onNuevaReserva`
- **Condición**: Siempre
- **Contenido Push**:
  - Título: ` Nueva Reserva`
  - Cuerpo: `{cliente} · {teléfono} · {N} pers. · {ubicación} — {fecha} · {servicio} · ⚠️ Alérgenos (si aplica)`
- **In-App bandeja**: Sí, en `notificaciones/{empresaId}/items`
- **Email empresa**: Sí, si `origen == "app_cliente" || "web_publica"` (función `onNuevaReservaEmail`)
  - Incluye botones **ACEPTAR** y **RECHAZAR** con token HMAC-SHA256

#### 3.2 Nueva Cita creada
- **Trigger**: Documento creado en `empresas/{empresaId}/citas/{citaId}`
- **Cloud Function**: `onNuevaCita`
- **Contenido Push**:
  - Título: ` Nueva Cita`
  - Cuerpo: `{cliente} — {fecha} · {servicio}`
- **In-App bandeja**: Sí
- **Email empresa**: No (solo reservas con origen app_cliente)

#### 3.3 Reserva Confirmada
- **Trigger**: Documento actualizado en `empresas/{empresaId}/reservas/{reservaId}`, campo `estado` cambia a `"CONFIRMADA"`
- **Cloud Function**: `onReservaConfirmada`
- **Contenido Push (empresa)**:
  - Título: `✅ Reserva Confirmada`
  - Cuerpo: `{cliente} — {fecha} · {servicio}`
- **Email cliente**: Sí, si `email_cliente` está disponible (confirmación de reserva con detalles)
- **In-App bandeja**: Sí

#### 3.4 Reserva Cancelada
- **Trigger**: Documento actualizado en `empresas/{empresaId}/reservas/{reservaId}`, campo `estado` cambia a `"CANCELADA"`
- **Cloud Function**: `onReservaCancelada`
- **Contenido Push (empresa)**:
  - Título: `❌ Reserva Cancelada`
  - Cuerpo: `{cliente} — {fecha} · {servicio}`
- **Email cliente**: Sí, si `email_cliente` está disponible (incluye motivo de cancelación)
- **In-App bandeja**: Sí

#### 3.5 Aceptar/Rechazar reserva por email
- **Trigger**: HTTP GET/POST a `/confirmarReserva` o `/rechazarReserva`
- **Cloud Functions**: `confirmarReserva`, `rechazarReserva`
- **Flujo**: El empresario recibe email → clica enlace → se abre página web de confirmación → cambia estado en Firestore → dispara `onReservaConfirmada`/`onReservaCancelada`
- **Seguridad**: Token HMAC-SHA256 (32 chars) con secreto `RESERVAS_TOKEN_SECRET`

---

###  Módulo CITAS (Recordatorios)

#### 3.6 Recordatorio de cita (24h antes)
- **Trigger**: Scheduler cada 1 hora (cron)
- **Cloud Function**: `enviarRecordatoriosCitas`
- **Condición**: Citas con `fecha_hora` entre 23h y 25h en el futuro, y `recordatorioEnviado != true`
- **Contenido Push (equipo empresa)**:
  - Título: ` Cita mañana`
  - Cuerpo: `{cliente} tiene cita mañana a las {hora}`
- **In-App bandeja**: Sí
- **Marca**: Pone `recordatorioEnviado: true` en la cita

---

###  Módulo PEDIDOS

#### 3.7 Nuevo Pedido
- **Trigger**: Documento creado en `empresas/{empresaId}/pedidos/{pedidoId}`
- **Cloud Function**: `onNuevoPedido`
- **Contenido Push**:
  - Título: ` Nuevo Pedido`
  - Cuerpo: `{cliente} — €{total} (vía {origen})`
- **In-App bandeja**: Sí
- **Factura**: Se genera automáticamente via `onNuevoPedidoGenerarFactura`

#### 3.8 Pedido por WhatsApp
- **Trigger**: Documento creado en `empresas/{empresaId}/pedidos_whatsapp/{pedidoId}`
- **Cloud Function**: `onNuevoPedidoWhatsApp`
- **Contenido Push**:
  - Título: ` Pedido por WhatsApp`
  - Cuerpo: `{cliente} — €{total}`

---

### ⭐ Módulo VALORACIONES

#### 3.9 Nueva Valoración (empresa — desde bandeja empresarial)
- **Trigger**: Documento creado en `empresas/{empresaId}/valoraciones/{valoracionId}`
- **Cloud Function**: `onNuevaValoracion`
- **Lógica**: Lee umbral configurado en `empresas/{id}/configuracion/alertas_resenas` (defecto: 3)
- **Si estrellas ≤ umbral**:
  - Título: `⚠️ Nueva reseña de {N} estrella(s)`
  - Canal: `fluixcrm_resenas_negativas` (MAX priority)
  - iOS: `time-sensitive`
- **Si estrellas > umbral**:
  - Título: `⭐ Nueva reseña positiva`
  - Canal: `fluixcrm_canal_principal`
- **Cuerpo**: `{cliente}: "{comentario (80 chars)...}"`

#### 3.10 Valoración baja en perfil público (módulo explorar)
- **Trigger**: Documento creado en `negocios_publicos/{negocioId}/valoraciones/{valoracionId}`
- **Cloud Function**: `onValoracionBaja`
- **Condición**: `estrellas <= 3`
- **Destino**: FCM a admins del negocio (campo `adminIds` del negocio público)
- **Contenido Push**:
  - Título: `⚠️ Valoración baja recibida`
  - Cuerpo: `{clienteNombre} ha dejado {N}★ en tu negocio`
- **Notificación persistente**: En `usuarios/{adminId}/notificaciones`

#### 3.11 Solicitud de valoración (post-visita al cliente)
- **Trigger**: `reservas/{reservaId}` actualizada, campo `estado` cambia a `"completada"`
- **Cloud Function**: `onReservaCompletada`
- **Destino**: FCM al cliente (`clientes/{clienteId}` → campo `fcmToken`)
- **Contenido Push**:
  - Título: `¿Cómo fue tu visita?`
  - Cuerpo: `Cuéntanos tu experiencia en {negocio.nombre}`
- **Notificación persistente**: En `clientes/{clienteId}/notificaciones`

#### 3.12 Recalcular Rating Fluix
- **Trigger**: Documento escrito/borrado en `negocios_publicos/{negocioId}/valoraciones/{valoracionId}`
- **Cloud Function**: `onValoracionWrite`
- **Acción**: Recalcula `ratingFluix` y `totalValoraciones` en el documento del negocio
- **No envía notificación push** — solo actualiza Firestore

---

###  Módulo TAREAS

#### 3.13 Tarea Asignada
- **Trigger**: Documento creado/actualizado en `empresas/{empresaId}/tareas/{tareaId}`
- **Cloud Function**: `onTareaAsignada`
- **Condición**: `usuario_asignado_id` cambia a un nuevo valor
- **Destino**: FCM al empleado asignado (`usuarios/{uid}` o `empresas/{id}/dispositivos/{uid}`)
- **Verificación**: El empleado debe seguir perteneciendo a la empresa (`empresa_id == empresaId`)
- **Contenido Push**:
  - Título: `Nueva tarea asignada`
  - Cuerpo: `Se te ha asignado: {titulo}`
- **Canal**: `fluixcrm_canal_principal`

#### 3.14 Recordatorio de Tareas Próximas
- **Trigger**: Scheduler cada hora
- **Cloud Function**: `scheduledRecordatoriosTareas`
- **Condición**: Tareas con vencimiento en las próximas 2 horas (no completadas)
- **Contenido Push**: `⏰ Tarea próxima: {titulo}`

#### 3.15 Tareas que Vencen Hoy
- **Trigger**: Scheduler diario a las 09:00 (Europe/Madrid)
- **Cloud Function**: `scheduledTareasVencenHoy`
- **Contenido Push**: ` Tareas de hoy: {N} tarea(s) programada(s) para hoy`

#### 3.16 Nueva Sugerencia
- **Trigger**: Documento creado (ruta de sugerencias de empleados)
- **Cloud Function**: `onNuevaSugerencia`
- **Destino**: Empresa (propietario)
- **Contenido Push**: ` Nueva sugerencia de {empleado}`

---

###  Módulo CONTACTO WEB

#### 3.17 Nuevo Mensaje de Contacto
- **Trigger**: Documento creado en `empresas/{empresaId}/contacto_web/{mensajeId}`
- **Cloud Function**: `onNuevoMensajeContacto`
- **Contenido Push (empresa)**:
  - Título: ` Nuevo mensaje de contacto`
  - Cuerpo: `De: {nombre} — {asunto}`
- **Canal**: `fluix_general`
- **Email empresa**: Sí, si tiene `email_notificaciones`
  - Incluye: nombre, email, teléfono del remitente y texto del mensaje

#### 3.18 Mensaje de Contacto Respondido
- **Trigger**: Documento actualizado en `empresas/{empresaId}/contacto_web/{mensajeId}`, `respondido` cambia de `false` a `true`
- **Cloud Function**: `onMensajeContactoRespondido`
- **Condición**: Debe haber campo `email` del remitente y `respuesta` no vacía
- **Email al visitante**: Sí, envía la respuesta del empresario

---

###  Módulo SUSCRIPCIÓN

#### 3.19 Suscripción por Vencer
- **Trigger**: Scheduler diario (cada 24 horas)
- **Cloud Function**: `verificarSuscripciones`
- **Avisos en: 7, 3 y 1 días antes del vencimiento**:
  - Título: `⚠️ Suscripción por Vencer`
  - Cuerpo: `Tu suscripción vence en {N} día(s). ¡Renueva para continuar!`

#### 3.20 Periodo de Gracia (0–7 días tras vencimiento)
- **Trigger**: Mismo scheduler diario
- **Condición**: `fecha_fin` pasada entre 0 y 7 días, estado `ACTIVA`
- **Aviso único** (`aviso_gracia_enviado`):
  - Título: `⚠️ Suscripción expirada — periodo de gracia`
  - Cuerpo: `Tu suscripción venció hace {N} día(s). Renueva antes de {X} días para no perder acceso.`

#### 3.21 Suscripción Vencida (bloqueo)
- **Trigger**: Mismo scheduler diario
- **Condición**: Más de 7 días tras vencimiento y estado `ACTIVA`
- **Acción**: Cambia estado a `VENCIDA` en Firestore
- **Push**:
  - Título: ` Suscripción Vencida`
  - Cuerpo: `Tu suscripción ha expirado. Renueva en fluixtech.com para seguir usando la app.`

---

###  Módulo FIDELIZACIÓN

#### 3.22 Check-in / Sello de Fidelización
- **Trigger**: `onCheckinFidelizacion` (Firestore)
- **Cloud Function**: exportada desde `fidelizacion.ts`
- **Destino**: Push al cliente

#### 3.23 Canje de Recompensa
- **Trigger**: `onCanjeRecompensa`
- **Notificación**: Confirmación de canje al cliente

---

###  Módulo FISCAL

#### 3.24 Alerta de Certificado por Vencer
- **Cloud Function**: `scheduledAlertaCertificado`
- **Canal**: `fluixcrm_fiscal`
- **Aviso**: Cuando el certificado digital está próximo a expirar

#### 3.25 Alerta Precios Antiguos (Catálogo)
- **Cloud Function**: `scheduledAlertaPreciosAntiguos`
- **Trigger**: Scheduler
- **Condición**: Productos con precio sin actualizar hace más de X tiempo

---

### ️ Google My Business

#### 3.26 Resumen Semanal de Reseñas
- **Cloud Function**: `resumenSemanalResenas`
- **Trigger**: Scheduler semanal
- **Contenido**: Resumen de reseñas de Google de la semana

#### 3.27 Alerta Reseñas Negativas Acumuladas
- **Cloud Function**: `alertaResenasNegativasAcumuladas`
- **Condición**: El negocio acumula N reseñas negativas recientes
- **Canal**: `fluixcrm_resenas_negativas`

---

## 4. Notificaciones Programadas (Cron) {#cron}

| Función | Frecuencia | Hora | Descripción |
|---|---|---|---|
| `enviarRecordatoriosCitas` | Cada 1 hora | — | Recordatorios de citas en las próximas 24h |
| `scheduledRecordatoriosTareas` | Cada 1 hora | — | Tareas vencen en próximas 2h |
| `scheduledTareasVencenHoy` | Diario | 09:00 Madrid | Resumen de tareas del día |
| `scheduledGenerarTareasRecurrentes` | Diario | 06:00 Madrid | Genera tareas periódicas |
| `verificarSuscripciones` | Diario | — | Verificar vencimientos de planes |
| `generarFacturasResumenTpv` | Diario | 23:30 Madrid | Factura resumen TPV automática |
| `scheduledAlertaCertificado` | Scheduled | — | Certificados digitales por vencer |
| `scheduledAlertaPreciosAntiguos` | Scheduled | — | Precios sin actualizar en catálogo |
| `scheduledSincronizarResenas` | Scheduled | — | Sincronizar reseñas desde Google |
| `resumenSemanalResenas` | Semanal | — | Resumen semanal de reseñas GMB |
| `marcarQRsExpirados` | Scheduled | — | Expirar QR de fidelización caducados |
| `verificarCaducidadSellos` | Scheduled | — | Caducar sellos de fidelización inactivos |

---

## 5. Notificaciones In-App (Cliente Final — Módulo Explorar) {#inapp-cliente}

Las notificaciones del cliente final se almacenan en:
```
usuarios/{uid}/notificaciones/{notifId}
```

### Campos del documento:
```json
{
  "titulo": "string",
  "cuerpo": "string",
  "tipo": "reserva_confirmada | reserva_cancelada | reserva_pendiente | promo | info",
  "creado_en": "Timestamp",
  "leida": false
}
```

### Tipos de notificación del cliente:

| Tipo | Icono | Color | Descripción |
|---|---|---|---|
| `reserva_confirmada` | ✅ check_circle | Cian `#00FFC8` | La reserva fue confirmada por el negocio |
| `reserva_cancelada` | ❌ cancel | Rojo `#FF2850` | La reserva fue cancelada |
| `reserva_pendiente` | ⏳ schedule | Rosa `#FF4678` | Reserva pendiente de confirmación |
| `promo` | ️ local_offer | Magenta `#FF3296` | Promoción o flash slot disponible |
| `info` (default) |  notifications | Gris `#B0B3C1` | Información general |

### Badget de notificaciones:
La pantalla explorar muestra en tiempo real el número de notificaciones no leídas en el ícono del campanita, usando `StreamBuilder` que escucha:
```
usuarios/{uid}/notificaciones WHERE leida == false
```

---

## 6. Flujo Técnico Completo {#flujo}

### Registro de dispositivo:
```
App abre → NotificacionesService.init() → getToken() FCM
         → Guarda token en:
           · usuarios/{uid}.token_dispositivo
           · empresas/{empresaId}/dispositivos/{uid}.token
```

### Envío de Push (empresa):
```
Cloud Function → obtenerTokensEmpresa(empresaId)
              → Busca en empresas/{id}/dispositivos WHERE activo == true
              → Fallback: busca en usuarios WHERE empresa_id == empresaId
              → messaging.sendEachForMulticast([tokens])
              → Si token inválido → marca activo=false en dispositivos
```

### Push a empleado individual:
```
Cloud Function → Lee token de empresas/{id}/dispositivos/{uid} o usuarios/{uid}
              → Verifica que usuario.empresa_id == empresaId (seguridad)
              → messaging.send({token})
```

### Relación entre Push FCM e In-App:
Muchas funciones hacen **ambas cosas** simultáneamente:
1. Guarda documento en `notificaciones/{empresaId}/items` → aparece en bandeja in-app
2. Envía FCM push → aparece en la barra de notificaciones del teléfono

Esto garantiza que aunque la app esté cerrada, el mensaje llegue por push y al abrirla aparezca en la bandeja.

---

## 7. Configuración por Empresa

### Umbral de Alertas de Reseñas:
```
empresas/{empresaId}/configuracion/alertas_resenas
  umbral_alerta: number (defecto: 3)
```

### Resumen Diario TPV:
```
empresas/{empresaId}/configuracion/...
  modo: "resumenDiario"
  generar_automaticamente: true
```

---

*Documentación generada automáticamente — Fluix CRM v2026*

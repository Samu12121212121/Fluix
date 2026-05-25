# 📊 Diagrama de Flujo: Sistema de Reservas B2C

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            CLIENTE (APP B2C)                                 │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ 1. Explorar negocios
                                    ▼
                        ┌───────────────────────┐
                        │  Pantalla Explorar    │
                        │  - Busca negocios     │
                        │  - Filtra por cat.    │
                        └───────────────────────┘
                                    │
                                    │ 2. Selecciona negocio
                                    ▼
                        ┌───────────────────────┐
                        │  Detalle Negocio      │
                        │  ┌─────────────────┐  │
                        │  │ TabBar (6 tabs) │  │
                        │  ├─────────────────┤  │
                        │  │ ⚡ Reservar      │◄─────── ¡ARREGLADO! Ocupa todo ancho
                        │  │ Info            │  │
                        │  │ Reseñas         │  │
                        │  │ Servicios       │  │
                        │  │ Galería         │  │
                        │  │ Política        │  │
                        │  └─────────────────┘  │
                        └───────────────────────┘
                                    │
                                    │ 3. Click en tab "Reservar"
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       FLUJO DE RESERVA (5 PASOS)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PASO 1: Seleccionar Servicio                                               │
│  ┌────────────────────────────────────────┐                                 │
│  │  StreamBuilder                         │                                 │
│  │  ➜ empresas/{id}/servicios ◄──────────────┐                             │
│  │                                        │   │                             │
│  │  🔄 Sincronizado con módulo owner     │   │                             │
│  │  ✂️ Servicios desde CSV importados    │   │                             │
│  │                                        │   │                             │
│  │  Cards:                                │   │                             │
│  │  ┌──────────────────┐                 │   │                             │
│  │  │ ✂️ Corte y color │  €25 • 60min   │   │                             │
│  │  │ Por ejemplo      │  [Reservar]     │   │                             │
│  │  └──────────────────┘                 │   │                             │
│  └────────────────────────────────────────┘   │                             │
│                 │                              │                             │
│                 │ Click "Reservar"             │                             │
│                 ▼                              │                             │
│                                                │                             │
│  PASO 2: Calendario con Carga                 │                             │
│  ┌────────────────────────────────────────┐   │                             │
│  │  Mayo 2026                             │   │                             │
│  │  L  M  X  J  V  S  D                   │   │                             │
│  │                 1  2  3                │   │                             │
│  │  4  5  6  7  8  9 10                   │   │                             │
│  │ 11 12 13 14 15 16 17                   │   │                             │
│  │ ...                                    │   │                             │
│  │                                        │   │                             │
│  │  Indicador de carga:                   │   │                             │
│  │  🟢 Libre (0 reservas)                 │   │                             │
│  │  🟡 Poco trabajo (1-4)                 │   │                             │
│  │  🟠 Algo ocupado (5-9)                 │   │                             │
│  │  🔴 Muy ocupado (10+)                  │   │                             │
│  └────────────────────────────────────────┘   │                             │
│                 │                              │                             │
│                 │ Selecciona día               │                             │
│                 ▼                              │                             │
│                                                │                             │
│  PASO 3: Seleccionar Hora                     │                             │
│  ┌────────────────────────────────────────┐   │                             │
│  │  Mañana:                               │   │                             │
│  │  [09:00] [09:30] [10:00] [10:30] ...   │   │                             │
│  │                                        │   │                             │
│  │  Tarde:                                │   │                             │
│  │  [16:00] [16:30] [17:00] [17:30] ...   │   │                             │
│  │                                        │   │                             │
│  │  ❌ Horas pasadas deshabilitadas        │   │                             │
│  └────────────────────────────────────────┘   │                             │
│                 │                              │                             │
│                 │ Selecciona hora              │                             │
│                 ▼                              │                             │
│                                                │                             │
│  PASO 4: Seleccionar Profesional              │                             │
│  ┌────────────────────────────────────────┐   │                             │
│  │  StreamBuilder                         │   │                             │
│  │  ➜ usuarios ◄────────────────────────────┐ │                             │
│  │    where('empresa_id' == empresaId)    │ │ │                             │
│  │    where('activo' == true)             │ │ │                             │
│  │                                        │ │ │                             │
│  │  🔄 Empleados reales del sistema       │ │ │                             │
│  │                                        │ │ │                             │
│  │  Cards:                                │ │ │                             │
│  │  ┌────────────────────┐                │ │ │                             │
│  │  │ 🔀 Cualquier prof. │ Auto-asignación│ │ │                             │
│  │  └────────────────────┘                │ │ │                             │
│  │  ┌────────────────────┐                │ │ │                             │
│  │  │ 👨 María García    │ Estilista      │ │ │                             │
│  │  └────────────────────┘                │ │ │                             │
│  │  ┌────────────────────┐                │ │ │                             │
│  │  │ 👨 Juan López      │ Barbero        │ │ │                             │
│  │  └────────────────────┘                │ │ │                             │
│  └────────────────────────────────────────┘ │ │                             │
│                 │                            │ │                             │
│                 │ Selecciona profesional     │ │                             │
│                 ▼                            │ │                             │
│                                              │ │                             │
│  PASO 5: Confirmación                       │ │                             │
│  ┌────────────────────────────────────────┐ │ │                             │
│  │  Resumen:                              │ │ │                             │
│  │  ┌──────────────────────────────────┐  │ │ │                             │
│  │  │ ✂️ Corte y color                 │  │ │ │                             │
│  │  │ Peluquería Ejemplo               │  │ │ │                             │
│  │  ├──────────────────────────────────┤  │ │ │                             │
│  │  │ 📅 lunes, 25 de mayo             │  │ │ │                             │
│  │  │ 🕐 16:30                         │  │ │ │                             │
│  │  │ 👨 María García                  │  │ │ │                             │
│  │  │ ⏱️ 60 minutos                    │  │ │ │                             │
│  │  ├──────────────────────────────────┤  │ │ │                             │
│  │  │ Total           €25.00           │  │ │ │                             │
│  │  └──────────────────────────────────┘  │ │ │                             │
│  │                                        │ │ │                             │
│  │  [✓ Confirmar Reserva]                 │ │ │                             │
│  └────────────────────────────────────────┘ │ │                             │
│                 │                            │ │                             │
│                 │ Click Confirmar            │ │                             │
│                 ▼                            │ │                             │
└─────────────────────────────────────────────────┴─┴─────────────────────────┘
                  │
                  │ Firestore Transaction
                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FIRESTORE DATABASE                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  (1) Crear reserva                                                           │
│  ➜ empresas/{empresaId}/reservas/{reservaId}                                │
│  {                                                                           │
│    cliente_uid: "...",                                                       │
│    cliente_nombre: "Cliente Ejemplo",                                       │
│    cliente_email: "cliente@email.com",                                      │
│    servicio_id: "...",                                                       │
│    servicio_nombre: "Corte y color",                                        │
│    empleado_id: "...",              ◄─────── ID real del empleado           │
│    empleado_nombre: "María García",                                         │
│    fecha_hora: Timestamp(2026-05-25 16:30),                                 │
│    duracion: 60,                                                             │
│    precio: 25.00,                                                            │
│    estado: "pendiente",             ◄─────── ¡IMPORTANTE! Owner debe aprobar│
│    origen: "fluix_b2c",                                                      │
│    fecha_creacion: Timestamp.now()                                           │
│  }                                                                           │
│                                                                              │
│  (2) Crear notificación                                                      │
│  ➜ empresas/{empresaId}/notificaciones_reservas/{notifId}                   │
│  {                                                                           │
│    reserva_id: "{reservaId}",                                               │
│    tipo: "nueva_reserva_b2c",                                               │
│    cliente_nombre: "Cliente Ejemplo",                                       │
│    servicio_nombre: "Corte y color",                                        │
│    fecha_hora: Timestamp(2026-05-25 16:30),                                 │
│    leida: false,                                                             │
│    fecha_creacion: Timestamp.now()                                           │
│  }                                                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                  │
                  │ Firestore Trigger
                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CLOUD FUNCTION                                       │
│                    notificarNuevaReserva                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  (1) Detectar nueva notificación                                             │
│      onCreate /empresas/.../notificaciones_reservas/{id}                    │
│                                                                              │
│  (2) Obtener datos empresa                                                   │
│      ➜ empresas/{empresaId}                                                 │
│      email_notificaciones: "negocio@email.com"                              │
│                                                                              │
│  (3) Obtener datos completos reserva                                         │
│      ➜ empresas/{empresaId}/reservas/{reservaId}                            │
│                                                                              │
│  (4) Construir email HTML profesional                                        │
│      - Header con gradiente #00FFC8                                          │
│      - Card con todos los datos                                              │
│      - Badge "Pendiente de confirmación"                                     │
│      - Botón CTA "Ver en Fluix CRM"                                          │
│                                                                              │
│  (5) Enviar email con Nodemailer/Sendgrid                                    │
│      From: Fluix CRM <noreply@fluix.app>                                    │
│      To: negocio@email.com                                                  │
│      Subject: "📅 Nueva reserva de [Cliente] - [Fecha]"                     │
│                                                                              │
│  (6) Marcar notificación como enviada                                        │
│      email_enviado: true                                                     │
│      email_enviado_en: Timestamp.now()                                       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                  │
                  │ SMTP
                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      EMAIL A OWNER/ADMIN                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  De: Fluix CRM <noreply@fluix.app>                                          │
│  Para: negocio@email.com                                                    │
│  Asunto: 📅 Nueva reserva de Cliente Ejemplo - lunes, 25 de mayo            │
│                                                                              │
│  ╔══════════════════════════════════════════════════════════════╗           │
│  ║          📅 Nueva Reserva Pendiente                          ║           │
│  ╚══════════════════════════════════════════════════════════════╝           │
│                                                                              │
│  Hola Peluquería Ejemplo,                                                   │
│                                                                              │
│  Has recibido una nueva solicitud de reserva desde Fluix:                   │
│                                                                              │
│  ┌────────────────────────────────────────────────────┐                     │
│  │ 👤 Cliente: Cliente Ejemplo                        │                     │
│  │    cliente@email.com                               │                     │
│  │                                                     │                     │
│  │ ✂️ Servicio: Corte y color                         │                     │
│  │ 📅 Fecha: lunes, 25 de mayo de 2026                │                     │
│  │ 🕐 Hora: 16:30                                      │                     │
│  │ 👨‍💼 Profesional: María García                       │                     │
│  │ ⏱️ Duración: 60 minutos                             │                     │
│  │ 💰 Precio: €25.00                                   │                     │
│  │                                                     │                     │
│  │        ⏳ Pendiente de confirmación                 │                     │
│  └────────────────────────────────────────────────────┘                     │
│                                                                              │
│          [ Ver en Fluix CRM → ]                                              │
│                                                                              │
│  ⚡ ACCIÓN REQUERIDA: Accede a tu panel de owner para                        │
│  confirmar o rechazar esta reserva. El cliente recibirá                     │
│  una notificación de tu decisión.                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                  │
                  │ Owner abre app
                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OWNER/ADMIN (APP OWNER)                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Módulo "Reservas"                                                           │
│  ➜ lib/features/reservas/pantallas/modulo_reservas_screen.dart              │
│                                                                              │
│  Lista de Reservas:                                                          │
│  ┌──────────────────────────────────────────────────────┐                   │
│  │ 🟡 PENDIENTE                                         │                   │
│  │ Cliente Ejemplo                                      │                   │
│  │ Corte y color • María García                         │                   │
│  │ 25 Mayo 16:30 • €25.00                               │                   │
│  │ [✓ Confirmar]  [✗ Cancelar]  [📝 Editar]            │                   │
│  └──────────────────────────────────────────────────────┘                   │
│                                                                              │
│  Opciones:                                                                   │
│  1. ✅ CONFIRMAR → estado: "confirmada" (color verde)                        │
│  2. ❌ CANCELAR → modal pide motivo → estado: "cancelada" (color rojo)      │
│  3. 📝 EDITAR → cambiar fecha/hora/profesional                               │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                  │
                  │ Click "Confirmar"
                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          FIRESTORE UPDATE                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ➜ empresas/{empresaId}/reservas/{reservaId}                                │
│  {                                                                           │
│    ...datos anteriores...,                                                   │
│    estado: "confirmada",            ◄─────── Cambio de estado                │
│    confirmada_por: "adminId",                                               │
│    confirmada_en: Timestamp.now(),                                           │
│    modificado_en: Timestamp.now()                                            │
│  }                                                                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                  │
                  │ (Opcional) Push Notification
                  ▼
            Cliente recibe notificación:
            "✅ Tu reserva ha sido confirmada"


═══════════════════════════════════════════════════════════════════════════════

SEGURIDAD (Firestore Rules):

✅ Cliente SOLO puede:
   - Crear reservas con estado "pendiente"
   - Leer sus propias reservas
   - NO puede modificar ni eliminar

✅ Owner/Admin puede:
   - Leer TODAS las reservas de su empresa
   - Modificar estado (pendiente → confirmada/cancelada)
   - Editar fecha/hora/profesional
   - NO puede eliminar (solo cancelar)

✅ Notificaciones:
   - SOLO owner puede leer
   - Cliente puede crear (trigger automático)
   - Owner puede marcar como leída

═══════════════════════════════════════════════════════════════════════════════

SINCRONIZACIÓN:

📊 empresas/{id}/servicios ◄──┬──► Módulo Owner (importa CSV)
                               │
                               └──► Tab Reservar B2C (muestra servicios)

👥 usuarios (empresa_id: ...) ◄──┬──► Sistema de fichajes/nóminas
                                  │
                                  └──► Selección de profesional

📅 empresas/{id}/reservas ◄───────┬──► Creadas desde B2C
                                  │
                                  └──► Gestionadas desde Owner

═══════════════════════════════════════════════════════════════════════════════

MÉTRICAS CLAVE:

⏱️  Tiempo de respuesta cliente: < 2s
📧 Emails enviados: 95-100%
✅ Tasa de confirmación: > 80%
⏰ Tiempo medio confirmación: < 2 horas
🔄 Sincronización datos: Real-time (Firestore Streams)

═══════════════════════════════════════════════════════════════════════════════
```

*Última actualización: 25 Mayo 2026*


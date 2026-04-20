# Módulos de Reservas, Citas y WhatsApp — Cómo funcionan

> Versión: Fluix CRM · Abril 2026

---

## 1. Módulo de Reservas

### ¿Qué hace?
Gestiona las **reservas de servicios** que hacen los clientes (peluquería, masajes, tratamientos, etc.).  
Cada reserva tiene cliente, servicio, fecha/hora, duración, precio y estado.

### Flujo de una reserva
```
Cliente solicita (web o app) → Reserva PENDIENTE
              ↓
Admin confirma → Reserva CONFIRMADA
              ↓
Se realiza el servicio → Reserva COMPLETADA
              ↓ (opcional)
Se cancela → Reserva CANCELADA
```

### Estados disponibles
| Estado | Significado |
|---|---|
| `PENDIENTE` | Esperando confirmación del negocio |
| `CONFIRMADA` | Aceptada, aparece en el calendario |
| `COMPLETADA` | El servicio ya se prestó |
| `CANCELADA` | Cancelada por el cliente o el negocio |

> **Nota sobre mayúsculas/minúsculas:** La app normaliza internamente con `.toUpperCase()` al filtrar, por lo que acepta `pendiente`, `PENDIENTE` o `Pendiente` sin problemas. La convención es guardar siempre en MAYÚSCULAS en Firestore.

### Dónde están los datos en Firestore
```
empresas/{empresaId}/reservas/{reservaId}
  ├── cliente_nombre
  ├── cliente_telefono
  ├── servicio
  ├── fecha          (Timestamp)
  ├── duracion       (minutos)
  ├── precio
  ├── estado         ('PENDIENTE' | 'CONFIRMADA' | 'COMPLETADA' | 'CANCELADA')
  ├── notas
  └── fecha_creacion
```

### Pantallas implicadas
- **`modulo_reservas.dart`** → lista principal con 5 tabs: Calendario, Pendientes, Confirmadas, Canceladas, Todas
- **`widget_proximos_dias.dart`** → muestra las reservas de hoy y mañana en el dashboard
- El formulario de crear/editar está inline en `modulo_reservas.dart`

### Integración con otros módulos
- Las reservas se reflejan en **Estadísticas** (ingresos previstos, ocupación) vía `EstadisticasTriggerService`
- Si el cliente tiene ficha en **Clientes**, se vincula automáticamente
- El módulo **Valoraciones** puede pedir reseña tras completar una reserva

---

## 2. Módulo de Citas

### ¿Qué hace?
Gestiona **citas con clientes** de forma similar a las reservas, pero orientado a negocios donde se gestionan turnos y horarios de empleados (clínicas, consultas, centros de estética).

> **Diferencia clave con Reservas:**
> - Reservas → cliente elige servicio + fecha
> - Citas → se asigna también **empleado/profesional** responsable

### Implementación técnica
El módulo de Citas **reutiliza el mismo widget `ModuloReservas`** pero con parámetros diferentes:
```dart
ModuloReservas(
  empresaId: empresaId,
  collectionId: 'citas',           // ← colección diferente
  moduloSingular: 'Cita',
  moduloPlural: 'Citas',
  mostrarProfesional: true,        // ← muestra selector de empleado
)
```

### Campos específicos de una cita en Firestore
```
empresas/{empresaId}/citas/{citaId}
  ├── cliente_nombre
  ├── cliente_telefono
  ├── servicio
  ├── empleado_id        ← empleado asignado
  ├── empleado_nombre
  ├── fecha              (Timestamp)
  ├── duracion           (minutos)
  ├── precio
  ├── estado             ('PENDIENTE' | 'CONFIRMADA' | 'COMPLETADA' | 'CANCELADA')
  ├── notas
  └── fecha_creacion
```

### Widget en el dashboard
El **`widget_proximos_dias.dart`** muestra tanto Reservas como Citas unificadas en la vista "Próximos días", ordenadas por hora.

---

## 3. Módulo de WhatsApp (Pedidos y Bot)

Este módulo tiene **tres partes diferenciadas**:

---

### 3.1 Gestión de Pedidos por WhatsApp

#### ¿Qué hace?
Permite recibir, ver y gestionar los pedidos que llegan por WhatsApp. Ideal para negocios de hostelería, comida para llevar, etc.

#### Flujo de un pedido
```
Cliente envía mensaje → Pedido NUEVO
        ↓
Negocio lo ve → Estado VISTO
        ↓
Se empieza a preparar → EN PROCESO
        ↓
Listo para entregar → LISTO
        ↓
Cliente recibe → ENTREGADO
              (o → CANCELADO)
```

#### Estructura en Firestore
```
empresas/{empresaId}/pedidos_whatsapp/{pedidoId}
  ├── cliente_nombre
  ├── cliente_telefono
  ├── mensaje_original       ← texto raw del WhatsApp
  ├── pedido_resumen         ← resumen generado por el bot (opcional)
  ├── items[]                ← lista de productos detectados
  │     ├── nombre
  │     ├── cantidad
  │     └── precio
  ├── total_estimado
  ├── estado                 (nuevo/visto/en_proceso/listo/entregado/cancelado)
  ├── fecha                  (Timestamp)
  ├── empresaId              ← necesario para las reglas de Firestore
  └── timestamp              ← ídem
```

> ⚠️ Los campos `empresaId` y `timestamp` son obligatorios para que las reglas de Firestore permitan la escritura cuando el usuario no es admin.

#### Pantalla principal
`modulo_whatsapp_screen.dart` muestra pestañas por estado: Todos, Nuevos, Proceso, Listos, Entregados + Bot.

---

### 3.2 Bot de WhatsApp (local / datos de prueba)

Permite probar el bot en la app con datos simulados.

- **Pantalla**: `pantalla_chats_bot.dart` → lista de conversaciones activas del bot
- **Servicio**: `chatbot_service.dart` → lógica del bot local
- **Configuración local**: `PantallaConfigBot` (dentro del mismo archivo) → mensajes de bienvenida, fallback, horario

---

### 3.3 Bot de WhatsApp con IA — WhatsApp Cloud API (Meta) + Claude

#### Arquitectura multiempresa
```
Cliente envía mensaje por WhatsApp
        ↓
Meta llama al webhook: /whatsappWebhook (Cloud Function única)
        ↓
La función busca empresa por phone_number_id en Firestore
        ↓
Carga instrucciones personalizadas del bot de esa empresa
        ↓
Llama a Claude (claude-sonnet-4-20250514) con el contexto + historial
        ↓
Guarda mensaje + respuesta en empresas/{empresaId}/chats_bot/{chatId}/mensajes/
        ↓
Responde al cliente via WhatsApp Cloud API
        ↓
Si el bot dice "Te paso con el equipo" → marca chat como derivado
```

#### Configuración por empresa en Firestore
```
empresas/{empresaId}/configuracion/whatsapp_bot
  ├── phone_number_id      ← ID del número en Meta
  ├── access_token         ← token permanente de Meta (encriptado)
  ├── verify_token         ← token para verificar webhook
  ├── activo               ← true/false
  ├── instrucciones_bot    ← personalidad y reglas del bot
  ├── nombre_negocio       ← para el system prompt
  ├── sector               ← hostelería, peluquería, etc.
  ├── derivar_si_no_sabe   ← true/false
  └── ultima_actualizacion
```

#### Chats del bot en Firestore
```
empresas/{empresaId}/chats_bot/{chatId}
  ├── cliente_nombre
  ├── cliente_telefono
  ├── estado                 (activo / derivado / resuelto)
  ├── fecha_creacion
  ├── fecha_ultimo_mensaje
  ├── total_mensajes
  └── mensajes/ (subcolección)
        └── {msgId}
              ├── texto
              ├── es_bot      (true/false)
              ├── timestamp
              └── nombre
```

#### Cloud Function: `whatsappWebhook`
- **Archivo**: `functions/src/whatsappBot.ts`
- **Exportada en**: `functions/src/index.ts`
- **URL**: `https://europe-west1-planeaapp-4bea4.cloudfunctions.net/whatsappWebhook`
- **GET**: Verificación de Meta (compara `hub.verify_token` con el guardado en Firestore)
- **POST**: Recibe mensajes, busca empresa por `phone_number_id`, procesa con Claude, responde

#### Pantalla de configuración en Flutter
- **Archivo**: `lib/features/pedidos/pantallas/configurar_bot_whatsapp_screen.dart`
- **Acceso**: Bot WhatsApp → menú ⋮ → "WhatsApp API (Meta)"
- **Campos**: phone_number_id, access_token (con toggle), verify_token, instrucciones, nombre negocio, sector, switch activo, switch derivar

#### Cómo configurar una empresa nueva
1. La empresa se registra en [Meta for Developers](https://developers.facebook.com) y crea una app de WhatsApp Business
2. En Meta, configura el webhook con la URL de arriba y el verify_token que elija
3. En Fluix → Bot WhatsApp → ⋮ → "WhatsApp API (Meta)":
   - Pega el `phone_number_id` (lo encuentra en API Setup de Meta)
   - Pega el `access_token` permanente
   - Pega el `verify_token` (el mismo que puso en Meta)
   - Escribe las instrucciones personalizadas
   - Activa el switch
4. Listo — los clientes que escriban a ese número serán respondidos por Claude con el contexto de esa empresa

---

## 4. Reglas de Firestore para estos módulos

```javascript
// Reservas y Citas
match /reservas/{id} { allow read, write: if puedeVerModulo(empresaId, 'reservas'); }
match /citas/{id}    { allow read, write: if puedeVerModulo(empresaId, 'citas'); }

// Pedidos WhatsApp
match /pedidos_whatsapp/{id} {
  allow read: if puedeVerModulo(empresaId, 'pedidos')
              || puedeVerModulo(empresaId, 'whatsapp')
              || esAdminOPropietario(empresaId);
  allow create: if esAdminOPropietario(empresaId)
    || ((puedeVerModulo(empresaId, 'pedidos') || puedeVerModulo(empresaId, 'whatsapp'))
      && request.resource.data.keys().hasAll(['empresaId', 'timestamp'])
      && request.resource.data.empresaId == empresaId);
  allow update, delete: if esAdminOPropietario(empresaId);
}

// Chats del bot WhatsApp
match /chats_bot/{chatId} {
  allow read, write: if esAdminOPropietario(empresaId);
  match /mensajes/{msgId} {
    allow read, write: if esAdminOPropietario(empresaId);
  }
}
```

---

## 5. Activar/Desactivar módulos desde la app

**Dashboard → Ajustes (tuerca) → Configuración → sección de módulos**

### Dónde se guardan los módulos activos
```
empresas/{empresaId}/configuracion/modulos
  └── modulos: [
        { "id": "reservas",  "activo": true },
        { "id": "citas",     "activo": false },
        { "id": "whatsapp",  "activo": true },
        ...
      ]
```

### Cómo funciona
1. El checkbox de cada módulo en la pantalla de configuración llama a `WidgetManagerService.toggleModulo()`
2. Esto escribe en `empresas/{id}/configuracion/modulos`
3. `pantalla_dashboard.dart` escucha el stream `obtenerTodosModulos(empresaId)` y filtra solo `activo == true`
4. Si desactivas un módulo, desaparece del tab bar en el próximo ciclo del StreamBuilder

### Módulos que siempre están activos (no se pueden desactivar)
- `dashboard`
- `valoraciones`

---

## 6. Resumen de módulos disponibles

| ID | Nombre | Plan | Descripción |
|---|---|---|---|
| `dashboard` | Dashboard | Básico (siempre activo) | Pantalla principal con widgets |
| `valoraciones` | Valoraciones | Básico (siempre activo) | Reseñas de Google |
| `estadisticas` | Estadísticas | Básico | Métricas del negocio |
| `reservas` | Reservas | Básico | Gestión de reservas de servicios |
| `citas` | Citas | Básico | Citas con asignación de profesional |
| `facturacion` | Facturación | Básico | Facturas, presupuestos |
| `clientes` | Clientes | Básico | CRM de clientes |
| `empleados` | Empleados | Básico | Gestión de empleados |
| `nominas` | Nóminas | Básico | Cálculo de nóminas |
| `tareas` | Tareas | Básico | Gestión de tareas |
| `pedidos` | Pedidos WhatsApp | Gestión | Pedidos desde WhatsApp |
| `whatsapp` | Bot WhatsApp | Gestión | Bot IA para WhatsApp |
| `web` | Contenido Web | Add-on | Gestión del sitio web |

---

## 7. Archivos clave

| Archivo | Qué hace |
|---|---|
| `lib/features/dashboard/widgets/modulo_reservas.dart` | Widget principal de Reservas Y Citas (reutilizable) |
| `lib/features/dashboard/widgets/modulo_citas.dart` | Wrapper que instancia `ModuloReservas` con `collectionId: 'citas'` |
| `lib/features/dashboard/widgets/widget_proximos_dias.dart` | Widget del dashboard con las próximas reservas/citas |
| `lib/features/pedidos/pantallas/modulo_whatsapp_screen.dart` | Pantalla principal de pedidos WhatsApp |
| `lib/features/pedidos/pantallas/pantalla_chats_bot.dart` | Lista de chats del bot + config local |
| `lib/features/pedidos/pantallas/configurar_bot_whatsapp_screen.dart` | Config de credenciales Meta + instrucciones IA |
| `lib/services/chatbot_service.dart` | Servicio del bot local |
| `lib/services/widget_manager_service.dart` | Gestión de módulos activos/inactivos |
| `functions/src/whatsappBot.ts` | Cloud Function webhook + procesamiento IA |
| `lib/features/dashboard/pantallas/configuracion_dashboard_screen.dart` | Pantalla de activar/desactivar módulos |


# ✅ NOTIFICACIONES PUSH - Reservas Web Damajuana

## 🔔 **Sistema de Notificaciones Ya Implementado**

Las notificaciones push para reservas web **YA ESTÁN programadas** en la Cloud Function `onNuevaReserva`.

### 📍 **Ubicación del Código**

**Archivo:** `functions/src/index.ts`

**Funciones relevantes:**
```
Línea 471-487:  onNuevaReserva()         - Trigger cuando se crea reserva
Línea 379-466:  procesarNuevaReservaOCita() - Procesa y envía notificación
Línea 291-377:  enviarNotificacionEmpresa()  - Envía push FCM
Línea 242-289:  obtenerTokensEmpresa()      - Obtiene tokens de dispositivos
```

## 🚀 **Cómo Funciona**

### 1. Usuario envía reserva web → Firestore
```
Formulario web → empresas/{empresaId}/reservas/{reservaId}
```

### 2. Cloud Function se dispara automáticamente
```typescript
// functions/src/index.ts línea 471
export const onNuevaReserva = onDocumentCreated(
  { document: "empresas/{empresaId}/reservas/{reservaId}" },
  async (event) => {
    await procesarNuevaReservaOCita(...);
  }
);
```

### 3. Procesamiento de la notificación
```typescript
// Línea 379 - procesarNuevaReservaOCita()
async function procesarNuevaReservaOCita(...) {
  // 1. Extraer datos de la reserva
  const cliente = reserva.nombre_cliente || "Cliente";
  const telefono = reserva.telefono_cliente;
  const personas = reserva.numero_personas;
  const ubicacion = reserva.ubicacion || reserva.zona;
  const alergenos = reserva.alergenos;
  const fechaHora = reserva.fecha_hora;
  
  // 2. Construir mensaje
  const titulo = "📅 Nueva Reserva";
  const cuerpo = `${cliente} · ${telefono} · ${personas} pers. · ${ubicacion} — ${fechaHora}`;
  
  // 3. Guardar en bandeja in-app
  await db.collection("notificaciones")
          .doc(empresaId)
          .collection("items")
          .add({
            titulo,
            cuerpo,
            tipo: "reservaNueva",
            timestamp: FieldValue.serverTimestamp(),
            leida: false,
            modulo_destino: "reservas",
            entidad_id: reservaId,
            remitente_nombre: cliente,
            remitente_telefono: telefono,
            remitente_email: email,
            ubicacion,
            personas,
            alergenos,
          });
  
  // 4. Enviar notificación push
  await enviarNotific acionEmpresa(empresaId, titulo, cuerpo, {
    tipo: "nueva_reserva",
    reserva_id: reservaId,
    coleccion: "reservas"
  });
}
```

### 4. Envío de Push Notification
```typescript
// Línea 291 - enviarNotificacionEmpresa()
async function enviarNotificacionEmpresa(...) {
  // 1. Obtener tokens FCM de todos los dispositivos
  const tokens = await obtenerTokensEmpresa(empresaId);
  
  // 2. Enviar multicast push
  await messaging.sendEachForMulticast({
    tokens,
    notification: {
      title: "📅 Nueva Reserva",
      body: "Juan Pérez · +34 600 000 000 · 4 pers. · Terraza — 27/05/2026 14:00"
    },
    data: {
      empresa_id: empresaId,
      tipo: "nueva_reserva",
      reserva_id: "abc123...",
      coleccion: "reservas"
    },
    android: {
      priority: "high",
      notification: {
        channelId: "fluixcrm_canal_principal",
        sound: "default"
      }
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1
        }
      }
    }
  });
}
```

## 📱 **Cómo se Ve en la App**

### Notificación Push (Pantalla bloqueada)
```
┌─────────────────────────────────────┐
│  📅 Nueva Reserva              FLUIX│
│  Juan Pérez · +34 600... · 4 pers.  │
│  🌿 Terraza — 27/05/2026 14:00      │
└─────────────────────────────────────┘
```

### Bandeja de Notificaciones (In-App)
```
┌─────────────────────────────────────┐
│  📅 Nueva Reserva          🔵 Nueva │
│  Juan Pérez · +34 600... · 4 pers.  │
│  🌿 Terraza — 27/05/2026 14:00      │
│  ⚠️ Alergias: Gluten, lactosa       │
│  💬 Notas: Celebración cumpleaños   │
│  ⏰ Hace 2 minutos                  │
└─────────────────────────────────────┘
```

## 🎯 **Qué Incluye la Notificación**

### Datos Básicos
- ✅ **Nombre del cliente**
- ✅ **Teléfono**
- ✅ **Email** (si lo proporcionó)
- ✅ **Fecha y hora de la reserva**

### Datos de Restaurante (Damajuana)
- ✅ **Número de personas**
- ✅ **Zona** (Salón 🏠 o Terraza 🌿)
- ✅ **Alergias** (⚠️ si las tiene + detalles)
- ✅ **Comentarios** (ocasión especial, peticiones)

### Datos de Peluquería/Spa (si aplica)
- ✅ **Servicio solicitado**
- ✅ **Profesional** (si se seleccionó)
- ✅ **Duración**
- ✅ **Precio**

## 📊 **Tokens de Dispositivos**

La función obtiene tokens FCM de dos fuentes:

### 1. Colección `empresas/{empresaId}/dispositivos`
```typescript
{
  token: "fGx7k2...",
  uid_usuario: "user123",
  activo: true,
  ultima_actualizacion: Timestamp
}
```

### 2. Fallback: Colección `usuarios`
```typescript
{
  empresa_id: empresaId,
  token_dispositivo: "fGx7k2...",
  activo: true
}
```

Si encuentra tokens en `usuarios` pero no en `dispositivos`, **sincroniza automáticamente**.

## ⚙️ **Canal de Notificaciones Android**

**ID:** `fluixcrm_canal_principal`
**Nombre:** Fluix CRM
**Importancia:** MAX
**Sonido:** ✅ Sí (default)
**Vibración:** ✅ Sí
**Badge:** ✅ Sí

Configurado en: `lib/services/notificaciones_service.dart` (línea 46-54)

## 🔧 **DESPLIEGUE**

### Opción 1: Script Automático
```bash
desplegar_push_reservas.bat
```

### Opción 2: Comando Manual
```bash
# 1. Desplegar reglas
firebase deploy --only firestore:rules

# 2. Desplegar función
firebase deploy --only functions:onNuevaReserva
```

## 🧪 **PRUEBA**

### 1. Enviar Reserva de Prueba
```
URL: https://damajuanaguadalajara.site
Datos:
- Nombre: Test Usuario
- Teléfono: +34 600 000 000
- Email: test@test.com
- Fecha: Mañana
- Hora: 14:00
- Personas: 4
- Zona: Terraza
- Alergias: Sí → Gluten
- Comentarios: Prueba de notificación
```

### 2. Verificar en Dispositivo
- ✅ Notificación push llega
- ✅ Aparece en bandeja de notificaciones de la app
- ✅ Al tocarla, navega a la pantalla de reservas
- ✅ Se muestra con marca de "no leída" (azul)

### 3. Verificar en Firebase Console

**Path:** `empresas/TUz8GOnQ6OX8ejiov7c5GM9LFPl2/notificaciones/items`

**Documento esperado:**
```json
{
  "titulo": "📅 Nueva Reserva",
  "cuerpo": "Test Usuario · +34 600... · 4 pers. · 🌿 Terraza — 27/05/2026 14:00 · ⚠️ Alergias: Gluten",
  "tipo": "reservaNueva",
  "timestamp": "2026-05-26T10:30:00Z",
  "leida": false,
  "modulo_destino": "reservas",
  "entidad_id": "abc123...",
  "remitente_nombre": "Test Usuario",
  "remitente_telefono": "+34 600 000 000",
  "remitente_email": "test@test.com",
  "ubicacion": "terraza",
  "personas": "4",
  "alergenos": true,
  "alergenos_detalle": "Gluten"
}
```

## 🐛 **Troubleshooting**

### Problema: "No llegan las notificaciones push"

**Verificaciones:**

1. **¿La función está desplegada?**
   ```bash
   firebase functions:list | findstr onNuevaReserva
   ```
   Debe mostrar: `onNuevaReserva(europe-west1)`

2. **¿Hay tokens FCM en Firestore?**
   ```
   Firebase Console → Firestore → empresas/{empresaId}/dispositivos
   ```
   Debe haber al menos 1 documento con campo `token`

3. **¿La app tiene permisos de notificaciones?**
   - Android: Configuración → Apps → Fluix CRM → Notificaciones → Activado
   - iOS: Configuración → Notificaciones → Fluix CRM → Permitir

4. **¿El canal está creado? (Android)**
   ```dart
   // Verificar en: lib/services/notificaciones_service.dart
   AndroidNotificationChannel('fluixcrm_canal_principal', ...)
   ```

5. **Logs de Cloud Functions**
   ```bash
   firebase functions:log --only onNuevaReserva
   ```
   Buscar:
   - ✅ `📤 Enviando push a X token(s)`
   - ✅ `✅ Notificaciones enviadas: X/X`
   - ❌ `❌ No hay tokens para empresa` → PROBLEMA

### Problema: "Llegan pero sin sonido"

**Fix:**
- Android: Revisar canal de notificaciones tiene `sound: default`
- iOS: Revisar payload APNS tiene `aps.sound: default`

### Problema: "Al tocar no navega a la reserva"

**Fix:** Verificar que el `data` payload incluye:
```json
{
  "tipo": "nueva_reserva",
  "reserva_id": "...",
  "coleccion": "reservas"
}
```

## 📝 **Notas Importantes**

1. **La función se dispara para TODAS las reservas:**
   - Reservas desde formulario web ✅
   - Reservas desde app B2C ✅
   - Citas desde TPV peluquería ✅

2. **Distingue automáticamente el tipo:**
   ```typescript
   const coleccion = reserva.origen === 'tpv_peluqueria' ? 'citas' : 'reservas';
   ```

3. **Soporta múltiples campos opcionales:**
   - Si falta `numero_personas` → no lo muestra
   - Si falta `alergenos` → no muestra alergias
   - Si falta `zona` → no muestra ubicación
   - Nunca falla por campos faltantes

4. **Limpieza automática de tokens inválidos:**
   - Si un token FCM se elimina o expira
   - La función lo detecta y lo borra de Firestore
   - Evita reintentos innecesarios

---

## ✅ TODO LISTO

**La funcionalidad YA está implementada.** Solo necesitas:
1. Desplegar las reglas de Firestore (para permitir reservas anónimas)
2. Desplegar la Cloud Function `onNuevaReserva`
3. Probar enviando una reserva web

**Ejecuta:** `desplegar_push_reservas.bat`


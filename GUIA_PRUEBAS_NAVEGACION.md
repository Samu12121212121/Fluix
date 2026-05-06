# 🧪 GUÍA DE PRUEBAS - Navegación de Notificaciones y Eventos

## ✅ CAMBIOS IMPLEMENTADOS

He mejorado el código con **logging detallado** para verificar qué está pasando:

### 1. **Notificaciones Push** → Detalle de Reserva
- ✅ Intenta múltiples nombres de campo: `reserva_id`, `id`, `reservaId`, `docId`
- ✅ Logging completo de cada paso
- ✅ Fallback al módulo de reservas si falla

### 2. **Próximos 3 Días** → Detalle de Reserva
- ✅ Busca en `reservas` y `citas`
- ✅ Logging detallado
- ✅ Verifica que el documento existe antes de navegar

### 3. **Cloud Functions** ✅ YA CONFIGURADAS
- ✅ `onNuevaReserva` envía `reserva_id`
- ✅ `onReservaConfirmada` envía `reserva_id`
- ✅ `onReservaCancelada` envía `reserva_id`

---

## 🧪 PRUEBA 1: Notificaciones Push

### Paso 1: Ejecuta la app en modo debug
```powershell
flutter run
```

### Paso 2: Ver los logs en tiempo real
En otra terminal:
```powershell
flutter logs
```

### Paso 3: Crear una reserva de prueba
1. Abre la app
2. Ve a "Reservas"
3. Crea una nueva reserva

### Paso 4: Verificar que llegó la notificación
Busca en los logs:
```
🔔 Notificación de reserva recibida
   tipo: nueva_reserva
   reserva_id: ABC123...
   data completo: {...}
```

### Paso 5: Tocar la notificación
**Si funciona**, verás en logs:
```
🔍 Buscando reserva en Firestore: ABC123...
✅ Reserva encontrada, navegando a detalle
```

**Si NO funciona**, verás:
```
⚠️ No hay reserva_id en el payload o widget no montado
🔙 Fallback: abriendo módulo de reservas
```

---

## 🧪 PRUEBA 2: Widget "Próximos 3 Días"

### Paso 1: Asegúrate de tener reservas HOY o MAÑANA
Crea reservas para hoy o mañana en la app.

### Paso 2: Ve al Dashboard
El widget "Próximos 3 Días" debe mostrar los eventos.

### Paso 3: Toca un día que tenga eventos
Se abrirá un modal con la lista detallada.

### Paso 4: Toca cualquier evento en la lista
**Si funciona**, verás en logs:
```
🔍 Navegando a evento: ABC123...
   Título: Juan Pérez
   Es reserva: true
✅ Documento encontrado, navegando a DetalleReservaScreen
```

**Si NO funciona**, verás:
```
❌ Documento no encontrado en reservas ni citas
```
o
```
⚠️ No se puede navegar: docId=null, esReserva=false
```

---

## 🔍 DEBUGGING - Qué significan los logs

### ✅ LOGS DE ÉXITO:

```
🔔 Notificación de reserva recibida
   tipo: nueva_reserva
   reserva_id: XYZ789
   data completo: {tipo: nueva_reserva, empresa_id: demo_empresa_fluix2026, reserva_id: XYZ789}
🔍 Buscando reserva en Firestore: XYZ789
✅ Reserva encontrada, navegando a detalle
```

**Significa**: Todo funciona perfectamente ✅

---

### ⚠️ LOGS DE PROBLEMA 1: No hay reserva_id

```
🔔 Notificación de reserva recibida
   tipo: nueva_reserva
   reserva_id: null
   data completo: {tipo: nueva_reserva, empresa_id: demo_empresa_fluix2026}
⚠️ No hay reserva_id en el payload o widget no montado
🔙 Fallback: abriendo módulo de reservas
```

**Causa**: La Cloud Function NO está enviando `reserva_id` en el payload

**Solución**: Desplegar Cloud Functions actualizadas:
```powershell
cd functions
npm run build
firebase deploy --only functions
```

---

### ⚠️ LOGS DE PROBLEMA 2: Reserva no existe

```
🔔 Notificación de reserva recibida
   tipo: nueva_reserva
   reserva_id: ABC123
   data completo: {...}
🔍 Buscando reserva en Firestore: ABC123
❌ Reserva no existe o widget no montado
🔙 Fallback: abriendo módulo de reservas
```

**Causa**: El ID de reserva en la notificación NO coincide con el documento en Firestore

**Solución**: Verificar en Firestore Console que la reserva existe con ese ID

---

### ⚠️ LOGS DE PROBLEMA 3: Widget no montado

```
🔔 Notificación de reserva recibida
   tipo: nueva_reserva
   reserva_id: ABC123
   data completo: {...}
⚠️ No hay reserva_id en el payload o widget no montado
```

**Causa**: El dashboard no está listo aún cuando llega la notificación

**Solución**: Esperar a que la app termine de cargar antes de tocar la notificación

---

## 📱 TESTING MANUAL CON FIREBASE CONSOLE

### Enviar notificación de prueba:

1. Ve a **Firebase Console** → **Cloud Messaging**
2. Click en "Send your first message"
3. Configuración:
   - **Notification title**: Nueva Reserva
   - **Notification text**: Juan Pérez - 19:00
4. Click "Next"
5. En "Target": Send test message
6. Pega tu **FCM Token** (aparece en logs al abrir la app)
7. En **Additional options**:
   - Click "Custom data"
   - Añade:
     ```
     Key: tipo               Value: nueva_reserva
     Key: empresa_id         Value: demo_empresa_fluix2026
     Key: reserva_id         Value: [ID_REAL_DE_UNA_RESERVA]
     ```
8. Click "Test"

**Resultado esperado**: La notificación llega y al tocarla abre el detalle de esa reserva.

---

## 🔧 SI AÚN NO FUNCIONA

### Verifica que las Cloud Functions están desplegadas:

```powershell
firebase functions:list | findstr reserva
```

Debes ver:
- `onNuevaReserva`
- `onReservaConfirmada`
- `onReservaCancelada`

### Verifica los logs de Cloud Functions:

```powershell
firebase functions:log --only onNuevaReserva
```

Busca:
```
✅ Reserva guardada en bandeja y push enviado
```

### Verifica el código de la función:

Archivo: `functions/src/index.ts` línea ~431

Debe contener:
```typescript
{ tipo: "nueva_reserva", reserva_id: entidadId, coleccion }
```

---

## 📋 CHECKLIST DE VERIFICACIÓN

### Backend (Cloud Functions):
- [ ] Functions compiladas: `cd functions && npm run build`
- [ ] Functions desplegadas: `firebase deploy --only functions`
- [ ] Logs confirman que envían `reserva_id`

### Frontend (Flutter):
- [ ] Código actualizado: `flutter clean && flutter pub get`
- [ ] App ejecutándose en modo debug: `flutter run`
- [ ] Logs visibles en otra terminal: `flutter logs`

### Prueba End-to-End:
- [ ] Crear reserva nueva → Llega notificación
- [ ] Tocar notificación → Abre detalle (NO solo módulo)
- [ ] Ver "Próximos 3 Días" → Tiene eventos
- [ ] Tocar evento → Abre detalle (NO solo módulo)

---

## 🎯 COMANDOS RÁPIDOS

### Setup inicial:
```powershell
# Limpiar y compilar Flutter
flutter clean
flutter pub get

# Compilar Cloud Functions
cd functions
npm run build
cd ..
```

### Desplegar backend:
```powershell
firebase deploy --only functions
```

### Ejecutar y ver logs:
```powershell
# Terminal 1:
flutter run

# Terminal 2:
flutter logs | findstr "🔔"
```

---

## 📊 RESULTADOS ESPERADOS

### ✅ FLUJO CORRECTO:

1. **Usuario crea reserva** → Cloud Function se ejecuta
2. **Cloud Function envía notificación** con `reserva_id`
3. **App recibe notificación** → Guarda en stream
4. **Usuario toca notificación** → Logs muestran "🔔 Notificación recibida"
5. **App busca reserva** → Logs muestran "🔍 Buscando reserva..."
6. **App encuentra documento** → Logs muestran "✅ Reserva encontrada"
7. **App navega** → Se abre `DetalleReservaScreen`
8. **Usuario ve los detalles** de esa reserva específica ✅

---

**Última actualización**: 5 Mayo 2026, 16:00  
**Estado**: 🔍 TESTING - Con logging mejorado
**Siguiente paso**: Ejecutar pruebas y verificar logs


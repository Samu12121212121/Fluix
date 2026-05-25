# 🚀 Despliegue del Sistema de Reservas B2C

## Checklist Rápido

- [ ] 1. Desplegar reglas de Firestore
- [ ] 2. Verificar módulo de reservas owner
- [ ] 3. Configurar Cloud Function para emails
- [ ] 4. Probar flujo completo
- [ ] 5. Monitoring en producción

---

## 1. Desplegar Reglas de Firestore ✅

### Opción A: Usando el script BAT
```bash
.\desplegar_reglas_reservas.bat
```

### Opción B: Manual
```bash
# Validar sintaxis
firebase deploy --only firestore:rules --dry-run

# Si todo OK, desplegar
firebase deploy --only firestore:rules
```

**Resultado esperado**:
```
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/tu-proyecto/overview
```

---

## 2. Verificar Módulo de Reservas Owner

El módulo de reservas del owner YA EXISTE pero asegúrate de que lee de la colección correcta:

**Archivo**: `lib/features/reservas/pantallas/modulo_reservas_screen.dart`

**Buscar** (línea ~400):
```dart
stream: FirebaseFirestore.instance
  .collection('empresas')
  .doc(empresaId)
  .collection('reservas')  // ← Debe ser 'reservas', NO 'citas'
```

Si dice `citas`, cambiar a `reservas`.

**Funcionalidades del módulo owner**:
- ✅ Ver reservas pendientes, confirmadas, canceladas
- ✅ Botón "Confirmar" → cambia estado a `confirmada`
- ✅ Botón "Cancelar" → cambia estado a `cancelada` + motivo
- ✅ Editar fecha/hora/profesional
- ✅ Filtros por fecha y estado

---

## 3. Configurar Cloud Function para Emails

### Paso 3.1: Verificar que las funciones estén inicializadas

**Archivo**: `functions/index.js`

Debe contener:
```javascript
const admin = require('firebase-admin');
admin.initializeApp();

// Importar función de notificación de reservas
const notificarReservas = require('./notificarNuevaReserva');
exports.notificarNuevaReserva = notificarReservas.notificarNuevaReserva;
exports.reenviarEmailReserva = notificarReservas.reenviarEmailReserva;
```

**Si no existe `index.js`**, créalo con el contenido de arriba.

### Paso 3.2: Instalar dependencias

```bash
cd functions
npm install nodemailer
cd ..
```

### Paso 3.3: Configurar credenciales SMTP

#### Opción A: Gmail (recomendado para desarrollo)

1. **Crear contraseña de aplicación** en tu cuenta de Gmail:
   - https://myaccount.google.com/apppasswords
   - Selecciona "Otra app" → escribe "Fluix CRM"
   - Copia la contraseña generada (16 caracteres)

2. **Configurar en Firebase**:
```bash
firebase functions:config:set email.user="tu_email@gmail.com"
firebase functions:config:set email.pass="xxxx xxxx xxxx xxxx"  # Contraseña de aplicación
```

#### Opción B: Sendgrid (recomendado para producción)

```bash
npm install @sendgrid/mail

firebase functions:config:set sendgrid.apikey="SG.xxxxxxxxxxxxxx"
```

Luego modifica `notificarNuevaReserva.js`:
```javascript
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(functions.config().sendgrid.apikey);

// Reemplazar transporter.sendMail con:
await sgMail.send(mailOptions);
```

### Paso 3.4: Desplegar función

```bash
firebase deploy --only functions:notificarNuevaReserva
```

**Resultado esperado**:
```
✔  functions[notificarNuevaReserva(us-central1)] Successful create operation.
Function URL: https://us-central1-tu-proyecto.cloudfunctions.net/notificarNuevaReserva
```

### Paso 3.5: Verificar configuración

```bash
# Ver config actual
firebase functions:config:get

# Resultado esperado:
{
  "email": {
    "user": "tu_email@gmail.com",
    "pass": "************"
  }
}
```

---

## 4. Probar Flujo Completo

### Test 1: Cliente crea reserva

1. **Abrir app** en modo cliente (logout si es owner)
2. **Ir a "Explorar"** → buscar un negocio
3. **Entrar en detalle** del negocio
4. **Tab "⚡ Reservar"**
5. **Seleccionar servicio** → ver que muestra servicios del módulo owner
6. **Calendario** → seleccionar día (verificar colores de carga)
7. **Hora** → seleccionar slot disponible
8. **Profesional** → verificar que aparecen empleados reales
9. **Confirmar** → debe mostrar "Reserva enviada, el negocio confirmará pronto"

### Test 2: Owner recibe notificación

1. **Login** como owner/admin de la empresa
2. **Ir a módulo "Reservas"**
3. **Verificar**:
   - [ ] Reserva aparece con estado "Pendiente"
   - [ ] Cliente se muestra correctamente
   - [ ] Servicio es el seleccionado
   - [ ] Fecha/hora correctas
   - [ ] Profesional asignado

### Test 3: Email enviado

1. **Verificar bandeja** del email de la empresa
2. **Debe llegar**:
   - Asunto: "📅 Nueva reserva de [Cliente] - [Fecha]"
   - Cuerpo: HTML con todos los datos
   - Botón "Ver en Fluix CRM"

Si NO llega:
```bash
# Ver logs
firebase functions:log --only notificarNuevaReserva

# Buscar errores
grep "Error" logs.txt
```

### Test 4: Owner confirma/rechaza

1. **En módulo Reservas** → abrir reserva pendiente
2. **Botón "Confirmar"**:
   - [ ] Estado cambia a "Confirmada"
   - [ ] Color verde
   - [ ] Cliente ve cambio (si tiene pantalla mis_reservas)

3. **O botón "Cancelar"**:
   - [ ] Modal pide motivo
   - [ ] Estado cambia a "Cancelada"
   - [ ] Color rojo

---

## 5. Monitoring en Producción

### Firestore Console

**Ver reservas**:
```
empresas/{empresaId}/reservas
```

**Ver notificaciones**:
```
empresas/{empresaId}/notificaciones_reservas
```

### Cloud Functions Console

**Ver invocaciones**:
https://console.firebase.google.com/project/tu-proyecto/functions/list

**Ver logs**:
```bash
# En tiempo real
firebase functions:log --only notificarNuevaReserva

# Últimas 100 líneas
firebase functions:log --only notificarNuevaReserva --lines 100
```

### Métricas clave a monitorear

1. **Tasa de error en emails**: < 5%
   ```bash
   firebase functions:log | grep "Error al enviar email" | wc -l
   ```

2. **Reservas pendientes sin confirmar**: Alertar si > 24h
   ```javascript
   // Query en Firestore
   .where('estado', '==', 'pendiente')
   .where('fecha_creacion', '<', hace24Horas)
   ```

3. **Profesionales sin reservas**: Detectar empleados inactivos

---

## Troubleshooting

### Problema: "Email no configurado"

**Síntoma**: Función ejecuta pero no envía email

**Solución**:
```bash
firebase functions:config:get
# Si está vacío:
firebase functions:config:set email.user="..." email.pass="..."
firebase deploy --only functions
```

### Problema: "Permission denied" al crear reserva

**Síntoma**: Cliente no puede crear reserva

**Solución**: Verificar rules:
```bash
firebase firestore:indexes | grep reservas
# Si no aparece, desplegar rules:
firebase deploy --only firestore:rules
```

### Problema: Servicios no aparecen en B2C

**Síntoma**: Tab "Reservar" muestra "Sin servicios"

**Verificar**:
1. Firestore console → `empresas/{id}/servicios`
2. Campo `activo: true`
3. Relación `empresaIdVinculada` correcta en negocio

**Solución**:
```dart
// En tab_reservas_screen.dart línea ~200
.where('activo', isNotEqualTo: false)  // ← Asegurar
```

### Problema: Profesionales no aparecen

**Verificar**:
1. Firestore console → `usuarios`
2. Campo `empresa_id` == ID de empresa
3. Campo `activo: true`

**Solución**: Asignar empleados correctamente en módulo owner

---

## Estadísticas de Éxito

Después de 1 semana en producción, deberías ver:

- ✅ **Reservas creadas**: > 10/semana
- ✅ **Tasa de confirmación**: > 80%
- ✅ **Emails enviados**: 95-100%
- ✅ **Tiempo medio de confirmación**: < 2 horas

---

## Siguiente Paso: Notificaciones Push

Cuando el owner confirma/rechaza, enviar push al cliente:

```javascript
// En Cloud Function
exports.notificarCambioEstadoReserva = functions.firestore
  .document('empresas/{empresaId}/reservas/{reservaId}')
  .onUpdate(async (change, context) => {
    const antes = change.before.data();
    const despues = change.after.data();
    
    if (antes.estado !== despues.estado) {
      // Obtener token FCM del cliente
      const tokenSnap = await admin.firestore()
        .collection('usuarios')
        .doc(despues.cliente_uid)
        .get();
      
      const token = tokenSnap.data()?.fcm_token;
      
      if (token) {
        await admin.messaging().send({
          token,
          notification: {
            title: despues.estado === 'confirmada' 
              ? '✅ Reserva confirmada' 
              : '❌ Reserva cancelada',
            body: `Tu reserva para ${despues.servicio_nombre} ha sido ${despues.estado}`,
          },
        });
      }
    }
  });
```

---

*Última actualización: 25 Mayo 2026*


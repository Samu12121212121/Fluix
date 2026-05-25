#  Análisis Completo: TPV y Sistema de Emails por Negocio

**Fecha**: 13 de Mayo de 2026

---

##  PROBLEMAS DETECTADOS EN EL TPV

### 1. ❌ App se Cierra al Cobrar
**Causa probable**: Error no capturado en `_cobrar()` línea 1573-1704

**Posibles razones**:
- `PedidosService().crearPedido()` puede lanzar excepción
- `TpvFacturacionService()` puede fallar
- Falta try-catch general en toda la función

**Solución**: Envolver toda la función en try-catch

```dart
Future<void> _cobrar(...) async {
  try {
    final pago = await showDialog<Map<String, dynamic>>(...);
    if (pago == null) return;
    
    // ... resto del código
    
  } catch (e, stackTrace) {
    debugPrint('Error en cobro: $e');
    debugPrint('StackTrace: $stackTrace');
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar el cobro: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
}
```

---

### 2. ⚠️ Funciones NO Implementadas en TPV

#### 2.1 Dividir Cuenta
**Estado**: Función vacía `// TODO: implementar`  
**Línea**: ~880  
**Complejidad**: Alta  
**Requiere**:
- Seleccionar productos por comensal
- Dividir total entre N personas
- Generar múltiples tickets
- UI para selección de ítems

#### 2.2 Enviar a Cocina
**Estado**: Parcial - no imprime ticket de cocina  
**Línea**: ~1310  
**Complejidad**: Media  
**Requiere**:
- Template de ticket de cocina
- Método `imprimirTicketCocina()` en ImpressoraBluetooth
- Clase `TicketCocinaData`

#### 2.3 Nota General de Comanda
**Estado**: Deshabilitado - modelo no soporta  
**Línea**: ~1337  
**Complejidad**: Baja  
**Requiere**:
- Añadir `notaGeneral` a modelo Comanda
- Añadir campo en Firestore

#### 2.4 Aplicar Descuento
**Estado**: Deshabilitado - modelo no soporta  
**Línea**: ~1479  
**Complejidad**: Media  
**Requiere**:
- Añadir `descuento` y `descuentoPct` a Comanda
- Recalcular totales
- Mostrar descuento en ticket

#### 2.5 Editar Precio de Línea
**Estado**: Deshabilitado - copyWith no soporta  
**Línea**: ~1527  
**Complejidad**: Baja  
**Requiere**:
- Añadir `precioUnitario` a `LineaComanda.copyWith()`

#### 2.6 Añadir Producto Manual
**Estado**: ✅ **FUNCIONA** (línea 1371-1425)

#### 2.7 Transferir Comanda
**Estado**: Función existe pero no está referenciada  
**Línea**: ~3554  
**Complejidad**: Alta

---

### 3. ✅ Funciones que SÍ Funcionan

- ✅ Crear/Editar/Eliminar Mesas (con diálogos nuevos)
- ✅ Establecer comensales
- ✅ Añadir productos del catálogo
- ✅ Modificar cantidades (+/-)
- ✅ Eliminar líneas
- ✅ Cálculo de totales (IVA incluido)
- ✅ Apertura/Cierre de caja (botones en AppBar)
- ✅ Búsqueda y filtrado de productos
- ✅ Guardar comanda en Firestore

---

##  SISTEMA DE EMAILS POR NEGOCIO

### Requerimientos

1. **Campo de correo POR NEGOCIO** en gestión de negocio
2. Cuando alguien reserva → email al correo del negocio
3. Email con botones **Aceptar** / **Rechazar**
4. Según respuesta → email de confirmación/rechazo al usuario

---

### Arquitectura de la Solución

```
Cliente Reserva
     ↓
Firestore: /empresas/{id}/reservas/{reservaId}
     ↓
Cloud Function: enviarEmailNuevaReserva
     ↓
Email al negocio con botones
     ↓
Usuario (propietario) hace clic en Aceptar/Rechazar
     ↓
Web Endpoint: /api/reservas/aceptar o /rechazar
     ↓
Cloud Function: procesarRespuestaReserva
     ↓
Actualiza Firestore + Envía email al cliente
```

---

### 1. Estructura de Firestore

#### `/empresas/{empresaId}`
```json
{
  "nombre": "Mi Restaurante",
  "correo_reservas": "reservas@mirestaurante.com",  // ← NUEVO CAMPO
  "direccion": "Calle Principal 123",
  "telefono": "+34 600 123 456"
}
```

#### `/empresas/{empresaId}/reservas/{reservaId}`
```json
{
  "usuario_uid": "abc123",
  "usuario_nombre": "Juan Pérez",
  "usuario_email": "juan@email.com",
  "usuario_telefono": "+34 600 555 666",
  "fecha_hora": "Timestamp",
  "servicio_id": "servicio_abc",
  "servicio_nombre": "Corte de Cabello",
  "num_personas": 1,
  "notas": "Sin barba por favor",
  "estado": "pendiente",  // pendiente | confirmada | rechazada | completada
  "creado_en": "Timestamp",
  "confirmada_en": "Timestamp | null",
  "rechazada_en": "Timestamp | null",
  "token_accion": "abc123def456",  // ← Token único para verificar acción
  "mensaje_propietario": "string | null"
}
```

---

### 2. Cloud Functions Necesarias

#### Función 1: `enviarEmailNuevaReserva`
**Trigger**: onCreate en `/empresas/{empresaId}/reservas/{reservaId}`

```typescript
export const enviarEmailNuevaReserva = functions.firestore
  .document('empresas/{empresaId}/reservas/{reservaId}')
  .onCreate(async (snapshot, context) => {
    const empresaId = context.params.empresaId;
    const reservaId = context.params.reservaId;
    const reservaData = snapshot.data();
    
    // Obtener correo del negocio
    const empresaDoc = await admin.firestore()
      .collection('empresas')
      .doc(empresaId)
      .get();
    
    const correoNegocio = empresaDoc.data()?.correo_reservas;
    if (!correoNegocio) {
      console.log('No hay correo configurado para este negocio');
      return;
    }
    
    // Generar token único para esta reserva
    const token = generarTokenSeguro();
    await snapshot.ref.update({ token_accion: token });
    
    // URLs de acción
    const urlBase = 'https://tu-dominio.com/api/reservas';
    const urlAceptar = `${urlBase}/aceptar?id=${reservaId}&token=${token}`;
    const urlRechazar = `${urlBase}/rechazar?id=${reservaId}&token=${token}`;
    
    // Enviar email
    await enviarEmail({
      para: correoNegocio,
      asunto: `Nueva Reserva - ${reservaData.usuario_nombre}`,
      html: generarHTMLEmailPropietario({
        ...reservaData,
        urlAceptar,
        urlRechazar,
      }),
    });
  });
```

#### Función 2: `aceptarReserva`  
**Trigger**: HTTPS callable

```typescript
export const aceptarReserva = functions.https.onRequest(async (req, res) => {
  const reservaId = req.query.id as string;
  const token = req.query.token as string;
  
  // Buscar la reserva
  const reservasSnapshot = await admin.firestore()
    .collectionGroup('reservas')
    .where(admin.firestore.FieldPath.documentId(), '==', reservaId)
    .get();
  
  if (reservasSnapshot.empty) {
    return res.status(404).send('Reserva no encontrada');
  }
  
  const reservaDoc = reservasSnapshot.docs[0];
  const reservaData = reservaDoc.data();
  
  // Verificar token
  if (reservaData.token_accion !== token) {
    return res.status(403).send('Token inválido');
  }
  
  // Verificar que no esté ya procesada
  if (reservaData.estado !== 'pendiente') {
    return res.send(`
      <html>
        <body style="font-family: Arial; text-align: center; padding: 50px;">
          <h2>Esta reserva ya fue ${reservaData.estado}</h2>
          <p>No es posible modificar el estado.</p>
        </body>
      </html>
    `);
  }
  
  // Actualizar estado
  await reservaDoc.ref.update({
    estado: 'confirmada',
    confirmada_en: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // Enviar email de confirmación al cliente
  await enviarEmail({
    para: reservaData.usuario_email,
    asunto: 'Reserva Confirmada',
    html: generarHTMLConfirmacionCliente(reservaData),
  });
  
  // Mostrar página de éxito
  res.send(`
    <html>
      <head>
        <style>
          body { font-family: Arial; text-align: center; padding: 50px; background: #0A0F23; color: white; }
          .success { background: linear-gradient(135deg, #00FFC8, #00D9FF); color: #0A0F23; padding: 30px; border-radius: 16px; }
          h1 { margin: 0; }
        </style>
      </head>
      <body>
        <div class="success">
          <h1>✅ Reserva Aceptada</h1>
          <p>Se ha enviado un email de confirmación al cliente.</p>
          <p><strong>${reservaData.usuario_nombre}</strong> - ${reservaData.usuario_email}</p>
        </div>
      </body>
    </html>
  `);
});
```

#### Función 3: `rechazarReserva`
**Trigger**: HTTPS callable

```typescript
export const rechazarReserva = functions.https.onRequest(async (req, res) => {
  // Similar a aceptarReserva pero cambia estado a 'rechazada'
  // y envía email de rechazo al cliente
});
```

---

### 3. Template de Email para Propietario

```html
<!DOCTYPE html>
<html>
<head>
  <style>
    /* Estilos del email */
    body { background: #0A0F23; font-family: Arial; }
    .container { max-width: 600px; margin: 0 auto; }
    .header { background: linear-gradient(135deg, #00FFC8, #00D9FF); padding: 30px; text-align: center; }
    .button-accept { 
      display: inline-block; 
      background: #00FFC8; 
      color: #0A0F23; 
      padding: 15px 40px; 
      text-decoration: none; 
      border-radius: 12px; 
      font-weight: bold;
      margin: 10px;
    }
    .button-reject { 
      display: inline-block; 
      background: #FF2850; 
      color: white; 
      padding: 15px 40px; 
      text-decoration: none; 
      border-radius: 12px; 
      font-weight: bold;
      margin: 10px;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Nueva Reserva</h1>
    </div>
    <div class="content" style="background: #1E2139; padding: 30px;">
      <h3>Cliente: {{nombreCliente}}</h3>
      <p>Email: {{emailCliente}}</p>
      <p>Teléfono: {{telefono}}</p>
      <p>Fecha: {{fechaHora}}</p>
      <p>Servicio: {{servicio}}</p>
      <p>Personas: {{numPersonas}}</p>
      
      <div style="text-align: center; margin: 30px 0;">
        <a href="{{urlAceptar}}" class="button-accept">✓ ACEPTAR RESERVA</a>
        <a href="{{urlRechazar}}" class="button-reject">✗ RECHAZAR RESERVA</a>
      </div>
      
      <p style="font-size: 12px; color: #6B6E82;">
        Al hacer clic en uno de los botones, la reserva se procesará automáticamente
        y se enviará un email al cliente.
      </p>
    </div>
  </div>
</body>
</html>
```

---

### 4. Integración en la App Flutter

#### 4.1 Agregar Campo de Correo en Gestión de Negocio

```dart
// En la pantalla de edición de negocio
TextFormField(
  controller: _correoReservasCtrl,
  keyboardType: TextInputType.emailAddress,
  decoration: InputDecoration(
    labelText: 'Correo para Reservas',
    hintText: 'reservas@tunegocio.com',
    helperText: 'A este correo llegarán las notificaciones de reservas',
    prefixIcon: Icon(Icons.email),
  ),
  validator: (value) {
    if (value != null && value.isNotEmpty) {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
        return 'Email inválido';
      }
    }
    return null;
  },
)

// Al guardar
await FirebaseFirestore.instance
  .collection('empresas')
  .doc(empresaId)
  .update({
    'correo_reservas': _correoReservasCtrl.text.trim(),
  });
```

#### 4.2 Crear Reserva desde la App

```dart
// Cuando el cliente hace una reserva
Future<void> crearReserva({
  required String empresaId,
  required String servicioId,
  required String servicioNombre,
  required DateTime fechaHora,
  required int numPersonas,
  String? notas,
}) async {
  final user = FirebaseAuth.instance.currentUser!;
  
  await FirebaseFirestore.instance
    .collection('empresas')
    .doc(empresaId)
    .collection('reservas')
    .add({
      'usuario_uid': user.uid,
      'usuario_nombre': user.displayName ?? 'Usuario',
      'usuario_email': user.email!,
      'usuario_telefono': user.phoneNumber ?? '',
      'fecha_hora': Timestamp.fromDate(fechaHora),
      'servicio_id': servicioId,
      'servicio_nombre': servicioNombre,
      'num_personas': numPersonas,
      'notas': notas,
      'estado': 'pendiente',
      'creado_en': FieldValue.serverTimestamp(),
    });
  
  // La Cloud Function se ejecuta automáticamente al crear el documento
}
```

---

### 5. Configuración de Email (Hostinger/Gmail)

#### Opción A: Usar Hostinger SMTP

```typescript
// En Cloud Functions
const transporter = nodemailer.createTransporter({
  host: 'smtp.hostinger.com',
  port: 587,
  secure: false,
  auth: {
    user: 'noreply@tudominio.com',
    pass: 'tu_contraseña',
  },
});
```

#### Opción B: Usar SendGrid (Recomendado para productivo)

```typescript
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_API_KEY);

await sgMail.send({
  to: correoNegocio,
  from: 'reservas@tuapp.com',
  subject: 'Nueva Reserva',
  html: htmlContent,
});
```

---

## ✅ CHECKLIST DE IMPLEMENTACIÓN

### TPV
- [ ] Envolver `_cobrar()` en try-catch completo
- [ ] Implementar dividir cuenta
- [ ] Completar envío a cocina con impresión
- [ ] Añadir campos faltantes a modelos (descuento, notaGeneral, etc.)
- [ ] Probar cobro con datos reales

### Emails de Reservas
- [ ] Agregar campo `correo_reservas` a formulario de negocio
- [ ] Crear Cloud Functions en Firebase
- [ ] Configurar SMTP (Hostinger o SendGrid)
- [ ] Crear templates HTML de emails
- [ ] Implementar endpoints web para aceptar/rechazar
- [ ] Probar flujo completo con emails reales
- [ ] Configurar dominio personalizado

---

##  PRIORIDADES

1. **URGENTE**: Arreglar crash al cobrar en TPV
2. **ALTA**: Implementar sistema de emails por negocio
3. **MEDIA**: Completar funciones faltantes TPV
4. **BAJA**: Optimizaciones y mejoras UI

---

**Próximo paso**: Implementar correcciones del TPV y crear las Cloud Functions

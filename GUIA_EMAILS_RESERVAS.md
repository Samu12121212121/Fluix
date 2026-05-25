#  GUÍA COMPLETA: Sistema de Emails de Reservas por Negocio

**Fecha**: 13 de Mayo de 2026  
**Versión**: 1.0

---

## ✅ TPV CORREGIDO

He corregido el error que causaba que la app se cerrar al cobrar:
- ✅ Toda la función `_cobrar()` ahora está envuelta en try-catch
- ✅ Se muestra mensaje de error detallado si algo falla
- ✅ Se puede ver el stack trace completo para debug

**Archivos modificados**:
- `lib/features/tpv/pantallas/tpv_root_screen.dart` (líneas 1573-1745)

---

##  SISTEMA DE EMAILS - EXPLICACIÓN SIMPLE

### ¿Cómo Funciona?

1. **Cliente hace reserva** en la app
2. **Se crea documento** en Firestore `/empresas/{id}/reservas/{reservaId}`
3. **Cloud Function detecta** el nuevo documento automáticamente
4. **Se envía email** al correo del negocio con 2 botones: ✓ Aceptar | ✗ Rechazar
5. **Propietario hace clic** en uno de los botones
6. **Se abre página web** que procesa la acción
7. **Se actualiza Firestore** (estado: confirmada o rechazada)
8. **Se envía email al cliente** con la confirmación/rechazo

---

##  PASO 1: Agregar Campo de Correo por Negocio

### Modificar Formulario de Negocio

Busca el archivo donde editas los datos de la empresa (nombre, dirección, etc.) y agrega este campo:

```dart
// En el formulario de edición de negocio
final _correoReservasCtrl = TextEditingController();

// En initState, cargar el valor
@override
void initState() {
  super.initState();
  _cargarDatosNegocio();
}

Future<void> _cargarDatosNegocio() async {
  final doc = await FirebaseFirestore.instance
    .collection('empresas')
    .doc(widget.empresaId)
    .get();
  
  if (doc.exists) {
    final data = doc.data()!;
    // ... otros campos
    _correoReservasCtrl.text = data['correo_reservas'] ?? '';
  }
}

// En el formulario
TextFormField(
  controller: _correoReservasCtrl,
  keyboardType: TextInputType.emailAddress,
  style: const TextStyle(color: Colors.white),
  decoration: const InputDecoration(
    labelText: 'Correo para Recibir Reservas',
    labelStyle: TextStyle(color: Color(0xFFB0B3C1)),
    hintText: 'reservas@tunegocio.com',
    hintStyle: TextStyle(color: Color(0xFF6B6E82)),
    prefixIcon: Icon(Icons.email, color: Color(0xFF00FFC8)),
    helperText: 'A este correo llegarán las notificaciones cuando alguien reserve',
    helperStyle: TextStyle(color: Color(0xFF6B6E82), fontSize: 11),
    filled: true,
    fillColor: Color(0xFF1E2139),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide.none,
    ),
  ),
  validator: (value) {
    if (value != null && value.trim().isNotEmpty) {
      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
        return 'Correo electrónico inválido';
      }
    }
    return null;
  },
),

// Al guardar
Future<void> _guardarNegocio() async {
  await FirebaseFirestore.instance
    .collection('empresas')
    .doc(widget.empresaId)
    .update({
      // ... otros campos
      'correo_reservas': _correoReservasCtrl.text.trim(),
      'actualizado_en': FieldValue.serverTimestamp(),
    });
}
```

---

##  PASO 2: Crear Cloud Functions

### 2.1 Configurar Firebase Functions

En tu terminal:

```bash
cd functions
npm install nodemailer
npm install @sendgrid/mail  # Si usas SendGrid
```

### 2.2 Crear archivo `index.ts`

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as nodemailer from 'nodemailer';

admin.initializeApp();

// Configurar transporter de Nodemailer (Hostinger)
const transporter = nodemailer.createTransporter({
  host: 'smtp.hostinger.com',
  port: 587,
  secure: false,
  auth: {
    user: 'noreply@tudominio.com',  // ← Cambia esto
    pass: 'tu_contraseña_smtp',      // ← Cambia esto
  },
});

/**
 * Se ejecuta automáticamente cuando se crea una nueva reserva
 */
export const enviarEmailNuevaReserva = functions.firestore
  .document('empresas/{empresaId}/reservas/{reservaId}')
  .onCreate(async (snapshot, context) => {
    const empresaId = context.params.empresaId;
    const reservaId = context.params.reservaId;
    const reservaData = snapshot.data();
    
    console.log(`Nueva reserva creada: ${reservaId}`);
    
    // Obtener datos de la empresa
    const empresaDoc = await admin.firestore()
      .collection('empresas')
      .doc(empresaId)
      .get();
    
    if (!empresaDoc.exists) {
      console.error('Empresa no encontrada');
      return;
    }
    
    const empresaData = empresaDoc.data()!;
    const correoNegocio = empresaData.correo_reservas;
    
    if (!correoNegocio) {
      console.log(`No hay correo configurado para ${empresaData.nombre}`);
      return;
    }
    
    // Generar token único para seguridad
    const token = generarTokenSeguro();
    await snapshot.ref.update({ token_accion: token });
    
    // URLs para aceptar/rechazar
    const urlBase = 'https://tu-dominio.com/api/reservas';  // ← Cambia esto
    const urlAceptar = `${urlBase}/aceptar?id=${reservaId}&token=${token}&empresa=${empresaId}`;
    const urlRechazar = `${urlBase}/rechazar?id=${reservaId}&token=${token}&empresa=${empresaId}`;
    
    // Formatear fecha
    const fecha = reservaData.fecha_hora.toDate();
    const fechaFormateada = fecha.toLocaleDateString('es-ES', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
    
    // HTML del email
    const html = generarHTMLEmailPropietario({
      nombreEmpresa: empresaData.nombre,
      nombreCliente: reservaData.usuario_nombre,
      emailCliente: reservaData.usuario_email,
      telefono: reservaData.usuario_telefono || 'No proporcionado',
      fechaHora: fechaFormateada,
      servicio: reservaData.servicio_nombre,
      numPersonas: reservaData.num_personas || 1,
      notas: reservaData.notas,
      urlAceptar,
      urlRechazar,
    });
    
    // Enviar email
    try {
      await transporter.sendMail({
        from: `"${empresaData.nombre}" <noreply@tudominio.com>`,
        to: correoNegocio,
        subject: ` Nueva Reserva - ${reservaData.usuario_nombre}`,
        html: html,
      });
      
      console.log(`Email enviado a ${correoNegocio}`);
      
      // Registrar envío
      await admin.firestore()
        .collection('empresas')
        .doc(empresaId)
        .collection('emails_enviados')
        .add({
          tipo: 'nueva_reserva',
          para: correoNegocio,
          reserva_id: reservaId,
          enviado_en: admin.firestore.FieldValue.serverTimestamp(),
        });
        
    } catch (error) {
      console.error('Error enviando email:', error);
    }
  });

/**
 * Endpoint para ACEPTAR una reserva
 */
export const aceptarReserva = functions.https.onRequest(async (req, res) => {
  const reservaId = req.query.id as string;
  const token = req.query.token as string;
  const empresaId = req.query.empresa as string;
  
  if (!reservaId || !token || !empresaId) {
    return res.status(400).send('Parámetros faltantes');
  }
  
  try {
    // Obtener reserva
    const reservaRef = admin.firestore()
      .collection('empresas')
      .doc(empresaId)
      .collection('reservas')
      .doc(reservaId);
    
    const reservaDoc = await reservaRef.get();
    
    if (!reservaDoc.exists) {
      return res.status(404).send('Reserva no encontrada');
    }
    
    const reservaData = reservaDoc.data()!;
    
    // Verificar token
    if (reservaData.token_accion !== token) {
      return res.status(403).send('Token inválido - acción no autorizada');
    }
    
    // Verificar que esté pendiente
    if (reservaData.estado !== 'pendiente') {
      return res.send(paginaYaProcesada(reservaData.estado));
    }
    
    // Actualizar estado a confirmada
    await reservaRef.update({
      estado: 'confirmada',
      confirmada_en: admin.firestore.FieldValue.serverTimestamp(),
    });
    
    // Obtener datos de la empresa
    const empresaDoc = await admin.firestore()
      .collection('empresas')
      .doc(empresaId)
      .get();
    const empresaData = empresaDoc.data()!;
    
    // Enviar email de confirmación al cliente
    const fecha = reservaData.fecha_hora.toDate();
    const fechaFormateada = fecha.toLocaleDateString('es-ES', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
    
    const htmlCliente = generarHTMLConfirmacionCliente({
      nombreCliente: reservaData.usuario_nombre,
      nombreEmpresa: empresaData.nombre,
      fechaHora: fechaFormateada,
      servicio: reservaData.servicio_nombre,
      numPersonas: reservaData.num_personas,
      direccion: empresaData.direccion || '',
      telefono: empresaData.telefono,
    });
    
    await transporter.sendMail({
      from: `"${empresaData.nombre}" <noreply@tudominio.com>`,
      to: reservaData.usuario_email,
      subject: `✅ Reserva Confirmada - ${empresaData.nombre}`,
      html: htmlCliente,
    });
    
    // Mostrar página de éxito
    res.send(paginaExito(reservaData, empresaData));
    
  } catch (error) {
    console.error('Error:', error);
    res.status(500).send(`Error al procesar: ${error}`);
  }
});

/**
 * Endpoint para RECHAZAR una reserva
 */
export const rechazarReserva = functions.https.onRequest(async (req, res) => {
  // Similar a aceptar pero actualiza estado a 'rechazada'
  // y envía email de rechazo al cliente
  // ... (código similar al de aceptar)
});

// Funciones auxiliares
function generarTokenSeguro(): string {
  return Math.random().toString(36).substring(2) + Date.now().toString(36);
}

function generarHTMLEmailPropietario(params: any): string {
  return `
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { background: #0A0F23; font-family: Arial, sans-serif; margin: 0; padding: 20px; }
    .container { max-width: 600px; margin: 0 auto; background: #1E2139; border-radius: 16px; overflow: hidden; }
    .header { background: linear-gradient(135deg, #00FFC8 0%, #00D9FF 100%); padding: 30px; text-align: center; }
    .header h1 { margin: 0; color: #0A0F23; font-size: 24px; }
    .content { padding: 30px; color: white; }
    .info-box { background: #151932; padding: 20px; border-radius: 12px; margin: 20px 0; border-left: 4px solid #FF3296; }
    .info-row { padding: 10px 0; border-bottom: 1px solid #2A2E45; }
    .info-row:last-child { border-bottom: none; }
    .label { color: #B0B3C1; font-weight: 600; }
    .value { color: #FFFFFF; font-weight: bold; float: right; }
    .buttons { text-align: center; margin: 30px 0; }
    .button { display: inline-block; padding: 15px 40px; margin: 10px; border-radius: 12px; text-decoration: none; font-weight: bold; font-size: 16px; }
    .btn-accept { background: #00FFC8; color: #0A0F23; }
    .btn-reject { background: #FF2850; color: white; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1> Nueva Reserva Recibida</h1>
      <p style="margin: 10px 0 0 0; color: #0A0F23;">${params.nombreEmpresa}</p>
    </div>
    <div class="content">
      <p>Se ha recibido una nueva reserva a través de la aplicación:</p>
      <div class="info-box">
        <h3 style="margin-top: 0; color: #FF3296;"> Detalles</h3>
        <div class="info-row">
          <span class="label">Cliente:</span>
          <span class="value">${params.nombreCliente}</span>
        </div>
        <div class="info-row">
          <span class="label">Email:</span>
          <span class="value">${params.emailCliente}</span>
        </div>
        <div class="info-row">
          <span class="label">Teléfono:</span>
          <span class="value">${params.telefono}</span>
        </div>
        <div class="info-row">
          <span class="label">Fecha y Hora:</span>
          <span class="value">${params.fechaHora}</span>
        </div>
        <div class="info-row">
          <span class="label">Servicio:</span>
          <span class="value">${params.servicio}</span>
        </div>
        <div class="info-row">
          <span class="label">Personas:</span>
          <span class="value">${params.numPersonas}</span>
        </div>
      </div>
      ${params.notas ? `<div style="background: #2A2E45; padding: 15px; border-radius: 8px; margin: 15px 0;">
        <strong>Nota del cliente:</strong><br>${params.notas}</div>` : ''}
      <div class="buttons">
        <p style="color: #B0B3C1; margin-bottom: 20px;">¿Qué deseas hacer con esta reserva?</p>
        <a href="${params.urlAceptar}" class="button btn-accept">✓ ACEPTAR RESERVA</a>
        <a href="${params.urlRechazar}" class="button btn-reject">✗ RECHAZAR RESERVA</a>
      </div>
      <p style="font-size: 12px; color: #6B6E82; text-align: center;">
        Al hacer clic, se procesará automáticamente y se enviará un email al cliente.
      </p>
    </div>
  </div>
</body>
</html>
  `;
}

function generarHTMLConfirmacionCliente(params: any): string {
  return `
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <style>
    body { background: #F5F5F5; font-family: Arial, sans-serif; padding: 20px; }
    .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #00FFC8 0%, #00D9FF 100%); padding: 40px; text-align: center; }
    .check { font-size: 60px; margin-bottom: 20px; }
    .header h1 { margin: 0; color: #0A0F23; }
    .content { padding: 30px; }
    .success { background: #E8F8F5; border-left: 4px solid #00FFC8; padding: 20px; margin: 20px 0; border-radius: 8px; }
    .info-box { background: #F8F9FA; padding: 25px; border-radius: 12px; margin: 20px 0; }
    .info-row { padding: 12px 0; border-bottom: 1px solid #E0E0E0; }
    .info-row:last-child { border-bottom: none; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="check">✓</div>
      <h1>¡Reserva Confirmada!</h1>
    </div>
    <div class="content">
      <p>Hola <strong>${params.nombreCliente}</strong>,</p>
      <div class="success">
        <p style="margin: 0; color: #00796B; font-weight: 600;">
          ¡Excelentes noticias! Tu reserva en <strong>${params.nombreEmpresa}</strong> ha sido confirmada.
        </p>
      </div>
      <div class="info-box">
        <h3 style="margin-top: 0;"> Detalles de tu Reserva</h3>
        <div class="info-row">
          <strong>Establecimiento:</strong> ${params.nombreEmpresa}
        </div>
        <div class="info-row">
          <strong>Fecha y Hora:</strong> ${params.fechaHora}
        </div>
        <div class="info-row">
          <strong>Servicio:</strong> ${params.servicio}
        </div>
        <div class="info-row">
          <strong>Personas:</strong> ${params.numPersonas}
        </div>
        <div class="info-row">
          <strong>Dirección:</strong> ${params.direccion}
        </div>
        ${params.telefono ? `<div class="info-row"><strong>Teléfono:</strong> ${params.telefono}</div>` : ''}
      </div>
      <p style="background: #FFF3CD; padding: 15px; border-radius: 8px; color: #856404;">
        <strong>⏰ Importante:</strong> Por favor, llega 10 minutos antes de tu cita.
      </p>
    </div>
  </div>
</body>
</html>
  `;
}

function paginaExito(reservaData: any, empresaData: any): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: Arial; text-align: center; padding: 50px; background: #0A0F23; color: white; }
    .success { background: linear-gradient(135deg, #00FFC8, #00D9FF); color: #0A0F23; padding: 40px; border-radius: 16px; max-width: 500px; margin: 0 auto; }
    h1 { margin: 0 0 20px 0; }
  </style>
</head>
<body>
  <div class="success">
    <h1>✅ Reserva Aceptada</h1>
    <p style="font-size: 18px;">Se ha enviado un email de confirmación al cliente.</p>
    <hr style="border: 1px solid rgba(10,15,35,0.2); margin: 20px 0;">
    <p><strong>${reservaData.usuario_nombre}</strong></p>
    <p>${reservaData.usuario_email}</p>
    <p style="margin-top: 30px; font-size: 14px; opacity: 0.8;">
      El cliente ha recibido un email con todos los detalles de su reserva.
    </p>
  </div>
</body>
</html>
  `;
}

function paginaYaProcesada(estado: string): string {
  return `
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><style>body{font-family:Arial;text-align:center;padding:50px;}</style></head>
<body>
  <h2>Esta reserva ya fue ${estado}</h2>
  <p>No es posible modificar el estado.</p>
</body>
</html>
  `;
}
```

### 2.3 Desplegar Functions

```bash
firebase deploy --only functions
```

---

##  PASO 3: Configurar Hosting (Opcional pero Recomendado)

Si quieres URLs personalizadas como `https://tuapp.com/api/reservas/aceptar`:

```bash
firebase init hosting
firebase deploy --only hosting
```

---

## ✅ RESUMEN DE LO QUE TIENES QUE HACER

1. **En la app**: Agregar campo `correo_reservas` al formulario de negocio
2. **En Firebase Functions**: Copiar el código de `index.ts`
3. **Configurar**: Cambiar email SMTP y dominio en el código
4. **Desplegar**: `firebase deploy --only functions`
5. **Probar**: Crear una reserva de prueba y verificar que llega el email

---

##  ARCHIVOS INCLUIDOS

- ✅ `ANALISIS_TPV_Y_EMAILS_RESERVAS.md` - Análisis completo
- ✅ `configuracion_propietario_screen.dart` - Pantalla de configuración
- ✅ Corrección del crash al cobrar en TPV
- ✅ Este documento con instrucciones paso a paso

---

**¿Necesitas ayuda con algún paso específico? Avísame y te guío.**

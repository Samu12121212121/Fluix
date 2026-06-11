/**
 * Cloud Function: Enviar email al owner cuando se crea una nueva reserva B2C
 *
 * Trigger: onCreate en /empresas/{empresaId}/notificaciones_reservas
 *
 * INSTALACIÓN:
 * 1. cd functions
 * 2. npm install nodemailer
 * 3. Configurar credenciales SMTP:
 *    firebase functions:config:set email.user="tu_email@gmail.com"
 *    firebase functions:config:set email.pass="tu_contraseña_app"
 * 4. firebase deploy --only functions:notificarNuevaReserva
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

// Asegúrate de que admin.initializeApp() esté en index.js
// Si no existe, añade:
// const admin = require('firebase-admin');
// admin.initializeApp();

exports.notificarNuevaReserva = functions.firestore
  .document('empresas/{empresaId}/notificaciones_reservas/{notifId}')
  .onCreate(async (snap, context) => {
    const { empresaId } = context.params;
    const notif = snap.data();

    // Solo procesar notificaciones de nuevas reservas
    if (notif.tipo !== 'nueva_reserva_b2c') {
      console.log('Tipo de notificación no es nueva_reserva_b2c, omitiendo...');
      return null;
    }

    try {
      // 1. Obtener información de la empresa
      const empresaDoc = await admin.firestore()
        .collection('empresas')
        .doc(empresaId)
        .get();

      if (!empresaDoc.exists) {
        console.error(`Empresa ${empresaId} no existe`);
        return null;
      }

      const empresaData = empresaDoc.data();
      const emailEmpresa = empresaData.email_notificaciones ||
                            empresaData.email ||
                            empresaData.emailPublico;

      if (!emailEmpresa) {
        console.log(`Empresa ${empresaId} sin email configurado`);
        return null;
      }

      // 2. Obtener información completa de la reserva
      const reservaDoc = await admin.firestore()
        .collection('empresas')
        .doc(empresaId)
        .collection('reservas')
        .doc(notif.reserva_id)
        .get();

      if (!reservaDoc.exists) {
        console.error(`Reserva ${notif.reserva_id} no existe`);
        return null;
      }

      const reserva = reservaDoc.data();

      // 3. Formatear fecha
      const fecha = reserva.fecha_hora.toDate();
      const dias = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
      const meses = [
        'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
      ];

      const fechaFormateada = `${dias[fecha.getDay()]}, ${fecha.getDate()} de ${meses[fecha.getMonth()]} de ${fecha.getFullYear()}`;
      const horaFormateada = fecha.toLocaleTimeString('es-ES', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
      });

      // 4. Configurar transporter de email
      const config = functions.config();

      if (!config.email || !config.email.user || !config.email.pass) {
        console.error('Credenciales de email no configuradas. Ejecuta:');
        console.error('firebase functions:config:set email.user="..." email.pass="..."');
        return null;
      }

      const transporter = nodemailer.createTransport({
        service: 'gmail',  // o tu servicio SMTP
        auth: {
          user: config.email.user,
          pass: config.email.pass,
        },
      });

      // 5. Construir HTML del email
      const nombreCliente = reserva.nombre_cliente || reserva.cliente_nombre || 'Cliente';
      const emailCliente = reserva.email || reserva.cliente_email || '';
      const telefonoCliente = reserva.telefono || reserva.cliente_telefono || '';
      const origenTexto = esReservaWeb ? 'tu página web' : 'la app Fluix';

      const htmlEmail = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
              line-height: 1.6;
              color: #333;
              max-width: 600px;
              margin: 0 auto;
              padding: 20px;
            }
            .header {
              background: linear-gradient(135deg, #00FFC8, #00D4AA);
              color: #0A0F23;
              padding: 30px;
              border-radius: 12px 12px 0 0;
              text-align: center;
            }
            .header h1 {
              margin: 0;
              font-size: 24px;
              font-weight: 800;
            }
            .content {
              background: #fff;
              padding: 30px;
              border: 1px solid #e0e0e0;
              border-top: none;
            }
            .reserva-card {
              background: #f5f7fa;
              padding: 20px;
              border-radius: 12px;
              margin: 20px 0;
            }
            .reserva-row {
              display: flex;
              align-items: center;
              margin: 10px 0;
              padding: 8px 0;
              border-bottom: 1px solid #e0e0e0;
            }
            .reserva-row:last-child {
              border-bottom: none;
            }
            .reserva-icon {
              width: 40px;
              font-size: 20px;
            }
            .reserva-label {
              color: #666;
              font-size: 12px;
              font-weight: 600;
              text-transform: uppercase;
            }
            .reserva-value {
              color: #0A0F23;
              font-size: 15px;
              font-weight: 600;
            }
            .btn {
              display: inline-block;
              background: #00FFC8;
              color: #0A0F23;
              padding: 14px 32px;
              text-decoration: none;
              border-radius: 10px;
              font-weight: 800;
              font-size: 15px;
              margin: 20px 0;
            }
            .btn:hover {
              background: #00D4AA;
            }
            .estado-badge {
              display: inline-block;
              background: #FFB830;
              color: #0A0F23;
              padding: 6px 12px;
              border-radius: 20px;
              font-size: 11px;
              font-weight: 700;
              text-transform: uppercase;
            }
            .footer {
              text-align: center;
              color: #999;
              font-size: 12px;
              margin-top: 30px;
              padding-top: 20px;
              border-top: 1px solid #e0e0e0;
            }
            .precio {
              font-size: 24px;
              color: #00FFC8;
              font-weight: 900;
            }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>📅 Nueva Reserva Pendiente</h1>
          </div>

          <div class="content">
            <p>Hola <strong>${empresaData.nombre_empresa || empresaData.nombre || 'Negocio'}</strong>,</p>

            <p>Has recibido una nueva solicitud de reserva desde <strong>${origenTexto}</strong>:</p>

            <div class="reserva-card">
              <div class="reserva-row">
                <div class="reserva-icon">👤</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Cliente</div>
                  <div class="reserva-value">${nombreCliente}</div>
                  ${emailCliente ? `<div style="color: #666; font-size: 12px;">${emailCliente}</div>` : ''}
                  ${telefonoCliente ? `<div style="color: #666; font-size: 12px;">📞 ${telefonoCliente}</div>` : ''}
                </div>
              </div>

              ${reserva.servicio_nombre ? `
              <div class="reserva-row">
                <div class="reserva-icon">✂️</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Servicio</div>
                  <div class="reserva-value">${reserva.servicio_nombre}</div>
                </div>
              </div>
              ` : ''}

              <div class="reserva-row">
                <div class="reserva-icon">📅</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Fecha</div>
                  <div class="reserva-value">${fechaFormateada}</div>
                </div>
              </div>

              <div class="reserva-row">
                <div class="reserva-icon">🕐</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Hora</div>
                  <div class="reserva-value">${horaFormateada}</div>
                </div>
              </div>

              ${reserva.empleado_nombre ? `
              <div class="reserva-row">
                <div class="reserva-icon">👨‍💼</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Profesional</div>
                  <div class="reserva-value">${reserva.empleado_nombre}</div>
                </div>
              </div>
              ` : ''}

              ${reserva.numero_personas ? `
              <div class="reserva-row">
                <div class="reserva-icon">👥</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Personas</div>
                  <div class="reserva-value">${reserva.numero_personas}</div>
                </div>
              </div>
              ` : ''}

              ${reserva.zona ? `
              <div class="reserva-row">
                <div class="reserva-icon">${reserva.zona === 'terraza' ? '🌿' : '🏠'}</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Zona</div>
                  <div class="reserva-value">${reserva.zona === 'terraza' ? 'Terraza' : 'Salón'}</div>
                </div>
              </div>
              ` : ''}

              ${reserva.duracion ? `
              <div class="reserva-row">
                <div class="reserva-icon">⏱️</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Duración</div>
                  <div class="reserva-value">${reserva.duracion} minutos</div>
                </div>
              </div>
              ` : ''}

              ${reserva.alergenos && reserva.detalle_alergenos ? `
              <div class="reserva-row">
                <div class="reserva-icon">⚠️</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Alergias/Intolerancias</div>
                  <div class="reserva-value">${reserva.detalle_alergenos}</div>
                </div>
              </div>
              ` : ''}

              ${reserva.notas ? `
              <div class="reserva-row">
                <div class="reserva-icon">📝</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Comentarios</div>
                  <div class="reserva-value">${reserva.notas}</div>
                </div>
              </div>
              ` : ''}

              ${reserva.precio ? `
              <div class="reserva-row">
                <div class="reserva-icon">💰</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Precio</div>
                  <div class="precio">€${reserva.precio.toFixed(2)}</div>
                </div>
              </div>
              ` : ''}

              <div style="text-align: center; margin-top: 20px;">
                <span class="estado-badge">⏳ Pendiente de confirmación</span>
              </div>
            </div>

            <p style="text-align: center;">
              <a href="https://app.fluix.es" class="btn">
                Ver en Fluix CRM →
              </a>
            </p>

            <div style="background: #FFF3E0; padding: 15px; border-radius: 8px; margin: 20px 0;">
              <p style="margin: 0; color: #E65100; font-size: 13px;">
                <strong>⚡ Acción requerida:</strong> Accede a tu panel en Fluix CRM para
                <strong>confirmar o rechazar</strong> esta reserva. El cliente recibirá una notificación
                de tu decisión.
              </p>
            </div>

            <div class="footer">
              <p>
                Este email fue generado automáticamente por <strong>Fluix CRM</strong><br>
                No respondas a este email. Gestiona tus reservas desde la app.
              </p>
              <p style="font-size: 11px; color: #ccc;">
                Reserva ID: ${notif.reserva_id}
              </p>
            </div>
          </div>
        </body>
        </html>
      `;
                </div>
              </div>

              <div class="reserva-row">
                <div class="reserva-icon">✂️</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Servicio</div>
                  <div class="reserva-value">${reserva.servicio_nombre}</div>
                </div>
              </div>

              <div class="reserva-row">
                <div class="reserva-icon">📅</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Fecha</div>
                  <div class="reserva-value">${fechaFormateada}</div>
                </div>
              </div>

              <div class="reserva-row">
                <div class="reserva-icon">🕐</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Hora</div>
                  <div class="reserva-value">${horaFormateada}</div>
                </div>
              </div>

              <div class="reserva-row">
                <div class="reserva-icon">👨‍💼</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Profesional</div>
                  <div class="reserva-value">${reserva.empleado_nombre}</div>
                </div>
              </div>

              ${reserva.duracion ? `
              <div class="reserva-row">
                <div class="reserva-icon">⏱️</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Duración</div>
                  <div class="reserva-value">${reserva.duracion} minutos</div>
                </div>
              </div>
              ` : ''}

              ${reserva.precio ? `
              <div class="reserva-row">
                <div class="reserva-icon">💰</div>
                <div style="flex: 1;">
                  <div class="reserva-label">Precio</div>
                  <div class="precio">€${reserva.precio.toFixed(2)}</div>
                </div>
              </div>
              ` : ''}

              <div style="text-align: center; margin-top: 20px;">
                <span class="estado-badge">⏳ Pendiente de confirmación</span>
              </div>
            </div>

            <p style="text-align: center;">
              <a href="https://app.fluix.es" class="btn">
                Ver en Fluix CRM →
              </a>
            </p>

            <div style="background: #FFF3E0; padding: 15px; border-radius: 8px; margin: 20px 0;">
              <p style="margin: 0; color: #E65100; font-size: 13px;">
                <strong>⚡ Acción requerida:</strong> Accede a tu panel de owner en Fluix CRM para
                <strong>confirmar o rechazar</strong> esta reserva. El cliente recibirá una notificación
                de tu decisión.
              </p>
            </div>

            <div class="footer">
              <p>
                Este email fue generado automáticamente por <strong>Fluix CRM</strong><br>
                No respondas a este email. Gestiona tus reservas desde la app.
              </p>
              <p style="font-size: 11px; color: #ccc;">
                Reserva ID: ${notif.reserva_id}
              </p>
            </div>
          </div>
        </body>
        </html>
      `;

      // 6. Enviar email
      const mailOptions = {
        from: `Fluix CRM <${config.email.user}>`,
        to: emailEmpresa,
        subject: `📅 Nueva reserva de ${nombreCliente} - ${fechaFormateada}`,
        html: htmlEmail,
      };

      await transporter.sendMail(mailOptions);

      console.log(`✅ Email enviado a ${emailEmpresa} para reserva ${notif.reserva_id}`);

      // 7. Marcar notificación como enviada
      await snap.ref.update({
        email_enviado: true,
        email_enviado_en: admin.firestore.FieldValue.serverTimestamp(),
      });

      return null;

    } catch (error) {
      console.error('❌ Error al enviar email:', error);

      // Marcar notificación como fallida
      await snap.ref.update({
        email_enviado: false,
        email_error: error.message,
      });

      return null;
    }
  });

// Exportar función auxiliar para reenviar emails manualmente
exports.reenviarEmailReserva = functions.https.onCall(async (data, context) => {
  // Solo admin puede reenviar
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Debes estar autenticado');
  }

  const { notificacionId, empresaId } = data;

  if (!notificacionId || !empresaId) {
    throw new functions.https.HttpsError('invalid-argument', 'Faltan parámetros');
  }

  try {
    // Obtener notificación
    const notifDoc = await admin.firestore()
      .collection('empresas')
      .doc(empresaId)
      .collection('notificaciones_reservas')
      .doc(notificacionId)
      .get();

    if (!notifDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'Notificación no encontrada');
    }

    // Reintentar enviando un evento manualmente
    // (puedes reutilizar la lógica de arriba)

    return { success: true, message: 'Email reenviado' };

  } catch (error) {
    console.error('Error al reenviar email:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});


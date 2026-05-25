import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';

const db = admin.firestore();

// Notificar check-in
export const onCheckinFidelizacion = functions.firestore.onDocumentCreated({
  document: 'negocios_publicos/{negocioId}/checkins/{checkinId}',
  region: 'europe-west1',
}, async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const clienteId = data.cliente_id;
  const negocioId = event.params.negocioId;
  const recompensaDesbloqueada = data.recompensa_desbloqueada || false;

  const negocioDoc = await db.doc(`negocios_publicos/${negocioId}`).get();
  const negocioNombre = negocioDoc.data()?.nombre || 'Negocio';

  const clienteDoc = await db.doc(`usuarios/${clienteId}`).get();
  const fcmToken = clienteDoc.data()?.fcmToken;
  if (!fcmToken) return;

  const title = recompensaDesbloqueada ? '¡Recompensa desbloqueada! 🎉' : `¡+1 sello en ${negocioNombre}! ☕`;
  const body = recompensaDesbloqueada ? `Has conseguido: ${data.recompensa_titulo || 'Recompensa'}` : 'Te queda menos para tu recompensa';

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data: { type: 'checkin_fidelizacion', negocio_id: negocioId },
      android: { priority: 'high', notification: { sound: 'default', channelId: 'fidelizacion' } },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    });
  } catch (error) {
    console.error('Error enviando notificación de check-in:', error);
  }
});

// Notificar canje
export const onCanjeRecompensa = functions.firestore.onDocumentUpdated({
  document: 'negocios_publicos/{negocioId}/qr_canjes/{qrId}',
  region: 'europe-west1',
}, async (event) => {
  const antes = event.data?.before.data();
  const despues = event.data?.after.data();

  if (antes?.estado === 'pendiente' && despues?.estado === 'canjeado') {
    const negocioId = event.params.negocioId;
    const negocioDoc = await db.doc(`negocios_publicos/${negocioId}`).get();
    const adminIds = negocioDoc.data()?.adminIds || [];

    for (const adminId of adminIds) {
      try {
        const adminDoc = await db.doc(`usuarios/${adminId}`).get();
        const fcmToken = adminDoc.data()?.fcmToken;
        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: { title: 'Recompensa canjeada ✅', body: `${despues.cliente_nombre} canjeó: ${despues.recompensa_titulo}` },
            data: { type: 'canje_confirmado', negocio_id: negocioId },
            android: { priority: 'high', notification: { sound: 'default', channelId: 'negocio' } },
          });
        }
      } catch (error) {
        console.error(`Error notificando a admin ${adminId}:`, error);
      }
    }
  }
});

// Marcar QRs expirados (cada hora)
export const marcarQRsExpirados = functions.scheduler.onSchedule({
  schedule: '0 * * * *',
  timeZone: 'Europe/Madrid',
  region: 'europe-west1',
}, async () => {
  const ahora = admin.firestore.Timestamp.now();
  const snapshot = await db.collectionGroup('qr_canjes').where('estado', '==', 'pendiente').where('expira_at', '<=', ahora).limit(500).get();
  if (snapshot.empty) return;

  const batch = db.batch();
  snapshot.docs.forEach(doc => batch.update(doc.ref, { estado: 'expirado' }));
  await batch.commit();
  console.log(`Marcados ${snapshot.size} QRs como expirados`);
});

// Verificar caducidad sellos (3 AM diario)
export const verificarCaducidadSellos = functions.scheduler.onSchedule({
  schedule: '0 3 * * *',
  timeZone: 'Europe/Madrid',
  region: 'europe-west1',
}, async () => {
  const programasSnap = await db.collectionGroup('programa_fidelizacion').where('activo', '==', true).where('caducidad_meses', '>', 0).get();
  if (programasSnap.empty) return;

  for (const programaDoc of programasSnap.docs) {
    const programa = programaDoc.data();
    const negocioId = programa.negocio_id;
    const caducidadMeses = programa.caducidad_meses;

    const fechaLimite = new Date();
    fechaLimite.setMonth(fechaLimite.getMonth() - caducidadMeses);
    const timestampLimite = admin.firestore.Timestamp.fromDate(fechaLimite);

    const tarjetasSnap = await db.collectionGroup('tarjetas_sellos')
      .where('negocio_id', '==', negocioId)
      .where('sellos_actuales', '>', 0)
      .where('ultimo_checkin', '<', timestampLimite)
      .get();

    if (tarjetasSnap.empty) continue;

    const batch = db.batch();
    tarjetasSnap.docs.forEach(tarjetaDoc => {
      batch.update(tarjetaDoc.ref, { sellos_actuales: 0, actualizado_at: admin.firestore.FieldValue.serverTimestamp() });
    });
    await batch.commit();
    console.log(`Procesados ${tarjetasSnap.size} tarjetas caducadas del negocio ${negocioId}`);
  }
});


import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════════
// TRIGGER: Envío de solicitud de valoración post-cita
// ═══════════════════════════════════════════════════════════════════
export const onReservaCompletada = functions.firestore
  .onDocumentUpdated({
    document: 'reservas/{reservaId}',
    region: 'europe-west1',
    maxInstances: 10,
  }, async (event) => {
    const antes = event.data?.before.data();
    const despues = event.data?.after.data();
    if (!antes ||!despues) return;

    // Solo si cambió a "completada" ahora
    if (antes.estado !== 'completada' && despues.estado === 'completada') {
      const r = despues as any;
      const clienteId = r.clienteId;
      const negocioId = r.negocioId;const reservaId = event.params.reservaId;
      if (!clienteId || !negocioId) return;

      try {
        // Verificar que no se ha valorado ya
        const valRef = db.collection(`negocios_publicos/${negocioId}/valoraciones`).where('reservaId', '==', reservaId).limit(1);
        const snap = await valRef.get();
        if (!snap.empty) return; // Ya valorado

        // Obtener datos del cliente y negocio
        const [clienteDoc, negocioDoc] = await Promise.all([
          db.doc(`clientes/${clienteId}`).get(),
          db.doc(`negocios_publicos/${negocioId}`).get(),
        ]);
        const cliente = clienteDoc.data();
        const negocio = negocioDoc.data();
        if (!cliente || !negocio) return;

        // Enviar notificación push al cliente
        const fcmToken = cliente.fcmToken;
        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: '¿Cómo fue tu visita?',
              body: `Cuéntanos tu experiencia en ${negocio.nombre || 'el negocio'}`,
            },
            data: {
              type: 'solicitud_valoracion',
              negocioId,
              reservaId,
              negocioNombre: negocio.nombre || '',
            },
          });
        }

        // Crear notificación persistente
        await db.collection(`clientes/${clienteId}/notificaciones`).add({
          tipo: 'solicitud_valoracion',
          titulo: '¿Cómo fue tu visita?',
          mensaje: `Comparte tu experiencia en ${negocio.nombre}`,
          negocioId,
          reservaId,
          negocioNombre: negocio.nombre || '',
          negocioFoto: negocio.fotoUrl || null,
          leida: false,
          creadoAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`✓ Solicitud valoración enviada: ${reservaId} → ${clienteId}`);
      } catch (err) {
        console.error('Error enviando solicitud valoración:', err);
      }
    }
  });

// ═══════════════════════════════════════════════════════════════════
// TRIGGER: Recalcular rating Fluix al publicar/editar valoración
// ═══════════════════════════════════════════════════════════════════
export const onValoracionWrite = functions.firestore
  .onDocumentWritten({
    document: 'negocios_publicos/{negocioId}/valoraciones/{valoracionId}',
    region: 'europe-west1',
    maxInstances: 10,
  }, async (event) => {
    const negocioId = event.params.negocioId;
    try {
      const valSnap = await db.collection(`negocios_publicos/${negocioId}/valoraciones`).get();
      const total = valSnap.size;
      if (total === 0) {
        await db.doc(`negocios_publicos/${negocioId}`).update({
          ratingFluix: null,
          totalValoraciones: 0,
        });
        return;
      }

      let sumaEstrellas = 0;
      valSnap.forEach((doc) => {
        const val = doc.data();
        sumaEstrellas += val.estrellas || 0;
      });

      const ratingPromedio = parseFloat((sumaEstrellas / total).toFixed(2));
      await db.doc(`negocios_publicos/${negocioId}`).update({
        ratingFluix: ratingPromedio,
        totalValoraciones: total,
      });

      console.log(`✓ Rating Fluix recalculado: ${negocioId} → ${ratingPromedio} (${total} valoraciones)`);
    } catch (err) {
      console.error('Error recalculando rating:', err);
    }
  });

// ═══════════════════════════════════════════════════════════════════
// TRIGGER: Notificar al negocio cuando recibe valoración baja
// ═══════════════════════════════════════════════════════════════════
export const onValoracionBaja = functions.firestore
  .onDocumentCreated({
    document: 'negocios_publicos/{negocioId}/valoraciones/{valoracionId}',
    region: 'europe-west1',
    maxInstances: 10,
  }, async (event) => {
    const val = event.data?.data();
    if (!val) return;

    if (val.estrellas <= 3) {
      const negocioId = event.params.negocioId;
      try {
        const negocioDoc = await db.doc(`negocios_publicos/${negocioId}`).get();
        const negocio = negocioDoc.data();
        if (!negocio) return;

        const adminIds = negocio.adminIds || [];
        for (const adminId of adminIds) {
          const adminDoc = await db.doc(`usuarios/${adminId}`).get();
          const admin = adminDoc.data();
          if (!admin) continue;

          const fcmToken = admin.fcmToken;
          if (fcmToken) {
            await admin.messaging().send({
              token: fcmToken,
              notification: {
                title: '⚠️ Valoración baja recibida',
                body: `${val.clienteNombre} ha dejado ${val.estrellas}★ en tu negocio`,
              },
              data: {
                type: 'valoracion_baja',
                negocioId,
                valoracionId: event.params.valoracionId,
                estrellas: val.estrellas.toString(),
              },
            });
          }

          await db.collection(`usuarios/${adminId}/notificaciones`).add({
            tipo: 'valoracion_baja',
            titulo: '⚠️ Valoración baja recibida',
            mensaje: `${val.clienteNombre} ha dejado ${val.estrellas}★`,
            negocioId,
            valoracionId: event.params.valoracionId,
            leida: false,
            creadoAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        console.log(`✓ Notificación valoración baja enviada: ${negocioId}`);
      } catch (err) {
        console.error('Error notificando valoración baja:', err);
      }
    }
  });

// ═══════════════════════════════════════════════════════════════════
// CALLABLE: Eliminar valoración (solo admins)
// ═══════════════════════════════════════════════════════════════════
export const eliminarValoracion = functions.https.onCall({
  region: 'europe-west1',
  maxInstances: 5,
}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new functions.https.HttpsError('unauthenticated', 'No autenticado');

  const { negocioId, valoracionId } = request.data;
  if (!negocioId || !valoracionId) {
    throw new functions.https.HttpsError('invalid-argument', 'Faltan parámetros');
  }

  try {
    // Verificar que el usuario es admin del negocio
    const negocioDoc = await db.doc(`negocios_publicos/${negocioId}`).get();
    const negocio = negocioDoc.data();
    if (!negocio) throw new functions.https.HttpsError('not-found', 'Negocio no existe');

    const adminIds = negocio.adminIds || [];
    if (!adminIds.includes(uid)) {
      throw new functions.https.HttpsError('permission-denied', 'No eres admin de este negocio');
    }

    await db.doc(`negocios_publicos/${negocioId}/valoraciones/${valoracionId}`).delete();
    return { success: true };
  } catch (err: any) {
    console.error('Error eliminando valoración:', err);
    throw new functions.https.HttpsError('internal', err.message || 'Error desconocido');
  }
});


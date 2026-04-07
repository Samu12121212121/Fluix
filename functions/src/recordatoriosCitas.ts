import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

// ⚠️ NO inicializar admin.firestore() a nivel de módulo.
//    Debe estar dentro del handler para que initializeApp() ya haya corrido.

export const enviarRecordatoriosCitas = onSchedule("every 1 hours", async (event) => {
    const db = admin.firestore(); // ← aquí, dentro del handler
    const now = new Date();

    // Rango de búsqueda: citas entre 23h y 25h desde ahora
    const start = new Date(now.getTime() + 23 * 60 * 60 * 1000);
    const end = new Date(now.getTime() + 25 * 60 * 60 * 1000); // Amplio margen para no perder ninguna

    console.log(`Buscando citas para recordar entre ${start.toISOString()} y ${end.toISOString()}`);

    // Nota: 'fecha_hora' se asume ISO String almacenado en Firestore por Flutter
    const snapshot = await db.collectionGroup("citas")
        .where("fecha_hora", ">=", start.toISOString())
        .where("fecha_hora", "<=", end.toISOString())
        .get();

    if (snapshot.empty) {
        console.log("No hay citas próximas para recordar.");
        return;
    }

    const promises: Promise<any>[] = [];

    snapshot.docs.forEach(doc => {
        const cita = doc.data();

        // Evitar duplicados
        if (cita.recordatorioEnviado === true) {
            return;
        }

        const clienteId = cita.cliente_id;
        // La referencia es: empresas/{empresaId}/citas/{citaId}
        const empresaRef = doc.ref.parent.parent;
        if (!empresaRef) return;

        const empresaId = empresaRef.id;

        if (!clienteId) return;

        const p = (async () => {
            try {
                // Obtener datos del cliente para el token FCM
                // Si ya guardamos el fcmToken en la cita, lo usamos directo.
                // Si no, lo buscamos.
                let fcmToken = cita.fcmToken;
                let nombreCliente = cita.nombre_cliente;

                if (!fcmToken) {
                    const clienteDoc = await db.collection("empresas").doc(empresaId).collection("clientes").doc(clienteId).get();
                    if (clienteDoc.exists) {
                        const cliente = clienteDoc.data();
                        fcmToken = cliente?.fcmToken;
                        nombreCliente = cliente?.nombre || nombreCliente;
                    }
                }

                if (fcmToken) {
                    // Enviar notificación FCM
                    const message = {
                        notification: {
                            title: "📅 Recordatorio de Cita",
                            body: `Hola ${nombreCliente}, recuerda tu cita mañana a las ${new Date(cita.fecha_hora).toLocaleTimeString("es-ES", {hour: "2-digit", minute:"2-digit"})}.`,
                        },
                        token: fcmToken
                    };

                    await admin.messaging().send(message);
                    console.log(`Notificación enviada a cliente ${clienteId} para cita ${doc.id}`);
                }

                // Marcar como enviada
                await doc.ref.update({
                    recordatorioEnviado: true,
                    fechaRecordatorio: admin.firestore.FieldValue.serverTimestamp()
                });

            } catch (error) {
                console.error(`Error procesando recordatorio para cita ${doc.id}:`, error);
            }
        })();

        promises.push(p);
    });

    await Promise.all(promises);
});

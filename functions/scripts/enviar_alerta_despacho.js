/**
 * enviar_alerta_despacho.js
 * Crea una alerta de despacho en Firestore y envía FCM a un usuario.
 *
 * Uso:
 *   node functions/scripts/enviar_alerta_despacho.js --uid <UID_OPERARIO>
 *   node functions/scripts/enviar_alerta_despacho.js --email elena.martin@fluixtest.com
 */
const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db        = admin.firestore();
const messaging = admin.messaging();
const Timestamp  = admin.firestore.Timestamp;

const EID = 'demo_ambulancias_guadalajara_2026';
const TIPOS = ['PCR', 'TCE', 'IAM', 'TRAUMA', 'SVB', 'POLITRAUMA'];
const DIRECCIONES = [
  { dir: 'Calle Mayor 42', local: 'Guadalajara', ref: 'Junto al banco Santander' },
  { dir: 'Avda. del Ejército 15', local: 'Guadalajara', ref: 'Entrada por garaje' },
  { dir: 'Paseo de la Estación 8', local: 'Azuqueca de Henares', ref: null },
  { dir: 'Calle Sigüenza 3', local: 'Guadalajara', ref: 'Portal izquierda, 2ºA' },
];

async function main() {
  // ── Resolver UID del operario ─────────────────────────────────────────────
  let operarioUid = null;
  const uidIdx   = process.argv.indexOf('--uid');
  const emailIdx = process.argv.indexOf('--email');

  if (uidIdx !== -1) {
    operarioUid = process.argv[uidIdx + 1];
  } else if (emailIdx !== -1) {
    const email = process.argv[emailIdx + 1];
    const user  = await admin.auth().getUserByEmail(email);
    operarioUid = user.uid;
    console.log('UID para', email, ':', operarioUid);
  } else {
    // Por defecto: Elena
    operarioUid = 'pZXLiG99ODfBe0Z2BGeGqWwvLcs2';
    console.log('Usando Elena (default):', operarioUid);
  }

  // ── Leer token FCM del usuario ────────────────────────────────────────────
  const userDoc = await db.collection('usuarios').doc(operarioUid).get();
  const token   = userDoc.data()?.token_dispositivo;
  if (!token) {
    console.error('❌ El usuario no tiene token FCM. Debe haber abierto la app al menos una vez.');
    process.exit(1);
  }

  // ── Crear alerta en Firestore ─────────────────────────────────────────────
  const tipo = TIPOS[Math.floor(Math.random() * TIPOS.length)];
  const dest = DIRECCIONES[Math.floor(Math.random() * DIRECCIONES.length)];
  const prioridad = tipo === 'PCR' || tipo === 'IAM' ? 'critica' : 'alta';

  const alertaRef = db.collection('empresas').doc(EID).collection('alertas_despacho').doc();
  const alerta = {
    empresa_id:          EID,
    tipo_codigo:         tipo,
    descripcion:         `${tipo} — Paciente con signos de ${tipo === 'PCR' ? 'parada cardiorrespiratoria' : tipo === 'IAM' ? 'infarto agudo de miocardio' : tipo === 'TCE' ? 'traumatismo craneoencefálico' : 'politraumatismo'}`,
    direccion:           dest.dir,
    localidad:           dest.local,
    referencia_mapa:     dest.ref,
    nombre_paciente:     null,
    edad_paciente:       Math.floor(Math.random() * 60) + 20,
    prioridad,
    ambulancia_asignada: 'A-07',
    medico_asignado:     'Dr. Hernández',
    estado:              'pendiente',
    operador_destino_uid: operarioUid,
    fecha_hora:          Timestamp.now(),
  };

  await alertaRef.set(alerta);
  console.log('✅ Alerta creada:', alertaRef.id);

  // ── Enviar FCM ────────────────────────────────────────────────────────────
  const titulo  = `🚨 DESPACHO ${prioridad.toUpperCase()} — ${tipo}`;
  const cuerpo  = `${dest.dir}, ${dest.local}${dest.ref ? ` (${dest.ref})` : ''}`;

  const message = {
    token,
    notification: { title: titulo, body: cuerpo },
    data: {
      tipo:       'alerta_despacho',
      empresa_id: EID,
      alerta_id:  alertaRef.id,
      prioridad,
    },
    android: {
      priority: 'high',
      notification: {
        channelId:         'sysday_despacho',
        priority:          'max',
        defaultSound:      true,
        defaultVibrateTimings: true,
        visibility:        'PUBLIC',
        notificationCount: 1,
      },
    },
    apns: {
      headers: { 'apns-priority': '10', 'apns-push-type': 'alert' },
      payload: {
        aps: {
          alert: { title: titulo, body: cuerpo },
          sound: 'default',
          badge: 1,
          'content-available': 1,
          'interruption-level': 'critical',
        },
      },
    },
  };

  const response = await messaging.send(message);
  console.log('✅ FCM enviado. Message ID:', response);
  console.log('\n📋 Alerta:', alertaRef.id);
  console.log('   Tipo:', tipo, '| Prioridad:', prioridad);
  console.log('   Destino:', dest.dir, dest.local);
  console.log('   Token (primeros 20):', token.substring(0, 20) + '...');
}

main().catch(e => { console.error('❌', e.message); process.exit(1); });

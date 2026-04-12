/**
 * crear_cuenta_demo.ts — Crea la cuenta demo demoFluix2026@gmail.com
 * USO: npx ts-node scripts/crear_cuenta_demo.ts
 * Requiere: credentials.json (Service Account) en la raíz del proyecto
 */
import * as admin from 'firebase-admin';
import * as path from 'path';

const serviceAccount = require(path.resolve(__dirname, '..', 'credentials.json'));

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const auth = admin.auth();
const db   = admin.firestore();

const DEMO_EMAIL      = 'demoFluix2026@gmail.com';
const DEMO_PASSWORD   = 'FlFluix26';
const DEMO_EMPRESA_ID = 'demo_empresa_fluix2026';
const TODOS_MODULOS   = [
  'dashboard','valoraciones','estadisticas','reservas','citas','web',
  'whatsapp','facturacion','pedidos','tareas','clientes','empleados',
  'nominas','vacaciones','servicios',
];

async function main() {
  console.log('🚀 Creando cuenta demo Fluix CRM...\n');
  const now      = admin.firestore.Timestamp.now();
  const fechaFin = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 365 * 24 * 60 * 60 * 1000)
  );

  // 1. Firebase Auth
  let uid: string;
  try {
    const u = await auth.getUserByEmail(DEMO_EMAIL);
    uid = u.uid;
    console.log(`✅ Auth ya existe — UID: ${uid}`);
  } catch (e: any) {
    if (e.code !== 'auth/user-not-found') throw e;
    const u = await auth.createUser({
      email: DEMO_EMAIL, password: DEMO_PASSWORD,
      displayName: 'Demo Fluix', emailVerified: true,
    });
    uid = u.uid;
    console.log(`✅ Auth creado — UID: ${uid}`);
  }

  // 2. Documento usuario
  const uRef = db.collection('usuarios').doc(uid);
  if (!(await uRef.get()).exists) {
    await uRef.set({
      nombre: 'Demo Fluix', correo: DEMO_EMAIL, telefono: '+34 900 000 000',
      empresa_id: DEMO_EMPRESA_ID, rol: 'admin', activo: true,
      fecha_creacion: now, permisos: [], es_demo: true,
      modulos_permitidos: TODOS_MODULOS,
    });
    console.log(`✅ usuarios/${uid} creado`);
  } else { console.log(`ℹ️  usuarios/${uid} ya existe`); }

  // 3. Empresa demo
  const eRef = db.collection('empresas').doc(DEMO_EMPRESA_ID);
  if (!(await eRef.get()).exists) {
    await eRef.set({
      nombre: 'Empresa Demo Fluix', correo: DEMO_EMAIL,
      telefono: '+34 900 000 000', direccion: 'Calle Demo 1, Madrid',
      categoria: 'Demostración', onboarding_completado: true,
      fecha_creacion: now, nif: 'B00000000',
      perfil: { nombre: 'Empresa Demo Fluix', correo: DEMO_EMAIL },
    });
    console.log(`✅ Empresa ${DEMO_EMPRESA_ID} creada`);
  } else { console.log(`ℹ️  Empresa ya existe`); }

  // 4. Suscripción
  const sRef = eRef.collection('suscripcion').doc('actual');
  if (!(await sRef.get()).exists) {
    await sRef.set({
      estado: 'ACTIVA', plan: 'completo', es_demo: true,
      fecha_inicio: now, fecha_fin: fechaFin, precio_anual: 0,
      modulos: TODOS_MODULOS,
    });
    console.log('✅ Suscripción creada');
  } else { console.log('ℹ️  Suscripción ya existe'); }

  // 5. Configuración módulos
  await eRef.collection('configuracion').doc('modulos').set({
    modulos: TODOS_MODULOS.map(id => ({ id, activo: true })),
    ultima_actualizacion: now,
  }, { merge: true });
  console.log('✅ Todos los módulos activados');

  // 6. Custom claims
  await auth.setCustomUserClaims(uid, {
    empresaId: DEMO_EMPRESA_ID, rol: 'admin', es_demo: true,
  });

  console.log('\n════════════════════════════════════════════');
  console.log('✅ CUENTA DEMO LISTA');
  console.log(`   Email:    ${DEMO_EMAIL}`);
  console.log(`   Password: ${DEMO_PASSWORD}`);
  console.log(`   UID:      ${uid}`);
  console.log(`   Empresa:  ${DEMO_EMPRESA_ID}`);
  console.log('════════════════════════════════════════════\n');
}

main().then(() => process.exit(0)).catch(e => { console.error('❌', e); process.exit(1); });


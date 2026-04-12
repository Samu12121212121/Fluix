/**
 * setup_demo.ts — Crea el documento Firestore para la cuenta demo existente.
 * La cuenta demoFluix2026@gmail.com ya existe en Firebase Auth con:
 *   UID: RjnhpAXBUWQhxlDgOm9PT0EcTIr2
 * USO: npx ts-node scripts/setup_demo.ts
 * Requiere: credentials.json (Service Account) en la raíz del proyecto
 */
import * as admin from 'firebase-admin';
import * as path  from 'path';

const serviceAccount = require(path.resolve(__dirname, '..', 'credentials.json'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const auth = admin.auth();
const db   = admin.firestore();

const DEMO_UID        = 'RjnhpAXBUWQhxlDgOm9PT0EcTIr2';
const DEMO_EMAIL      = 'demoFluix2026@gmail.com';
const DEMO_PASSWORD   = 'FlFluix26';
const DEMO_EMPRESA_ID = 'demo_empresa_fluix2026';
const TODOS_MODULOS   = [
  'dashboard','valoraciones','estadisticas','reservas','citas','web',
  'whatsapp','facturacion','pedidos','tareas','clientes','empleados',
  'nominas','vacaciones','servicios',
];

async function main() {
  console.log('🚀 Setup cuenta demo Fluix CRM\n');
  const now      = admin.firestore.Timestamp.now();
  const fechaFin = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
  );

  // 1. Verificar/reparar Firebase Auth
  try {
    const user = await auth.getUser(DEMO_UID);
    console.log(`✅ Auth UID ${DEMO_UID} existe — ${user.email}`);
    await auth.updateUser(DEMO_UID, { password: DEMO_PASSWORD, emailVerified: true, displayName: 'Demo Fluix CRM' });
  } catch (e: any) {
    if (e.code === 'auth/user-not-found') {
      await auth.createUser({ uid: DEMO_UID, email: DEMO_EMAIL, password: DEMO_PASSWORD, displayName: 'Demo Fluix CRM', emailVerified: true });
      console.log(`✅ Auth creado con UID ${DEMO_UID}`);
    } else { throw e; }
  }

  // 2. Documento usuarios/{uid}
  const uRef = db.collection('usuarios').doc(DEMO_UID);
  const uDoc: Record<string, unknown> = {
    nombre: 'Demo Fluix CRM', correo: DEMO_EMAIL, email: DEMO_EMAIL,
    telefono: '+34 900 000 000', empresa_id: DEMO_EMPRESA_ID,
    rol: 'admin', activo: true, es_demo: true, onboarding_completado: true,
    fecha_creacion: now, modulos_permitidos: TODOS_MODULOS, permisos: [],
  };
  await uRef.set(uDoc, { merge: true });
  console.log(`✅ usuarios/${DEMO_UID} OK`);

  // 3. Empresa
  const eRef = db.collection('empresas').doc(DEMO_EMPRESA_ID);
  const eDoc: Record<string, unknown> = {
    nombre: 'Empresa Demo Fluix', correo: DEMO_EMAIL, email: DEMO_EMAIL,
    telefono: '+34 900 000 000', direccion: 'Calle Demo 1, 28001 Madrid',
    categoria: 'Demostración', sector: 'hosteleria', tipo_negocio: 'Restaurante / Bar',
    onboarding_completado: true, es_demo: true, fecha_creacion: now, nif: 'B00000000',
    perfil: { nombre: 'Empresa Demo Fluix', correo: DEMO_EMAIL, email: DEMO_EMAIL,
              telefono: '+34 900 000 000', descripcion: 'Cuenta de demostración de Fluix CRM' },
  };
  await eRef.set(eDoc, { merge: true });
  console.log(`✅ empresas/${DEMO_EMPRESA_ID} OK`);

  // 4. Suscripción
  await eRef.collection('suscripcion').doc('actual').set(
    { estado: 'ACTIVA', plan: 'completo', es_demo: true, fecha_inicio: now, fecha_fin: fechaFin, precio_anual: 0, modulos: TODOS_MODULOS },
    { merge: true },
  );
  console.log('✅ Suscripción demo activa (1 año)');

  // 5. Módulos
  const modulosConfig: Record<string, boolean> = Object.fromEntries(TODOS_MODULOS.map((m) => [m, true]));
  await eRef.collection('configuracion').doc('modulos').set({ modulos: modulosConfig }, { merge: true });
  console.log('✅ Todos los módulos activados');

  // 6. Config general
  await eRef.collection('configuracion').doc('general').set(
    { moneda: 'EUR', idioma: 'es', zona_horaria: 'Europe/Madrid', formato_fecha: 'DD/MM/YYYY' },
    { merge: true },
  );

  console.log('\n🎉 Setup completado');
  console.log(`   Email:     ${DEMO_EMAIL}`);
  console.log(`   Password:  ${DEMO_PASSWORD}`);
  console.log(`   UID:       ${DEMO_UID}`);
  console.log(`   EmpresaId: ${DEMO_EMPRESA_ID}`);
  process.exit(0);
}

main().catch((e) => { console.error('❌', e); process.exit(1); });


/**
 * crear_cuentas_empleados_sanir.js
 * ─────────────────────────────────────────────────────────────────
 * Crea o resetea las cuentas Firebase Auth de los empleados de prueba
 * de Sanir Transporte Sanitario CLM (demo_sanir_clm_2026).
 *
 * — Si la cuenta ya existe (mismo email): resetea la contraseña.
 * — Si no existe: la crea con el UID canónico y vincula a Sanir.
 * — Desactiva 2FA para facilitar las pruebas.
 *
 * USO (desde functions/):
 *   node scripts/crear_cuentas_empleados_sanir.js
 * ─────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa), projectId: 'planeaapp-4bea4' });
}

const auth = admin.auth();
const db   = admin.firestore();
const EID  = 'demo_sanir_clm_2026';

// ── Cuentas de prueba ──────────────────────────────────────────────────────
// uid: UID canónico almacenado en Firestore. Si la cuenta se crea nueva,
//      se usa este UID. Si ya existe (mismo email), se usa el UID real de Auth
//      y se actualiza el doc de Firestore para que apunte al UID correcto.

const CUENTAS = [
  {
    uid:      'SpnOb0ySgRa7Zqe308u0bZx0YJ63',
    email:    'Test_Sanir_CLM@fluixtest.com',
    password: 'DemoSeed1972',
    nombre:   'Coordinador Demo',
    rol:      'admin',
  },
  {
    uid:      'pZXLiG99ODfBe0Z2BGeGqWwvLcs2',
    email:    'elena.martin@fluixtest.com',
    password: 'ElenaTES2026',
    nombre:   'Elena Martín Sanz',
    rol:      'staff',
  },
  {
    uid:      'U5TgqYNniEXV6sbqPTWSq3oSQYQ2',
    email:    'roberto.lopez@fluixtest.com',
    password: 'RobertoConduTES',
    nombre:   'Roberto López Vega',
    rol:      'staff',
  },
];

async function procesarCuenta(c) {
  let realUid;

  // 1. ¿Existe ya la cuenta con este email?
  try {
    const existing = await auth.getUserByEmail(c.email);
    realUid = existing.uid;
    // Resetear contraseña
    await auth.updateUser(realUid, {
      password:      c.password,
      emailVerified: true,
      displayName:   c.nombre,
    });
    console.log(`   ✔  ${c.email} ya existía (UID: ${realUid}) → contraseña reseteada`);
  } catch (e) {
    if (e.code !== 'auth/user-not-found') throw e;

    // 2. No existe: crear con el UID canónico
    try {
      const newUser = await auth.createUser({
        uid:           c.uid,
        email:         c.email,
        password:      c.password,
        displayName:   c.nombre,
        emailVerified: true,
      });
      realUid = newUser.uid;
      console.log(`   ✅ ${c.email} creada (UID: ${realUid})`);
    } catch (e2) {
      if (e2.code === 'auth/uid-already-exists') {
        // UID canónico ya tiene otro email: actualizar email+password
        await auth.updateUser(c.uid, {
          email:         c.email,
          password:      c.password,
          emailVerified: true,
          displayName:   c.nombre,
        });
        realUid = c.uid;
        console.log(`   ✅ UID ${c.uid} actualizado con email ${c.email}`);
      } else throw e2;
    }
  }

  // 3. Asegurar doc en Firestore con el UID real
  const uRef = db.collection('usuarios').doc(realUid);
  await uRef.set({
    uid:            realUid,
    nombre:         c.nombre,
    correo:         c.email,
    email:          c.email,
    empresa_id:     EID,
    empresa_ids:    [EID],
    rol:            c.rol,
    activo:         true,
    es_demo:        true,
    // Desactivar 2FA para pruebas
    dos_factores_activo:   false,
    dos_factores_telefono: '',
    onboarding_completado: true,
    fecha_creacion: admin.firestore.Timestamp.now(),
  }, { merge: true });

  // 4. Si el UID canónico difiere del real, mantener también doc en uid canónico
  if (realUid !== c.uid) {
    await db.collection('usuarios').doc(c.uid).set(
      { uid: realUid, _redirige_a: realUid, correo: c.email },
      { merge: true },
    );
    console.log(`      ↳ Redirigido: usuarios/${c.uid} → ${realUid}`);
  }

  return realUid;
}

async function main() {
  console.log('\n🚑 CREAR/RESETEAR CUENTAS EMPLEADOS — Sanir Transporte Sanitario CLM');
  console.log(`   empresaId: ${EID}\n`);

  for (const c of CUENTAS) {
    await procesarCuenta(c);
  }

  console.log('\n' + '─'.repeat(55));
  console.log('✅ Listo. Credenciales de prueba:\n');
  for (const c of CUENTAS) {
    console.log(`   [${c.rol.padEnd(5)}]  ${c.email.padEnd(35)}  ${c.password}`);
  }
  console.log('');
}

main()
  .then(() => process.exit(0))
  .catch(e => {
    console.error('\n❌ Error:', e.message);
    process.exit(1);
  });

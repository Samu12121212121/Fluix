/**
 * verificar_cuentas_sanir.js — Diagnóstico + forzar contraseña
 * Uso (desde functions/):
 *   node scripts/verificar_cuentas_sanir.js
 */
const admin = require('firebase-admin');
const sa    = require('../serviceAccountKey.json');
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa), projectId: 'planeaapp-4bea4' });
}

const auth = admin.auth();
const db   = admin.firestore();

const CUENTAS = [
  { email: 'Test_Sanir_CLM@fluixtest.com', password: 'DemoSeed1972',    nombre: 'Coordinador', rol: 'admin' },
  { email: 'elena.martin@fluixtest.com',   password: 'ElenaTES2026',    nombre: 'Elena',       rol: 'staff' },
  { email: 'roberto.lopez@fluixtest.com',  password: 'RobertoConduTES', nombre: 'Roberto',     rol: 'staff' },
];

const EID = 'demo_sanir_clm_2026';

async function main() {
  console.log('\n🔍 DIAGNÓSTICO CUENTAS SANIR');
  console.log(`   Proyecto: planeaapp-4bea4\n`);

  for (const c of CUENTAS) {
    console.log(`── ${c.nombre} (${c.email}) ─────────────────────`);
    try {
      const user = await auth.getUserByEmail(c.email);
      console.log(`   ✅ Existe en Auth — UID: ${user.uid}`);
      console.log(`   • emailVerified: ${user.emailVerified}`);
      console.log(`   • disabled:      ${user.disabled}`);

      // Forzar nueva contraseña y habilitar cuenta
      await auth.updateUser(user.uid, {
        password:      c.password,
        emailVerified: true,
        disabled:      false,
        displayName:   c.nombre,
      });
      console.log(`   ✅ Contraseña forzada → ${c.password}`);

      // Verificar doc Firestore
      const doc = await db.collection('usuarios').doc(user.uid).get();
      if (doc.exists) {
        const d = doc.data();
        console.log(`   📄 Firestore usuarios/${user.uid}`);
        console.log(`      empresa_id:           ${d.empresa_id || '(vacío)'}`);
        console.log(`      rol:                  ${d.rol || '(vacío)'}`);
        console.log(`      activo:               ${d.activo}`);
        console.log(`      dos_factores_activo:  ${d.dos_factores_activo}`);

        // Corregir empresa_id y rol si hacen falta
        const updates = {};
        if (d.empresa_id !== EID)          updates.empresa_id = EID;
        if (!d.empresa_ids?.includes(EID)) updates.empresa_ids = admin.firestore.FieldValue.arrayUnion(EID);
        if (d.rol !== c.rol)               updates.rol = c.rol;
        if (d.activo !== true)             updates.activo = true;
        if (d.dos_factores_activo !== false) updates.dos_factores_activo = false;

        if (Object.keys(updates).length > 0) {
          await doc.ref.update(updates);
          console.log(`   ✅ Firestore corregido:`, updates);
        } else {
          console.log(`   ✅ Firestore OK — sin cambios`);
        }
      } else {
        // Crear doc
        await db.collection('usuarios').doc(user.uid).set({
          uid:                   user.uid,
          nombre:                c.nombre,
          correo:                c.email,
          email:                 c.email,
          empresa_id:            EID,
          empresa_ids:           [EID],
          rol:                   c.rol,
          activo:                true,
          es_demo:               true,
          dos_factores_activo:   false,
          dos_factores_telefono: '',
          onboarding_completado: true,
          fecha_creacion:        admin.firestore.Timestamp.now(),
        });
        console.log(`   ✅ Doc Firestore creado`);
      }

    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        console.log(`   ❌ NO existe en Auth — creando...`);
        try {
          const newUser = await auth.createUser({
            email: c.email, password: c.password,
            displayName: c.nombre, emailVerified: true,
          });
          console.log(`   ✅ Creada — UID: ${newUser.uid}`);

          await db.collection('usuarios').doc(newUser.uid).set({
            uid:                   newUser.uid,
            nombre:                c.nombre,
            correo:                c.email,
            email:                 c.email,
            empresa_id:            EID,
            empresa_ids:           [EID],
            rol:                   c.rol,
            activo:                true,
            es_demo:               true,
            dos_factores_activo:   false,
            dos_factores_telefono: '',
            onboarding_completado: true,
            fecha_creacion:        admin.firestore.Timestamp.now(),
          });
          console.log(`   ✅ Doc Firestore creado`);
        } catch (e2) {
          console.log(`   ❌ Error creando:`, e2.message);
        }
      } else {
        console.log(`   ❌ Error inesperado:`, e.message);
      }
    }
    console.log('');
  }

  console.log('═'.repeat(55));
  console.log('Credenciales tras el fix:\n');
  for (const c of CUENTAS) {
    console.log(`  ${c.email}`);
    console.log(`  Contraseña: ${c.password}\n`);
  }
}

main()
  .then(() => process.exit(0))
  .catch(e => { console.error('❌ Fatal:', e.message); process.exit(1); });

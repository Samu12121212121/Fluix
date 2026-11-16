'use strict';
/**
 * vincular_testers_empresa.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Para cada tester:
 *   - Si tiene cuenta Firebase Auth → crea/actualiza usuarios/{uid} (ficha completa)
 *   - Si NO tiene cuenta aún        → crea usuarios/{auto-id} con es_solo_ficha:true
 *     para que aparezca en el módulo Empleados desde ya
 *
 * Staff verá: Reservas (ver), Clientes (ver), Valoraciones, Fichaje, Portal Empleado, Web
 *
 * Uso:
 *   cd functions
 *   node scripts/vincular_testers_empresa.js
 *   node scripts/vincular_testers_empresa.js --dry-run
 * ─────────────────────────────────────────────────────────────────────────────
 */

const admin = require('firebase-admin');
const sa = require('../serviceAccountKey.json');
if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(sa) });
const db   = admin.firestore();
const auth = admin.auth();

const args    = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');

const EMPRESA_ID = '37KyODVYpXYD04VwG3Vf';

// Excluidos (ya tienen su propia empresa): Nazarí, Acentuarte, Dama Juana.
const TESTERS = [
  { email: 'aguedesamado@gmail.com',               nombre: 'Agüeda Samado'      },
  { email: 'aliorte.lope@gmail.com',               nombre: 'Ali Orte'           },
  { email: 'alvarolanga1@gmail.com',               nombre: 'Álvaro Langa'       },
  { email: 'amazoncompra2006@gmail.com',           nombre: 'Tester Amazon'      },
  { email: 'anasofiasota82@gmail.com',             nombre: 'Ana Sofía Sota'     },
  { email: 'bryanmagro19@gmail.com',               nombre: 'Bryan Magro'        },
  { email: 'datl@hotmail.es',                      nombre: 'Tester DATL'        },
  { email: 'judastadeo1@hotmail.com',              nombre: 'Judas Tadeo'        },
  { email: 'luciarodriguezsobrinoclase@gmail.com', nombre: 'Lucía Rodríguez'    },
  { email: 'martina.valfiguer@gmail.com',          nombre: 'Martina Valfiguer'  },
  { email: 'mrr300042@gmail.com',                  nombre: 'Tester MRR'         },
  { email: 'ospinlop@gmail.com',                   nombre: 'Ospín López'        },
  { email: 'zaragozachecacarlos@gmail.com',        nombre: 'Carlos Zaragoza'    },
];

function fichaBase(t, uid) {
  return {
    uid:            uid ?? null,
    nombre:         t.nombre,
    correo:         t.email,
    telefono:       '',
    empresa_id:     EMPRESA_ID,
    rol:            'staff',
    activo:         true,
    permisos:       [],
    fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function main() {
  console.log(`\n🏢 Empresa: ${EMPRESA_ID}`);
  console.log(`📋 Testers: ${TESTERS.length}`);
  if (DRY_RUN) console.log('ℹ️  Modo --dry-run — no se escribe nada\n');
  else console.log('');

  const res = { conCuenta: [], sinCuenta: [], errores: [] };

  for (const t of TESTERS) {
    process.stdout.write(`  ${t.email}… `);
    try {
      const user = await auth.getUserByEmail(t.email);

      if (DRY_RUN) {
        console.log(`✓ UID ${user.uid} (dry-run, ficha completa)`);
        res.conCuenta.push(t.email);
        continue;
      }

      // Tiene cuenta → ficha vinculada al UID real
      await db.collection('usuarios').doc(user.uid).set(
        fichaBase(t, user.uid),
        { merge: true }
      );
      console.log(`✅ ficha vinculada  (UID: ${user.uid})`);
      res.conCuenta.push(t.email);

    } catch (e) {
      if (e.code !== 'auth/user-not-found') {
        console.log(`❌ error: ${e.message}`);
        res.errores.push({ email: t.email, error: e.message });
        continue;
      }

      // Sin cuenta aún → crear ficha de solo empleado (es_solo_ficha)
      if (DRY_RUN) {
        console.log('⚠️  sin cuenta (dry-run, crearía ficha vacía)');
        res.sinCuenta.push(t.email);
        continue;
      }

      // Comprobar si ya existe una ficha previa con ese correo
      const existing = await db.collection('usuarios')
        .where('correo', '==', t.email)
        .where('empresa_id', '==', EMPRESA_ID)
        .limit(1).get();

      if (!existing.empty) {
        console.log(`⚠️  ya tiene ficha (sin cuenta Auth)`);
        res.sinCuenta.push(t.email);
        continue;
      }

      await db.collection('usuarios').add({
        ...fichaBase(t, null),
        es_solo_ficha: true,
      });
      console.log(`📋 ficha creada sin cuenta Auth`);
      res.sinCuenta.push(t.email);
    }
  }

  console.log('\n──────────────────────────────────────────');
  console.log(`✅ Con cuenta Firebase:  ${res.conCuenta.length}`);
  console.log(`📋 Ficha sin cuenta:     ${res.sinCuenta.length}`);
  console.log(`❌ Con error:            ${res.errores.length}`);

  console.log('\n📌 Módulos que verá cada staff:');
  console.log('   Reservas (ver) · Clientes (ver) · Valoraciones · Fichaje · Portal Empleado · Web');
  console.log('   NO ven: TPV · Facturación · Nóminas · Estadísticas · Tareas · Servicios\n');

  if (res.errores.length > 0) {
    console.log('❌ Errores:');
    res.errores.forEach(r => console.log(`   • ${r.email}: ${r.error}`));
    console.log('');
  }

  process.exit(0);
}

main().catch(e => {
  console.error('❌ Error inesperado:', e.message);
  process.exit(1);
});

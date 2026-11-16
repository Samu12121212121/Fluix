/**
 * MIGRACIÓN: Roles y Departamentos
 *
 * Para cada empresa activa:
 *   1. Lee todos los usuarios con campo 'departamento' (texto libre)
 *   2. Agrupa por nombre de departamento y crea documentos en roles_empresa y departamentos
 *   3. Asigna departamento_id a cada usuario
 *   4. Asigna nivel_jerarquico según su rol actual (admin→1, staff→3)
 *
 * USO (desde functions/):
 *   cd functions
 *   node scripts/migrar_roles_departamentos.js --dry-run
 *   node scripts/migrar_roles_departamentos.js --empresa=<empresaId>
 *   node scripts/migrar_roles_departamentos.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'planeaapp-4bea4',
});
const db = admin.firestore();

const DRY_RUN = process.argv.includes('--dry-run');
const EMPRESA_FILTER = process.argv.find(a => a.startsWith('--empresa='))?.split('=')[1];

// Nivel por defecto según rol existente
const NIVEL_POR_ROL = {
  propietario: 1,
  admin:       1,
  staff:       3,
  empleado:    4,
};

// Roles predefinidos que se crearán automáticamente si no existen roles en la empresa
const ROLES_DEFAULT = [
  { nombre: 'Director',       nivel: 1, color: '#EF4444',
    permisos: { gestionar_empleados: true, ver_nominas_equipo: true, exportar_datos: true,
                ver_fichajes_equipo: true, editar_fichajes_equipo: true, aprobar_vacaciones: true } },
  { nombre: 'Mando intermedio', nivel: 2, color: '#F59E0B',
    permisos: { ver_fichajes_equipo: true, editar_fichajes_equipo: true, aprobar_vacaciones: true,
                ver_informes: true } },
  { nombre: 'Empleado senior',  nivel: 3, color: '#3B82F6',
    permisos: { ver_nominas_propias: true, ver_informes: true } },
  { nombre: 'Empleado',         nivel: 4, color: '#64748B',
    permisos: { ver_nominas_propias: true } },
];

async function migrarEmpresa(empresaId) {
  console.log(`\n── Empresa: ${empresaId} ──`);

  // 1. Leer todos los usuarios de esta empresa
  const snap = await db.collection('usuarios')
    .where('empresa_id', '==', empresaId)
    .where('activo', '==', true)
    .get();

  if (snap.empty) {
    console.log('  Sin usuarios activos.');
    return;
  }

  // 2. Verificar si ya existen roles/departamentos
  const rolesExist = await db.collection('empresas').doc(empresaId)
    .collection('roles_empresa').limit(1).get();

  // 3. Crear roles por defecto si no existen
  const rolIdPorNivel = {};
  if (rolesExist.empty) {
    console.log(`  Creando ${ROLES_DEFAULT.length} roles por defecto...`);
    for (const r of ROLES_DEFAULT) {
      if (!DRY_RUN) {
        const ref = await db.collection('empresas').doc(empresaId)
          .collection('roles_empresa').add({
            ...r, activo: true, creado_at: admin.firestore.FieldValue.serverTimestamp(),
            descripcion: null,
          });
        rolIdPorNivel[r.nivel] = ref.id;
        console.log(`    ✓ Rol "${r.nombre}" → ${ref.id}`);
      } else {
        rolIdPorNivel[r.nivel] = `dry_run_nivel_${r.nivel}`;
        console.log(`    [DRY] Crearía rol "${r.nombre}"`);
      }
    }
  } else {
    // Ya existen — cargar sus IDs
    const rolesSnap = await db.collection('empresas').doc(empresaId)
      .collection('roles_empresa').where('activo', '==', true).get();
    for (const doc of rolesSnap.docs) {
      rolIdPorNivel[doc.data().nivel] = doc.id;
    }
    console.log(`  Roles existentes: ${Object.keys(rolIdPorNivel).length}`);
  }

  // 4. Agrupar usuarios por nombre de departamento
  const deptMap = {}; // nombre → { id: null, usuarios: [] }
  for (const doc of snap.docs) {
    const d = doc.data();
    // Ya migrado → saltar
    if (d.departamento_id && d.nivel_jerarquico) {
      console.log(`  [SKIP] ${d.nombre || doc.id} ya migrado`);
      continue;
    }
    const dept = (d.departamento || '').trim() || 'General';
    if (!deptMap[dept]) deptMap[dept] = { id: null, usuarios: [] };
    deptMap[dept].usuarios.push({ uid: doc.id, rol: d.rol || 'staff', nombre: d.nombre || '' });
  }

  if (Object.keys(deptMap).length === 0) {
    console.log('  Todos los usuarios ya migrados.');
    return;
  }

  // 5. Crear departamentos
  console.log(`  Creando ${Object.keys(deptMap).length} departamento(s)...`);
  for (const [nombre, entry] of Object.entries(deptMap)) {
    // Comprobar si ya existe
    const existing = await db.collection('empresas').doc(empresaId)
      .collection('departamentos')
      .where('nombre', '==', nombre)
      .where('activo', '==', true)
      .limit(1).get();

    if (!existing.empty) {
      entry.id = existing.docs[0].id;
      console.log(`    ↩ Departamento "${nombre}" ya existe → ${entry.id}`);
    } else if (!DRY_RUN) {
      const ref = await db.collection('empresas').doc(empresaId)
        .collection('departamentos').add({
          nombre, descripcion: null, jefe_uid: null, jefe_nombre: null,
          padre_id: null, activo: true,
          creado_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      entry.id = ref.id;
      console.log(`    ✓ Departamento "${nombre}" → ${ref.id}`);
    } else {
      entry.id = `dry_run_${nombre.replace(/\s/g, '_')}`;
      console.log(`    [DRY] Crearía departamento "${nombre}"`);
    }
  }

  // 6. Asignar departamento_id y nivel_jerarquico a cada usuario
  const batch = db.batch();
  let count = 0;
  for (const entry of Object.values(deptMap)) {
    for (const u of entry.usuarios) {
      const nivel = NIVEL_POR_ROL[u.rol] ?? 4;
      const rolId = rolIdPorNivel[nivel] ?? null;
      const userRef = db.collection('usuarios').doc(u.uid);
      const update = {
        departamento_id:  entry.id,
        nivel_jerarquico: nivel,
        ...(rolId ? { rol_empresa_id: rolId } : {}),
      };
      if (!DRY_RUN) {
        batch.update(userRef, update);
      } else {
        console.log(`    [DRY] ${u.nombre} → dept=${entry.id} nivel=${nivel}`);
      }
      count++;
    }
  }

  if (!DRY_RUN && count > 0) {
    await batch.commit();
    console.log(`  ✅ ${count} usuarios actualizados en batch.`);
  } else if (DRY_RUN) {
    console.log(`  [DRY] Se actualizarían ${count} usuarios.`);
  }
}

async function main() {
  console.log(DRY_RUN ? '🔍 DRY RUN — sin escrituras' : '✏️  ESCRITURA REAL');

  if (EMPRESA_FILTER) {
    await migrarEmpresa(EMPRESA_FILTER);
  } else {
    const empresasSnap = await db.collection('empresas')
      .where('activo', '==', true).get();
    console.log(`Empresas activas: ${empresasSnap.size}`);
    for (const doc of empresasSnap.docs) {
      await migrarEmpresa(doc.id);
    }
  }

  console.log('\n✅ Migración completada.');
  process.exit(0);
}

main().catch(err => { console.error(err); process.exit(1); });

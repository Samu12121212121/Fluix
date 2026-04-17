// functions/scripts/migrate_fase1.ts
//
// Añade campos nuevos (opcionales) a empresas y usuarios existentes.
// NO sobrescribe datos existentes. Seguro de ejecutar varias veces.
//
// Uso:  cd functions && npx ts-node --project scripts/tsconfig.scripts.json scripts/migrate_fase1.ts

import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';

// ── Inicializar Firebase Admin ──────────────────────────────────────────────
const saPath = path.resolve(__dirname, '..', 'serviceAccountKey.json');
if (!fs.existsSync(saPath)) {
  // Intentar con credentials.json en la raíz del proyecto
  const altPath = path.resolve(__dirname, '..', '..', 'credentials.json');
  if (fs.existsSync(altPath)) {
    const serviceAccount = require(altPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  } else {
    console.error('❌ No se encontró serviceAccountKey.json ni credentials.json');
    console.error('   Descárgalo de Firebase Console → Project Settings → Service Accounts');
    process.exit(1);
  }
} else {
  const serviceAccount = require(saPath);
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
}

const db = admin.firestore();

// ─────────────────────────────────────────────────────────
// 1. Migración de EMPRESAS
// ─────────────────────────────────────────────────────────

async function migrarEmpresas() {
  console.log('🏢 Migrando empresas...');

  const snap = await db.collection('empresas').get();
  let actualizadas = 0;
  let sinCambios = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const updates: Record<string, any> = {};

    // active_packs — por defecto el pack base
    if (!Array.isArray(data.active_packs)) {
      updates.active_packs = ['base'];
    }

    // regimen_fiscal
    if (!data.regimen_fiscal || typeof data.regimen_fiscal !== 'object') {
      updates.regimen_fiscal = {
        tipo: 'general',
        periodicidad_iva: 'trimestral',
        obligado_sii: false,
        obligado_verifactu: false,
        es_nueva_creacion: false,
        codigos_cnae: [],
      };
    }

    // sector — mantén 'otro' como default
    if (!data.sector) {
      updates.sector = 'otro';
    }

    if (Object.keys(updates).length > 0) {
      updates.updated_at = admin.firestore.FieldValue.serverTimestamp();
      await doc.ref.update(updates);
      actualizadas++;
      console.log(`  ✓ ${doc.id}: ${Object.keys(updates).join(', ')}`);
    } else {
      sinCambios++;
    }
  }

  console.log(`✅ Empresas: ${actualizadas} actualizadas, ${sinCambios} sin cambios`);
}

// ─────────────────────────────────────────────────────────
// 2. Migración de USUARIOS
// ─────────────────────────────────────────────────────────

async function migrarUsuarios() {
  console.log('\n👤 Migrando usuarios...');

  const snap = await db.collection('usuarios').get();
  let actualizados = 0;
  let sinCambios = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const updates: Record<string, any> = {};

    // fcm_tokens como array (antes era string único)
    if (data.fcm_token && !Array.isArray(data.fcm_tokens)) {
      updates.fcm_tokens = [data.fcm_token];
    } else if (!data.fcm_tokens) {
      updates.fcm_tokens = [];
    }

    // preferencias
    if (!data.preferencias || typeof data.preferencias !== 'object') {
      updates.preferencias = {
        idioma: 'es',
        notificaciones_push: true,
        notificaciones_email: true,
        tema: 'auto',
      };
    }

    // Asegurar que es_plataforma_admin existe
    if (data.es_plataforma_admin === undefined) {
      updates.es_plataforma_admin = false;
    }

    if (Object.keys(updates).length > 0) {
      await doc.ref.update(updates);
      actualizados++;
      console.log(`  ✓ ${doc.id}: ${Object.keys(updates).join(', ')}`);
    } else {
      sinCambios++;
    }
  }

  console.log(`✅ Usuarios: ${actualizados} actualizados, ${sinCambios} sin cambios`);
}

// ─────────────────────────────────────────────────────────
// 3. Crear config/modelos_aeat si no existe
// ─────────────────────────────────────────────────────────

async function crearConfigModelos() {
  console.log('\n⚙️  Creando config/modelos_aeat...');

  const ref = db.doc('config/modelos_aeat');
  const existing = await ref.get();

  if (existing.exists) {
    console.log('  ⚠️  Ya existe, no se sobrescribe');
    return;
  }

  await ref.set({
    modelos: {
      '303': {
        nombre: 'IVA trimestral',
        tipo: 'trimestral',
        fecha_limite_dias: 20,
        activo: true,
      },
      '111': {
        nombre: 'Retenciones IRPF',
        tipo: 'trimestral',
        fecha_limite_dias: 20,
        activo: true,
      },
      '115': {
        nombre: 'Retenciones alquileres',
        tipo: 'trimestral',
        fecha_limite_dias: 20,
        activo: true,
      },
      '202': {
        nombre: 'Pagos a cuenta IS',
        tipo: 'trimestral',
        fecha_limite_dias: 20,
        activo: false, // futuro
      },
      '390': {
        nombre: 'Resumen anual IVA',
        tipo: 'anual',
        fecha_limite_dias: 30,
        mes_limite: 1, // enero
        activo: true,
      },
      '190': {
        nombre: 'Resumen anual retenciones IRPF',
        tipo: 'anual',
        fecha_limite_dias: 31,
        mes_limite: 1,
        activo: true,
      },
      '180': {
        nombre: 'Resumen anual retenciones alquileres',
        tipo: 'anual',
        fecha_limite_dias: 31,
        mes_limite: 1,
        activo: true,
      },
      '347': {
        nombre: 'Operaciones con terceros',
        tipo: 'anual',
        fecha_limite_dias: 28,
        mes_limite: 2, // febrero
        umbral_euros: 3005.06,
        activo: true,
      },
    },
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('  ✓ Creado');
}

// ─────────────────────────────────────────────────────────
// 4. Crear config/pack_fiscal si no existe
// ─────────────────────────────────────────────────────────

async function crearConfigPackFiscal() {
  console.log('\n⚙️  Creando config/pack_fiscal...');

  const ref = db.doc('config/pack_fiscal');
  const existing = await ref.get();

  if (existing.exists) {
    console.log('  ⚠️  Ya existe, no se sobrescribe');
    return;
  }

  await ref.set({
    activo: true,
    precio_anual_eur: 450,
    max_facturas_mes: 500,
    trial_days: 14,
    prompt_version_actual: 'invoice_es_v1_2026_04',
    llm_model: 'claude-sonnet-4-5',
    docai_processor_id: 'PENDIENTE_PONER_ID',
    categorias_gasto: [
      'HOSTELERIA_INSUMOS',
      'PRODUCTOS_BELLEZA',
      'MATERIAL_TATUAJE',
      'SUMINISTROS_CARNICERIA',
      'ALQUILER_LOCAL',
      'SUMINISTROS_BASICOS',
      'SERVICIOS_PROFESIONALES',
      'PUBLICIDAD',
      'EQUIPAMIENTO',
      'SOFTWARE_LICENCIAS',
      'TRANSPORTE',
      'FORMACION',
      'LIMPIEZA',
      'OTROS',
    ],
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('  ✓ Creado');
}

// ─────────────────────────────────────────────────────────
// 5. Actualizar config/verifactu con campos nuevos
// ─────────────────────────────────────────────────────────

async function actualizarConfigVerifactu() {
  console.log('\n⚙️  Actualizando config/verifactu...');

  const ref = db.doc('config/verifactu');
  const existing = await ref.get();

  if (!existing.exists) {
    console.log('  ⚠️  No existe config/verifactu — creándolo completo');
    await ref.set({
      endpoint_produccion: 'https://www1.agenciatributaria.gob.es/wlpl/TIKE-CONT/ws/SusFactFEV2SOAP',
      endpoint_pruebas: 'https://prewww1.aeat.es/wlpl/TIKE-CONT/ws/SuusFactFEV2SOAP',
      usar_pruebas: true,
      version: '1.0',
      obligatorio_desde: '2026-07-01',
      fase_implementacion: 'preparacion',
      last_updated: admin.firestore.FieldValue.serverTimestamp(),
      notas: 'Recordar cambiar usar_pruebas:false antes de 2026-07-01',
    });
    console.log('  ✓ Creado desde cero');
    return;
  }

  // Solo añadir campos que falten
  const data = existing.data()!;
  const updates: Record<string, any> = {};

  if (!data.obligatorio_desde) updates.obligatorio_desde = '2026-07-01';
  if (!data.fase_implementacion) updates.fase_implementacion = 'preparacion';
  if (!data.notas) updates.notas = 'Recordar cambiar usar_pruebas:false antes de 2026-07-01';

  if (Object.keys(updates).length > 0) {
    updates.last_updated = admin.firestore.FieldValue.serverTimestamp();
    await ref.update(updates);
    console.log(`  ✓ Añadidos: ${Object.keys(updates).join(', ')}`);
  } else {
    console.log('  ✓ Ya tiene todos los campos, sin cambios');
  }
}

// ─────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────

(async () => {
  try {
    console.log('🚀 Iniciando migración Fase 1...\n');

    await migrarEmpresas();
    await migrarUsuarios();
    await crearConfigModelos();
    await crearConfigPackFiscal();
    await actualizarConfigVerifactu();

    console.log('\n✅ Migración Fase 1 completa');
    process.exit(0);
  } catch (e) {
    console.error('\n❌ Error:', e);
    process.exit(1);
  }
})();


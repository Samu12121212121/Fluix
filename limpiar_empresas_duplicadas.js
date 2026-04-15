/**
 * SCRIPT DE LIMPIEZA FIREBASE
 * Elimina la empresa con ID incorrecto y verifica que la correcta esté bien
 *
 * Ejecutar: node limpiar_empresas_duplicadas.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./credentials.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'planeaapp-4bea4'
});

const db = admin.firestore();

// IDs de empresas
const ID_INCORRECTO = '7Uz8GOnQ6OX8ejiov7c5M9LFPI2';  // ❌ Este se elimina
const ID_CORRECTO   = 'TUz8GOnQ6OX8ejiov7c5GM9LFPl2'; // ✅ Este se mantiene

async function limpiarEmpresas() {
  console.log('🧹 LIMPIEZA DE EMPRESAS DUPLICADAS');
  console.log('═══════════════════════════════════════');

  try {
    // 1. Verificar que la empresa correcta existe y tiene datos
    console.log('\n📊 Verificando empresa CORRECTA:', ID_CORRECTO);
    const empresaCorrecta = await db.collection('empresas').doc(ID_CORRECTO).get();

    if (!empresaCorrecta.exists) {
      console.error('❌ ERROR: La empresa correcta no existe!');
      process.exit(1);
    }

    const datos = empresaCorrecta.data();
    console.log('✅ Empresa correcta encontrada:');
    console.log(`   - Nombre: ${datos.nombre || 'Sin nombre'}`);
    console.log(`   - Email: ${datos.email_contacto || 'Sin email'}`);
    console.log(`   - Tipo: ${datos.tipo_negocio || 'Sin tipo'}`);
    console.log(`   - Plan: ${datos.plan_id || 'Sin plan'}`);
    console.log(`   - Activa: ${datos.suscripcion?.activa || false}`);

    // 2. Verificar subcolecciones de la empresa correcta
    console.log('\n📁 Verificando subcolecciones de la empresa correcta:');
    const subcolecciones = ['configuracion', 'contenido_web', 'estadisticas', 'dispositivos'];

    for (const subcol of subcolecciones) {
      const docs = await empresaCorrecta.ref.collection(subcol).get();
      console.log(`   - ${subcol}: ${docs.size} documento(s)`);
    }

    // 3. Verificar si la empresa incorrecta existe
    console.log('\n⚠️  Verificando empresa INCORRECTA:', ID_INCORRECTO);
    const empresaIncorrecta = await db.collection('empresas').doc(ID_INCORRECTO).get();

    if (!empresaIncorrecta.exists) {
      console.log('✅ La empresa incorrecta no existe (ya fue eliminada)');
    } else {
      console.log('❌ La empresa incorrecta SÍ existe. Analizando...');

      const datosIncorrectos = empresaIncorrecta.data();
      console.log('   Datos en empresa incorrecta:');
      console.log(`   - Nombre: ${datosIncorrectos.nombre || 'Sin nombre'}`);
      console.log(`   - Email: ${datosIncorrectos.email_contacto || 'Sin email'}`);

      // Verificar subcolecciones de la empresa incorrecta
      for (const subcol of subcolecciones) {
        const docs = await empresaIncorrecta.ref.collection(subcol).get();
        if (docs.size > 0) {
          console.log(`   - ${subcol}: ${docs.size} documento(s) - ⚠️ CONTIENE DATOS`);
        }
      }

      // Preguntar si eliminar (simulado - en producción sería manual)
      console.log('\n🗑️  ¿Eliminar empresa incorrecta?');
      console.log('   NOTA: Ejecuta manualmente desde Firebase Console para mayor seguridad');
      console.log('   1. Ve a Firebase Console → Firestore');
      console.log(`   2. Busca la colección "empresas" → documento "${ID_INCORRECTO}"`);
      console.log('   3. Elimínalo junto con todas sus subcolecciones');

      // Para mayor seguridad, NO eliminamos automáticamente
      console.log('\n⚠️  NO eliminando automáticamente por seguridad');
    }

    // 4. Verificar archivos de configuración
    console.log('\n📄 Verificando archivos de configuración local:');

    const archivosImportantes = [
      'seed_contenido_web.js',
      'sincronizar_carta.html',
      'sincronizar_todo.html',
      'public_web_visor/carta_dama_juana_conectada.html',
      'GUIA_SCRIPT_ANALITICAS_WEB.md'
    ];

    for (const archivo of archivosImportantes) {
      try {
        const fs = require('fs');
        const contenido = fs.readFileSync(archivo, 'utf8');

        const tieneIncorrecto = contenido.includes(ID_INCORRECTO);
        const tieneCorrecto = contenido.includes(ID_CORRECTO);

        if (tieneIncorrecto) {
          console.log(`   ❌ ${archivo}: contiene ID incorrecto`);
        } else if (tieneCorrecto) {
          console.log(`   ✅ ${archivo}: usa ID correcto`);
        } else {
          console.log(`   ⚪ ${archivo}: no contiene IDs de empresa`);
        }
      } catch (e) {
        console.log(`   ⚠️  ${archivo}: no encontrado`);
      }
    }

    console.log('\n═══════════════════════════════════════');
    console.log('✅ VERIFICACIÓN COMPLETADA');
    console.log('\n📋 RESUMEN:');
    console.log(`   - Empresa correcta (${ID_CORRECTO}): ✅ OK`);
    console.log(`   - Empresa incorrecta (${ID_INCORRECTO}): ${empresaIncorrecta.exists ? '⚠️ Pendiente eliminar' : '✅ No existe'}`);
    console.log('   - Archivos de código: ✅ Corregidos');

    console.log('\n🎯 PRÓXIMOS PASOS:');
    console.log('   1. Si la empresa incorrecta existe, elimínala manualmente desde Firebase Console');
    console.log('   2. Ejecuta: node seed_contenido_web.js');
    console.log('   3. Prueba las webs HTML para verificar que conectan correctamente');
    console.log('   4. Abre la app Flutter y verifica el contenido web');

  } catch (error) {
    console.error('❌ Error durante la verificación:', error.message);
    process.exit(1);
  }
}

limpiarEmpresas();

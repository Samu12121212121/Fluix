/**
 * 🔧 Script para agregar el módulo de Plantillas PDF a todas las empresas
 *
 * Ejecutar con:
 *   node agregar_modulo_plantillas_pdf.js
 *
 * REQUIERE Firebase Admin SDK configurado
 */

const admin = require('firebase-admin');
const path = require('path');

// Configurar Firebase Admin con service account
const serviceAccount = require(path.join(__dirname, '../functions/serviceAccountKey.json'));

try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} catch(e) {
  console.log('ℹ️  Firebase Admin ya inicializado');
}

const db = admin.firestore();

async function agregarModulo() {
  try {
    console.log('🔍 Buscando empresas...');
    const empresasSnapshot = await db.collection('empresas').get();

    console.log(`📊 Encontradas ${empresasSnapshot.size} empresas`);

    let actualizadas = 0;
    let errores = 0;

    for (const doc of empresasSnapshot.docs) {
      const empresaId = doc.id;
      const modulosRef = db.collection(`empresas/${empresaId}/modulos`).doc('plantillas_pdf');

      try {
        //Verificar si ya existe
        const existing = await modulosRef.get();
        if (existing.exists) {
          console.log(`⏭️  ${empresaId}: Ya tiene el módulo`);
          continue;
        }

        // Crear módulo
        await modulosRef.set({
          id: 'plantillas_pdf',
          nombre: 'Plantillas PDF',
          icono: 'article', // MaterialIcons.article
          activo: false, // Desactivado por defecto, admin lo activa
          orden: 100,
          descripcion: 'Personaliza el diseño de tus documentos PDF',
          categoria: 'facturacion',
          rolesPermitidos: ['admin', 'propietario'],
          requiereSuscripcion: false,
        });

        actualizadas++;
        console.log(`✅ ${empresaId}: Módulo agregado`);
      } catch (error) {
        errores++;
        console.error(`❌ ${empresaId}: Error -`, error.message);
      }
    }

    console.log('\n📊 RESUMEN:');
    console.log(`   ✅ Actualizadas: ${actualizadas}`);
    console.log(`   ❌ Errores: ${errores}`);
    console.log(`   ⏭️  Ya existentes: ${empresasSnapshot.size - actualizadas - errores}`);

  } catch (error) {
    console.error('❌ Error fatal:', error);
  }
}

agregarModulo()
  .then(() => {
    console.log('\n✨ Proceso completado');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Proceso fallido:', error);
    process.exit(1);
  });



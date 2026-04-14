/**
 * SCRIPT PARA CREAR DATOS REALES EN FIRESTORE
 * Empresa: 7Uz8GOnQ6OX8ejiov7c5M9LFPI2
 *
 * Ejecutar: node seed_contenido_web.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./credentials.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'planeaapp-4bea4'
});

const db = admin.firestore();
const EMPRESA_ID = 'TUz8GOnQ6OX8ejiov7c5GM9LFPl2';

async function crearDatosIniciales() {
  console.log('🚀 Creando datos para empresa:', EMPRESA_ID);

  // 1. Verificar/crear documento de empresa
  const empresaRef = db.collection('empresas').doc(EMPRESA_ID);
  const empresaDoc = await empresaRef.get();

  if (!empresaDoc.exists) {
    console.log('📝 Creando documento de empresa...');
    await empresaRef.set({
      nombre: 'Mi Empresa',
      dominio: 'miempresa.com',
      sitio_web: 'https://miempresa.com',
      telefono: '',
      direccion: '',
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    console.log('✅ Empresa ya existe:', empresaDoc.data().nombre || 'Sin nombre');
  }

  // 2. Crear secciones de contenido web
  const contenidoWebRef = empresaRef.collection('contenido_web');

  const secciones = [
    {
      id: 'servicios',
      nombre: 'Nuestros Servicios',
      descripcion: 'Los servicios que ofrecemos',
      activa: true,
      tipo: 'generico',
      orden: 1,
      contenido: {
        titulo: 'Nuestros Servicios',
        texto: '',
        items: [
          {
            id: 'serv1',
            nombre: 'Servicio 1',
            descripcion: 'Descripción del servicio 1',
            precio: 99,
            disponible: true
          },
          {
            id: 'serv2',
            nombre: 'Servicio 2',
            descripcion: 'Descripción del servicio 2',
            precio: 149,
            disponible: true
          },
          {
            id: 'serv3',
            nombre: 'Servicio 3',
            descripcion: 'Descripción del servicio 3',
            precio: 199,
            disponible: true
          }
        ]
      },
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'ofertas',
      nombre: 'Ofertas Especiales',
      descripcion: 'Promociones y descuentos',
      activa: true,
      tipo: 'ofertas',
      orden: 2,
      contenido: {
        titulo: 'Ofertas del Mes',
        texto: '¡Aprovecha nuestras ofertas especiales!',
        ofertas: [
          {
            id: 'of1',
            nombre: 'Oferta Especial',
            descripcion: 'Descuento en todos los servicios',
            precio_original: 100,
            precio_oferta: 75,
            disponible: true
          }
        ]
      },
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'about',
      nombre: 'Sobre Nosotros',
      descripcion: 'Información de la empresa',
      activa: true,
      tipo: 'texto',
      orden: 3,
      contenido: {
        titulo: 'Sobre Nosotros',
        texto: 'Somos una empresa dedicada a ofrecer el mejor servicio. Con años de experiencia en el sector, nos comprometemos a la excelencia.',
        imagen_url: null
      },
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'horarios',
      nombre: 'Horarios',
      descripcion: 'Nuestros horarios de atención',
      activa: true,
      tipo: 'horarios',
      orden: 4,
      contenido: {
        titulo: 'Horarios de Atención',
        texto: '',
        horarios: [
          { id: 'h1', dia: 'Lunes - Viernes', horario: '09:00 - 20:00' },
          { id: 'h2', dia: 'Sábados', horario: '10:00 - 14:00' },
          { id: 'h3', dia: 'Domingos', horario: 'Cerrado' }
        ]
      },
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      id: 'contacto',
      nombre: 'Contacto',
      descripcion: 'Información de contacto',
      activa: true,
      tipo: 'texto',
      orden: 5,
      contenido: {
        titulo: 'Contáctanos',
        texto: '¿Tienes alguna pregunta? No dudes en contactarnos.',
        imagen_url: null
      },
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    }
  ];

  for (const seccion of secciones) {
    const docRef = contenidoWebRef.doc(seccion.id);
    const doc = await docRef.get();

    if (doc.exists) {
      console.log(`  ⏭️  Sección "${seccion.nombre}" ya existe, saltando...`);
    } else {
      await docRef.set(seccion);
      console.log(`  ✅ Creada sección: ${seccion.nombre}`);
    }
  }

  // 3. Crear configuración web_avanzada
  const configRef = empresaRef.collection('configuracion').doc('web_avanzada');
  const configDoc = await configRef.get();

  if (!configDoc.exists) {
    await configRef.set({
      banner_activo: false,
      banner_texto: '',
      banner_color: '#1976D2',
      banner_url_destino: '',
      popup_activo: false,
      popup_titulo: '',
      popup_texto: '',
      popup_boton_texto: 'Ver más',
      popup_boton_url: '',
      popup_retraso_seg: 5,
      contacto_activo: false,
      contacto_titulo: 'Contáctanos',
      contacto_email: '',
      contacto_whatsapp: '',
      dominio_propio_url: 'https://damajuanaguadalajara.site',
      fecha_creacion: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Creada configuración web_avanzada');
  } else {
    console.log('✅ Configuración web_avanzada ya existe');
  }

  // 4. Crear estadísticas de tráfico
  const statsRef = empresaRef.collection('estadisticas').doc('trafico_web');
  const statsDoc = await statsRef.get();

  if (!statsDoc.exists) {
    await statsRef.set({
      visitas_total: 0,
      visitas_hoy: 0,
      visitas_semana: 0,
      visitas_mes: 0,
      visitas_movil: 0,
      visitas_desktop: 0,
      visitas_tablet: 0,
      paginas_mas_vistas: {},
      referrers: {},
      ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Creadas estadísticas trafico_web');
  } else {
    console.log('✅ Estadísticas trafico_web ya existen');
  }

  console.log('\n🎉 ¡DATOS CREADOS CORRECTAMENTE!');
  console.log('\n📱 Ahora en la App Flutter:');
  console.log('   1. Ve al módulo "Contenido Web"');
  console.log('   2. Verás las 5 secciones creadas');
  console.log('   3. Edita el contenido desde la app');
  console.log('   4. Los cambios se reflejan en la web automáticamente');

  process.exit(0);
}

crearDatosIniciales().catch(err => {
  console.error('❌ Error:', err.message);
  process.exit(1);
});




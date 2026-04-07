<!-- 🔥 PLANEAGUADA CRM - INTEGRACIÓN WORDPRESS OPTIMIZADA -->
<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/9.23.0/firebase-firestore-compat.js"></script>

<script>
document.addEventListener("DOMContentLoaded", function() {
    console.log('🚀 Inicializando PlaneaGuada CRM Integration...');

    // 🔥 Configuración Firebase (ACTUALIZADA)
    const firebaseConfig = {
        apiKey: "AIzaSyDpAGshzWcOWsJ1dRhBZybnhBjm8tY5234", // ← Tu API Key real
        authDomain: "planeaapp-4bea4.firebaseapp.com",
        projectId: "planeaapp-4bea4",
        storageBucket: "planeaapp-4bea4.appspot.com",
        messagingSenderId: "1085482191658",
        appId: "1:1085482191658:web:c5461353b123ab92d62c53"
    };

    // Inicializar Firebase
    if (!firebase.apps.length) {
        firebase.initializeApp(firebaseConfig);
    }

    const db = firebase.firestore();

    // 🏢 CONFIGURACIÓN (actualizar con tus datos)
    const EMPRESA_ID = "ulhYZOjxH35a663JdU3y"; // ← ID de tu empresa del CRM
    const PAGINA_ACTUAL = window.location.pathname;
    const TITULO_PAGINA = document.title;

    /* =====================================================
       📊 ANALYTICS MEJORADOS - ESTRUCTURA CRM
       ===================================================== */
    async function registrarVisitaWeb() {
        try {
            const ahora = new Date();
            const fechaHoy = ahora.toISOString().substring(0, 10); // YYYY-MM-DD

            // 1. Actualizar estadísticas generales
            const statsRef = db
                .collection('empresas')
                .doc(EMPRESA_ID)
                .collection('estadisticas')
                .doc('resumen');

            await statsRef.set({
                visitas_web_mes: firebase.firestore.FieldValue.increment(1),
                ultima_visita: firebase.firestore.FieldValue.serverTimestamp(),
                paginas_populares: {
                    [PAGINA_ACTUAL]: firebase.firestore.FieldValue.increment(1)
                },
                fecha_actualizacion: ahora.toISOString()
            }, { merge: true });

            // 2. Registrar visita diaria para gráfico
            const visitaDiariaRef = db
                .collection('empresas')
                .doc(EMPRESA_ID)
                .collection('estadisticas')
                .doc('visitas_diarias')
                .collection('datos')
                .doc(fechaHoy);

            await visitaDiariaRef.set({
                fecha: fechaHoy,
                visitas: firebase.firestore.FieldValue.increment(1),
                ultima_actualizacion: firebase.firestore.FieldValue.serverTimestamp()
            }, { merge: true });

            // 3. Actualizar array de visitas diarias en resumen (para el gráfico)
            await actualizarArrayVisitas(fechaHoy);

            console.log('✅ Visita web registrada:', fechaHoy);

        } catch (error) {
            console.error('❌ Error registrando visita:', error);
        }
    }

    /* =====================================================
       📈 ACTUALIZAR ARRAY VISITAS PARA GRÁFICO
       ===================================================== */
    async function actualizarArrayVisitas(fechaHoy) {
        try {
            const statsRef = db
                .collection('empresas')
                .doc(EMPRESA_ID)
                .collection('estadisticas')
                .doc('resumen');

            const doc = await statsRef.get();
            let visitasDiarias = [];

            if (doc.exists && doc.data().visitas_diarias) {
                visitasDiarias = doc.data().visitas_diarias;
            }

            // Buscar si ya existe la fecha de hoy
            const indiceHoy = visitasDiarias.findIndex(v => v.fecha === fechaHoy);

            if (indiceHoy >= 0) {
                // Incrementar visitas del día
                visitasDiarias[indiceHoy].visitas = (visitasDiarias[indiceHoy].visitas || 0) + 1;
            } else {
                // Añadir nuevo día
                visitasDiarias.push({
                    fecha: fechaHoy,
                    visitas: 1
                });

                // Mantener solo últimos 30 días
                visitasDiarias.sort((a, b) => new Date(a.fecha) - new Date(b.fecha));
                if (visitasDiarias.length > 30) {
                    visitasDiarias = visitasDiarias.slice(-30);
                }
            }

            // Actualizar en Firebase
            await statsRef.set({
                visitas_diarias: visitasDiarias
            }, { merge: true });

        } catch (error) {
            console.error('❌ Error actualizando array visitas:', error);
        }
    }

    /* =====================================================
       ⭐ CAPTURAR RESEÑAS DE PLUGINS EXISTENTES
       ===================================================== */
    function detectarNuevasResenas() {
        // Si usas un plugin de reseñas, detectamos cuando se envía
        const formsResenas = document.querySelectorAll('form[class*="review"], form[class*="rating"], .comment-form');

        formsResenas.forEach(form => {
            form.addEventListener('submit', async function(e) {
                setTimeout(async () => {
                    await capturarResenaNueva();
                }, 2000); // Esperar que se procese en WordPress
            });
        });
    }

    async function capturarResenaNueva() {
        try {
            // Buscar último comentario/reseña en la página
            const ultimoComentario = document.querySelector('.comment:last-child, .review:last-child');
            if (!ultimoComentario) return;

            const nombre = ultimoComentario.querySelector('.comment-author, .review-author')?.textContent?.trim() || 'Usuario Web';
            const comentario = ultimoComentario.querySelector('.comment-content, .review-content')?.textContent?.trim() || '';
            const estrellas = ultimoComentario.querySelectorAll('.star, .rating .filled, [class*="star-filled"]').length || 5;

            if (comentario) {
                await db.collection('empresas')
                    .doc(EMPRESA_ID)
                    .collection('valoraciones')
                    .add({
                        nombre_persona: nombre,
                        estrellas: estrellas,
                        comentario: comentario,
                        fecha: new Date().toISOString(),
                        respuesta: null,
                        origen: 'wordpress',
                        pagina: PAGINA_ACTUAL,
                        titulo_pagina: TITULO_PAGINA
                    });

                console.log('✅ Reseña capturada:', nombre);
            }
        } catch (error) {
            console.error('❌ Error capturando reseña:', error);
        }
    }

    /* =====================================================
       📅 CAPTURAR RESERVAS DE FORMULARIOS CONTACT FORM 7
       ===================================================== */
    function detectarFormularioReservas() {
        // Contact Form 7
        document.addEventListener('wpcf7mailsent', async function(event) {
            await procesarReservaContactForm7(event.detail);
        });

        // Formularios genéricos
        const formsReservas = document.querySelectorAll('form[class*="contact"], form[class*="booking"], form[class*="appointment"]');

        formsReservas.forEach(form => {
            form.addEventListener('submit', async function(e) {
                const formData = new FormData(form);
                await procesarReservaGenerica(formData);
            });
        });
    }

    async function procesarReservaContactForm7(formData) {
        try {
            const nombre = formData.get('your-name') || formData.get('nombre') || '';
            const email = formData.get('your-email') || formData.get('email') || '';
            const telefono = formData.get('your-phone') || formData.get('telefono') || '';
            const servicio = formData.get('service') || formData.get('servicio') || 'Consulta general';
            const fecha = formData.get('appointment-date') || formData.get('fecha') || '';
            const mensaje = formData.get('your-message') || formData.get('mensaje') || '';

            if (nombre && email) {
                await db.collection('empresas')
                    .doc(EMPRESA_ID)
                    .collection('reservas')
                    .add({
                        nombre_cliente: nombre,
                        correo_cliente: email,
                        telefono_cliente: telefono,
                        servicio: servicio,
                        fecha_hora: fecha ? new Date(fecha).toISOString() : new Date().toISOString(),
                        estado: 'pendiente',
                        notas: mensaje,
                        origen: 'wordpress',
                        fecha_creacion: new Date().toISOString(),
                        pagina_origen: PAGINA_ACTUAL
                    });

                console.log('✅ Reserva creada para:', nombre);

                // Mostrar mensaje de confirmación
                mostrarMensajeConfirmacion('¡Reserva enviada! Te contactaremos pronto.');
            }
        } catch (error) {
            console.error('❌ Error procesando reserva:', error);
        }
    }

    async function procesarReservaGenerica(formData) {
        try {
            const datos = {};
            for (let [key, value] of formData.entries()) {
                datos[key] = value;
            }

            // Mapear campos comunes
            const reserva = {
                nombre_cliente: datos.nombre || datos.name || datos['your-name'] || 'Cliente Web',
                correo_cliente: datos.email || datos.correo || datos['your-email'] || '',
                telefono_cliente: datos.telefono || datos.phone || datos['your-phone'] || '',
                servicio: datos.servicio || datos.service || 'Consulta general',
                fecha_hora: datos.fecha || datos.date || new Date().toISOString(),
                estado: 'pendiente',
                notas: datos.mensaje || datos.message || datos.comentarios || '',
                origen: 'wordpress',
                fecha_creacion: new Date().toISOString(),
                pagina_origen: PAGINA_ACTUAL
            };

            if (reserva.nombre_cliente && reserva.correo_cliente) {
                await db.collection('empresas')
                    .doc(EMPRESA_ID)
                    .collection('reservas')
                    .add(reserva);

                console.log('✅ Reserva genérica creada');
            }
        } catch (error) {
            console.error('❌ Error procesando reserva genérica:', error);
        }
    }

    /* =====================================================
       💬 LISTENER PARA RESPUESTAS DEL CRM
       ===================================================== */
    function escucharRespuestasCRM() {
        // Escuchar cambios en valoraciones para mostrar respuestas
        db.collection('empresas')
            .doc(EMPRESA_ID)
            .collection('valoraciones')
            .where('origen', '==', 'wordpress')
            .onSnapshot(snapshot => {
                snapshot.docChanges().forEach(change => {
                    if (change.type === 'modified') {
                        const data = change.doc.data();
                        if (data.respuesta && !data.respuesta_mostrada) {
                            mostrarRespuestaAdmin(data.nombre_persona, data.respuesta);

                            // Marcar como mostrada
                            change.doc.ref.update({
                                respuesta_mostrada: true
                            });
                        }
                    }
                });
            });
    }

    /* =====================================================
       🎨 FUNCIONES UI
       ===================================================== */
    function mostrarMensajeConfirmacion(mensaje) {
        const div = document.createElement('div');
        div.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: #4CAF50;
            color: white;
            padding: 15px 20px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
            z-index: 10000;
            font-family: Arial, sans-serif;
            font-size: 14px;
            max-width: 300px;
        `;
        div.textContent = mensaje;
        document.body.appendChild(div);

        setTimeout(() => {
            div.style.opacity = '0';
            div.style.transition = 'opacity 0.3s';
            setTimeout(() => document.body.removeChild(div), 300);
        }, 4000);
    }

    function mostrarRespuestaAdmin(nombreCliente, respuesta) {
        const div = document.createElement('div');
        div.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            background: #2196F3;
            color: white;
            padding: 15px 20px;
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.2);
            z-index: 10000;
            font-family: Arial, sans-serif;
            font-size: 14px;
            max-width: 350px;
        `;
        div.innerHTML = `<strong>Respuesta para ${nombreCliente}:</strong><br>${respuesta}`;
        document.body.appendChild(div);

        setTimeout(() => {
            div.style.opacity = '0';
            div.style.transition = 'opacity 0.3s';
            setTimeout(() => document.body.removeChild(div), 300);
        }, 8000);
    }

    /* =====================================================
       🔄 INSERTAR DATOS DEMO (SOLO SI NO EXISTEN)
       ===================================================== */
    async function insertarDatosDemo() {
        try {
            // Verificar si ya hay valoraciones
            const valoracionesRef = db.collection('empresas').doc(EMPRESA_ID).collection('valoraciones');
            const snapshot = await valoracionesRef.limit(1).get();

            if (!snapshot.empty) {
                console.log('ℹ️ Datos demo ya existen, omitiendo inserción');
                return;
            }

            // Insertar valoraciones demo
            const valoracionesDemo = [
                {
                    nombre_persona: 'Laura Martínez',
                    estrellas: 5,
                    comentario: 'Increíble atención, el mejor sitio de Guadalajara. Volveré seguro.',
                    fecha: new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString(),
                    respuesta: null,
                    origen: 'wordpress'
                },
                {
                    nombre_persona: 'Carlos Gómez',
                    estrellas: 4,
                    comentario: 'Muy buena atención y rapidez en el servicio.',
                    fecha: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString(),
                    respuesta: '¡Gracias Carlos! Nos alegra saber que quedaste satisfecho.',
                    origen: 'wordpress'
                },
                {
                    nombre_persona: 'Ana López',
                    estrellas: 5,
                    comentario: 'Excelente experiencia, totalmente recomendado. El equipo es muy profesional.',
                    fecha: new Date(Date.now() - 8 * 24 * 60 * 60 * 1000).toISOString(),
                    respuesta: null,
                    origen: 'wordpress'
                },
                {
                    nombre_persona: 'Pedro Sánchez',
                    estrellas: 5,
                    comentario: 'Servicio de primera calidad, instalaciones perfectas.',
                    fecha: new Date(Date.now() - 12 * 24 * 60 * 60 * 1000).toISOString(),
                    respuesta: null,
                    origen: 'wordpress'
                }
            ];

            const batch = db.batch();
            valoracionesDemo.forEach(valoracion => {
                const docRef = valoracionesRef.doc();
                batch.set(docRef, valoracion);
            });

            await batch.commit();
            console.log('✅ Valoraciones demo insertadas');

            // Insertar estadísticas base
            await inicializarEstadisticas();

        } catch (error) {
            console.error('❌ Error insertando datos demo:', error);
        }
    }

    async function inicializarEstadisticas() {
        const statsRef = db.collection('empresas').doc(EMPRESA_ID).collection('estadisticas').doc('resumen');

        // Generar visitas de los últimos 30 días
        const visitasDiarias = [];
        for (let i = 29; i >= 0; i--) {
            const fecha = new Date();
            fecha.setDate(fecha.getDate() - i);
            const fechaStr = fecha.toISOString().substring(0, 10);

            visitasDiarias.push({
                fecha: fechaStr,
                visitas: Math.floor(Math.random() * 50) + 20 // Entre 20-70 visitas
            });
        }

        await statsRef.set({
            visitas_web_mes: 1240,
            visitas_web_mes_anterior: 980,
            porcentaje_cambio_visitas: 26.5,
            visitas_diarias: visitasDiarias,
            fecha_actualizacion: new Date().toISOString()
        }, { merge: true });

        console.log('✅ Estadísticas base inicializadas');
    }

    /* =====================================================
       🚀 INICIALIZACIÓN
       ===================================================== */
    async function inicializar() {
        try {
            // 1. Registrar visita
            await registrarVisitaWeb();

            // 2. Configurar detectores
            detectarNuevasResenas();
            detectarFormularioReservas();
            escucharRespuestasCRM();

            // 3. Insertar datos demo si es primera vez
            await insertarDatosDemo();

            console.log('🎉 PlaneaGuada CRM Integration iniciada correctamente');

        } catch (error) {
            console.error('❌ Error en inicialización:', error);
        }
    }

    // ⚡ EJECUTAR
    inicializar();
});
</script>

<!-- 📱 Notificación Visual de Conexión CRM -->
<div id="crm-status" style="position:fixed;bottom:10px;left:10px;background:#4CAF50;color:white;padding:8px 12px;border-radius:20px;font-size:12px;z-index:9999;opacity:0;transition:opacity 0.3s;">
    🔗 Conectado con PlaneaGuada CRM
</div>

<script>
// Mostrar indicador de conexión
setTimeout(() => {
    const indicator = document.getElementById('crm-status');
    if (indicator) {
        indicator.style.opacity = '1';
        setTimeout(() => {
            indicator.style.opacity = '0';
        }, 3000);
    }
}, 1000);
</script>

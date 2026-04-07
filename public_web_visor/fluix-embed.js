(function() {
    // 1. Configuración de Firebase (Tu proyecto)
    const firebaseConfig = {
        apiKey: "AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU",
        appId: "1:1085482191658:web:c5461353b123ab92d62c53",
        messagingSenderId: "1085482191658",
        projectId: "planeaapp-4bea4",
        authDomain: "planeaapp-4bea4.firebaseapp.com",
        storageBucket: "planeaapp-4bea4.firebasestorage.app",
        measurementId: "G-D71JMGGGZM"
    };

    // 2. Cargar Dependencias (Firebase SDK) si no existen
    function loadScript(src) {
        return new Promise((resolve, reject) => {
            if (document.querySelector(`script[src="${src}"]`)) {
                resolve();
                return;
            }
            const script = document.createElement('script');
            script.src = src;
            script.onload = resolve;
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }

    // 3. Inyectar estilos básicos (CSS) para los widgets
    function injectStyles() {
        const styleId = 'fluix-embed-styles';
        if (document.getElementById(styleId)) return;
        const style = document.createElement('style');
        style.id = styleId;
        style.textContent = `
            .fluix-widget-container { font-family: system-ui, -apple-system, sans-serif; width: 100%; box-sizing: border-box; }
            .fluix-loading { text-align: center; padding: 20px; color: #666; font-style: italic; }
            .fluix-error { color: #d32f2f; background: #ffebee; padding: 10px; border-radius: 4px; border: 1px solid #ffcdd2; }

            /* Carta / Menú */
            .fluix-carta { background: #fff; border: 1px solid #eee; border-radius: 8px; overflow: hidden; }
            .fluix-carta-header { background: #f9f9f9; padding: 15px; text-align: center; border-bottom: 1px solid #eee; }
            .fluix-carta-title { margin: 0; font-size: 1.5em; color: #333; }
            .fluix-carta-body { padding: 15px; }
            .fluix-carta-category { font-size: 1.2em; color: #e65100; border-bottom: 2px solid #ffe0b2; padding-bottom: 5px; margin-bottom: 15px; margin-top: 20px; text-transform: uppercase; letter-spacing: 1px; }
            .fluix-item { display: flex; justify-content: space-between; margin-bottom: 12px; padding-bottom: 12px; border-bottom: 1px dashed #eee; }
            .fluix-item:last-child { border-bottom: none; }
            .fluix-item-details { flex: 1; padding-right: 15px; }
            .fluix-item-name { font-weight: bold; color: #333; margin: 0 0 4px 0; }
            .fluix-item-desc { font-size: 0.9em; color: #666; margin: 0; }
            .fluix-item-price { font-weight: bold; color: #e65100; font-size: 1.1em; white-space: nowrap; }
            .fluix-agotado { text-decoration: line-through; color: #999; }
            .fluix-tag-agotado { font-size: 0.7em; color: red; background: #ffebee; padding: 2px 6px; border-radius: 4px; vertical-align: middle; margin-left: 5px; }

            /* Ofertas */
            .fluix-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 20px; }
            .fluix-oferta { border: 1px solid #e0f2f1; border-radius: 12px; overflow: hidden; background: #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.05); transition: transform 0.2s; }
            .fluix-oferta:hover { transform: translateY(-3px); box-shadow: 0 4px 12px rgba(0,0,0,0.1); }
            .fluix-oferta-img-container { height: 180px; overflow: hidden; position: relative; background: #eee; }
            .fluix-oferta-img { width: 100%; height: 100%; object-fit: cover; }
            .fluix-badge { position: absolute; top: 10px; right: 10px; background: #d32f2f; color: white; padding: 4px 10px; border-radius: 20px; font-size: 0.8em; font-weight: bold; }
            .fluix-oferta-body { padding: 15px; }
            .fluix-oferta-title { margin: 0 0 8px 0; font-size: 1.1em; }
            .fluix-oferta-desc { font-size: 0.9em; color: #666; margin-bottom: 15px; }
            .fluix-oferta-prices { display: flex; align-items: baseline; gap: 10px; }
            .fluix-price-old { text-decoration: line-through; color: #999; font-size: 0.9em; }
            .fluix-price-new { color: #2e7d32; font-weight: bold; font-size: 1.4em; }

            /* Horarios */
            .fluix-horarios { background: #263238; color: #fff; border-radius: 12px; padding: 20px; max-width: 500px; margin: 0 auto; }
            .fluix-horarios-title { text-align: center; margin-bottom: 20px; border-bottom: 1px solid #37474f; padding-bottom: 10px; }
            .fluix-horario-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #37474f; }
            .fluix-horario-row:last-child { border-bottom: none; }
            .fluix-dia { color: #b0bec5; }
            .fluix-horas { font-weight: bold; }
            .fluix-cerrado { color: #ef5350; }
            .fluix-hoy { color: #4fc3f7; font-weight: bold; }
        `;
        document.head.appendChild(style);
    }

    // 4. Inicializar Widget
    async function initFluixWidgets() {
        console.log("🚀 Fluix Embed: Conectando tu web con la App...");
        injectStyles();

        // Cargar Firebase Compat
        try {
            if (typeof firebase === 'undefined') {
                await loadScript("https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js");
                await loadScript("https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore-compat.js");
            }
        } catch (e) {
            console.error("Fluix Embed: Error cargando SDK Firebase", e);
            return;
        }

        // Inicializar App con nombre único para evitar conflictos con otras instancias de Firebase en la web del cliente
        let app;
        try {
            // Buscamos si ya existe nuestra app específica
            const appName = "FluixEmbedApp";
            const existingApp = firebase.apps.find(a => a.name === appName);

            if (existingApp) {
                app = existingApp;
            } else {
                app = firebase.initializeApp(firebaseConfig, appName);
            }
        } catch (e) {
            console.error("Fluix Embed: Error inicializando Firebase App", e);
            return;
        }

        const db = app.firestore();

        // Buscar todos los divs .fluix-widget
        const widgets = document.querySelectorAll('.fluix-widget');

        widgets.forEach(widget => {
            // Evitar reinicializar widgets ya procesados
            if (widget.dataset.fluixInit) return;
            widget.dataset.fluixInit = "true";

            const empresaId = widget.getAttribute('data-empresa');
            const seccionId = widget.getAttribute('data-seccion');

            // Detectar si el widget ya tiene contenido HTML manual (Modo Sincronización/Templates)
            const tieneContenidoManual = widget.innerHTML.trim().length > 0;
            if (tieneContenidoManual) {
                widget.setAttribute('data-modo-manual', 'true');
            }

            if (!empresaId || !seccionId) {
                widget.innerHTML = `<div class="fluix-error">Faltan parámetros (data-empresa o data-seccion)</div>`;
                return;
            }

            widget.classList.add('fluix-widget-container');

            // CORRECCIÓN: Si hay contenido manual, NO mostrar "Cargando..."
            // Así mantenemos tu diseño intacto mientras conectamos en segundo plano
            if (!tieneContenidoManual) {
                widget.innerHTML = `<div class="fluix-loading">Cargando contenido...</div>`;
            }

            // Suscribirse a cambios en Firestore
            db.collection('empresas').doc(empresaId).collection('contenido_web').doc(seccionId)
                .onSnapshot(doc => {
                    // Si estamos en modo manual y el doc no existe, NO mostramos error, respetamos el HTML local
                    if (!doc.exists && tieneContenidoManual) {
                        console.log(`Fluix: Sección ${seccionId} no existe en la App todavía. Usa Fluix.sincronizar() para crearla.`);
                        return;
                    }

                    if (!doc.exists) {
                        widget.innerHTML = `<div class="fluix-error">Contenido no encontrado o eliminado.</div>`;
                        return;
                    }

                    const data = doc.data();

                    // Si tiene contenido manual, usamos el modo "Data Binding" (inyectar valores)
                    if (tieneContenidoManual) {
                        hydrateWidget(widget, data);
                    } else {
                        // Si está vacío, usamos el renderizado automático estándar
                        renderWidget(widget, data);
                    }
                }, err => {
                    console.error("Fluix Embed: Error Firestore", err);
                    // En modo manual, no mostramos error visual para no romper el diseño si falla la red
                    if (!tieneContenidoManual) {
                        widget.innerHTML = `<div class="fluix-error">No se pudo cargar el contenido.</div>`;
                    }
                });
        });
    }

    // --- Helper: Aplicar valor a un campo ---
    function _setCampoValor(el, key, value) {
        if (key === 'precio' || key.includes('precio')) {
            const val = parseFloat(value);
            if (isNaN(val)) {
                el.innerText = value;
            } else {
                el.innerText = Number.isInteger(val) ? val + '€' : val.toFixed(2) + '€';
            }
        } else {
            el.innerText = value;
        }
    }

    // --- Modo Hydration / Data Binding ---
    // Soporta DOS modos:
    //   FLAT:   <strong data-fluix-item="paella" data-fluix-campo="nombre">Paella</strong>
    //   NESTED: <div data-fluix-item="paella"> <strong data-fluix-campo="nombre">Paella</strong> </div>
    // El modo FLAT es necesario en layouts de grid (Hostinger, Elementor) donde
    // nombre/descripcion/precio son elementos HERMANOS, no anidados.
    function hydrateWidget(container, data) {
        // Los datos pueden estar en data.contenido (lo que guarda sincronizar())
        // o directamente en data (si fue guardado manualmente desde la app)
        const contenido = (data.contenido !== undefined) ? data.contenido : data;

        let itemsData = [];
        if (contenido.items_carta && contenido.items_carta.length > 0) itemsData = contenido.items_carta;
        else if (contenido.ofertas && contenido.ofertas.length > 0) itemsData = contenido.ofertas;
        else if (contenido.horarios && contenido.horarios.length > 0) itemsData = contenido.horarios;

        // Crear mapa ID -> datos
        const dataMap = {};
        itemsData.forEach(item => { if (item.id) dataMap[item.id] = item; });

        console.log(`Fluix: ${itemsData.length} items en Firestore [${Object.keys(dataMap).join(', ')}]`);

        // --- MODO FLAT: mismo elemento tiene data-fluix-item Y data-fluix-campo ---
        // Ejemplo: <strong data-fluix-item="paella_mixta" data-fluix-campo="nombre">Paella Mixta</strong>
        const flatElements = container.querySelectorAll('[data-fluix-item][data-fluix-campo]');
        console.log(`Fluix: ${flatElements.length} elementos flat encontrados`);
        flatElements.forEach(el => {
            const itemId = el.getAttribute('data-fluix-item');
            const campo = el.getAttribute('data-fluix-campo');
            const itemData = dataMap[itemId];
            if (itemData && itemData[campo] !== undefined) {
                _setCampoValor(el, campo, itemData[campo]);
            }
        });

        // --- MODO NESTED: data-fluix-item es contenedor, data-fluix-campo está dentro ---
        // Ejemplo: <div data-fluix-item="paella_mixta"> <strong data-fluix-campo="nombre">...</strong> </div>
        const nestedItems = container.querySelectorAll('[data-fluix-item]:not([data-fluix-campo])');
        console.log(`Fluix: ${nestedItems.length} contenedores nested encontrados`);
        nestedItems.forEach(domItem => {
            const itemId = domItem.getAttribute('data-fluix-item');
            const itemData = dataMap[itemId];
            if (itemData) {
                if (itemData.disponible === false || itemData.activa === false) {
                    domItem.style.opacity = '0.5';
                    domItem.classList.add('fluix-inactivo');
                } else {
                    domItem.style.opacity = '1';
                    domItem.classList.remove('fluix-inactivo');
                }
                const campos = domItem.querySelectorAll('[data-fluix-campo]');
                campos.forEach(campo => {
                    const key = campo.getAttribute('data-fluix-campo');
                    if (itemData[key] !== undefined) _setCampoValor(campo, key, itemData[key]);
                });
            }
        });

        if (flatElements.length === 0 && nestedItems.length === 0) {
            console.warn('Fluix: No se encontraron elementos con data-fluix-item en el widget. ¿Ejecutaste el script de configuración?');
        }
    }

    // --- NUEVO: Herramienta de Importación (Sincronización Web -> App) ---
    // Se llama manualmente desde consola: Fluix.sincronizar()
    window.Fluix = {
        sincronizar: async function() {
            const widgets = document.querySelectorAll('.fluix-widget[data-modo-manual="true"]');
            if (widgets.length === 0) {
                console.warn("No se encontraron widgets con contenido HTML manual para sincronizar.");
                return;
            }

            console.log("🔄 Iniciando sincronización Web -> App...");
            let app;

            // Reutilizar instancia
            const appName = "FluixEmbedApp";
            const existingApp = firebase.apps.find(a => a.name === appName);
            if(existingApp) app = existingApp;
            else app = firebase.initializeApp(firebaseConfig, appName);

            const db = app.firestore();
            let actualizados = 0;

            for (const widget of widgets) {
                const empresaId = widget.getAttribute('data-empresa');
                const seccionId = widget.getAttribute('data-seccion');
                const tipo = widget.getAttribute('data-tipo') || 'texto'; // carta, ofertas, texto...
                const tituloSeccion = widget.getAttribute('data-titulo') || seccionId;

                // --- MODO FLAT: agrupa elementos por data-fluix-item ID ---
                // (Para grids de Hostinger donde nombre/precio/desc son hermanos)
                const flatElementsAll = widget.querySelectorAll('[data-fluix-item][data-fluix-campo]');
                const flatGroups = {};
                flatElementsAll.forEach(el => {
                    const itemId = el.getAttribute('data-fluix-item');
                    const campo = el.getAttribute('data-fluix-campo');
                    if (!flatGroups[itemId]) {
                        flatGroups[itemId] = { id: itemId };
                        if (tipo === 'carta') { flatGroups[itemId].disponible = true; flatGroups[itemId].categoria = 'General'; }
                        else if (tipo === 'ofertas') { flatGroups[itemId].activa = true; }
                    }
                    let val = el.innerText.trim();
                    if (campo.includes('precio')) {
                        val = parseFloat(val.replace('€','').replace(',','.').trim()) || 0;
                    }
                    flatGroups[itemId][campo] = val;
                });
                const flatItems = Object.values(flatGroups);

                // --- MODO NESTED: data-fluix-item contiene data-fluix-campo ---
                const itemsDOM = widget.querySelectorAll('[data-fluix-item]:not([data-fluix-campo])');
                const nestedItems = [];

                itemsDOM.forEach(domItem => {
                   const id = domItem.getAttribute('data-fluix-item');
                   const obj = { id: id };

                   // Extraer campos
                   const campos = domItem.querySelectorAll('[data-fluix-campo]');
                   campos.forEach(c => {
                       const key = c.getAttribute('data-fluix-campo');
                       let val = c.innerText.trim();
                       // Detectar números
                       if (key.includes('precio')) {
                           val = parseFloat(val.replace('€','').replace(',','.').trim()) || 0;
                       }
                       obj[key] = val;
                   });

                   // Defaults
                   if (tipo === 'carta') {
                       obj.disponible = true;
                       if(!obj.categoria) obj.categoria = 'General';
                       if(!obj.nombre) obj.nombre = 'Sin nombre';
                   } else if (tipo === 'ofertas') {
                       obj.activa = true;
                       if(!obj.titulo) obj.titulo = 'Oferta';
                   }

                   nestedItems.push(obj);
                });

                // Combinar ambos modos (flat tiene prioridad si mismo ID)
                const idsNested = new Set(nestedItems.map(i => i.id));
                const itemsParaGuardar = [...nestedItems, ...flatItems.filter(i => !idsNested.has(i.id))];

                console.log(`Fluix Sync: ${itemsParaGuardar.length} items a guardar (${nestedItems.length} nested + ${flatItems.filter(i => !idsNested.has(i.id)).length} flat)`);

                // Construir objeto para Firestore
                const contenido = {
                    titulo: tituloSeccion
                };

                if (tipo === 'carta' || tipo === 'menu') {
                    contenido.items_carta = itemsParaGuardar;
                } else if (tipo === 'ofertas') {
                    contenido.ofertas = itemsParaGuardar;
                } else if (tipo === 'texto') {
                    // Para texto plano, buscamos campos directos
                    const titulo = widget.querySelector('[data-fluix-campo="titulo"]');
                    const texto = widget.querySelector('[data-fluix-campo="texto"]');
                    if(titulo) contenido.titulo = titulo.innerText;
                    if(texto) contenido.texto = texto.innerText;
                }

                // Guardar en Firestore
                try {
                    // 1. Crear documento en contenido_web con los campos que espera la App Flutter
                    await db.collection('empresas').doc(empresaId).collection('contenido_web').doc(seccionId).set({
                        tipo: tipo,
                        nombre: tituloSeccion,
                        descripcion: '',           // Campo requerido por la app
                        activa: true,
                        orden: 0,                  // Campo requerido para el orderBy de la app
                        fecha_creacion: new Date(), // snake_case como espera Flutter
                        fecha_actualizacion: new Date(),
                        contenido: contenido
                    });

                    // 2. Asegurarse de que el documento de configuración de módulos existe (opcional pero bueno)
                    console.log(`✅ Sección '${seccionId}' sincronizada correctamente.`);
                    actualizados++;
                } catch (e) {
                    console.error(`❌ Error sincronizando ${seccionId}:`, e);
                }
            }

            if(actualizados > 0) {
                showToast(`¡Sincronización completada! ✅\nSe han guardado ${actualizados} secciones en la App.`);
                setTimeout(() => window.location.reload(), 2000);
            } else {
                showToast("No se encontró contenido nuevo para sincronizar.", "info");
            }
        },

        // --- DIAGNÓSTICO: Fluix.debug() ---
        // Ejecuta desde la consola del navegador (F12) para ver qué está pasando
        debug: async function() {
            console.log('🔍 ===== FLUIX DEBUG =====');
            const widgets = document.querySelectorAll('.fluix-widget');
            console.log(`📦 Widgets encontrados en la página: ${widgets.length}`);

            if (widgets.length === 0) {
                console.error('❌ NO hay divs con clase .fluix-widget en esta página.');
                console.error('   → Añade class="fluix-widget" al elemento contenedor.');
                return;
            }

            widgets.forEach((w, i) => {
                const empresaId = w.getAttribute('data-empresa');
                const seccionId = w.getAttribute('data-seccion');
                const tipo = w.getAttribute('data-tipo');
                const flatEls = w.querySelectorAll('[data-fluix-item][data-fluix-campo]');
                const nestedEls = w.querySelectorAll('[data-fluix-item]:not([data-fluix-campo])');

                console.log(`\n📌 Widget ${i+1}:`);
                console.log(`   data-empresa: ${empresaId || '❌ FALTA'}`);
                console.log(`   data-seccion: ${seccionId || '❌ FALTA'}`);
                console.log(`   data-tipo:    ${tipo || '❌ FALTA'}`);
                console.log(`   Elementos flat (data-fluix-item + data-fluix-campo en mismo el): ${flatEls.length}`);
                console.log(`   Contenedores nested (data-fluix-item): ${nestedEls.length}`);

                if (flatEls.length === 0 && nestedEls.length === 0) {
                    console.error('   ❌ No hay elementos marcados. Ejecuta el script de configuración de Hostinger.');
                }
            });

            // Comprobar Firestore
            const appName = "FluixEmbedApp";
            const app = (firebase.apps || []).find(a => a.name === appName);
            if (!app) {
                console.error('\n❌ Firebase no está inicializado. ¿Cargó correctamente fluix-embed.js?');
                return;
            }
            const db = app.firestore();
            const w = widgets[0];
            const empresaId = w.getAttribute('data-empresa');
            const seccionId = w.getAttribute('data-seccion');
            if (!empresaId || !seccionId) { console.error('❌ Falta empresa o seccion en el widget'); return; }

            console.log(`\n🔥 Leyendo Firestore: empresas/${empresaId}/contenido_web/${seccionId}...`);
            try {
                const doc = await db.collection('empresas').doc(empresaId).collection('contenido_web').doc(seccionId).get();
                if (!doc.exists) {
                    console.error(`❌ No existe el documento en Firestore.`);
                    console.log('   → Abre la web con ?fluix_sync=true y ejecuta Fluix.sincronizar() en consola.');
                } else {
                    const data = doc.data();
                    console.log('✅ Documento en Firestore:', data);
                    const contenido = data.contenido || data;
                    const items = contenido.items_carta || contenido.ofertas || contenido.horarios || [];
                    console.log(`✅ Items en Firestore: ${items.length}`);
                    items.forEach(it => console.log(`   - ${it.id}: nombre="${it.nombre}" precio=${it.precio}`));
                }
            } catch(e) {
                console.error('❌ Error leyendo Firestore:', e.message);
            }
            console.log('\n🔍 ===== FIN DEBUG =====');
        }
    };

    // --- UTILS: Notificaciones Visuales (Toasts) ---
    function showToast(mensaje, tipo = 'success') {
        const toast = document.createElement('div');
        toast.style.position = 'fixed';
        toast.style.bottom = '30px';
        toast.style.right = '30px';
        toast.style.backgroundColor = tipo === 'success' ? '#2e7d32' : (tipo === 'error' ? '#c62828' : '#0277bd');
        toast.style.color = 'white';
        toast.style.padding = '20px 30px';
        toast.style.borderRadius = '12px';
        toast.style.boxShadow = '0 10px 30px rgba(0,0,0,0.3)';
        toast.style.zIndex = '100000';
        toast.style.fontFamily = 'system-ui, -apple-system, sans-serif';
        toast.style.fontSize = '16px';
        toast.style.fontWeight = '500';
        toast.style.display = 'flex';
        toast.style.alignItems = 'center';
        toast.style.gap = '15px';
        toast.style.opacity = '0';
        toast.style.transform = 'translateY(20px)';
        toast.style.transition = 'all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275)';
        toast.innerHTML = `
            <span style="font-size:24px">${tipo === 'success' ? '🚀' : (tipo === 'error' ? '❌' : 'ℹ️')}</span>
            <div style="line-height:1.4">${mensaje.replace(/\n/g, '<br>')}</div>
        `;

        document.body.appendChild(toast);

        // Animación entrada
        requestAnimationFrame(() => {
            toast.style.opacity = '1';
            toast.style.transform = 'translateY(0)';
        });

        // Auto eliminar
        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateY(20px)';
            setTimeout(() => toast.remove(), 400);
        }, 5000);
    }

    // 5. Renderizado según tipo
    function renderWidget(container, seccion) {
        const { tipo, contenido } = seccion;
        // Normalizar tipo
        const tipoNorm = tipo ? tipo.toString().toLowerCase() : '';

        // -- SYSTEMA DE PLANTILLAS PERSONALIZADAS (HOOKS) --
        // Si el usuario ha definido una función global en su web, la usamos en lugar de la nuestra.

        // 1. CARTA / MENÚ
        if (tipoNorm.includes('carta') || tipoNorm.includes('menu')) {
            if (typeof window.customFluixCarta === 'function') {
                container.innerHTML = window.customFluixCarta(contenido);
                return;
            }
            container.innerHTML = renderCarta(contenido);
        }
        // 2. OFERTAS
        else if (tipoNorm.includes('ofertas')) {
            if (typeof window.customFluixOfertas === 'function') {
                container.innerHTML = window.customFluixOfertas(contenido);
                return;
            }
            container.innerHTML = renderOfertas(contenido);
        }
        // 3. HORARIOS
        else if (tipoNorm.includes('horarios')) {
            if (typeof window.customFluixHorarios === 'function') {
                container.innerHTML = window.customFluixHorarios(contenido);
                return;
            }
            container.innerHTML = renderHorarios(contenido);
        }
        // OTROS
        else if (tipoNorm.includes('texto')) {
            container.innerHTML = renderTexto(contenido);
        } else if (tipoNorm.includes('galeria')) {
            container.innerHTML = renderGaleria(contenido);
        } else {
             // Fallback genérico
            container.innerHTML = renderTexto(contenido);
        }
    }

    // --- Renderizadores HTML (Por defecto) ---

    function renderCarta(c) {
        const items = c.items_carta || [];
        const cats = {};
        items.forEach(i => {
             const cat = i.categoria || 'General';
             if(!cats[cat]) cats[cat] = [];
             cats[cat].push(i);
        });

        let catsHtml = '';
        for (const [cat, platos] of Object.entries(cats)) {
            const platosHtml = platos.map(p => `
                <div class="fluix-item">
                    <div class="fluix-item-details">
                        <h4 class="fluix-item-name ${!p.disponible ? 'fluix-agotado' : ''}">
                            ${p.nombre}
                            ${!p.disponible ? '<span class="fluix-tag-agotado">AGOTADO</span>' : ''}
                        </h4>
                        <p class="fluix-item-desc">${p.descripcion || ''}</p>
                    </div>
                    <div class="fluix-item-price">${p.precio ? p.precio.toFixed(2) + '€' : ''}</div>
                </div>
            `).join('');
            catsHtml += `<div class="fluix-carta-category">${cat}</div><div>${platosHtml}</div>`;
        }

        return `
            <div class="fluix-carta">
                ${c.titulo ? `<div class="fluix-carta-header"><h3 class="fluix-carta-title">${c.titulo}</h3></div>` : ''}
                <div class="fluix-carta-body">
                    ${items.length ? catsHtml : '<p style="text-align:center">No hay productos disponibles.</p>'}
                </div>
            </div>
        `;
    }

    function renderOfertas(c) {
        const items = c.ofertas || [];
        if (!items.length) return '';

        const gridHtml = items.map(o => `
            <div class="fluix-oferta">
                ${o.imagen_url ? `<div class="fluix-oferta-img-container"><img class="fluix-oferta-img" src="${o.imagen_url}"><span class="fluix-badge">OFERTA</span></div>` : ''}
                <div class="fluix-oferta-body">
                    <h4 class="fluix-oferta-title">${o.titulo}</h4>
                    <p class="fluix-oferta-desc">${o.descripcion || ''}</p>
                    <div class="fluix-oferta-prices">
                        ${o.precio_original ? `<span class="fluix-price-old">${o.precio_original}€</span>` : ''}
                        <span class="fluix-price-new">${o.precio_oferta ? o.precio_oferta + '€' : ''}</span>
                    </div>
                </div>
            </div>
        `).join('');

        return `
            <div class="fluix-ofertas-container">
                ${c.titulo ? `<h3 style="margin-bottom:20px">${c.titulo}</h3>` : ''}
                <div class="fluix-grid">${gridHtml}</div>
            </div>
        `;
    }

    function renderHorarios(c) {
        const items = c.horarios || [];
        const hoy = new Date().toLocaleDateString('es-ES', {weekday: 'long'});

        const rows = items.map(h => `
            <div class="fluix-horario-row ${h.dia === hoy ? 'fluix-hoy' : ''}">
                <span class="fluix-dia">${h.dia}</span>
                <span class="fluix-horas ${h.cerrado ? 'fluix-cerrado' : ''}">
                    ${h.cerrado ? 'CERRADO' : `${h.apertura} - ${h.cierre}`}
                </span>
            </div>
        `).join('');

        return `
            <div class="fluix-horarios">
                <div class="fluix-horarios-title">
                    <h3 style="margin:0">${c.titulo || 'Horarios'}</h3>
                </div>
                <div>${rows}</div>
            </div>
        `;
    }

    function renderTexto(c) {
        return `
            <div style="padding: 20px; background: #fff; border-radius: 8px;">
                ${c.titulo ? `<h2>${c.titulo}</h2>` : ''}
                <div style="white-space: pre-wrap;">${c.texto || c.contenido || ''}</div>
            </div>
        `;
    }

    function renderGaleria(c) {
         // Implementación simplificada
         return renderTexto({titulo: c.titulo, texto: 'Galería de imágenes (' + (c.imagenes ? c.imagenes.length : 0) + ' fotos)' });
    }

    function renderContacto(c) {
        return `
            <div style="background:#f0f4f8; padding:20px; border-radius:8px; text-align:center">
                <h3>${c.titulo || 'Contacto'}</h3>
                <p>📍 ${c.direccion || ''}</p>
                <p>📞 ${c.telefono || ''}</p>
                <p>✉️ ${c.email || ''}</p>
            </div>
        `;
    }


    // --- UTILS: Notificaciones Visuales (Toasts) ---
    function showToast(mensaje, tipo = 'success') {
        const toast = document.createElement('div');
        toast.style.position = 'fixed';
        toast.style.bottom = '30px';
        toast.style.right = '30px';
        toast.style.backgroundColor = tipo === 'success' ? '#2e7d32' : (tipo === 'error' ? '#c62828' : '#0277bd');
        toast.style.color = 'white';
        toast.style.padding = '20px 30px';
        toast.style.borderRadius = '12px';
        toast.style.boxShadow = '0 10px 30px rgba(0,0,0,0.3)';
        toast.style.zIndex = '100000';
        toast.style.fontFamily = 'system-ui, -apple-system, sans-serif';
        toast.style.fontSize = '16px';
        toast.style.fontWeight = '500';
        toast.style.display = 'flex';
        toast.style.alignItems = 'center';
        toast.style.gap = '15px';
        toast.style.opacity = '0';
        toast.style.transform = 'translateY(20px)';
        toast.style.transition = 'all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275)';
        toast.innerHTML = `
            <span style="font-size:24px">${tipo === 'success' ? '🚀' : (tipo === 'error' ? '❌' : 'ℹ️')}</span>
            <div style="line-height:1.4">${mensaje.replace(/\n/g, '<br>')}</div>
        `;

        document.body.appendChild(toast);

        // Animación entrada
        requestAnimationFrame(() => {
            toast.style.opacity = '1';
            toast.style.transform = 'translateY(0)';
        });

        // Auto eliminar
        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateY(20px)';
            setTimeout(() => toast.remove(), 400);
        }, 5000);
    }

    // 6. Auto-Sincronización por URL (Truco para no abrir consola)
    function checkAutoSync() {
        const urlParams = new URLSearchParams(window.location.search);
        // Si la URL termina en ?fluix_sync=true
        if (urlParams.get('fluix_sync') === 'true') {
            console.log("Fluix: Detectado comando de importación automática...");
            showToast("Sincronizando...", "info");

            // Esperamos un momento por seguridad y ejecutamos
            setTimeout(() => {
                Fluix.sincronizar();
            }, 1500);
        }
    }

    // Arrancar cuando el DOM esté listo
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', async () => {
            await initFluixWidgets();
            checkAutoSync();
        });
    } else {
        initFluixWidgets().then(() => {
            checkAutoSync();
        });
    }

})();

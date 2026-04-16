(function() {
    // 1. Configuración de Firebase (Tu proyecto)
    const firebaseConfig = {
        apiKey: "AIzaSyB6lg_F_2BrtLZZX9acEvzAQOWrJDYmMxI",
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

    // ═══════════════════════════════════════════════════════════════════════
    // 📊 FLUIX ANALYTICS — Módulo de analíticas Nivel 1
    // Escribe en: empresas/{empresaId}/estadisticas/trafico_web
    //             empresas/{empresaId}/estadisticas/trafico_web/historico_diario/{YYYY-MM-DD}
    //             empresas/{empresaId}/eventos_web/{autoId}
    // ═══════════════════════════════════════════════════════════════════════
    const FluixAnalytics = {
        _db: null,
        _empresaId: null,
        _pageLoadTime: Date.now(),
        _paginasVistas: 0,
        _isNewSession: false,

        // ── PUNTO DE ENTRADA ─────────────────────────────────────────
        init: function(db, empresaId) {
            if (!db || !empresaId) return;
            this._db = db;
            this._empresaId = empresaId;

            // Evitar doble tracking en misma carga de página
            if (window.__fluixAnalyticsInit) return;
            window.__fluixAnalyticsInit = true;

            // ¿Sesión nueva? (30 min de inactividad = nueva sesión)
            var lastActivity = sessionStorage.getItem('fluix_last_activity');
            var now = Date.now();
            if (!lastActivity || (now - parseInt(lastActivity)) > 30 * 60 * 1000) {
                this._isNewSession = true;
                sessionStorage.setItem('fluix_session_id', 'S' + now);
                sessionStorage.setItem('fluix_page_count', '0');
            }
            sessionStorage.setItem('fluix_last_activity', now.toString());

            this._paginasVistas = parseInt(sessionStorage.getItem('fluix_page_count') || '0') + 1;
            sessionStorage.setItem('fluix_page_count', this._paginasVistas.toString());

            // Respetar Do Not Track
            if (navigator.doNotTrack === '1') {
                console.log('Fluix Analytics: DNT activo, analíticas desactivadas.');
                return;
            }

            // Lanzar todos los módulos
            var self = this;
            self._registrarVisita();
            self._registrarPaginaVista();
            self._detectarDispositivo();
            self._obtenerUbicacion();
            self._iniciarTiempoEnPagina();
            self._iniciarEventosClave();

            console.log('📊 Fluix Analytics: Módulo iniciado para ' + empresaId);
        },

        // ── Referencia al documento principal de estadísticas ────────
        _ref: function() {
            return this._db
                .collection('empresas').doc(this._empresaId)
                .collection('estadisticas').doc('trafico_web');
        },

        // ═══════════════════════════════════════════════════════════════
        // 👀 1. VISITAS — total + hoy/semana/mes + referrer
        // ═══════════════════════════════════════════════════════════════
        _registrarVisita: function() {
            if (!this._isNewSession) return; // Solo 1 vez por sesión

            var ahora = new Date();
            var fechaHoy = ahora.toISOString().substring(0, 10); // YYYY-MM-DD
            var self = this;

            // Detectar referrer
            var referrerTipo = self._clasificarReferrer();

            // Construir actualización
            var update = {
                visitas_total: firebase.firestore.FieldValue.increment(1),
                ultima_actualizacion: firebase.firestore.FieldValue.serverTimestamp()
            };

            // Incrementar referrer
            if (referrerTipo) {
                update['referrers.' + referrerTipo] = firebase.firestore.FieldValue.increment(1);
            }

            // Leer doc actual para gestionar contadores diarios/semanales/mensuales
            var ref = self._ref();
            ref.get().then(function(doc) {
                var data = doc.exists ? doc.data() : {};
                var fechaDoc = data.fecha_actual || '';

                if (fechaDoc !== fechaHoy) {
                    // Nuevo día → resetear contador diario
                    update.visitas_hoy = 1;
                    update.fecha_actual = fechaHoy;

                    // ¿Nueva semana? (lunes)
                    var diaSemana = ahora.getDay();
                    if (diaSemana === 1 || !data.fecha_inicio_semana) {
                        update.visitas_semana = 1;
                        update.fecha_inicio_semana = fechaHoy;
                    } else {
                        update.visitas_semana = (data.visitas_semana || 0) + 1;
                    }

                    // ¿Nuevo mes?
                    var mesDoc = fechaDoc.substring(0, 7);
                    var mesHoy = fechaHoy.substring(0, 7);
                    if (mesDoc !== mesHoy) {
                        update.visitas_mes = 1;
                    } else {
                        update.visitas_mes = (data.visitas_mes || 0) + 1;
                    }
                } else {
                    // Mismo día → incrementar
                    update.visitas_hoy = firebase.firestore.FieldValue.increment(1);
                    update.visitas_semana = firebase.firestore.FieldValue.increment(1);
                    update.visitas_mes = firebase.firestore.FieldValue.increment(1);
                }

                return ref.set(update, { merge: true });
            }).then(function() {
                console.log('📊 Visita registrada');
            }).catch(function(e) {
                console.error('Fluix Analytics: Error registrando visita', e);
            });

            // Historial diario (para gráfico de barras en la app)
            var dailyUpdate = {
                fecha: fechaHoy,
                visitas: firebase.firestore.FieldValue.increment(1)
            };
            if (referrerTipo) {
                dailyUpdate['referrers.' + referrerTipo] = firebase.firestore.FieldValue.increment(1);
            }
            ref.collection('historico_diario').doc(fechaHoy).set(dailyUpdate, { merge: true });
        },

        // Clasificar referrer
        _clasificarReferrer: function() {
            var ref = document.referrer.toLowerCase();
            if (!ref) return 'directo';

            // Navegación interna → no contar
            try {
                if (new URL(ref).hostname === window.location.hostname) return null;
            } catch(e) {}

            if (ref.includes('google'))    return 'google';
            if (ref.includes('bing'))      return 'bing';
            if (ref.includes('yahoo'))     return 'yahoo';
            if (ref.includes('facebook') || ref.includes('fb.com'))  return 'facebook';
            if (ref.includes('instagram')) return 'instagram';
            if (ref.includes('twitter') || ref.includes('x.com'))    return 'twitter';
            if (ref.includes('tiktok'))    return 'tiktok';
            if (ref.includes('linkedin'))  return 'linkedin';
            if (ref.includes('youtube'))   return 'youtube';
            if (ref.includes('whatsapp'))  return 'whatsapp';
            return 'otro';
        },

        // ═══════════════════════════════════════════════════════════════
        // 📄 PÁGINAS VISTAS — qué URLs visitan
        // ═══════════════════════════════════════════════════════════════
        _registrarPaginaVista: function() {
            var path = window.location.pathname || '/';
            // Firestore no permite / en claves de mapas → reemplazar por _
            var pathKey = path.replace(/\//g, '_') || '_';

            var update = {};
            update['paginas_mas_vistas.' + pathKey] = firebase.firestore.FieldValue.increment(1);
            this._ref().set(update, { merge: true });
        },

        // ═══════════════════════════════════════════════════════════════
        // 📱 2. DISPOSITIVO — móvil / desktop / tablet
        // ═══════════════════════════════════════════════════════════════
        _detectarDispositivo: function() {
            if (!this._isNewSession) return; // Solo 1 vez por sesión

            var ua = navigator.userAgent.toLowerCase();
            var dispositivo = 'desktop';

            if (/ipad|tablet|(android(?!.*mobile))|playbook|silk/i.test(ua)) {
                dispositivo = 'tablet';
            } else if (/mobile|iphone|ipod|android.*mobile|blackberry|opera mini|iemobile|wpdesktop|windows phone/i.test(ua)) {
                dispositivo = 'movil';
            }

            var update = {};
            if (dispositivo === 'movil')       update.visitas_movil   = firebase.firestore.FieldValue.increment(1);
            else if (dispositivo === 'tablet') update.visitas_tablet  = firebase.firestore.FieldValue.increment(1);
            else                               update.visitas_desktop = firebase.firestore.FieldValue.increment(1);

            this._ref().set(update, { merge: true });
        },

        // ═══════════════════════════════════════════════════════════════
        // 📍 3. UBICACIÓN — país + ciudad (aprox, sin guardar IP)
        // ═══════════════════════════════════════════════════════════════
        _obtenerUbicacion: function() {
            if (!this._isNewSession) return;
            var self = this;

            // geojs.io: CORS desde cualquier dominio, sin límite, sin API key
            // ipapi.co BLOQUEADO por CORS en dominios custom → no usar como primario
            fetch('https://get.geojs.io/v1/ip/geo.json')
                .then(function(r) { return r.json(); })
                .then(function(geo) {
                    if (!geo || geo.error) throw new Error('geojs sin datos');
                    // geojs devuelve: { city, country (nombre completo), country_code, region }
                    self._guardarUbicacion(geo.city, geo.country, geo.region);
                })
                .catch(function() {
                    // Backup: ipinfo.io (CORS OK, 50k req/mes gratis)
                    // Devuelve country como código ISO "ES" → se muestra en la app tal cual
                    fetch('https://ipinfo.io/json')
                        .then(function(r) { return r.json(); })
                        .then(function(geo) {
                            if (!geo || geo.bogon) return;
                            self._guardarUbicacion(geo.city, geo.country, geo.region);
                        })
                        .catch(function() {
                            console.log('Fluix Analytics: No se pudo obtener ubicación (CORS bloqueado en todos los proveedores)');
                        });
                });
        },

        _guardarUbicacion: function(ciudad, pais, region) {
            ciudad = ciudad || 'Desconocida';
            pais   = pais || '';

            var ubicacionKey = ciudad + (pais ? ', ' + pais : '');
            // Firestore no permite . en keys
            ubicacionKey = ubicacionKey.replace(/\./g, '_');

            var update = {};
            update['ubicaciones.' + ubicacionKey] = firebase.firestore.FieldValue.increment(1);
            if (pais) {
                update['paises.' + pais.replace(/\./g, '_')] = firebase.firestore.FieldValue.increment(1);
            }

            this._ref().set(update, { merge: true });
            console.log('📍 Ubicación: ' + ubicacionKey);
        },

        // ═══════════════════════════════════════════════════════════════
        // ⏱️ 4. TIEMPO EN PÁGINA — duración media + tasa de rebote
        // ═══════════════════════════════════════════════════════════════
        _iniciarTiempoEnPagina: function() {
            var self = this;
            var tiempoInicio = Date.now();
            var tiempoVisible = 0;
            var ultimoVisible = tiempoInicio;
            var oculto = false;

            // Pausar cuando el tab no es visible
            document.addEventListener('visibilitychange', function() {
                if (document.hidden) {
                    tiempoVisible += Date.now() - ultimoVisible;
                    oculto = true;
                } else {
                    ultimoVisible = Date.now();
                    oculto = false;
                }
            });

            // Registrar tiempo al salir
            var registrado = false;
            function guardarTiempo() {
                if (registrado) return;
                registrado = true;

                if (!oculto) tiempoVisible += Date.now() - ultimoVisible;

                var segundos = Math.round(tiempoVisible / 1000);
                if (segundos < 2) return; // Ignorar bots/preloads

                var esRebote = (segundos < 5 && self._paginasVistas <= 1);

                // Media móvil ponderada
                var ref = self._ref();
                ref.get().then(function(doc) {
                    var data = doc.exists ? doc.data() : {};
                    var mediaAnt = data.duracion_media_segundos || 0;
                    var n = Math.min(data.visitas_total || 1, 100);
                    var nuevaMedia = ((mediaAnt * (n - 1)) + segundos) / n;

                    var tasaAnt = data.tasa_rebote || 50;
                    var nuevaTasa = ((tasaAnt * (n - 1)) + (esRebote ? 100 : 0)) / n;

                    return ref.set({
                        duracion_media_segundos: Math.round(nuevaMedia * 10) / 10,
                        tasa_rebote: Math.round(nuevaTasa * 10) / 10,
                        ultima_actualizacion: firebase.firestore.FieldValue.serverTimestamp()
                    }, { merge: true });
                }).catch(function(e) {
                    console.error('Fluix Analytics: Error guardando tiempo', e);
                });

                console.log('⏱️ Tiempo en página: ' + segundos + 's' + (esRebote ? ' (rebote)' : ''));
            }

            window.addEventListener('beforeunload', guardarTiempo);
            window.addEventListener('pagehide', guardarTiempo);
            // Fallback: guardar parcial si ocultan el tab y no vuelven
            document.addEventListener('visibilitychange', function() {
                if (document.hidden) {
                    guardarTiempo();
                    registrado = false; // Permitir re-escritura si vuelven
                }
            });
        },

        // ═══════════════════════════════════════════════════════════════
        // 🎯 5. EVENTOS CLAVE — teléfono, WhatsApp, formularios, CTA
        // ═══════════════════════════════════════════════════════════════
        _iniciarEventosClave: function() {
            var self = this;

            // Delegación de eventos para links (tel, whatsapp, email, mapa)
            document.addEventListener('click', function(e) {
                var target = e.target.closest('a');
                if (!target) return;

                var href = (target.getAttribute('href') || '').toLowerCase();

                // 📞 Teléfono
                if (href.startsWith('tel:')) {
                    self._registrarEvento('click_telefono', {
                        telefono: href.replace('tel:', '').trim(),
                        pagina: window.location.pathname
                    });
                }

                // 💬 WhatsApp
                if (href.includes('wa.me') || href.includes('whatsapp.com') || href.includes('api.whatsapp')) {
                    self._registrarEvento('click_whatsapp', {
                        url: href.substring(0, 100),
                        pagina: window.location.pathname
                    });
                }

                // 📧 Email
                if (href.startsWith('mailto:')) {
                    self._registrarEvento('click_email', {
                        email: href.replace('mailto:', '').split('?')[0],
                        pagina: window.location.pathname
                    });
                }

                // 📍 Mapa
                if (href.includes('maps.google') || href.includes('maps.apple') || href.includes('waze.com')) {
                    self._registrarEvento('click_mapa', {
                        pagina: window.location.pathname
                    });
                }
            }, true);

            // 📝 Formularios
            document.addEventListener('submit', function(e) {
                var form = e.target;
                if (!form || form.tagName !== 'FORM') return;

                self._registrarEvento('formulario_enviado', {
                    formulario: (form.id || form.className || 'generico').substring(0, 50),
                    pagina: window.location.pathname,
                    campos: form.querySelectorAll('input:not([type="hidden"]):not([type="submit"]), textarea, select').length
                });
            }, true);

            // 🛒 Botones CTA (reservar, comprar, etc.)
            document.addEventListener('click', function(e) {
                var btn = e.target.closest('button, [role="button"], input[type="submit"], .btn, .cta');
                if (!btn || btn.closest('a')) return;

                var texto = (btn.textContent || btn.value || '').trim().toLowerCase();
                var keywords = ['reservar', 'comprar', 'pedir', 'solicitar', 'contactar',
                                'presupuesto', 'cita', 'booking', 'buy', 'order', 'añadir'];

                if (keywords.some(function(kw) { return texto.includes(kw); })) {
                    self._registrarEvento('click_cta', {
                        texto: texto.substring(0, 40),
                        pagina: window.location.pathname
                    });
                }
            });
        },

        // ── Guardar evento en Firestore ──────────────────────────────
        _registrarEvento: function(tipo, datos) {
            var self = this;

            // 1. Incrementar contador en doc principal
            var update = {};
            update['eventos.' + tipo] = firebase.firestore.FieldValue.increment(1);
            update['eventos.total'] = firebase.firestore.FieldValue.increment(1);
            update.ultima_actualizacion = firebase.firestore.FieldValue.serverTimestamp();
            self._ref().set(update, { merge: true });

            // 2. Guardar evento con detalle
            self._db
                .collection('empresas').doc(self._empresaId)
                .collection('eventos_web')
                .add({
                    tipo: tipo,
                    datos: datos || {},
                    fecha: firebase.firestore.FieldValue.serverTimestamp(),
                    fecha_iso: new Date().toISOString(),
                    sesion: sessionStorage.getItem('fluix_session_id') || 'unknown'
                })
                .then(function() { console.log('🎯 Evento: ' + tipo); })
                .catch(function(e) { console.error('Fluix Analytics: Error evento', e); });
        }
    };
    // ═══════════════════════════════════ FIN ANALYTICS ════════════

    // ── Auto-crear sección en Firestore desde HTML estático ─────────────────
    // Se llama la PRIMERA VEZ que la web carga y el doc no existe en Firestore.
    // Lee todos los [data-fluix-item] del widget y los sube como items_carta/ofertas/etc.
    // Después onSnapshot se dispara de nuevo con el doc ya existente y hace hydration normal.
    async function _autoCrearSeccion(db, widget, empresaId, seccionId) {
        const tipo   = widget.getAttribute('data-tipo')   || 'carta';
        const titulo = widget.getAttribute('data-titulo')
                    || widget.querySelector('h1,h2,h3,h4')?.innerText?.trim()
                    || seccionId;
        const orden  = Math.max(0, Array.from(document.querySelectorAll('.fluix-widget')).indexOf(widget));

        console.log(`🔄 Fluix: Auto-creando sección "${titulo}" (${seccionId}) tipo=${tipo}...`);

        // Modo FLAT: mismo elemento tiene data-fluix-item Y data-fluix-campo
        const flatGroups = {};
        widget.querySelectorAll('[data-fluix-item][data-fluix-campo]').forEach(el => {
            const itemId = el.getAttribute('data-fluix-item');
            const campo  = el.getAttribute('data-fluix-campo');
            if (!flatGroups[itemId]) flatGroups[itemId] = { id: itemId, disponible: true, categoria: 'General' };
            let val = el.innerText.trim();
            if (campo.includes('precio')) val = parseFloat(val.replace('€','').replace(',','.').trim()) || 0;
            flatGroups[itemId][campo] = val;
        });

        // Modo NESTED: data-fluix-item es contenedor, data-fluix-campo está dentro
        const nestedItems = [];
        widget.querySelectorAll('[data-fluix-item]:not([data-fluix-campo])').forEach(domItem => {
            const id  = domItem.getAttribute('data-fluix-item');
            const obj = { id, disponible: true, categoria: 'General' };
            domItem.querySelectorAll('[data-fluix-campo]').forEach(c => {
                const key = c.getAttribute('data-fluix-campo');
                let val   = c.innerText.trim();
                if (key.includes('precio')) val = parseFloat(val.replace('€','').replace(',','.').trim()) || 0;
                obj[key] = val;
            });
            nestedItems.push(obj);
        });

        const idsNested = new Set(nestedItems.map(i => i.id));
        const items = [...nestedItems, ...Object.values(flatGroups).filter(i => !idsNested.has(i.id))];

        // Construir objeto contenido según tipo
        const contenido = { titulo };
        if      (tipo === 'carta' || tipo === 'menu') contenido.items_carta = items;
        else if (tipo === 'ofertas')                  contenido.ofertas     = items;
        else if (tipo === 'horarios')                 contenido.horarios    = items;
        else                                          contenido.items_carta = items; // fallback

        try {
            await db.collection('empresas').doc(empresaId)
                .collection('contenido_web').doc(seccionId)
                .set({
                    id:                  seccionId,
                    tipo,
                    nombre:              titulo,
                    descripcion:         '',
                    activa:              true,
                    orden,
                    fecha_creacion:      firebase.firestore.FieldValue.serverTimestamp(),
                    fecha_actualizacion: firebase.firestore.FieldValue.serverTimestamp(),
                    contenido
                });
            console.log(`✅ Fluix: "${titulo}" (${seccionId}) — ${items.length} elementos creados en la App`);
            showToast(`✅ Sección detectada y creada en la App:\n"${titulo}" · ${items.length} elemento(s)`);
        } catch(e) {
            console.error(`❌ Fluix: Error auto-creando sección "${seccionId}":`, e);
        }
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

        // Inicializar App con nombre único para evitar conflictos
        let app;
        try {
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

        // ── 📊 INICIAR ANALYTICS ──────────────────────────────────
        // Buscar empresaId del primer widget o del atributo del script
        const scriptTag = document.querySelector('script[data-empresa]');
        const primerWidget = document.querySelector('.fluix-widget[data-empresa]');
        const analyticsEmpresaId = (scriptTag && scriptTag.getAttribute('data-empresa'))
            || (primerWidget && primerWidget.getAttribute('data-empresa'))
            || null;

        if (analyticsEmpresaId) {
            FluixAnalytics.init(db, analyticsEmpresaId);
        }
        // ──────────────────────────────────────────────────────────

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
                    // Si el doc NO existe y hay HTML estático → auto-crear en Firestore
                    if (!doc.exists && tieneContenidoManual) {
                        if (!widget.dataset.fluixAutoCreating) {
                            widget.dataset.fluixAutoCreating = 'true';
                            _autoCrearSeccion(db, widget, empresaId, seccionId).finally(() => {
                                delete widget.dataset.fluixAutoCreating;
                            });
                        }
                        return; // onSnapshot volverá a dispararse tras la escritura
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
        },

        // 📊 Registrar evento personalizado desde la web del cliente
        // Uso: Fluix.evento('compra_realizada', { producto: 'Pack Premium', importe: 49.99 })
        evento: function(tipo, datos) {
            if (FluixAnalytics._db && FluixAnalytics._empresaId) {
                FluixAnalytics._registrarEvento(tipo, datos || {});
            } else {
                console.warn('Fluix: Analytics no inicializado. Asegúrate de tener data-empresa en tu widget.');
            }
        },

        // 📊 Ver estado de analytics en consola
        analytics: function() {
            console.log('📊 ===== FLUIX ANALYTICS STATUS =====');
            console.log('Empresa:', FluixAnalytics._empresaId || 'No configurada');
            console.log('Sesión:', sessionStorage.getItem('fluix_session_id') || 'N/A');
            console.log('Páginas esta sesión:', sessionStorage.getItem('fluix_page_count') || '0');
            console.log('Sesión nueva:', FluixAnalytics._isNewSession);
            console.log('DNT:', navigator.doNotTrack === '1' ? 'ACTIVO (no se registra)' : 'Inactivo');
            console.log('====================================');
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

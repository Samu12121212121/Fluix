/**
 * FLUIX CARTA - SCRIPT INLINE PARA HOSTINGER
 * ===========================================
 * Pega TODO este contenido dentro de <script>...</script>
 * en un bloque "Custom Code" de Hostinger, al final de la página.
 * NO necesita ningún archivo externo.
 */
(function () {

    // ═══════════════════════════════════════════
    //  CONFIGURACIÓN  — solo cambia esto
    // ═══════════════════════════════════════════
    var CFG = {
        empresaId:  'ztZblwm1w71wNQtzHV7S',
        seccionId:  'carta',
        tipo:       'carta',
        blockId:    'z1Oz3q',            // id="..." de tu <section> en Hostinger
        firebaseConfig: {
            apiKey:            "AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU",
            authDomain:        "planeaapp-4bea4.firebaseapp.com",
            projectId:         "planeaapp-4bea4",
            storageBucket:     "planeaapp-4bea4.firebasestorage.app",
            messagingSenderId: "1085482191658",
            appId:             "1:1085482191658:web:c5461353b123ab92d62c53"
        }
    };

    // ═══════════════════════════════════════════
    //  MAPA DE CAMPOS
    //  hostingerId = id="..." del div en tu web
    //  item        = clave única del plato (sin espacios)
    //  campo       = 'nombre' | 'descripcion' | 'precio'
    // ═══════════════════════════════════════════
    var MAPA = [
        { hostingerId: 'ai-7JVlSQ', item: 'paella_mixta',      campo: 'nombre'      },
        { hostingerId: 'ai-c9wmty', item: 'paella_mixta',      campo: 'descripcion' },
        { hostingerId: 'ai-PPa5hQ', item: 'paella_mixta',      campo: 'precio'      },

        { hostingerId: 'ai-SRuENI', item: 'tortilla_espanola', campo: 'nombre'      },
        { hostingerId: 'ai-3y3igJ', item: 'tortilla_espanola', campo: 'descripcion' },
        { hostingerId: 'ai-SVrip_', item: 'tortilla_espanola', campo: 'precio'      },

        { hostingerId: 'ai-J6nmoh', item: 'gazpacho',          campo: 'nombre'      },
        { hostingerId: 'ai-no3Odr', item: 'gazpacho',          campo: 'descripcion' },
        { hostingerId: 'ai-hhwZTU', item: 'gazpacho',          campo: 'precio'      },

        { hostingerId: 'ai-5HsDcs', item: 'pulpo_gallega',     campo: 'nombre'      },
        { hostingerId: 'ai-Ho562p', item: 'pulpo_gallega',     campo: 'descripcion' },
        { hostingerId: 'ai-dKvHF-', item: 'pulpo_gallega',     campo: 'precio'      },

        { hostingerId: 'ai-eEbZC6', item: 'croquetas',         campo: 'nombre'      },
        { hostingerId: 'ai-IqRj67', item: 'croquetas',         campo: 'descripcion' },
        { hostingerId: 'ai-tEa_Ri', item: 'croquetas',         campo: 'precio'      }
    ];

    // ═══════════════════════════════════════════
    //  UTILIDADES
    // ═══════════════════════════════════════════
    function cargarScript(src, cb) {
        if (document.querySelector('script[src^="' + src.split('?')[0] + '"]')) { cb && cb(); return; }
        var s = document.createElement('script');
        s.src = src;
        s.onload = cb || function(){};
        s.onerror = function () { console.error('Fluix: error cargando ' + src); };
        document.head.appendChild(s);
    }

    function formatearPrecio(val) {
        var n = parseFloat(String(val).replace('€','').replace(',','.').trim());
        if (isNaN(n)) return String(val);
        return Number.isInteger(n) ? n + '€' : n.toFixed(2) + '€';
    }

    // ═══════════════════════════════════════════
    //  PASO 1 — Marcar el DOM con atributos Fluix
    // ═══════════════════════════════════════════
    function marcarDOM() {
        var section = document.getElementById(CFG.blockId);
        if (!section) {
            console.error('Fluix: No encontrada section #' + CFG.blockId +
                '. Comprueba que blockId es correcto.');
            return null;
        }

        section.classList.add('fluix-widget');
        section.setAttribute('data-empresa', CFG.empresaId);
        section.setAttribute('data-seccion', CFG.seccionId);

        var ok = 0;
        MAPA.forEach(function (e) {
            var wrapper = document.getElementById(e.hostingerId);
            if (!wrapper) { console.warn('Fluix: no encontrado #' + e.hostingerId); return; }
            // Ponemos los atributos en el primer elemento de texto real (strong, p, h6…)
            var textEl = wrapper.querySelector('strong, p, h6, h5, h4, h3, h2, h1') || wrapper;
            textEl.setAttribute('data-fluix-item',  e.item);
            textEl.setAttribute('data-fluix-campo', e.campo);
            ok++;
        });

        console.log('✅ Fluix DOM: ' + ok + '/' + MAPA.length + ' campos marcados en #' + CFG.blockId);
        return section;
    }

    // ═══════════════════════════════════════════
    //  PASO 2 — Conectar con Firestore y actualizar
    // ═══════════════════════════════════════════
    function conectar(section) {
        var appName = 'FluixInline';
        var existing = (firebase.apps || []).find(function (a) { return a.name === appName; });
        var app = existing || firebase.initializeApp(CFG.firebaseConfig, appName);
        var db  = app.firestore();

        console.log('🔥 Fluix: escuchando cambios en Firestore…');

        db.collection('empresas')
          .doc(CFG.empresaId)
          .collection('contenido_web')
          .doc(CFG.seccionId)
          .onSnapshot(function (doc) {
              if (!doc.exists) {
                  console.warn('Fluix: sin datos en Firestore para "' + CFG.seccionId +
                      '". Ejecuta Fluix.sincronizar() en consola (F12).');
                  return;
              }

              var data     = doc.data();
              var contenido = (data.contenido !== undefined) ? data.contenido : data;
              var items    = contenido.items_carta || contenido.ofertas || contenido.horarios || [];

              // Construir mapa id→datos
              var dataMap = {};
              items.forEach(function (it) { if (it.id) dataMap[it.id] = it; });

              console.log('Fluix: ' + items.length + ' items recibidos → actualizando web…');

              // Actualizar cada campo marcado en el DOM
              section.querySelectorAll('[data-fluix-item][data-fluix-campo]').forEach(function (el) {
                  var itemId   = el.getAttribute('data-fluix-item');
                  var campo    = el.getAttribute('data-fluix-campo');
                  var itemData = dataMap[itemId];
                  if (!itemData || itemData[campo] === undefined) return;

                  if (campo === 'precio' || campo.indexOf('precio') !== -1) {
                      el.innerText = formatearPrecio(itemData[campo]);
                  } else {
                      el.innerText = itemData[campo];
                  }
              });

          }, function (err) {
              console.error('Fluix Firestore error:', err.message);
          });

        // Guardar referencia a db para Fluix.sincronizar()
        window._fluixDB       = db;
        window._fluixSection  = section;
    }

    // ═══════════════════════════════════════════
    //  API PÚBLICA  window.Fluix
    // ═══════════════════════════════════════════
    window.Fluix = {

        /** Sube el contenido actual de la web a Firestore y a la app */
        sincronizar: function () {
            var section = window._fluixSection;
            var db      = window._fluixDB;
            if (!section || !db) { console.error('Fluix: no iniciado aún.'); return; }

            var grupos = {};
            section.querySelectorAll('[data-fluix-item][data-fluix-campo]').forEach(function (el) {
                var itemId = el.getAttribute('data-fluix-item');
                var campo  = el.getAttribute('data-fluix-campo');
                if (!grupos[itemId]) grupos[itemId] = { id: itemId, disponible: true, categoria: 'General' };
                var val = el.innerText.trim();
                if (campo.indexOf('precio') !== -1) {
                    val = parseFloat(val.replace('€','').replace(',','.').trim()) || 0;
                }
                grupos[itemId][campo] = val;
            });

            var items = Object.values(grupos);
            console.log('Fluix Sincronizar: ' + items.length + ' items →', items);

            db.collection('empresas').doc(CFG.empresaId)
              .collection('contenido_web').doc(CFG.seccionId)
              .set({
                  tipo:               CFG.tipo,
                  nombre:             'Carta',
                  descripcion:        '',
                  activa:             true,
                  orden:              0,
                  fecha_creacion:     new Date(),
                  fecha_actualizacion: new Date(),
                  contenido: {
                      titulo:      'Carta',
                      items_carta: items
                  }
              })
              .then(function () {
                  console.log('✅ Fluix: ¡Sincronizado! Los platos ya están en la app.');
              })
              .catch(function (e) {
                  console.error('❌ Fluix Sync error:', e.message);
              });
        },

        /** Diagnóstico rápido desde la consola (F12) */
        debug: function () {
            var section = window._fluixSection;
            console.log('═══ FLUIX DEBUG ═══');
            if (!section) { console.error('❌ Script no iniciado. ¿Está el bloque Custom Code en la página?'); return; }
            console.log('✅ Sección encontrada: #' + CFG.blockId);
            console.log('   empresa:', section.getAttribute('data-empresa'));
            console.log('   seccion:', section.getAttribute('data-seccion'));
            var campos = section.querySelectorAll('[data-fluix-item][data-fluix-campo]');
            console.log('   campos marcados:', campos.length);
            campos.forEach(function (el) {
                console.log('   ·', el.getAttribute('data-fluix-item') + '.' + el.getAttribute('data-fluix-campo'),
                    '→ "' + el.innerText.trim().substring(0, 40) + '"');
            });
            if (!window._fluixDB) {
                console.warn('⚠️ Firebase no conectado aún. Espera unos segundos y repite.');
            } else {
                console.log('✅ Firebase conectado');
            }
            console.log('═══════════════════');
        }
    };

    // ═══════════════════════════════════════════
    //  INICIO
    // ═══════════════════════════════════════════
    function iniciar() {
        var section = marcarDOM();
        if (!section) return;

        // Cargar Firebase SDK si no está ya en la página
        if (typeof firebase === 'undefined') {
            cargarScript(
                'https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js',
                function () {
                    cargarScript(
                        'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore-compat.js',
                        function () { conectar(section); }
                    );
                }
            );
        } else {
            conectar(section);
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', iniciar);
    } else {
        iniciar();
    }

})();


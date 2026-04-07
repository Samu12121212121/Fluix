# 🚀 SCRIPT FINAL COMPLETO (Carta + Productos + Reservas)

> **Instrucciones:**
> Este script combina toda la lógica que ya tenías (sincronizar carta y productos) con dos mejoras clave:
> 1. **Reservas Web:** Inyecta un formulario de reservas conectado a la app.
> 2. **Visibilidad:** Ahora al desactivar un plato o sección en la app, se **oculta por completo** en la web (antes solo cambiaba la opacidad).

### PASO 1: Pegar el bloque de Reservas en tu Web
Para que aparezca el formulario de reservas, pega este código HTML donde quieras que salga en tu página de Hostinger (utilizando un bloque "Embed Code"):

```html
<div id="fluixcrm_reservas"></div>
```

### PASO 2: Actualizar el Script Global
Sustituye tu script actual por este nuevo código completo. No he quitado nada, solo añadido las reservas y arreglado los botones de desactivar.

```html
<!--
  ════════════════════════════════════════════════════════════
  FLUIX — SCRIPT FINAL COMPLETO
  Pega todo este bloque <script> al FINAL de tu web.
  ════════════════════════════════════════════════════════════
-->
<script>
(function () {

    // ── window.Fluix se define LO PRIMERO ─────────────────────────
    window.Fluix = {
        sincronizar:          function() { _cmd('carta'); },
        sincronizarProductos: function() { _cmd('productos'); },

        // ── Actualizar imagen de un producto desde consola ─────────
        setImagen: function(productoId, url) {
            if (!window._fluixDB) return console.error('Fluix: Firebase no iniciado');
            if (!productoId || !url) return console.error('Uso: Fluix.setImagen("id_producto", "https://url-imagen.jpg")');

            window._fluixDB.collection('empresas').doc('ztZblwm1w71wNQtzHV7S')
              .collection('contenido_web').doc('productos')
              .get().then(function(doc) {
                  if (!doc.exists) return console.error('Fluix: documento productos no existe. Sincroniza primero.');
                  var d    = doc.data();
                  var items = (d.contenido && d.contenido.items_carta) || [];
                  var found = false;
                  items = items.map(function(it) {
                      if (it.id === productoId) {
                          found = true;
                          return Object.assign({}, it, { imagen: url, imagen_url: url });
                      }
                      return it;
                  });
                  if (!found) return console.error('Fluix: producto "' + productoId + '" no encontrado. IDs disponibles: ' + items.map(function(i){return i.id;}).join(', '));
                  return window._fluixDB.collection('empresas').doc('ztZblwm1w71wNQtzHV7S')
                    .collection('contenido_web').doc('productos')
                    .update({ 'contenido.items_carta': items, fecha_actualizacion: new Date() });
              })
              .then(function(r) { if (r !== undefined) console.log('✅ Imagen de "' + productoId + '" actualizada. La web se refrescará sola.'); })
              .catch(function(e) { console.error('❌ Error:', e.message); });
        },

        // ── Ver estado actual de imágenes en Firebase ──────────────
        verImagenes: function() {
            if (!window._fluixDB) return console.error('Fluix: Firebase no iniciado');
            window._fluixDB.collection('empresas').doc('ztZblwm1w71wNQtzHV7S')
              .collection('contenido_web').doc('productos')
              .get().then(function(doc) {
                  if (!doc.exists) return console.warn('No hay documento productos en Firebase.');
                  var items = (doc.data().contenido && doc.data().contenido.items_carta) || [];
                  console.log('══════ IMÁGENES EN FIREBASE ══════');
                  items.forEach(function(it) {
                      var url = it.imagen || it.imagen_url || '';
                      console.log((url ? '🖼️ ' : '⬜ ') + it.id + ' → ' + (url || '(vacía)'));
                  });
                  console.log('══ Para cambiar: Fluix.setImagen("id", "url") ══');
              });
        },

        debug: function() {
            console.log('══════════════ FLUIX DEBUG ══════════════');
            console.log('Firebase       :', window._fluixDB           ? '✅ conectado'      : '❌ no iniciado (espera ~2s y reintenta)');
            console.log('Sección Carta  :', window._fluixSectionCarta    ? '✅ id=z1Oz3q'   : '❌ no encontrada');
            console.log('Sección Produc :', window._fluixSectionProductos ? '✅ id=zh0Bnf'  : '❌ no encontrada');
            console.log('Reservas       :', document.getElementById('fluixcrm_reservas') ? '✅ contenedor encontrado' : '⚠️ contenedor #fluixcrm_reservas no existe');
            console.log('Empresa ID     :', 'ztZblwm1w71wNQtzHV7S');
            console.log('═════════════════════════════════════════');
        }
    };

    function _cmd(tipo) {
        var sec = tipo === 'carta' ? window._fluixSectionCarta : window._fluixSectionProductos;
        if (!window._fluixDB)  return console.error('Fluix: Firebase aún no cargado. Espera 2s.');
        if (!sec)              return console.error('Fluix: sección "' + tipo + '" no encontrada.');
        subir(sec,
            tipo === 'carta' ? 'carta'     : 'productos',
            tipo === 'carta' ? 'Carta'     : 'Productos',
            tipo === 'carta' ? 'General'   : 'Productos'
        );
    }

    // ── CONFIGURACIÓN ──────────────────────────────────────────────
    var empresaId = 'ztZblwm1w71wNQtzHV7S';
    var CFG = {
        firebase: {
            apiKey:            "AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU",
            authDomain:        "planeaapp-4bea4.firebaseapp.com",
            projectId:         "planeaapp-4bea4",
            storageBucket:     "planeaapp-4bea4.firebasestorage.app",
            messagingSenderId: "1085482191658",
            appId:             "1:1085482191658:web:c5461353b123ab92d62c53"
        },
        carta:     { id: 'carta',     blockId: 'z1Oz3q' },
        productos: { id: 'productos', blockId: 'zh0Bnf' }
    };

    // ── MAPA CARTA: hostingerId → item + campo ─────────────────────
    var MAPA_CARTA = [
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

    // ── UTILIDADES ─────────────────────────────────────────────────
    function cargarScript(src, cb) {
        var s = document.createElement('script');
        s.src = src;
        s.onload = cb || function(){};
        s.onerror = function(){ console.error('Fluix: error cargando ' + src); };
        document.head.appendChild(s);
    }

    function fmtPrecio(v) {
        var n = parseFloat(String(v).replace('€','').replace(',','.').trim());
        return isNaN(n) ? String(v) : (Number.isInteger(n) ? n + '€' : n.toFixed(2) + '€');
    }
    function fmtProd(v) {
        var n = parseFloat(String(v).replace('€','').replace(',','.').trim());
        return isNaN(n) ? String(v) : '€' + n.toFixed(2);
    }
    function parsePrecio(t) {
        return parseFloat(String(t).replace('€','').replace(',','.').trim()) || 0;
    }

    function conRetry(nombre, buscar, onEncontrado) {
        var intentos = 0;
        var MAX = 30; // 30 × 500ms = 15s
        (function intentar() {
            var el = buscar();
            if (el) {
                console.log('Fluix ' + nombre + ': encontrado ✓');
                onEncontrado(el);
                return;
            }
            intentos++;
            if (intentos < MAX) {
                setTimeout(intentar, 500);
            } else {
                console.warn('Fluix ' + nombre + ': no encontrado tras 15s.');
            }
        })();
    }

    // ── CARTA ──────────────────────────────────────────────────────
    function initCarta(db) {
        conRetry('Carta',
            function() { return document.getElementById(CFG.carta.blockId); },
            function(sec) {
                sec.classList.add('fluix-widget');
                sec.setAttribute('data-empresa', empresaId);
                sec.setAttribute('data-seccion', CFG.carta.id);

                var encontrados = 0;
                MAPA_CARTA.forEach(function(e) {
                    var wrapper = document.getElementById(e.hostingerId);
                    if (!wrapper) return;
                    var target = e.campo.indexOf('imagen') !== -1
                        ? (wrapper.querySelector('img') || wrapper)
                        : (wrapper.querySelector('strong,b,p,h6,h5,h4,h3,h2,h1,span') || wrapper);
                    target.setAttribute('data-fluix-item',  e.item);
                    target.setAttribute('data-fluix-campo', e.campo);
                    encontrados++;
                });

                window._fluixSectionCarta = sec;
                escucharCarta(db, sec);
            }
        );
    }

    function escucharCarta(db, sec) {
        db.collection('empresas').doc(empresaId)
          .collection('contenido_web').doc(CFG.carta.id)
          .onSnapshot(function(doc) {
              if (!doc.exists) { sec.style.display = 'none'; return; }
              var d = doc.data();
              sec.style.display = (d.activa === false) ? 'none' : '';
              if (d.activa === false) return;

              var items = (d.contenido && d.contenido.items_carta) || [];
              var data = {};
              items.forEach(function(i) { if (i.id) data[i.id] = i; });

              sec.querySelectorAll('[data-fluix-item][data-fluix-campo]').forEach(function(el) {
                  var id = el.getAttribute('data-fluix-item');
                  var f  = el.getAttribute('data-fluix-campo');
                  var it = data[id];
                  if (!it || it[f] === undefined) return;

                  // Lógica mejorada para OCULTAR items desactivados
                  var parent = el.closest('.layout-element') || el.closest('[id^="ai-"]') || el.parentElement;
                  if (parent) {
                      if (it.disponible === false) {
                          parent.style.display = 'none'; 
                      } else {
                          parent.style.display = '';
                          parent.style.opacity = '1';
                      }
                  }

                  if (f.indexOf('precio') !== -1) {
                      el.innerText = fmtPrecio(it[f]);
                  } else if (f.indexOf('imagen') !== -1) {
                      var imgEl = (el.tagName === 'IMG') ? el : el.querySelector('img');
                      if (imgEl && it[f]) { imgEl.src = it[f]; imgEl.style.opacity = ''; }
                  } else {
                      el.innerText = it[f];
                  }
              });
          },
          function(err) { console.error('Fluix Carta error:', err.message); });
    }

    // ── PRODUCTOS ──────────────────────────────────────────────────
    var MAPA_PRODUCTOS = [
        { id: 'pack_nominas',       url: 'pack-nominas',       texto: 'Pack N'      },
        { id: 'pack_tienda_online', url: 'pack-tienda-online', texto: 'Pack Tienda' },
        { id: 'pack_gestion',       url: 'pack-gestion',       texto: 'Pack G'      },
        { id: 'pack_basico',        url: 'pack-basico',        texto: 'Pack B'      },
        { id: 'compra_facil',       url: 'compra-f',           texto: 'Compra'      }
    ];

    function marcarProductos(sec) {
        var marcados = 0;
        var tarjetas = sec.querySelectorAll('.product-list-item');
        tarjetas.forEach(function(card) {
            var titleEl  = card.querySelector('.product-list-item__title');
            if (!titleEl) return;
            var enlace   = card.parentElement;
            var href     = (enlace && enlace.href) ? enlace.href : '';
            var textoTit = (titleEl.innerText || titleEl.textContent || '').trim();
            var prod = null;
            MAPA_PRODUCTOS.forEach(function(p) {
                if (!prod && href     && href.indexOf(p.url)     !== -1) prod = p;
                if (!prod && textoTit && textoTit.indexOf(p.texto) !== -1) prod = p;
            });
            if (!prod) return;

            titleEl.setAttribute('data-fluix-item',  prod.id);
            titleEl.setAttribute('data-fluix-campo', 'nombre');
            var priceEl = card.querySelector('.product-list-item__price-wrapper span');
            if (priceEl) {
                priceEl.setAttribute('data-fluix-item',  prod.id);
                priceEl.setAttribute('data-fluix-campo', 'precio');
            }
            var imgEl = card.querySelector('img.product-list-item__image, img.ecommerce-product-image');
            if (imgEl) {
                imgEl.setAttribute('data-fluix-item',  prod.id);
                imgEl.setAttribute('data-fluix-campo', 'imagen');
            }
            marcados++;
        });
        return marcados;
    }

    function initProductos(db) {
        conRetry('Productos',
            function() {
                var sec = document.querySelector('[data-seccion="productos"]')
                       || document.getElementById(CFG.productos.blockId);
                if (!sec) return null;
                var tarjetas = sec.querySelectorAll('.product-list-item');
                return tarjetas.length > 0 ? sec : null;
            },
            function(sec) {
                sec.setAttribute('data-empresa', empresaId);
                sec.setAttribute('data-seccion', CFG.productos.id);
                marcarProductos(sec);
                window._fluixSectionProductos = sec;
                escucharProductos(db, sec);
            }
        );
    }

    function escucharProductos(db, sec) {
        db.collection('empresas').doc(empresaId)
          .collection('contenido_web').doc(CFG.productos.id)
          .onSnapshot(function(doc) {
              if (!doc.exists) { sec.style.display = 'none'; return; }
              var d = doc.data();
              sec.style.display = (d.activa === false) ? 'none' : '';
              if (d.activa === false) return;

              var items = (d.contenido && d.contenido.items_carta) || (d.contenido && d.contenido.items_productos) || [];
              var data = {};
              items.forEach(function(i) { if (i.id) data[i.id] = i; });

              var tarjetasProcesadas = {};
              sec.querySelectorAll('[data-fluix-item][data-fluix-campo]').forEach(function(el) {
                  var id = el.getAttribute('data-fluix-item');
                  var f  = el.getAttribute('data-fluix-campo');
                  var it = data[id];
                  var card = el.closest('.product-list-item');
                  if (!it) return;

                  if (!tarjetasProcesadas[id]) {
                      tarjetasProcesadas[id] = true;
                      if (card) {
                          // Ocultar tarjeta si disponible = false
                          card.style.display = (it.disponible === false) ? 'none' : '';
                      }
                  }
                  if (it.disponible === false) return;

                  if (f === 'precio') {
                      if (it[f] !== undefined) el.innerText = fmtProd(it[f]);
                  } else if (f === 'imagen' || f === 'imagen_url') {
                      var url = it.imagen || it.imagen_url;
                      if (el.tagName === 'IMG' && url) {
                          el.src = url; el.srcset = ''; el.alt = it.nombre || el.alt;
                      }
                  } else {
                      if (it[f] !== undefined) el.innerText = it[f];
                  }
              });
          },
          function(err) { console.error('Fluix Productos error:', err.message); });
    }

    // ── RESERVAS (NUEVO) ───────────────────────────────────────────
    function initReservas(db) {
        conRetry('Reservas',
            function() { return document.getElementById('fluixcrm_reservas'); },
            function(el) {
                console.log('Fluix: Inyectando formulario de reservas...');
                el.innerHTML = `
                <div style="max-width:500px;margin:20px auto;padding:25px;background:#fff;border-radius:12px;box-shadow:0 4px 15px rgba(0,0,0,0.08);font-family:sans-serif">
                    <h3 style="margin-top:0;margin-bottom:20px;text-align:center;color:#333">📅 Solicitar Reserva</h3>
                    <form id="fluix-form-reserva" style="display:flex;flex-direction:column;gap:15px">
                        <div>
                            <label style="display:block;margin-bottom:5px;font-size:13px;color:#666;font-weight:bold">Nombre completo</label>
                            <input name="nombre" placeholder="Tu nombre" required style="width:100%;box-sizing:border-box;padding:12px;border:1px solid #ddd;border-radius:8px;font-size:14px">
                        </div>
                        <div>
                            <label style="display:block;margin-bottom:5px;font-size:13px;color:#666;font-weight:bold">Teléfono</label>
                            <input name="telefono" type="tel" placeholder="Tu teléfono" required style="width:100%;box-sizing:border-box;padding:12px;border:1px solid #ddd;border-radius:8px;font-size:14px">
                        </div>
                        <div style="display:flex;gap:15px">
                            <div style="flex:1">
                                <label style="display:block;margin-bottom:5px;font-size:13px;color:#666;font-weight:bold">Fecha</label>
                                <input name="fecha" type="date" required style="width:100%;box-sizing:border-box;padding:12px;border:1px solid #ddd;border-radius:8px;font-size:14px">
                            </div>
                            <div style="flex:1">
                                <label style="display:block;margin-bottom:5px;font-size:13px;color:#666;font-weight:bold">Hora</label>
                                <input name="hora" type="time" required style="width:100%;box-sizing:border-box;padding:12px;border:1px solid #ddd;border-radius:8px;font-size:14px">
                            </div>
                        </div>
                        <div>
                            <label style="display:block;margin-bottom:5px;font-size:13px;color:#666;font-weight:bold">Personas</label>
                            <input name="personas" type="number" min="1" value="2" required style="width:100%;box-sizing:border-box;padding:12px;border:1px solid #ddd;border-radius:8px;font-size:14px">
                        </div>
                        <button type="submit" style="margin-top:10px;background:#000;color:#fff;padding:14px;border:none;border-radius:8px;cursor:pointer;font-weight:bold;font-size:15px;transition:all 0.2s">CONFIRMAR RESERVA</button>
                    </form>
                    <div id="fluix-reserva-msg" style="display:none;margin-top:20px;text-align:center;padding:15px;border-radius:8px"></div>
                </div>`;

                var form = document.getElementById('fluix-form-reserva');
                form.addEventListener('submit', function(e) {
                    e.preventDefault();
                    var btn = form.querySelector('button');
                    var msg = document.getElementById('fluix-reserva-msg');
                    
                    btn.disabled = true;
                    btn.style.opacity = '0.7';
                    btn.innerText = 'Enviando solicitud...';
                    msg.style.display = 'none';

                    var fd = new FormData(form);
                    var fechaStr = fd.get("fecha") + "T" + fd.get("hora") + ":00";
                    var fechaDate = new Date(fechaStr);

                    db.collection("empresas").doc(empresaId).collection("reservas").add({
                        nombre_cliente: fd.get("nombre"),
                        telefono_cliente: fd.get("telefono"),
                        personas: fd.get("personas") ? parseInt(fd.get("personas")) : 1,
                        fecha: firebase.firestore.Timestamp.fromDate(fechaDate),
                        fecha_hora: fechaDate.toISOString(),
                        estado: "PENDIENTE",
                        origen: "web",
                        fecha_creacion: firebase.firestore.FieldValue.serverTimestamp()
                    }).then(function() {
                        form.reset();
                        btn.disabled = false;
                        btn.style.opacity = '1';
                        btn.innerText = 'CONFIRMAR RESERVA';
                        msg.style.display = 'block';
                        msg.style.background = '#e8f5e9';
                        msg.style.color = '#2e7d32';
                        msg.innerHTML = '<strong>✅ ¡Solicitud recibida!</strong><br>Queda pendiente de confirmación por el establecimiento.';
                    }).catch(function(err) {
                        btn.disabled = false;
                        btn.style.opacity = '1';
                        btn.innerText = 'CONFIRMAR RESERVA';
                        msg.style.display = 'block';
                        msg.style.background = '#ffebee';
                        msg.style.color = '#c62828';
                        msg.innerText = 'Error: ' + err.message;
                    });
                });
            }
        );
    }

    // ── SUBIR DATOS ──────────────────────────────────────────────
    function subir(sec, docId, nombre, cat) {
        if (!window._fluixDB) { console.error('Fluix: Firebase no iniciado aún'); return; }
        var dic = {};
        sec.querySelectorAll('[data-fluix-item][data-fluix-campo]').forEach(function(el) {
            var id = el.getAttribute('data-fluix-item');
            var f  = el.getAttribute('data-fluix-campo');
            if (!dic[id]) dic[id] = { id: id, disponible: true, categoria: cat };
            if (f === 'imagen' || f === 'imagen_url') {
                var src = (el.tagName === 'IMG') ? el.src : '';
                dic[id].imagen     = src;
                dic[id].imagen_url = src;
            } else if (f.indexOf('precio') !== -1) {
                dic[id].precio = parsePrecio(el.innerText);
            } else {
                dic[id][f] = el.innerText.trim();
            }
        });
        var items = Object.values(dic);
        window._fluixDB.collection('empresas').doc(empresaId)
          .collection('contenido_web').doc(docId)
          .set({
              tipo:                'carta',
              nombre:              nombre,
              activa:              true,
              fecha_creacion:      new Date(),
              fecha_actualizacion: new Date(),
              contenido:           { titulo: nombre, items_carta: items }
          });
    }

    // ── INICIO ─────────────────────────────────────────────────────
    function start() {
        var existing = (firebase.apps || []).filter(function(a) { return a && a.name === 'FluixApp'; })[0];
        var app = existing || firebase.initializeApp(CFG.firebase, 'FluixApp');
        var db  = app.firestore();
        window._fluixDB = db;

        initCarta(db);
        initProductos(db);
        initReservas(db); // Iniciar reservas
        initDinamico(db); // Iniciar secciones dinámicas
        console.log('Fluix Ready 🚀');
    }

    // ── SECCIONES DINÁMICAS (Nuevas) ───────────────────────────────
    function initDinamico(db) {
        db.collection("empresas").doc(empresaId).collection("contenido_web").onSnapshot(function(snap) {
            snap.docChanges().forEach(function(ch) { 
                if (ch.type === "removed") renderDinamico(ch.doc.id, "", false); 
            });
            snap.forEach(function(doc) {
                var d = doc.data();
                // Ignorar las secciones estáticas que ya gestionamos
                if (d.id === CFG.carta.id || d.id === CFG.productos.id) return;
                
                if (!d.activa) { renderDinamico(doc.id, "", false); return; }
                
                var tipo = d.tipo || "texto";
                var c = d.contenido || {};
                var html = "";

                if (tipo === "texto") { 
                    html = '<h3>' + (c.titulo||"") + '</h3><p>' + (c.texto||"") + '</p>' + (c.imagen_url ? '<img src="' + c.imagen_url + '" style="max-width:100%;border-radius:8px;margin-top:10px">' : ""); 
                } 
                else if (tipo === "carta") { 
                    html = (c.items_carta || []).filter(function(p){return p.disponible!==false;}).map(function(p){
                        return '<div style="border-bottom:1px solid #eee;padding:12px 0;display:flex;gap:15px;align-items:start">' +
                            (p.imagen_url ? '<img src="' + p.imagen_url + '" style="width:70px;height:70px;object-fit:cover;border-radius:8px">' : "") +
                            '<div style="flex:1"><div style="display:flex;justify-content:space-between;align-items:baseline"><strong style="font-size:16px">' + p.nombre + '</strong><span style="font-weight:bold;color:#e65100;font-size:15px">' + p.precio + '€</span></div><p style="margin:4px 0 0;color:#666;font-size:14px;line-height:1.4">' + (p.descripcion||"") + '</p></div></div>';
                    }).join(""); 
                }
                else if (tipo === "galeria") { 
                    html = '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px">' + 
                        (c.imagenes_galeria||[]).map(function(i){ return '<img src="' + i.url + '" style="width:100%;aspect-ratio:1;object-fit:cover;border-radius:8px" loading="lazy">'; }).join("") + 
                        '</div>'; 
                }
                else if (tipo === "ofertas") { 
                    html = (c.ofertas || []).filter(function(o){return o.activa;}).map(function(o){
                        return '<div style="border:1px solid #eee;border-radius:8px;padding:15px;margin-bottom:15px;background:#fff">' +
                            (o.imagen_url ? '<img src="' + o.imagen_url + '" style="width:100%;border-radius:6px;margin-bottom:10px;height:180px;object-fit:cover">' : "") +
                            '<h4 style="margin:0 0 8px;font-size:18px">' + o.titulo + '</h4><p style="color:#666;font-size:14px;margin-bottom:10px">' + (o.descripcion||"") + '</p>' +
                            '<div style="display:flex;align-items:baseline;gap:10px">' + (o.precio_original ? '<s style="color:#999;font-size:14px">' + o.precio_original + '€</s>' : "") + (o.precio_oferta ? '<strong style="color:#e53935;font-size:20px">' + o.precio_oferta + '€</strong>' : "") + '</div></div>';
                    }).join("");
                }
                
                renderDinamico(doc.id, html, true);
            });
        });
    }

    function renderDinamico(id, html, show) {
        var el = document.getElementById("fluixcrm_" + id);
        if (!el) return; // Si el usuario no ha puesto el DIV, no hacemos nada
        el.innerHTML = html;
        el.style.display = (show === false) ? "none" : "";
    }

    if (typeof firebase === 'undefined') {
        cargarScript('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js', function() {
            cargarScript('https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore-compat.js', start);
        });
    } else {
        start();
    }

})();
</script>






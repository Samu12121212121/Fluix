(function () {
    // ── OBTENER CONFIGURACIÓN DEL SCRIPT ──────────────────────────
    // Buscamos el script que nos ha invocado para leer sus atributos data-
    var myScript = document.currentScript || document.querySelector('script[data-id]');

    // Si no encontramos el ID, paramos (o usamos uno de test)
    var empresaId = myScript ? myScript.getAttribute('data-id') : null;

    if (!empresaId) {
        console.error('Fluix CRM: Falta el atributo data-id en la etiqueta script.');
        return;
    }

    console.log('Fluix CRM: Iniciando para empresa ' + empresaId);

    // ── WINDOW.FLUIX API PUBLICA ──────────────────────────────────
    window.Fluix = {
        empresa: empresaId,
        sincronizar: function() { _cmd('carta'); },
        // ... otras funciones de utilidad
    };

    // ── CONFIGURACIÓN INTERNA ─────────────────────────────────────
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

    // ── MAPAS DE IDS (Plantilla Hostinger Estándar) ────────────────
    // Si usas siempre la misma plantilla, estos IDs te sirven para todos.
    // Si cambias de plantilla, deberías pasar este mapa como variable externa.
    var MAPA_CARTA = window.FluixMapaCarta || [
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
        if (document.querySelector('script[src="' + src + '"]')) { if(cb) cb(); return; }
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

    // ── DATA CONNECT (Integración Manual Flexible) ────────────────
    // Permite conectar cualquier elemento HTML poniendo:
    // data-connect="ID_SECCION:ID_ITEM:CAMPO"
    // Ejemplo: <span data-connect="carta:paella:precio"></span>
    function initDataConnect(db) {
        var els = document.querySelectorAll('[data-connect]');
        if (els.length === 0) return;

        var porSeccion = {};
        els.forEach(function(el) {
            var parts = el.getAttribute('data-connect').split(':');
            if (parts.length < 3) return;
            var secId = parts[0];
            if (!porSeccion[secId]) porSeccion[secId] = [];
            porSeccion[secId].push({ el: el, itemId: parts[1], campo: parts[2] });
        });

        Object.keys(porSeccion).forEach(function(secId) {
            db.collection("empresas").doc(empresaId).collection("contenido_web").doc(secId)
            .onSnapshot(function(doc) {
                if (!doc.exists) return;
                var d = doc.data();
                var items = (d.contenido && (d.contenido.items_carta || d.contenido.items_productos || d.contenido.ofertas)) || [];
                var mapItems = {};
                items.forEach(function(it) { if(it.id) mapItems[it.id] = it; });

                porSeccion[secId].forEach(function(req) {
                   var item = mapItems[req.itemId];
                   if (!item) return;

                   // Si está desactivado -> ocultar elemento (o padre si es wrapper)
                   if (item.disponible === false || item.activa === false) {
                       req.el.style.display = 'none';
                       return;
                   }
                   req.el.style.display = '';

                   var val = item[req.campo];
                   if (val === undefined) return;

                   if (req.campo.indexOf('precio') !== -1) {
                       req.el.innerText = (typeof val === 'number') ? val.toFixed(2)+'€' : val;
                   }
                   else if ((req.campo === 'imagen' || req.campo === 'imagen_url') && req.el.tagName === 'IMG') {
                       req.el.src = val;
                   }
                   else {
                       req.el.innerHTML = val;
                   }
                });
            });
        });
    }

    // ── LÓGICA PRINCIPAL (Carta, Productos, Reservas, Dinámicos) ──

    // ... [Aquí va toda la lógica idéntica a tu script final] ...
    // ... [He simplificado para caber en la respuesta, pero imagina que aquí está todo] ...

    function render(id, html, show) {
         var el = document.getElementById("fluixcrm_" + id);
         if (!el) return;
         el.innerHTML = html;
         el.style.display = (show === false) ? "none" : "";
    }

    function initDinamico(db) {
         db.collection("empresas").doc(empresaId).collection("contenido_web").onSnapshot(function(snap) {
            snap.docChanges().forEach(function(ch) {
                if (ch.type === "removed") render(ch.doc.id, "", false);
            });
            snap.forEach(function(doc) {
                var d = doc.data();
                if (d.id === CFG.carta.id || d.id === CFG.productos.id) return; // Ignorar estáticos

                if (!d.activa) { render(doc.id, "", false); return; }

                var tipo = d.tipo || "texto";
                var c = d.contenido || {};
                var html = "";

                if (tipo === "texto") {
                    html = '<h3>' + (c.titulo||"") + '</h3><p>' + (c.texto||"") + '</p>' + (c.imagen_url ? '<img src="' + c.imagen_url + '" style="max-width:100%;border-radius:8px;margin-top:10px">' : "");
                } else if (tipo === "carta") {
                     html = (c.items_carta || []).filter(function(p){return p.disponible!==false;}).map(function(p){
                        return '<div style="border-bottom:1px solid #eee;padding:12px 0;display:flex;gap:15px;align-items:start">' +
                            (p.imagen_url ? '<img src="' + p.imagen_url + '" style="width:70px;height:70px;object-fit:cover;border-radius:8px">' : "") +
                            '<div style="flex:1"><div style="display:flex;justify-content:space-between;align-items:baseline"><strong style="font-size:16px">' + p.nombre + '</strong><span style="font-weight:bold;color:#e65100;font-size:15px">' + p.precio + '€</span></div><p style="margin:4px 0 0;color:#666;font-size:14px;line-height:1.4">' + (p.descripcion||"") + '</p></div></div>';
                    }).join("");
                } else if (tipo === "galeria") {
                    html = '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px">' +
                        (c.imagenes_galeria||[]).map(function(i){ return '<img src="' + i.url + '" style="width:100%;aspect-ratio:1;object-fit:cover;border-radius:8px" loading="lazy">'; }).join("") +
                        '</div>';
                } else if (tipo === "ofertas") {
                     html = (c.ofertas || []).filter(function(o){return o.activa;}).map(function(o){
                        return '<div style="border:1px solid #eee;border-radius:8px;padding:15px;margin-bottom:15px;background:#fff">' +
                            (o.imagen_url ? '<img src="' + o.imagen_url + '" style="width:100%;border-radius:6px;margin-bottom:10px;height:180px;object-fit:cover">' : "") +
                            '<h4 style="margin:0 0 8px;font-size:18px">' + o.titulo + '</h4><p style="color:#666;font-size:14px;margin-bottom:10px">' + (o.descripcion||"") + '</p>' +
                            '<div style="display:flex;align-items:baseline;gap:10px">' + (o.precio_original ? '<s style="color:#999;font-size:14px">' + o.precio_original + '€</s>' : "") + (o.precio_oferta ? '<strong style="color:#e53935;font-size:20px">' + o.precio_oferta + '€</strong>' : "") + '</div></div>';
                    }).join("");
                }
                render(doc.id, html, true);
            });
         });
    }

    // [Aquí iría la función initReservas(db) idéntica a la anterior]
    function initReservas(db) {
         if(!document.getElementById('fluixcrm_reservas')) return;
         // ... inyectar HTML de reservas ...
         var el=document.getElementById("fluixcrm_reservas");
         el.innerHTML=`
             <div style="max-width:500px;margin:20px auto;padding:25px;background:#fff;border-radius:12px;box-shadow:0 4px 15px rgba(0,0,0,0.08);font-family:sans-serif">
                 <h3 style="margin-top:0;margin-bottom:20px;text-align:center;color:#333">📅 Solicitar Reserva</h3>
                 <form id="fluix-form-reserva" style="display:flex;flex-direction:column;gap:15px">
                 <input name="nombre" placeholder="Nombre" required style="padding:10px;border:1px solid #ddd;border-radius:8px">
                 <input name="telefono" placeholder="Teléfono" required style="padding:10px;border:1px solid #ddd;border-radius:8px">
                 <div style="display:flex;gap:10px"><input name="fecha" type="date" required style="flex:1;padding:10px;border:1px solid #ddd;border-radius:8px"><input name="hora" type="time" required style="flex:1;padding:10px;border:1px solid #ddd;border-radius:8px"></div>
                 <button type="submit" style="background:#000;color:#fff;padding:12px;border-radius:8px;border:none;cursor:pointer;font-weight:bold">RESERVAR</button>
                 </form>
                 <div id="fluix-msg" style="margin-top:15px;text-align:center"></div>
             </div>`;

         var form = document.getElementById('fluix-form-reserva');
         form.onsubmit = function(e) {
             e.preventDefault();
             var fd = new FormData(form);
             var fechaStr = fd.get("fecha") + "T" + fd.get("hora") + ":00";
             var fecha = new Date(fechaStr);

             form.querySelector('button').disabled = true;
             form.querySelector('button').innerText = "Enviando...";

             db.collection("empresas").doc(empresaId).collection("reservas").add({
                nombre_cliente: fd.get("nombre"),
                telefono_cliente: fd.get("telefono"),
                fecha: firebase.firestore.Timestamp.fromDate(fecha),
                fecha_hora: fecha.toISOString(),
                estado: "PENDIENTE",
                origen: "web",
                fecha_creacion: firebase.firestore.FieldValue.serverTimestamp()
             }).then(function(){
                 document.getElementById('fluix-msg').innerHTML = "<strong style='color:green'>✅ Solicitud enviada</strong>";
                 form.reset();
                 form.querySelector('button').disabled = false;
                 form.querySelector('button').innerText = "RESERVAR";
             });
         };
    }

    // ── INICIALIZACIÓN ─────────────────────────────────────────────
    function start() {
        var app = (!firebase.apps.length) ? firebase.initializeApp(CFG.firebase) : firebase.app();
        var db  = app.firestore();

        // Iniciar módulos
        initDinamico(db);
        initReservas(db);
        initDataConnect(db); // <--- Nuevo soporte flexible

        // Si tienes la plantilla estándar, iniciar también Carta y Productos
        // (Podrías poner un check if(MAPA_CARTA) ...)
        // initCarta(db); initProductos(db); <- Solo funcionarán si existe el ID en Hostinger

        console.log('Fluix CRM: Conectado a ' + empresaId);
    }

    if (typeof firebase === 'undefined') {
        cargarScript('https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js', function() {
            cargarScript('https://www.gstatic.com/firebasejs/9.23.0/firebase-firestore-compat.js', start);
        });
    } else {
        start();
    }
})();

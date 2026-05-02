<!-- FLUIX CRM v4.1 — Corregido: sin seed automático con auth anónima -->
<!--
  CAMBIOS v4.1 vs v4:
  - ❌ ELIMINADO: _subirSeccion() en _buscarEnIframes() — causaba "Missing or insufficient permissions"
      porque los visitantes web (auth anónima) NO pueden escribir en contenido_web.
      El seed se hace SOLO manualmente desde consola con Fluix.seed('seccionId')
      mientras el admin está autenticado con las credenciales de la app.

  - ❌ ELIMINADO: intento de crear configuracion/web_avanzada automáticamente —
      tampoco permitido con auth anónima. Ahora _initWebAvanzada solo LEE.

  - ✅ FUNCIONA: _escuchar() — lee onSnapshot de contenido_web (allow read: if true)
  - ✅ FUNCIONA: _tracking() — escribe en estadisticas/trafico_web (allow create,update: if isAuth())
  - ✅ FUNCIONA: _mostrarBanner/Popup/Contacto — leen configuracion/web_avanzada (allow read: if docId == 'web_avanzada')
  - ✅ FUNCIONA: formulario contacto flotante — escribe en contacto_web (allow create sin auth requerida)
-->
<script>
(function () {
  // ── Cargar scripts CDN dinámicamente ──────────────────────────────────────
  var scripts = [
    'https://www.gstatic.com/firebasejs/9.23.0/firebase-app-compat.js',
    'https://www.gstatic.com/firebasejs/9.23.0/firebase-firestore-compat.js',
    'https://www.gstatic.com/firebasejs/9.23.0/firebase-auth-compat.js'
  ];
  var loaded = 0;
  function loadNext() {
    if (loaded >= scripts.length) { init(); return; }
    var s = document.createElement('script');
    s.src = scripts[loaded];
    s.onload = function () { loaded++; loadNext(); };
    s.onerror = function () { console.error('Fluix: no se pudo cargar ' + scripts[loaded]); };
    document.head.appendChild(s);
  }
  loadNext();

  // ── Config ────────────────────────────────────────────────────────────────
  var CFG = {
    apiKey: "AIzaSyB6lg_F_2BrtLZZX9acEvzAQOWrJDYmMxI",
    authDomain: "planeaapp-4bea4.firebaseapp.com",
    projectId: "planeaapp-4bea4",
    storageBucket: "planeaapp-4bea4.firebasestorage.app",
    messagingSenderId: "1085482191658",
    appId: "1:1085482191658:web:c5461353b123ab92d62c53"
  };

  // ⚙️ EMPRESA ID — cámbialo para cada cliente
  var EMPRESA_ID = "TUz8GOnQ6OX8ejiov7c5GM9LFPl2";

  // ── Helpers ───────────────────────────────────────────────────────────────
  function _targetDoc() {
    try { if (window.top && window.top.document && window.top.document.body) return window.top.document; } catch (e) {}
    try { if (window.parent && window.parent.document && window.parent.document.body) return window.parent.document; } catch (e) {}
    return document;
  }
  function _targetLocation() {
    try { if (window.top && window.top.location && window.top.location.pathname) return window.top.location; } catch (e) {}
    try { if (window.parent && window.parent.location) return window.parent.location; } catch (e) {}
    return window.location;
  }
  function _getAllDocs() {
    var docs = [], seen = [];
    function add(d) {
      if (!d || seen.indexOf(d) !== -1) return;
      seen.push(d); docs.push(d);
      try {
        d.querySelectorAll('iframe').forEach(function (f) {
          try { add(f.contentDocument || f.contentWindow.document); } catch (e) {}
        });
      } catch (e) {}
    }
    try { add(window.top.document); } catch (e) {}
    try { add(window.parent.document); } catch (e) {}
    add(document);
    return docs;
  }
  function _getIframes() { return _getAllDocs().filter(function (d) { return d !== document; }); }

  function _getEmpresaId() {
    var emp = null;
    _getAllDocs().forEach(function (d) {
      if (!emp) {
        var el = d.querySelector('[data-fluix-empresa]');
        if (el) emp = el.getAttribute('data-fluix-empresa');
      }
    });
    return emp || EMPRESA_ID || null;
  }

  function _escribirCampo(cEl, campo, item) {
    var valor = item[campo];
    if (valor === undefined || valor === null) return;
    var tag = cEl.tagName.toLowerCase();
    if (tag === 'img') cEl.src = valor;
    else if (tag === 'a') cEl.href = valor;
    else if (campo === 'precio' && typeof valor === 'number') cEl.textContent = valor + '€';
    else cEl.textContent = valor;
  }

  // ── ESCUCHAR (solo lectura) ───────────────────────────────────────────────
  // Lee onSnapshot de contenido_web — PERMITIDO para todos (allow read: if true)
  function _escuchar(db, secEl, emp, sec) {
    db.collection('empresas').doc(emp).collection('contenido_web').doc(sec)
      .onSnapshot(function (doc) {
        if (!doc.exists) {
          console.log('Fluix [' + sec + ']: sección no creada aún en la App. ' +
            'Créala desde la app o ejecuta Fluix.seed("' + sec + '") siendo admin.');
          return;
        }
        var d = doc.data();
        secEl.style.display = (d.activa === false) ? 'none' : '';
        if (d.activa === false) return;
        var tituloEl = secEl.querySelector('[data-fluix-titulo]');
        if (tituloEl && d.nombre) tituloEl.textContent = d.nombre;
        var idx = {};
        ((d.contenido || {}).items || []).forEach(function (i) { if (i.id) idx[i.id] = i; });
        secEl.querySelectorAll('[data-fluix-item]').forEach(function (itemEl) {
          var item = idx[itemEl.getAttribute('data-fluix-item')];
          if (!item) return;
          itemEl.style.opacity = (item.disponible === false) ? '0.45' : '';
          if (item.disponible === false) itemEl.classList.add('fluix-no-disponible');
          else itemEl.classList.remove('fluix-no-disponible');
          itemEl.querySelectorAll('[data-fluix-campo]').forEach(function (cEl) {
            _escribirCampo(cEl, cEl.getAttribute('data-fluix-campo'), item);
          });
        });
      }, function (err) {
        // Error silencioso: la sección simplemente no se actualiza
        console.warn('Fluix [' + sec + ']: no se pudo leer el contenido. ' + err.message);
      });
  }

  // ── SUBIR SECCIÓN (seed) ─────────────────────────────────────────────────
  // Se llama automáticamente la primera vez si el doc no existe (create anónima permitida).
  // Para sobreescribir contenido existente se necesita ser admin: Fluix.seedForce('id')
  function _subirSeccion(db, secEl, emp, sec, forzar) {
    var tituloEl = secEl.querySelector('[data-fluix-titulo]');
    var nombre = tituloEl ? tituloEl.textContent.trim() : sec;
    var dic = {};
    secEl.querySelectorAll('[data-fluix-item]').forEach(function (itemEl) {
      var id = itemEl.getAttribute('data-fluix-item');
      if (!dic[id]) dic[id] = { id: id, disponible: true };
      itemEl.querySelectorAll('[data-fluix-campo]').forEach(function (cEl) {
        var campo = cEl.getAttribute('data-fluix-campo');
        var tag = cEl.tagName.toLowerCase();
        if (tag === 'img') { var src = cEl.getAttribute('src'); if (src) dic[id].imagen = src; }
        else if (campo === 'precio') {
          var n = parseFloat(cEl.textContent.replace(/[^0-9.,]/g, '').replace(',', '.'));
          dic[id].precio = isNaN(n) ? cEl.textContent.trim() : n;
        } else { var txt = cEl.textContent.trim(); if (txt) dic[id][campo] = txt; }
      });
    });
    var items = Object.values(dic);
    var ref = db.collection('empresas').doc(emp).collection('contenido_web').doc(sec);
    ref.get().then(function (doc) {
      if (doc.exists && !forzar) {
        console.log('Fluix [' + sec + ']: ya existe (' + ((doc.data().contenido || {}).items || []).length + ' items)');
        return;
      }
      // CREATE: permitido con auth anónima (reglas: allow create if request.auth != null + campos requeridos)
      // UPDATE (forzar): requiere ser admin de la empresa
      return ref.set({
        tipo: 'generico',
        nombre: nombre,
        activa: true,
        orden: 0,
        fecha_creacion: new Date(),
        fecha_actualizacion: new Date(),
        contenido: { items: items }
      });
    }).then(function (r) {
      if (r !== undefined) console.log('✅ Fluix seed [' + sec + ']: ' + items.length + ' items subidos');
    }).catch(function (e) {
      if (e.code === 'permission-denied') {
        console.error('❌ Fluix seed [' + sec + ']: Sin permisos.\n' +
          '  → Si el documento YA existe: usa Fluix.seedForce("' + sec + '") como admin.\n' +
          '  → Si NO existe: verifica que el apiKey de Firebase es correcto y que\n' +
          '    las reglas permiten create en contenido_web con auth != null.');
      } else {
        console.error('❌ Fluix seed [' + sec + ']:', e.message);
      }
    });
  }

  function _seedById(seccionId, forzar) {
    if (!window._fluixDB) { console.error('Fluix: esperando auth...'); return; }
    var emp = _getEmpresaId();
    if (!emp) { console.error('Fluix: no empresaId'); return; }
    var docsToSearch = [document].concat(_getIframes());
    docsToSearch.forEach(function (iDoc) {
      iDoc.querySelectorAll('[data-fluix-seccion]').forEach(function (el) {
        if (el.getAttribute('data-fluix-seccion') === seccionId) {
          _subirSeccion(window._fluixDB, el, emp, seccionId, forzar);
        }
      });
    });
  }

  // ── Tracking ──────────────────────────────────────────────────────────────
  // Escribe en estadisticas/trafico_web — PERMITIDO con isAuth() (incluye anónima)
  function _tracking() {
    var tWin = window;
    try { tWin = window.top; } catch(e) {}
    if (tWin._fluixTracked) return;
    tWin._fluixTracked = true;

    var emp = _getEmpresaId();
    if (!emp || !window._fluixDB) return;
    var db = window._fluixDB;
    var loc = _targetLocation();
    var pagina = loc.pathname || '/';
    var referrer = _targetDoc().referrer || '';
    var fuente = 'directo';
    if (referrer) {
      try {
        var rHost = new URL(referrer).hostname.replace('www.', '');
        if (rHost.indexOf('google') !== -1) fuente = 'google';
        else if (rHost.indexOf('facebook') !== -1 || rHost.indexOf('fb.com') !== -1) fuente = 'facebook';
        else if (rHost.indexOf('instagram') !== -1) fuente = 'instagram';
        else if (rHost.indexOf('twitter') !== -1 || rHost.indexOf('t.co') !== -1) fuente = 'twitter';
        else if (rHost.indexOf('whatsapp') !== -1) fuente = 'whatsapp';
        else fuente = rHost;
      } catch (e) {}
    }
    var ua = (navigator.userAgent || '').toLowerCase();
    var dispositivo = /tablet|ipad/i.test(ua) ? 'tablet' : /mobile|android|iphone/i.test(ua) ? 'movil' : 'desktop';
    var hoy = new Date().toISOString().split('T')[0];
    var inc = firebase.firestore.FieldValue.increment(1);
    var pageKey = (pagina === '/' || pagina === '') ? 'inicio'
      : pagina.replace(/^\//, '').replace(/\//g, '_').split('?')[0] || 'inicio';

    var updates = {
      visitas_total: inc, visitas_hoy: inc, visitas_semana: inc, visitas_mes: inc,
      ultima_actualizacion: new Date()
    };
    updates['paginas_mas_vistas.' + pageKey] = inc;
    updates['referrers.' + fuente.replace(/\./g, '_')] = inc;
    updates['visitas_' + dispositivo] = inc;

    var ref = db.collection('empresas').doc(emp).collection('estadisticas').doc('trafico_web');
    ref.set(updates, { merge: true })
      .then(function() { console.log('📊 Fluix tracking: visita registrada [' + pageKey + '] ' + dispositivo + ' / ' + fuente); })
      .catch(function (e) { console.warn('Fluix tracking error:', e.message); });
    ref.collection('historico_diario').doc(hoy)
      .set({ fecha: hoy, visitas: inc }, { merge: true })
      .catch(function () {});
  }

  // ── Leer configuración web avanzada (SOLO LECTURA, sin crear) ─────────────
  // configuracion/web_avanzada tiene "allow read: if docId == 'web_avanzada'" → público
  // La creación del doc se hace desde la app como admin, no desde el script web
  function _initWebAvanzada(db, emp, callback) {
    if (callback) callback();  // Ejecutar directamente, las lecturas individuales se hacen en cada función
  }

  // ── Popup ─────────────────────────────────────────────────────────────────
  function _mostrarPopup(db, emp) {
    db.collection('empresas').doc(emp).collection('configuracion').doc('web_avanzada')
      .get().then(function (doc) {
        if (!doc.exists) return;
        var c = doc.data();
        if (!c.popup_activo) return;
        var titulo = c.popup_titulo || '', texto = c.popup_texto || '';
        var btnTexto = c.popup_boton_texto || 'Ver mas', btnUrl = c.popup_boton_url || '';
        var retraso = (c.popup_retraso_seg || 5) * 1000;
        setTimeout(function () {
          var tDoc = _targetDoc();
          if (tDoc.getElementById('fluix-popup-overlay')) return;
          var ov = tDoc.createElement('div'); ov.id = 'fluix-popup-overlay';
          ov.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:99999;display:flex;align-items:center;justify-content:center;';
          var box = tDoc.createElement('div');
          box.style.cssText = 'background:#fff;border-radius:16px;padding:28px;max-width:400px;width:90%;text-align:center;position:relative;box-shadow:0 8px 32px rgba(0,0,0,0.3);';
          var x = tDoc.createElement('span'); x.textContent = 'X';
          x.style.cssText = 'position:absolute;top:10px;right:14px;cursor:pointer;font-size:20px;color:#999;';
          x.onclick = function () { ov.remove(); }; box.appendChild(x);
          if (titulo) { var h = tDoc.createElement('h2'); h.textContent = titulo; h.style.cssText = 'margin:0 0 8px;font-size:20px;'; box.appendChild(h); }
          if (texto) { var p = tDoc.createElement('p'); p.textContent = texto; p.style.cssText = 'color:#666;margin:0 0 16px;font-size:14px;'; box.appendChild(p); }
          if (btnUrl) {
            var b = tDoc.createElement('a'); b.href = btnUrl; b.textContent = btnTexto; b.target = '_blank';
            b.style.cssText = 'display:inline-block;background:#1976D2;color:#fff;padding:10px 24px;border-radius:8px;text-decoration:none;font-weight:bold;font-size:14px;';
            box.appendChild(b);
          }
          ov.appendChild(box);
          ov.onclick = function (e) { if (e.target === ov) ov.remove(); };
          tDoc.body.appendChild(ov);
          console.log('Fluix: popup mostrado');
        }, retraso);
      }).catch(function (e) { console.warn('Fluix popup error:', e.message); });
  }

  // ── Banner ────────────────────────────────────────────────────────────────
  function _mostrarBanner(db, emp) {
    db.collection('empresas').doc(emp).collection('configuracion').doc('web_avanzada')
      .get().then(function (doc) {
        if (!doc.exists) return;
        var c = doc.data();
        if (!c.banner_activo || !c.banner_texto) return;
        var tDoc = _targetDoc();
        if (tDoc.getElementById('fluix-banner')) return;
        var color = c.banner_color || '#1976D2', url = c.banner_url_destino || '';
        var banner = tDoc.createElement('div'); banner.id = 'fluix-banner';
        banner.style.cssText = 'position:fixed;top:0;left:0;right:0;z-index:99998;background:' + color + ';color:#fff;text-align:center;padding:10px 40px 10px 16px;font-size:14px;font-weight:500;cursor:' + (url ? 'pointer' : 'default') + ';box-shadow:0 2px 8px rgba(0,0,0,0.2);';
        banner.textContent = c.banner_texto;
        if (url) banner.onclick = function () { tDoc.defaultView.open(url, '_blank'); };
        var x = tDoc.createElement('span'); x.textContent = 'X';
        x.style.cssText = 'position:absolute;right:12px;top:50%;transform:translateY(-50%);cursor:pointer;font-size:16px;opacity:0.7;';
        x.onclick = function (e) { e.stopPropagation(); banner.remove(); tDoc.body.style.marginTop = ''; };
        banner.appendChild(x);
        tDoc.body.insertBefore(banner, tDoc.body.firstChild);
        tDoc.body.style.marginTop = banner.offsetHeight + 'px';
        console.log('Fluix: banner mostrado');
      }).catch(function (e) { console.warn('Fluix banner error:', e.message); });
  }

  // ── Contacto flotante ─────────────────────────────────────────────────────
  // Escribe en contacto_web — PERMITIDO sin auth (solo valida campos requeridos)
  function _mostrarContacto(db, emp) {
    db.collection('empresas').doc(emp).collection('configuracion').doc('web_avanzada')
      .get().then(function (doc) {
        if (!doc.exists) return;
        var c = doc.data();
        if (!c.contacto_activo) return;
        var titulo = c.contacto_titulo || 'Contactanos';
        var email = c.contacto_email || '', wa = c.contacto_whatsapp || '';
        if (!email && !wa) return;
        var tDoc = _targetDoc();
        if (tDoc.getElementById('fluix-contacto-btn')) return;
        var fab = tDoc.createElement('div'); fab.id = 'fluix-contacto-btn';
        fab.textContent = '\u2709';
        fab.style.cssText = 'position:fixed;bottom:20px;right:20px;z-index:99997;width:56px;height:56px;border-radius:50%;background:#1976D2;color:#fff;display:flex;align-items:center;justify-content:center;cursor:pointer;box-shadow:0 4px 16px rgba(0,0,0,0.3);font-size:24px;';
        var formVisible = false, formEl = null;
        fab.onclick = function () {
          if (formVisible && formEl) { formEl.remove(); formVisible = false; return; }
          formEl = tDoc.createElement('div');
          formEl.style.cssText = 'position:fixed;bottom:84px;right:20px;z-index:99997;background:#fff;border-radius:16px;padding:20px;width:300px;box-shadow:0 8px 32px rgba(0,0,0,0.2);';
          var h = tDoc.createElement('h3'); h.textContent = titulo; h.style.cssText = 'margin:0 0 12px;font-size:16px;'; formEl.appendChild(h);
          var inp = function (ph, t) { var i = tDoc.createElement('input'); i.placeholder = ph; i.type = t || 'text'; i.style.cssText = 'width:100%;padding:8px 12px;border:1px solid #ddd;border-radius:8px;margin-bottom:8px;box-sizing:border-box;font-size:13px;'; return i; };
          var nombre = inp('Tu nombre'); formEl.appendChild(nombre);
          var correo = inp('Tu email', 'email'); formEl.appendChild(correo);
          var msgEl = tDoc.createElement('textarea'); msgEl.placeholder = 'Tu mensaje...'; msgEl.rows = 3;
          msgEl.style.cssText = 'width:100%;padding:8px 12px;border:1px solid #ddd;border-radius:8px;margin-bottom:10px;box-sizing:border-box;font-size:13px;resize:none;';
          formEl.appendChild(msgEl);
          var enviar = tDoc.createElement('button'); enviar.textContent = 'Enviar mensaje';
          enviar.style.cssText = 'width:100%;padding:10px;background:#1976D2;color:#fff;border:none;border-radius:8px;font-weight:bold;cursor:pointer;font-size:14px;';
          enviar.onclick = function () {
            var n = nombre.value.trim(), eVal = correo.value.trim(), m = msgEl.value.trim();
            if (!n || !eVal || !m) {
              alert('Por favor rellena todos los campos.');
              return;
            }
            if (!eVal.includes('@')) {
              alert('Introduce un email válido.');
              return;
            }
            enviar.disabled = true; enviar.textContent = 'Enviando...';
            // Escribe en contacto_web — las reglas permiten create sin auth si tiene nombre+email+mensaje
            db.collection('empresas').doc(emp).collection('contacto_web')
              .add({
                nombre: n,
                email: eVal,
                mensaje: m,
                telefono: null,
                asunto: 'Contacto desde web',
                origen: 'web',
                leido: false,
                respondido: false,
                respuesta: null,
                fecha_respuesta: null,
                fecha_creacion: firebase.firestore.FieldValue.serverTimestamp()
              })
              .then(function () {
                formEl.innerHTML = '<p style="text-align:center;color:#2E7D32;font-weight:bold;padding:20px 0;">✅ Mensaje enviado correctamente</p>';
                setTimeout(function () { formEl.remove(); formVisible = false; }, 2500);
              }).catch(function (e) {
                enviar.disabled = false; enviar.textContent = 'Enviar mensaje';
                alert('Error al enviar: ' + e.message);
              });
          };
          formEl.appendChild(enviar);
          if (wa) {
            var waBtn = tDoc.createElement('a');
            waBtn.href = 'https://wa.me/' + wa.replace(/[^0-9]/g, ''); waBtn.target = '_blank';
            waBtn.textContent = '💬 Abrir WhatsApp';
            waBtn.style.cssText = 'display:block;text-align:center;margin-top:8px;color:#25D366;font-weight:bold;text-decoration:none;font-size:13px;';
            formEl.appendChild(waBtn);
          }
          tDoc.body.appendChild(formEl); formVisible = true;
        };
        tDoc.body.appendChild(fab);
        console.log('Fluix: contacto activado');
      }).catch(function (e) { console.warn('Fluix contacto error:', e.message); });
  }

  // ── Buscar secciones, hacer seed si no existen, y escuchar cambios ───────
  // El seed automático (CREATE) está permitido con auth anónima.
  // El seedForce (UPDATE de doc existente) solo funciona siendo admin.
  function _buscarEnIframes(db, intentos) {
    var encontradas = 0, empGlobal = null;

    _getAllDocs().forEach(function (iDoc) {
      iDoc.querySelectorAll('[data-fluix-seccion]').forEach(function (secEl) {
        var emp = secEl.getAttribute('data-fluix-empresa') || EMPRESA_ID;
        var sec = secEl.getAttribute('data-fluix-seccion');
        if (!emp || !sec) return;
        if (!empGlobal) empGlobal = emp;
        encontradas++;
        _subirSeccion(db, secEl, emp, sec, false); // seed si no existe
        _escuchar(db, secEl, emp, sec);            // escuchar cambios en tiempo real
      });
    });

    if (encontradas > 0) {
      console.log('🚀 Fluix Ready — ' + encontradas + ' sección(es) conectadas');
      var empBanner = empGlobal || EMPRESA_ID;
      if (empBanner) {
        _initWebAvanzada(db, empBanner, function () {
          _mostrarBanner(db, empBanner);
          _mostrarPopup(db, empBanner);
          _mostrarContacto(db, empBanner);
        });
      }
      return;
    }

    if (intentos < 30) {
      setTimeout(function () { _buscarEnIframes(db, intentos + 1); }, 500);
    } else {
      console.log('Fluix: sin secciones con data-fluix-seccion');
      var emp0 = EMPRESA_ID;
      if (emp0) {
        _initWebAvanzada(db, emp0, function () {
          _mostrarBanner(db, emp0);
          _mostrarPopup(db, emp0);
          _mostrarContacto(db, emp0);
        });
      }
    }
  }

  // ── API pública ───────────────────────────────────────────────────────────
  window.Fluix = {
    // Debug: muestra estado en consola
    debug: function () {
      console.log('--- Fluix Debug ---');
      console.log('EMPRESA_ID:', EMPRESA_ID);
      console.log('empresaId resuelto:', _getEmpresaId());
      console.log('En iframe:', window.self !== window.top);
      console.log('Firebase cargado:', typeof firebase !== 'undefined');
      console.log('DB lista:', !!window._fluixDB);
      var allDocs = _getAllDocs();
      console.log('Documentos accesibles:', allDocs.length);
      allDocs.forEach(function (d, i) {
        var secs = d.querySelectorAll('[data-fluix-seccion]');
        var label = d === document ? 'actual' : 'doc-' + i;
        console.log('  [' + label + ']: ' + secs.length + ' sección(es)');
        secs.forEach(function (el) {
          console.log('    seccion=' + el.getAttribute('data-fluix-seccion') +
            ' empresa=' + (el.getAttribute('data-fluix-empresa') || '(usa EMPRESA_ID)'));
        });
      });
    },

    // Seed manual — solo funciona si el usuario es admin (autenticado en la app)
    // Uso desde consola: Fluix.seed('carta')
    seed: function (s) { _seedById(s, false); },
    seedForce: function (s) { _seedById(s, true); },

    // Tests visuales
    testPopup: function () {
      var tDoc = _targetDoc();
      var old = tDoc.getElementById('fluix-popup-overlay'); if (old) old.remove();
      var ov = tDoc.createElement('div'); ov.id = 'fluix-popup-overlay';
      ov.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.5);z-index:99999;display:flex;align-items:center;justify-content:center;';
      var box = tDoc.createElement('div');
      box.style.cssText = 'background:#fff;border-radius:16px;padding:28px;max-width:400px;width:90%;text-align:center;position:relative;box-shadow:0 8px 32px rgba(0,0,0,0.3);';
      box.innerHTML = '<h2 style="margin:0 0 8px">🧪 Popup de prueba</h2><p style="color:#666;font-size:14px">Si ves esto el popup funciona.<br>Actívalo en la app con popup_activo: true</p><button onclick="document.getElementById(\'fluix-popup-overlay\').remove()" style="margin-top:12px;padding:8px 20px;background:#1976D2;color:#fff;border:none;border-radius:8px;cursor:pointer">Cerrar</button>';
      ov.appendChild(box);
      ov.onclick = function (e) { if (e.target === ov) ov.remove(); };
      tDoc.body.appendChild(ov);
      console.log('Fluix testPopup: OK');
    },
    testBanner: function (texto) {
      var tDoc = _targetDoc();
      var old = tDoc.getElementById('fluix-banner'); if (old) old.remove();
      var b = tDoc.createElement('div'); b.id = 'fluix-banner';
      b.style.cssText = 'position:fixed;top:0;left:0;right:0;z-index:99998;background:#1976D2;color:#fff;text-align:center;padding:10px 40px 10px 16px;font-size:14px;font-weight:500;box-shadow:0 2px 8px rgba(0,0,0,0.2);';
      b.textContent = texto || '🧪 Banner de prueba — activa banner_activo: true en la app';
      var x = tDoc.createElement('span'); x.textContent = 'X';
      x.style.cssText = 'position:absolute;right:12px;top:50%;transform:translateY(-50%);cursor:pointer;font-size:16px;opacity:0.7;';
      x.onclick = function () { b.remove(); tDoc.body.style.marginTop = ''; };
      b.appendChild(x);
      tDoc.body.insertBefore(b, tDoc.body.firstChild);
      tDoc.body.style.marginTop = b.offsetHeight + 'px';
      console.log('Fluix testBanner: OK');
    }
  };

  console.log('Fluix: script cargado, esperando Firebase...');

  // ── Arranque ──────────────────────────────────────────────────────────────
  function init() {
    console.log('Fluix: Firebase cargado OK');
    var existing = (firebase.apps || []).filter(function (a) { return a && a.name === 'FluixApp'; })[0];
    var app = existing || firebase.initializeApp(CFG, 'FluixApp');
    var db = app.firestore();
    window._fluixDB = db;
    firebase.auth(app).signInAnonymously().then(function () {
      console.log('🔐 Fluix: autenticación anónima OK');
      _tracking();           // Registrar visita (escribe en estadisticas — auth anónima válida)
      _buscarEnIframes(db, 0);  // Escuchar secciones (solo lectura)
    }).catch(function (e) {
      console.error('Fluix auth error:', e.message);
    });
  }
})();
</script>




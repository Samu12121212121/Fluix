(function () {
  'use strict';

  // ─────────────────────────────────────────────────────────────────────────────
  //  FLUIX CRM — SCRIPT UNIVERSAL v2.0
  //  Uso: <script src="fluix_script_universal.js" data-empresa="EMPRESA_ID"></script>
  // ─────────────────────────────────────────────────────────────────────────────

  // ── 1. LEER EMPRESA ID desde el atributo data-empresa ────────────────────────
  var _tag = document.currentScript || (function () {
    var s = document.getElementsByTagName('script');
    return s[s.length - 1];
  })();

  var EMPRESA_ID = (_tag && _tag.getAttribute('data-empresa')) || '';

  if (!EMPRESA_ID) {
    console.error('❌ Fluix: Falta data-empresa.\n   Correcto: <script src="fluix_script_universal.js" data-empresa="TU_ID">');
    return;
  }

  // ── 2. FIREBASE CONFIG ────────────────────────────────────────────────────────
  var FIREBASE_CONFIG = {
    apiKey:            'AIzaSyCvOaB1hF_sF-A6jMZ0MusttuhzSMDezb4',
    authDomain:        'planeaapp-4bea4.firebaseapp.com',
    projectId:         'planeaapp-4bea4',
    storageBucket:     'planeaapp-4bea4.firebasestorage.app',
    messagingSenderId: '1085482191658',
    appId:             '1:1085482191658:web:c5461353b123ab92d62c53'
  };

  // ── 3. API PÚBLICA window.Fluix ───────────────────────────────────────────────
  window.Fluix = {

    /**
     * PRIMERA SINCRONIZACIÓN:
     * Escanea todos los [data-fluix] del HTML y sube la estructura a Firebase.
     * Solo es necesario ejecutarlo UNA VEZ por empresa para crear las secciones.
     * Después el empresario las edita desde la app.
     */
    sincronizar: function () {
      if (!window._fluixDB) { console.error('Fluix: Firebase aún no iniciado. Espera 2s.'); return; }
      _escanearYSubir();
    },

    /**
     * Debug: muestra el estado de la conexión y todos los campos detectados.
     * Ejecutar en consola del navegador para verificar que todo está bien.
     */
    debug: function () {
      console.log('══════════════ FLUIX DEBUG ══════════════');
      console.log('Empresa ID :', EMPRESA_ID);
      console.log('Firebase   :', window._fluixDB ? '✅ conectado' : '❌ no iniciado');
      var campos = document.querySelectorAll('[data-fluix]');
      console.log('Campos     :', campos.length + ' elementos marcados con data-fluix');
      var secciones = _parsearCampos();
      Object.keys(secciones).forEach(function (sec) {
        console.log('  📁 ' + sec + ' → ' + Object.keys(secciones[sec]).length + ' items');
      });
      console.log('Reservas   :', document.getElementById('fluixcrm_reservas')  ? '✅' : '⚠️ div no encontrado');
      console.log('Contacto   :', document.getElementById('fluixcrm_contacto')  ? '✅' : '⚠️ div no encontrado');
      console.log('Blog       :', document.getElementById('fluixcrm_blog')       ? '✅' : '⚠️ div no encontrado');
      console.log('═════════════════════════════════════════');
    },

    /**
     * Escanear: muestra qué campos detecta en el HTML sin subir nada a Firebase.
     * Útil para verificar que los data-fluix están bien puestos antes de sincronizar.
     */
    escanear: function () {
      var secciones = _parsearCampos();
      if (Object.keys(secciones).length === 0) {
        console.warn('Fluix.escanear(): No se encontraron elementos con data-fluix.');
        return;
      }
      console.log('══════ CAMPOS DETECTADOS EN EL HTML ══════');
      Object.keys(secciones).forEach(function (sec) {
        console.log('📁 ' + sec + ' (tipo: ' + _inferirTipo(sec) + ')');
        Object.keys(secciones[sec]).forEach(function (item) {
          console.log('   └─ ' + item + ':', secciones[sec][item]);
        });
      });
      console.log('Total: ' + Object.keys(secciones).length + ' secciones');
      console.log('Listo para sincronizar → Fluix.sincronizar()');
    }
  };

  // ── 4. PARSEAR CAMPOS [data-fluix] ────────────────────────────────────────────
  // Formato del atributo: data-fluix="seccionId/itemId/campo"
  // Ejemplo:              data-fluix="carta/paella_mixta/precio"
  function _parsearCampos() {
    var secciones = {};
    document.querySelectorAll('[data-fluix]').forEach(function (el) {
      var partes = (el.getAttribute('data-fluix') || '').split('/');
      if (partes.length < 3) return;
      var seccionId = partes[0].trim();
      var itemId    = partes[1].trim();
      var campo     = partes[2].trim();

      if (!secciones[seccionId]) secciones[seccionId] = {};
      if (!secciones[seccionId][itemId]) secciones[seccionId][itemId] = { id: itemId, disponible: true };

      if (campo === 'imagen' || campo === 'imagen_url') {
        var src = (el.tagName === 'IMG') ? el.src : (el.querySelector('img') ? el.querySelector('img').src : '');
        secciones[seccionId][itemId].imagen     = src;
        secciones[seccionId][itemId].imagen_url = src;
      } else if (campo === 'precio' || campo === 'precio_oferta') {
        secciones[seccionId][itemId].precio = parseFloat(
          String(el.innerText || '0').replace('€', '').replace(',', '.').trim()
        ) || 0;
      } else {
        secciones[seccionId][itemId][campo] = (el.innerText || '').trim();
      }
    });
    return secciones;
  }

  // ── 5. INFERIR TIPO DE SECCIÓN POR NOMBRE ─────────────────────────────────────
  function _inferirTipo(nombre) {
    var n = nombre.toLowerCase();
    if (/carta|menu|menú|plato|producto|bebida|vino/.test(n)) return 'carta';
    if (/horario|hora|apertura|cierre|horari/.test(n))        return 'horarios';
    if (/oferta|promo|descuento|especial/.test(n))            return 'ofertas';
    if (/galeria|galería|foto|imagen|foto/.test(n))           return 'galeria';
    return 'texto';
  }

  // ── 6. SUBIR ESTRUCTURA A FIREBASE (primera vez) ─────────────────────────────
  function _escanearYSubir() {
    var secciones = _parsearCampos();
    var nombres   = Object.keys(secciones);

    if (nombres.length === 0) {
      console.warn('Fluix.sincronizar(): No hay elementos con data-fluix en el HTML.');
      console.info('Añade data-fluix="seccion/item/campo" a los elementos editables.');
      return;
    }

    console.log('Subiendo ' + nombres.length + ' secciones a Firebase...');

    var promesas = nombres.map(function (seccionId, idx) {
      var items = Object.values(secciones[seccionId]);
      var tipo  = _inferirTipo(seccionId);
      var nombreLegible = seccionId.charAt(0).toUpperCase() + seccionId.slice(1).replace(/_/g, ' ');

      // Construir el documento compatible con SeccionWeb de la app Flutter
      var doc = {
        tipo:        tipo,
        nombre:      nombreLegible,
        descripcion: 'Sección ' + nombreLegible,
        activa:      true,
        orden:       idx,
        fecha_creacion:      new Date(),
        fecha_actualizacion: new Date(),
        contenido:   {}
      };

      if (tipo === 'carta') {
        doc.contenido = { titulo: nombreLegible, items_carta: items };

      } else if (tipo === 'horarios') {
        var horarios = items.map(function (it) {
          return { dia: it.nombre || it.dia || it.id, apertura: it.apertura || '', cierre: it.cierre || '', cerrado: false };
        });
        doc.contenido = { titulo: nombreLegible, horarios: horarios };

      } else if (tipo === 'texto') {
        var primer = items[0] || {};
        doc.contenido = {
          titulo:     primer.titulo || primer.nombre || nombreLegible,
          texto:      primer.texto  || primer.descripcion || '',
          imagen_url: primer.imagen_url || ''
        };

      } else if (tipo === 'ofertas') {
        var ofertas = items.map(function (it) {
          return { titulo: it.nombre || it.titulo || '', descripcion: it.descripcion || '', precio_oferta: it.precio || 0, imagen_url: it.imagen_url || '', activa: true };
        });
        doc.contenido = { titulo: nombreLegible, ofertas: ofertas };
      }

      return window._fluixDB
        .collection('empresas').doc(EMPRESA_ID)
        .collection('contenido_web').doc(seccionId)
        .set(doc, { merge: false })
        .then(function () { console.log('  ✅ ' + seccionId + ' (' + tipo + ', ' + items.length + ' items)'); });
    });

    Promise.all(promesas)
      .then(function ()  { console.log('🚀 Sincronización completa. El empresario ya puede editar desde la app.'); })
      .catch(function (e) { console.error('❌ Error en sincronización:', e.message); });
  }

  // ── 7. ESCUCHAR FIREBASE Y ACTUALIZAR DOM ─────────────────────────────────────
  function _escucharFirebase(db) {
    db.collection('empresas').doc(EMPRESA_ID)
      .collection('contenido_web')
      .onSnapshot(function (snap) {

        // Secciones eliminadas → ocultar
        snap.docChanges().forEach(function (ch) {
          if (ch.type !== 'removed') return;
          _ocultarSeccion(ch.doc.id);
          _renderDinamico(ch.doc.id, null, null, null, false);
        });

        snap.forEach(function (doc) {
          var d         = doc.data();
          var tipo      = d.tipo || 'texto';
          var c         = d.contenido || {};
          var seccionId = doc.id;

          // Sección desactivada → ocultar
          if (!d.activa) {
            _ocultarSeccion(seccionId);
            _renderDinamico(seccionId, d, tipo, c, false);
            return;
          }

          // Actualizar elementos marcados con data-fluix
          _actualizarElementos(seccionId, tipo, c);

          // Actualizar divs fluixcrm_XXX (si existen)
          _renderDinamico(seccionId, d, tipo, c, true);
        });

      }, function (err) {
        console.error('Fluix onSnapshot error:', err.message);
      });
  }

  function _ocultarSeccion(seccionId) {
    document.querySelectorAll('[data-fluix^="' + seccionId + '/"]').forEach(function (el) {
      var bloque = el.closest('[data-block-id]') || el.closest('section') || el.parentElement;
      if (bloque) bloque.style.display = 'none';
    });
  }

  function _actualizarElementos(seccionId, tipo, c) {
    // Construir índice por itemId para acceso O(1)
    var idx = {};

    if (tipo === 'carta') {
      (c.items_carta || []).forEach(function (it) { if (it.id) idx[it.id] = it; });
    } else if (tipo === 'horarios') {
      (c.horarios || []).forEach(function (h) {
        var key = (h.dia || '').toLowerCase().replace(/\s+/g, '_');
        idx[key] = h;
      });
    } else if (tipo === 'ofertas') {
      (c.ofertas || []).forEach(function (o) {
        var key = (o.titulo || '').toLowerCase().replace(/\s+/g, '_');
        idx[key] = o;
      });
    } else if (tipo === 'texto') {
      idx['_root'] = c; // texto tiene un solo "item"
    }

    document.querySelectorAll('[data-fluix^="' + seccionId + '/"]').forEach(function (el) {
      var partes    = el.getAttribute('data-fluix').split('/');
      var itemId    = partes[1];
      var campo     = partes[2];
      var it        = tipo === 'texto' ? idx['_root'] : idx[itemId];
      if (!it) return;

      // Mostrar/ocultar bloque según disponible/activa
      var disponible = (it.disponible !== false) && (it.activa !== false);
      var bloque     = el.closest('.layout-element') || el.closest('[id^="ai-"]') || el.parentElement;
      if (bloque) bloque.style.display = disponible ? '' : 'none';
      if (!disponible) return;

      // Actualizar contenido
      if (campo === 'precio' || campo === 'precio_oferta') {
        el.innerText = _fmtPrecio(it[campo] !== undefined ? it[campo] : it.precio);

      } else if (campo === 'imagen' || campo === 'imagen_url') {
        var url   = it.imagen_url || it.imagen;
        var imgEl = (el.tagName === 'IMG') ? el : el.querySelector('img');
        if (imgEl && url) { imgEl.src = url; imgEl.srcset = ''; }

      } else if (campo === 'apertura' || campo === 'cierre') {
        // Horarios: si está cerrado mostrar "Cerrado"
        el.innerText = it.cerrado ? 'Cerrado' : (it[campo] || '');

      } else if (it[campo] !== undefined) {
        el.innerText = it[campo];
      }
    });
  }

  // ── 8. RENDER EN DIVS fluixcrm_XXX (webs sin data-fluix) ─────────────────────
  function _renderDinamico(id, d, tipo, c, show) {
    var el = document.getElementById('fluixcrm_' + id);
    if (!el) return;

    if (show === false || !d || !d.activa) {
      el.innerHTML = '';
      el.style.display = 'none';
      return;
    }

    var html = '';
    if (tipo === 'texto') {
      html = (c.titulo ? '<h3 style="margin:0 0 12px">' + c.titulo + '</h3>' : '')
           + (c.texto  ? '<p style="margin:0 0 12px;line-height:1.6">' + c.texto + '</p>' : '')
           + (c.imagen_url ? '<img src="' + c.imagen_url + '" style="max-width:100%;border-radius:8px">' : '');

    } else if (tipo === 'carta') {
      html = (c.items_carta || []).filter(function (p) { return p.disponible !== false; }).map(function (p) {
        return '<div style="border-bottom:1px solid #eee;padding:12px 0;display:flex;gap:14px;align-items:start">'
          + (p.imagen_url ? '<img src="' + p.imagen_url + '" style="width:72px;height:72px;object-fit:cover;border-radius:8px;flex-shrink:0">' : '')
          + '<div style="flex:1;min-width:0">'
          + '<div style="display:flex;justify-content:space-between;align-items:baseline;gap:8px">'
          + '<strong style="font-size:15px">' + (p.nombre || '') + '</strong>'
          + '<b style="color:#e65100;white-space:nowrap;flex-shrink:0">' + _fmtPrecio(p.precio) + '</b></div>'
          + (p.descripcion ? '<p style="margin:4px 0 0;color:#666;font-size:13px;line-height:1.4">' + p.descripcion + '</p>' : '')
          + '</div></div>';
      }).join('');

    } else if (tipo === 'horarios') {
      html = '<table style="width:100%;border-collapse:collapse">'
        + (c.horarios || []).map(function (h) {
          return '<tr style="border-bottom:1px solid #f5f5f5">'
            + '<td style="padding:8px 12px;font-weight:600">' + h.dia + '</td>'
            + '<td style="padding:8px 12px;color:' + (h.cerrado ? '#e53935' : '#2e7d32') + '">'
            + (h.cerrado ? 'Cerrado' : (h.apertura || '') + ' – ' + (h.cierre || '')) + '</td></tr>';
        }).join('') + '</table>';

    } else if (tipo === 'galeria') {
      html = '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px">'
        + (c.imagenes_galeria || []).map(function (i) {
          return '<img src="' + i.url + '" style="width:100%;aspect-ratio:1;object-fit:cover;border-radius:8px" loading="lazy">';
        }).join('') + '</div>';

    } else if (tipo === 'ofertas') {
      html = (c.ofertas || []).filter(function (o) { return o.activa; }).map(function (o) {
        return '<div style="border:1px solid #eee;border-radius:8px;padding:14px;margin-bottom:14px">'
          + (o.imagen_url ? '<img src="' + o.imagen_url + '" style="width:100%;border-radius:6px;margin-bottom:10px;height:180px;object-fit:cover">' : '')
          + '<h4 style="margin:0 0 6px">' + (o.titulo || '') + '</h4>'
          + '<p style="color:#666;font-size:13px;margin:0 0 10px">' + (o.descripcion || '') + '</p>'
          + '<div style="display:flex;align-items:baseline;gap:10px">'
          + (o.precio_original ? '<s style="color:#999;font-size:14px">' + _fmtPrecio(o.precio_original) + '</s>' : '')
          + (o.precio_oferta   ? '<strong style="color:#e53935;font-size:18px">' + _fmtPrecio(o.precio_oferta) + '</strong>' : '')
          + '</div></div>';
      }).join('');
    }

    el.innerHTML = html;
    el.style.display = '';
  }

  // ── 9. MÓDULOS FIJOS: RESERVAS ────────────────────────────────────────────────
  function _initReservas(db) {
    _conRetry('Reservas', function () { return document.getElementById('fluixcrm_reservas'); }, function (el) {
      el.innerHTML =
        '<div style="max-width:500px;margin:0 auto;font-family:sans-serif">' +
        '<form id="fluix-form-reserva" style="display:flex;flex-direction:column;gap:14px">' +
        '<div><label style="display:block;margin-bottom:5px;font-size:13px;font-weight:600;color:#555">Nombre completo</label>' +
        '<input name="nombre" placeholder="Tu nombre" required style="width:100%;box-sizing:border-box;padding:12px;border:1px solid #ddd;border-radius:8px;font-size:14px"></div>' +
        '<div><label style="display:block;margin-bottom:5px;font-size:13px;font-weight:600;color:#555">Teléfono</label>' +
        '<input name="telefono" type="tel" placeholder="Tu teléfono" required style="width:100%;box-sizing:border-box;padding:12px;border:1px solid #ddd;border-radius:8px;font-size:14px"></div>' +
        '<div style="display:flex;gap:12px">' +
        '<div style="flex:1"><label style="display:block;margin-bottom:5px;font-size:13px;font-weight:600;color:#555">Fecha</label>' +
        '<input name="fecha" type="date" required style="width:100%;box-sizing:border-box;padding:12px;border:1px solid #ddd;border-radius:8px"></div>' +
        '<div style="flex:1"><label style="display:block;margin-bottom:5px;font-size:13px;font-weight:600;color:#555">Hora</label>' +
        '<input name="hora" type="time" required style="width:100%;box-sizing:border-box;padding:12px;border:1px solid #ddd;border-radius:8px"></div></div>' +
        '<div><label style="display:block;margin-bottom:5px;font-size:13px;font-weight:600;color:#555">Personas</label>' +
        '<input name="personas" type="number" min="1" value="2" style="width:100%;box-sizing:border-box;padding:12px;border:1px solid #ddd;border-radius:8px"></div>' +
        '<button type="submit" style="background:#1976D2;color:#fff;padding:14px;border:none;border-radius:8px;cursor:pointer;font-weight:bold;font-size:15px">Solicitar Reserva</button>' +
        '</form>' +
        '<div id="fluix-reserva-ok" style="display:none;text-align:center;padding:20px;background:#e8f5e9;border-radius:8px;color:#2e7d32;margin-top:12px"></div>' +
        '</div>';

      document.getElementById('fluix-form-reserva').addEventListener('submit', function (e) {
        e.preventDefault();
        var fd  = new FormData(e.target);
        var btn = e.target.querySelector('button');
        btn.disabled = true;
        btn.innerText = 'Enviando...';

        var fechaDate = new Date(fd.get('fecha') + 'T' + fd.get('hora') + ':00');
        db.collection('empresas').doc(EMPRESA_ID).collection('reservas').add({
          nombre_cliente:   fd.get('nombre'),
          telefono_cliente: fd.get('telefono'),
          personas:         parseInt(fd.get('personas')) || 1,
          fecha:            firebase.firestore.Timestamp.fromDate(fechaDate),
          fecha_hora:       fechaDate.toISOString(),
          estado:           'PENDIENTE',
          origen:           'web',
          fecha_creacion:   firebase.firestore.FieldValue.serverTimestamp()
        }).then(function () {
          e.target.style.display = 'none';
          var ok = document.getElementById('fluix-reserva-ok');
          ok.style.display = 'block';
          ok.innerHTML = '<h3 style="margin:0 0 8px">✅ ¡Solicitud enviada!</h3><p style="margin:0">Te confirmaremos la reserva pronto.</p>';
        }).catch(function (err) {
          btn.disabled  = false;
          btn.innerText = 'Solicitar Reserva';
          alert('Error al enviar: ' + err.message);
        });
      });
    });
  }

  // ── 10. MÓDULOS FIJOS: CONTACTO ───────────────────────────────────────────────
  function _initContacto(db) {
    _conRetry('Contacto', function () { return document.getElementById('fluixcrm_contacto'); }, function (el) {
      el.innerHTML =
        '<div style="max-width:480px;font-family:sans-serif">' +
        '<form id="fluix-form-contacto" style="display:flex;flex-direction:column;gap:12px">' +
        '<input name="nombre" placeholder="Tu nombre" required style="padding:11px;border:1px solid #ddd;border-radius:8px;font-size:14px">' +
        '<input name="email" type="email" placeholder="Tu email" required style="padding:11px;border:1px solid #ddd;border-radius:8px;font-size:14px">' +
        '<textarea name="mensaje" placeholder="Tu mensaje" rows="4" required style="padding:11px;border:1px solid #ddd;border-radius:8px;resize:vertical;font-size:14px"></textarea>' +
        '<button type="submit" style="background:#1976D2;color:#fff;padding:12px;border:none;border-radius:8px;cursor:pointer;font-weight:bold">Enviar mensaje</button>' +
        '</form></div>';

      document.getElementById('fluix-form-contacto').addEventListener('submit', function (e) {
        e.preventDefault();
        var fd = new FormData(e.target);
        db.collection('empresas').doc(EMPRESA_ID).collection('contacto_web').add({
          nombre:  fd.get('nombre'),
          email:   fd.get('email'),
          mensaje: fd.get('mensaje'),
          fecha:   firebase.firestore.FieldValue.serverTimestamp(),
          leido:   false
        }).then(function () {
          e.target.innerHTML = '<p style="color:#2e7d32;font-weight:bold">✅ Mensaje enviado. Te responderemos pronto.</p>';
        }).catch(function (err) { alert('Error: ' + err.message); });
      });
    });
  }

  // ── 11. MÓDULOS FIJOS: BLOG ───────────────────────────────────────────────────
  function _initBlog(db) {
    _conRetry('Blog', function () { return document.getElementById('fluixcrm_blog'); }, function (el) {
      db.collection('empresas').doc(EMPRESA_ID).collection('blog')
        .where('publicada', '==', true)
        .orderBy('fecha_publicacion', 'desc')
        .limit(6)
        .onSnapshot(function (snap) {
          if (snap.empty) { el.innerHTML = '<p>No hay noticias por el momento.</p>'; return; }
          el.innerHTML = '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:18px">'
            + snap.docs.map(function (d) {
              var b = d.data();
              var f = b.fecha_publicacion && b.fecha_publicacion.toDate
                ? b.fecha_publicacion.toDate().toLocaleDateString('es-ES') : '';
              return '<article style="border:1px solid #eee;border-radius:10px;overflow:hidden">'
                + (b.imagen_url ? '<img src="' + b.imagen_url + '" style="width:100%;height:160px;object-fit:cover">'
                                : '<div style="height:6px;background:#1976D2"></div>')
                + '<div style="padding:14px">'
                + '<h4 style="margin:0 0 8px">' + (b.titulo || '') + '</h4>'
                + '<p style="color:#666;font-size:13px;margin:0 0 10px">' + (b.resumen || '') + '</p>'
                + '<small style="color:#999">' + f + '</small>'
                + '</div></article>';
            }).join('') + '</div>';
        });
    });
  }

  // ── 12. ANALYTICS ────────────────────────────────────────────────────────────
  function _registrarVisita(db) {
    try {
      var hoy    = new Date().toISOString().substring(0, 10);
      var pagina = window.location.pathname || '/';
      db.collection('empresas').doc(EMPRESA_ID).collection('estadisticas').doc('web_resumen')
        .set({
          visitas_totales:  firebase.firestore.FieldValue.increment(1),
          ultima_visita:    firebase.firestore.FieldValue.serverTimestamp(),
          pagina_actual:    pagina
        }, { merge: true });
      db.collection('empresas').doc(EMPRESA_ID).collection('estadisticas').doc('visitas_' + hoy)
        .set({
          fecha:   hoy,
          visitas: firebase.firestore.FieldValue.increment(1),
          timestamp: firebase.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
    } catch (e) { /* silencioso */ }
  }

  // ── UTILIDADES ───────────────────────────────────────────────────────────────
  function _fmtPrecio(v) {
    var n = parseFloat(String(v || 0).replace('€', '').replace(',', '.').trim());
    return isNaN(n) ? String(v) : (Number.isInteger(n) ? n + '€' : n.toFixed(2) + '€');
  }

  function _conRetry(nombre, buscar, cb) {
    var intentos = 0;
    (function intentar() {
      var el = buscar();
      if (el) { cb(el); return; }
      if (++intentos < 30) setTimeout(intentar, 500);
      else console.warn('Fluix ' + nombre + ': elemento no encontrado tras 15s.');
    })();
  }

  function _cargarScript(src, cb) {
    var s = document.createElement('script');
    s.src     = src;
    s.onload  = cb || function () {};
    s.onerror = function () { console.error('Fluix: error cargando ' + src); };
    document.head.appendChild(s);
  }

  // ── INICIO ───────────────────────────────────────────────────────────────────
  function _start() {
    var existing = (firebase.apps || []).filter(function (a) { return a && a.name === 'FluixApp'; })[0];
    var app      = existing || firebase.initializeApp(FIREBASE_CONFIG, 'FluixApp');
    var db       = app.firestore();
    window._fluixDB = db;

    _escucharFirebase(db);
    _initReservas(db);
    _initContacto(db);
    _initBlog(db);
    _registrarVisita(db);

    console.log('Fluix Ready 🚀 | Empresa: ' + EMPRESA_ID);
  }

  if (typeof firebase === 'undefined') {
    _cargarScript('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js', function () {
      _cargarScript('https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore-compat.js', _start);
    });
  } else {
    _start();
  }

})();


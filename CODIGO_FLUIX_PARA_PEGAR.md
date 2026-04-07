# 📋 Código completo para pegar en cualquier web

> Copia este script, rellena los valores marcados con `← CAMBIAR`, y pégalo en el Custom Code de tu web.

---

## ✅ Script completo (listo para copiar)

```html
<script>
(function () {

    /* ══════════════════════════════════════════════════════════════
       ① CONFIGURACIÓN — CAMBIA ESTOS VALORES PARA CADA SECCIÓN
    ══════════════════════════════════════════════════════════════ */
    var CFG = {
        empresaId:  'TU_EMPRESA_ID_AQUI',   // ← CAMBIAR (ID de la empresa en Firestore)
        seccionId:  'carta',                 // ← CAMBIAR (nombre único de esta sección, ej: 'carta', 'ofertas', 'equipo')
        tipo:       'carta',                 // ← CAMBIAR (tipo: 'carta', 'ofertas', 'texto', 'horarios')
        blockId:    'ID_DEL_BLOQUE_HTML',    // ← CAMBIAR (id="" del contenedor principal en el HTML)
        firebaseConfig: {
            apiKey:            "AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU",
            authDomain:        "planeaapp-4bea4.firebaseapp.com",
            projectId:         "planeaapp-4bea4",
            storageBucket:     "planeaapp-4bea4.firebasestorage.app",
            messagingSenderId: "1085482191658",
            appId:             "1:1085482191658:web:c5461353b123ab92d62c53"
        }
    };

    /* ══════════════════════════════════════════════════════════════
       ② MAPA DE ELEMENTOS — UN OBJETO POR CADA CAMPO A CONTROLAR
       
       hostingerId → el id="" del elemento en el HTML de la web
       item        → nombre del item (sin espacios, sin acentos)
       campo       → 'nombre', 'precio', 'descripcion', 'titulo', etc.
    ══════════════════════════════════════════════════════════════ */
    var MAPA = [
        { hostingerId: 'ai-XXXXX1', item: 'plato_1', campo: 'nombre'      },
        { hostingerId: 'ai-XXXXX2', item: 'plato_1', campo: 'descripcion' },
        { hostingerId: 'ai-XXXXX3', item: 'plato_1', campo: 'precio'      },
        { hostingerId: 'ai-XXXXX4', item: 'plato_2', campo: 'nombre'      },
        { hostingerId: 'ai-XXXXX5', item: 'plato_2', campo: 'descripcion' },
        { hostingerId: 'ai-XXXXX6', item: 'plato_2', campo: 'precio'      },
        // ← Agrega más filas para cada elemento que quieras controlar
    ];

    /* ══════════════════════════════════════════════════════════════
       NO TOQUES NADA DE AQUÍ PARA ABAJO
    ══════════════════════════════════════════════════════════════ */

    function cargarScript(src, cb) {
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

    function marcarDOM() {
        var section = document.getElementById(CFG.blockId);
        if (!section) {
            console.error('Fluix: No encontrada section #' + CFG.blockId + '. Revisa el blockId en CFG.');
            return null;
        }
        section.classList.add('fluix-widget');
        section.setAttribute('data-empresa', CFG.empresaId);
        section.setAttribute('data-seccion', CFG.seccionId);

        var ok = 0;
        MAPA.forEach(function (e) {
            var wrapper = document.getElementById(e.hostingerId);
            if (!wrapper) { console.warn('Fluix: no encontrado #' + e.hostingerId); return; }
            var textEl = wrapper.querySelector('strong, p, h6, h5, h4, h3, h2, h1') || wrapper;
            textEl.setAttribute('data-fluix-item',  e.item);
            textEl.setAttribute('data-fluix-campo', e.campo);
            ok++;
        });
        console.log('Fluix DOM: ' + ok + '/' + MAPA.length + ' campos marcados');
        return section;
    }

    function conectar(section) {
        var appName = 'FluixInline_' + CFG.seccionId;
        var existing = (firebase.apps || []).find(function (a) { return a.name === appName; });
        var app = existing || firebase.initializeApp(CFG.firebaseConfig, appName);
        var db  = app.firestore();
        console.log('Fluix: conectado. Escuchando sección "' + CFG.seccionId + '"...');

        db.collection('empresas').doc(CFG.empresaId)
          .collection('contenido_web').doc(CFG.seccionId)
          .onSnapshot(function (doc) {
              if (!doc.exists) {
                  console.warn('Fluix: sin datos en Firestore. Ejecuta Fluix.sincronizar() en consola F12.');
                  return;
              }
              var data = doc.data();

              // Toggle visible/oculto (el Switch de la app)
              if (data.activa === false) {
                  section.style.display = 'none';
                  console.log('Fluix: sección desactivada desde la app → oculta en web');
                  return;
              }
              section.style.display = '';

              var contenido = (data.contenido !== undefined) ? data.contenido : data;
              var items = contenido.items_carta || contenido.ofertas || contenido.horarios || [];
              var dataMap = {};
              items.forEach(function (it) { if (it.id) dataMap[it.id] = it; });
              console.log('Fluix: ' + items.length + ' items recibidos. Actualizando web...');

              section.querySelectorAll('[data-fluix-item][data-fluix-campo]').forEach(function (el) {
                  var itemId   = el.getAttribute('data-fluix-item');
                  var campo    = el.getAttribute('data-fluix-campo');
                  var itemData = dataMap[itemId];
                  if (!itemData || itemData[campo] === undefined) return;

                  // Plato agotado: lo atenúa al 40%
                  if (itemData.disponible === false) {
                      var parent = el.parentElement;
                      while (parent && !parent.getAttribute('data-fluix-item')) parent = parent.parentElement;
                      if (parent) parent.style.opacity = '0.4';
                  } else {
                      var parent2 = el.parentElement;
                      while (parent2 && !parent2.getAttribute('data-fluix-item')) parent2 = parent2.parentElement;
                      if (parent2) parent2.style.opacity = '';
                  }

                  if (campo === 'precio' || campo.indexOf('precio') !== -1) {
                      el.innerText = formatearPrecio(itemData[campo]);
                  } else {
                      el.innerText = itemData[campo];
                  }
              });
          }, function (err) {
              console.error('Fluix error:', err.message);
          });

        window._fluixDB      = db;
        window._fluixSection = section;
    }

    // Herramientas accesibles desde consola
    window.Fluix = {

        // Sube los datos actuales de la web a Firestore (solo la 1ª vez)
        sincronizar: function () {
            var section = window._fluixSection;
            var db      = window._fluixDB;
            if (!section || !db) { console.error('Fluix: no iniciado todavía.'); return; }
            var grupos = {};
            section.querySelectorAll('[data-fluix-item][data-fluix-campo]').forEach(function (el) {
                var itemId = el.getAttribute('data-fluix-item');
                var campo  = el.getAttribute('data-fluix-campo');
                if (!grupos[itemId]) grupos[itemId] = { id: itemId, disponible: true, categoria: 'General' };
                var val = el.innerText.trim();
                if (campo.indexOf('precio') !== -1) val = parseFloat(val.replace('€','').replace(',','.').trim()) || 0;
                grupos[itemId][campo] = val;
            });
            var items = Object.values(grupos);
            console.log('Fluix Sync: subiendo ' + items.length + ' items...', items);
            db.collection('empresas').doc(CFG.empresaId)
              .collection('contenido_web').doc(CFG.seccionId)
              .set({
                  tipo: CFG.tipo,
                  nombre: CFG.seccionId.charAt(0).toUpperCase() + CFG.seccionId.slice(1),
                  descripcion: '',
                  activa: true,
                  orden: 0,
                  fecha_creacion: new Date(),
                  fecha_actualizacion: new Date(),
                  contenido: { titulo: CFG.seccionId, items_carta: items }
              })
              .then(function () { console.log('✅ Fluix: Sincronizado correctamente! Ya puedes editar desde la app.'); })
              .catch(function (e) { console.error('Fluix Sync error:', e.message); });
        },

        // Diagnóstico — muestra qué campos están detectados
        debug: function () {
            var section = window._fluixSection;
            console.log('=== FLUIX DEBUG ===');
            if (!section) { console.error('Script no cargado / sección no encontrada'); return; }
            console.log('Sección #' + CFG.blockId + ': OK');
            var campos = section.querySelectorAll('[data-fluix-item][data-fluix-campo]');
            console.log('Campos marcados: ' + campos.length);
            campos.forEach(function (el) {
                console.log('  ' + el.getAttribute('data-fluix-item') + '.' + el.getAttribute('data-fluix-campo') + ' = "' + el.innerText.trim().substring(0,40) + '"');
            });
            console.log('Firebase: ' + (window._fluixDB ? 'OK' : 'NO conectado'));
            console.log('==================');
        }
    };

    function iniciar() {
        var section = marcarDOM();
        if (!section) return;
        if (typeof firebase === 'undefined') {
            cargarScript('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js', function () {
                cargarScript('https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore-compat.js', function () {
                    conectar(section);
                });
            });
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
</script>
```

---

## 📝 Instrucciones rápidas

### 1. Rellena la sección CFG

| Campo | Qué poner |
|---|---|
| `empresaId` | El ID de la empresa en Firestore (te lo damos nosotros) |
| `seccionId` | Un nombre único para esta sección: `carta`, `ofertas`, `equipo`... |
| `tipo` | `carta`, `ofertas`, `texto`, `horarios` |
| `blockId` | El `id=""` del contenedor padre en el HTML de tu web |

### 2. Rellena el MAPA

Para cada texto que quieras controlar, añade una línea:
```javascript
{ hostingerId: 'id-del-elemento-en-web', item: 'nombre_del_item', campo: 'nombre_del_campo' },
```

### 3. Pégalo en la web

En Hostinger: Editor → Custom Code (bloque de página, no de sección).

### 4. Primera sync (solo 1 vez)

Abre la web, F12 → Consola, escribe:
```javascript
Fluix.sincronizar()
```

### 5. Ya está ✅

Desde la app puedes editar, el Switch activa/desactiva la sección en la web.

---

## 🏢 Ejemplo real — Restaurante con 3 secciones

Si tienes carta + ofertas + horarios, pegas **3 scripts separados**, cada uno con su `seccionId` y `blockId` diferente:

```
Script 1: seccionId='carta',   blockId='z1Oz3q'
Script 2: seccionId='ofertas', blockId='kXp7mN'
Script 3: seccionId='horarios',blockId='rT4qWs'
```

---

## 🔍 Cómo encontrar los IDs en Hostinger

1. Publica la web
2. Abre la web publicada (no el editor)
3. F12 → pestaña **Elements** (Elementos)
4. Haz clic en el icono de cursor arriba a la izquierda del inspector
5. Haz clic sobre el texto que quieres controlar
6. Busca el atributo `id="ai-XXXXX"` en el elemento o su contenedor
7. Ese es tu `hostingerId`

> ⚠️ Los IDs que ves en el editor de Hostinger son distintos a los de la web publicada. Siempre inspecciona la **web publicada**.


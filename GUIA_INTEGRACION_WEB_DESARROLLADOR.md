# 🛠️ Guía de Integración Web — PlaneaG / FluixCRM
> **Solo para el desarrollador web (FluixTech)**  
> Los clientes configuran el aspecto desde la app; tú integras el código.

---

## Estructura general

Cada empresa tiene su configuración almacenada en Firestore bajo:

```
empresas/{empresaId}/configuracion/reservas_web
```

El script que tú pegas en la web lee ese documento en tiempo real vía Firestore SDK (sin autenticación, acceso público configurado en las reglas de seguridad).

---

## 🔥 Configuración Firebase necesaria en la web

Añade el SDK de Firebase al `<head>` de cada página que use formularios dinámicos:

```html
<!-- Firebase v9 compat (CDN) -->
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore-compat.js"></script>
<script>
  if (!firebase.apps.length) {
    firebase.initializeApp({
      apiKey:            "TU_API_KEY",
      authDomain:        "TU_PROJECT.firebaseapp.com",
      projectId:         "TU_PROJECT_ID",
    });
  }
</script>
```

---

## 📅 Formulario de Reservas (Tab "Reservas Web" en la app)

### Campos config que maneja la app
| Campo Firestore         | Tipo        | Qué hace                                         |
|-------------------------|-------------|--------------------------------------------------|
| `activo`                | bool        | Si false → oculta el formulario y muestra aviso  |
| `horas_bloqueadas`      | List<String>| Franjas que aparecerán deshabilitadas            |
| `fechas_bloqueadas`     | List<String>| Fechas en formato `YYYY-MM-DD` bloqueadas        |
| `aforo_maximo_por_franja` | int       | Máximo de reservas por hora/franja               |
| `mensaje_slot_lleno`    | String      | Texto que aparece cuando una franja está llena   |

### IDs HTML requeridos en tu formulario

```html
<div id="reservaForm">
  <select id="fecha" onchange="updateSlotInfo()">
    <option value="2025-06-01">01/06/2025</option>
    <!-- más fechas... -->
  </select>

  <select id="hora" onchange="updateSlotInfo()">
    <option value="09:00">09:00</option>
    <option value="10:00">10:00</option>
    <option value="11:00">11:00</option>
    <!-- más horas... -->
  </select>

  <span id="slotInfo"></span>

  <button id="btnReservar" type="submit">Reservar</button>
</div>
```

### Script de integración (añadir antes de `</body>`)

Sustituye `EMPRESA_ID` por el ID real de la empresa en Firestore.

```html
<script>
(function (empresaId) {
  function aplicarConfigReservas(cfg) {
    var selectHora    = document.getElementById('hora');
    var selectFecha   = document.getElementById('fecha');
    var btnReservar   = document.getElementById('btnReservar');
    var formContainer = document.getElementById('reservaForm');

    // Formulario desactivado desde la app
    if (cfg.activo === false) {
      if (formContainer) formContainer.style.display = 'none';
      var aviso = document.createElement('p');
      aviso.textContent = 'Las reservas no están disponibles en este momento.';
      aviso.style.cssText = 'text-align:center;color:#e07070;padding:2rem;';
      if (formContainer && formContainer.parentNode)
        formContainer.parentNode.insertBefore(aviso, formContainer);
      return;
    }

    // Aforo y mensaje configurados desde la app
    window.AFORO_MAX      = cfg.aforo_maximo_por_franja || 2;
    window.MSG_SLOT_LLENO = cfg.mensaje_slot_lleno || '⚠ Esta franja está completa';

    // Bloquear horas
    var bloqueadas = cfg.horas_bloqueadas || [];
    if (selectHora) {
      Array.from(selectHora.options).forEach(function (opt) {
        if (bloqueadas.indexOf(opt.value) !== -1) {
          opt.disabled = true;
          opt.text     = opt.value + ' (no disponible)';
          opt.style.color = '#999';
        }
      });
    }

    // Bloquear fechas
    var fechasBloqueadas = cfg.fechas_bloqueadas || [];
    if (selectFecha) {
      selectFecha.addEventListener('change', function () {
        if (fechasBloqueadas.indexOf(this.value) !== -1) {
          var info = document.getElementById('slotInfo');
          if (info) { info.textContent = '⛔ Este día no está disponible'; info.className = 'slot-info full'; }
          if (btnReservar) btnReservar.disabled = true;
        }
      });
    }
  }

  // Función global para comprobar aforo (llámala también al enviar el form)
  window.updateSlotInfo = function () {
    var fecha = document.getElementById('fecha') && document.getElementById('fecha').value;
    var hora  = document.getElementById('hora')  && document.getElementById('hora').value;
    var info  = document.getElementById('slotInfo');
    var btn   = document.getElementById('btnReservar');
    var max   = window.AFORO_MAX      || 2;
    var msg   = window.MSG_SLOT_LLENO || '⚠ Esta franja está completa';

    if (!fecha || !hora) { if (info) info.textContent = ''; if (btn) btn.disabled = false; return; }

    // Lee reservas del localStorage (sincronizado por el script de registro de reservas)
    var r = (function () {
      try { return JSON.parse(localStorage.getItem('dj_reservas') || '{}'); } catch (e) { return {}; }
    })();
    var count = (r[fecha] && r[fecha][hora]) ? r[fecha][hora] : 0;

    if (count >= max) {
      if (info) { info.textContent = msg; info.className = 'slot-info full'; }
      if (btn)  btn.disabled = true;
    } else {
      if (info) { info.textContent = '✓ Disponible'; info.className = 'slot-info available'; }
      if (btn)  btn.disabled = false;
    }
  };

  // Suscriptor en tiempo real → se actualiza automáticamente al guardar desde la app
  firebase.firestore()
    .collection('empresas').doc(empresaId)
    .collection('configuracion').doc('reservas_web')
    .onSnapshot(function (doc) {
      if (doc.exists) aplicarConfigReservas(doc.data());
    });

})('EMPRESA_ID');  // ← Reemplaza por el empresaId real
</script>
```

---

## 📝 Formulario de Contacto / Servicios (dinámico)

La app permite configurar los **campos del formulario de contacto** desde el módulo de configuración web. La configuración se guarda en:

```
empresas/{empresaId}/configuracion/formulario_contacto
```

### Campos config
| Campo Firestore    | Tipo        | Descripción                                          |
|--------------------|-------------|------------------------------------------------------|
| `campos`           | List<Map>   | Lista de campos dinámicos (ver estructura abajo)     |
| `color_primario`   | String      | Color HEX del botón y elementos de acento            |
| `titulo_form`      | String      | Título visible sobre el formulario                   |
| `boton_texto`      | String      | Texto del botón de envío                             |
| `mensaje_exito`    | String      | Mensaje tras enviar el formulario                    |

### Estructura de cada campo en `campos`
```json
{
  "id": "nombre",           // ID único del campo
  "tipo": "text",           // text | email | tel | textarea | select | checkbox
  "etiqueta": "Tu nombre",  // Texto del label
  "requerido": true,        // Si es obligatorio
  "opciones": []            // Solo para tipo "select"
}
```

### Script de renderizado dinámico

```html
<div id="fluix-form-container"></div>

<script>
(function (empresaId) {
  function renderizarFormulario(cfg) {
    var container = document.getElementById('fluix-form-container');
    if (!container) return;

    var color  = cfg.color_primario  || '#1976D2';
    var titulo = cfg.titulo_form     || 'Contacto';
    var btnTxt = cfg.boton_texto     || 'Enviar';
    var campos = cfg.campos          || [];

    var html = '<h2 style="color:' + color + '">' + titulo + '</h2>';
    html += '<form id="fluix-form">';

    campos.forEach(function (campo) {
      html += '<div class="fluix-campo">';
      html += '<label for="campo_' + campo.id + '">' + campo.etiqueta;
      if (campo.requerido) html += ' <span style="color:red">*</span>';
      html += '</label>';

      if (campo.tipo === 'textarea') {
        html += '<textarea id="campo_' + campo.id + '" name="' + campo.id + '"'
             + (campo.requerido ? ' required' : '') + '></textarea>';
      } else if (campo.tipo === 'select') {
        html += '<select id="campo_' + campo.id + '" name="' + campo.id + '"'
             + (campo.requerido ? ' required' : '') + '>';
        (campo.opciones || []).forEach(function (op) {
          html += '<option value="' + op + '">' + op + '</option>';
        });
        html += '</select>';
      } else if (campo.tipo === 'checkbox') {
        html += '<input type="checkbox" id="campo_' + campo.id + '" name="' + campo.id + '">';
      } else {
        html += '<input type="' + campo.tipo + '" id="campo_' + campo.id + '" name="' + campo.id + '"'
             + (campo.requerido ? ' required' : '') + '>';
      }
      html += '</div>';
    });

    html += '<button type="submit" style="background:' + color
         + ';color:#fff;padding:12px 24px;border:none;border-radius:8px;cursor:pointer">'
         + btnTxt + '</button>';
    html += '</form>';
    html += '<p id="fluix-mensaje-exito" style="display:none;color:green">'
         + (cfg.mensaje_exito || '¡Mensaje enviado!') + '</p>';

    container.innerHTML = html;

    // Manejador de envío (integra con tu backend o Firestore directamente)
    document.getElementById('fluix-form').addEventListener('submit', function (e) {
      e.preventDefault();
      var datos = { empresa_id: empresaId, timestamp: new Date().toISOString() };
      campos.forEach(function (c) {
        var el = document.getElementById('campo_' + c.id);
        if (el) datos[c.id] = c.tipo === 'checkbox' ? el.checked : el.value;
      });
      console.log('📨 Datos del formulario:', datos);
      // Aquí envía a tu Cloud Function o endpoint:
      // fetch('/api/contacto', { method: 'POST', body: JSON.stringify(datos) });
      document.getElementById('fluix-mensaje-exito').style.display = 'block';
      document.getElementById('fluix-form').reset();
    });
  }

  // Escucha cambios en tiempo real → el formulario se actualiza al guardar desde la app
  firebase.firestore()
    .collection('empresas').doc(empresaId)
    .collection('configuracion').doc('formulario_contacto')
    .onSnapshot(function (doc) {
      if (doc.exists) renderizarFormulario(doc.data());
    });

})('EMPRESA_ID');  // ← Reemplaza por el empresaId real
</script>
```

---

## 🎨 Popup de Ofertas / Avisos

La app permite configurar un popup emergente desde la pestaña de configuración web. Se guarda en:

```
empresas/{empresaId}/configuracion/popup_web
```

### Campos config
| Campo            | Tipo   | Descripción                                      |
|------------------|--------|--------------------------------------------------|
| `activo`         | bool   | Si mostrar el popup                              |
| `titulo`         | String | Título del popup                                 |
| `texto`          | String | Cuerpo del popup                                 |
| `boton_texto`    | String | Texto del botón de acción                        |
| `boton_url`      | String | URL a la que lleva el botón                      |
| `delay_segundos` | int    | Segundos antes de mostrar (0 = inmediato)        |

### Script

```html
<script>
(function (empresaId) {
  firebase.firestore()
    .collection('empresas').doc(empresaId)
    .collection('configuracion').doc('popup_web')
    .onSnapshot(function (doc) {
      if (!doc.exists) return;
      var cfg = doc.data();
      if (!cfg.activo) return;
      if (sessionStorage.getItem('fluix_popup_visto')) return;

      setTimeout(function () {
        var overlay = document.createElement('div');
        overlay.style.cssText =
          'position:fixed;inset:0;background:rgba(0,0,0,.5);z-index:9999;'
          + 'display:flex;align-items:center;justify-content:center';

        var box = document.createElement('div');
        box.style.cssText =
          'background:#fff;border-radius:16px;padding:28px;max-width:380px;'
          + 'width:90%;text-align:center;box-shadow:0 8px 32px rgba(0,0,0,.2)';

        box.innerHTML =
          '<button onclick="this.closest(\'[data-fluix-popup]\').remove();sessionStorage.setItem(\'fluix_popup_visto\',1)"'
          + ' style="position:absolute;top:12px;right:16px;background:none;border:none;font-size:18px;cursor:pointer">✕</button>'
          + '<h3 style="margin-top:0">' + (cfg.titulo || '') + '</h3>'
          + '<p>' + (cfg.texto  || '') + '</p>'
          + (cfg.boton_url
              ? '<a href="' + cfg.boton_url + '" style="display:inline-block;background:#1976D2;color:#fff;'
                + 'padding:10px 22px;border-radius:8px;text-decoration:none;font-weight:bold">'
                + (cfg.boton_texto || 'Ver más') + '</a>'
              : '');

        overlay.setAttribute('data-fluix-popup', '');
        overlay.appendChild(box);
        document.body.appendChild(overlay);
        overlay.addEventListener('click', function (e) {
          if (e.target === overlay) {
            overlay.remove();
            sessionStorage.setItem('fluix_popup_visto', '1');
          }
        });
      }, (cfg.delay_segundos || 0) * 1000);
    });
})('EMPRESA_ID');  // ← Reemplaza por el empresaId real
</script>
```

---

## 📊 Script de Tráfico Web (Fluix Analytics)

Este script envía datos de visita al módulo **Tráfico Web** del panel propietario.  
Se guarda en: `empresas/{empresaId}/estadisticas/web_resumen`

```html
<script>
(function (empresaId) {
  var db = firebase.firestore();

  // Auth anónima para poder escribir (las reglas lo permiten para tracking)
  firebase.auth().signInAnonymously().then(function () {
    var ref = db.collection('empresas').doc(empresaId)
                .collection('estadisticas').doc('web_resumen');

    var isMobile  = /Mobi|Android/i.test(navigator.userAgent);
    var isTablet  = /Tablet|iPad/i.test(navigator.userAgent);
    var device    = isTablet ? 'visitas_tablet' : isMobile ? 'visitas_movil' : 'visitas_desktop';
    var pagina    = window.location.pathname || '/';
    var referrer  = document.referrer || 'directo';
    var now       = new Date();
    var hoy       = now.toISOString().split('T')[0];

    var upd = {
      visitas_total:    firebase.firestore.FieldValue.increment(1),
      visitas_mes:      firebase.firestore.FieldValue.increment(1),
      ultima_visita:    firebase.firestore.Timestamp.now(),
      ultima_actualizacion: firebase.firestore.FieldValue.serverTimestamp(),
    };
    upd[device] = firebase.firestore.FieldValue.increment(1);
    upd['paginas_mas_vistas.' + pagina.replace(/\//g, '_').replace(/^_/, '') || 'inicio'] =
      firebase.firestore.FieldValue.increment(1);

    ref.set(upd, { merge: true }).catch(console.error);
  });
})('EMPRESA_ID');  // ← Reemplaza por el empresaId real
</script>
```

> **Nota**: Para que este script funcione necesitas añadir Firebase Auth al SDK:
> ```html
> <script src="https://www.gstatic.com/firebasejs/10.12.0/firebase-auth-compat.js"></script>
> ```

---

## 🔑 ¿Cómo obtener el `empresaId`?

1. Ve a Firebase Console → Firestore → colección `empresas`
2. El ID del documento de cada empresa es el `empresaId` que debes usar en todos los scripts

---

## ✅ Checklist por empresa nueva

- [ ] Copiar `empresaId` de Firestore
- [ ] Añadir SDK de Firebase al `<head>` con las credenciales del proyecto
- [ ] Sustituir todos los `EMPRESA_ID` de los scripts
- [ ] Probar en local con las reglas de Firestore correctas
- [ ] Verificar que el documento `configuracion/reservas_web` existe en Firestore
- [ ] Ajustar estilos CSS del formulario (los scripts no imponen estilos de layout)


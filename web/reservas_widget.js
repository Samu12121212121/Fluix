/**
 * FLUIX CRM — Script de reservas genérico para cualquier empresa
 * =============================================================
 * USO en Hostinger/WordPress — copia este bloque en el footer o en la página:
 *
 *   <form id="form-reserva"> ... </form>
 *   <div id="mensaje-resultado"></div>
 *
 *   <script>
 *     window.FluixReservaConfig = {
 *       empresaId: 'TU_EMPRESA_ID',   // ← ID del doc empresa en Firestore
 *       nombre:    'Mi Restaurante',   // ← Nombre para logs (opcional)
 *     };
 *   </script>
 *   <script src="https://planeaapp-4bea4.web.app/reservas_widget.js" defer></script>
 *
 * CAMPOS ESPERADOS EN EL FORMULARIO (id del input):
 *   - fecha          (obligatorio)
 *   - hora           (obligatorio)
 *   - nombre         (obligatorio)
 *   - telefono       (obligatorio)
 *   - email          (opcional)
 *   - comensales     (opcional, número)
 *   - notas          (opcional)
 *   - servicio       (opcional, para peluquerías/citas)
 *
 * ELEMENTOS DE FEEDBACK:
 *   - btn-submit         → botón de envío
 *   - mensaje-resultado  → div donde aparece el mensaje de éxito/error
 */

(function () {
  'use strict';

  var cfg = (window.FluixReservaConfig || {});
  var EMPRESA_ID = cfg.empresaId || '';
  var PROJECT_ID = 'planeaapp-4bea4';
  var FS_BASE = 'https://firestore.googleapis.com/v1/projects/' + PROJECT_ID
              + '/databases/(default)/documents';

  if (!EMPRESA_ID) {
    console.error('[FluixReservas] Falta window.FluixReservaConfig.empresaId');
    return;
  }

  // ── Poner fecha mínima = hoy ─────────────────────────────────
  var hoy = new Date().toISOString().split('T')[0];
  var fechaEl = document.getElementById('fecha');
  if (fechaEl) {
    fechaEl.min   = hoy;
    if (!fechaEl.value) fechaEl.value = hoy;
  }

  // ── Conversión a formato Firestore REST ──────────────────────
  function toFields(obj) {
    var fields = {};
    Object.keys(obj).forEach(function (k) {
      var v = obj[k];
      if (v === null || v === undefined || v === '') return; // omitir vacíos
      if (typeof v === 'boolean')  { fields[k] = { booleanValue: v }; }
      else if (typeof v === 'number') { fields[k] = { integerValue: String(Math.round(v)) }; }
      else if (v instanceof Date)  { fields[k] = { timestampValue: v.toISOString() }; }
      else                         { fields[k] = { stringValue: String(v) }; }
    });
    return fields;
  }

  // ── Leer campo del formulario de forma segura ────────────────
  function val(id) {
    var el = document.getElementById(id);
    if (!el) return '';
    // Si es select sin valor, coge la primera opción
    if (el.tagName === 'SELECT' && !el.value && el.options.length) {
      return el.options[0].value;
    }
    return (el.value || '').trim();
  }

  function numVal(id, def) {
    var v = parseInt(val(id));
    return isNaN(v) ? def : v;
  }

  // ── Mostrar mensaje ──────────────────────────────────────────
  function mostrarMensaje(texto, exito) {
    var div = document.getElementById('mensaje-resultado');
    if (!div) return;
    div.textContent   = texto;
    div.className     = exito ? 'exito' : 'error';
    div.style.display = 'block';
    div.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  function formatFecha(str) {
    var p = str.split('-');
    return p[2] + '/' + p[1] + '/' + p[0];
  }

  // ── Listener del formulario ──────────────────────────────────
  var form = document.getElementById('form-reserva');
  if (!form) {
    console.warn('[FluixReservas] No se encontró #form-reserva');
    return;
  }

  form.addEventListener('submit', function (e) {
    e.preventDefault();

    var fecha    = val('fecha');
    var hora     = val('hora');
    var nombre   = val('nombre');
    var telefono = val('telefono');
    var email    = val('email');
    var notas    = val('notas');
    var servicio = val('servicio');
    var comensales = numVal('comensales', 1);

    if (!fecha || !nombre || !telefono) {
      mostrarMensaje('Por favor rellena todos los campos obligatorios.', false);
      return;
    }
    if (!hora) {
      mostrarMensaje('Por favor selecciona una hora.', false);
      return;
    }

    var btn = document.getElementById('btn-submit');
    if (btn) { btn.disabled = true; btn.textContent = 'Enviando...'; }

    // Parsear fecha local (evitar UTC shift en España UTC+2)
    var ymd = fecha.split('-');
    var hm  = hora.split(':');
    var fechaObj = new Date(
      parseInt(ymd[0]), parseInt(ymd[1]) - 1, parseInt(ymd[2]),
      parseInt(hm[0] || 0), parseInt(hm[1] || 0), 0
    );

    var datos = {
      nombre_cliente:   nombre,
      telefono_cliente: telefono,
      correo_cliente:   email,
      personas:         comensales,
      fecha_hora:       fecha + 'T' + hora + ':00',
      fecha:            fechaObj,
      estado:           'PENDIENTE',
      origen:           'web',
      notas:            notas,
      empresa_id:       EMPRESA_ID,
      fecha_creacion:   new Date(),
    };
    if (servicio) datos.servicio = servicio;

    fetch(FS_BASE + '/empresas/' + EMPRESA_ID + '/reservas', {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify({ fields: toFields(datos) })
    })
    .then(function (res) {
      if (!res.ok) return res.text().then(function (t) { throw new Error(t); });
      mostrarMensaje(
        '✅ ¡Reserva recibida! Para el ' + formatFecha(fecha) + ' a las ' + hora +
        '. En breve te confirmamos.',
        true
      );
      form.reset();
      if (fechaEl) fechaEl.value = hoy;
    })
    .catch(function (err) {
      console.error('[FluixReservas] Error:', err);
      mostrarMensaje('Error al enviar la reserva. Inténtalo de nuevo o llámanos.', false);
    })
    .finally(function () {
      if (btn) { btn.disabled = false; btn.textContent = 'Solicitar Reserva'; }
    });
  });

})();


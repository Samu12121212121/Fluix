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
 * CAMPOS SOPORTADOS EN EL FORMULARIO (el script busca estos ids automáticamente):
 *   Obligatorios:
 *     - nombre / nombre_cliente
 *     - telefono / telefono_cliente / phone
 *     - fecha / date
 *     - hora / franja / franja_horaria / time_slot   → puede ser 'HH:MM' o 'HH:MM - HH:MM'
 *   Opcionales:
 *     - email / correo / email_cliente               → para emails de confirmación/cancelación
 *     - personas / numero_personas / comensales / num_personas
 *     - zona / mesa / preferencia_mesa               → 'terraza' | 'salon'
 *     - alergenos / alergias                         → checkbox → true/false
 *     - detalle_alergenos / alergias_detalle / cuales / detalle_alergias
 *     - notas / comentarios / observaciones / comments
 *     - servicio / servicio_sel
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
  var fechaEl = document.getElementById('fecha') || document.getElementById('date');
  if (fechaEl) {
    fechaEl.min = hoy;
    if (!fechaEl.value) fechaEl.value = hoy;
  }

  // ── Lee un campo buscando por varios IDs posibles ────────────
  function valFlexible(ids) {
    for (var i = 0; i < ids.length; i++) {
      var el = document.getElementById(ids[i]);
      if (!el) continue;
      if (el.type === 'checkbox') return el.checked ? (el.value || 'si') : '';
      if (el.tagName === 'SELECT') return (el.value || '').trim();
      if (el.value !== undefined) return (el.value || '').trim();
    }
    return '';
  }

  function checkFlexible(ids) {
    for (var i = 0; i < ids.length; i++) {
      var el = document.getElementById(ids[i]);
      if (!el) continue;
      if (el.type === 'checkbox') return el.checked;
      var v = (el.value || '').toLowerCase();
      return v === 'si' || v === 'yes' || v === 'true' || v === '1';
    }
    return false;
  }

  function numFlexible(ids, def) {
    var v = parseInt(valFlexible(ids));
    return isNaN(v) ? def : v;
  }

  // ── Conversión a formato Firestore REST ──────────────────────
  function toFields(obj) {
    var fields = {};
    Object.keys(obj).forEach(function (k) {
      var v = obj[k];
      if (v === null || v === undefined || v === '') return;
      if (typeof v === 'boolean')     { fields[k] = { booleanValue: v }; }
      else if (typeof v === 'number') { fields[k] = { integerValue: String(Math.round(v)) }; }
      else if (v instanceof Date)     { fields[k] = { timestampValue: v.toISOString() }; }
      else                            { fields[k] = { stringValue: String(v) }; }
    });
    return fields;
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

    // ── Leer campos con fallback múltiple de IDs ─────────────
    var fecha    = valFlexible(['fecha', 'date', 'fecha_reserva']);
    var hora     = valFlexible(['hora', 'franja', 'franja_horaria', 'time_slot', 'horario']);
    var nombre   = valFlexible(['nombre', 'nombre_cliente', 'name']);
    var telefono = valFlexible(['telefono', 'telefono_cliente', 'phone', 'tel']);
    var email    = valFlexible(['email', 'correo', 'email_cliente', 'mail']);

    var numPersonas = numFlexible(
      ['personas', 'numero_personas', 'num_personas', 'comensales', 'guests'], 1
    );
    var servicio = valFlexible(['servicio', 'servicio_sel', 'service']);
    var zona     = valFlexible(['zona', 'mesa', 'preferencia_mesa', 'table', 'table_preference']);
    var alergenos       = checkFlexible(['alergenos', 'alergias', 'alergias_intolerancia', 'has_alergias']);
    var detalleAlergenos = alergenos
      ? valFlexible(['detalle_alergenos', 'alergias_detalle', 'cuales', 'detalle_alergias', 'allergens_detail'])
      : '';
    var notas = valFlexible(['notas', 'comentarios', 'comments', 'observaciones', 'nota']);

    // ── Validación ────────────────────────────────────────────
    if (!fecha || !nombre || !telefono) {
      mostrarMensaje('Por favor rellena los campos obligatorios: nombre, teléfono y fecha.', false);
      return;
    }
    if (!hora) {
      mostrarMensaje('Por favor selecciona una franja horaria.', false);
      return;
    }

    var btn = document.getElementById('btn-submit');
    if (btn) { btn.disabled = true; btn.textContent = 'Enviando...'; }

    // ── Parsear hora (puede ser 'HH:MM' o 'HH:MM - HH:MM') ──
    var horaParsed = hora.split(' - ')[0].split(' – ')[0].trim();
    var matchHora = horaParsed.match(/(\d{1,2}):(\d{2})/);
    var horaH = matchHora ? parseInt(matchHora[1]) : 20;
    var horaM = matchHora ? parseInt(matchHora[2]) : 0;

    // Limpiar hora para mostrar en el mensaje
    var horaDisplay = (matchHora ? horaParsed : hora).substring(0, 5);

    // ── Parsear fecha (evitar UTC shift en España UTC+2) ─────
    var ymd = fecha.split('-');
    var fechaObj = new Date(
      parseInt(ymd[0]), parseInt(ymd[1]) - 1, parseInt(ymd[2]),
      horaH, horaM, 0
    );

    // ── Construir documento de reserva ───────────────────────
    // Nombres de campo exactos que usa la app Flutter / Firestore existente
    var datos = {
      nombre_cliente:    nombre,
      telefono_cliente:  telefono,
      email_cliente:     email,       // para emails de confirmación/cancelación
      correo_cliente:    email,       // campo legacy (compatibilidad con versiones antiguas)
      numero_personas:   numPersonas,
      fecha:             fechaObj,    // Timestamp — calendario de la app
      fecha_hora:        fechaObj,    // Timestamp — vistas de detalle y triggers
      estado:            'PENDIENTE',
      origen:            'web',
      created_at:        new Date(),  // Timestamp de creación (nombre que usa la app)
      // Campos extra hostelería/Damajuana
      zona:              zona,
      alergenos:         alergenos,
      detalle_alergenos: detalleAlergenos,
      notas:             notas,
    };

    if (servicio)          datos.servicio = servicio;
    // Limpiar campos vacíos para no contaminar Firestore
    if (!email)            { delete datos.email_cliente; delete datos.correo_cliente; }
    if (!zona)             delete datos.zona;
    if (!notas)            delete datos.notas;
    if (!alergenos)        delete datos.alergenos;
    if (!detalleAlergenos) delete datos.detalle_alergenos;

    fetch(FS_BASE + '/empresas/' + EMPRESA_ID + '/reservas', {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify({ fields: toFields(datos) })
    })
    .then(function (res) {
      if (!res.ok) return res.text().then(function (t) { throw new Error(t); });
      mostrarMensaje(
        '✅ ¡Reserva recibida! Para el ' + formatFecha(fecha) + ' a las ' + horaDisplay +
        '. En breve te confirmamos.',
        true
      );
      form.reset();
      if (fechaEl) fechaEl.value = hoy;
    })
    .catch(function (err) {
      console.error('[FluixReservas] Error guardando reserva:', err);
      mostrarMensaje('Error al enviar la reserva. Inténtalo de nuevo o llámanos directamente.', false);
    })
    .finally(function () {
      if (btn) { btn.disabled = false; btn.textContent = 'Solicitar Reserva'; }
    });
  });

})();

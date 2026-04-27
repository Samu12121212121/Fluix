
/**
 * FLUIX CRM — Script de reservas
 * ====================================================
 * MODO A — Formulario Dama Juana (y cualquier form que lance el evento):
 *   document.dispatchEvent(new CustomEvent('fluix:reserva', { detail: formData }))
 *   → El widget escucha el evento y guarda en Firestore. No necesita id="form-reserva".
 *
 * MODO B — Widget genérico con id="form-reserva"
 *   → El widget toma el submit y guarda en Firestore.
 *
 * CONFIGURACIÓN:
 *   window.FluixReservaConfig = { empresaId: 'TU_EMPRESA_ID' };
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

  var hoy = new Date().toISOString().split('T')[0];
  var fechaEl = document.getElementById('fecha') || document.getElementById('date');
  if (fechaEl) { fechaEl.min = hoy; if (!fechaEl.value) fechaEl.value = hoy; }

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

  function parseFechaHora(fechaStr, horaStr) {
    var m = horaStr.match(/(\d{1,2}):(\d{2})/);
    var ymd = fechaStr.split('-');
    return new Date(parseInt(ymd[0]), parseInt(ymd[1])-1, parseInt(ymd[2]),
                    m ? parseInt(m[1]) : 20, m ? parseInt(m[2]) : 0, 0);
  }

  function guardarEnFirestore(datos, onExito, onError) {
    fetch(FS_BASE + '/empresas/' + EMPRESA_ID + '/reservas', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: toFields(datos) })
    })
    .then(function(res) {
      if (!res.ok) return res.text().then(function(t) { throw new Error(t); });
      console.log('[FluixReservas] ✅ Reserva guardada — empresa:', EMPRESA_ID);
      if (onExito) onExito();
    })
    .catch(function(err) {
      console.error('[FluixReservas] ❌ Error Firestore:', err);
      if (onError) onError(err);
    });
  }

  function mostrarMensaje(texto, exito) {
    var div = document.getElementById('formMsg') || document.getElementById('mensaje-resultado');
    if (!div) return;
    div.textContent = texto;
    if (div.id === 'formMsg') {
      div.className = exito ? 'form-msg success' : 'form-msg error';
    } else {
      div.className = exito ? 'exito' : 'error';
      div.style.display = 'block';
    }
  }

  function formatFecha(str) { var p = str.split('-'); return p[2]+'/'+p[1]+'/'+p[0]; }

  // ══ MODO A — CustomEvent 'fluix:reserva' (Dama Juana) ══
  document.addEventListener('fluix:reserva', function(e) {
    var d = e.detail || {};
    if (!d.fecha || !d.hora || !d.nombre) {
      console.warn('[FluixReservas] fluix:reserva datos incompletos', d); return;
    }

    var alergenos  = d.alergenos === 'si' || d.alergenos === true;
    var detalleAler = alergenos ? (d.alergenos_detalle || '') : '';
    var zona       = d.ubicacion || d.zona || '';
    var email      = d.email || d.correo || '';

    var datos = {
      nombre_cliente:    d.nombre,
      telefono_cliente:  d.telefono || '',
      email_cliente:     email,
      correo_cliente:    email,
      numero_personas:   parseInt(d.personas) || 1,
      fecha:             parseFechaHora(d.fecha, d.hora),
      fecha_hora:        parseFechaHora(d.fecha, d.hora),
      estado:            'PENDIENTE',
      origen:            'web',
      created_at:        new Date(),
      zona:              zona,
      alergenos:         alergenos,
      detalle_alergenos: detalleAler,
      notas:             d.comentarios || d.notas || '',
    };

    if (!email)       { delete datos.email_cliente; delete datos.correo_cliente; }
    if (!zona)        delete datos.zona;
    if (!datos.notas) delete datos.notas;
    if (!alergenos)   delete datos.alergenos;
    if (!detalleAler) delete datos.detalle_alergenos;

    guardarEnFirestore(datos, null, function() {
      mostrarMensaje('Reserva recibida, pero hubo un error al registrarla. Llámanos para confirmar.', false);
    });
  });

  // ══ MODO B — form genérico id="form-reserva" ══
  var form = document.getElementById('form-reserva');
  if (!form) return;

  form.addEventListener('submit', function(e) {
    e.preventDefault();

    var fecha    = valFlexible(['fecha','date']);
    var hora     = valFlexible(['hora','franja','franja_horaria','time_slot']);
    var nombre   = valFlexible(['nombre','nombre_cliente']);
    var telefono = valFlexible(['telefono','telefono_cliente','phone']);
    var email    = valFlexible(['email','correo','email_cliente']);
    var numP     = numFlexible(['personas','numero_personas','comensales'], 1);
    var zona     = valFlexible(['zona','mesa','preferencia_mesa']);
    var aler     = checkFlexible(['alergenos','alergias']);
    var detalleAler = aler ? valFlexible(['detalle_alergenos','alergenosTexto','alergias_detalle','cuales']) : '';
    var notas    = valFlexible(['notas','comentarios','observaciones']);

    if (!fecha || !nombre || !telefono) {
      mostrarMensaje('Rellena los campos obligatorios.', false); return;
    }
    if (!hora) { mostrarMensaje('Selecciona una franja horaria.', false); return; }

    var btn = document.getElementById('btn-submit');
    if (btn) { btn.disabled = true; btn.textContent = 'Enviando...'; }

    var horaDisplay = (hora.match(/\d{1,2}:\d{2}/) || [hora])[0];
    var datos = {
      nombre_cliente: nombre, telefono_cliente: telefono,
      email_cliente: email, correo_cliente: email,
      numero_personas: numP, fecha: parseFechaHora(fecha, hora),
      fecha_hora: parseFechaHora(fecha, hora),
      estado: 'PENDIENTE', origen: 'web', created_at: new Date(),
      zona: zona, alergenos: aler, detalle_alergenos: detalleAler, notas: notas,
    };
    if (!email)      { delete datos.email_cliente; delete datos.correo_cliente; }
    if (!zona)       delete datos.zona;
    if (!notas)      delete datos.notas;
    if (!aler)       delete datos.alergenos;
    if (!detalleAler) delete datos.detalle_alergenos;

    guardarEnFirestore(datos,
      function() {
        mostrarMensaje('✅ Reserva recibida para el '+formatFecha(fecha)+' a las '+horaDisplay+'. En breve te confirmamos.', true);
        form.reset();
        if (fechaEl) fechaEl.value = hoy;
        if (btn) { btn.disabled = false; btn.textContent = 'Solicitar Reserva'; }
      },
      function() {
        mostrarMensaje('Error al enviar. Inténtalo de nuevo o llámanos.', false);
        if (btn) { btn.disabled = false; btn.textContent = 'Solicitar Reserva'; }
      }
    );
  });

})();
/**
 * fluix-reservas-core.js
 * Script compartido para todos los formularios de reservas Fluix.
 *
 * USO EN CADA HTML DE EMPRESA:
 *   1. Incluir Firebase + este script
 *   2. Llamar FluixReservas.init('TU_EMPRESA_ID', { ...opciones })
 *
 * Cada HTML puede tener su propio CSS y campos únicos.
 * La lógica de horarios, bloqueos y Firestore está aquí, no en cada HTML.
 */
(function (global) {
  'use strict';

  /* ── Firebase (mismo proyecto para todas las empresas) ─────────────── */
  var firebaseConfig = {
    apiKey:            'AIzaSyB6lg_F_2BrtLZZX9acEvzAQOWrJDYmMxI',
    authDomain:        'planeaapp-4bea4.firebaseapp.com',
    projectId:         'planeaapp-4bea4',
    storageBucket:     'planeaapp-4bea4.firebasestorage.app',
    messagingSenderId: '1085482191658',
    appId:             '1:1085482191658:web:c5461353b123ab92d62c53'
  };

  if (!firebase.apps.length) firebase.initializeApp(firebaseConfig);

  var db   = firebase.firestore();
  var auth = firebase.auth();

  /* ── Estado interno ─────────────────────────────────────────────────── */
  var _empresaId = '';
  var _opts      = {};
  var _user      = null;
  var _slotCounts = {};

  var _cfg = {
    activo:                  true,
    aforoMax:                2,
    diasActivos:             [],
    fechasBloqueadas:        [],
    motivosCierre:           {},
    diasRecurrentesCerrados: [],
    intervalosCerrados:      [],
    duracionSlotMinutos:     30,
    horarioPorDia:           {},
    horariosReservaPorDia:   {}
  };

  /* ── Utilidades ─────────────────────────────────────────────────────── */
  function pad(n) { return n < 10 ? '0' + n : '' + n; }

  function getDiaISO(fecha) {
    var d = fecha.getUTCDay();
    return d === 0 ? 7 : d;
  }

  function parseHora(str) {
    var p = str.split(':');
    return parseInt(p[0], 10) * 60 + parseInt(p[1], 10);
  }

  /* ── Reglas de bloqueo (sincronizadas desde la app) ────────────────── */
  function getMensajeBloqueo(fechaStr) {
    if (!fechaStr) return null;
    var p = fechaStr.split('-');
    var f = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2], 12, 0, 0));
    var d = getDiaISO(f);

    if (_cfg.diasActivos.length > 0 && _cfg.diasActivos.indexOf(d) === -1)
      return '⛔ Cerrado este día de la semana';

    if (_cfg.diasRecurrentesCerrados.indexOf(d) !== -1)
      return '⛔ Cerrado habitualmente este día';

    for (var i = 0; i < _cfg.intervalosCerrados.length; i++) {
      var iv = _cfg.intervalosCerrados[i];
      if (iv.inicio && iv.fin) {
        if (f >= new Date(iv.inicio + 'T00:00:00') && f <= new Date(iv.fin + 'T23:59:59'))
          return iv.motivo ? '⛔ ' + iv.motivo : '⛔ Cerrado temporalmente';
      }
    }

    if (_cfg.fechasBloqueadas.indexOf(fechaStr) !== -1) {
      var m = _cfg.motivosCierre[fechaStr];
      return m ? '⛔ ' + m : '⛔ Este día no está disponible';
    }
    return null;
  }

  /* ── Generador de slots ─────────────────────────────────────────────── */
  function generarSlots(fechaStr) {
    if (!fechaStr) return [];
    var p   = fechaStr.split('-');
    var f   = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2], 12, 0, 0));
    var key = getDiaISO(f).toString();

    if (_cfg.horariosReservaPorDia[key] && _cfg.horariosReservaPorDia[key].length)
      return _cfg.horariosReservaPorDia[key];

    var h = _cfg.horarioPorDia[key];
    if (!h || !h.apertura || !h.cierre) return [];

    var slots = [];
    var t = parseHora(h.apertura);
    var c = parseHora(h.cierre);
    while (t < c) {
      slots.push(pad(Math.floor(t / 60)) + ':' + pad(t % 60));
      t += _cfg.duracionSlotMinutos;
    }
    return slots;
  }

  /* ── Consulta aforo real desde Firestore ────────────────────────────── */
  function cargarAforo(fechaStr, callback) {
    var p     = fechaStr.split('-');
    var ini   = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2], 0, 0, 0));
    var fin   = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2], 23, 59, 59));

    db.collection('empresas').doc(_empresaId)
      .collection('reservas')
      .where('fecha_hora', '>=', firebase.firestore.Timestamp.fromDate(ini))
      .where('fecha_hora', '<=', firebase.firestore.Timestamp.fromDate(fin))
      .get()
      .then(function (snap) {
        var counts = {};
        snap.forEach(function (doc) {
          var d = doc.data();
          var estado = (d.estado || '').toLowerCase();
          if (estado === 'cancelada' || estado === 'rechazada') return;
          var hora = d.hora;
          if (!hora && d.fecha_hora) {
            var ts = d.fecha_hora.toDate();
            hora = pad(ts.getUTCHours()) + ':' + pad(ts.getUTCMinutes());
          }
          if (hora) counts[hora] = (counts[hora] || 0) + 1;
        });
        _slotCounts = counts;
        if (callback) callback();
      })
      .catch(function () { if (callback) callback(); });
  }

  /* ── Actualizar el <select> de hora ────────────────────────────────── */
  function actualizarSelectHora(fechaStr) {
    var sel  = document.getElementById(_opts.campoHora       || 'hora');
    var info = document.getElementById(_opts.idSlotInfo      || 'slotInfo');
    var btn  = document.getElementById(_opts.idBotonEnviar   || 'btnReservar');
    if (!sel) return;

    sel.innerHTML = '<option value="">Cargando...</option>';
    if (btn) btn.disabled = true;

    if (!fechaStr) {
      sel.innerHTML = '<option value="">Selecciona una fecha primero</option>';
      return;
    }

    var bloqueo = getMensajeBloqueo(fechaStr);
    if (bloqueo) {
      sel.innerHTML = '<option value="">No disponible</option>';
      if (info) { info.textContent = bloqueo; info.className = 'fluix-slot-info fluix-closed'; }
      return;
    }

    cargarAforo(fechaStr, function () {
      var slots = generarSlots(fechaStr);
      if (!slots.length) {
        sel.innerHTML = '<option value="">No hay horarios disponibles</option>';
        return;
      }
      sel.innerHTML = '<option value="">Seleccionar hora</option>';
      slots.forEach(function (hora) {
        var lleno = (_slotCounts[hora] || 0) >= _cfg.aforoMax;
        var opt   = document.createElement('option');
        opt.value = hora;
        opt.text  = lleno ? hora + ' (completo)' : hora;
        opt.disabled = lleno;
        sel.appendChild(opt);
      });
      if (info) { info.textContent = ''; info.className = 'fluix-slot-info'; }
      if (btn) btn.disabled = false;
    });
  }

  function actualizarInfoSlot() {
    var sel  = document.getElementById(_opts.campoHora     || 'hora');
    var info = document.getElementById(_opts.idSlotInfo    || 'slotInfo');
    var btn  = document.getElementById(_opts.idBotonEnviar || 'btnReservar');
    if (!sel || !sel.value) return;

    var count = _slotCounts[sel.value] || 0;
    if (count >= _cfg.aforoMax) {
      if (info) { info.textContent = '⚠ Esta franja está completa'; info.className = 'fluix-slot-info fluix-full'; }
      if (btn) btn.disabled = true;
    } else if (count === _cfg.aforoMax - 1) {
      if (info) { info.textContent = '✓ Último hueco disponible'; info.className = 'fluix-slot-info fluix-ok'; }
      if (btn) btn.disabled = false;
    } else {
      if (info) { info.textContent = '✓ Disponible'; info.className = 'fluix-slot-info fluix-ok'; }
      if (btn) btn.disabled = false;
    }
  }

  /* ── Guardar reserva en Firestore ───────────────────────────────────── */
  function guardarReserva(datos) {
    var fechaHora = new Date(datos.fecha + 'T' + datos.hora + ':00');
    var payload = {
      fecha_hora:     firebase.firestore.Timestamp.fromDate(fechaHora),
      hora:           datos.hora,
      estado:         'PENDIENTE',
      origen:         'web',
      fecha_creacion: firebase.firestore.FieldValue.serverTimestamp()
    };

    /* Añadir todos los campos extra declarados por el HTML */
    (_opts.camposExtra || []).forEach(function (id) {
      if (datos[id] !== undefined) payload[id] = datos[id];
    });

    function escribir() {
      return db.collection('empresas').doc(_empresaId)
               .collection('reservas').add(payload);
    }

    return _user ? escribir()
                 : auth.signInAnonymously().then(function (c) { _user = c.user; return escribir(); });
  }

  /* ── Recoger valor de cualquier tipo de campo ───────────────────────── */
  function getValorCampo(form, id) {
    var el = document.getElementById(id);
    if (!el) {
      /* Intentar por name (para radio groups) */
      var byName = form.querySelector('[name="' + id + '"]:checked');
      return byName ? byName.value : '';
    }
    if (el.type === 'checkbox') return el.checked ? 'si' : 'no';
    if (el.type === 'radio')   {
      var r = form.querySelector('[name="' + el.name + '"]:checked');
      return r ? r.value : '';
    }
    return el.value.trim();
  }

  /* ════════════════════════════════════════════════════════════════════════
   * API PÚBLICA
   * ════════════════════════════════════════════════════════════════════════
   *
   * FluixReservas.init(empresaId, opciones)
   *
   * opciones:
   *   formId          string    id del <form>                  (def: 'reservaForm')
   *   campoFecha      string    id del <input type="date">     (def: 'fecha')
   *   campoHora       string    id del <select> de hora        (def: 'hora')
   *   idSlotInfo      string    id del <span> info de slot     (def: 'slotInfo')
   *   idBotonEnviar   string    id del <button> submit         (def: 'btnReservar')
   *   idMensaje       string    id del div resultado           (def: 'formMsg')
   *   idAvisoInactivo string    id del aviso inactivo          (def: 'reservaDesactivadoAviso')
   *   camposExtra     string[]  ids de campos a guardar        (ej: ['nombre','telefono','email'])
   *   mensajeExito    function  (datos) => string de éxito     (opcional)
   *   onExito         function  (datos) => void                (callback tras éxito)
   */
  var FluixReservas = {

    init: function (empresaId, opciones) {
      _empresaId = empresaId;
      _opts      = opciones || {};

      var formId    = _opts.formId          || 'reservaForm';
      var campoFecha = _opts.campoFecha     || 'fecha';
      var campoHora  = _opts.campoHora      || 'hora';
      var msgId      = _opts.idMensaje      || 'formMsg';
      var avisoId    = _opts.idAvisoInactivo|| 'reservaDesactivadoAviso';

      /* Auth anónima */
      auth.signInAnonymously().then(function (c) { _user = c.user; }).catch(function () {});
      auth.onAuthStateChanged(function (u) { _user = u; });

      /* Escuchar configuración en tiempo real */
      db.collection('empresas').doc(_empresaId)
        .collection('configuracion').doc('reservas_web')
        .onSnapshot(function (doc) {
          if (doc.exists) {
            var c = doc.data();
            _cfg.activo                  = c.activo !== false;
            _cfg.aforoMax                = c.aforo_maximo_por_franja || 2;
            _cfg.diasActivos             = c.dias_activos || [];
            _cfg.fechasBloqueadas        = c.fechas_bloqueadas || [];
            _cfg.motivosCierre           = c.motivos_cierre || {};
            _cfg.diasRecurrentesCerrados = c.dias_recurrentes_cerrados || [];
            _cfg.intervalosCerrados      = c.intervalos_cerrados || [];
            _cfg.duracionSlotMinutos     = c.duracion_slot_minutos || 30;
            _cfg.horarioPorDia           = c.horario_por_dia || {};
            _cfg.horariosReservaPorDia   = c.horarios_reserva_por_dia || {};
          }

          /* Mostrar / ocultar formulario según estado activo */
          var form  = document.getElementById(formId);
          var aviso = document.getElementById(avisoId);
          if (!_cfg.activo) {
            if (form)  form.style.display = 'none';
            if (aviso) aviso.style.cssText = 'display:block!important';
          } else {
            if (form)  form.style.display = '';
            if (aviso) aviso.style.cssText = 'display:none!important';
          }

          /* Recalcular si ya hay fecha elegida */
          var inputFecha = document.getElementById(campoFecha);
          if (inputFecha && inputFecha.value) actualizarSelectHora(inputFecha.value);
        });

      /* Esperar DOM listo */
      function setup() {
        var inputFecha = document.getElementById(campoFecha);
        var inputHora  = document.getElementById(campoHora);
        var form       = document.getElementById(formId);

        if (inputFecha) {
          inputFecha.min = new Date().toISOString().split('T')[0];
          inputFecha.addEventListener('change', function () {
            actualizarSelectHora(this.value);
          });
        }
        if (inputHora) {
          inputHora.addEventListener('change', actualizarInfoSlot);
        }

        if (!form) return;

        form.addEventListener('submit', function (e) {
          e.preventDefault();
          var msg   = document.getElementById(msgId);
          var fecha = inputFecha ? inputFecha.value : '';
          var hora  = inputHora  ? inputHora.value  : '';

          if (!fecha || !hora) return;

          var bloqueo = getMensajeBloqueo(fecha);
          if (bloqueo) {
            if (msg) { msg.textContent = bloqueo; msg.className = 'form-msg error'; }
            return;
          }
          if ((_slotCounts[hora] || 0) >= _cfg.aforoMax) {
            if (msg) { msg.textContent = 'Lo sentimos, esta franja ya no tiene disponibilidad.'; msg.className = 'form-msg error'; }
            return;
          }

          /* Recoger campos del formulario */
          var datos = { fecha: fecha, hora: hora };
          (_opts.camposExtra || []).forEach(function (id) {
            datos[id] = getValorCampo(form, id);
          });

          var btn = document.getElementById(_opts.idBotonEnviar || 'btnReservar');
          if (btn) btn.disabled = true;

          guardarReserva(datos)
            .then(function () {
              _slotCounts[hora] = (_slotCounts[hora] || 0) + 1;

              var textoOk = _opts.mensajeExito
                ? _opts.mensajeExito(datos)
                : '✅ Reserva recibida para el ' + fecha + ' a las ' + hora + '. En breve te confirmamos.';

              if (msg) { msg.textContent = textoOk; msg.className = 'form-msg success'; }
              form.reset();
              if (inputHora) inputHora.innerHTML = '<option value="">Selecciona una fecha primero</option>';
              if (_opts.onExito) _opts.onExito(datos);
            })
            .catch(function (err) {
              if (msg) { msg.textContent = '❌ Error al enviar. Inténtalo de nuevo.'; msg.className = 'form-msg error'; }
              if (btn) btn.disabled = false;
              console.error('[FluixReservas]', err);
            });
        });
      }

      if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', setup);
      } else {
        setup();
      }
    }
  };

  global.FluixReservas = FluixReservas;

})(window);

(function () {

  // ── CONFIGURACIÓN ─────────────────────────────────────────────
  var EMPRESA_ID = "TUz8GOnQ6OX8ejiov7c5GM9LFPl2"; // Dama Juana

  var cfg = {
    apiKey:            "AIzaSyCVK8AUerxlYcr6N1fZg6t0RL8c7ajfNzU",
    authDomain:        "planeaapp-4bea4.firebaseapp.com",
    projectId:         "planeaapp-4bea4",
    storageBucket:     "planeaapp-4bea4.firebasestorage.app",
    messagingSenderId: "1085482191658",
    appId:             "1:1085482191658:web:c5461353b123ab92d62c53"
  };

  var app = (firebase.apps || []).find(function (a) { return a && a.name === 'FluixReservas'; })
         || firebase.initializeApp(cfg, 'FluixReservas');
  var db   = firebase.firestore(app);
  var auth = firebase.auth(app);

  // Poner fecha mínima = hoy
  var hoy = new Date().toISOString().split('T')[0];
  document.getElementById('fecha').min   = hoy;
  document.getElementById('fecha').value = hoy;

  // ── AUTENTICACIÓN ANÓNIMA ──────────────────────────────────────
  // Guardamos la promesa para esperar a que termine antes de escribir
  var authListo = auth.signInAnonymously().catch(function (e) {
    console.warn('Fluix: auth anónima no disponible, se intentará sin auth:', e.message);
  });

  // ── SUBMIT ─────────────────────────────────────────────────────
  document.getElementById('form-reserva').addEventListener('submit', function (e) {
    e.preventDefault();

    var fecha      = document.getElementById('fecha').value;
    var hora       = document.getElementById('hora').value;
    var comensales = parseInt(document.getElementById('comensales').value) || 1;
    var nombre     = document.getElementById('nombre').value.trim();
    var email      = document.getElementById('email').value.trim();
    var telefono   = document.getElementById('telefono').value.trim();
    var notas      = document.getElementById('notas').value.trim();

    if (!fecha || !hora || !nombre || !telefono) {
      _mostrarMensaje('Por favor rellena todos los campos obligatorios.', false);
      return;
    }

    var btn = document.getElementById('btn-submit');
    btn.disabled    = true;
    btn.textContent = 'Enviando reserva...';

    var fechaHoraStr = fecha + 'T' + hora + ':00';
    // Parsear manualmente para evitar que JS interprete la fecha como UTC.
    // new Date("YYYY-MM-DDTHH:MM:SS") sin zona horaria = UTC en muchos navegadores,
    // lo que haría que en España (UTC+2) las 20:00 se guarden como 18:00.
    var _ymd = fecha.split('-');
    var _hm  = hora.split(':');
    var fechaObj = new Date(
      parseInt(_ymd[0]),
      parseInt(_ymd[1]) - 1,
      parseInt(_ymd[2]),
      parseInt(_hm[0]),
      parseInt(_hm[1]),
      0
    );

    // Esperamos a que la auth anónima termine antes de escribir en Firestore
    // NOTA: el check de disponibilidad se eliminó porque los usuarios anónimos
    // no tienen permiso de lectura en /reservas (datos privados de clientes).
    // El restaurante gestiona conflictos desde la app.
    authListo.then(function () {
      return db.collection('empresas').doc(EMPRESA_ID)
        .collection('reservas')
        .add({
          nombre_cliente:   nombre,
          telefono_cliente: telefono,
          correo_cliente:   email,
          personas:         comensales,
          fecha:            firebase.firestore.Timestamp.fromDate(fechaObj),
          fecha_hora:       fechaHoraStr,
          estado:           'PENDIENTE',
          origen:           'web',
          notas:            notas || '',
          fecha_creacion:   firebase.firestore.FieldValue.serverTimestamp(),
          empresa_id:       EMPRESA_ID,
        });
    })
    .then(function () {
      _mostrarMensaje(
        '✅ ¡Solicitud recibida! Tu reserva para el ' +
        _formatFecha(fecha) + ' a las ' + hora +
        ' está pendiente de confirmación. Te contactaremos pronto.',
        true
      );
      document.getElementById('form-reserva').reset();
      document.getElementById('fecha').value = hoy;
    })
    .catch(function (err) {
      console.error('Error guardando reserva:', err);
      _mostrarMensaje('Error al enviar la reserva: ' + err.message, false);
    })
    .finally(function () {
      btn.disabled    = false;
      btn.textContent = 'Solicitar Reserva';
    });
  });

  // ── UTILIDADES ─────────────────────────────────────────────────
  function _mostrarMensaje(texto, exito) {
    var div = document.getElementById('mensaje-resultado');
    div.textContent = texto;
    div.className   = exito ? 'exito' : 'error';
    div.style.display = 'block';
    div.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  function _formatFecha(fechaStr) {
    var partes = fechaStr.split('-');
    return partes[2] + '/' + partes[1] + '/' + partes[0];
  }

})();



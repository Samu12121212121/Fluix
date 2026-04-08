/**
 * FLUIX CRM — Widget de Reservas Web Embebible
 * ─────────────────────────────────────────────
 * Uso:
 *   <div id="fluix-reservas"></div>
 *   <script>
 *     window.FluixReservas = { empresaId: 'TU_EMPRESA_ID' };
 *   </script>
 *   <script src="reservas.js" defer></script>
 *
 * Opciones (window.FluixReservas):
 *   empresaId       {string}  OBLIGATORIO — ID del documento de empresa en Firestore
 *   containerId     {string}  ID del div contenedor (default: 'fluix-reservas')
 *   color           {string}  Color primario hex (default: '#1976D2')
 *   titulo          {string}  Título del widget (default: 'Reserva tu cita')
 *   subtitulo       {string}  Subtítulo (default: '')
 *   horaInicio      {number}  Hora apertura en 24h (default: 9)
 *   horaFin         {number}  Hora cierre en 24h (default: 20)
 *   intervaloMin    {number}  Intervalo de slots en minutos (default: 30)
 *   diasSemana      {array}   Días laborables 0=Dom..6=Sáb (default: [1,2,3,4,5])
 */

(function () {
  'use strict';

  // ── Configuración ────────────────────────────────────────────────────────
  const cfg = Object.assign({
    empresaId: '',
    containerId: 'fluix-reservas',
    color: '#1976D2',
    titulo: 'Reserva tu cita',
    subtitulo: '',
    horaInicio: 9,
    horaFin: 20,
    intervaloMin: 30,
    diasSemana: [1, 2, 3, 4, 5],
  }, window.FluixReservas || {});

  const FIREBASE_CDN = 'https://www.gstatic.com/firebasejs/10.14.0/';
  let db = null;

  // ── Estado del widget ─────────────────────────────────────────────────────
  const state = {
    paso: 1,           // 1=servicio, 2=fecha, 3=datos, 4=confirmacion
    servicios: [],
    servicioSel: null,
    fechaSel: null,    // Date object
    horaSel: null,     // 'HH:MM'
    reservasOcupadas: [],
    nombre: '',
    telefono: '',
    correo: '',
    notas: '',
    cargando: false,
    error: null,
    idReserva: null,
  };

  // ── Helpers ───────────────────────────────────────────────────────────────
  const dias = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
  const meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
                  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

  function pad(n) { return String(n).padStart(2, '0'); }

  function formatFecha(d) {
    return `${dias[d.getDay()]} ${d.getDate()} de ${meses[d.getMonth()]}`;
  }

  function isoFechaHora(date, hora) {
    const [h, m] = hora.split(':').map(Number);
    const d = new Date(date);
    d.setHours(h, m, 0, 0);
    return d.toISOString();
  }

  function generarSlots(durMin) {
    const slots = [];
    const total = (cfg.horaFin - cfg.horaInicio) * 60;
    for (let i = 0; i < total; i += Math.max(cfg.intervaloMin, durMin)) {
      const h = cfg.horaInicio + Math.floor(i / 60);
      const m = i % 60;
      if (h < cfg.horaFin) slots.push(`${pad(h)}:${pad(m)}`);
    }
    return slots;
  }

  function slotOcupado(fecha, hora, durMin) {
    const inicio = new Date(isoFechaHora(fecha, hora)).getTime();
    const fin = inicio + durMin * 60000;
    return state.reservasOcupadas.some(r => {
      const rInicio = new Date(r.fecha_hora).getTime();
      const rFin = rInicio + r.duracion_minutos * 60000;
      return rInicio < fin && rFin > inicio;
    });
  }

  function proximosDias(n) {
    const result = [];
    const hoy = new Date();
    hoy.setHours(0, 0, 0, 0);
    let d = new Date(hoy);
    d.setDate(d.getDate() + 1); // Mañana mínimo
    while (result.length < n) {
      if (cfg.diasSemana.includes(d.getDay())) result.push(new Date(d));
      d.setDate(d.getDate() + 1);
    }
    return result;
  }

  // ── Estilos ───────────────────────────────────────────────────────────────
  function injectStyles() {
    if (document.getElementById('fluix-reservas-css')) return;
    const s = document.createElement('style');
    s.id = 'fluix-reservas-css';
    s.textContent = `
      .frw { font-family: system-ui,-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;
             max-width: 540px; margin: 0 auto; color: #333; box-sizing: border-box; }
      .frw *, .frw *::before, .frw *::after { box-sizing: inherit; }
      .frw-card { background: #fff; border-radius: 12px; box-shadow: 0 2px 16px rgba(0,0,0,.1);
                  overflow: hidden; }
      .frw-head { background: ${cfg.color}; color: #fff; padding: 20px 24px; }
      .frw-head h2 { margin: 0 0 4px; font-size: 1.3rem; }
      .frw-head p  { margin: 0; opacity: .85; font-size: .9rem; }
      .frw-steps { display: flex; border-bottom: 1px solid #eee; }
      .frw-step  { flex: 1; text-align: center; padding: 10px 4px; font-size: .75rem;
                   color: #aaa; border-bottom: 3px solid transparent; transition: all .2s; }
      .frw-step.active   { color: ${cfg.color}; border-color: ${cfg.color}; font-weight: 600; }
      .frw-step.done     { color: #4caf50; border-color: #4caf50; }
      .frw-body  { padding: 20px 24px; }
      .frw-sec-title { font-size: .85rem; font-weight: 600; color: #888;
                       text-transform: uppercase; letter-spacing: .05em; margin: 0 0 12px; }
      /* Servicios */
      .frw-svc-list { display: grid; gap: 10px; }
      .frw-svc { border: 2px solid #eee; border-radius: 8px; padding: 12px 16px;
                 cursor: pointer; transition: border-color .2s, background .2s; }
      .frw-svc:hover  { border-color: ${cfg.color}; background: ${cfg.color}11; }
      .frw-svc.sel    { border-color: ${cfg.color}; background: ${cfg.color}18; }
      .frw-svc-name   { font-weight: 600; margin-bottom: 4px; }
      .frw-svc-meta   { display: flex; gap: 16px; font-size: .82rem; color: #666; }
      .frw-svc-precio { color: ${cfg.color}; font-weight: 700; }
      /* Días */
      .frw-dias { display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 20px; }
      .frw-dia  { border: 2px solid #eee; border-radius: 8px; padding: 8px 12px; cursor: pointer;
                  text-align: center; min-width: 72px; transition: border-color .2s, background .2s; }
      .frw-dia:hover { border-color: ${cfg.color}; background: ${cfg.color}11; }
      .frw-dia.sel   { border-color: ${cfg.color}; background: ${cfg.color}18; }
      .frw-dia-nombre { font-size: .75rem; color: #888; }
      .frw-dia-num    { font-size: 1.2rem; font-weight: 700; }
      /* Horas */
      .frw-horas { display: flex; gap: 8px; flex-wrap: wrap; }
      .frw-hora  { border: 2px solid #eee; border-radius: 6px; padding: 6px 12px;
                   font-size: .9rem; cursor: pointer; transition: all .2s; }
      .frw-hora:hover    { border-color: ${cfg.color}; background: ${cfg.color}11; }
      .frw-hora.sel      { border-color: ${cfg.color}; background: ${cfg.color}; color: #fff; }
      .frw-hora.ocupado  { background: #f5f5f5; color: #ccc; cursor: not-allowed;
                           border-color: #eee; text-decoration: line-through; }
      /* Form datos */
      .frw-field       { margin-bottom: 14px; }
      .frw-field label { display: block; font-size: .82rem; color: #666;
                         font-weight: 600; margin-bottom: 4px; }
      .frw-field input, .frw-field textarea {
        width: 100%; padding: 9px 12px; border: 1px solid #ddd;
        border-radius: 6px; font-size: .95rem; font-family: inherit;
        transition: border-color .2s; }
      .frw-field input:focus, .frw-field textarea:focus {
        outline: none; border-color: ${cfg.color}; }
      .frw-field textarea { resize: vertical; min-height: 70px; }
      /* Resumen */
      .frw-resumen { background: #f8f9fa; border-radius: 8px; padding: 14px 16px; margin-bottom: 20px; }
      .frw-resumen-row { display: flex; justify-content: space-between;
                         padding: 5px 0; font-size: .9rem; }
      .frw-resumen-label { color: #888; }
      .frw-resumen-val   { font-weight: 600; }
      /* Botones */
      .frw-btns { display: flex; justify-content: space-between; gap: 12px; margin-top: 20px; }
      .frw-btn  { flex: 1; padding: 11px 20px; border-radius: 8px; border: none;
                  font-size: .95rem; font-weight: 600; cursor: pointer; transition: opacity .2s; }
      .frw-btn:disabled { opacity: .5; cursor: not-allowed; }
      .frw-btn-primary  { background: ${cfg.color}; color: #fff; }
      .frw-btn-primary:hover:not(:disabled) { opacity: .88; }
      .frw-btn-sec      { background: #eee; color: #555; }
      .frw-btn-sec:hover:not(:disabled) { background: #e0e0e0; }
      /* Loading / Error / Success */
      .frw-loading { text-align: center; padding: 32px; color: #888; }
      .frw-spinner { width: 36px; height: 36px; border: 3px solid #eee;
                     border-top-color: ${cfg.color}; border-radius: 50%;
                     animation: frw-spin 0.7s linear infinite; margin: 0 auto 12px; }
      @keyframes frw-spin { to { transform: rotate(360deg); } }
      .frw-error  { background: #ffebee; color: #c62828; border-radius: 8px;
                    padding: 10px 14px; margin-bottom: 14px; font-size: .88rem; }
      .frw-success{ text-align: center; padding: 28px 24px; }
      .frw-success-icon { font-size: 3rem; margin-bottom: 12px; }
      .frw-success h3   { margin: 0 0 8px; font-size: 1.2rem; }
      .frw-success p    { color: #666; font-size: .9rem; margin: 0 0 20px; }
    `;
    document.head.appendChild(s);
  }

  // ── Render ────────────────────────────────────────────────────────────────
  function render() {
    const el = document.getElementById(cfg.containerId);
    if (!el) return;

    let html = `<div class="frw"><div class="frw-card">`;

    // Cabecera
    html += `<div class="frw-head">
      <h2>${cfg.titulo}</h2>
      ${cfg.subtitulo ? `<p>${cfg.subtitulo}</p>` : ''}
    </div>`;

    // Pasos
    const pasos = ['Servicio', 'Fecha y hora', 'Tus datos', 'Confirmar'];
    html += `<div class="frw-steps">`;
    pasos.forEach((p, i) => {
      const n = i + 1;
      let cls = '';
      if (n === state.paso) cls = 'active';
      else if (n < state.paso) cls = 'done';
      html += `<div class="frw-step ${cls}">${n < state.paso ? '✓ ' : ''}${p}</div>`;
    });
    html += `</div>`;

    html += `<div class="frw-body">`;

    // Error global
    if (state.error) {
      html += `<div class="frw-error">⚠️ ${state.error}</div>`;
    }

    // Loading
    if (state.cargando) {
      html += `<div class="frw-loading"><div class="frw-spinner"></div>Un momento…</div>`;
    } else if (state.paso === 1) {
      html += renderPasoServicios();
    } else if (state.paso === 2) {
      html += renderPasoFecha();
    } else if (state.paso === 3) {
      html += renderPasoDatos();
    } else if (state.paso === 4) {
      html += renderPasoConfirmar();
    } else if (state.paso === 5) {
      html += renderExito();
    }

    html += `</div></div></div>`;
    el.innerHTML = html;
    bindEvents();
  }

  function renderPasoServicios() {
    if (!state.servicios.length) {
      return `<p style="color:#888;text-align:center">No hay servicios disponibles.</p>`;
    }
    let h = `<p class="frw-sec-title">¿Qué servicio deseas?</p>
             <div class="frw-svc-list">`;
    state.servicios.forEach(svc => {
      const sel = state.servicioSel && state.servicioSel.id === svc.id ? 'sel' : '';
      const dur = svc.duracion_minutos || 60;
      const precio = svc.precio ? `${Number(svc.precio).toFixed(2)} €` : 'Consultar';
      h += `<div class="frw-svc ${sel}" data-svc="${svc.id}">
        <div class="frw-svc-name">${svc.nombre}</div>
        ${svc.descripcion ? `<div style="font-size:.82rem;color:#666;margin-bottom:6px">${svc.descripcion}</div>` : ''}
        <div class="frw-svc-meta">
          <span>⏱ ${dur} min</span>
          <span class="frw-svc-precio">${precio}</span>
        </div>
      </div>`;
    });
    h += `</div>`;
    h += `<div class="frw-btns">
      <div></div>
      <button class="frw-btn frw-btn-primary" id="frw-sig1"
        ${state.servicioSel ? '' : 'disabled'}>Siguiente →</button>
    </div>`;
    return h;
  }

  function renderPasoFecha() {
    const dias14 = proximosDias(14);
    let h = `<p class="frw-sec-title">Elige el día</p>
             <div class="frw-dias">`;
    dias14.forEach(d => {
      const sel = state.fechaSel && d.toDateString() === state.fechaSel.toDateString() ? 'sel' : '';
      h += `<div class="frw-dia ${sel}" data-fecha="${d.toISOString()}">
        <div class="frw-dia-nombre">${dias[d.getDay()]}</div>
        <div class="frw-dia-num">${d.getDate()}</div>
        <div class="frw-dia-nombre">${meses[d.getMonth()].slice(0,3)}</div>
      </div>`;
    });
    h += `</div>`;

    if (state.fechaSel) {
      const durMin = state.servicioSel ? (state.servicioSel.duracion_minutos || 60) : 60;
      const slots = generarSlots(durMin);
      h += `<p class="frw-sec-title">Elige la hora</p>
            <div class="frw-horas">`;
      slots.forEach(slot => {
        const ocup = slotOcupado(state.fechaSel, slot, durMin);
        const sel = state.horaSel === slot ? 'sel' : '';
        h += `<div class="frw-hora ${sel} ${ocup ? 'ocupado' : ''}" data-hora="${slot}">${slot}</div>`;
      });
      h += `</div>`;
    } else {
      h += `<p style="color:#aaa;font-size:.88rem">Selecciona un día para ver los horarios disponibles.</p>`;
    }

    h += `<div class="frw-btns">
      <button class="frw-btn frw-btn-sec" id="frw-ant2">← Atrás</button>
      <button class="frw-btn frw-btn-primary" id="frw-sig2"
        ${state.fechaSel && state.horaSel ? '' : 'disabled'}>Siguiente →</button>
    </div>`;
    return h;
  }

  function renderPasoDatos() {
    let h = `<p class="frw-sec-title">Tus datos de contacto</p>`;
    h += `<div class="frw-field">
      <label>Nombre completo *</label>
      <input type="text" id="frw-nombre" placeholder="Tu nombre" value="${escHtml(state.nombre)}" required>
    </div>
    <div class="frw-field">
      <label>Teléfono *</label>
      <input type="tel" id="frw-tel" placeholder="600 000 000" value="${escHtml(state.telefono)}" required>
    </div>
    <div class="frw-field">
      <label>Email (opcional)</label>
      <input type="email" id="frw-email" placeholder="tu@email.com" value="${escHtml(state.correo)}">
    </div>
    <div class="frw-field">
      <label>Notas para el establecimiento</label>
      <textarea id="frw-notas" placeholder="Comentarios, preferencias…">${escHtml(state.notas)}</textarea>
    </div>`;

    h += `<div class="frw-btns">
      <button class="frw-btn frw-btn-sec" id="frw-ant3">← Atrás</button>
      <button class="frw-btn frw-btn-primary" id="frw-sig3">Revisar reserva →</button>
    </div>`;
    return h;
  }

  function renderPasoConfirmar() {
    const svc = state.servicioSel;
    const durMin = svc ? (svc.duracion_minutos || 60) : 60;
    const precioStr = svc && svc.precio ? `${Number(svc.precio).toFixed(2)} €` : '—';

    let h = `<p class="frw-sec-title">Resumen de tu reserva</p>
    <div class="frw-resumen">
      <div class="frw-resumen-row">
        <span class="frw-resumen-label">Servicio</span>
        <span class="frw-resumen-val">${svc ? escHtml(svc.nombre) : '—'}</span>
      </div>
      <div class="frw-resumen-row">
        <span class="frw-resumen-label">Día</span>
        <span class="frw-resumen-val">${state.fechaSel ? formatFecha(state.fechaSel) : '—'}</span>
      </div>
      <div class="frw-resumen-row">
        <span class="frw-resumen-label">Hora</span>
        <span class="frw-resumen-val">${state.horaSel || '—'}</span>
      </div>
      <div class="frw-resumen-row">
        <span class="frw-resumen-label">Duración</span>
        <span class="frw-resumen-val">${durMin} min</span>
      </div>
      <div class="frw-resumen-row">
        <span class="frw-resumen-label">Precio</span>
        <span class="frw-resumen-val" style="color:${cfg.color}">${precioStr}</span>
      </div>
      <div class="frw-resumen-row">
        <span class="frw-resumen-label">Nombre</span>
        <span class="frw-resumen-val">${escHtml(state.nombre)}</span>
      </div>
      <div class="frw-resumen-row">
        <span class="frw-resumen-label">Teléfono</span>
        <span class="frw-resumen-val">${escHtml(state.telefono)}</span>
      </div>
    </div>

    <p style="font-size:.82rem;color:#888;margin-bottom:18px">
      Tu reserva quedará en estado <strong>pendiente</strong> hasta que el establecimiento la confirme.
      Te contactaremos por teléfono si hay algún cambio.
    </p>`;

    h += `<div class="frw-btns">
      <button class="frw-btn frw-btn-sec" id="frw-ant4">← Editar</button>
      <button class="frw-btn frw-btn-primary" id="frw-confirmar">✓ Confirmar reserva</button>
    </div>`;
    return h;
  }

  function renderExito() {
    return `<div class="frw-success">
      <div class="frw-success-icon">🎉</div>
      <h3>¡Reserva enviada!</h3>
      <p>Tu solicitud ha sido registrada. El establecimiento la revisará y recibirás confirmación por teléfono.</p>
      <div class="frw-resumen" style="text-align:left;max-width:280px;margin:0 auto 20px">
        <div class="frw-resumen-row">
          <span class="frw-resumen-label">Servicio</span>
          <span class="frw-resumen-val">${escHtml(state.servicioSel?.nombre || '')}</span>
        </div>
        <div class="frw-resumen-row">
          <span class="frw-resumen-label">Día</span>
          <span class="frw-resumen-val">${state.fechaSel ? formatFecha(state.fechaSel) : ''}</span>
        </div>
        <div class="frw-resumen-row">
          <span class="frw-resumen-label">Hora</span>
          <span class="frw-resumen-val">${state.horaSel}</span>
        </div>
      </div>
      <button class="frw-btn frw-btn-sec" id="frw-nueva" style="max-width:220px;margin:0 auto">
        Hacer otra reserva
      </button>
    </div>`;
  }

  function escHtml(s) {
    if (!s) return '';
    return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  }

  // ── Eventos ───────────────────────────────────────────────────────────────
  function bindEvents() {
    // Paso 1 — seleccionar servicio
    document.querySelectorAll('.frw-svc').forEach(el => {
      el.addEventListener('click', () => {
        const id = el.dataset.svc;
        state.servicioSel = state.servicios.find(s => s.id === id) || null;
        state.horaSel = null; // reset hora si cambia servicio
        render();
      });
    });
    on('frw-sig1', 'click', () => { if (state.servicioSel) nextPaso(); });

    // Paso 2 — seleccionar día y hora
    document.querySelectorAll('.frw-dia').forEach(el => {
      el.addEventListener('click', () => {
        state.fechaSel = new Date(el.dataset.fecha);
        state.horaSel = null;
        cargarReservasDelDia();
      });
    });
    document.querySelectorAll('.frw-hora:not(.ocupado)').forEach(el => {
      el.addEventListener('click', () => {
        state.horaSel = el.dataset.hora;
        render();
      });
    });
    on('frw-ant2', 'click', () => prevPaso());
    on('frw-sig2', 'click', () => { if (state.fechaSel && state.horaSel) nextPaso(); });

    // Paso 3 — datos del cliente
    on('frw-nombre', 'input', e => { state.nombre = e.target.value; });
    on('frw-tel',    'input', e => { state.telefono = e.target.value; });
    on('frw-email',  'input', e => { state.correo = e.target.value; });
    on('frw-notas',  'input', e => { state.notas = e.target.value; });
    on('frw-ant3', 'click', () => prevPaso());
    on('frw-sig3', 'click', () => {
      state.nombre = val('frw-nombre');
      state.telefono = val('frw-tel');
      state.correo = val('frw-email');
      state.notas = val('frw-notas');

      if (!state.nombre.trim()) { alert('Por favor, introduce tu nombre.'); return; }
      if (!state.telefono.trim()) { alert('Por favor, introduce tu teléfono.'); return; }
      nextPaso();
    });

    // Paso 4 — confirmar
    on('frw-ant4', 'click', () => prevPaso());
    on('frw-confirmar', 'click', crearReserva);

    // Éxito
    on('frw-nueva', 'click', () => {
      Object.assign(state, {
        paso: 1, servicioSel: null, fechaSel: null, horaSel: null,
        nombre: '', telefono: '', correo: '', notas: '',
        error: null, cargando: false, idReserva: null,
      });
      render();
    });
  }

  function on(id, ev, fn) {
    const el = document.getElementById(id);
    if (el) el.addEventListener(ev, fn);
  }

  function val(id) {
    const el = document.getElementById(id);
    return el ? el.value : '';
  }

  function nextPaso() { state.paso++; state.error = null; render(); }
  function prevPaso() { state.paso--; state.error = null; render(); }

  // ── Firebase ──────────────────────────────────────────────────────────────
  async function loadFirebase() {
    // Carga los módulos de Firebase como scripts de módulo si no están ya
    const scripts = [
      FIREBASE_CDN + 'firebase-app.js',
      FIREBASE_CDN + 'firebase-firestore.js',
    ];
    for (const src of scripts) {
      if (!document.querySelector(`script[src="${src}"]`)) {
        await new Promise((res, rej) => {
          const s = document.createElement('script');
          s.src = src; s.onload = res; s.onerror = rej;
          document.head.appendChild(s);
        });
      }
    }
  }

  async function initFirebase() {
    // Obtener config desde Firestore público de la empresa
    // Usamos la REST API de Firestore para no requerir auth
    const url = `https://firestore.googleapis.com/v1/projects/planeaapp-4bea4/databases/(default)/documents/empresas/${cfg.empresaId}?fields=firebase_config,nombre`;
    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error('No se pudo conectar');
      // Usamos el SDK global si está disponible (inyectado por el host)
      // o la REST API directamente
      db = { empresaId: cfg.empresaId };
    } catch (e) {
      // Fallback: usar REST API directamente
      db = { empresaId: cfg.empresaId };
    }
  }

  // ── REST API Firestore (sin SDK) ─────────────────────────────────────────
  const PROJECT_ID = 'planeaapp-4bea4';
  const FS_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

  async function fsGet(path) {
    const r = await fetch(`${FS_BASE}/${path}`);
    if (!r.ok) throw new Error(`Firestore GET error: ${r.status}`);
    return r.json();
  }

  async function fsQuery(colPath, filters) {
    const body = {
      structuredQuery: {
        from: [{ collectionId: colPath.split('/').pop() }],
        where: filters.length === 1 ? filters[0] : {
          compositeFilter: { op: 'AND', filters }
        },
        orderBy: [{ field: { fieldPath: 'fecha_hora' }, direction: 'ASCENDING' }],
        limit: 200,
      }
    };
    const parentPath = colPath.split('/').slice(0, -1).join('/');
    const r = await fetch(
      `${FS_BASE}/${parentPath}:runQuery`,
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }
    );
    if (!r.ok) throw new Error(`Firestore query error: ${r.status}`);
    return r.json();
  }

  async function fsCreate(colPath, data) {
    const fsData = toFirestoreFields(data);
    const r = await fetch(`${FS_BASE}/${colPath}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fields: fsData })
    });
    if (!r.ok) {
      const txt = await r.text();
      throw new Error(`Firestore create error: ${r.status} - ${txt}`);
    }
    return r.json();
  }

  function toFirestoreFields(obj) {
    const out = {};
    for (const [k, v] of Object.entries(obj)) {
      if (v === null || v === undefined) out[k] = { nullValue: null };
      else if (typeof v === 'boolean') out[k] = { booleanValue: v };
      else if (typeof v === 'number') out[k] = { doubleValue: v };
      else if (typeof v === 'string') out[k] = { stringValue: v };
      else if (v instanceof Date) out[k] = { timestampValue: v.toISOString() };
      else if (Array.isArray(v)) out[k] = { arrayValue: { values: v.map(i => toFirestoreValue(i)) } };
      else out[k] = { stringValue: String(v) };
    }
    return out;
  }

  function toFirestoreValue(v) {
    if (v === null || v === undefined) return { nullValue: null };
    if (typeof v === 'boolean') return { booleanValue: v };
    if (typeof v === 'number') return { doubleValue: v };
    return { stringValue: String(v) };
  }

  function fromFirestoreDoc(doc) {
    if (!doc || !doc.fields) return null;
    const out = { id: doc.name.split('/').pop() };
    for (const [k, v] of Object.entries(doc.fields)) {
      if ('stringValue' in v) out[k] = v.stringValue;
      else if ('integerValue' in v) out[k] = Number(v.integerValue);
      else if ('doubleValue' in v) out[k] = v.doubleValue;
      else if ('booleanValue' in v) out[k] = v.booleanValue;
      else if ('timestampValue' in v) out[k] = v.timestampValue;
      else if ('nullValue' in v) out[k] = null;
      else if ('arrayValue' in v) out[k] = (v.arrayValue.values || []).map(i => {
        if ('stringValue' in i) return i.stringValue;
        if ('integerValue' in i) return Number(i.integerValue);
        if ('doubleValue' in i) return i.doubleValue;
        if ('booleanValue' in i) return i.booleanValue;
        return null;
      });
    }
    return out;
  }

  // ── Carga de datos ────────────────────────────────────────────────────────
  async function cargarServicios() {
    if (!cfg.empresaId) {
      state.error = 'Widget no configurado: falta empresaId.';
      render();
      return;
    }
    state.cargando = true;
    render();

    try {
      const colPath = `empresas/${cfg.empresaId}/servicios`;
      const r = await fetch(`${FS_BASE}/${colPath}?pageSize=50`);
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      const data = await r.json();
      const docs = data.documents || [];
      state.servicios = docs
        .map(fromFirestoreDoc)
        .filter(s => s && s.activo !== false)
        .sort((a, b) => (a.nombre || '').localeCompare(b.nombre || ''));
    } catch (e) {
      state.error = 'No se pudieron cargar los servicios. Inténtalo de nuevo.';
      console.error('[FluixReservas]', e);
    }

    state.cargando = false;
    render();
  }

  async function cargarReservasDelDia() {
    if (!state.fechaSel) return;
    state.cargando = true;
    render();

    try {
      const diaInicio = new Date(state.fechaSel);
      diaInicio.setHours(0, 0, 0, 0);
      const diaFin = new Date(diaInicio);
      diaFin.setDate(diaFin.getDate() + 1);

      // Consulta simple por colección (sin filtros complejos — todos los del día)
      const r = await fetch(
        `${FS_BASE}/empresas/${cfg.empresaId}/reservas?pageSize=100`
      );
      if (!r.ok) throw new Error(`HTTP ${r.status}`);
      const data = await r.json();
      const docs = data.documents || [];

      state.reservasOcupadas = docs
        .map(fromFirestoreDoc)
        .filter(rv => {
          if (!rv || !rv.fecha_hora) return false;
          if (rv.estado === 'cancelada') return false;
          const t = new Date(rv.fecha_hora).getTime();
          return t >= diaInicio.getTime() && t < diaFin.getTime();
        });
    } catch (e) {
      state.reservasOcupadas = [];
      console.warn('[FluixReservas] No se pudieron cargar reservas:', e);
    }

    state.cargando = false;
    render();
  }

  async function crearReserva() {
    state.cargando = true;
    state.error = null;
    render();

    try {
      const svc = state.servicioSel;
      const durMin = svc ? (svc.duracion_minutos || 60) : 60;
      const fechaHoraStr = isoFechaHora(state.fechaSel, state.horaSel);

      // 1. Buscar o crear cliente por teléfono
      let clienteId = '';
      try {
        const rClientes = await fetch(`${FS_BASE}/empresas/${cfg.empresaId}/clientes?pageSize=200`);
        if (rClientes.ok) {
          const cData = await rClientes.json();
          const clientes = (cData.documents || []).map(fromFirestoreDoc);
          const existing = clientes.find(c => c && c.telefono === state.telefono.trim());
          if (existing) {
            clienteId = existing.id;
          } else {
            // Crear cliente nuevo
            const nuevoCliente = await fsCreate(
              `empresas/${cfg.empresaId}/clientes`,
              {
                nombre: state.nombre.trim(),
                telefono: state.telefono.trim(),
                correo: state.correo.trim(),
                activo: true,
                fecha_creacion: new Date().toISOString(),
                origen: 'web_widget',
              }
            );
            clienteId = nuevoCliente.name.split('/').pop();
          }
        }
      } catch (eCliente) {
        console.warn('[FluixReservas] No se pudo crear/buscar cliente:', eCliente);
      }

      // 2. Crear la reserva
      await fsCreate(
        `empresas/${cfg.empresaId}/reservas`,
        {
          cliente_id: clienteId,
          servicio_id: svc ? svc.id : '',
          estado: 'pendiente',
          fecha_hora: fechaHoraStr,
          duracion_minutos: durMin,
          precio: svc ? (svc.precio || 0) : 0,
          notas: state.notas.trim(),
          notas_internas: '',
          fecha_creacion: new Date().toISOString(),
          creado_por: 'web_widget',
          // Campos extra para identificación rápida desde la app
          nombre_cliente_web: state.nombre.trim(),
          telefono_cliente_web: state.telefono.trim(),
          correo_cliente_web: state.correo.trim(),
        }
      );

      state.paso = 5; // Éxito
    } catch (e) {
      state.error = 'No se pudo crear la reserva. Por favor, llámanos directamente.';
      console.error('[FluixReservas]', e);
    }

    state.cargando = false;
    render();
  }

  // ── Init ──────────────────────────────────────────────────────────────────
  function init() {
    injectStyles();
    render();
    cargarServicios();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();


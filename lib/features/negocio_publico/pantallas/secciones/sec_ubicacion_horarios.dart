part of '../modulo_app_screen.dart';

extension _SecUbicacionHorarios on _ModuloAppScreenState {

  // ── UBICACIÓN ──────────────────────────────────────────────────────────────
  Widget _buildUbicacion() => Column(children: [
    _Seccion(icono: Icons.location_on_outlined, titulo: 'Dirección',
      child: Column(children: [
        Row(children: [
          Expanded(flex: 3, child: _InputIcon(ctrl: _calleCtrl,
              icon: Icons.signpost_outlined, label: 'Calle', hint: 'Calle Mayor')),
          const SizedBox(width: 10),
          Expanded(child: _InputIcon(ctrl: _numCtrl,
              icon: Icons.numbers_rounded, label: 'Nº', hint: '12')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _InputIcon(ctrl: _cpCtrl,
              icon: Icons.local_post_office_outlined, label: 'C.P.', hint: '28001')),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: _InputIcon(ctrl: _localidadCtrl,
              icon: Icons.location_city_outlined, label: 'Localidad', hint: 'Madrid')),
        ]),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _provinciaCtrl, icon: Icons.map_outlined, label: 'Provincia', hint: 'Madrid'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _indicacionesCtrl, icon: Icons.directions_outlined,
            label: 'Indicaciones para llegar', hint: 'Junto al metro Sol, 2ª planta…'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text('Mostrar dirección en el perfil público',
              style: TextStyle(color: _kTexto, fontSize: 13))),
          Switch(value: _mostrarDireccion,
              onChanged: (v) => setState(() => _mostrarDireccion = v),
              activeColor: _kAccent,
              activeTrackColor: _kAccent.withValues(alpha: 0.25),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ]),
      ])),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.gps_fixed_rounded, titulo: 'Coordenadas GPS',
      subtitulo: 'Para mostrar el mapa exacto al cliente',
      child: Column(children: [
        Row(children: [
          Expanded(child: _InputIcon(ctrl: _latCtrl,
              icon: Icons.north_rounded, label: 'Latitud', hint: '40.4168')),
          const SizedBox(width: 10),
          Expanded(child: _InputIcon(ctrl: _lngCtrl,
              icon: Icons.east_rounded, label: 'Longitud', hint: '-3.7038')),
        ]),
        const SizedBox(height: 8),
        Text('Tip: busca tu negocio en Google Maps → clic derecho → copia las coordenadas',
            style: TextStyle(color: _kMuted, fontSize: 11)),
      ])),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.radar_rounded, titulo: 'Zona de servicio',
      child: _InputIcon(ctrl: _zonaServicioCtrl, icon: Icons.circle_outlined,
          label: 'Zona / radio de atención', hint: 'Ej: Madrid centro, hasta 20 km…')),
  ]);

  // ── HORARIOS COMPLETO ──────────────────────────────────────────────────────
  Widget _buildHorariosCompleto() => Column(children: [
    _buildHorarios(),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.tune_rounded, titulo: 'Configuración avanzada',
      child: Column(children: [
        _buildSwRow('Turnos partidos (mañana y tarde)', _turnosPartidos,
            (v) => setState(() => _turnosPartidos = v)),
        const SizedBox(height: 8),
        _buildSwRow('Atención con cita previa', _atencionConCita,
            (v) => setState(() => _atencionConCita = v)),
        const SizedBox(height: 8),
        _buildSwRow('Atención sin cita previa', _atencionSinCita,
            (v) => setState(() => _atencionSinCita = v)),
        const SizedBox(height: 12),
        _InputIcon(ctrl: _ultimaHoraCtrl, icon: Icons.last_page_rounded,
            label: 'Última hora de admisión', hint: 'Ej: 19:30'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _zonaHorariaCtrl, icon: Icons.public_rounded,
            label: 'Zona horaria', hint: 'Europe/Madrid'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _cierreTemporalCtrl, icon: Icons.event_busy_outlined,
            label: 'Cierre temporal hasta', hint: 'Ej: 15/08/2026 – vacaciones'),
      ])),
  ]);

  Widget _buildSwRow(String label, bool value, ValueChanged<bool> onChanged) =>
      Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: _kTexto, fontSize: 13))),
        Switch(value: value, onChanged: onChanged, activeColor: _kAccent,
            activeTrackColor: _kAccent.withValues(alpha: 0.25),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]);
}

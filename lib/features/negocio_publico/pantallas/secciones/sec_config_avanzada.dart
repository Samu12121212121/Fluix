part of '../modulo_app_screen.dart';

extension _SecConfigAvanzada on _ModuloAppScreenState {

  // ── RESERVAS ────────────────────────────────────────────────────────────────
  Widget _buildReservasConfig() => Column(children: [
    _Seccion(icono: Icons.toggle_on_outlined, titulo: 'Activación',
      child: Column(children: [
        _buildSwOpt('Activar reservas online', _reservasOnlineActivas, (v) => setState(() => _reservasOnlineActivas = v)),
        const SizedBox(height: 8),
        _buildSwOpt('Mostrar agenda de disponibilidad', _mostrarAgenda, (v) => setState(() => _mostrarAgenda = v)),
        const SizedBox(height: 8),
        _buildSwOpt('Reservar sin registro', _reservarSinRegistro, (v) => setState(() => _reservarSinRegistro = v)),
        const SizedBox(height: 8),
        _buildSwOpt('Lista de espera', _listaEspera, (v) => setState(() => _listaEspera = v)),
        const SizedBox(height: 8),
        _buildSwOpt('Pago anticipado obligatorio', _pagosAnticipados, (v) => setState(() => _pagosAnticipados = v)),
      ])),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.timer_outlined, titulo: 'Antelación para reservar',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Mínimo: $_antelacionMin horas', style: TextStyle(color: _kMuted, fontSize: 12)),
        Slider(value: _antelacionMin.toDouble(), min: 0, max: 72, divisions: 72,
            activeColor: _kAccent, label: '${_antelacionMin}h',
            onChanged: (v) => setState(() => _antelacionMin = v.round())),
        Text('Máximo: $_antelacionMax días', style: TextStyle(color: _kMuted, fontSize: 12)),
        Slider(value: _antelacionMax.toDouble(), min: 1, max: 365, divisions: 36,
            activeColor: _kAccent, label: '${_antelacionMax}d',
            onChanged: (v) => setState(() => _antelacionMax = v.round())),
      ])),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.text_fields_rounded, titulo: 'Textos',
      child: Column(children: [
        _InputIcon(ctrl: _textoBotonCtrl,   icon: Icons.smart_button_outlined, label: 'Texto del botón', hint: 'Reservar cita'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _instrReservaCtrl, icon: Icons.info_outline_rounded,  label: 'Instrucciones',   hint: 'Llega 5 min antes…'),
        const SizedBox(height: 16),
        ..._campos.asMap().entries.map((e) {
          final c = e.value;
          return Container(margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kBorde, width: 0.5)),
            child: Row(children: [
              Icon(_iconTipoCampo(c.tipo), color: _kAccent, size: 18), const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.label, style: TextStyle(color: _kTexto, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${c.tipo} · ${c.obligatorio ? "obligatorio" : "opcional"}', style: TextStyle(color: _kMuted, fontSize: 11)),
              ])),
              IconButton(icon: Icon(Icons.edit_outlined, color: _kAccent, size: 18), onPressed: () async {
                final r = await showDialog<CampoPersonalizado>(context: context, builder: (_) => _DialogoCampo(campo: c));
                if (r != null) setState(() => _campos[e.key] = r);
              }),
              IconButton(icon: Icon(Icons.delete_outline, color: _kRosa, size: 18),
                  onPressed: () => setState(() => _campos.removeAt(e.key))),
            ]));
        }),
        FilledButton.icon(
          onPressed: () async {
            final r = await showDialog<CampoPersonalizado>(context: context, builder: (_) => const _DialogoCampo());
            if (r != null) setState(() => _campos.add(r));
          },
          icon: const Icon(Icons.add, size: 18), label: const Text('Añadir campo'),
          style: FilledButton.styleFrom(backgroundColor: _kRosa, foregroundColor: _kBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        ),
      ])),
  ]);

  // ── PROFESIONALES ───────────────────────────────────────────────────────────
  Widget _buildProfesionales() => Column(children: [
    _Seccion(icono: Icons.people_outline, titulo: 'Configuración del equipo',
      child: Column(children: [
        _buildSwOpt('Mostrar sección del equipo', _mostrarEquipo, (v) => setState(() => _mostrarEquipo = v)),
        const SizedBox(height: 8),
        _buildSwOpt('Permitir elegir profesional al reservar', _permitirElegirProfesional, (v) => setState(() => _permitirElegirProfesional = v)),
      ])),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.badge_outlined, titulo: 'Perfiles del equipo',
      subtitulo: 'Los profesionales se gestionan desde el módulo Empleados',
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.people_alt_outlined, color: _kMuted, size: 32), const SizedBox(height: 8),
          Text('Ve a Empleados → edita cada perfil\npara configurar su visibilidad pública',
              style: TextStyle(color: _kMuted, fontSize: 12), textAlign: TextAlign.center),
        ])))),
  ]);

  // ── RESEÑAS CONFIG ──────────────────────────────────────────────────────────
  Widget _buildResenasConfig() => Column(children: [
    _Seccion(icono: Icons.star_outline_rounded, titulo: 'Configuración de reseñas',
      child: Column(children: [
        _buildSwOpt('Mostrar reseñas de Google',      _mostrarResenasGoogle, (v) => setState(() => _mostrarResenasGoogle = v)),
        const SizedBox(height: 8),
        _buildSwOpt('Mostrar reseñas de Fluix',       _mostrarResenasFluix,  (v) => setState(() => _mostrarResenasFluix  = v)),
        const SizedBox(height: 8),
        _buildSwOpt('Permitir que los clientes reseñen', _permitirResenas,   (v) => setState(() => _permitirResenas       = v)),
      ])),
    const SizedBox(height: 16),
    _buildTabResenas(),
  ]);

  // ── POLÍTICAS ───────────────────────────────────────────────────────────────
  Widget _buildPoliticas() => Column(children: [
    _buildTerminos(),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.cancel_outlined, titulo: 'Cancelaciones y retrasos',
      child: _TextAreaLocal('Ej: Cancelaciones con menos de 24h no tienen reembolso…')),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.assignment_return_outlined, titulo: 'Devoluciones',
      child: _TextAreaLocal('Ej: Aceptamos devoluciones en 14 días con ticket…')),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.accessible_rounded, titulo: 'Normas del local',
      child: _TextAreaLocal('Ej: Local accesible. No admitimos menores de 16 años sin adulto…')),
  ]);

  Widget _TextAreaLocal(String hint) => TextField(maxLines: 4,
      style: TextStyle(color: _kTexto, fontSize: 13),
      decoration: _dec(hint));

  // ── PAGOS ───────────────────────────────────────────────────────────────────
  Widget _buildPagos() => Column(children: [
    _Seccion(icono: Icons.receipt_long_outlined, titulo: 'Identificación fiscal',
      child: Column(children: [
        _InputIcon(ctrl: _razonSocialCtrl, icon: Icons.business_outlined,    label: 'Razón social', hint: 'Ej: Peluquería Lucía S.L.'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _nifCifCtrl,      icon: Icons.numbers_rounded,      label: 'NIF / CIF',    hint: 'B12345678'),
        const SizedBox(height: 12),
        _buildSwOpt('Factura disponible',              _facturaDisponible,    (v) => setState(() => _facturaDisponible    = v)),
        const SizedBox(height: 8),
        _buildSwOpt('Precios con IVA incluido',        _preciosConImpuestos,  (v) => setState(() => _preciosConImpuestos  = v)),
        const SizedBox(height: 8),
        _buildSwOpt('Aceptar pagos online',            _pagosOnline,          (v) => setState(() => _pagosOnline          = v)),
      ])),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.payments_outlined, titulo: 'Métodos de pago',
      child: _buildChipListField('Métodos de pago', _metodosPago,
          (v) => setState(() => _metodosPago.add(v)),
          (v) => setState(() => _metodosPago.remove(v)),
          sugerencias: ['Efectivo','Tarjeta','Bizum','PayPal','Transferencia','Apple Pay','Google Pay','Financiación'])),
  ]);

  // ── DISEÑO ──────────────────────────────────────────────────────────────────
  Widget _buildDiseno() => Column(children: [
    _Seccion(icono: Icons.palette_outlined, titulo: 'Colores de marca',
      child: Column(children: [
        _InputIcon(ctrl: _colorPrincipalCtrl,  icon: Icons.circle_rounded,  label: 'Color principal (hex)',  hint: '#00BFA5'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _colorSecundarioCtrl, icon: Icons.circle_outlined, label: 'Color secundario (hex)', hint: '#E91E63'),
      ])),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.text_snippet_outlined, titulo: 'Textos destacados',
      child: Column(children: [
        _InputIcon(ctrl: _textoBienvenidaCtrl, icon: Icons.waving_hand_outlined, label: 'Texto de bienvenida',   hint: '¡Bienvenido a nuestra peluquería!'),
        const SizedBox(height: 10),
        _InputIcon(ctrl: _msgPromoCtrl,        icon: Icons.local_offer_outlined,  label: 'Mensaje promocional', hint: 'Esta semana 20% en todos los servicios'),
      ])),
    const SizedBox(height: 16),
    _Seccion(icono: Icons.dark_mode_outlined, titulo: 'Tema de la app',
      child: _buildSwOpt('Modo oscuro', AppSettings.darkMode.value, (v) { AppSettings.darkMode.value = v; setState(() {}); })),
  ]);

  // ── SEO ─────────────────────────────────────────────────────────────────────
  Widget _buildSeo() => _Seccion(
    icono: Icons.search_rounded, titulo: 'SEO y visibilidad en buscadores',
    child: Column(children: [
      _InputIcon(ctrl: _urlPublicaCtrl, icon: Icons.link_rounded,       label: 'URL pública',        hint: 'peluqueria-lucia'),
      const SizedBox(height: 10),
      _InputIcon(ctrl: _tituloSeoCtrl,  icon: Icons.title_rounded,       label: 'Título SEO',         hint: 'Peluquería Lucía – Madrid'),
      const SizedBox(height: 10),
      _InputIcon(ctrl: _descSeoCtrl,    icon: Icons.description_outlined, label: 'Descripción SEO',    hint: 'Peluquería profesional en Madrid centro…'),
      const SizedBox(height: 12),
      _buildChipListField('Palabras clave', _palabrasClave,
          (v) => setState(() => _palabrasClave.add(v)),
          (v) => setState(() => _palabrasClave.remove(v)),
          sugerencias: ['peluquería','corte de pelo','tinte','belleza','spa','barber']),
      const SizedBox(height: 12),
      _buildSwOpt('Aparecer en resultados de Fluix',        _aparecerEnResultados,  (v) => setState(() => _aparecerEnResultados  = v)),
      const SizedBox(height: 8),
      _buildSwOpt('Permitir indexación en buscadores externos', _indexarExternamente, (v) => setState(() => _indexarExternamente = v)),
    ]),
  );

  // ── VISIBILIDAD ─────────────────────────────────────────────────────────────
  Widget _buildVisibilidad() => _Seccion(
    icono: Icons.visibility_outlined, titulo: 'Visibilidad de secciones',
    subtitulo: 'Elige qué ve el cliente en tu perfil',
    child: Column(children: _visItems.map((s) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Expanded(child: Text(s.$2, style: TextStyle(color: _kTexto, fontSize: 13))),
        Switch(value: _seccionesVisibles[s.$1] ?? true,
            onChanged: (v) => setState(() => _seccionesVisibles[s.$1] = v),
            activeColor: _kAccent,
            activeTrackColor: _kAccent.withValues(alpha: 0.25),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]),
    )).toList()),
  );

  static const _visItems = [
    ('descripcion',   'Descripción'), ('contacto',    'Contacto'),
    ('horarios',      'Horarios'),    ('ubicacion',   'Ubicación'),
    ('servicios',     'Servicios'),   ('reservas',    'Reservas / Agenda'),
    ('profesionales', 'Profesionales'), ('resenas_google', 'Reseñas Google'),
    ('resenas_fluix', 'Reseñas Fluix'), ('galeria',   'Galería'),
    ('promociones',   'Promociones'), ('politicas',   'Políticas'),
  ];

  // ── ESTADÍSTICAS ────────────────────────────────────────────────────────────
  Widget _buildEstadisticas() {
    if (_negocioId == null) {
      return _Seccion(icono: Icons.bar_chart_rounded, titulo: 'Estadísticas',
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(child: Text('Activa tu perfil público para ver métricas', style: TextStyle(color: _kMuted, fontSize: 13)))));
    }
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('negocios_publicos').doc(_negocioId).snapshots(),
      builder: (_, snap) {
        final d = (snap.data?.data() as Map<String, dynamic>?) ?? {};
        final s = d['stats'] as Map<String, dynamic>? ?? {};
        return GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.0,
          children: [
            _statTile('Visitas al perfil',  s['visitas']?.toString() ?? '0',         Icons.visibility_outlined,     _kAccent),
            _statTile('Clics Reservar',     s['clics_reservar']?.toString() ?? '0',  Icons.calendar_today_rounded,  const Color(0xFF3B82F6)),
            _statTile('Clics Teléfono',     s['clics_telefono']?.toString() ?? '0',  Icons.phone_outlined,           const Color(0xFF27AE60)),
            _statTile('Clics WhatsApp',     s['clics_whatsapp']?.toString() ?? '0',  Icons.chat_outlined,            const Color(0xFF25D366)),
            _statTile('Visitas Galería',    s['visitas_galeria']?.toString() ?? '0', Icons.photo_library_outlined,   _kRosa),
            _statTile('Cómo llegar',        s['clics_como_llegar']?.toString() ?? '0', Icons.directions_outlined,   _kOro),
          ],
        );
      },
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorde, width: 0.5)),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16)),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(value, style: TextStyle(color: _kTexto, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: _kMuted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';
import 'pantalla_integracion_script.dart';
import 'tab_seo_web.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB CONFIGURACIÓN WEB — Diseño tipo panel de ajustes profesional
// ═════════════════════════════════════════════════════════════════════════════

class TabConfigWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;
  const TabConfigWeb({super.key, required this.empresaId, required this.svc});

  @override
  State<TabConfigWeb> createState() => _TabConfigWebState();
}

class _TabConfigWebState extends State<TabConfigWeb> {
  bool _cargado    = false;
  bool _guardando  = false;
  bool _hasChanges = false;
  String _categoria = 'seo';
  DateTime? _ultimaGuardado;

  // ── Dominio ───────────────────────────────────────────────────────────────
  final _dominioCtrl = TextEditingController();
  String? _dominioStatus;
  bool _verificando = false;
  bool _scriptCopiado = false; // true cuando el usuario ha copiado el script al menos una vez

  // ── Contacto ──────────────────────────────────────────────────────────────
  bool _contactoActivo   = false;
  bool _contactoAutoResp = false;
  final _contactoEmailCtrl    = TextEditingController();
  final _contactoWaCtrl       = TextEditingController();
  final _contactoTituloCtrl   = TextEditingController();
  final _contactoAutoRespCtrl = TextEditingController();

  // ── Popup ─────────────────────────────────────────────────────────────────
  bool   _popupActivo     = false;
  bool   _popupExitIntent = false;
  int    _popupRetraso    = 5;
  int    _popupFrecuencia = 0;
  String _popupDispositivo = 'todos';
  final _popupTituloCtrl   = TextEditingController();
  final _popupTextoCtrl    = TextEditingController();
  final _popupBtnTextoCtrl = TextEditingController();
  final _popupBtnUrlCtrl   = TextEditingController();

  // ── Banner ────────────────────────────────────────────────────────────────
  bool   _bannerActivo = false;
  String _bannerColor  = '#1976D2';
  final _bannerTextoCtrl = TextEditingController();
  final _bannerUrlCtrl   = TextEditingController();

  // ── GDPR ──────────────────────────────────────────────────────────────────
  bool _gdprActivo    = false;
  bool _gdprAnalitica = false;
  bool _gdprMarketing = false;
  final _gdprTextoCtrl    = TextEditingController();
  final _gdprPoliticaCtrl = TextEditingController();

  // ── WhatsApp ──────────────────────────────────────────────────────────────
  bool _waActivo = false;
  final _waNumeroCtrl         = TextEditingController();
  final _waMensajeCtrl        = TextEditingController();
  final _waHorarioInicioCtrl  = TextEditingController();
  final _waHorarioFinCtrl     = TextEditingController();
  final _waFueraHorarioCtrl   = TextEditingController();

  // ── Reservas ──────────────────────────────────────────────────────────────
  bool _reservasActivo = true;
  int  _aforoMaximo    = 2;
  int  _duracionSlot   = 30;
  final List<String> _horasBloqueadas  = [];
  final List<String> _fechasBloqueadas = [];
  final List<int>    _diasCerrados     = [];
  final _msgSlotCtrl = TextEditingController();
  final Map<int, Map<String, String>> _horarioPorDia = {};

  static const _dias = [(1,'Lunes'),(2,'Martes'),(3,'Miércoles'),
    (4,'Jueves'),(5,'Viernes'),(6,'Sábado'),(7,'Domingo')];
  static const _categoriasNav = [
    ('seo',       'SEO',        Icons.manage_search_rounded,   'Meta tags y buscadores'),
    ('marketing', 'Marketing',  Icons.campaign_rounded,        'Popups y banners'),
    ('tecnico',   'Técnico',    Icons.settings_ethernet_rounded,'Dominio y APIs'),
    ('reservas',  'Reservas',   Icons.calendar_month_rounded,  'Formulario y horarios'),
    ('seguridad', 'Seguridad',  Icons.shield_rounded,          'Cookies y privacidad'),
  ];

  List<TextEditingController> get _allControllers => [
    _dominioCtrl, _contactoEmailCtrl, _contactoWaCtrl, _contactoTituloCtrl, _contactoAutoRespCtrl,
    _popupTituloCtrl, _popupTextoCtrl, _popupBtnTextoCtrl, _popupBtnUrlCtrl,
    _bannerTextoCtrl, _bannerUrlCtrl, _gdprTextoCtrl, _gdprPoliticaCtrl,
    _waNumeroCtrl, _waMensajeCtrl, _waHorarioInicioCtrl, _waHorarioFinCtrl, _waFueraHorarioCtrl,
    _msgSlotCtrl,
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
    for (final c in _allControllers) {
      c.addListener(() { if (_cargado && !_hasChanges) setState(() => _hasChanges = true); });
    }
  }

  void _cargar() {
    widget.svc.obtenerConfigAvanzada(widget.empresaId).first.then((cfg) {
      if (!mounted) return;
      setState(() {
        _dominioCtrl.text          = cfg.dominioPropioUrl ?? '';
        _contactoActivo            = cfg.contactoActivo;
        _contactoAutoResp          = cfg.contactoAutoRespuesta;
        _contactoEmailCtrl.text    = cfg.contactoEmail ?? '';
        _contactoWaCtrl.text       = cfg.contactoWhatsapp ?? '';
        _contactoTituloCtrl.text   = cfg.contactoTitulo ?? '';
        _contactoAutoRespCtrl.text = cfg.contactoAutoRespuestaTexto ?? '';
        _popupActivo               = cfg.popupActivo;
        _popupExitIntent           = cfg.popupExitIntent;
        _popupRetraso              = cfg.popupRetrasoSeg;
        _popupFrecuencia           = cfg.popupFrecuenciaDias;
        _popupDispositivo          = cfg.popupDispositivo;
        _popupTituloCtrl.text      = cfg.popupTitulo ?? '';
        _popupTextoCtrl.text       = cfg.popupTexto ?? '';
        _popupBtnTextoCtrl.text    = cfg.popupBotonTexto ?? '';
        _popupBtnUrlCtrl.text      = cfg.popupBotonUrl ?? '';
        _bannerActivo              = cfg.bannerActivo;
        _bannerTextoCtrl.text      = cfg.bannerTexto ?? '';
        _bannerUrlCtrl.text        = cfg.bannerUrlDestino ?? '';
        _bannerColor               = cfg.bannerColor ?? '#1976D2';
        _gdprActivo                = cfg.gdprActivo;
        _gdprAnalitica             = cfg.gdprCategoriasAnalitica;
        _gdprMarketing             = cfg.gdprCategoriasMarketing;
        _gdprTextoCtrl.text        = cfg.gdprTexto ?? '';
        _gdprPoliticaCtrl.text     = cfg.gdprPoliticaUrl ?? '';
        _waActivo                  = cfg.whatsappWidgetActivo;
        _waNumeroCtrl.text         = cfg.whatsappNumero ?? '';
        _waMensajeCtrl.text        = cfg.whatsappMensaje ?? '';
        _waHorarioInicioCtrl.text  = cfg.whatsappHorarioInicio ?? '';
        _waHorarioFinCtrl.text     = cfg.whatsappHorarioFin ?? '';
        _waFueraHorarioCtrl.text   = cfg.whatsappMensajeFueraHorario ?? '';
        _cargado    = true;
        _hasChanges = false;
      });
    });
    // Cargar si el script ya fue copiado anteriormente
    FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('configuracion').doc('web_avanzada')
        .get().then((doc) {
      if (!mounted) return;
      final copiado = doc.data()?['script_copiado'] == true;
      if (copiado && !_scriptCopiado) setState(() => _scriptCopiado = true);
    });
    widget.svc.obtenerConfigReservasWeb(widget.empresaId).first.then((r) {
      if (!mounted) return;
      setState(() {
        _reservasActivo = r.activo;
        _aforoMaximo    = r.aforoMaximoPorFranja;
        _duracionSlot   = r.duracionSlotMinutos;
        _horasBloqueadas..clear()..addAll(r.horasBloqueadas);
        _fechasBloqueadas..clear()..addAll(r.fechasBloqueadas);
        _diasCerrados..clear()..addAll(r.diasRecurrentesCerrados);
        _msgSlotCtrl.text = r.mensajeSlotLleno ?? '';
        _horarioPorDia.clear();
        r.horarioPorDia.forEach((k, v) {
          final n = int.tryParse(k);
          if (n != null) _horarioPorDia[n] = {...v};
        });
      });
    });
  }

  @override
  void dispose() {
    for (final c in _allControllers) c.dispose();
    _horarioCtrlCache.forEach((_, c) => c.dispose());
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;
    if (!_cargado) return Center(child: CircularProgressIndicator(color: color));

    return ColoredBox(
      color: const Color(0xFFF5F7FA),
      child: Column(children: [
        _buildHeader(color),
        Expanded(child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _buildStatCards(color)),
          SliverToBoxAdapter(child: _buildCategoryNav(color)),
          SliverToBoxAdapter(child: _buildContent(color)),
          if (_categoria == 'marketing')
            SliverToBoxAdapter(child: _buildVistaPrevia(color)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ])),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(Color color) {
    final url = _dominioCtrl.text.trim();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.language_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Configuración web',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          Text('Personaliza tu página web, dominio y preferencias',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ])),
        if (url.isNotEmpty)
          IconButton(
            icon: Icon(Icons.open_in_new_rounded, size: 17, color: Colors.grey[400]),
            tooltip: 'Copiar URL del sitio',
            onPressed: () => Clipboard.setData(ClipboardData(text: url)).then((_) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('URL copiada'), duration: Duration(seconds: 1)));
            }),
          ),
        const SizedBox(width: 4),
        FilledButton.icon(
          onPressed: _guardando ? null : () => _guardar(context),
          icon: _guardando
              ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded, size: 15),
          label: Text(_guardando ? 'Guardando…' : 'Guardar cambios',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          style: FilledButton.styleFrom(
            backgroundColor: _hasChanges ? color : color.withValues(alpha: 0.55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          ),
        ),
      ]),
    );
  }

  // ── Stat cards ────────────────────────────────────────────────────────────

  Widget _buildStatCards(Color color) {
    final url       = _dominioCtrl.text.trim();
    final hasUrl    = url.isNotEmpty;
    final isHttps   = url.startsWith('https://');
    final ultimaStr = _ultimaGuardado == null ? 'Nunca'
        : 'Hoy, ${_ultimaGuardado!.hour.toString().padLeft(2,'0')}:${_ultimaGuardado!.minute.toString().padLeft(2,'0')}';
    final estadoOk = hasUrl && isHttps;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Row(children: [
        Expanded(child: _statCard(
          icono: Icons.language_rounded,
          iconBg: const Color(0xFFEFF6FF),
          iconColor: const Color(0xFF2563EB),
          label: 'Dominio activo',
          valor: hasUrl ? url.replaceAll(RegExp(r'https?://'), '').split('/').first : 'No configurado',
          badge: hasUrl ? _badge('Conectado', const Color(0xFF059669), const Color(0xFFD1FAE5)) : null,
        )),
        const SizedBox(width: 8),
        Expanded(child: _statCard(
          icono: Icons.lock_rounded,
          iconBg: const Color(0xFFF0FDF4),
          iconColor: const Color(0xFF16A34A),
          label: 'SSL',
          valor: isHttps ? 'Activo' : (hasUrl ? 'Sin SSL' : '—'),
          badge: isHttps ? _badge('Seguro', const Color(0xFF16A34A), const Color(0xFFD1FAE5)) : null,
        )),
        const SizedBox(width: 8),
        Expanded(child: _statCard(
          icono: Icons.history_rounded,
          iconBg: const Color(0xFFFFF7ED),
          iconColor: const Color(0xFFD97706),
          label: 'Última actualización',
          valor: ultimaStr,
          sub: _ultimaGuardado != null
              ? '${_ultimaGuardado!.day.toString().padLeft(2,'0')}/${_ultimaGuardado!.month.toString().padLeft(2,'0')}/${_ultimaGuardado!.year}'
              : null,
        )),
        const SizedBox(width: 8),
        Expanded(child: _statCard(
          icono: estadoOk ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
          iconBg: estadoOk ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
          iconColor: estadoOk ? const Color(0xFF16A34A) : const Color(0xFFD97706),
          label: 'Estado general',
          valor: estadoOk ? 'Todo correcto' : 'Sin incidencias',
          sub: estadoOk ? 'Sin incidencias' : 'Configura el dominio',
        )),
      ]),
    );
  }

  Widget _statCard({
    required IconData icono, required Color iconBg, required Color iconColor,
    required String label, required String valor, String? sub, Widget? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EDF2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icono, color: iconColor, size: 16),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 9.5, color: Colors.grey[500], fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(valor,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        if (badge != null) ...[const SizedBox(height: 4), badge],
        if (sub != null && badge == null)
          Text(sub, style: TextStyle(fontSize: 9.5, color: Colors.grey[400])),
      ]),
    );
  }

  Widget _badge(String label, Color textColor, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 9.5, color: textColor, fontWeight: FontWeight.w700)),
    );
  }

  // ── Category nav ──────────────────────────────────────────────────────────

  Widget _buildCategoryNav(Color color) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
      ),
      child: Column(
        children: _categoriasNav.asMap().entries.map((e) {
          final (id, titulo, icono, sub) = e.value;
          final sel = _categoria == id;
          final isLast = e.key == _categoriasNav.length - 1;
          return Column(children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _categoria = id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: sel ? color.withValues(alpha: 0.12) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icono, size: 19, color: sel ? color : Colors.grey[500]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(titulo, style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600,
                      color: sel ? color : const Color(0xFF0F172A),
                    )),
                    Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ])),
                  Icon(Icons.chevron_right_rounded, size: 18,
                      color: sel ? color : Colors.grey[300]),
                ]),
              ),
            ),
            if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
          ]);
        }).toList(),
      ),
    );
  }

  // ── Content router ────────────────────────────────────────────────────────

  Widget _buildContent(Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: switch (_categoria) {
        'seo'       => TabSeoWeb(empresaId: widget.empresaId, svc: widget.svc),
        'marketing' => _buildMarketingList(color),
        'tecnico'   => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildScriptStatusCard(color),
            const SizedBox(height: 10),
            _buildTecnicoList(color),
          ]),
        'reservas'  => _buildReservasList(color),
        'seguridad' => _buildSeguridadList(color),
        _           => const SizedBox.shrink(),
      },
    );
  }

  Widget _buildScriptStatusCard(Color color) {
    return StreamBuilder<DateTime?>(
      stream: widget.svc.obtenerUltimoPingScript(widget.empresaId),
      builder: (_, snap) {
        final ping = snap.data;
        final activo = ping != null &&
            DateTime.now().difference(ping).inMinutes < 60;
        final hace = ping == null
            ? null
            : DateTime.now().difference(ping);
        final haceStr = hace == null
            ? null
            : hace.inMinutes < 1
                ? 'hace unos segundos'
                : hace.inHours < 1
                    ? 'hace ${hace.inMinutes} min'
                    : hace.inHours < 24
                        ? 'hace ${hace.inHours}h'
                        : 'hace ${hace.inDays}d';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: ping == null
                  ? const Color(0xFFE2E8F0)
                  : activo
                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.4),
            ),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: ping == null
                    ? const Color(0xFFF1F5F9)
                    : activo
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                ping == null
                    ? Icons.integration_instructions_outlined
                    : activo
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded,
                size: 20,
                color: ping == null
                    ? Colors.grey
                    : activo
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                ping == null
                    ? 'Script no detectado'
                    : activo
                        ? 'Script activo en tu web'
                        : 'Script instalado (inactivo)',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13,
                    color: ping == null
                        ? const Color(0xFF64748B)
                        : activo
                            ? const Color(0xFF059669)
                            : const Color(0xFFD97706)),
              ),
              const SizedBox(height: 2),
              Text(
                ping == null
                    ? 'Instala el script en tu WordPress para sincronizar'
                    : 'Último ping: $haceStr',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              ),
            ])),
            if (ping == null)
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PantallaIntegracionScript(empresaId: widget.empresaId))),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                child: const Text('Ver script →', style: TextStyle(fontSize: 12)),
              ),
          ]),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LISTAS DE AJUSTES
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMarketingList(Color color) {
    return _settingsGroup(title: 'Marketing',
        subtitle: 'Gestiona los elementos de marketing de tu sitio web',
        color: color, rows: [
      _settingRow(
        iconBg: const Color(0xFFEFF6FF), iconColor: const Color(0xFF2563EB),
        icono: Icons.language_rounded,
        titulo: 'Dominio y SSL',
        subtitulo: 'Gestiona tu dominio y certificados SSL',
        toggle: null,
        summary: [
          if (_dominioCtrl.text.isEmpty) ('', 'No configurado')
          else ('Dominio principal', _dominioCtrl.text.replaceAll(RegExp(r'https?://'), '').split('/').first),
          if (_dominioCtrl.text.startsWith('https://'))
            ('SSL activo', 'Conexión segura'),
        ],
        onTap: () => _openSheet(context, color, 'Dominio y SSL', _buildEditorDominio(color)),
      ),
      _settingRow(
        iconBg: const Color(0xFFF5F3FF), iconColor: const Color(0xFF7C3AED),
        icono: Icons.open_in_new_rounded,
        titulo: 'Popup de bienvenida',
        subtitulo: 'Ventana emergente con ofertas o avisos',
        toggle: _popupActivo,
        onToggle: (v) => setState(() { _popupActivo = v; _hasChanges = true; }),
        summary: _popupActivo ? [
          if (_popupTituloCtrl.text.isNotEmpty) ('Título', _popupTituloCtrl.text),
          ('Mostrar después de', '$_popupRetraso segundos'),
        ] : [],
        onTap: () => _openSheet(context, color, 'Popup de bienvenida', _buildEditorPopup(color)),
      ),
      _settingRow(
        iconBg: const Color(0xFFFFF7ED), iconColor: const Color(0xFFD97706),
        icono: Icons.view_day_outlined,
        titulo: 'Banner superior',
        subtitulo: 'Barra informativa en la parte superior',
        toggle: _bannerActivo,
        onToggle: (v) => setState(() { _bannerActivo = v; _hasChanges = true; }),
        summary: _bannerActivo && _bannerTextoCtrl.text.isNotEmpty ? [
          ('Texto del banner', _bannerTextoCtrl.text),
          if (_bannerUrlCtrl.text.isNotEmpty) ('Enlace', 'Configurado'),
        ] : [],
        onTap: () => _openSheet(context, color, 'Banner superior', _buildEditorBanner(color)),
      ),
      _settingRow(
        iconBg: const Color(0xFFF0FDF4), iconColor: const Color(0xFF16A34A),
        icono: Icons.chat_rounded,
        titulo: 'Widget de WhatsApp',
        subtitulo: 'Botón flotante de WhatsApp en tu web',
        toggle: _waActivo,
        onToggle: (v) => setState(() { _waActivo = v; _hasChanges = true; }),
        summary: _waActivo ? [
          if (_waMensajeCtrl.text.isNotEmpty) ('Mensaje automático', _waMensajeCtrl.text),
          if (_waNumeroCtrl.text.isNotEmpty) ('Teléfono', _waNumeroCtrl.text),
        ] : [],
        onTap: () => _openSheet(context, color, 'Widget de WhatsApp', _buildEditorWhatsapp(color)),
      ),
      _settingRow(
        iconBg: const Color(0xFFEFF6FF), iconColor: const Color(0xFF3B82F6),
        icono: Icons.contact_mail_outlined,
        titulo: 'Formulario de contacto',
        subtitulo: 'Configuración del formulario de contacto',
        toggle: _contactoActivo,
        onToggle: (v) => setState(() { _contactoActivo = v; _hasChanges = true; }),
        summary: _contactoActivo ? [
          ('Email de destino', _contactoEmailCtrl.text.isEmpty ? 'No configurado' : _contactoEmailCtrl.text),
          if (_contactoAutoResp) ('Auto-respuesta', 'Activada'),
        ] : [],
        onTap: () => _openSheet(context, color, 'Formulario de contacto', _buildEditorContacto(color)),
      ),
    ]);
  }

  Widget _buildTecnicoList(Color color) {
    return _settingsGroup(title: 'Técnico',
        subtitle: 'Configuración técnica y conexión con el sitio web',
        color: color, rows: [
      _settingRow(
        iconBg: const Color(0xFFEFF6FF), iconColor: const Color(0xFF2563EB),
        icono: Icons.link_rounded,
        titulo: 'Dominio y SSL',
        subtitulo: 'URL donde está instalado el script Fluix',
        toggle: null,
        summary: [
          ('URL del sitio', _dominioCtrl.text.isEmpty ? 'No configurado' : _dominioCtrl.text),
          if (_dominioCtrl.text.startsWith('https://')) ('SSL', 'Conexión segura'),
        ],
        onTap: () => _openSheet(context, color, 'Dominio', _buildEditorDominio(color)),
      ),
      _settingRow(
        iconBg: const Color(0xFFF0FDF4), iconColor: const Color(0xFF16A34A),
        icono: Icons.integration_instructions_rounded,
        titulo: 'Script de integración',
        subtitulo: 'Código para conectar tu web con Fluix',
        toggle: null,
        summary: [
          ('Estado', _dominioCtrl.text.isEmpty ? 'Configura el dominio primero' : 'Listo para instalar'),
        ],
        onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => PantallaIntegracionScript(empresaId: widget.empresaId))),
      ),
    ]);
  }

  Widget _buildEditorScript(Color color) {
    final snippet =
        '<script src="https://cdn.fluix.app/v1/widget.js"\n'
        '  data-empresa="${widget.empresaId}" defer></script>';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Expanded(child: Text(snippet,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11.5,
                  fontFamily: 'monospace', height: 1.6))),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: snippet));
              if (!mounted) return;
              setState(() => _scriptCopiado = true);
              try {
                await FirebaseFirestore.instance
                    .collection('empresas').doc(widget.empresaId)
                    .collection('configuracion').doc('web_avanzada')
                    .set({'script_copiado': true}, SetOptions(merge: true));
              } catch (_) {}
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Código copiado — instálalo en tu web para activar la sincronización'),
                  duration: Duration(seconds: 3),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.copy_rounded, size: 16, color: color),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: const Text(
          '📋 Copia este código y pégalo en el HTML de tu web, justo antes del cierre de la página. '
          'Solo necesitas hacerlo una vez para activar la sincronización en tiempo real.',
          style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.5),
        ),
      ),
      const SizedBox(height: 10),
      // Badge estado script
      Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _scriptCopiado
                ? const Color(0xFFECFDF5)
                : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _scriptCopiado
                ? const Color(0xFFBBF7D0)
                : const Color(0xFFFDE68A)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              _scriptCopiado ? Icons.check_circle_rounded : Icons.pending_outlined,
              size: 13,
              color: _scriptCopiado ? const Color(0xFF16A34A) : const Color(0xFFD97706),
            ),
            const SizedBox(width: 5),
            Text(
              _scriptCopiado ? 'Script copiado — instálalo en tu web' : 'Script pendiente de copiar',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _scriptCopiado ? const Color(0xFF16A34A) : const Color(0xFFD97706),
              ),
            ),
          ]),
        ),
      ]),
    ]);
  }

  Widget _buildReservasList(Color color) {
    final diasAbiertos = _dias.where((d) => !_diasCerrados.contains(d.$1)).length;
    return _settingsGroup(title: 'Reservas',
        subtitle: 'Gestiona el formulario de reservas de tu sitio web',
        color: color, rows: [
      _settingRow(
        iconBg: const Color(0xFFFFF7ED), iconColor: const Color(0xFFD97706),
        icono: Icons.calendar_month_rounded,
        titulo: 'Formulario de reservas web',
        subtitulo: 'Activar o desactivar el formulario en la web',
        toggle: _reservasActivo,
        onToggle: (v) => setState(() { _reservasActivo = v; _hasChanges = true; }),
        summary: _reservasActivo ? [
          ('Aforo máximo', '$_aforoMaximo personas por franja'),
          ('Duración del slot', '$_duracionSlot minutos'),
        ] : [],
        onTap: () => _openSheet(context, color, 'Reservas web', _buildEditorReservas(color)),
      ),
      _settingRow(
        iconBg: const Color(0xFFF0FDF4), iconColor: const Color(0xFF16A34A),
        icono: Icons.schedule_rounded,
        titulo: 'Horario semanal',
        subtitulo: 'Días y horas de apertura configurados',
        toggle: null,
        summary: [
          ('Días abiertos', '$diasAbiertos de 7'),
          if (_diasCerrados.isNotEmpty)
            ('Días cerrados', _diasCerrados.map((d) => _dias.firstWhere((dd) => dd.$1 == d).$2.substring(0,3)).join(', ')),
        ],
        onTap: () => _openSheet(context, color, 'Horario semanal', _buildEditorHorario(color)),
      ),
      _settingRow(
        iconBg: const Color(0xFFFEF2F2), iconColor: const Color(0xFFDC2626),
        icono: Icons.block_rounded,
        titulo: 'Horas y fechas bloqueadas',
        subtitulo: 'Excepciones al horario normal',
        toggle: null,
        summary: [
          ('Horas bloqueadas', _horasBloqueadas.isEmpty ? 'Ninguna' : '${_horasBloqueadas.length} horas'),
          ('Fechas bloqueadas', _fechasBloqueadas.isEmpty ? 'Ninguna' : '${_fechasBloqueadas.length} días'),
        ],
        onTap: () => _openSheet(context, color, 'Excepciones', _buildEditorExcepciones(color)),
      ),
    ]);
  }

  Widget _buildSeguridadList(Color color) {
    return _settingsGroup(title: 'Seguridad',
        subtitle: 'Privacidad, cookies y protección de tu web',
        color: color, rows: [
      _settingRow(
        iconBg: const Color(0xFFF0FDF4), iconColor: const Color(0xFF16A34A),
        icono: Icons.cookie_outlined,
        titulo: 'GDPR / Cookies',
        subtitulo: 'Banner de consentimiento de cookies (obligatorio UE)',
        toggle: _gdprActivo,
        onToggle: (v) => setState(() { _gdprActivo = v; _hasChanges = true; }),
        summary: _gdprActivo ? [
          ('Texto del banner', _gdprTextoCtrl.text.isEmpty ? 'Sin configurar' : _gdprTextoCtrl.text),
          ('Categorías', [
            if (_gdprAnalitica) 'Analytics',
            if (_gdprMarketing) 'Marketing',
            'Necesarias',
          ].join(', ')),
        ] : [],
        onTap: () => _openSheet(context, color, 'GDPR / Cookies', _buildEditorGdpr(color)),
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VISTA PREVIA
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildVistaPrevia(Color color) {
    final urlDisplay = _dominioCtrl.text.trim().replaceAll(RegExp(r'https?://'), '').split('/').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EDF2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Vista previa',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              Text('Así se verán los elementos en tu sitio web',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
          ),
          // Mini web browser
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(children: [
              // Address bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                color: const Color(0xFFF1F5F9),
                child: Row(children: [
                  Icon(Icons.lock_rounded, size: 10, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(urlDisplay.isEmpty ? 'tunegocio.com' : urlDisplay,
                      style: TextStyle(fontSize: 9.5, color: Colors.grey[600])),
                ]),
              ),
              SizedBox(
                height: 220,
                child: Stack(children: [
                  // Banner
                  if (_bannerActivo && _bannerTextoCtrl.text.isNotEmpty)
                    Positioned(top: 0, left: 0, right: 0, child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      color: _hexColor(_bannerColor),
                      child: Row(children: [
                        Expanded(child: Text(_bannerTextoCtrl.text,
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                        const Text('Ver ofertas →', style: TextStyle(color: Colors.white70, fontSize: 8.5)),
                        const SizedBox(width: 6),
                        const Icon(Icons.close, color: Colors.white60, size: 10),
                      ]),
                    )),
                  // Nav bar
                  Positioned(top: _bannerActivo && _bannerTextoCtrl.text.isNotEmpty ? 26 : 0,
                      left: 0, right: 0, child: Container(
                    height: 38,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                        child: Text(urlDisplay.isEmpty ? 'Fluix' : urlDisplay.split('.').first.capitalize(),
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      ...['Inicio','Tienda','Servicios','Nosotros','Contacto'].map((t) => Padding(
                        padding: const EdgeInsets.only(right: 9),
                        child: Text(t, style: TextStyle(fontSize: 8.5, color: Colors.grey[600])),
                      )),
                    ]),
                  )),
                  // Popup
                  if (_popupActivo && _popupTituloCtrl.text.isNotEmpty)
                    Positioned(left: 10, bottom: 10, child: Container(
                      width: 130,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10)],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(_popupTituloCtrl.text,
                              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold),
                              maxLines: 2)),
                          const Icon(Icons.close, size: 9, color: Colors.grey),
                        ]),
                        if (_popupTextoCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(_popupTextoCtrl.text,
                              style: TextStyle(fontSize: 7.5, color: Colors.grey[600]),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                        if (_popupBtnTextoCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                            child: Text(_popupBtnTextoCtrl.text,
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ]),
                    )),
                  // WhatsApp FAB
                  if (_waActivo)
                    Positioned(right: 10, bottom: 10, child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25d366), shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.chat_rounded, color: Colors.white, size: 17),
                    )),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS BASE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _settingsGroup({
    required String title, required String subtitle,
    required Color color, required List<Widget> rows,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ]),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EDF2)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
        ),
        child: Column(children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Column(children: [
            e.value,
            if (!isLast) const Divider(height: 1, indent: 16, endIndent: 0, color: Color(0xFFF1F5F9)),
          ]);
        }).toList()),
      ),
    ]);
  }

  Widget _settingRow({
    required Color iconBg, required Color iconColor, required IconData icono,
    required String titulo, required String subtitulo,
    bool? toggle, ValueChanged<bool>? onToggle,
    required List<(String, String)> summary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Icon
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icono, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Title + subtitle
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          const SizedBox(width: 8),
          // Toggle
          if (toggle != null)
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: toggle, onChanged: onToggle,
                activeColor: const Color(0xFF2563EB),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          // Summary
          if (summary.isNotEmpty)
            Expanded(flex: 2, child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: summary.take(2).map((s) {
                  final (label, value) = s;
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (label.isNotEmpty)
                      Text(label, style: TextStyle(fontSize: 9.5, color: Colors.grey[400])),
                    Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                  ]);
                }).toList()),
            )),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey[300]),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHEETS EDITORES
  // ═══════════════════════════════════════════════════════════════════════════

  void _openSheet(BuildContext context, Color color, String titulo, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => DraggableScrollableSheet(
          initialChildSize: 0.9, maxChildSize: 0.97, minChildSize: 0.4,
          expand: false,
          builder: (_, ctrl) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              // Handle
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                child: Container(width: 38, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              ),
              // Título
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(children: [
                  Expanded(child: Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                  FilledButton(
                    onPressed: () { setState(() {}); Navigator.pop(ctx); },
                    style: FilledButton.styleFrom(
                      backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Listo', style: TextStyle(fontSize: 13)),
                  ),
                ]),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.all(20),
                  children: [content])),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildEditorDominio(Color color) {
    return Column(children: [
      _fld(Icons.public_rounded, 'URL del sitio web *', _dominioCtrl, 'https://tunegocio.com'),
      const SizedBox(height: 12),
      Row(children: [
        if (_dominioStatus != null) ...[
          Icon(
            switch (_dominioStatus) {
              'ok'      => Icons.check_circle_rounded,
              'timeout' => Icons.timer_off_outlined,
              'unknown' => Icons.help_outline_rounded,
              _         => Icons.error_outline_rounded,
            },
            size: 14,
            color: switch (_dominioStatus) {
              'ok'      => Colors.green,
              'timeout' => Colors.orange,
              'unknown' => Colors.orange,
              _         => Colors.red,
            },
          ),
          const SizedBox(width: 6),
          Text(
            switch (_dominioStatus) {
              'ok'      => 'Sitio accesible ✓',
              'timeout' => 'Sin respuesta (timeout)',
              'unknown' => 'El dominio parece correcto. La verificación completa se hace al instalar el código.',
              _         => 'No accesible',
            },
            style: TextStyle(fontSize: 12,
              color: switch (_dominioStatus) {
                'ok'      => Colors.green,
                'timeout' || 'unknown' => Colors.orange,
                _         => Colors.red,
              }),
          ),
        ],
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _verificando ? null : _verificarDominio,
          icon: _verificando ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5))
              : const Icon(Icons.radar_rounded, size: 14),
          label: const Text('Verificar', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(foregroundColor: color,
              side: BorderSide(color: color.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ]),
    ]);
  }

  Widget _buildEditorPopup(Color color) {
    return Column(children: [
      _fld(Icons.title_rounded, 'Título *', _popupTituloCtrl, '¡Oferta especial!'),
      const SizedBox(height: 10),
      _fld(Icons.notes_rounded, 'Texto descriptivo', _popupTextoCtrl, 'Solo este fin de semana…', lines: 3),
      const SizedBox(height: 10),
      _fld(Icons.smart_button_outlined, 'Texto del botón', _popupBtnTextoCtrl, 'Ver oferta'),
      const SizedBox(height: 10),
      _fld(Icons.link_rounded, 'URL del botón', _popupBtnUrlCtrl, 'https://...'),
      const SizedBox(height: 16),
      Row(children: [
        Icon(Icons.timer_outlined, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text('Retraso: ${_popupRetraso}s', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
        Expanded(child: Slider(value: _popupRetraso.toDouble(), min: 0, max: 30, divisions: 6,
            activeColor: color, label: '$_popupRetraso s',
            onChanged: (v) => setState(() { _popupRetraso = v.toInt(); _hasChanges = true; }))),
      ]),
      const SizedBox(height: 10),
      _dropRow(Icons.repeat_rounded, 'Frecuencia', _popupFrecuencia,
          {0: 'Siempre', 1: '1 vez', 7: 'Semanal', 30: 'Mensual'},
          (v) => setState(() { _popupFrecuencia = v; _hasChanges = true; }), color),
      const SizedBox(height: 10),
      _dropRow(Icons.devices_rounded, 'Dispositivo', _popupDispositivo,
          {'todos': 'Todos', 'mobile': 'Solo móvil', 'desktop': 'Solo escritorio'},
          (v) => setState(() { _popupDispositivo = v; _hasChanges = true; }), color),
      const SizedBox(height: 10),
      _switchRow(Icons.exit_to_app_rounded, 'Exit-intent', _popupExitIntent, color,
          (v) => setState(() { _popupExitIntent = v; _hasChanges = true; })),
    ]);
  }

  Widget _buildEditorBanner(Color color) {
    return Column(children: [
      _fld(Icons.announcement_outlined, 'Texto del banner *', _bannerTextoCtrl, '🎉 Oferta especial…'),
      const SizedBox(height: 10),
      _fld(Icons.link_rounded, 'URL de destino', _bannerUrlCtrl, 'https://...'),
      const SizedBox(height: 16),
      Text('Color:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      const SizedBox(height: 8),
      Wrap(spacing: 10, children: ['#1976D2','#E53935','#2E7D32','#E65100','#6A1B9A','#00796B','#212121'].map((hex) {
        final c = _hexColor(hex);
        return GestureDetector(
          onTap: () => setState(() { _bannerColor = hex; _hasChanges = true; }),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle,
              border: _bannerColor == hex ? Border.all(color: Colors.white, width: 3) : null,
              boxShadow: [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 5)]),
            child: _bannerColor == hex ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
          ),
        );
      }).toList()),
    ]);
  }

  Widget _buildEditorWhatsapp(Color color) {
    return Column(children: [
      _fld(Icons.phone_outlined, 'Número WhatsApp *', _waNumeroCtrl, '+34600000000'),
      const SizedBox(height: 10),
      _fld(Icons.chat_bubble_outline_rounded, 'Mensaje predefinido', _waMensajeCtrl, 'Hola, ¿en qué podemos ayudarte?'),
      const SizedBox(height: 16),
      Text('Horario de atención', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[700])),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _tpk('Desde', _waHorarioInicioCtrl, color)),
        const SizedBox(width: 12),
        Expanded(child: _tpk('Hasta', _waHorarioFinCtrl, color)),
      ]),
      const SizedBox(height: 10),
      _fld(Icons.schedule_rounded, 'Mensaje fuera de horario', _waFueraHorarioCtrl, 'Estamos disponibles de 9h a 21h…'),
    ]);
  }

  Widget _buildEditorContacto(Color color) {
    return Column(children: [
      _fld(Icons.title_rounded, 'Título del formulario', _contactoTituloCtrl, 'Contáctanos'),
      const SizedBox(height: 10),
      _fld(Icons.email_outlined, 'Email de destino *', _contactoEmailCtrl, 'hola@tunegocio.com'),
      const SizedBox(height: 10),
      _fld(Icons.phone_outlined, 'WhatsApp (opcional)', _contactoWaCtrl, '+34 6XX XXX XXX'),
      const SizedBox(height: 10),
      _switchRow(Icons.reply_rounded, 'Auto-respuesta al cliente', _contactoAutoResp, color,
          (v) => setState(() { _contactoAutoResp = v; _hasChanges = true; })),
      if (_contactoAutoResp) ...[
        const SizedBox(height: 10),
        _fld(Icons.chat_bubble_outline_rounded, 'Texto de la auto-respuesta', _contactoAutoRespCtrl,
            'Gracias por tu mensaje, te responderemos pronto.', lines: 3),
      ],
    ]);
  }

  Widget _buildEditorGdpr(Color color) {
    return Column(children: [
      _fld(Icons.description_outlined, 'Texto del banner *', _gdprTextoCtrl,
          'Usamos cookies para mejorar tu experiencia.', lines: 2),
      const SizedBox(height: 10),
      _fld(Icons.policy_outlined, 'URL política de privacidad', _gdprPoliticaCtrl,
          'https://tunegocio.com/privacidad'),
      const SizedBox(height: 16),
      Text('Categorías', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[700])),
      const SizedBox(height: 6),
      _switchRow(Icons.bar_chart_rounded, 'Analytics / estadísticas', _gdprAnalitica, color,
          (v) => setState(() { _gdprAnalitica = v; _hasChanges = true; })),
      const SizedBox(height: 6),
      _switchRow(Icons.campaign_rounded, 'Marketing / publicidad', _gdprMarketing, color,
          (v) => setState(() { _gdprMarketing = v; _hasChanges = true; })),
    ]);
  }

  Widget _buildEditorReservas(Color color) {
    return Column(children: [
      Text('Duración del slot: ${_duracionSlot}min',
          style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      Slider(value: _duracionSlot.toDouble(), min: 15, max: 120, divisions: 7,
          activeColor: color, label: '$_duracionSlot min',
          onChanged: (v) => setState(() { _duracionSlot = v.toInt(); _hasChanges = true; })),
      Text('Aforo máximo: $_aforoMaximo personas',
          style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      Slider(value: _aforoMaximo.toDouble(), min: 1, max: 50, divisions: 49,
          activeColor: color, label: '$_aforoMaximo',
          onChanged: (v) => setState(() { _aforoMaximo = v.toInt(); _hasChanges = true; })),
      const SizedBox(height: 10),
      _fld(Icons.warning_amber_outlined, 'Mensaje slot lleno', _msgSlotCtrl, '⚠ Sin disponibilidad en esta franja'),
    ]);
  }

  Widget _buildEditorHorario(Color color) {
    return Column(children: [
      ..._dias.map(((int, String) d) {
        final (num, nombre) = d;
        final abierto = !_diasCerrados.contains(num);
        final horario = _horarioPorDia[num];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            SizedBox(width: 76, child: Text(nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            Transform.scale(scale: 0.8, child: Switch(
              value: abierto, activeColor: color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) => setState(() {
                v ? _diasCerrados.remove(num) : _diasCerrados.add(num);
                _hasChanges = true;
              }),
            )),
            if (abierto) ...[
              const SizedBox(width: 4),
              Expanded(child: _tpk('Apertura', _horarioCtrl(num, 'apertura', horario?['apertura'] ?? '09:00'), color)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('–', style: TextStyle(color: Colors.grey))),
              Expanded(child: _tpk('Cierre', _horarioCtrl(num, 'cierre', horario?['cierre'] ?? '21:00'), color)),
            ] else
              Text('Cerrado', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ]),
        );
      }),
    ]);
  }

  Widget _buildEditorExcepciones(Color color) {
    final todasHoras = <String>[];
    for (int h = 8; h < 23; h++) {
      for (int m = 0; m < 60; m += 30) {
        todasHoras.add('${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}');
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Horas bloqueadas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey[800])),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: todasHoras.map((h) {
        final bl = _horasBloqueadas.contains(h);
        return GestureDetector(
          onTap: () => setState(() { bl ? _horasBloqueadas.remove(h) : _horasBloqueadas.add(h); _hasChanges = true; }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: bl ? Colors.red[50] : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: bl ? Colors.red[300]! : const Color(0xFFE2E8F0)),
            ),
            child: Text(h, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: bl ? Colors.red[700] : Colors.grey[600])),
          ),
        );
      }).toList()),
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Fechas bloqueadas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey[800])),
        TextButton.icon(
          onPressed: () async {
            final p = await showDatePicker(context: context, initialDate: DateTime.now(),
                firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)),
                locale: const Locale('es'));
            if (p != null) {
              final iso = p.toIso8601String().split('T').first;
              if (!_fechasBloqueadas.contains(iso)) setState(() { _fechasBloqueadas.add(iso); _hasChanges = true; });
            }
          },
          icon: const Icon(Icons.add, size: 13), label: const Text('Añadir', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
        ),
      ]),
      Wrap(spacing: 6, runSpacing: 6, children: _fechasBloqueadas.isEmpty
          ? [Text('Sin fechas bloqueadas', style: TextStyle(fontSize: 11, color: Colors.grey[400], fontStyle: FontStyle.italic))]
          : _fechasBloqueadas.map((f) => Chip(
              label: Text(f, style: const TextStyle(fontSize: 11)),
              backgroundColor: Colors.red[50],
              side: BorderSide(color: Colors.red[200]!),
              labelStyle: TextStyle(color: Colors.red[700]),
              deleteIconColor: Colors.red[400],
              onDeleted: () => setState(() { _fechasBloqueadas.remove(f); _hasChanges = true; }),
            )).toList()),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS WIDGET
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _fld(IconData icono, String label, TextEditingController ctrl, String hint, {int lines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextFormField(
        controller: ctrl, maxLines: lines,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          border: InputBorder.none, labelText: label, hintText: hint,
          labelStyle: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
          hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
          prefixIcon: Icon(icono, size: 17, color: Colors.grey[400]),
          prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 36),
          isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _switchRow(IconData icono, String label, bool value, Color color, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        Icon(icono, size: 17, color: Colors.grey[400]),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        Switch(value: value, onChanged: onChanged, activeColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]),
    );
  }

  Widget _dropRow<T>(IconData icono, String label, T value, Map<T, String> options,
      ValueChanged<T> onChanged, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        Icon(icono, size: 17, color: Colors.grey[400]),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        DropdownButton<T>(
          value: value, isDense: true, underline: const SizedBox(),
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
          onChanged: (v) => onChanged(v as T),
          items: options.entries.map((e) =>
              DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        ),
      ]),
    );
  }

  Widget _tpk(String label, TextEditingController ctrl, Color color) {
    return GestureDetector(
      onTap: () async {
        final parts = ctrl.text.split(':');
        final initial = TimeOfDay(
          hour: int.tryParse(parts.isNotEmpty ? parts[0] : '9') ?? 9,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
        );
        final picked = await showTimePicker(context: context, initialTime: initial);
        if (picked != null && mounted) {
          setState(() {
            ctrl.text = '${picked.hour.toString().padLeft(2,'0')}:${picked.minute.toString().padLeft(2,'0')}';
            _hasChanges = true;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(children: [
          Icon(Icons.access_time_rounded, size: 13, color: color),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[400])),
            Text(ctrl.text.isEmpty ? '--:--' : ctrl.text,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
          ]),
        ]),
      ),
    );
  }

  // Horario controller cache
  final Map<String, TextEditingController> _horarioCtrlCache = {};
  TextEditingController _horarioCtrl(int dia, String campo, String defaultVal) {
    final key = '${dia}_$campo';
    if (!_horarioCtrlCache.containsKey(key)) {
      _horarioCtrlCache[key] = TextEditingController(text: defaultVal);
      _horarioCtrlCache[key]!.addListener(() {
        _horarioPorDia[dia] ??= {'apertura': '09:00', 'cierre': '21:00'};
        _horarioPorDia[dia]![campo] = _horarioCtrlCache[key]!.text;
        if (_cargado && !_hasChanges) setState(() => _hasChanges = true);
      });
    }
    return _horarioCtrlCache[key]!;
  }

  Color _hexColor(String hex) {
    final clean = hex.replaceAll('#', '');
    try { return Color(int.parse('FF$clean', radix: 16)); }
    catch (_) { return Colors.blue; }
  }

  String? _t(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Future<void> _verificarDominio() async {
    final url = _dominioCtrl.text.trim();
    if (url.isEmpty) return;

    // Normalizar URL
    final normalized = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasAuthority) {
      setState(() { _dominioStatus = 'error'; });
      return;
    }

    setState(() { _verificando = true; _dominioStatus = null; });

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': 'FluixCRM/1.0 (verificacion-dominio)'})
          .timeout(const Duration(seconds: 10));

      // Cualquier código 2xx o 3xx = el dominio responde
      final ok = response.statusCode >= 200 && response.statusCode < 400;
      if (mounted) setState(() { _dominioStatus = ok ? 'ok' : 'error'; _verificando = false; });
    } on TimeoutException {
      if (mounted) setState(() { _dominioStatus = 'timeout'; _verificando = false; });
    } catch (_) {
      // Si falla en web (CORS), no es un error real del dominio
      if (mounted) setState(() { _dominioStatus = 'unknown'; _verificando = false; });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GUARDAR
  // ═══════════════════════════════════════════════════════════════════════════

  // ── Validadores ───────────────────────────────────────────────────────────

  static bool _esEmailValido(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  static bool _esUrlValida(String url) {
    final u = Uri.tryParse(url);
    return u != null && u.hasScheme && u.hasAuthority;
  }

  static bool _esTelefonoValido(String tel) =>
      RegExp(r'^\+?[\d\s\-]{7,15}$').hasMatch(tel.replaceAll(' ', ''));

  Future<void> _guardar(BuildContext context) async {
    // Validaciones de entrada antes de guardar
    if (_contactoActivo) {
      final email = _contactoEmailCtrl.text.trim();
      if (email.isNotEmpty && !_esEmailValido(email)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El email de contacto no tiene un formato válido'),
          backgroundColor: Colors.orange,
        ));
        return;
      }
    }
    final dominio = _dominioCtrl.text.trim();
    if (dominio.isNotEmpty && !_esUrlValida(dominio.startsWith('http') ? dominio : 'https://$dominio')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('La URL del sitio web no tiene un formato válido (ej: https://tunegocio.com)'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    if (_waActivo) {
      final wa = _waNumeroCtrl.text.trim();
      if (wa.isNotEmpty && !_esTelefonoValido(wa)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El número de WhatsApp no tiene un formato válido (ej: +34600000000)'),
          backgroundColor: Colors.orange,
        ));
        return;
      }
    }
    setState(() => _guardando = true);
    final horario = <String, Map<String, String>>{};
    _horarioCtrlCache.forEach((key, ctrl) {
      final parts = key.split('_');
      final dia = parts[0]; final campo = parts[1];
      horario.putIfAbsent(dia, () => {});
      horario[dia]![campo] = ctrl.text;
    });
    final cfg = ConfigWebAvanzada(
      dominioPropioUrl:            _t(_dominioCtrl),
      contactoActivo:              _contactoActivo,
      contactoEmail:               _t(_contactoEmailCtrl),
      contactoWhatsapp:            _t(_contactoWaCtrl),
      contactoTitulo:              _t(_contactoTituloCtrl),
      contactoAutoRespuesta:       _contactoAutoResp,
      contactoAutoRespuestaTexto:  _t(_contactoAutoRespCtrl),
      popupActivo:                 _popupActivo,
      popupTitulo:                 _t(_popupTituloCtrl),
      popupTexto:                  _t(_popupTextoCtrl),
      popupBotonTexto:             _t(_popupBtnTextoCtrl),
      popupBotonUrl:               _t(_popupBtnUrlCtrl),
      popupRetrasoSeg:             _popupRetraso,
      popupFrecuenciaDias:         _popupFrecuencia,
      popupExitIntent:             _popupExitIntent,
      popupDispositivo:            _popupDispositivo,
      bannerActivo:                _bannerActivo,
      bannerTexto:                 _t(_bannerTextoCtrl),
      bannerColor:                 _bannerColor,
      bannerUrlDestino:            _t(_bannerUrlCtrl),
      gdprActivo:                  _gdprActivo,
      gdprTexto:                   _t(_gdprTextoCtrl),
      gdprPoliticaUrl:             _t(_gdprPoliticaCtrl),
      gdprCategoriasAnalitica:     _gdprAnalitica,
      gdprCategoriasMarketing:     _gdprMarketing,
      whatsappWidgetActivo:        _waActivo,
      whatsappNumero:              _t(_waNumeroCtrl),
      whatsappMensaje:             _t(_waMensajeCtrl),
      whatsappHorarioInicio:       _t(_waHorarioInicioCtrl),
      whatsappHorarioFin:          _t(_waHorarioFinCtrl),
      whatsappMensajeFueraHorario: _t(_waFueraHorarioCtrl),
    );
    try {
      await widget.svc.guardarConfigAvanzada(widget.empresaId, cfg);
      await widget.svc.guardarConfigReservasWeb(widget.empresaId, ConfigReservasWeb(
        activo:                  _reservasActivo,
        aforoMaximoPorFranja:    _aforoMaximo,
        duracionSlotMinutos:     _duracionSlot,
        horasBloqueadas:         List.from(_horasBloqueadas),
        fechasBloqueadas:        List.from(_fechasBloqueadas),
        diasRecurrentesCerrados: List.from(_diasCerrados),
        horarioPorDia:           horario.map((k, v) => MapEntry(k, Map<String,String>.from(v))),
        mensajeSlotLleno:        _t(_msgSlotCtrl),
      ));
      if (mounted) {
        setState(() { _hasChanges = false; _ultimaGuardado = DateTime.now(); });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Configuración guardada'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}

extension _StringExt on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}

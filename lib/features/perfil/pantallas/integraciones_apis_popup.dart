import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/ia_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO
// ─────────────────────────────────────────────────────────────────────────────

enum EstadoApi { disponible, proximamente }

class ApiIntegracion {
  final String id;
  final String nombre;
  final String descripcion;
  final IconData icono;
  final Color color;
  final EstadoApi estado;
  bool activa;

  ApiIntegracion({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.icono,
    required this.color,
    this.estado = EstadoApi.disponible,
    this.activa = false,
  });
}

class CategoriaApi {
  final String emoji;
  final String nombre;
  final List<ApiIntegracion> items;
  const CategoriaApi({required this.emoji, required this.nombre, required this.items});
}

// ─────────────────────────────────────────────────────────────────────────────
// DATOS
// ─────────────────────────────────────────────────────────────────────────────

List<CategoriaApi> _buildCategorias() => [
  CategoriaApi(emoji: '📞', nombre: 'Comunicación', items: [
    ApiIntegracion(id: 'whatsapp',  nombre: 'WhatsApp Business', descripcion: 'Envía mensajes y notificaciones a clientes',     icono: Icons.chat_bubble_outline_rounded,     color: const Color(0xFF25D366)),
    ApiIntegracion(id: 'gmail',     nombre: 'Gmail',             descripcion: 'Conecta tu bandeja y envía emails desde Fluix', icono: Icons.email_outlined,                  color: const Color(0xFFEA4335)),
    ApiIntegracion(id: 'smtp',      nombre: 'Email SMTP',        descripcion: 'Servidor de correo personalizado',              icono: Icons.alternate_email_rounded,         color: const Color(0xFF6366F1)),
    ApiIntegracion(id: 'twilio',    nombre: 'Twilio SMS',        descripcion: 'Envía SMS a clientes automáticamente',          icono: Icons.sms_outlined,                    color: const Color(0xFFF22F46)),
    ApiIntegracion(id: 'telegram',  nombre: 'Telegram',          descripcion: 'Notificaciones y bot de atención al cliente',   icono: Icons.send_outlined,                   color: const Color(0xFF26A5E4)),
  ]),
  CategoriaApi(emoji: '📅', nombre: 'Calendario', items: [
    ApiIntegracion(id: 'gcal',      nombre: 'Google Calendar',      descripcion: 'Sincroniza reservas y citas automáticamente',  icono: Icons.calendar_month_outlined,  color: const Color(0xFF4285F4)),
    ApiIntegracion(id: 'outlook',   nombre: 'Microsoft Outlook',    descripcion: 'Integración con el calendario de Outlook',     icono: Icons.calendar_today_outlined,  color: const Color(0xFF0078D4)),
    ApiIntegracion(id: 'apple_cal', nombre: 'Apple Calendar',       descripcion: 'Sincroniza con iCal y dispositivos Apple',     icono: Icons.event_outlined,           color: const Color(0xFF555555), estado: EstadoApi.proximamente),
  ]),
  CategoriaApi(emoji: '💳', nombre: 'Pagos', items: [
    ApiIntegracion(id: 'stripe',    nombre: 'Stripe',               descripcion: 'Cobros online con tarjeta y Apple/Google Pay', icono: Icons.credit_card_outlined,     color: const Color(0xFF635BFF)),
    ApiIntegracion(id: 'redsys',    nombre: 'Redsys / TPV Virtual', descripcion: 'Pasarela de pago española homologada',         icono: Icons.payment_outlined,         color: const Color(0xFFE53935)),
    ApiIntegracion(id: 'paypal',    nombre: 'PayPal',               descripcion: 'Acepta pagos por PayPal y tarjeta',            icono: Icons.account_balance_wallet_outlined, color: const Color(0xFF003087)),
  ]),
  CategoriaApi(emoji: '📊', nombre: 'Contabilidad', items: [
    ApiIntegracion(id: 'holded',    nombre: 'Holded',               descripcion: 'Sincroniza facturas y contabilidad',           icono: Icons.receipt_long_outlined,    color: const Color(0xFF00C8A0)),
    ApiIntegracion(id: 'a3',        nombre: 'A3 Software',          descripcion: 'Exporta datos a A3 Asesor y A3con',           icono: Icons.bar_chart_outlined,       color: const Color(0xFF1565C0), estado: EstadoApi.proximamente),
    ApiIntegracion(id: 'sage',      nombre: 'Sage',                 descripcion: 'Conecta con Sage 50 y Sage Despachos',         icono: Icons.business_outlined,        color: const Color(0xFF00B140), estado: EstadoApi.proximamente),
  ]),
  CategoriaApi(emoji: '📢', nombre: 'Marketing', items: [
    ApiIntegracion(id: 'mailchimp', nombre: 'Mailchimp',            descripcion: 'Email marketing y automatizaciones',           icono: Icons.campaign_outlined,        color: const Color(0xFFFFE01B)),
    ApiIntegracion(id: 'brevo',     nombre: 'Brevo',                descripcion: 'Newsletters, SMS y automatizaciones',          icono: Icons.mark_email_unread_outlined, color: const Color(0xFF0B96E5)),
  ]),
  CategoriaApi(emoji: '🌍', nombre: 'Google', items: [
    ApiIntegracion(id: 'gmb',       nombre: 'Google My Business',   descripcion: 'Gestiona reseñas y ficha de negocio',          icono: Icons.store_mall_directory_outlined, color: const Color(0xFF4285F4)),
    ApiIntegracion(id: 'ga',        nombre: 'Google Analytics',     descripcion: 'Estadísticas de tu web y reservas',            icono: Icons.analytics_outlined,       color: const Color(0xFFFF6D00)),
  ]),
  CategoriaApi(emoji: '🤖', nombre: 'Inteligencia Artificial', items: [
    ApiIntegracion(id: 'openai',    nombre: 'OpenAI',               descripcion: 'GPT-4 para respuestas automáticas y resúmenes', icono: Icons.psychology_outlined,     color: const Color(0xFF10A37F)),
    ApiIntegracion(id: 'claude',    nombre: 'Anthropic Claude',     descripcion: 'IA avanzada para análisis de negocio',          icono: Icons.auto_awesome_outlined,   color: const Color(0xFFD4A574)),
  ]),
];

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────────────────────

void mostrarIntegracionesApis(BuildContext context, {bool dark = false, String empresaId = ''}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (_) => _IntegracionesSheet(dark: dark, empresaId: empresaId),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class _IntegracionesSheet extends StatefulWidget {
  final bool dark;
  final String empresaId;
  const _IntegracionesSheet({required this.dark, required this.empresaId});
  @override State<_IntegracionesSheet> createState() => _IntegracionesSheetState();
}

class _IntegracionesSheetState extends State<_IntegracionesSheet> {
  late List<CategoriaApi> _categorias;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filtro = 'todas'; // todas | conectadas | disponibles | proximamente
  final Set<String> _expanded = {};

  // ── Colores ──────────────────────────────────────────────────────────────
  bool get dk => widget.dark;
  Color get _bg      => dk ? const Color(0xFF0A0F23) : const Color(0xFFF8FAFC);
  Color get _surface => dk ? const Color(0xFF131929) : Colors.white;
  Color get _border  => dk ? const Color(0xFF2A2E45) : const Color(0xFFE8ECF0);
  Color get _text    => dk ? Colors.white : const Color(0xFF0F172A);
  Color get _sub     => dk ? const Color(0xFFB0B3C1) : const Color(0xFF64748B);
  Color get _muted   => dk ? const Color(0xFF5A5F7A) : const Color(0xFFA0AEC0);
  Color get _inputBg => dk ? const Color(0xFF1E2A42) : const Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _categorias = _buildCategorias();
    // Expandir primera categoría por defecto
    if (_categorias.isNotEmpty) _expanded.add(_categorias.first.nombre);
    _cargarEstados();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarEstados() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios').doc(uid)
          .collection('configuracion').doc('integraciones').get();
      if (!doc.exists || !mounted) return;
      final data = doc.data() ?? {};
      setState(() {
        for (final cat in _categorias) {
          for (final api in cat.items) {
            if (data[api.id] == true) api.activa = true;
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _toggleApi(ApiIntegracion api, bool value) async {
    setState(() => api.activa = value);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('usuarios').doc(uid)
          .collection('configuracion').doc('integraciones')
          .set({api.id: value}, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Filtrado ──────────────────────────────────────────────────────────────

  List<ApiIntegracion> _todosLosApis() =>
      _categorias.expand((c) => c.items).toList();

  bool _apiMatchesFilter(ApiIntegracion api) {
    final matchQuery = _query.isEmpty ||
        api.nombre.toLowerCase().contains(_query) ||
        api.descripcion.toLowerCase().contains(_query);
    if (!matchQuery) return false;
    switch (_filtro) {
      case 'conectadas':   return api.activa;
      case 'disponibles':  return !api.activa && api.estado == EstadoApi.disponible;
      case 'proximamente': return api.estado == EstadoApi.proximamente;
      default:             return true;
    }
  }

  int get _conectadas => _todosLosApis().where((a) => a.activa).length;
  int get _total      => _todosLosApis().length;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        _buildHandle(),
        _buildHeader(),
        _buildSearchBar(),
        _buildFilterChips(),
        Container(height: 1, color: _border),
        Expanded(child: _buildContent()),
      ]),
    );
  }

  // ── Handle ────────────────────────────────────────────────────────────────
  Widget _buildHandle() => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Center(child: Container(
      width: 36, height: 4,
      decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
    )),
  );

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF3B82F6).withValues(alpha: dk ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.api_rounded, color: Color(0xFF3B82F6), size: 19),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Integraciones', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _text, letterSpacing: -0.3)),
        Text('Conecta servicios externos a Fluix', style: TextStyle(fontSize: 12, color: _sub)),
      ])),
      // ── Contador ──────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _conectadas > 0
              ? const Color(0xFF10B981).withValues(alpha: dk ? 0.15 : 0.1)
              : _inputBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _conectadas > 0
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : _border),
        ),
        child: Text(
          '$_conectadas / $_total',
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: _conectadas > 0 ? const Color(0xFF10B981) : _sub,
          ),
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: _inputBg, shape: BoxShape.circle),
          child: Icon(Icons.close_rounded, color: _sub, size: 16),
        ),
      ),
    ]),
  );

  // ── Buscador ──────────────────────────────────────────────────────────────
  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Container(
      height: 40,
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        const SizedBox(width: 12),
        Icon(Icons.search_rounded, size: 16, color: _muted),
        const SizedBox(width: 8),
        Expanded(child: TextField(
          controller: _searchCtrl,
          style: TextStyle(fontSize: 13, color: _text),
          decoration: InputDecoration(
            hintText: 'Buscar integración...',
            hintStyle: TextStyle(fontSize: 13, color: _muted),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        )),
        if (_query.isNotEmpty)
          GestureDetector(
            onTap: () { _searchCtrl.clear(); setState(() => _query = ''); },
            child: Padding(padding: const EdgeInsets.only(right: 10),
              child: Icon(Icons.close_rounded, size: 14, color: _muted)),
          ),
      ]),
    ),
  );

  // ── Filtros ───────────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    final filters = [
      ('todas', 'Todas'),
      ('conectadas', 'Conectadas'),
      ('disponibles', 'Disponibles'),
      ('proximamente', 'Próximamente'),
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        children: filters.map((f) {
          final sel = _filtro == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _filtro = f.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF3B82F6) : _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? const Color(0xFF3B82F6) : _border),
                ),
                child: Text(f.$2, style: TextStyle(
                  fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                  color: sel ? Colors.white : _sub,
                )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Contenido ─────────────────────────────────────────────────────────────
  Widget _buildContent() {
    // Si hay búsqueda activa o filtro != todas, lista plana
    if (_query.isNotEmpty || _filtro != 'todas') {
      final items = _todosLosApis().where(_apiMatchesFilter).toList();
      if (items.isEmpty) return _buildEmpty();
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(height: 8),
        itemBuilder: (_, i) => _ApiCard(
          api: items[i], dark: dk,
          surface: _surface, border: _border,
          textC: _text, subC: _sub, muted: _muted,
          empresaId: widget.empresaId,
          onToggle: (v) => _toggleApi(items[i], v),
        ),
      );
    }

    // Vista de categorías colapsables
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      itemCount: _categorias.length,
      itemBuilder: (_, i) {
        final cat = _categorias[i];
        final isExpanded = _expanded.contains(cat.nombre);
        final conectadasEnCat = cat.items.where((a) => a.activa).length;
        return _CategoriaSection(
          categoria: cat,
          isExpanded: isExpanded,
          conectadas: conectadasEnCat,
          dark: dk,
          surface: _surface,
          border: _border,
          bg: _bg,
          textC: _text,
          subC: _sub,
          muted: _muted,
          empresaId: widget.empresaId,
          onToggleExpand: () => setState(() {
            if (isExpanded) _expanded.remove(cat.nombre);
            else _expanded.add(cat.nombre);
          }),
          onToggleApi: (api, v) => _toggleApi(api, v),
        );
      },
    );
  }

  Widget _buildEmpty() => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.search_off_rounded, size: 48, color: _muted),
      const SizedBox(height: 12),
      Text('Sin resultados', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _sub)),
      const SizedBox(height: 4),
      Text('Prueba con otro término o filtro', style: TextStyle(fontSize: 12.5, color: _muted)),
    ]),
  ));
}

// ─────────────────────────────────────────────────────────────────────────────
// SECCIÓN DE CATEGORÍA
// ─────────────────────────────────────────────────────────────────────────────

class _CategoriaSection extends StatelessWidget {
  final CategoriaApi categoria;
  final bool isExpanded;
  final int conectadas;
  final bool dark;
  final Color surface, border, bg, textC, subC, muted;
  final String empresaId;
  final VoidCallback onToggleExpand;
  final void Function(ApiIntegracion, bool) onToggleApi;

  const _CategoriaSection({
    required this.categoria, required this.isExpanded, required this.conectadas,
    required this.dark, required this.surface, required this.border, required this.bg,
    required this.textC, required this.subC, required this.muted,
    required this.empresaId,
    required this.onToggleExpand, required this.onToggleApi,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header de categoría ──────────────────────────────────────────
      GestureDetector(
        onTap: onToggleExpand,
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            Text(categoria.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 8),
            Expanded(child: Text(categoria.nombre,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textC))),
            if (conectadas > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: dark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$conectadas', style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
              ),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: subC),
            ),
          ]),
        ),
      ),
      // ── Cards de la categoría ────────────────────────────────────────
      AnimatedCrossFade(
        firstChild: const SizedBox.shrink(),
        secondChild: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(children: categoria.items.map((api) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ApiCard(
              api: api, dark: dark,
              surface: surface, border: border, textC: textC, subC: subC, muted: muted,
              empresaId: empresaId,
              onToggle: (v) => onToggleApi(api, v),
            ),
          )).toList()),
        ),
        crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 220),
        sizeCurve: Curves.easeInOut,
      ),
      Divider(height: 1, indent: 20, endIndent: 20, color: border),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TARJETA DE INTEGRACIÓN — guarda/carga API key real en Firestore
// ─────────────────────────────────────────────────────────────────────────────

class _ApiCard extends StatefulWidget {
  final ApiIntegracion api;
  final bool dark;
  final Color surface, border, textC, subC, muted;
  final String empresaId;
  final void Function(bool) onToggle;

  const _ApiCard({
    required this.api, required this.dark,
    required this.surface, required this.border,
    required this.textC, required this.subC, required this.muted,
    required this.empresaId,
    required this.onToggle,
  });

  @override
  State<_ApiCard> createState() => _ApiCardState();
}

class _ApiCardState extends State<_ApiCard> {
  bool _tieneKey = false;

  @override
  void initState() {
    super.initState();
    _verificarKey();
  }


  @override
  Widget build(BuildContext context) {
    final api = widget.api;
    final dark = widget.dark;
    final esProximamente = api.estado == EstadoApi.proximamente;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: api.activa
            ? api.color.withValues(alpha: dark ? 0.08 : 0.04)
            : widget.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: api.activa
              ? api.color.withValues(alpha: dark ? 0.3 : 0.2)
              : widget.border,
          width: api.activa ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        // ── Icono ────────────────────────────────────────────────────
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: esProximamente
                ? (dark ? const Color(0xFF1E2A42) : const Color(0xFFF1F5F9))
                : api.color.withValues(alpha: dark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(api.icono, size: 20,
              color: esProximamente ? widget.muted : api.color),
        ),
        const SizedBox(width: 12),
        // ── Info ─────────────────────────────────────────────────────
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text(api.nombre,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
                    color: esProximamente ? widget.muted : widget.textC))),
            if (_tieneKey && api.activa) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('✓ Key guardada',
                    style: TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
              ),
            ] else if (api.activa && !_tieneKey) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('⚠ Falta API Key',
                    style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.w700)),
              ),
            ] else if (esProximamente) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('Próximamente',
                    style: TextStyle(fontSize: 9.5, color: Colors.orange, fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
          const SizedBox(height: 2),
          Text(api.descripcion,
              style: TextStyle(fontSize: 11.5, color: widget.subC),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        const SizedBox(width: 10),
        // ── Acciones ─────────────────────────────────────────────────
        if (esProximamente)
          Icon(Icons.lock_outline_rounded, size: 16, color: widget.muted)
        else
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Switch(
              value: api.activa,
              onChanged: widget.onToggle,
              activeColor: api.color,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            if (api.activa)
              GestureDetector(
                onTap: () => _mostrarConfig(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: api.color.withValues(alpha: dark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: api.color.withValues(alpha: 0.25)),
                  ),
                  child: Text(_tieneKey ? 'Ver/Editar key' : 'Añadir API Key',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: api.color)),
                ),
              ),
          ]),
      ]),
    );
  }

  // ── Google Calendar — diálogo OAuth (sin API key) ───────────────────────

  void _mostrarConfigGoogleCalendar(BuildContext context) {
    final dark2 = widget.dark;
    final cardC = dark2 ? const Color(0xFF1E2139) : Colors.white;
    final textC2= dark2 ? Colors.white : const Color(0xFF0F172A);
    final subC2 = dark2 ? const Color(0xFFB0B3C1) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardC,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        title: Row(children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF4285F4).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.calendar_month_outlined,
              color: Color(0xFF4285F4), size: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text('Google Calendar',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textC2))),
          GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Icon(Icons.close_rounded, color: subC2, size: 18)),
        ]),
        content: Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.2)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded,
                  size: 15, color: Color(0xFF4285F4)),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Google Calendar usa tu cuenta Google directamente.\n'
                  'Al activar la integración se pedirá permiso para '
                  'añadir eventos a tu calendario.',
                  style: TextStyle(fontSize: 11.5, color: subC2, height: 1.4),
                )),
              ]),
            ),
            const SizedBox(height: 14),
            Text('Las reservas confirmadas se añadirán automáticamente '
                'a tu Google Calendar con recordatorios.',
              style: TextStyle(fontSize: 12, color: subC2),
              textAlign: TextAlign.center),
          ]),
        ),
        actions: [Row(children: [
          const Spacer(),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              foregroundColor: subC2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            child: const Text('Cerrar', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Entendido', style: TextStyle(fontSize: 13)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
          ),
        ])],
      ),
    );
  }

  // ── Diálogo genérico multi-campo (Twilio, SMTP…) ─────────────────────────

  void _mostrarConfigMultiField(
    BuildContext context,
    List<(String label, String keyId, String hint)> campos,
  ) {
    final api   = widget.api;
    final dark2 = widget.dark;
    final cardC = dark2 ? const Color(0xFF1E2139) : Colors.white;
    final textC2= dark2 ? Colors.white : const Color(0xFF0F172A);
    final subC2 = dark2 ? const Color(0xFFB0B3C1) : const Color(0xFF64748B);
    final fillC = dark2 ? const Color(0xFF0D1627) : const Color(0xFFF8FAFC);
    final borC  = dark2 ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0);
    final ctrls = List.generate(campos.length, (_) => TextEditingController());
    bool guardando = false;

    for (int i = 0; i < campos.length; i++) {
      IaService().obtenerApiKey(campos[i].$2).then((v) {
        if (v != null) ctrls[i].text = v;
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: cardC,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          title: Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(
                color: api.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(api.icono, color: api.color, size: 16)),
            const SizedBox(width: 10),
            Expanded(child: Text('Configurar ${api.nombre}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textC2))),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Icon(Icons.close_rounded, color: subC2, size: 18)),
          ]),
          content: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: campos.asMap().entries.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: e.key < campos.length - 1 ? 12 : 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.value.$1, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: subC2)),
                    const SizedBox(height: 5),
                    TextField(
                      controller: ctrls[e.key],
                      obscureText: e.value.$2.contains('token') ||
                                   e.value.$2.contains('password'),
                      style: TextStyle(fontSize: 12.5, color: textC2,
                        fontFamily: 'monospace'),
                      decoration: InputDecoration(
                        hintText: e.value.$3,
                        hintStyle: TextStyle(color: subC2, fontSize: 12,
                          fontFamily: 'monospace'),
                        prefixIcon: Icon(Icons.key_outlined, size: 16, color: subC2),
                        filled: true, fillColor: fillC,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: borC)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: api.color, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 11),
                        isDense: true,
                      ),
                    ),
                  ]),
                )).toList(),
              ),
            ),
          ),
          actions: [Row(children: [
            if (_tieneKey)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 18),
                tooltip: 'Eliminar configuración',
                onPressed: () async {
                  for (final c in campos) {
                    await IaService().eliminarApiKey(c.$2);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _verificarKey();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(foregroundColor: subC2,
                side: BorderSide(color: borC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: guardando ? null : () async {
                if (ctrls.any((c) => c.text.trim().isEmpty)) return;
                setDlg(() => guardando = true);
                for (int i = 0; i < campos.length; i++) {
                  await IaService().guardarApiKey(
                    campos[i].$2, ctrls[i].text.trim());
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _verificarKey();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Row(children: [
                      const Icon(Icons.check_circle,
                        color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text('${api.nombre} configurado'),
                    ]),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              },
              style: FilledButton.styleFrom(backgroundColor: api.color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              child: guardando
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                : const Text('Guardar',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ])],
        ),
      ),
    );
  }

  // ── Stripe — diálogo completo con instrucciones y almacenamiento empresa ─────
  void _mostrarConfigStripe(BuildContext context) {
    final dark2  = widget.dark;
    final cardC  = dark2 ? const Color(0xFF1E2139) : Colors.white;
    final textC2 = dark2 ? Colors.white : const Color(0xFF0F172A);
    final subC2  = dark2 ? const Color(0xFFB0B3C1) : const Color(0xFF64748B);
    final fillC  = dark2 ? const Color(0xFF0D1627) : const Color(0xFFF8FAFC);
    final borC   = dark2 ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0);
    const stripeColor = Color(0xFF635BFF);

    final keyCtrl    = TextEditingController();
    final webhookCtrl = TextEditingController();
    bool guardando   = false;
    bool keyOculta   = true;
    bool webhookOculto = true;
    int tab = 0; // 0=Conectar, 1=Instrucciones

    const webhookUrl =
        'https://europe-west1-planeaapp-4bea4.cloudfunctions.net/stripeWebhookTienda';
    final empresaId = widget.empresaId;

    // Pre-cargar valores existentes de empresa
    if (empresaId.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('empresas').doc(empresaId)
          .collection('integraciones').doc('stripe')
          .get().then((doc) {
        if (doc.exists) {
          keyCtrl.text    = doc.data()?['secret_key']         ?? '';
          webhookCtrl.text = doc.data()?['webhook_secret']    ?? '';
        }
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: cardC,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          title: Row(children: [
            Container(width: 34, height: 34,
              decoration: BoxDecoration(
                color: stripeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.credit_card_outlined, color: stripeColor, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text('Conectar Stripe',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textC2))),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Icon(Icons.close_rounded, color: subC2, size: 18)),
          ]),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Tabs ───────────────────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: dark2 ? const Color(0xFF0D1627) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(children: [
                        _tabBtn('Configurar', tab == 0, stripeColor, textC2, subC2,
                            () => setDlg(() => tab = 0)),
                        const SizedBox(width: 4),
                        _tabBtn('Instrucciones', tab == 1, stripeColor, textC2, subC2,
                            () => setDlg(() => tab = 1)),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    if (tab == 0) ...[
                      // ── Empresa ID ──────────────────────────────────────
                      if (empresaId.isNotEmpty) ...[
                        Text('Tu empresa ID', style: TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600, color: subC2)),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: stripeColor.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(color: stripeColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(children: [
                            Expanded(child: Text(empresaId,
                              style: TextStyle(fontFamily: 'monospace',
                                fontSize: 12, color: stripeColor, fontWeight: FontWeight.w600))),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: empresaId));
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('ID copiado al portapapeles'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ));
                              },
                              child: const Icon(Icons.copy_rounded,
                                size: 14, color: stripeColor),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 4),
                        Text('Añade este valor como metadata empresa_id en tu checkout Stripe.',
                          style: TextStyle(fontSize: 10.5, color: subC2)),
                        const SizedBox(height: 14),
                      ],

                      // ── Secret key ──────────────────────────────────────
                      Text('Clave secreta de Stripe (sk_live_...)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: subC2)),
                      const SizedBox(height: 5),
                      TextField(
                        controller: keyCtrl,
                        obscureText: keyOculta,
                        style: TextStyle(fontSize: 12, color: textC2, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'Introduce tu clave secreta de Stripe',
                          hintStyle: TextStyle(color: subC2, fontSize: 12, fontFamily: 'monospace'),
                          prefixIcon: const Icon(Icons.key_outlined, size: 16, color: stripeColor),
                          suffixIcon: IconButton(
                            icon: Icon(keyOculta
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                                size: 16, color: subC2),
                            onPressed: () => setDlg(() => keyOculta = !keyOculta),
                          ),
                          filled: true, fillColor: fillC,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borC)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: stripeColor, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Webhook secret ──────────────────────────────────
                      Text('Signing secret del webhook (whsec_...)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: subC2)),
                      const SizedBox(height: 5),
                      TextField(
                        controller: webhookCtrl,
                        obscureText: webhookOculto,
                        style: TextStyle(fontSize: 12, color: textC2, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          hintText: 'whsec_xxxxxxxxxxxxxxxxxxxxxxxx',
                          hintStyle: TextStyle(color: subC2, fontSize: 12, fontFamily: 'monospace'),
                          prefixIcon: const Icon(Icons.webhook_outlined, size: 16, color: stripeColor),
                          suffixIcon: IconButton(
                            icon: Icon(webhookOculto
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                                size: 16, color: subC2),
                            onPressed: () => setDlg(() => webhookOculto = !webhookOculto),
                          ),
                          filled: true, fillColor: fillC,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borC)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: stripeColor, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── URL webhook ─────────────────────────────────────
                      Text('URL del webhook (configura en Stripe)',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: subC2)),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: fillC,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: borC),
                        ),
                        child: Row(children: [
                          Expanded(child: Text(webhookUrl,
                            style: TextStyle(fontFamily: 'monospace',
                              fontSize: 10.5, color: subC2))),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(const ClipboardData(text: webhookUrl));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('URL copiada al portapapeles'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ));
                            },
                            child: Icon(Icons.copy_rounded, size: 14, color: subC2),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 4),
                      Text('Evento a escuchar: checkout.session.completed',
                        style: TextStyle(fontSize: 10.5, color: subC2)),
                    ],

                    if (tab == 1) ...[
                      // ── Instrucciones ───────────────────────────────────
                      _infoBox('Tipo de clave recomendado',
                        'Usa una Clave restringida (Restricted Key) en lugar de la clave secreta completa. '
                        'Es más seguro y solo concede los permisos que Fluix necesita.',
                        stripeColor, fillC, dark2),
                      const SizedBox(height: 12),
                      Text('Permisos necesarios en la Restricted Key',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textC2)),
                      const SizedBox(height: 8),
                      ..._permisosStripe(textC2, subC2, dark2),
                      const SizedBox(height: 14),
                      _infoBox('Cómo obtener la clave',
                        '1. Ve a dashboard.stripe.com\n'
                        '2. Developers → API Keys → Create restricted key\n'
                        '3. Activa los permisos de la lista de arriba\n'
                        '4. Copia la clave y pégala en la pestaña Configurar',
                        const Color(0xFF3B82F6), fillC, dark2),
                      const SizedBox(height: 12),
                      _infoBox('Cómo configurar el webhook',
                        '1. Developers → Webhooks → Add endpoint\n'
                        '2. URL: la que aparece en la pestaña Configurar\n'
                        '3. Evento: checkout.session.completed\n'
                        '4. Copia el Signing secret y pégalo en Fluix',
                        const Color(0xFF10B981), fillC, dark2),
                      const SizedBox(height: 12),
                      _infoBox('Metadata obligatorio en el checkout',
                        'Cada sesión de checkout creada en tu web debe incluir:\n\n'
                        '  metadata: {\n'
                        '    empresa_id: "$empresaId",\n'
                        '    tipo: "pedido_tienda"\n'
                        '  }',
                        stripeColor, fillC, dark2),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [Row(children: [
            if (_tieneKey && tab == 0)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                tooltip: 'Desconectar Stripe',
                onPressed: () async {
                  if (empresaId.isNotEmpty) {
                    await FirebaseFirestore.instance
                        .collection('empresas').doc(empresaId)
                        .collection('integraciones').doc('stripe')
                        .update({'secret_key': '', 'webhook_secret': '', 'connected': false});
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _verificarKey();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(foregroundColor: subC2,
                side: BorderSide(color: borC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              child: const Text('Cerrar', style: TextStyle(fontSize: 13)),
            ),
            if (tab == 0) ...[
              const SizedBox(width: 8),
              FilledButton(
                onPressed: guardando ? null : () async {
                  final key = keyCtrl.text.trim();
                  if (key.isEmpty) return;
                  setDlg(() => guardando = true);
                  try {
                    if (empresaId.isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('empresas').doc(empresaId)
                          .collection('integraciones').doc('stripe')
                          .set({
                        'secret_key':     key,
                        'webhook_secret': webhookCtrl.text.trim(),
                        'connected':      true,
                        'activo':         true,
                        'updated_at':     FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                    } else {
                      await IaService().guardarApiKey('stripe', key);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _verificarKey();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Row(children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text('Stripe conectado correctamente'),
                        ]),
                        backgroundColor: Color(0xFF10B981),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  } finally {
                    if (ctx.mounted) setDlg(() => guardando = false);
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: stripeColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                child: guardando
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ])],
        ),
      ),
    );
  }

  Widget _tabBtn(String label, bool sel, Color active, Color textC, Color subC, VoidCallback onTap) =>
    Expanded(child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: sel ? active : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.w600,
          color: sel ? Colors.white : subC)),
      ),
    ));

  Widget _infoBox(String titulo, String body, Color color, Color bg, bool dark) =>
    Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_outline_rounded, size: 13, color: color),
          const SizedBox(width: 6),
          Text(titulo, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 6),
        Text(body, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.85), height: 1.5,
          fontFamily: body.contains('{') ? 'monospace' : null)),
      ]),
    );

  List<Widget> _permisosStripe(Color textC, Color subC, bool dark) {
    const permisos = [
      ('Checkout Sessions', 'Write', '✓ Crear sesiones de pago'),
      ('Products', 'Write', '✓ Sincronizar catálogo'),
      ('Prices', 'Write', '✓ Gestionar precios'),
      ('Payment Intents', 'Read', '✓ Verificar pagos'),
      ('Webhook Endpoints', 'Read', '✓ Confirmar webhooks'),
    ];
    return permisos.map((p) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF635BFF).withValues(alpha: dark ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(p.$1,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF635BFF))),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: (p.$2 == 'Write' ? Colors.orange : Colors.green).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(p.$2,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600,
              color: p.$2 == 'Write' ? Colors.orange : Colors.green)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(p.$3,
          style: TextStyle(fontSize: 11, color: subC))),
      ]),
    )).toList();
  }

  // ── Leer stripe key a nivel empresa para verificar ────────────────────────
  Future<void> _verificarKey() async {
    bool tiene = false;
    if (widget.api.id == 'stripe' && widget.empresaId.isNotEmpty) {
      final doc = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('integraciones').doc('stripe').get();
      tiene = doc.exists && (doc.data()?['secret_key'] ?? '').toString().isNotEmpty;
    } else if (widget.api.id == 'twilio') {
      final sid = await IaService().obtenerApiKey('twilio_sid');
      tiene = sid != null && sid.isNotEmpty;
    } else if (widget.api.id == 'smtp') {
      final host = await IaService().obtenerApiKey('smtp_host');
      tiene = host != null && host.isNotEmpty;
    } else if (widget.api.id == 'gcal') {
      tiene = widget.api.activa;
    } else {
      final key = await IaService().obtenerApiKey(widget.api.id);
      tiene = key != null && key.isNotEmpty;
    }
    if (mounted) setState(() => _tieneKey = tiene);
  }

  void _mostrarConfig(BuildContext context) {
    if (widget.api.id == 'stripe') {
      _mostrarConfigStripe(context);
      return;
    }
    if (widget.api.id == 'twilio') {
      _mostrarConfigMultiField(context, [
        ('Account SID', 'twilio_sid', 'ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'),
        ('Auth Token', 'twilio_token', 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'),
        ('Teléfono remitente (E.164)', 'twilio_from', '+34600000000'),
      ]);
      return;
    }
    if (widget.api.id == 'smtp') {
      _mostrarConfigMultiField(context, [
        ('Servidor SMTP', 'smtp_host', 'smtp.gmail.com'),
        ('Puerto', 'smtp_port', '587'),
        ('Usuario', 'smtp_user', 'tu@empresa.com'),
        ('Contraseña / App Password', 'smtp_password', '••••••••'),
        ('Email de envío', 'smtp_from', 'tu@empresa.com'),
      ]);
      return;
    }
    if (widget.api.id == 'gcal') {
      _mostrarConfigGoogleCalendar(context);
      return;
    }
    final api  = widget.api;
    final dark2  = widget.dark;
    final cardC  = dark2 ? const Color(0xFF1E2139) : Colors.white;
    final textC2 = dark2 ? Colors.white : const Color(0xFF0F172A);
    final subC2  = dark2 ? const Color(0xFFB0B3C1) : const Color(0xFF64748B);
    final fillC  = dark2 ? const Color(0xFF0D1627) : const Color(0xFFF8FAFC);
    final borC   = dark2 ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0);

    final keyCtrl = TextEditingController();
    bool guardando = false;
    bool keyOculta = true;

    // Pre-cargar la key existente
    IaService().obtenerApiKey(api.id).then((k) {
      if (k != null) keyCtrl.text = k;
    });

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: cardC,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          title: Row(children: [
            Container(width: 32, height: 32,
                decoration: BoxDecoration(
                    color: api.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(api.icono, color: api.color, size: 16)),
            const SizedBox(width: 10),
            Expanded(child: Text('Configurar ${api.nombre}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textC2))),
            GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Icon(Icons.close_rounded, color: subC2, size: 18)),
          ]),
          content: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Ayuda
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: api.color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: api.color.withValues(alpha: 0.2))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: api.color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _ayudaApiKey(api.id),
                    style: TextStyle(fontSize: 11, color: api.color, height: 1.4),
                  )),
                ]),
              ),
              const SizedBox(height: 12),
              // Campo API Key
              Text('API Key', style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: subC2)),
              const SizedBox(height: 6),
              TextField(
                controller: keyCtrl,
                obscureText: keyOculta,
                style: TextStyle(fontSize: 12.5, color: textC2, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: _hintApiKey(api.id),
                  hintStyle: TextStyle(color: subC2, fontSize: 12, fontFamily: 'monospace'),
                  prefixIcon: Icon(Icons.key_outlined, size: 16, color: subC2),
                  suffixIcon: IconButton(
                    icon: Icon(
                        keyOculta ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 16, color: subC2),
                    onPressed: () => setDlg(() => keyOculta = !keyOculta),
                  ),
                  filled: true, fillColor: fillC,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borC)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: api.color, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _abrirDocumentacion(api.id),
                child: Row(children: [
                  Icon(Icons.open_in_new_rounded, size: 11, color: subC2),
                  const SizedBox(width: 4),
                  Text('Obtener API Key →', style: TextStyle(
                      fontSize: 11, color: subC2, decoration: TextDecoration.underline)),
                ]),
              ),
            ]),
          ),
          actions: [
            Row(children: [
              if (_tieneKey)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                  tooltip: 'Eliminar key',
                  onPressed: () async {
                    await IaService().eliminarApiKey(api.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _verificarKey();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(foregroundColor: subC2,
                    side: BorderSide(color: borC),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: guardando ? null : () async {
                  final key = keyCtrl.text.trim();
                  if (key.isEmpty) return;
                  setDlg(() => guardando = true);
                  await IaService().guardarApiKey(api.id, key);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _verificarKey();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text('API Key de ${api.nombre} guardada'),
                      ]),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                    ));
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: api.color,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
                child: guardando
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _ayudaApiKey(String apiId) {
    switch (apiId) {
      case 'openai':  return 'Entra en platform.openai.com → API Keys → Create new secret key. Empieza por "sk-..."';
      case 'claude':  return 'Entra en console.anthropic.com → API Keys. Empieza por "sk-ant-..."';
      case 'twilio':  return 'Entra en console.twilio.com → Cuenta → Credenciales. Necesitas el Account SID, Auth Token y tu número de teléfono Twilio.';
      case 'gmail':   return 'Activa la API de Gmail en Google Cloud Console y genera una clave OAuth2.';
      case 'stripe':  return 'Entra en dashboard.stripe.com → Developers → API Keys.';
      case 'mailchimp': return 'En Mailchimp: Perfil → Extras → API Keys → Create A Key.';
      case 'holded':   return 'En Holded: Configuración → API → Generar nueva API Key.';
      case 'brevo':    return 'En Brevo: Mi cuenta → SMTP & API → API Keys → Generar nueva clave.';
      case 'paypal':   return 'En PayPal Developer: dashboard.paypal.com → Apps & Credentials → Crear app.';
      default: return 'Introduce tu clave de API para conectar ${apiId.toUpperCase()} con Fluix.';
    }
  }

  String _hintApiKey(String apiId) {
    switch (apiId) {
      case 'openai':  return 'sk-proj-...';
      case 'claude':  return 'sk-ant-api03-...';
      case 'twilio':  return 'ACxxxxxxxx...';
      case 'stripe':  return 'sk_live_...';
      default: return 'Pega tu API Key aquí';
    }
  }

  void _abrirDocumentacion(String apiId) {
    // Solo informativo — el usuario copiará la URL
    final urls = {
      'openai':   'platform.openai.com/api-keys',
      'claude':   'console.anthropic.com/keys',
      'twilio':   'console.twilio.com',
      'stripe':   'dashboard.stripe.com/apikeys',
      'mailchimp':'mailchimp.com/account/api',
    };
    final url = urls[apiId] ?? '';
    if (url.isNotEmpty && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ve a: $url'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ));
    }
  }
}

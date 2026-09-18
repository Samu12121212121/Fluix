import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/app_settings.dart';
import '../../../domain/modelos/sugerencia_empresa.dart';
import '../../../services/sugerencias_service.dart';
import '../../../services/contacto_soporte_service.dart';
import '../../../core/widgets/flux_toast.dart';

// ── Pantalla de Soporte y Ayuda ───────────────────────────────────────────────
// Secciones: Accesos rápidos | Tutoriales | Mejoras | Contáctanos
// Responsive: columna única en móvil, dos columnas en tablet/desktop.
// ─────────────────────────────────────────────────────────────────────────────

const _kAccent = Color(0xFF6D5EF8);
const _kGold   = Color(0xFFF59E0B);
const _kGreen  = Color(0xFF10B981);
const _kRed    = Color(0xFFEF4444);

class ModuloSoporteScreen extends StatefulWidget {
  final String empresaId;
  final String nombreEmpresa;
  final String autorUid;
  const ModuloSoporteScreen({
    super.key,
    required this.empresaId,
    required this.nombreEmpresa,
    required this.autorUid,
  });

  @override
  State<ModuloSoporteScreen> createState() => _State();
}

class _State extends State<ModuloSoporteScreen> {
  bool _isDark = false;
  void _onDark() { if (mounted) setState(() => _isDark = AppSettings.darkMode.value); }

  @override
  void initState() {
    super.initState();
    _isDark = AppSettings.darkMode.value;
    AppSettings.darkMode.addListener(_onDark);
  }
  @override
  void dispose() { AppSettings.darkMode.removeListener(_onDark); super.dispose(); }

  Color get _bg   => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  Color get _surf => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _text => _isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _sub  => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280);
  Color get _bdr  => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w >= 800;
    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isWide ? 24 : 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _header(),
          const SizedBox(height: 20),
          _quickActions(),
          const SizedBox(height: 20),
          if (isWide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: Column(children: [
                _tutorialesSection(),
                const SizedBox(height: 20),
                _contactoCard(),
              ])),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: _sugerenciasCard()),
            ])
          else
            Column(children: [
              _tutorialesSection(),
              const SizedBox(height: 20),
              _sugerenciasCard(),
              const SizedBox(height: 20),
              _contactoCard(),
            ]),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _header() => Row(children: [
    Container(
      width: 44, height: 44,
      decoration: BoxDecoration(color: _kAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.support_agent_rounded, color: _kAccent, size: 22),
    ),
    const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Soporte y Ayuda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _text)),
      Text('¿En qué podemos ayudarte?', style: TextStyle(fontSize: 12, color: _sub)),
    ]),
  ]);

  // ── Accesos rápidos ───────────────────────────────────────────────────────

  Widget _quickActions() => Row(children: [
    Expanded(child: _actionCard(Icons.play_circle_rounded, 'Tutoriales', 'Vídeos por módulo', _kGold, _abrirTutoriales)),
    const SizedBox(width: 12),
    Expanded(child: _actionCard(Icons.lightbulb_rounded, 'Mejoras', 'Envía una sugerencia', _kGreen, () {})),
    const SizedBox(width: 12),
    Expanded(child: _actionCard(Icons.mail_rounded, 'Contáctanos', 'Escríbenos directamente', _kRed, () {})),
  ]);

  Widget _actionCard(IconData icon, String title, String sub, Color color, VoidCallback onTap) =>
    GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: _surf, borderRadius: BorderRadius.circular(12), border: Border.all(color: _bdr),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isDark ? 0.25 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(icon, color: color, size: 18)),
        const SizedBox(height: 8),
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _text)),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 9.5, color: _sub), textAlign: TextAlign.center),
      ]),
    ));

  // ── Tutoriales ────────────────────────────────────────────────────────────

  Widget _tutorialesSection() => _card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle(Icons.play_circle_rounded, 'Tutoriales en vídeo', _kGold),
      const SizedBox(height: 8),
      Text('Aprende a usar cada módulo con vídeos explicativos paso a paso.',
        style: TextStyle(fontSize: 12, color: _sub, height: 1.5)),
      const SizedBox(height: 14),
      _videoModulos(),
      const SizedBox(height: 16),
      GestureDetector(
        onTap: _abrirTutoriales,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFF97316)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.open_in_new_rounded, color: Colors.white, size: 15),
            SizedBox(width: 7),
            Text('Ver todos los tutoriales', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
        ),
      ),
    ]),
  );

  Widget _videoModulos() {
    const modulos = [
      (Icons.receipt_long_rounded, 'Facturación', Color(0xFF10B981)),
      (Icons.people_alt_rounded, 'Clientes', Color(0xFF3B82F6)),
      (Icons.point_of_sale_rounded, 'TPV', Color(0xFFF59E0B)),
      (Icons.badge_rounded, 'Personal', Color(0xFF8B5CF6)),
      (Icons.inventory_2_rounded, 'Pedidos', Color(0xFFEC4899)),
      (Icons.language_rounded, 'Web', Color(0xFF22D3EE)),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: modulos.map((m) =>
      GestureDetector(
        onTap: _abrirTutoriales,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: m.$3.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: m.$3.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(m.$1, size: 13, color: m.$3),
            const SizedBox(width: 5),
            Text(m.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: m.$3)),
            const SizedBox(width: 4),
            Icon(Icons.play_arrow_rounded, size: 12, color: m.$3),
          ]),
        ),
      ),
    ).toList());
  }

  Future<void> _abrirTutoriales() async {
    final uri = Uri.parse('https://fluixapp.es/tutoriales');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── Mejoras y sugerencias ─────────────────────────────────────────────────

  Widget _sugerenciasCard() => _card(
    child: _SugerenciasWidget(
      empresaId: widget.empresaId,
      nombreEmpresa: widget.nombreEmpresa,
      autorUid: widget.autorUid,
      isDark: _isDark,
      surf: _surf, text: _text, sub: _sub, bdr: _bdr,
    ),
  );

  // ── Contáctanos ───────────────────────────────────────────────────────────

  Widget _contactoCard() => _card(
    child: _ContactoWidget(
      empresaId: widget.empresaId,
      nombreEmpresa: widget.nombreEmpresa,
      isDark: _isDark,
      surf: _surf, text: _text, sub: _sub, bdr: _bdr,
    ),
  );

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _surf, borderRadius: BorderRadius.circular(14), border: Border.all(color: _bdr),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _isDark ? 0.22 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: child,
  );

  Widget _sectionTitle(IconData icon, String title, Color color) => Row(children: [
    Icon(icon, size: 16, color: color),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _text)),
  ]);
}

// ── Widget de mejoras/sugerencias ─────────────────────────────────────────────

class _SugerenciasWidget extends StatefulWidget {
  final String empresaId, nombreEmpresa, autorUid;
  final bool isDark;
  final Color surf, text, sub, bdr;
  const _SugerenciasWidget({
    required this.empresaId, required this.nombreEmpresa, required this.autorUid,
    required this.isDark, required this.surf, required this.text, required this.sub, required this.bdr,
  });
  @override
  State<_SugerenciasWidget> createState() => _SugerenciasWidgetState();
}

class _SugerenciasWidgetState extends State<_SugerenciasWidget> {
  final _ctrl = TextEditingController();
  final _svc  = SugerenciasService();
  bool _sending = false;
  bool _showHistory = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _enviar() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _svc.guardarSugerencia(
        empresaId: widget.empresaId,
        texto: text,
        nombreEmpresa: widget.nombreEmpresa.isEmpty ? 'Sin nombre' : widget.nombreEmpresa,
        autorUid: widget.autorUid,
      );
      _ctrl.clear();
      if (mounted) {
        setState(() => _showHistory = true);
        FluxToast.exito(context, '¡Sugerencia enviada! Gracias por tu feedback.');
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al enviar: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.lightbulb_rounded, size: 16, color: _kGreen),
        const SizedBox(width: 8),
        Text('Mejoras y sugerencias', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: widget.text)),
        const Spacer(),
        TextButton.icon(
          onPressed: () => setState(() => _showHistory = !_showHistory),
          icon: Icon(_showHistory ? Icons.expand_less : Icons.history, size: 15, color: _kGreen),
          label: Text(_showHistory ? 'Ocultar' : 'Historial', style: const TextStyle(fontSize: 11, color: _kGreen)),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ),
      ]),
      const SizedBox(height: 6),
      Text('Propón mejoras o nuevas funcionalidades para la app.',
        style: TextStyle(fontSize: 11.5, color: widget.sub, height: 1.4)),
      const SizedBox(height: 12),
      _inputBox(widget.isDark, widget.bdr, widget.text, widget.sub,
        controller: _ctrl, hint: '"Necesitaría poder exportar nóminas a Excel..."', maxLines: 4),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerRight,
        child: _submitBtn('Enviar sugerencia', Icons.send_rounded, _kGreen, _sending, _enviar),
      ),
      if (_showHistory) ...[
        const SizedBox(height: 16),
        StreamBuilder<List<SugerenciaEmpresa>>(
          stream: _svc.obtenerSugerencias(widget.empresaId),
          builder: (ctx, snap) {
            final lista = snap.data ?? [];
            if (lista.isEmpty) return Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Aún no has enviado ninguna sugerencia.', style: TextStyle(fontSize: 12, color: widget.sub)),
            ));
            return Column(children: lista.take(5).map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.texto, style: TextStyle(fontSize: 12, color: widget.text, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.access_time_rounded, size: 10, color: widget.sub),
                  const SizedBox(width: 3),
                  Text('${s.fechaCreacion.day.toString().padLeft(2,"0")}/${s.fechaCreacion.month.toString().padLeft(2,"0")}/${s.fechaCreacion.year}',
                    style: TextStyle(fontSize: 10, color: widget.sub)),
                ]),
              ]),
            )).toList());
          },
        ),
      ],
    ]);
  }
}

// ── Formulario de contacto ────────────────────────────────────────────────────

class _ContactoWidget extends StatefulWidget {
  final String empresaId, nombreEmpresa;
  final bool isDark;
  final Color surf, text, sub, bdr;
  const _ContactoWidget({
    required this.empresaId, required this.nombreEmpresa,
    required this.isDark, required this.surf, required this.text, required this.sub, required this.bdr,
  });
  @override
  State<_ContactoWidget> createState() => _ContactoWidgetState();
}

class _ContactoWidgetState extends State<_ContactoWidget> {
  final _nombre  = TextEditingController();
  final _email   = TextEditingController();
  final _mensaje = TextEditingController();
  String _asunto = 'Consulta general';
  bool _sending = false;
  bool _enviado = false;
  final _svc = ContactoSoporteService();

  static const _asuntos = [
    'Consulta general',
    'Error o bug',
    'Solicitud de función',
    'Problema con facturación',
    'Integración o API',
    'Otro',
  ];

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _mensaje.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final nombre  = _nombre.text.trim();
    final email   = _email.text.trim();
    final mensaje = _mensaje.text.trim();
    if (nombre.isEmpty || email.isEmpty || mensaje.isEmpty) {
      FluxToast.error(context, 'Rellena todos los campos antes de enviar.');
      return;
    }
    setState(() => _sending = true);
    try {
      await _svc.enviar(
        empresaId:      widget.empresaId,
        empresaNombre:  widget.nombreEmpresa.isEmpty ? 'Sin nombre' : widget.nombreEmpresa,
        nombreContacto: nombre,
        emailContacto:  email,
        asunto:         _asunto,
        mensaje:        mensaje,
      );
      if (mounted) {
        setState(() { _enviado = true; _sending = false; });
        _nombre.clear(); _email.clear(); _mensaje.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        FluxToast.error(context, 'Error al enviar: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.mail_rounded, size: 16, color: _kRed),
        const SizedBox(width: 8),
        Text('Contáctanos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: widget.text)),
      ]),
      const SizedBox(height: 6),
      Text('Envíanos un mensaje y te respondemos en menos de 24 h.',
        style: TextStyle(fontSize: 11.5, color: widget.sub, height: 1.4)),
      const SizedBox(height: 14),

      if (_enviado)
        _successBanner()
      else ...[
        // Nombre + Email en fila
        Row(children: [
          Expanded(child: _inputBox(widget.isDark, widget.bdr, widget.text, widget.sub,
            controller: _nombre, hint: 'Nombre', maxLines: 1)),
          const SizedBox(width: 10),
          Expanded(child: _inputBox(widget.isDark, widget.bdr, widget.text, widget.sub,
            controller: _email, hint: 'Email de contacto', maxLines: 1,
            keyboardType: TextInputType.emailAddress)),
        ]),
        const SizedBox(height: 10),
        // Asunto dropdown
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.bdr),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _asunto,
              isExpanded: true,
              style: TextStyle(fontSize: 13, color: widget.text),
              dropdownColor: widget.surf,
              icon: Icon(Icons.expand_more_rounded, size: 18, color: widget.sub),
              onChanged: (v) { if (v != null) setState(() => _asunto = v); },
              items: _asuntos.map((s) => DropdownMenuItem(
                value: s,
                child: Text(s, style: TextStyle(fontSize: 13, color: widget.text)),
              )).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Mensaje
        _inputBox(widget.isDark, widget.bdr, widget.text, widget.sub,
          controller: _mensaje, hint: 'Describe tu consulta con el mayor detalle posible...', maxLines: 5),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: _submitBtn('Enviar mensaje', Icons.send_rounded, _kRed, _sending, _enviar),
        ),
      ],
    ]);
  }

  Widget _successBanner() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kGreen.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
    ),
    child: Column(children: [
      const Icon(Icons.check_circle_rounded, color: _kGreen, size: 32),
      const SizedBox(height: 8),
      Text('¡Mensaje enviado!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: widget.text)),
      const SizedBox(height: 4),
      Text('Te responderemos en menos de 24 horas a tu email.',
        style: TextStyle(fontSize: 12, color: widget.sub), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => setState(() => _enviado = false),
        child: const Text('Enviar otro mensaje', style: TextStyle(fontSize: 12, color: _kRed)),
      ),
    ]),
  );
}

// ── Helpers compartidos ────────────────────────────────────────────────────────

Widget _inputBox(bool isDark, Color bdr, Color textColor, Color subColor, {
  required TextEditingController controller,
  required String hint,
  required int maxLines,
  TextInputType keyboardType = TextInputType.text,
}) => Container(
  decoration: BoxDecoration(
    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: bdr),
  ),
  child: TextField(
    controller: controller,
    maxLines: maxLines,
    style: TextStyle(fontSize: 13, color: textColor),
    keyboardType: keyboardType,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12, color: subColor),
      contentPadding: const EdgeInsets.all(12),
      border: InputBorder.none,
    ),
  ),
);

Widget _submitBtn(String label, IconData icon, Color color, bool loading, VoidCallback onTap) =>
  ElevatedButton.icon(
    onPressed: loading ? null : onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
    icon: loading
      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
      : Icon(icon, size: 15),
    label: Text(loading ? 'Enviando...' : label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
  );

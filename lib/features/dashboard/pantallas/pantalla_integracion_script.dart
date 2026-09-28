import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/contenido_web_service.dart';

// ignore_for_file: use_build_context_synchronously

// ═════════════════════════════════════════════════════════════════════════════
// PANEL DE INTEGRACIÓN WEB — Fluix Web SDK
// Muestra módulos detectados en la web, suscriptores push y permite copiar SDK
// ═════════════════════════════════════════════════════════════════════════════

class PantallaIntegracionScript extends StatelessWidget {
  final String empresaId;
  const PantallaIntegracionScript({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Integración Web'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SdkStatusCard(empresaId: empresaId),
          const SizedBox(height: 14),
          _ModulosDetectadosCard(empresaId: empresaId),
          const SizedBox(height: 14),
          _PushSuscriptoresCard(empresaId: empresaId),
          const SizedBox(height: 14),
          _CopiarSdkCard(empresaId: empresaId),
          const SizedBox(height: 14),
          _PushConfigCard(empresaId: empresaId),
          const SizedBox(height: 14),
          _CdnConfigCard(empresaId: empresaId),
          const SizedBox(height: 14),
          _GuiaAtributosCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Card 1: Estado del SDK ────────────────────────────────────────────────────

class _SdkStatusCard extends StatelessWidget {
  final String empresaId;
  const _SdkStatusCard({required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: ContenidoWebService().obtenerSdkStatus(empresaId),
      builder: (_, snap) {
        final data    = snap.data ?? {};
        final mods    = (data['modulos'] as List?)?.cast<String>() ?? [];
        final url     = data['url'] as String? ?? '';
        final ts      = data['ts'];
        DateTime? ultima;
        if (ts is Timestamp) ultima = ts.toDate();

        final activo = ultima != null &&
            DateTime.now().difference(ultima).inHours < 24;

        return _card(
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: activo
                    ? const Color(0xFF10B981).withValues(alpha: 0.1)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                activo ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                color: activo ? const Color(0xFF10B981) : Colors.grey[400],
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(
                  activo ? 'SDK activo' : 'SDK sin actividad reciente',
                  style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14,
                    color: activo ? const Color(0xFF10B981) : Colors.grey[600],
                  ),
                ),
                if (mods.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${mods.length} módulo${mods.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF1565C0),
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              if (url.isNotEmpty)
                Text(url, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              if (ultima != null)
                Text('Última visita: ${_fmtTs(ultima)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              if (data.isEmpty)
                const Text('El SDK no ha sido detectado en ninguna web todavía.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
            ])),
          ]),
        );
      },
    );
  }

  String _fmtTs(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inHours < 1)   return 'hace ${diff.inMinutes} min';
    if (diff.inDays < 1)    return 'hace ${diff.inHours} h';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ── Card 2: Módulos detectados ────────────────────────────────────────────────

class _ModulosDetectadosCard extends StatelessWidget {
  final String empresaId;
  const _ModulosDetectadosCard({required this.empresaId});

  static const _allMods = [
    ('agenda',             'Agenda',          Icons.event_rounded,               Color(0xFF1E4D6B)),
    ('agenda-detalle',     'Evento',          Icons.event_note_rounded,          Color(0xFF1E4D6B)),
    ('catalogo',           'Catálogo',        Icons.grid_view_rounded,           Color(0xFF6B1E2A)),
    ('catalogo-detalle',   'Item',            Icons.inventory_2_outlined,        Color(0xFF6B1E2A)),
    ('seleccion-nazari',   'Selec. Nazarí',   Icons.stars_rounded,               Color(0xFF6B1E2A)),
    ('blog',               'Blog',            Icons.article_rounded,             Color(0xFF2563EB)),
    ('blog-post',          'Artículo',        Icons.newspaper_rounded,           Color(0xFF059669)),
    ('contacto',           'Contacto',        Icons.chat_bubble_outline_rounded, Color(0xFF059669)),
    ('resenas',            'Reseñas',         Icons.star_outline_rounded,        Color(0xFFF59E0B)),
    ('secciones',          'Secciones',       Icons.dashboard_customize_rounded, Color(0xFF7C3AED)),
    ('push',               'Push',            Icons.notifications_outlined,      Color(0xFFE11D48)),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: ContenidoWebService().obtenerSdkStatus(empresaId),
      builder: (_, snap) {
        final activos = (snap.data?['modulos'] as List?)?.cast<String>() ?? [];

        return _card(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Módulos detectados en la web',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Los módulos con data-fluix-* encontrados la última vez que cargó la web.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8,
              children: _allMods.map((m) {
                final detectado = activos.contains(m.$1);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: detectado
                        ? m.$4.withValues(alpha: 0.1)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: detectado ? m.$4.withValues(alpha: 0.4) : Colors.transparent,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(m.$3,
                        size: 14,
                        color: detectado ? m.$4 : Colors.grey[400]),
                    const SizedBox(width: 5),
                    Text(m.$2,
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: detectado ? m.$4 : Colors.grey[400],
                        )),
                    const SizedBox(width: 4),
                    Icon(
                      detectado ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size: 11,
                      color: detectado ? m.$4 : Colors.grey[300],
                    ),
                  ]),
                );
              }).toList(),
            ),
          ]),
        );
      },
    );
  }
}

// ── Card 3: Push suscriptores ─────────────────────────────────────────────────

class _PushSuscriptoresCard extends StatelessWidget {
  final String empresaId;
  const _PushSuscriptoresCard({required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(empresaId)
          .collection('suscriptores_web')
          .snapshots(),
      builder: (_, snap) {
        final total = snap.data?.docs.length ?? 0;

        return _card(
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.notifications_active_rounded,
                  color: Color(0xFFE11D48), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$total suscriptor${total == 1 ? '' : 'es'} web push',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                      color: Color(0xFF0F172A))),
              const Text(
                'Visitantes que han dado permiso de notificaciones en tu web.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
              ),
            ])),
            if (total > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$total',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 18,
                      color: Color(0xFFE11D48),
                    )),
              ),
          ]),
        );
      },
    );
  }
}

// ── Card 4: Copiar SDK ────────────────────────────────────────────────────────

class _CopiarSdkCard extends StatefulWidget {
  final String empresaId;
  const _CopiarSdkCard({required this.empresaId});

  @override
  State<_CopiarSdkCard> createState() => _CopiarSdkCardState();
}

class _CopiarSdkCardState extends State<_CopiarSdkCard> {
  bool _copiado = false;

  void _copiar() {
    final sdk = ContenidoWebService().generarScriptHostinger(widget.empresaId);
    Clipboard.setData(ClipboardData(text: sdk));
    setState(() => _copiado = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _copiado = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ Script SDK copiado al portapapeles'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.code_rounded, color: Color(0xFF1565C0), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Fluix Web SDK', style: TextStyle(fontWeight: FontWeight.w700,
                fontSize: 14, color: Color(0xFF0F172A))),
            Text('Pega este script antes de </body> en tu web.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          ])),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _copiar,
            icon: Icon(_copiado ? Icons.check_rounded : Icons.copy_rounded, size: 16),
            label: Text(_copiado ? '¡Copiado!' : 'Copiar script SDK'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _copiado ? Colors.green : const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'El script detecta automáticamente qué módulos data-fluix-* tienes en el HTML '
          'y solo carga los necesarios. Cualquier cambio desde la app se refleja '
          'en la web en tiempo real sin tocar código.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.5),
        ),
      ]),
    );
  }
}

// ── Card 5: Push config ───────────────────────────────────────────────────────

class _PushConfigCard extends StatefulWidget {
  final String empresaId;
  const _PushConfigCard({required this.empresaId});
  @override
  State<_PushConfigCard> createState() => _PushConfigCardState();
}

class _PushConfigCardState extends State<_PushConfigCard> {
  bool _expandida = false;
  bool _guardando = false;
  bool _swCopiado = false;
  final _vapidCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ContenidoWebService().obtenerConfigPush(widget.empresaId).then((cfg) {
      if (mounted && cfg != null) {
        _vapidCtrl.text = cfg['vapid_key'] as String? ?? '';
      }
    });
  }

  @override
  void dispose() {
    _vapidCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final key = _vapidCtrl.text.trim();
    if (key.isEmpty) return;
    setState(() => _guardando = true);
    await ContenidoWebService().guardarConfigPush(widget.empresaId, key);
    setState(() => _guardando = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ VAPID key guardada'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _copiarSW() {
    Clipboard.setData(ClipboardData(
        text: ContenidoWebService.generarServiceWorkerPush()));
    setState(() => _swCopiado = true);
    Future.delayed(const Duration(seconds: 3),
        () { if (mounted) setState(() => _swCopiado = false); });
  }

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => setState(() => _expandida = !_expandida),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notifications_active_rounded,
                  color: Color(0xFFE11D48), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Push Web · Configuración',
                  style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 14, color: Color(0xFF0F172A))),
              Text('VAPID key + service worker para notificaciones push',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            ])),
            Icon(_expandida ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey[500]),
          ]),
        ),
        if (_expandida) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const Text('1. Consigue tu VAPID public key en Firebase Console → Project Settings → Cloud Messaging.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 10),
          TextField(
            controller: _vapidCtrl,
            decoration: InputDecoration(
              labelText: 'VAPID public key',
              hintText: 'BNYx...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _guardando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar VAPID key'),
            ),
          ),
          const SizedBox(height: 14),
          const Text('2. Sube el service worker a la raíz de tu web como /firebase-messaging-sw.js',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _copiarSW,
              icon: Icon(_swCopiado ? Icons.check_rounded : Icons.copy_rounded, size: 14),
              label: Text(_swCopiado ? '¡Copiado!' : 'Copiar firebase-messaging-sw.js'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE11D48),
                side: const BorderSide(color: Color(0xFFE11D48)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text('3. Añade <div data-fluix-push></div> donde quieras el botón "Activar notificaciones" en tu web.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      ]),
    );
  }
}

// ── Card 6: CDN / Webhooks ────────────────────────────────────────────────────

class _CdnConfigCard extends StatefulWidget {
  final String empresaId;
  const _CdnConfigCard({required this.empresaId});
  @override
  State<_CdnConfigCard> createState() => _CdnConfigCardState();
}

class _CdnConfigCardState extends State<_CdnConfigCard> {
  bool _expandida = false;
  bool _guardando = false;
  final _baseUrlCtrl  = TextEditingController();
  final _zoneCtrl     = TextEditingController();
  final _tokenCtrl    = TextEditingController();
  final _agendaCtrl   = TextEditingController(text: '/agenda');
  final _blogCtrl     = TextEditingController(text: '/blog');
  final _catalogoCtrl = TextEditingController(text: '/libros');
  final _libroCtrl    = TextEditingController(text: '/libro.html');
  final _eventoCtrl   = TextEditingController(text: '/evento.html');

  @override
  void initState() {
    super.initState();
    ContenidoWebService().obtenerConfigCdn(widget.empresaId).first.then((cfg) {
      if (!mounted) return;
      _baseUrlCtrl.text  = cfg['base_url']      as String? ?? '';
      _zoneCtrl.text     = cfg['cloudflare_zone'] as String? ?? '';
      _tokenCtrl.text    = cfg['cloudflare_token'] as String? ?? '';
      _agendaCtrl.text   = cfg['agenda_path']   as String? ?? '/agenda';
      _blogCtrl.text     = cfg['blog_path']     as String? ?? '/blog';
      _catalogoCtrl.text = cfg['catalogo_path'] as String? ?? '/libros';
      _libroCtrl.text    = cfg['libro_path']    as String? ?? '/libro.html';
      _eventoCtrl.text   = cfg['evento_path']   as String? ?? '/evento.html';
    });
  }

  @override
  void dispose() {
    for (final c in [_baseUrlCtrl, _zoneCtrl, _tokenCtrl,
        _agendaCtrl, _blogCtrl, _catalogoCtrl, _libroCtrl, _eventoCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    await ContenidoWebService().guardarConfigCdn(widget.empresaId, {
      'base_url':          _baseUrlCtrl.text.trim(),
      'cloudflare_zone':   _zoneCtrl.text.trim(),
      'cloudflare_token':  _tokenCtrl.text.trim(),
      'agenda_path':       _agendaCtrl.text.trim(),
      'blog_path':         _blogCtrl.text.trim(),
      'catalogo_path':     _catalogoCtrl.text.trim(),
      'libro_path':        _libroCtrl.text.trim(),
      'evento_path':       _eventoCtrl.text.trim(),
    });
    setState(() => _guardando = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('✅ Config CDN guardada — se aplicará en el próximo cambio'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => setState(() => _expandida = !_expandida),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud_sync_rounded,
                  color: Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CDN Webhooks · Cloudflare',
                  style: TextStyle(fontWeight: FontWeight.w700,
                      fontSize: 14, color: Color(0xFF0F172A))),
              Text('Purga automática de caché al publicar eventos, posts o libros',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            ])),
            Icon(_expandida ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey[500]),
          ]),
        ),
        if (_expandida) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          _field('URL base de tu web', _baseUrlCtrl,
              hint: 'https://editorialnazari.com'),
          _field('Cloudflare Zone ID', _zoneCtrl,
              hint: 'abc123def456...'),
          _field('Cloudflare API Token', _tokenCtrl,
              hint: 'Token con permiso Cache Purge'),
          const Divider(height: 20),
          const Text('Rutas de páginas (para purgar la URL correcta):',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _field('Agenda / Eventos', _agendaCtrl, hint: '/agenda'),
          _field('Detalle de evento', _eventoCtrl, hint: '/evento.html'),
          _field('Blog / Noticias', _blogCtrl, hint: '/blog'),
          _field('Catálogo / Libros', _catalogoCtrl, hint: '/libros'),
          _field('Detalle de libro', _libroCtrl, hint: '/libro.html'),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _guardando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar config CDN',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Necesitas un Cloudflare API Token con permiso "Cache Purge" sobre tu zona. '
            'Se crea en cloudflare.com → My Profile → API Tokens.',
            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.4),
          ),
        ],
      ]),
    );
  }
}

// ── Card 7: Guía de atributos ─────────────────────────────────────────────────

class _GuiaAtributosCard extends StatefulWidget {
  @override
  State<_GuiaAtributosCard> createState() => _GuiaAtributosCardState();
}

class _GuiaAtributosCardState extends State<_GuiaAtributosCard> {
  bool _expandida = false;

  @override
  Widget build(BuildContext context) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => setState(() => _expandida = !_expandida),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.help_outline_rounded, color: Colors.grey[600], size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Referencia de atributos', style: TextStyle(fontWeight: FontWeight.w700,
                  fontSize: 14, color: Color(0xFF0F172A))),
              Text('Cómo usar data-fluix-* en tu HTML',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
            ])),
            Icon(_expandida ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.grey[500]),
          ]),
        ),
        if (_expandida) ...[
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          ..._atributos.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(a.$1,
                    style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF7DD3FC),
                      fontFamily: 'monospace')),
              ),
              const SizedBox(height: 4),
              Text(a.$2, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ]),
          )),
        ],
      ]),
    );
  }

  static const _atributos = [
    ('<div data-fluix-agenda>',           'Lista de eventos en tiempo real'),
    ('<div data-fluix-agenda-detalle>',   'Detalle de evento (?evento=ID)'),
    ('<div data-fluix-catalogo>',         'Lista del catálogo en tiempo real'),
    ('<div data-fluix-catalogo-detalle>', 'Detalle de item (?item=ID)'),
    ('<div data-fluix-blog>',             'Artículos y noticias del blog'),
    ('<div data-fluix-blog-post>',        'Artículo completo (?post=slug)'),
    ('<div data-fluix-contacto>',         'Formulario → llega a Mensajes en Fluix'),
    ('<div data-fluix-resenas>',          'Valoraciones de clientes'),
    ('<div data-fluix-seccion="ID">',     'Sección personalizada por ID'),
    ('<div data-fluix-push>',             'Botón para activar notificaciones push web'),
    ('data-fluix-limite="10"',           'Máximo de items a mostrar'),
    ('data-fluix-tipo="Presentación"',   'Filtrar por tipo (agenda/blog)'),
    ('data-fluix-ciudad="Granada"',      'Filtrar eventos por ciudad'),
    ('data-fluix-detalle-url="evento.html?evento="', 'URL de la página de detalle'),
    ('<span data-fluix-campo="titulo">', 'Campo de dato dentro de template'),
  ];
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Widget _card({required Widget child}) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10, offset: const Offset(0, 2))],
  ),
  child: child,
);

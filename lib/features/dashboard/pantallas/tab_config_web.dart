import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB CONFIGURACIÓN WEB — Dominio, Popup, Banner, Formulario de contacto
// ═════════════════════════════════════════════════════════════════════════════

class TabConfigWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;

  const TabConfigWeb(
      {super.key, required this.empresaId, required this.svc});

  @override
  State<TabConfigWeb> createState() => _TabConfigWebState();
}

class _TabConfigWebState extends State<TabConfigWeb> {
  ConfigWebAvanzada _cfg = const ConfigWebAvanzada();
  bool _cargado = false;
  bool _guardando = false;

  // Dominio
  final _dominioCtrl = TextEditingController();

  // Contacto
  bool _contactoActivo = false;
  final _contactoEmailCtrl = TextEditingController();
  final _contactoWaCtrl = TextEditingController();
  final _contactoTituloCtrl = TextEditingController();

  // Popup
  bool _popupActivo = false;
  final _popupTituloCtrl = TextEditingController();
  final _popupTextoCtrl = TextEditingController();
  final _popupBtnTextoCtrl = TextEditingController();
  final _popupBtnUrlCtrl = TextEditingController();
  int _popupRetraso = 5;

  // Banner
  bool _bannerActivo = false;
  final _bannerTextoCtrl = TextEditingController();
  final _bannerUrlCtrl = TextEditingController();
  String _bannerColor = '#1976D2';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    widget.svc.obtenerConfigAvanzada(widget.empresaId).first.then((cfg) {
      if (!mounted) return;
      setState(() {
        _cfg = cfg;
        _dominioCtrl.text = cfg.dominioPropioUrl ?? '';
        _contactoActivo = cfg.contactoActivo;
        _contactoEmailCtrl.text = cfg.contactoEmail ?? '';
        _contactoWaCtrl.text = cfg.contactoWhatsapp ?? '';
        _contactoTituloCtrl.text = cfg.contactoTitulo ?? '';
        _popupActivo = cfg.popupActivo;
        _popupTituloCtrl.text = cfg.popupTitulo ?? '';
        _popupTextoCtrl.text = cfg.popupTexto ?? '';
        _popupBtnTextoCtrl.text = cfg.popupBotonTexto ?? '';
        _popupBtnUrlCtrl.text = cfg.popupBotonUrl ?? '';
        _popupRetraso = cfg.popupRetrasoSeg;
        _bannerActivo = cfg.bannerActivo;
        _bannerTextoCtrl.text = cfg.bannerTexto ?? '';
        _bannerUrlCtrl.text = cfg.bannerUrlDestino ?? '';
        _bannerColor = cfg.bannerColor ?? '#1976D2';
        _cargado = true;
      });
    });
  }

  @override
  void dispose() {
    _dominioCtrl.dispose();
    _contactoEmailCtrl.dispose();
    _contactoWaCtrl.dispose();
    _contactoTituloCtrl.dispose();
    _popupTituloCtrl.dispose();
    _popupTextoCtrl.dispose();
    _popupBtnTextoCtrl.dispose();
    _popupBtnUrlCtrl.dispose();
    _bannerTextoCtrl.dispose();
    _bannerUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    if (!_cargado) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Dominio propio ────────────────────────────────────────────────
        _buildSeccion(
          color: color,
          icono: Icons.link,
          titulo: 'Dominio propio',
          subtitulo: 'URL de la web donde tienes instalado el script',
          child: TextFormField(
            controller: _dominioCtrl,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'https://tunegocio.com',
              prefixIcon: Icon(Icons.public),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Formulario de contacto ────────────────────────────────────────
        _buildSeccion(
          color: color,
          icono: Icons.contact_mail,
          titulo: 'Formulario de contacto',
          subtitulo: 'Permite a los visitantes enviarte mensajes desde la web',
          headerWidget: Switch(
            value: _contactoActivo,
            onChanged: (v) => setState(() => _contactoActivo = v),
            activeThumbColor: color,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _contactoActivo
                ? Column(children: [
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _contactoTituloCtrl,
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'Título del formulario',
                          hintText: 'Contáctanos',
                          prefixIcon: Icon(Icons.title)),
                    ),
                    const Divider(height: 1),
                    TextFormField(
                      controller: _contactoEmailCtrl,
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'Email de destino',
                          hintText: 'info@tunegocio.com',
                          prefixIcon: Icon(Icons.email_outlined)),
                    ),
                    const Divider(height: 1),
                    TextFormField(
                      controller: _contactoWaCtrl,
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'WhatsApp (opcional)',
                          hintText: '+34 600 000 000',
                          prefixIcon: Icon(Icons.chat_outlined)),
                    ),
                    const SizedBox(height: 8),
                    _buildInfo(
                        'Los mensajes se guardan en Firestore. '
                        'También se envían al email si está configurado.',
                        Colors.green),
                  ])
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 12),

        // ── Popup ─────────────────────────────────────────────────────────
        _buildSeccion(
          color: color,
          icono: Icons.open_in_new,
          titulo: 'Popup de bienvenida',
          subtitulo: 'Ventana emergente con oferta o aviso',
          headerWidget: Switch(
            value: _popupActivo,
            onChanged: (v) => setState(() => _popupActivo = v),
            activeThumbColor: color,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _popupActivo
                ? Column(children: [
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _popupTituloCtrl,
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'Título del popup *',
                          prefixIcon: Icon(Icons.title)),
                    ),
                    const Divider(height: 1),
                    TextFormField(
                      controller: _popupTextoCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'Texto descriptivo',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes)),
                    ),
                    const Divider(height: 1),
                    TextFormField(
                      controller: _popupBtnTextoCtrl,
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'Texto del botón',
                          hintText: 'Ver oferta',
                          prefixIcon: Icon(Icons.smart_button_outlined)),
                    ),
                    const Divider(height: 1),
                    TextFormField(
                      controller: _popupBtnUrlCtrl,
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'URL del botón',
                          hintText: 'https://tunegocio.com/oferta',
                          prefixIcon: Icon(Icons.link)),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        const Icon(Icons.timer_outlined,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('Retraso de aparición:',
                            style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: Slider(
                            value: _popupRetraso.toDouble(),
                            min: 0,
                            max: 30,
                            divisions: 6,
                            label: '$_popupRetraso s',
                            onChanged: (v) =>
                                setState(() => _popupRetraso = v.toInt()),
                            activeColor: color,
                          ),
                        ),
                        Text('${_popupRetraso}s',
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    // Preview
                    _buildPreviewPopup(color),
                  ])
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 12),

        // ── Banner ────────────────────────────────────────────────────────
        _buildSeccion(
          color: color,
          icono: Icons.view_day_outlined,
          titulo: 'Banner superior',
          subtitulo: 'Barra informativa al tope de la web',
          headerWidget: Switch(
            value: _bannerActivo,
            onChanged: (v) => setState(() => _bannerActivo = v),
            activeThumbColor: color,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _bannerActivo
                ? Column(children: [
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bannerTextoCtrl,
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'Texto del banner *',
                          hintText: '🎉 Oferta especial este fin de semana',
                          prefixIcon: Icon(Icons.announcement_outlined)),
                    ),
                    const Divider(height: 1),
                    TextFormField(
                      controller: _bannerUrlCtrl,
                      decoration: const InputDecoration(
                          border: InputBorder.none,
                          labelText: 'URL de destino (opcional)',
                          hintText: 'https://...',
                          prefixIcon: Icon(Icons.link)),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Color del banner:',
                              style: TextStyle(fontSize: 13)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              '#1976D2', '#E53935', '#2E7D32',
                              '#E65100', '#6A1B9A', '#00796B',
                              '#212121',
                            ].map((hex) {
                              final c = _hexColor(hex);
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _bannerColor = hex),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: _bannerColor == hex
                                        ? Border.all(
                                            color: Colors.white, width: 3)
                                        : null,
                                    boxShadow: [
                                      BoxShadow(
                                          color:
                                              c.withValues(alpha: 0.4),
                                          blurRadius: 4)
                                    ],
                                  ),
                                  child: _bannerColor == hex
                                      ? const Icon(Icons.check,
                                          color: Colors.white, size: 18)
                                      : null,
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),
                          // Preview banner
                          _buildPreviewBanner(),
                        ],
                      ),
                    ),
                  ])
                : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 20),

        // Botón guardar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _guardando ? null : () => _guardar(context),
            icon: _guardando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label:
                Text(_guardando ? 'Guardando...' : 'Guardar configuración'),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPreviewPopup(Color color) {
    final titulo = _popupTituloCtrl.text.isEmpty
        ? 'Título del popup'
        : _popupTituloCtrl.text;
    final texto = _popupTextoCtrl.text.isEmpty
        ? 'Descripción de la oferta o aviso...'
        : _popupTextoCtrl.text;
    final boton =
        _popupBtnTextoCtrl.text.isEmpty ? 'Ver más' : _popupBtnTextoCtrl.text;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.visibility_outlined,
                color: Colors.grey, size: 12),
            const SizedBox(width: 4),
            Text('Preview popup',
                style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12)
              ],
            ),
            child: Column(
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 6),
                Text(texto,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(boton,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBanner() {
    final texto = _bannerTextoCtrl.text.isEmpty
        ? 'Tu banner aquí'
        : _bannerTextoCtrl.text;
    final bgColor = _hexColor(_bannerColor);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            texto,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 6),
          const Text('▸',
              style: TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildInfo(String texto, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
              child: Text(texto,
                  style: TextStyle(fontSize: 11, color: color))),
        ],
      ),
    );
  }

  Widget _buildSeccion({
    required Color color,
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required Widget child,
    Widget? headerWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icono, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(subtitulo,
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 11)),
              ],
            )),
            if (headerWidget != null) headerWidget,
          ]),
          child,
        ],
      ),
    );
  }

  Color _hexColor(String hex) {
    final clean = hex.replaceAll('#', '');
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.blue;
    }
  }

  Future<void> _guardar(BuildContext context) async {
    setState(() => _guardando = true);
    final cfg = ConfigWebAvanzada(
      dominioPropioUrl: _dominioCtrl.text.trim().isEmpty
          ? null
          : _dominioCtrl.text.trim(),
      contactoActivo: _contactoActivo,
      contactoEmail: _contactoEmailCtrl.text.trim().isEmpty
          ? null
          : _contactoEmailCtrl.text.trim(),
      contactoWhatsapp: _contactoWaCtrl.text.trim().isEmpty
          ? null
          : _contactoWaCtrl.text.trim(),
      contactoTitulo: _contactoTituloCtrl.text.trim().isEmpty
          ? null
          : _contactoTituloCtrl.text.trim(),
      popupActivo: _popupActivo,
      popupTitulo: _popupTituloCtrl.text.trim().isEmpty
          ? null
          : _popupTituloCtrl.text.trim(),
      popupTexto: _popupTextoCtrl.text.trim().isEmpty
          ? null
          : _popupTextoCtrl.text.trim(),
      popupBotonTexto: _popupBtnTextoCtrl.text.trim().isEmpty
          ? null
          : _popupBtnTextoCtrl.text.trim(),
      popupBotonUrl: _popupBtnUrlCtrl.text.trim().isEmpty
          ? null
          : _popupBtnUrlCtrl.text.trim(),
      popupRetrasoSeg: _popupRetraso,
      bannerActivo: _bannerActivo,
      bannerTexto: _bannerTextoCtrl.text.trim().isEmpty
          ? null
          : _bannerTextoCtrl.text.trim(),
      bannerColor: _bannerColor,
      bannerUrlDestino: _bannerUrlCtrl.text.trim().isEmpty
          ? null
          : _bannerUrlCtrl.text.trim(),
    );

    try {
      await widget.svc.guardarConfigAvanzada(widget.empresaId, cfg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Configuración guardada'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }
}


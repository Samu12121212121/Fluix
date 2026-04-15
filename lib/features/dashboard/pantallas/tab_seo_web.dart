import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_config_provider.dart';
import '../../../services/contenido_web_service.dart';
import '../../../domain/modelos/seccion_web.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TAB SEO — Meta tags y herramientas de búsqueda
// ═════════════════════════════════════════════════════════════════════════════

class TabSeoWeb extends StatefulWidget {
  final String empresaId;
  final ContenidoWebService svc;

  const TabSeoWeb({super.key, required this.empresaId, required this.svc});

  @override
  State<TabSeoWeb> createState() => _TabSeoWebState();
}

class _TabSeoWebState extends State<TabSeoWeb> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _kwCtrl = TextEditingController();
  final _gaCtrl = TextEditingController();
  final _fbCtrl = TextEditingController();

  SeoConfig _config = const SeoConfig();
  String? _imagenOg;
  String _robots = 'index,follow';
  bool _guardando = false;
  bool _cargado = false;
  bool _subiendoImagen = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    widget.svc.obtenerSeoConfig(widget.empresaId).first.then((cfg) {
      if (!mounted) return;
      setState(() {
        _config = cfg;
        _tituloCtrl.text = cfg.tituloSeo;
        _descCtrl.text = cfg.descripcionSeo;
        _kwCtrl.text = cfg.palabrasClave;
        _gaCtrl.text = cfg.googleAnalyticsId ?? '';
        _fbCtrl.text = cfg.pixelFacebook ?? '';
        _imagenOg = cfg.imagenOg;
        _robots = cfg.robotsContent;
        _cargado = true;
      });
    });
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descCtrl.dispose();
    _kwCtrl.dispose();
    _gaCtrl.dispose();
    _fbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.watch<AppConfigProvider>().colorPrimario;

    if (!_cargado) {
      return const Center(child: CircularProgressIndicator());
    }

    final tituloLen = _tituloCtrl.text.length;
    final descLen = _descCtrl.text.length;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Preview Google ──────────────────────────────────────────────
          _buildCard(
            titulo: 'Vista previa en Google',
            icono: Icons.search,
            color: color,
            child: _buildPreviewGoogle(),
          ),
          const SizedBox(height: 14),

          // ── Título SEO ──────────────────────────────────────────────────
          _buildCard(
            titulo: 'Título de la página',
            icono: Icons.title,
            color: color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _tituloCtrl,
                  maxLength: 70,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        'Ej: Tu Restaurante | Cocina mediterránea en Madrid',
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                _contadorSeo(tituloLen, 30, 60, 'Ideal: 30–60 caracteres'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Descripción ─────────────────────────────────────────────────
          _buildCard(
            titulo: 'Meta descripción',
            icono: Icons.description_outlined,
            color: color,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  maxLength: 170,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        'Describe tu negocio en 1-2 frases para que aparezca en Google...',
                    alignLabelWithHint: true,
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                _contadorSeo(
                    descLen, 120, 160, 'Ideal: 120–160 caracteres'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Palabras clave ──────────────────────────────────────────────
          _buildCard(
            titulo: 'Palabras clave',
            icono: Icons.label_outline,
            color: color,
            child: TextFormField(
              controller: _kwCtrl,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'restaurante, menú del día, terraza, delivery...',
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Open Graph (imagen redes sociales) ──────────────────────────
          _buildCard(
            titulo: 'Imagen para redes sociales (OG)',
            icono: Icons.share,
            color: color,
            child: Column(
              children: [
                if (_imagenOg != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(_imagenOg!,
                        height: 130,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () => _subirImagenOg(),
                        icon: Icon(Icons.swap_horiz, color: color),
                        label: Text('Cambiar',
                            style: TextStyle(color: color)),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _imagenOg = null),
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      label: const Text('Quitar',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ]),
                ] else
                  OutlinedButton.icon(
                    onPressed: _subiendoImagen ? null : _subirImagenOg,
                    icon: _subiendoImagen
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.add_photo_alternate, color: color),
                    label: Text(
                        _subiendoImagen
                            ? 'Subiendo...'
                            : 'Subir imagen (1200×630 recomendado)',
                        style: TextStyle(color: color)),
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: color.withValues(alpha: 0.4))),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Indexación ──────────────────────────────────────────────────
          _buildCard(
            titulo: 'Indexación en buscadores',
            icono: Icons.travel_explore,
            color: color,
            child: Column(
              children: [
                _opcionRobots('index,follow',
                    'Indexar mi web (recomendado)',
                    'Google puede rastrear e indexar tu contenido', color),
                _opcionRobots('noindex,nofollow',
                    'No indexar',
                    'Ocultar de los resultados de búsqueda', color),
                _opcionRobots('index,nofollow',
                    'Indexar sin seguir enlaces',
                    'Google indexa pero no sigue links de tu web', color),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Analytics ───────────────────────────────────────────────────
          _buildCard(
            titulo: 'Herramientas de analítica',
            icono: Icons.analytics_outlined,
            color: color,
            child: Column(children: [
              TextFormField(
                controller: _gaCtrl,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Google Analytics ID',
                  hintText: 'G-XXXXXXXXXX o UA-XXXXXXXX',
                  prefixIcon: Icon(Icons.bar_chart_outlined),
                ),
              ),
              const Divider(height: 1),
              TextFormField(
                controller: _fbCtrl,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  labelText: 'Facebook Pixel ID',
                  hintText: '123456789012345',
                  prefixIcon: Icon(Icons.facebook),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Estos códigos se añaden automáticamente al script generado.',
                      style: TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ),
                ]),
              ),
            ]),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_guardando ? 'Guardando...' : 'Guardar configuración SEO'),
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
      ),
    );
  }

  Widget _buildPreviewGoogle() {
    final titulo = _tituloCtrl.text.isEmpty
        ? 'Título de tu página | Tu Negocio'
        : _tituloCtrl.text;
    final desc = _descCtrl.text.isEmpty
        ? 'Descripción de tu negocio que aparecerá en los resultados de búsqueda de Google...'
        : _descCtrl.text;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // URL ficticia
          Row(children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                  color: Colors.green[100], borderRadius: BorderRadius.circular(4)),
              child: const Icon(Icons.lock, size: 10, color: Colors.green),
            ),
            const SizedBox(width: 4),
            Text('tunegocio.com',
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          // Título en azul (como Google)
          Text(
            titulo.length > 60 ? '${titulo.substring(0, 60)}...' : titulo,
            style: const TextStyle(
                color: Color(0xFF1A0DAB),
                fontSize: 18,
                fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 4),
          // Descripción
          Text(
            desc.length > 155 ? '${desc.substring(0, 155)}...' : desc,
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _contadorSeo(
      int actual, int min, int max, String texto) {
    final ok = actual >= min && actual <= max;
    final color = actual == 0
        ? Colors.grey
        : ok
            ? Colors.green
            : Colors.orange;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Icon(
            ok ? Icons.check_circle : Icons.info_outline,
            color: color,
            size: 14),
        const SizedBox(width: 4),
        Text(
          '$actual caracteres — $texto',
          style: TextStyle(fontSize: 11, color: color),
        ),
      ]),
    );
  }

  Widget _opcionRobots(String valor, String titulo, String desc, Color color) {
    final sel = _robots == valor;
    return GestureDetector(
      onTap: () => setState(() => _robots = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.07) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: sel ? color : Colors.grey[200]!,
              width: sel ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: sel ? color : Colors.grey, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: sel ? color : Colors.black87)),
                Text(desc,
                    style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _subirImagenOg() async {
    setState(() => _subiendoImagen = true);
    final url = await widget.svc
        .subirImagenDesdeGaleria(widget.empresaId, 'seo');
    if (mounted) setState(() {
      _imagenOg = url;
      _subiendoImagen = false;
    });
  }

  Future<void> _guardar(BuildContext context) async {
    setState(() => _guardando = true);
    final cfg = SeoConfig(
      tituloSeo: _tituloCtrl.text.trim(),
      descripcionSeo: _descCtrl.text.trim(),
      palabrasClave: _kwCtrl.text.trim(),
      imagenOg: _imagenOg,
      googleAnalyticsId:
          _gaCtrl.text.trim().isEmpty ? null : _gaCtrl.text.trim(),
      pixelFacebook:
          _fbCtrl.text.trim().isEmpty ? null : _fbCtrl.text.trim(),
      googleAnalyticsId:
          _gaCtrl.text.trim().isEmpty ? null : _gaCtrl.text.trim(),
      pixelFacebook:
          _fbCtrl.text.trim().isEmpty ? null : _fbCtrl.text.trim(),
      robotsContent: _robots,
    );
    try {
      await widget.svc.guardarSeoConfig(widget.empresaId, cfg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ SEO guardado correctamente'),
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

  Widget _buildCard({
    required String titulo,
    required IconData icono,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icono, color: color, size: 16),
            const SizedBox(width: 6),
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}


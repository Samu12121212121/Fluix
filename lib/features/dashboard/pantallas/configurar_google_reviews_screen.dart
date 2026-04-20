import 'package:flutter/material.dart';
import '../../../services/google_reviews_service.dart';
import '../../../services/demo_cuenta_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Pantalla para configurar la integración con Google Reviews.
/// Solo requiere API Key de Google Places y Place ID del negocio.
/// No necesita OAuth ni Cloud Functions — escribe directamente en
/// empresas/{empresaId}/configuracion/google_reviews
class ConfigurarGoogleReviewsScreen extends StatefulWidget {
  final String empresaId;

  const ConfigurarGoogleReviewsScreen({
    super.key,
    required this.empresaId,
  });

  @override
  State<ConfigurarGoogleReviewsScreen> createState() =>
      _ConfigurarGoogleReviewsScreenState();
}

class _ConfigurarGoogleReviewsScreenState
    extends State<ConfigurarGoogleReviewsScreen> {
  final _svc = GoogleReviewsService();
  final _apiKeyCtrl = TextEditingController();
  final _placeIdCtrl = TextEditingController();
  bool _cargando = true;
  bool _guardando = false;
  bool _testando = false;
  String? _error;
  String? _exito;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _placeIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final config = await _svc.obtenerConfigPublica(widget.empresaId);
      _apiKeyCtrl.text = config['apiKey'] ?? '';
      _placeIdCtrl.text = config['placeId'] ?? '';
    } catch (e) {
      // Sin config previa — campos vacíos
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    final apiKey = _apiKeyCtrl.text.trim();
    final placeId = _placeIdCtrl.text.trim();

    if (apiKey.isEmpty || placeId.isEmpty) {
      setState(() => _error = 'Rellena la API Key y el Place ID');
      return;
    }

    setState(() { _guardando = true; _error = null; _exito = null; });

    try {
      await _svc.guardarConfig(
        widget.empresaId,
        apiKey: apiKey,
        placeId: placeId,
      );
      if (mounted) {
        setState(() {
          _guardando = false;
          _exito = '✅ Configuración guardada correctamente';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _error = 'Error al guardar: $e';
        });
      }
    }
  }

  Future<void> _testar() async {
    final apiKey = _apiKeyCtrl.text.trim();
    final placeId = _placeIdCtrl.text.trim();
    if (apiKey.isEmpty || placeId.isEmpty) {
      setState(() => _error = 'Guarda la configuración primero');
      return;
    }

    setState(() { _testando = true; _error = null; _exito = null; });

    try {
      final resultado = await _svc.sincronizarDesdeGoogle(widget.empresaId);
      if (mounted) {
        setState(() {
          _testando = false;
          if (resultado.error != null) {
            _error = 'Error de prueba: ${resultado.error}';
          } else {
            _exito = '✅ Conexión OK — Rating: ${resultado.rating.toStringAsFixed(1)} '
                '(${resultado.total} reseñas)';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testando = false;
          _error = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (DemoCuentaService().esDemo(email)) {
      return _buildDemoScreen(context);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Configurar Google Reviews'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Info ──────────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4285F4).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF4285F4).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFF4285F4), size: 18),
                          SizedBox(width: 8),
                          Text('¿Cómo obtener estos datos?',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1565C0))),
                        ]),
                        const SizedBox(height: 10),
                        _paso('1', 'Place ID',
                            'Ve a maps.googleapis.com/maps/api/place/findplacefromtext, '
                            'busca tu negocio y copia el place_id'),
                        const SizedBox(height: 6),
                        _paso('2', 'API Key',
                            'Crea una clave en console.cloud.google.com → '
                            'Credenciales → Clave de API. '
                            'Activa Places API en el proyecto.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Campos ───────────────────────────────────────────────
                  const Text('API Key de Google Places',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _apiKeyCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'AIzaSy...',
                      prefixIcon: const Icon(Icons.key),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text('Place ID del negocio',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _placeIdCtrl,
                    decoration: InputDecoration(
                      hintText: 'ChIJN1t_tDeu...',
                      prefixIcon: const Icon(Icons.place_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Errores / Éxito ──────────────────────────────────────
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_error!,
                                style: const TextStyle(color: Colors.red))),
                      ]),
                    ),
                  if (_exito != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline,
                            color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(_exito!,
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600))),
                      ]),
                    ),

                  // ── Botones ──────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined),
                      label: Text(_guardando ? 'Guardando...' : 'Guardar configuración'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (_testando || _guardando) ? null : _testar,
                      icon: _testando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.play_circle_outline),
                      label: Text(_testando
                          ? 'Probando conexión...'
                          : 'Probar conexión con Google'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1976D2),
                        side: const BorderSide(color: Color(0xFF1976D2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _paso(String num, String titulo, String descripcion) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: Color(0xFF4285F4), shape: BoxShape.circle),
        child: Center(
            child: Text(num,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold))),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          Text(descripcion,
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 12, height: 1.4)),
        ]),
      ),
    ]);
  }

  Widget _buildDemoScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Reseñas de Google'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFFBBC04), size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'Integración con Google Reviews',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Esta es una cuenta de demostración.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _demoInfoCard(
              icon: Icons.sync_rounded,
              color: const Color(0xFF4285F4),
              titulo: '¿Cómo funciona?',
              descripcion:
                  'Conectamos tu cuenta de Google Business Profile a Fluix para '
                  'que las reseñas de tus clientes lleguen automáticamente a la '
                  'aplicación, sin que tengas que hacer nada.',
            ),
            const SizedBox(height: 16),
            _demoInfoCard(
              icon: Icons.save_rounded,
              color: const Color(0xFF34A853),
              titulo: 'Almacenamiento inteligente',
              descripcion:
                  'Guardamos hasta 20 reseñas de forma automática. Cuando se '
                  'alcanza el límite, eliminamos la más antigua para que el '
                  'sistema pueda seguir almacenando las nuevas.',
            ),
            const SizedBox(height: 16),
            _demoInfoCard(
              icon: Icons.reply_rounded,
              color: const Color(0xFFEA4335),
              titulo: 'Responder reseñas',
              descripcion:
                  'Para poder responder a las reseñas directamente desde la '
                  'app necesitas conectar tu perfil de Google Business Profile. '
                  'En la versión completa podrás responder con un solo toque.',
            ),
            const SizedBox(height: 16),
            _demoInfoCard(
              icon: Icons.notifications_active_rounded,
              color: const Color(0xFFFBBC04),
              titulo: 'Notificaciones en tiempo real',
              descripcion:
                  'Recibe una notificación cada vez que un cliente deje una '
                  'nueva reseña, para que puedas reaccionar rápidamente y '
                  'mantener una buena reputación online.',
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_open_rounded, color: Colors.amber[700], size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Activa tu cuenta completa para configurar la integración '
                      'con Google Reviews y responder a tus clientes.',
                      style: TextStyle(color: Colors.amber[900], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _demoInfoCard({
    required IconData icon,
    required Color color,
    required String titulo,
    required String descripcion,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                Text(descripcion,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}






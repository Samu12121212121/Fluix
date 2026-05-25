import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../negocio_publico/pantallas/personalizacion_app_screen.dart';

/// Pantalla de Configuración del Propietario
/// Incluye: Gestión de reseñas Google, configuración de emails, scripts Hostinger
class ConfiguracionPropietarioScreen extends StatefulWidget {
  final String empresaId;

  const ConfiguracionPropietarioScreen({
    super.key,
    required this.empresaId,
  });

  @override
  State<ConfiguracionPropietarioScreen> createState() =>
      _ConfiguracionPropietarioScreenState();
}

class _ConfiguracionPropietarioScreenState
    extends State<ConfiguracionPropietarioScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores
  final _correoReservasCtrl = TextEditingController();
  final _scriptHostingerCtrl = TextEditingController();
  final _placeIdGoogleCtrl = TextEditingController();
  final _apiKeyGoogleCtrl = TextEditingController();
  
  bool _guardando = false;
  bool _enviarEmailReservas = true;
  bool _requiereConfirmacion = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  @override
  void dispose() {
    _correoReservasCtrl.dispose();
    _scriptHostingerCtrl.dispose();
    _placeIdGoogleCtrl.dispose();
    _apiKeyGoogleCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracion() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('configuracion')
          .doc('propietario')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _correoReservasCtrl.text = data['correo_reservas'] ?? '';
          _scriptHostingerCtrl.text = data['script_hostinger'] ?? '';
          _placeIdGoogleCtrl.text = data['google_place_id'] ?? '';
          _apiKeyGoogleCtrl.text = data['google_api_key'] ?? '';
          _enviarEmailReservas = data['enviar_email_reservas'] ?? true;
          _requiereConfirmacion = data['requiere_confirmacion'] ?? true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar configuración: $e')),
        );
      }
    }
  }

  Future<void> _guardarConfiguracion() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('configuracion')
          .doc('propietario')
          .set({
        'correo_reservas': _correoReservasCtrl.text.trim(),
        'script_hostinger': _scriptHostingerCtrl.text.trim(),
        'google_place_id': _placeIdGoogleCtrl.text.trim(),
        'google_api_key': _apiKeyGoogleCtrl.text.trim(),
        'enviar_email_reservas': _enviarEmailReservas,
        'requiere_confirmacion': _requiereConfirmacion,
        'actualizado_en': FieldValue.serverTimestamp(),
        'actualizado_por': FirebaseAuth.instance.currentUser?.uid,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada correctamente'),
            backgroundColor: Color(0xFF00FFC8),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: const Color(0xFFFF2850),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F23),
      appBar: AppBar(
        title: const Text('Configuración del Propietario'),
        backgroundColor: const Color(0xFF151932),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _mostrarAyuda(),
            tooltip: 'Ayuda',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Sección: Configuración de Emails
            _buildSeccionTitulo(
              'Configuración de Emails para Reservas',
              Icons.email,
              const Color(0xFF00FFC8),
            ),
            const SizedBox(height: 16),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Enviar emails automáticos',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Notificar al negocio cuando llegue una reserva',
                      style: TextStyle(color: Color(0xFFB0B3C1), fontSize: 12),
                    ),
                    value: _enviarEmailReservas,
                    onChanged: (val) => setState(() => _enviarEmailReservas = val),
                    activeColor: const Color(0xFF00FFC8),
                  ),
                  const Divider(color: Color(0xFF2A2E45)),
                  SwitchListTile(
                    title: const Text(
                      'Requiere confirmación manual',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'El propietario debe aceptar/rechazar cada reserva',
                      style: TextStyle(color: Color(0xFFB0B3C1), fontSize: 12),
                    ),
                    value: _requiereConfirmacion,
                    onChanged: (val) => setState(() => _requiereConfirmacion = val),
                    activeColor: const Color(0xFFFF3296),
                  ),
                  const Divider(color: Color(0xFF2A2E45)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _correoReservasCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Correo para recibir reservas *',
                      labelStyle: TextStyle(color: Color(0xFFB0B3C1)),
                      hintText: 'reservas@tunegocio.com',
                      hintStyle: TextStyle(color: Color(0xFF6B6E82)),
                      prefixIcon: Icon(Icons.email, color: Color(0xFF00FFC8)),
                      helperText: 'A este correo llegarán las notificaciones de reservas',
                      helperStyle: TextStyle(color: Color(0xFF6B6E82), fontSize: 11),
                      filled: true,
                      fillColor: Color(0xFF1E2139),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa un correo electrónico';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value.trim())) {
                        return 'Correo electrónico inválido';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Sección: Script de Hostinger
            _buildSeccionTitulo(
              'Script de Hostinger (Email Server)',
              Icons.code,
              const Color(0xFFFF3296),
            ),
            const SizedBox(height: 16),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configuración del servidor de correo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pega aquí el script de configuración SMTP de Hostinger. '
                    'Este script se usará para enviar emails desde tu dominio.',
                    style: TextStyle(color: Color(0xFFB0B3C1), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _scriptHostingerCtrl,
                    maxLines: 6,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Script de configuración SMTP',
                      labelStyle: TextStyle(color: Color(0xFFB0B3C1)),
                      hintText: '{\n  "host": "smtp.hostinger.com",\n  "port": 587,\n  ...\n}',
                      hintStyle: TextStyle(color: Color(0xFF6B6E82)),
                      helperText: 'Formato JSON con host, port, user, password',
                      helperStyle: TextStyle(color: Color(0xFF6B6E82), fontSize: 11),
                      filled: true,
                      fillColor: Color(0xFF1E2139),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Color(0xFFFF4678)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Consejo: Usa las credenciales SMTP de tu cuenta de Hostinger',
                          style: TextStyle(
                            color: Colors.orange.shade300,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ───────────────────────────────────────────────
            // Botón de Personalización App
            // ───────────────────────────────────────────────
            _buildSeccionTitulo(
              'Personalización App',
              Icons.palette,
              const Color(0xFF00FFC8),
            ),
            const SizedBox(height: 16),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configura lo que ven tus clientes',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Personaliza la descripción, horarios, galería de fotos, redes sociales y los campos del formulario de reserva.',
                    style: TextStyle(color: Color(0xFFB0B3C1), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonalizacionAppScreen(empresaId: widget.empresaId),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Abrir Personalización App'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFC8),
                      foregroundColor: const Color(0xFF0A0F23),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Sección: Configuración de Emails
            _buildSeccionTitulo(
              'Gestión de Reseñas de Google',
              Icons.star,
              const Color(0xFFFF4678),
            ),
            const SizedBox(height: 16),
            _buildCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Configuración de Google My Business',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Conecta tu negocio con Google para gestionar y responder reseñas',
                    style: TextStyle(color: Color(0xFFB0B3C1), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _placeIdGoogleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Google Place ID',
                      labelStyle: TextStyle(color: Color(0xFFB0B3C1)),
                      hintText: 'ChIJN1t_tDeuEmsRUsoyG83frY4',
                      hintStyle: TextStyle(color: Color(0xFF6B6E82)),
                      prefixIcon: Icon(Icons.place, color: Color(0xFFFF4678)),
                      helperText: 'ID único de tu negocio en Google Maps',
                      helperStyle: TextStyle(color: Color(0xFF6B6E82), fontSize: 11),
                      filled: true,
                      fillColor: Color(0xFF1E2139),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _apiKeyGoogleCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Google API Key',
                      labelStyle: TextStyle(color: Color(0xFFB0B3C1)),
                      hintText: 'AIzaSy...',
                      hintStyle: TextStyle(color: Color(0xFF6B6E82)),
                      prefixIcon: Icon(Icons.key, color: Color(0xFFFF4678)),
                      helperText: 'API Key con acceso a Places API',
                      helperStyle: TextStyle(color: Color(0xFF6B6E82), fontSize: 11),
                      filled: true,
                      fillColor: Color(0xFF1E2139),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _verResenasGoogle(),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ver reseñas en Google'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00FFC8),
                      side: const BorderSide(color: Color(0xFF00FFC8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Botón Guardar
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _guardando ? null : _guardarConfiguracion,
                icon: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_guardando ? 'Guardando...' : 'Guardar Configuración'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFC8),
                  foregroundColor: const Color(0xFF0A0F23),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionTitulo(String titulo, IconData icono, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2139),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2E45)),
      ),
      child: child,
    );
  }

  void _mostrarAyuda() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2139),
        title: const Row(
          children: [
            Icon(Icons.help, color: Color(0xFF00FFC8)),
            SizedBox(width: 8),
            Text('Ayuda de Configuración', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAyudaItem(
                '1. Correo de Reservas',
                'Ingresa el email donde quieres recibir notificaciones cuando alguien haga una reserva.',
              ),
              _buildAyudaItem(
                '2. Script Hostinger',
                'Copia la configuración SMTP de tu panel de Hostinger (host, port, usuario, contraseña).',
              ),
              _buildAyudaItem(
                '3. Google Place ID',
                'Búscalo en Google Cloud Console o en la URL de tu ficha de Google My Business.',
              ),
              _buildAyudaItem(
                '4. Confirmación Manual',
                'Si está activada, deberás aceptar/rechazar cada reserva antes de que se confirme al cliente.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Color(0xFF00FFC8))),
          ),
        ],
      ),
    );
  }

  Widget _buildAyudaItem(String titulo, String descripcion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Color(0xFF00FFC8),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            descripcion,
            style: const TextStyle(color: Color(0xFFB0B3C1), fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _verResenasGoogle() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GestionResenasGoogleScreen(
          empresaId: widget.empresaId,
        ),
      ),
    );
  }
}

/// Pantalla de Gestión de Reseñas de Google
class GestionResenasGoogleScreen extends StatelessWidget {
  final String empresaId;

  const GestionResenasGoogleScreen({
    super.key,
    required this.empresaId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F23),
      appBar: AppBar(
        title: const Text('Reseñas de Google'),
        backgroundColor: const Color(0xFF151932),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.star_border,
                size: 80,
                color: Color(0xFFFF4678),
              ),
              const SizedBox(height: 24),
              const Text(
                'Gestión de Reseñas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Aquí podrás ver y responder a las reseñas de tu negocio en Google.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFB0B3C1)),
              ),
              const SizedBox(height: 32),
              const Text(
                '🚧 Función en desarrollo',
                style: TextStyle(color: Color(0xFFFF4678)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Próximamente: listado de reseñas, respuestas automáticas, estadísticas',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B6E82), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}




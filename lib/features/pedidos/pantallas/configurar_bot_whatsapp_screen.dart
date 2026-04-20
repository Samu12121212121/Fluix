import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Pantalla para configurar el bot de WhatsApp de la empresa.
/// Guarda la config en empresas/{empresaId}/configuracion/whatsapp_bot
class ConfigurarBotWhatsAppScreen extends StatefulWidget {
  final String empresaId;
  const ConfigurarBotWhatsAppScreen({super.key, required this.empresaId});

  @override
  State<ConfigurarBotWhatsAppScreen> createState() =>
      _ConfigurarBotWhatsAppScreenState();
}

class _ConfigurarBotWhatsAppScreenState
    extends State<ConfigurarBotWhatsAppScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneNumberIdCtrl = TextEditingController();
  final _accessTokenCtrl = TextEditingController();
  final _verifyTokenCtrl = TextEditingController();
  final _instruccionesCtrl = TextEditingController();
  final _nombreNegocioCtrl = TextEditingController();
  final _sectorCtrl = TextEditingController();

  bool _activo = false;
  bool _derivarSiNoSabe = true;
  bool _mostrarToken = false;
  bool _cargando = true;
  bool _guardando = false;

  DocumentReference get _configRef => FirebaseFirestore.instance
      .collection('empresas')
      .doc(widget.empresaId)
      .collection('configuracion')
      .doc('whatsapp_bot');

  @override
  void initState() {
    super.initState();
    _cargarConfig();
  }

  @override
  void dispose() {
    _phoneNumberIdCtrl.dispose();
    _accessTokenCtrl.dispose();
    _verifyTokenCtrl.dispose();
    _instruccionesCtrl.dispose();
    _nombreNegocioCtrl.dispose();
    _sectorCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarConfig() async {
    try {
      final doc = await _configRef.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        _phoneNumberIdCtrl.text = data['phone_number_id'] ?? '';
        _accessTokenCtrl.text = data['access_token'] ?? '';
        _verifyTokenCtrl.text = data['verify_token'] ?? '';
        _instruccionesCtrl.text = data['instrucciones_bot'] ?? '';
        _nombreNegocioCtrl.text = data['nombre_negocio'] ?? '';
        _sectorCtrl.text = data['sector'] ?? '';
        _activo = data['activo'] == true;
        _derivarSiNoSabe = data['derivar_si_no_sabe'] != false;
      }
    } catch (e) {
      debugPrint('Error cargando config bot: $e');
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await _configRef.set({
        'phone_number_id': _phoneNumberIdCtrl.text.trim(),
        'access_token': _accessTokenCtrl.text.trim(),
        'verify_token': _verifyTokenCtrl.text.trim(),
        'instrucciones_bot': _instruccionesCtrl.text.trim(),
        'nombre_negocio': _nombreNegocioCtrl.text.trim(),
        'sector': _sectorCtrl.text.trim(),
        'activo': _activo,
        'derivar_si_no_sabe': _derivarSiNoSabe,
        'ultima_actualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuracion del bot guardada'),
            backgroundColor: Color(0xFF25D366),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Configurar Bot WhatsApp'),
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_guardando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Guardar',
              onPressed: _guardar,
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header info ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.smart_toy, size: 40, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Bot WhatsApp',
                                    style: TextStyle(color: Colors.white,
                                        fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                  _activo ? 'Activo' : 'Desactivado',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _activo,
                            onChanged: (v) => setState(() => _activo = v),
                            activeThumbColor: Colors.white,
                            activeTrackColor: Colors.white38,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Datos de la empresa ──────────────────────────────
                    _seccion('Datos del negocio', Icons.store),
                    const SizedBox(height: 8),
                    _campo(
                      controller: _nombreNegocioCtrl,
                      label: 'Nombre del negocio',
                      hint: 'Ej: Peluqueria Ana',
                      icon: Icons.badge,
                    ),
                    const SizedBox(height: 12),
                    _campo(
                      controller: _sectorCtrl,
                      label: 'Sector',
                      hint: 'Ej: peluqueria, hosteleria, clinica...',
                      icon: Icons.category,
                    ),

                    const SizedBox(height: 24),

                    // ── Credenciales Meta ────────────────────────────────
                    _seccion('Credenciales Meta WhatsApp', Icons.key),
                    const SizedBox(height: 4),
                    Text(
                      'Obten estos datos en developers.facebook.com > Tu App > WhatsApp > API Setup',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    _campo(
                      controller: _phoneNumberIdCtrl,
                      label: 'Phone Number ID',
                      hint: 'Ej: 123456789012345',
                      icon: Icons.phone_android,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _accessTokenCtrl,
                      obscureText: !_mostrarToken,
                      decoration: InputDecoration(
                        labelText: 'Access Token',
                        hintText: 'Token permanente de Meta',
                        prefixIcon: const Icon(Icons.vpn_key),
                        suffixIcon: IconButton(
                          icon: Icon(_mostrarToken
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _mostrarToken = !_mostrarToken),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 12),
                    _campo(
                      controller: _verifyTokenCtrl,
                      label: 'Verify Token',
                      hint: 'Token que pusiste en la config del webhook de Meta',
                      icon: Icons.verified_user,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),

                    const SizedBox(height: 16),

                    // ── URL del webhook ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange, size: 18),
                              SizedBox(width: 6),
                              Text('URL del Webhook',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          SizedBox(height: 6),
                          SelectableText(
                            'https://europe-west1-planeaapp-4bea4.cloudfunctions.net/whatsappWebhook',
                            style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Copia esta URL en la configuracion del webhook de Meta.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Instrucciones del bot ────────────────────────────
                    _seccion('Personalidad del bot', Icons.psychology),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _instruccionesCtrl,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText:
                            'Ej: Responde de forma amable. Nuestro horario es de 9 a 20h...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Opciones ─────────────────────────────────────────
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      child: SwitchListTile(
                        value: _derivarSiNoSabe,
                        onChanged: (v) =>
                            setState(() => _derivarSiNoSabe = v),
                        title: const Text('Derivar al equipo si no sabe',
                            style: TextStyle(fontSize: 14)),
                        subtitle: const Text(
                          'El bot responde "Te paso con el equipo" y marca el chat como derivado',
                          style: TextStyle(fontSize: 12),
                        ),
                        secondary: const Icon(Icons.support_agent,
                            color: Color(0xFF25D366)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Boton guardar ────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _guardando ? null : _guardar,
                        icon: _guardando
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save),
                        label: Text(_guardando
                            ? 'Guardando...'
                            : 'Guardar configuracion'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _seccion(String titulo, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 20, color: const Color(0xFF25D366)),
        const SizedBox(width: 8),
        Text(titulo,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
      ],
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }
}



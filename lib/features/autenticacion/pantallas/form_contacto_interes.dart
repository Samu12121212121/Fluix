import 'package:flutter/material.dart';
import '../../../services/contacto_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO — ¿Estás interesado en trabajar con nosotros?
// Aparece en la pantalla de login al pulsar el botón correspondiente.
// ─────────────────────────────────────────────────────────────────────────────

void mostrarFormContactoInteres(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _FormContactoInteres(),
  );
}

class _FormContactoInteres extends StatefulWidget {
  const _FormContactoInteres();

  @override
  State<_FormContactoInteres> createState() => _FormContactoInteresState();
}

class _FormContactoInteresState extends State<_FormContactoInteres> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl      = TextEditingController();
  final _correoCtrl      = TextEditingController();
  final _telefonoCtrl    = TextEditingController();
  final _empresaCtrl     = TextEditingController();
  final _actividadCtrl   = TextEditingController();

  String? _numTrabajadores;
  bool _enviando = false;
  bool _enviado  = false;

  static const _opcionesEmpleados = [
    'Solo yo',
    '2 – 5',
    '6 – 15',
    '16 – 50',
    'Más de 50',
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _empresaCtrl.dispose();
    _actividadCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);

    try {
      print('📋 Enviando formulario de contacto...');
      await ContactoService().enviarContactoInteres(
        nombre:          _nombreCtrl.text.trim(),
        correo:          _correoCtrl.text.trim(),
        telefono:        _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        nombreEmpresa:   _empresaCtrl.text.trim(),
        actividad:       _actividadCtrl.text.trim(),
        numTrabajadores: _numTrabajadores,
      );
      print('✅ Formulario enviado correctamente');
      if (mounted) {
        setState(() { _enviando = false; _enviado = true; });
        // Mostrar confirmación adicional
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Solicitud enviada. Revisa tu correo.'),
          backgroundColor: Color(0xFF43A047),
          duration: Duration(seconds: 3),
        ));
      }
    } catch (e, stack) {
      print('❌ Error al enviar formulario: $e');
      print('Stack: $stack');
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al enviar: $e\n\nRevisa tu conexión e inténtalo de nuevo.'),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Contenido: pantalla de éxito o formulario
          _enviado ? _buildExito() : _buildFormulario(),
        ],
      ),
    );
  }

  // ── Pantalla de éxito ─────────────────────────────────────────────────────
  Widget _buildExito() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: Color(0xFF43A047), size: 44),
          ),
          const SizedBox(height: 20),
          const Text(
            '¡Solicitud enviada! 🎉',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Hemos recibido tus datos y te hemos enviado un correo de confirmación.\n\nNos pondremos en contacto contigo en breve.',
            style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cerrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Formulario ────────────────────────────────────────────────────────────
  Widget _buildFormulario() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¿Interesado en trabajar\ncon nosotros? 🤝',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rellena el formulario y te contactaremos en breve',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                color: Colors.grey[500],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Campo: Nombre completo
          _campo(
            controller: _nombreCtrl,
            label:       'Nombre completo',
            icono:       Icons.person_outline,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
          ),
          const SizedBox(height: 12),

          // Campo: Correo
          _campo(
            controller:  _correoCtrl,
            label:       'Correo electrónico',
            icono:       Icons.email_outlined,
            tipo:        TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
              if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                return 'Correo no válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Campo: Teléfono (opcional)
          _campo(
            controller:  _telefonoCtrl,
            label:       'Teléfono (opcional)',
            icono:       Icons.phone_outlined,
            tipo:        TextInputType.phone,
            required:    false,
          ),
          const SizedBox(height: 12),

          // Campo: Nombre empresa
          _campo(
            controller:  _empresaCtrl,
            label:       'Nombre de la empresa',
            icono:       Icons.business_outlined,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
          ),
          const SizedBox(height: 12),

          // Campo: ¿A qué se dedica? (textarea)
          TextFormField(
            controller: _actividadCtrl,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: '¿A qué se dedica tu empresa?',
              hintText: 'Ej: Peluquería canina, restaurante, clínica dental...',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.work_outline),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
              alignLabelWithHint: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
          ),
          const SizedBox(height: 12),

          // Dropdown: Número de empleados
          DropdownButtonFormField<String>(
            value: _numTrabajadores,
            decoration: InputDecoration(
              labelText: 'Número de trabajadores (opcional)',
              prefixIcon: const Icon(Icons.people_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: _opcionesEmpleados
                .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: (v) => setState(() => _numTrabajadores = v),
          ),
          const SizedBox(height: 24),

          // Botón enviar
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _enviando ? null : _enviar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: _enviando
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Enviar solicitud',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '🔒 Tus datos están seguros y no serán compartidos',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper: campo de texto estándar ──────────────────────────────────────
  Widget _campo({
    required TextEditingController controller,
    required String                label,
    required IconData              icono,
    TextInputType                  tipo     = TextInputType.text,
    bool                           required = true,
    String? Function(String?)?     validator,
  }) {
    return TextFormField(
      controller:   controller,
      keyboardType: tipo,
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icono),
        border:     OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled:     true,
        fillColor:  Colors.grey[50],
      ),
      validator: validator ?? (required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null
          : null),
    );
  }
}



import 'package:flutter/material.dart';
import '../../../services/contacto_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO — ¿Estás interesado en trabajar con nosotros?
// Estilo dark igual que el login principal
// ─────────────────────────────────────────────────────────────────────────────

// Paleta dark (misma que login)
const _kBgForm     = Color(0xFF0A0F23);
const _kSurfaceF   = Color(0xFF1E2139);
const _kBorderF    = Color(0xFF2A2E45);
const _kAccentF    = Color(0xFF00FFC8);
const _kTextoF     = Color(0xFFFFFFFF);
const _kMutedF     = Color(0xFFB0B3C1);

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
      await ContactoService().enviarContactoInteres(
        nombre:          _nombreCtrl.text.trim(),
        correo:          _correoCtrl.text.trim(),
        telefono:        _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
        nombreEmpresa:   _empresaCtrl.text.trim(),
        actividad:       _actividadCtrl.text.trim(),
        numTrabajadores: _numTrabajadores,
      );
      if (mounted) {
        setState(() { _enviando = false; _enviado = true; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Solicitud enviada. Revisa tu correo.'),
          backgroundColor: Color(0xFF00C48C),
          duration: Duration(seconds: 3),
        ));
      }
    } catch (e) {
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
        color: _kBgForm,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: _kAccentF, width: 2)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _kBorderF,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Contenido: pantalla de éxito o formulario
            _enviado ? _buildExito() : _buildFormulario(),
          ],
        ),
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
            decoration: BoxDecoration(
              color: _kAccentF.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: _kAccentF, width: 2),
            ),
            child: const Icon(Icons.check_circle, color: _kAccentF, size: 44),
          ),
          const SizedBox(height: 20),
          const Text(
            '¡Solicitud enviada! 🎉',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _kTextoF),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Hemos recibido tus datos y te hemos enviado un correo de confirmación.\n\nNos pondremos en contacto contigo en breve.',
            style: TextStyle(fontSize: 15, color: _kMutedF, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccentF,
                foregroundColor: _kBgForm,
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
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.3, color: _kTextoF),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Rellena el formulario y te contactaremos en breve',
                      style: TextStyle(fontSize: 13, color: _kMutedF),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: _kMutedF),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _campo(controller: _nombreCtrl, label: 'Nombre completo', icono: Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null),
          const SizedBox(height: 12),
          _campo(
            controller: _correoCtrl, label: 'Correo electrónico', icono: Icons.email_outlined,
            tipo: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
              if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Correo no válido';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _campo(controller: _telefonoCtrl, label: 'Teléfono (opcional)', icono: Icons.phone_outlined,
              tipo: TextInputType.phone, required: false),
          const SizedBox(height: 12),
          _campo(controller: _empresaCtrl, label: 'Nombre de la empresa', icono: Icons.business_outlined,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null),
          const SizedBox(height: 12),

          // Textarea actividad
          TextFormField(
            controller: _actividadCtrl,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
            style: const TextStyle(color: _kTextoF),
            decoration: InputDecoration(
              labelText: '¿A qué se dedica tu empresa?',
              hintText: 'Ej: Peluquería canina, restaurante…',
              labelStyle: const TextStyle(color: _kMutedF),
              hintStyle: const TextStyle(color: Color(0xFF6B6E82)),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 44),
                child: Icon(Icons.work_outline, color: _kAccentF),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorderF)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorderF)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kAccentF, width: 2)),
              filled: true,
              fillColor: _kSurfaceF,
              alignLabelWithHint: true,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
          ),
          const SizedBox(height: 12),

          // Dropdown empleados
          DropdownButtonFormField<String>(
            value: _numTrabajadores,
            dropdownColor: _kSurfaceF,
            style: const TextStyle(color: _kTextoF),
            decoration: InputDecoration(
              labelText: 'Número de trabajadores (opcional)',
              labelStyle: const TextStyle(color: _kMutedF),
              prefixIcon: const Icon(Icons.people_outline, color: _kAccentF),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorderF)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorderF)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kAccentF, width: 2)),
              filled: true,
              fillColor: _kSurfaceF,
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
                backgroundColor: _kAccentF,
                foregroundColor: _kBgForm,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _enviando
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _kBgForm))
                  : const Text('Enviar solicitud', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '🔒 Tus datos están seguros y no serán compartidos',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B6E82)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper: campo de texto estándar oscuro ────────────────────────────────
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
      style: const TextStyle(color: _kTextoF),
      decoration: InputDecoration(
        labelText:  label,
        labelStyle: const TextStyle(color: _kMutedF),
        prefixIcon: Icon(icono, color: _kAccentF),
        border:     OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorderF)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorderF)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kAccentF, width: 2)),
        filled:     true,
        fillColor:  _kSurfaceF,
      ),
      validator: validator ?? (required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null
          : null),
    );
  }
}

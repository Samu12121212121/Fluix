import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PANTALLA PÚBLICA DE RESERVAS
// Accesible desde https://app.fluix.es/reservar/{empresaId}
// Sin autenticación. Guarda en empresas/{id}/reservas con origen:'web'
// ═════════════════════════════════════════════════════════════════════════════

class PantallaReservaPublica extends StatelessWidget {
  final String empresaId;
  const PantallaReservaPublica({super.key, required this.empresaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('empresas')
            .doc(empresaId)
            .get(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const _ErrorNegocio();
          }
          final data = snap.data!.data() as Map<String, dynamic>? ?? {};
          final nombre = data['nombre'] as String? ??
              data['nombre_empresa'] as String? ?? 'Reserva';
          final logo   = data['logo_url'] as String?;
          final color  = _parseColor(data['color_primario'] as String?) ??
              const Color(0xFF1565C0);
          return _FormReservaPublica(
            empresaId: empresaId,
            nombreEmpresa: nombre,
            logoUrl: logo,
            color: color,
          );
        },
      ),
    );
  }

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    try {
      final c = hex.replaceAll('#', '');
      return Color(int.parse('FF$c', radix: 16));
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FormReservaPublica extends StatefulWidget {
  final String empresaId;
  final String nombreEmpresa;
  final String? logoUrl;
  final Color color;

  const _FormReservaPublica({
    required this.empresaId,
    required this.nombreEmpresa,
    required this.logoUrl,
    required this.color,
  });

  @override
  State<_FormReservaPublica> createState() => _FormReservaPublicaState();
}

class _FormReservaPublicaState extends State<_FormReservaPublica> {
  final _formKey   = GlobalKey<FormState>();
  final _ctrlNombre   = TextEditingController();
  final _ctrlTelefono = TextEditingController();
  final _ctrlEmail    = TextEditingController();
  final _ctrlNotas    = TextEditingController();

  int _personas      = 2;
  DateTime _fecha    = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _hora    = const TimeOfDay(hour: 13, minute: 0);
  bool _guardando    = false;
  bool _enviado      = false;

  @override
  void dispose() {
    _ctrlNombre.dispose();
    _ctrlTelefono.dispose();
    _ctrlEmail.dispose();
    _ctrlNotas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_enviado) return _PantallaExito(nombre: _ctrlNombre.text,
        color: widget.color, nombreEmpresa: widget.nombreEmpresa);

    return CustomScrollView(slivers: [
      // AppBar con logo/nombre del negocio
      SliverAppBar(
        expandedHeight: 140,
        pinned: true,
        backgroundColor: widget.color,
        automaticallyImplyLeading: false,
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            color: widget.color,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(height: 40),
              if (widget.logoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(widget.logoUrl!,
                      width: 52, height: 52, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              const SizedBox(height: 8),
              Text(widget.nombreEmpresa,
                  style: const TextStyle(color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const Text('Solicitar reserva',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
        ),
      ),

      // Formulario
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _card([
                _campo(_ctrlNombre, 'Tu nombre *',
                    icon: Icons.person_outline, validator: _req),
                const SizedBox(height: 14),
                _campo(_ctrlTelefono, 'Teléfono *',
                    icon: Icons.phone_outlined,
                    tipo: TextInputType.phone, validator: _req),
                const SizedBox(height: 14),
                _campo(_ctrlEmail, 'Email (opcional)',
                    icon: Icons.email_outlined,
                    tipo: TextInputType.emailAddress),
              ], titulo: 'Tus datos'),
              const SizedBox(height: 16),
              _card([
                // Fecha
                _selectorFecha(),
                const SizedBox(height: 14),
                // Hora
                _selectorHora(),
                const SizedBox(height: 14),
                // Personas
                _selectorPersonas(),
              ], titulo: 'Fecha y hora'),
              const SizedBox(height: 16),
              _card([
                _campo(_ctrlNotas, 'Notas adicionales (alérgenos, peticiones...)',
                    icon: Icons.notes_outlined, maxLines: 3),
              ], titulo: 'Notas'),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _enviar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _guardando
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Solicitar reserva',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
              Center(child: Text('Powered by Fluix',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]))),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    ]);
  }

  // ── Selectores ────────────────────────────────────────────────────────────

  Widget _selectorFecha() {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: _fecha,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 180)),
          locale: const Locale('es', 'ES'),
        );
        if (d != null) setState(() => _fecha = d);
      },
      child: _readonlyRow(Icons.calendar_today_outlined, 'Fecha',
          '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}'),
    );
  }

  Widget _selectorHora() {
    return InkWell(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: _hora);
        if (t != null) setState(() => _hora = t);
      },
      child: _readonlyRow(Icons.access_time_outlined, 'Hora',
          '${_hora.hour.toString().padLeft(2, '0')}:${_hora.minute.toString().padLeft(2, '0')}'),
    );
  }

  Widget _selectorPersonas() {
    return Row(children: [
      const Icon(Icons.people_outline, size: 20, color: Color(0xFF64748B)),
      const SizedBox(width: 12),
      const Expanded(child: Text('Personas',
          style: TextStyle(fontSize: 15, color: Color(0xFF334155)))),
      IconButton(
        icon: const Icon(Icons.remove_circle_outline),
        color: const Color(0xFF64748B),
        onPressed: _personas > 1 ? () => setState(() => _personas--) : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('$_personas',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A))),
      ),
      IconButton(
        icon: const Icon(Icons.add_circle_outline),
        color: const Color(0xFF64748B),
        onPressed: _personas < 20 ? () => setState(() => _personas++) : null,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    ]);
  }

  Widget _readonlyRow(IconData icon, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11,
              color: Color(0xFF94A3B8))),
          Text(valor, style: const TextStyle(fontSize: 15,
              fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        ])),
        const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
      ]),
    );
  }

  // ── Campo texto ───────────────────────────────────────────────────────────

  Widget _campo(TextEditingController ctrl, String label, {
    IconData? icon,
    TextInputType tipo = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, size: 18, color: const Color(0xFF94A3B8))
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: widget.color, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }

  Widget _card(List<Widget> children, {required String titulo}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EDF2)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w700, color: Color(0xFF64748B),
            letterSpacing: 0.3)),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }

  // ── Guardar ───────────────────────────────────────────────────────────────

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final fechaHora = DateTime(
          _fecha.year, _fecha.month, _fecha.day, _hora.hour, _hora.minute);
      await FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.empresaId)
          .collection('reservas')
          .add({
        'nombre_cliente':   _ctrlNombre.text.trim(),
        'telefono_cliente': _ctrlTelefono.text.trim(),
        'email_cliente':    _ctrlEmail.text.trim(),
        'personas':         _personas,
        'comensales':       _personas,
        'fecha_hora':       Timestamp.fromDate(fechaHora),
        'estado':           'PENDIENTE',
        'origen':           'web',
        'comentarios':      _ctrlNotas.text.trim(),
        'fecha_creacion':   FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _enviado = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al enviar: $e'),
          backgroundColor: Colors.red,
        ));
        setState(() => _guardando = false);
      }
    }
  }

  String? _req(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla de éxito
// ─────────────────────────────────────────────────────────────────────────────

class _PantallaExito extends StatelessWidget {
  final String nombre;
  final String nombreEmpresa;
  final Color color;

  const _PantallaExito({
    required this.nombre,
    required this.nombreEmpresa,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, size: 44, color: color),
            ),
            const SizedBox(height: 24),
            Text('¡Reserva enviada!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 12),
            Text('Gracias, ${nombre.isNotEmpty ? nombre : 'cliente'}.',
                style: const TextStyle(fontSize: 16, color: Color(0xFF334155))),
            const SizedBox(height: 8),
            Text('$nombreEmpresa confirmará tu reserva a la mayor brevedad.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                textAlign: TextAlign.center),
            const SizedBox(height: 40),
            Text('Powered by Fluix',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ErrorNegocio extends StatelessWidget {
  const _ErrorNegocio();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: 48, color: Colors.red),
        SizedBox(height: 16),
        Text('Enlace no válido',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Este formulario de reservas no está disponible.',
            style: TextStyle(color: Colors.grey)),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ReservaFormWidget
//
// Crea un documento en negocios_publicos/{negocioId}/reservas/{id} con
// status: 'pending'. La Cloud Function onReservaPublicaCreada lo detecta y
// envía el email con botones JWT al emailNotificaciones del negocio.
//
// Uso:
//   ReservaFormWidget(
//     negocioId: negocio.id,
//     negocioNombre: negocio.nombre,
//     servicioPreseleccionado: servicio?.nombre,  // opcional
//   )
//
// Firestore rules: permitir create en
//   negocios_publicos/{negocioId}/reservas/{id}
// ─────────────────────────────────────────────────────────────────────────────

enum _Estado { formulario, cargando, exito, error }

class ReservaFormWidget extends StatefulWidget {
  final String negocioId;
  final String negocioNombre;
  final String? servicioPreseleccionado;

  const ReservaFormWidget({
    super.key,
    required this.negocioId,
    required this.negocioNombre,
    this.servicioPreseleccionado,
  });

  @override
  State<ReservaFormWidget> createState() => _ReservaFormWidgetState();
}

class _ReservaFormWidgetState extends State<ReservaFormWidget> {
  // Design system alineado con tab_reservas_screen.dart / DetalleNegocioScreen
  static const _bg         = Color(0xFF0A0F23);
  static const _superficie  = Color(0xFF151932);
  static const _borde       = Color(0xFF2A2E45);
  static const _accent      = Color(0xFF00FFC8);
  static const _accentRosa  = Color(0xFFFF3296);
  static const _texto       = Color(0xFFFFFFFF);
  static const _muted       = Color(0xFFB0B3C1);

  final _formKey     = GlobalKey<FormState>();
  final _nombreCtrl  = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _notasCtrl   = TextEditingController();
  final _personasCtrl = TextEditingController(text: '1');

  DateTime? _fecha;
  TimeOfDay? _hora;
  _Estado _estado = _Estado.formulario;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailCtrl.text  = user.email ?? '';
      _nombreCtrl.text = user.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _notasCtrl.dispose();
    _personasCtrl.dispose();
    super.dispose();
  }

  // ── Selectores ──────────────────────────────────────────────────────────────

  Future<void> _seleccionarFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            surface: _superficie,
            onSurface: _texto,
          ),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _fecha = d);
  }

  Future<void> _seleccionarHora() async {
    final t = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _accent,
            surface: _superficie,
            onSurface: _texto,
          ),
        ),
        child: child!,
      ),
    );
    if (t != null) setState(() => _hora = t);
  }

  // ── Envío ────────────────────────────────────────────────────────────────────

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fecha == null || _hora == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona fecha y hora'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _estado = _Estado.cargando);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      // Formato YYYY-MM-DD y HH:MM requerido por onReservaPublicaCreada
      final dateStr =
          '${_fecha!.year.toString().padLeft(4, '0')}-'
          '${_fecha!.month.toString().padLeft(2, '0')}-'
          '${_fecha!.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${_hora!.hour.toString().padLeft(2, '0')}:'
          '${_hora!.minute.toString().padLeft(2, '0')}';

      final datos = <String, dynamic>{
        'customerName':  _nombreCtrl.text.trim(),
        'customerEmail': _emailCtrl.text.trim(),
        'phone':         _telefonoCtrl.text.trim(),
        'date':          dateStr,
        'time':          timeStr,
        'guests':        int.tryParse(_personasCtrl.text.trim()) ?? 1,
        'notes':         _notasCtrl.text.trim(),
        'status':        'pending',
        'createdAt':     FieldValue.serverTimestamp(),
        'updatedAt':     FieldValue.serverTimestamp(),
        if (widget.servicioPreseleccionado != null)
          'servicio': widget.servicioPreseleccionado,
        if (uid != null) 'usuarioUid': uid,
      };

      await FirebaseFirestore.instance
          .collection('negocios_publicos')
          .doc(widget.negocioId)
          .collection('reservas')
          .add(datos);

      if (mounted) setState(() => _estado = _Estado.exito);
    } catch (e) {
      if (mounted) {
        setState(() {
          _estado = _Estado.error;
          _errorMsg = e.toString();
        });
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => switch (_estado) {
        _Estado.cargando    => _buildCargando(),
        _Estado.exito       => _buildExito(),
        _Estado.error       => _buildError(),
        _Estado.formulario  => _buildFormulario(),
      };

  Widget _buildCargando() => const Center(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
        SizedBox(height: 18),
        Text('Enviando solicitud…',
            style: TextStyle(color: _muted, fontSize: 14)),
      ]),
    ),
  );

  Widget _buildExito() => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.check_circle_rounded, color: _accent, size: 68),
      const SizedBox(height: 18),
      const Text('¡Solicitud enviada!',
          style: TextStyle(
              color: _texto, fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
      const SizedBox(height: 10),
      Text(
        '${widget.negocioNombre} recibirá tu solicitud y te confirmará por email en ${_emailCtrl.text}.',
        style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      const Text(
        'Si no reciben respuesta en 60 min, recibirás un email automático.',
        style: TextStyle(color: Color(0xFF6B6E82), fontSize: 12),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 28),
      TextButton.icon(
        onPressed: () => setState(() {
          _estado = _Estado.formulario;
          _fecha = null;
          _hora = null;
        }),
        icon: const Icon(Icons.add_circle_outline_rounded, color: _accent, size: 18),
        label: const Text('Hacer otra reserva',
            style: TextStyle(color: _accent, fontSize: 14)),
      ),
    ]),
  );

  Widget _buildError() => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, color: _accentRosa, size: 60),
      const SizedBox(height: 14),
      const Text('Error al enviar',
          style: TextStyle(
              color: _texto, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      Text(_errorMsg,
          style: const TextStyle(color: _muted, fontSize: 12),
          textAlign: TextAlign.center),
      const SizedBox(height: 20),
      TextButton(
        onPressed: () => setState(() => _estado = _Estado.formulario),
        child: const Text('Volver a intentar',
            style: TextStyle(color: _accent)),
      ),
    ]),
  );

  Widget _buildFormulario() {
    final fechaTxt = _fecha != null
        ? '${_fecha!.day.toString().padLeft(2, '0')}/'
          '${_fecha!.month.toString().padLeft(2, '0')}/'
          '${_fecha!.year}'
        : 'Seleccionar fecha';
    final horaTxt = _hora != null ? _hora!.format(context) : 'Seleccionar hora';

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Header
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: _accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reservar en ${widget.negocioNombre}',
                style: const TextStyle(
                    color: _texto, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ]),

          if (widget.servicioPreseleccionado != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accent.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.content_cut_rounded, color: _accent, size: 16),
                const SizedBox(width: 8),
                Text(widget.servicioPreseleccionado!,
                    style: const TextStyle(
                        color: _accent, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],

          const SizedBox(height: 18),

          // Campos personales
          _campo(_nombreCtrl, 'Nombre completo *', Icons.person_outline_rounded,
              validator: _obligatorio),
          const SizedBox(height: 12),
          _campo(_emailCtrl, 'Email *', Icons.email_outlined,
              teclado: TextInputType.emailAddress,
              validator: _validarEmail),
          const SizedBox(height: 12),
          _campo(_telefonoCtrl, 'Teléfono', Icons.phone_outlined,
              teclado: TextInputType.phone),
          const SizedBox(height: 14),

          // Fecha y hora
          Row(children: [
            Expanded(child: _selector(fechaTxt, Icons.calendar_today_outlined,
                _fecha != null, _seleccionarFecha)),
            const SizedBox(width: 10),
            Expanded(child: _selector(horaTxt, Icons.access_time_rounded,
                _hora != null, _seleccionarHora)),
          ]),
          const SizedBox(height: 12),

          // Personas
          _campo(_personasCtrl, 'Nº de personas', Icons.people_outline_rounded,
              teclado: TextInputType.number),
          const SizedBox(height: 12),

          // Notas
          _campo(_notasCtrl, 'Notas o peticiones especiales', null,
              lineas: 3),
          const SizedBox(height: 22),

          // Botón enviar
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _enviar,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: const Text('Solicitar reserva',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: _bg,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'El negocio confirmará tu reserva por email en menos de 60 min.',
            style: TextStyle(color: Color(0xFF6B6E82), fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Helpers de UI ────────────────────────────────────────────────────────────

  Widget _campo(
    TextEditingController ctrl,
    String label,
    IconData? icono, {
    TextInputType? teclado,
    int lineas = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: teclado,
        maxLines: lineas,
        style: const TextStyle(color: _texto, fontSize: 14),
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: _muted, fontSize: 13),
          prefixIcon: icono != null
              ? Icon(icono, color: _muted, size: 18)
              : null,
          filled: true,
          fillColor: _superficie,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borde)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _borde)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accent, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accentRosa)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );

  Widget _selector(
    String texto,
    IconData icono,
    bool seleccionado,
    VoidCallback onTap,
  ) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: _superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: seleccionado ? _accent : _borde, width: 1.2),
          ),
          child: Row(children: [
            Icon(icono,
                color: seleccionado ? _accent : _muted, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texto,
                style: TextStyle(
                    color: seleccionado ? _texto : _muted,
                    fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      );

  String? _obligatorio(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  String? _validarEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
    final ok = RegExp(r'^[\w.+\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(v.trim());
    return ok ? null : 'Email no válido';
  }
}

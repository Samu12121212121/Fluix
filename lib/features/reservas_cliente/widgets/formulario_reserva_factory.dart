import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/negocio_publico_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Servicio compartido para guardar reserva + disparar notificación al negocio
// ─────────────────────────────────────────────────────────────────────────────
class ReservaService {
  static Future<void> guardarYNotificar({
    required NegocioPublico negocio,
    required Map<String, dynamic> datos,
    required BuildContext ctx,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('No autenticado. Por favor inicia sesión para reservar.');

    final empresaId = negocio.empresaIdVinculada;
    if (empresaId.isEmpty) {
      throw Exception('Este negocio no puede recibir reservas online en este momento.');
    }

    // 1. Guardar reserva en la colección de la empresa
    final docRef = await FirebaseFirestore.instance
        .collection('empresas')
        .doc(empresaId)
        .collection('reservas')
        .add({
      ...datos,
      'usuario_uid': uid,
      'estado': 'pendiente',
      'origen': 'app_cliente',
      'negocio_id': negocio.id,
      'negocio_nombre': negocio.nombre,
      'creado_en': FieldValue.serverTimestamp(),
    });

    // 2. Disparar notificación → Cloud Function onNuevaReservaEmail
    try {
      await FirebaseFirestore.instance
          .collection('notificaciones_reservas')
          .add({
        'reserva_id': docRef.id,
        'empresa_id': empresaId,
        'negocio_id': negocio.id,
        'negocio_nombre': negocio.nombre,
        'email_notificaciones': negocio.emailNotificaciones ?? '',
        'datos_reserva': datos,
        'procesado': false,
        'creado_en': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // La notificación es opcional — no bloquear si falla
    }
  }
}

class FormularioReservaFactory {
  static Widget crearFormulario({
    required CategoriaNegocio categoria,
    required NegocioPublico negocio,
  }) {
    // Si el negocio tiene formulario personalizado configurado → usarlo
    if (negocio.formularioTitulo != null ||
        (negocio.camposPersonalizados != null && negocio.camposPersonalizados!.isNotEmpty)) {
      return FormularioPersonalizado(negocio: negocio);
    }
    switch (categoria) {
      case CategoriaNegocio.esteticas:
      case CategoriaNegocio.peluquerias:
        return FormularioEsteticaPeluqueria(negocio: negocio);
      case CategoriaNegocio.restaurantes:
        return FormularioRestaurante(negocio: negocio);
      default:
        return FormularioEstandar(negocio: negocio);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Paleta oscura interna (coherente con pantalla_explorar.dart)
// ─────────────────────────────────────────────────────────────────────────────
class _CF {
  static const fondo      = Color(0xFF0A0F23);
  static const superficie = Color(0xFF151932);
  static const tarjeta    = Color(0xFF1E2139);
  static const borde      = Color(0xFF2A2E45);
  static const accent     = Color(0xFF00FFC8);
  static const accentRosa = Color(0xFFFF3296);
  static const texto      = Color(0xFFFFFFFF);
  static const textoMuted = Color(0xFFB0B3C1);
  static const textoHint  = Color(0xFF6B6E82);

  static InputDecoration inputDecor(String label, IconData? icon) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _CF.textoMuted, fontSize: 13),
    hintStyle: const TextStyle(color: _CF.textoHint, fontSize: 13),
    prefixIcon: icon != null ? Icon(icon, color: _CF.textoMuted, size: 18) : null,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _CF.borde),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _CF.borde),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _CF.accent, width: 1.5),
    ),
    filled: true,
    fillColor: _CF.superficie,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// FORMULARIO PERSONALIZADO (dinámico, configurado por el negocio admin)
// ═══════════════════════════════════════════════════════════════════════════

class FormularioPersonalizado extends StatefulWidget {
  final NegocioPublico negocio;
  const FormularioPersonalizado({super.key, required this.negocio});

  @override
  State<FormularioPersonalizado> createState() => _FormularioPersonalizadoState();
}

class _FormularioPersonalizadoState extends State<FormularioPersonalizado> {
  final _formKey = GlobalKey<FormState>();
  bool _cargando = false;
  final Map<String, dynamic> _valores = {};

  @override
  Widget build(BuildContext context) {
    final campos = widget.negocio.camposPersonalizados ?? [];
    final titulo = widget.negocio.formularioTitulo ?? 'Reservar';
    final boton = widget.negocio.formularioBoton ?? 'Confirmar reserva';

    return Form(
      key: _formKey,
      child: Container(
        decoration: BoxDecoration(
          color: _CF.tarjeta,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _CF.borde),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 4, height: 28,
                decoration: BoxDecoration(
                  color: _CF.accent, borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(titulo, style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: _CF.texto,
              )),
            ]),
            const SizedBox(height: 20),
            ...campos.map((campo) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCampo(context, campo),
            )),
            const SizedBox(height: 24),
            // Botón enviar
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _cargando ? null : _enviar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _CF.accent, foregroundColor: _CF.fondo,
                  disabledBackgroundColor: _CF.borde, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _cargando
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: _CF.fondo, strokeWidth: 2.5))
                    : Text(boton, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampo(BuildContext context, CampoPersonalizado campo) {
    final label = '${campo.label}${campo.obligatorio ? ' *' : ''}';
    switch (campo.tipo) {
      case 'fecha':
        final fecha = _valores[campo.id] as DateTime?;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final sel = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              locale: const Locale('es', 'ES'),
              builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: _CF.accent, onPrimary: _CF.fondo,
                  surface: _CF.tarjeta, onSurface: _CF.texto,
                )), child: child!),
            );
            if (sel != null) setState(() => _valores[campo.id] = sel);
          },
          child: InputDecorator(
            decoration: _CF.inputDecor(label, Icons.calendar_today_outlined),
            child: Text(
              fecha == null
                  ? campo.placeholder ?? 'Selecciona una fecha'
                  : '${fecha.day}/${fecha.month}/${fecha.year}',
              style: TextStyle(color: fecha == null ? _CF.textoHint : _CF.texto, fontSize: 14),
            ),
          ),
        );

      case 'hora':
        final hora = _valores[campo.id] as TimeOfDay?;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final sel = await showTimePicker(
              context: context, initialTime: TimeOfDay.now(),
              builder: (ctx, child) => Theme(data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: _CF.accent, onPrimary: _CF.fondo,
                  surface: _CF.tarjeta, onSurface: _CF.texto,
                )), child: child!),
            );
            if (sel != null) setState(() => _valores[campo.id] = sel);
          },
          child: InputDecorator(
            decoration: _CF.inputDecor(label, Icons.access_time_outlined),
            child: Text(
              hora == null
                  ? campo.placeholder ?? 'Selecciona una hora'
                  : hora.format(context),
              style: TextStyle(color: hora == null ? _CF.textoHint : _CF.texto, fontSize: 14),
            ),
          ),
        );

      case 'selector':
        return Theme(
          data: ThemeData.dark().copyWith(canvasColor: _CF.superficie),
          child: DropdownButtonFormField<String>(
            value: _valores[campo.id] as String?,
            dropdownColor: _CF.superficie,
            style: const TextStyle(color: _CF.texto, fontSize: 14),
            decoration: _CF.inputDecor(label, null),
            items: (campo.opciones ?? []).map((o) =>
                DropdownMenuItem(value: o,
                    child: Text(o, style: const TextStyle(color: _CF.texto)))).toList(),
            onChanged: (v) => setState(() => _valores[campo.id] = v),
            validator: campo.obligatorio ? (v) => v == null ? 'Campo obligatorio' : null : null,
          ),
        );

      case 'numero':
        return TextFormField(
          keyboardType: TextInputType.number,
          initialValue: _valores[campo.id]?.toString(),
          style: const TextStyle(color: _CF.texto, fontSize: 14),
          decoration: _CF.inputDecor(label, null),
          onChanged: (v) => _valores[campo.id] = int.tryParse(v) ?? v,
          validator: campo.obligatorio
              ? (v) => (v == null || v.isEmpty) ? 'Campo obligatorio' : null : null,
        );

      case 'checkbox':
        return Container(
          decoration: BoxDecoration(
            color: _CF.superficie, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _CF.borde),
          ),
          child: CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(label, style: const TextStyle(fontSize: 13, color: _CF.texto)),
            value: _valores[campo.id] as bool? ?? false,
            onChanged: (v) => setState(() => _valores[campo.id] = v),
            activeColor: _CF.accent, checkColor: _CF.fondo,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );

      default: // texto, email, telefono
        return TextFormField(
          keyboardType: campo.tipo == 'email'
              ? TextInputType.emailAddress
              : campo.tipo == 'telefono'
                  ? TextInputType.phone
                  : TextInputType.multiline,
          maxLines: campo.tipo == 'textarea' ? 3 : 1,
          style: const TextStyle(color: _CF.texto, fontSize: 14),
          decoration: _CF.inputDecor(label, null),
          onChanged: (v) => _valores[campo.id] = v,
          validator: campo.obligatorio
              ? (v) => (v == null || v.isEmpty) ? 'Campo obligatorio' : null : null,
        );
    }
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar campos fecha/hora obligatorios
    final campos = widget.negocio.camposPersonalizados ?? [];
    for (final campo in campos) {
      if (campo.obligatorio && (campo.tipo == 'fecha' || campo.tipo == 'hora')) {
        if (!_valores.containsKey(campo.id) || _valores[campo.id] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selecciona ${campo.label}'), backgroundColor: Colors.orange),
          );
          return;
        }
      }
    }

    setState(() => _cargando = true);
    try {
      // Serializar valores
      final datosSerializados = <String, dynamic>{};
      for (final entry in _valores.entries) {
        final v = entry.value;
        if (v is DateTime) {
          datosSerializados[entry.key] = Timestamp.fromDate(v);
        } else if (v is TimeOfDay) {
          datosSerializados[entry.key] = '${v.hour.toString().padLeft(2,'0')}:${v.minute.toString().padLeft(2,'0')}';
        } else {
          datosSerializados[entry.key] = v;
        }
      }

      await ReservaService.guardarYNotificar(
        negocio: widget.negocio,
        ctx: context,
        datos: datosSerializados,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡${widget.negocio.formularioBoton ?? "Solicitud"} enviada con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
      // Limpiar formulario
      setState(() => _valores.clear());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FORMULARIO PARA ESTÉTICAS Y PELUQUERÍAS
// ═══════════════════════════════════════════════════════════════════════════

class FormularioEsteticaPeluqueria extends StatefulWidget {
  final NegocioPublico negocio;

  const FormularioEsteticaPeluqueria({super.key, required this.negocio});

  @override
  State<FormularioEsteticaPeluqueria> createState() => _FormularioEsteticaPeluqueriaState();
}

class _FormularioEsteticaPeluqueriaState extends State<FormularioEsteticaPeluqueria> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _fechaSeleccionada;
  TimeOfDay? _horaSeleccionada;
  String? _empleadoSeleccionado;
  String? _servicioSeleccionado;
  String? _empleadoNombre;
  String? _servicioNombre;
  double? _servicioPrecio;
  bool _cargando = false;
  final Map<String, dynamic> _camposExtra = {};

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Container(
        decoration: BoxDecoration(
          color: _CF.tarjeta,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _CF.borde),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 4, height: 28,
                decoration: BoxDecoration(
                  color: _CF.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Reservar cita',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _CF.texto,
                ),
              ),
            ]),
            const SizedBox(height: 20),
            _buildEmpleadoSelector(),
            const SizedBox(height: 12),
            _buildServicioSelector(),
            const SizedBox(height: 12),
            _buildFechaSelector(),
            const SizedBox(height: 12),
            _buildHoraSelector(),
            const SizedBox(height: 12),
            // Campos personalizados del negocio
            if (widget.negocio.camposPersonalizados != null)
              _CamposPersonalizados(
                campos: widget.negocio.camposPersonalizados!,
                valores: _camposExtra,
                onChanged: (id, v) => setState(() => _camposExtra[id] = v),
              ),
            const SizedBox(height: 24),
            _buildReservarButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpleadoSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.negocio.empresaIdVinculada)
          .collection('empleados')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _CF.accent));
        }
        final empleados = snapshot.data!.docs;
        return Theme(
          data: Theme.of(context).copyWith(
            canvasColor: _CF.superficie,
          ),
          child: DropdownButtonFormField<String>(
            value: _empleadoSeleccionado,
            dropdownColor: _CF.superficie,
            style: const TextStyle(color: _CF.texto, fontSize: 14),
            decoration: _CF.inputDecor('Selecciona empleado', Icons.person_outline),
            items: empleados.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return DropdownMenuItem(
                value: doc.id,
                child: Text(data['nombre'] ?? 'Sin nombre',
                    style: const TextStyle(color: _CF.texto)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _empleadoSeleccionado = value;
                final empleadoDoc = empleados.firstWhere((doc) => doc.id == value);
                final data = empleadoDoc.data() as Map<String, dynamic>;
                _empleadoNombre = data['nombre'];
              });
            },
            validator: (value) => value == null ? 'Selecciona un empleado' : null,
          ),
        );
      },
    );
  }

  Widget _buildServicioSelector() {
    // Validar que empresaIdVinculada no esté vacío
    if (widget.negocio.empresaIdVinculada == null || 
        widget.negocio.empresaIdVinculada!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Este negocio no tiene servicios configurados disponibles.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas')
          .doc(widget.negocio.empresaIdVinculada)
          .collection('servicios')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _CF.accent));
        }
        final servicios = snapshot.data!.docs;
        return Theme(
          data: Theme.of(context).copyWith(canvasColor: _CF.superficie),
          child: DropdownButtonFormField<String>(
            value: _servicioSeleccionado,
            dropdownColor: _CF.superficie,
            style: const TextStyle(color: _CF.texto, fontSize: 14),
            decoration: _CF.inputDecor('Selecciona servicio', Icons.design_services_outlined),
            items: servicios.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final precio = data['precio']?.toDouble() ?? 0.0;
              return DropdownMenuItem(
                value: doc.id,
                child: Text('${data['nombre']} – €${precio.toStringAsFixed(2)}',
                    style: const TextStyle(color: _CF.texto)),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _servicioSeleccionado = value;
                final servicioDoc = servicios.firstWhere((doc) => doc.id == value);
                final data = servicioDoc.data() as Map<String, dynamic>;
                _servicioNombre = data['nombre'];
                _servicioPrecio = data['precio']?.toDouble();
              });
            },
            validator: (value) => value == null ? 'Selecciona un servicio' : null,
          ),
        );
      },
    );
  }

  Widget _buildFechaSelector() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final fecha = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
          locale: const Locale('es', 'ES'),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: _CF.accent, onPrimary: _CF.fondo,
                surface: _CF.tarjeta, onSurface: _CF.texto,
              ),
            ),
            child: child!,
          ),
        );
        if (fecha != null) setState(() => _fechaSeleccionada = fecha);
      },
      child: InputDecorator(
        decoration: _CF.inputDecor('Fecha', Icons.calendar_today_outlined),
        child: Text(
          _fechaSeleccionada == null
              ? 'Selecciona una fecha'
              : '${_fechaSeleccionada!.day}/${_fechaSeleccionada!.month}/${_fechaSeleccionada!.year}',
          style: TextStyle(
            color: _fechaSeleccionada == null ? _CF.textoHint : _CF.texto,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildHoraSelector() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final hora = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.now(),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: _CF.accent, onPrimary: _CF.fondo,
                surface: _CF.tarjeta, onSurface: _CF.texto,
              ),
            ),
            child: child!,
          ),
        );
        if (hora != null) setState(() => _horaSeleccionada = hora);
      },
      child: InputDecorator(
        decoration: _CF.inputDecor('Hora', Icons.access_time_outlined),
        child: Text(
          _horaSeleccionada == null
              ? 'Selecciona una hora'
              : _horaSeleccionada!.format(context),
          style: TextStyle(
            color: _horaSeleccionada == null ? _CF.textoHint : _CF.texto,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildReservarButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _cargando ? null : _reservar,
        style: ElevatedButton.styleFrom(
          backgroundColor: _CF.accent,
          foregroundColor: _CF.fondo,
          disabledBackgroundColor: _CF.borde,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _cargando
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: _CF.fondo, strokeWidth: 2.5))
            : const Text(
                'Confirmar reserva',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  Future<void> _reservar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaSeleccionada == null || _horaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fecha y hora')),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final fechaHora = DateTime(
        _fechaSeleccionada!.year,
        _fechaSeleccionada!.month,
        _fechaSeleccionada!.day,
        _horaSeleccionada!.hour,
        _horaSeleccionada!.minute,
      );

      await ReservaService.guardarYNotificar(
        negocio: widget.negocio,
        ctx: context,
        datos: {
          'empleado_id': _empleadoSeleccionado,
          'empleado_nombre': _empleadoNombre,
          'servicio_id': _servicioSeleccionado,
          'servicio_nombre': _servicioNombre,
          'servicio_precio': _servicioPrecio,
          'fecha_hora': Timestamp.fromDate(fechaHora),
          if (_camposExtra.isNotEmpty) 'campos_extra': _camposExtra,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Reserva realizada! Recibirás confirmación por email'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FORMULARIO PARA RESTAURANTES
// ═══════════════════════════════════════════════════════════════════════════

class FormularioRestaurante extends StatefulWidget {
  final NegocioPublico negocio;

  const FormularioRestaurante({super.key, required this.negocio});

  @override
  State<FormularioRestaurante> createState() => _FormularioRestauranteState();
}

class _FormularioRestauranteState extends State<FormularioRestaurante> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _fechaSeleccionada;
  TimeOfDay? _horaSeleccionada;
  String _ubicacion = 'interior';
  int _numeroPersonas = 2;
  bool _cargando = false;
  final Map<String, dynamic> _camposExtra = {};

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Container(
        decoration: BoxDecoration(
          color: _CF.tarjeta,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _CF.borde),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 4, height: 28,
                decoration: BoxDecoration(
                  color: _CF.accent, borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Reservar mesa', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: _CF.texto,
              )),
            ]),
            const SizedBox(height: 20),
            _buildFechaSelector(),
            const SizedBox(height: 12),
            _buildHoraSelector(),
            const SizedBox(height: 12),
            _buildUbicacionSelector(),
            const SizedBox(height: 12),
            _buildNumeroPersonasSelector(),
            if (widget.negocio.camposPersonalizados != null)
              _CamposPersonalizados(
                campos: widget.negocio.camposPersonalizados!,
                valores: _camposExtra,
                onChanged: (id, v) => setState(() => _camposExtra[id] = v),
              ),
            const SizedBox(height: 24),
            _buildReservarButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFechaSelector() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final fecha = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
          locale: const Locale('es', 'ES'),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(
              primary: _CF.accent, onPrimary: _CF.fondo,
              surface: _CF.tarjeta, onSurface: _CF.texto,
            )), child: child!,
          ),
        );
        if (fecha != null) setState(() => _fechaSeleccionada = fecha);
      },
      child: InputDecorator(
        decoration: _CF.inputDecor('Fecha', Icons.calendar_today_outlined),
        child: Text(
          _fechaSeleccionada == null
              ? 'Selecciona una fecha'
              : '${_fechaSeleccionada!.day}/${_fechaSeleccionada!.month}/${_fechaSeleccionada!.year}',
          style: TextStyle(
            color: _fechaSeleccionada == null ? _CF.textoHint : _CF.texto,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildHoraSelector() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final hora = await showTimePicker(
          context: context, initialTime: TimeOfDay.now(),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(
              primary: _CF.accent, onPrimary: _CF.fondo,
              surface: _CF.tarjeta, onSurface: _CF.texto,
            )), child: child!,
          ),
        );
        if (hora != null) setState(() => _horaSeleccionada = hora);
      },
      child: InputDecorator(
        decoration: _CF.inputDecor('Hora', Icons.access_time_outlined),
        child: Text(
          _horaSeleccionada == null ? 'Selecciona una hora' : _horaSeleccionada!.format(context),
          style: TextStyle(
            color: _horaSeleccionada == null ? _CF.textoHint : _CF.texto,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildUbicacionSelector() {
    return Theme(
      data: Theme.of(context).copyWith(canvasColor: _CF.superficie),
      child: DropdownButtonFormField<String>(
        value: _ubicacion,
        dropdownColor: _CF.superficie,
        style: const TextStyle(color: _CF.texto, fontSize: 14),
        decoration: _CF.inputDecor('Ubicación', Icons.location_on_outlined),
        items: const [
          DropdownMenuItem(value: 'interior',
              child: Text('Interior', style: TextStyle(color: _CF.texto))),
          DropdownMenuItem(value: 'exterior',
              child: Text('Terraza / Exterior', style: TextStyle(color: _CF.texto))),
        ],
        onChanged: (value) => setState(() => _ubicacion = value!),
      ),
    );
  }

  Widget _buildNumeroPersonasSelector() {
    return Theme(
      data: Theme.of(context).copyWith(canvasColor: _CF.superficie),
      child: DropdownButtonFormField<int>(
        value: _numeroPersonas,
        dropdownColor: _CF.superficie,
        style: const TextStyle(color: _CF.texto, fontSize: 14),
        decoration: _CF.inputDecor('Número de personas', Icons.people_outline),
        items: List.generate(20, (index) => DropdownMenuItem(
          value: index + 1,
          child: Text('${index + 1} ${index == 0 ? 'persona' : 'personas'}',
              style: const TextStyle(color: _CF.texto)),
        )),
        onChanged: (value) => setState(() => _numeroPersonas = value!),
      ),
    );
  }

  Widget _buildReservarButton() {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: _cargando ? null : _reservar,
        style: ElevatedButton.styleFrom(
          backgroundColor: _CF.accent, foregroundColor: _CF.fondo,
          disabledBackgroundColor: _CF.borde, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _cargando
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: _CF.fondo, strokeWidth: 2.5))
            : const Text('Confirmar reserva',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _reservar() async {
    if (_fechaSeleccionada == null || _horaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fecha y hora')),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final fechaHora = DateTime(
        _fechaSeleccionada!.year, _fechaSeleccionada!.month, _fechaSeleccionada!.day,
        _horaSeleccionada!.hour, _horaSeleccionada!.minute,
      );

      await ReservaService.guardarYNotificar(
        negocio: widget.negocio,
        ctx: context,
        datos: {
          'fecha_hora': Timestamp.fromDate(fechaHora),
          'ubicacion': _ubicacion,
          'numero_personas': _numeroPersonas,
          if (_camposExtra.isNotEmpty) 'campos_extra': _camposExtra,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Reserva realizada! Recibirás confirmación por email'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FORMULARIO ESTÁNDAR (otros negocios)
// ═══════════════════════════════════════════════════════════════════════════

class FormularioEstandar extends StatefulWidget {
  final NegocioPublico negocio;

  const FormularioEstandar({super.key, required this.negocio});

  @override
  State<FormularioEstandar> createState() => _FormularioEstandarState();
}

class _FormularioEstandarState extends State<FormularioEstandar> {
  final _formKey = GlobalKey<FormState>();
  final _notasController = TextEditingController();
  DateTime? _fechaSeleccionada;
  TimeOfDay? _horaSeleccionada;
  bool _cargando = false;
  final Map<String, dynamic> _camposExtra = {};

  @override
  void dispose() { _notasController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Container(
        decoration: BoxDecoration(
          color: _CF.tarjeta,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _CF.borde),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 4, height: 28,
                decoration: BoxDecoration(
                  color: _CF.accent, borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Reservar cita', style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: _CF.texto,
              )),
            ]),
            const SizedBox(height: 20),
            _buildFechaSelector(),
            const SizedBox(height: 12),
            _buildHoraSelector(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notasController,
              maxLines: 3,
              style: const TextStyle(color: _CF.texto, fontSize: 14),
              decoration: _CF.inputDecor('Notas (opcional)', null),
            ),
            if (widget.negocio.camposPersonalizados != null)
              _CamposPersonalizados(
                campos: widget.negocio.camposPersonalizados!,
                valores: _camposExtra,
                onChanged: (id, v) => setState(() => _camposExtra[id] = v),
              ),
            const SizedBox(height: 24),
            _buildReservarButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFechaSelector() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final fecha = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 90)),
          locale: const Locale('es', 'ES'),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(
              primary: _CF.accent, onPrimary: _CF.fondo,
              surface: _CF.tarjeta, onSurface: _CF.texto,
            )), child: child!,
          ),
        );
        if (fecha != null) setState(() => _fechaSeleccionada = fecha);
      },
      child: InputDecorator(
        decoration: _CF.inputDecor('Fecha', Icons.calendar_today_outlined),
        child: Text(
          _fechaSeleccionada == null
              ? 'Selecciona una fecha'
              : '${_fechaSeleccionada!.day}/${_fechaSeleccionada!.month}/${_fechaSeleccionada!.year}',
          style: TextStyle(
            color: _fechaSeleccionada == null ? _CF.textoHint : _CF.texto,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildHoraSelector() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final hora = await showTimePicker(
          context: context, initialTime: TimeOfDay.now(),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(
              primary: _CF.accent, onPrimary: _CF.fondo,
              surface: _CF.tarjeta, onSurface: _CF.texto,
            )), child: child!,
          ),
        );
        if (hora != null) setState(() => _horaSeleccionada = hora);
      },
      child: InputDecorator(
        decoration: _CF.inputDecor('Hora', Icons.access_time_outlined),
        child: Text(
          _horaSeleccionada == null ? 'Selecciona una hora' : _horaSeleccionada!.format(context),
          style: TextStyle(
            color: _horaSeleccionada == null ? _CF.textoHint : _CF.texto,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildReservarButton() {
    return SizedBox(
      width: double.infinity, height: 52,
      child: ElevatedButton(
        onPressed: _cargando ? null : _reservar,
        style: ElevatedButton.styleFrom(
          backgroundColor: _CF.accent, foregroundColor: _CF.fondo,
          disabledBackgroundColor: _CF.borde, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _cargando
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: _CF.fondo, strokeWidth: 2.5))
            : const Text('Confirmar reserva',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _reservar() async {
    if (_fechaSeleccionada == null || _horaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona fecha y hora')),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      final fechaHora = DateTime(
        _fechaSeleccionada!.year, _fechaSeleccionada!.month, _fechaSeleccionada!.day,
        _horaSeleccionada!.hour, _horaSeleccionada!.minute,
      );

      await ReservaService.guardarYNotificar(
        negocio: widget.negocio,
        ctx: context,
        datos: {
          'fecha_hora': Timestamp.fromDate(fechaHora),
          'notas': _notasController.text.trim(),
          if (_camposExtra.isNotEmpty) 'campos_extra': _camposExtra,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Reserva realizada! Recibirás confirmación por email'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget: campos personalizados dinámicos del negocio
// ─────────────────────────────────────────────────────────────────────────────
class _CamposPersonalizados extends StatelessWidget {
  final List<CampoPersonalizado> campos;
  final Map<String, dynamic> valores;
  final void Function(String id, dynamic valor) onChanged;

  const _CamposPersonalizados({
    required this.campos,
    required this.valores,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (campos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Información adicional',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _CF.accent)),
        const SizedBox(height: 10),
        ...campos.map((campo) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCampo(context, campo),
        )),
      ],
    );
  }

  Widget _buildCampo(BuildContext context, CampoPersonalizado campo) {
    switch (campo.tipo) {
      case 'checkbox':
        return Container(
          decoration: BoxDecoration(
            color: _CF.superficie, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _CF.borde),
          ),
          child: CheckboxListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text('${campo.label}${campo.obligatorio ? " *" : ""}',
                style: const TextStyle(fontSize: 13, color: _CF.texto)),
            value: valores[campo.id] as bool? ?? false,
            onChanged: (v) => onChanged(campo.id, v),
            activeColor: _CF.accent,
            checkColor: _CF.fondo,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        );
      case 'selector':
        return Theme(
          data: ThemeData.dark().copyWith(canvasColor: _CF.superficie),
          child: DropdownButtonFormField<String>(
            value: valores[campo.id] as String?,
            dropdownColor: _CF.superficie,
            style: const TextStyle(color: _CF.texto, fontSize: 14),
            decoration: _CF.inputDecor(
              '${campo.label}${campo.obligatorio ? " *" : ""}', null),
            items: (campo.opciones ?? []).map((o) =>
                DropdownMenuItem(value: o,
                    child: Text(o, style: const TextStyle(color: _CF.texto)))).toList(),
            onChanged: (v) => onChanged(campo.id, v),
            validator: campo.obligatorio
                ? (v) => v == null ? 'Campo obligatorio' : null : null,
          ),
        );
      case 'numero':
        return TextFormField(
          keyboardType: TextInputType.number,
          initialValue: valores[campo.id]?.toString(),
          style: const TextStyle(color: _CF.texto, fontSize: 14),
          decoration: _CF.inputDecor(
            '${campo.label}${campo.obligatorio ? " *" : ""}', null),
          onChanged: (v) => onChanged(campo.id, int.tryParse(v) ?? v),
          validator: campo.obligatorio
              ? (v) => (v == null || v.isEmpty) ? 'Campo obligatorio' : null : null,
        );
      default:
        return TextFormField(
          keyboardType: campo.tipo == 'email'
              ? TextInputType.emailAddress
              : campo.tipo == 'telefono'
                  ? TextInputType.phone
                  : TextInputType.text,
          initialValue: valores[campo.id] as String?,
          style: const TextStyle(color: _CF.texto, fontSize: 14),
          decoration: _CF.inputDecor(
            '${campo.label}${campo.obligatorio ? " *" : ""}', null),
          onChanged: (v) => onChanged(campo.id, v),
          validator: campo.obligatorio
              ? (v) => (v == null || v.isEmpty) ? 'Campo obligatorio' : null : null,
        );
    }
  }
}

















import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/flash_slot_model.dart';
import '../../../services/flash_slot_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETA
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const fondo      = Color(0xFF0A0F23);
  static const superficie = Color(0xFF151932);
  static const tarjeta    = Color(0xFF1E2139);
  static const borde      = Color(0xFF2A2E45);
  static const flash      = Color(0xFFFFBB00);
  static const flashBg    = Color(0xFF3D2E00);
  static const accent     = Color(0xFF00FFC8);
  static const rosa       = Color(0xFFFF3296);
  static const rojo       = Color(0xFFFF2850);
  static const texto      = Color(0xFFFFFFFF);
  static const textoMuted = Color(0xFFB0B3C1);
  static const textoHint  = Color(0xFF6B6E82);

  static InputDecoration inp(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _C.textoMuted, fontSize: 13),
    hintStyle: const TextStyle(color: _C.textoHint, fontSize: 13),
    prefixIcon: icon != null ? Icon(icon, color: _C.textoMuted, size: 18) : null,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.borde)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.borde)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _C.flash, width: 1.5)),
    filled: true, fillColor: _C.superficie,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA CREAR FLASH SLOT (vista NEGOCIO)
// ─────────────────────────────────────────────────────────────────────────────
class PantallaCrearFlashSlot extends StatefulWidget {
  final String negocioId;
  final String negocioNombre;
  final String empresaId;
  final String? negocioFotoUrl;

  const PantallaCrearFlashSlot({
    super.key,
    required this.negocioId,
    required this.negocioNombre,
    required this.empresaId,
    this.negocioFotoUrl,
  });

  @override
  State<PantallaCrearFlashSlot> createState() => _PantallaCrearFlashSlotState();
}

class _PantallaCrearFlashSlotState extends State<PantallaCrearFlashSlot> {
  final _formKey = GlobalKey<FormState>();

  // Servicio
  String? _servicioId;
  String _servicioNombre = '';
  double _precioOriginal = 0;

  // Descuento
  bool _esPortentaje = true;
  final _ctrlDescuento = TextEditingController();

  // Fecha/Hora
  DateTime? _fechaHoraInicio;

  // Visibilidad
  int _horasVisibilidad = 2; // 1, 2, 4, 8, 24

  // Huecos
  int _huecos = 1;

  // Profesional
  String? _profesionalId;
  String? _profesionalNombre;

  bool _publicando = false;

  // Calculado
  double get _precioFinal {
    final v = double.tryParse(_ctrlDescuento.text) ?? 0;
    if (_esPortentaje) {
      return (_precioOriginal * (1 - v / 100)).clamp(0, double.infinity);
    }
    return (_precioOriginal - v).clamp(0, double.infinity);
  }

  @override
  void dispose() {
    _ctrlDescuento.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.fondo,
      appBar: AppBar(
        backgroundColor: _C.superficie,
        foregroundColor: _C.texto,
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _C.flash, borderRadius: BorderRadius.circular(6),
            ),
            child: Text('⚡ FLASH',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900,
                    color: _C.fondo)),
          ),
          const SizedBox(width: 10),
          const Text('Crear slot de última hora',
              style: TextStyle(fontSize: 15)),
        ]),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Aviso informativo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _C.flashBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.flash.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Text('⚡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  'Publica un hueco de última hora con descuento. Se notificará a tus clientes y seguidores.',
                  style: const TextStyle(fontSize: 12, color: _C.textoMuted, height: 1.4),
                )),
              ]),
            ),
            const SizedBox(height: 24),

            // ── SERVICIO ────────────────────────────────────────────
            _seccionTitulo('1. Selecciona el servicio'),
            const SizedBox(height: 10),
            _buildServicioSelector(),
            const SizedBox(height: 20),

            // ── DESCUENTO ───────────────────────────────────────────
            _seccionTitulo('2. Descuento'),
            const SizedBox(height: 10),
            _buildDescuento(),
            const SizedBox(height: 20),

            // ── FECHA Y HORA ────────────────────────────────────────
            _seccionTitulo('3. Fecha y hora del hueco'),
            const SizedBox(height: 10),
            _buildFechaHora(),
            const SizedBox(height: 20),

            // ── VISIBILIDAD ─────────────────────────────────────────
            _seccionTitulo('4. Tiempo de visibilidad'),
            const SizedBox(height: 10),
            _buildVisibilidad(),
            const SizedBox(height: 20),

            // ── HUECOS ──────────────────────────────────────────────
            _seccionTitulo('5. Número de huecos disponibles'),
            const SizedBox(height: 10),
            _buildHuecos(),
            const SizedBox(height: 20),

            // ── PROFESIONAL ─────────────────────────────────────────
            _seccionTitulo('6. Profesional (opcional)'),
            const SizedBox(height: 10),
            _buildProfesionalSelector(),
            const SizedBox(height: 32),

            // ── RESUMEN PREVIO ──────────────────────────────────────
            if (_servicioNombre.isNotEmpty && _fechaHoraInicio != null)
              _buildResumen(),

            // ── BOTÓN PUBLICAR ──────────────────────────────────────
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _publicando ? null : _publicar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.flash,
                  foregroundColor: _C.fondo,
                  disabledBackgroundColor: _C.borde,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _publicando
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Color(0xFF0A0F23), strokeWidth: 2.5))
                    : const Row(mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('⚡', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 8),
                          Text('Publicar flash slot',
                              style: TextStyle(fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                        ]),
              ),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  // ── SERVICIO ───────────────────────────────────────────────────
  Widget _buildServicioSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('servicios')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _C.flash));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _C.superficie,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.borde)),
            child: const Text('No tienes servicios configurados',
                style: TextStyle(color: _C.textoMuted)),
          );
        }
        return Theme(
          data: ThemeData.dark().copyWith(canvasColor: _C.superficie),
          child: DropdownButtonFormField<String>(
            value: _servicioId,
            dropdownColor: _C.superficie,
            style: const TextStyle(color: _C.texto, fontSize: 14),
            decoration: _C.inp('Selecciona servicio',
                icon: Icons.design_services_outlined),
            items: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final precio = (d['precio'] as num?)?.toDouble() ?? 0;
              return DropdownMenuItem(
                value: doc.id,
                child: Text('${d['nombre']} — €${precio.toStringAsFixed(2)}',
                    style: const TextStyle(color: _C.texto)),
              );
            }).toList(),
            onChanged: (id) {
              if (id == null) return;
              final doc = docs.firstWhere((d) => d.id == id);
              final d = doc.data() as Map<String, dynamic>;
              setState(() {
                _servicioId = id;
                _servicioNombre = d['nombre'] as String? ?? '';
                _precioOriginal = (d['precio'] as num?)?.toDouble() ?? 0;
              });
            },
            validator: (v) => v == null ? 'Selecciona un servicio' : null,
          ),
        );
      },
    );
  }

  // ── DESCUENTO ──────────────────────────────────────────────────
  Widget _buildDescuento() {
    return Column(children: [
      // Toggle porcentaje / precio fijo
      Container(
        decoration: BoxDecoration(
          color: _C.superficie, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.borde),
        ),
        child: Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _esPortentaje = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _esPortentaje ? _C.flash.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
              child: Center(child: Text('% Porcentaje',
                  style: TextStyle(
                    color: _esPortentaje ? _C.flash : _C.textoMuted,
                    fontWeight: _esPortentaje ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 13,
                  ))),
            ),
          )),
          Container(width: 1, height: 40, color: _C.borde),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _esPortentaje = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: !_esPortentaje ? _C.flash.withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
              ),
              child: Center(child: Text('€ Precio fijo',
                  style: TextStyle(
                    color: !_esPortentaje ? _C.flash : _C.textoMuted,
                    fontWeight: !_esPortentaje ? FontWeight.w700 : FontWeight.w400,
                    fontSize: 13,
                  ))),
            ),
          )),
        ]),
      ),
      const SizedBox(height: 10),

      // Input descuento + precio final preview
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: _ctrlDescuento,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: _C.texto, fontSize: 14),
            decoration: _C.inp(
              _esPortentaje ? 'Descuento (%)' : 'Descuento (€)',
              icon: Icons.local_offer_outlined,
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Introduce el descuento';
              final n = double.tryParse(v);
              if (n == null || n <= 0) return 'Valor inválido';
              if (_esPortentaje && n >= 100) return 'Máximo 99%';
              if (!_esPortentaje && n >= _precioOriginal) return 'Mayor que el precio';
              return null;
            },
          ),
        ),
        const SizedBox(width: 12),
        // Precio final preview
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.flashBg, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.flash.withValues(alpha: 0.4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Precio final', style: TextStyle(
                  fontSize: 11, color: _C.textoMuted)),
              const SizedBox(height: 2),
              Text('€${_precioFinal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                      color: _C.flash)),
              if (_precioOriginal > 0) Text(
                'Ahorro: €${(_precioOriginal - _precioFinal).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 10, color: _C.rosa),
              ),
            ]),
          ),
        ),
      ]),
    ]);
  }

  // ── FECHA Y HORA ───────────────────────────────────────────────
  Widget _buildFechaHora() {
    return GestureDetector(
      onTap: () async {
        final fecha = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(hours: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 30)),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(
              primary: _C.flash, onPrimary: _C.fondo,
              surface: _C.tarjeta, onSurface: _C.texto,
            )), child: child!,
          ),
        );
        if (fecha == null || !mounted) return;
        final hora = await showTimePicker(
          context: context, initialTime: TimeOfDay.now(),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(colorScheme: ColorScheme.dark(
              primary: _C.flash, onPrimary: _C.fondo,
              surface: _C.tarjeta, onSurface: _C.texto,
            )), child: child!,
          ),
        );
        if (hora == null || !mounted) return;
        setState(() {
          _fechaHoraInicio = DateTime(
              fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _C.superficie, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _fechaHoraInicio != null ? _C.flash : _C.borde),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined,
              size: 18, color: _fechaHoraInicio != null ? _C.flash : _C.textoMuted),
          const SizedBox(width: 10),
          Text(
            _fechaHoraInicio == null
                ? 'Selecciona fecha y hora del hueco'
                : '${_fechaHoraInicio!.day}/${_fechaHoraInicio!.month}/${_fechaHoraInicio!.year}'
                  '  ${_fechaHoraInicio!.hour}:${_fechaHoraInicio!.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 14,
              color: _fechaHoraInicio != null ? _C.texto : _C.textoHint,
            ),
          ),
        ]),
      ),
    );
  }

  // ── VISIBILIDAD ────────────────────────────────────────────────
  Widget _buildVisibilidad() {
    const opciones = [1, 2, 4, 8, 24];
    return Row(
      children: opciones.map((h) {
        final sel = _horasVisibilidad == h;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _horasVisibilidad = h),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? _C.flash.withValues(alpha: 0.15) : _C.superficie,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? _C.flash : _C.borde),
              ),
              child: Center(
                child: Text('${h}h',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: sel ? _C.flash : _C.textoMuted,
                    )),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── HUECOS ────────────────────────────────────────────────────
  Widget _buildHuecos() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _C.superficie, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.borde),
      ),
      child: Row(children: [
        Icon(Icons.people_outline_rounded, size: 18, color: _C.textoMuted),
        const SizedBox(width: 10),
        Text('Huecos disponibles',
            style: const TextStyle(fontSize: 13, color: _C.textoMuted)),
        const Spacer(),
        IconButton(
          onPressed: _huecos > 1 ? () => setState(() => _huecos--) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: _huecos > 1 ? _C.flash : _C.borde,
          iconSize: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 12),
        Text('$_huecos',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: _C.texto)),
        const SizedBox(width: 12),
        IconButton(
          onPressed: _huecos < 20 ? () => setState(() => _huecos++) : null,
          icon: const Icon(Icons.add_circle_outline),
          color: _C.flash,
          iconSize: 22,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  // ── PROFESIONAL ──────────────────────────────────────────────
  Widget _buildProfesionalSelector() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('empleados')
          .where('activo', isEqualTo: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final docs = snap.data!.docs;
        return Theme(
          data: ThemeData.dark().copyWith(canvasColor: _C.superficie),
          child: DropdownButtonFormField<String>(
            value: _profesionalId,
            dropdownColor: _C.superficie,
            style: const TextStyle(color: _C.texto, fontSize: 14),
            decoration: _C.inp('Asignar profesional (opcional)',
                icon: Icons.person_outline),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Cualquier profesional disponible',
                    style: TextStyle(color: Color(0xFFB0B3C1))),
              ),
              ...docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                return DropdownMenuItem(
                  value: doc.id,
                  child: Text(d['nombre'] as String? ?? 'Sin nombre',
                      style: const TextStyle(color: _C.texto)),
                );
              }),
            ],
            onChanged: (id) {
              setState(() {
                _profesionalId = id;
                if (id != null) {
                  final doc = docs.firstWhere((d) => d.id == id);
                  final d = doc.data() as Map<String, dynamic>;
                  _profesionalNombre = d['nombre'] as String?;
                } else {
                  _profesionalNombre = null;
                }
              });
            },
          ),
        );
      },
    );
  }

  // ── RESUMEN PREVIO ────────────────────────────────────────────
  Widget _buildResumen() {
    final exp = _fechaHoraInicio!.add(Duration(hours: _horasVisibilidad));
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.flashBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.flash.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('⚡', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          const Text('Resumen del flash slot',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: _C.flash)),
        ]),
        const SizedBox(height: 12),
        _resumenFila('Servicio', _servicioNombre),
        _resumenFila('Precio original', '€${_precioOriginal.toStringAsFixed(2)}'),
        _resumenFila('Precio flash', '€${_precioFinal.toStringAsFixed(2)}'),
        _resumenFila('Huecos', '$_huecos'),
        _resumenFila('Expira el',
            '${exp.day}/${exp.month}/${exp.year} ${exp.hour}:${exp.minute.toString().padLeft(2, '0')}'),
      ]),
    );
  }

  Widget _resumenFila(String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(children: [
      SizedBox(width: 130,
          child: Text(label, style: const TextStyle(
              fontSize: 12, color: _C.textoMuted))),
      Text(val, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: _C.texto)),
    ]),
  );

  Widget _seccionTitulo(String t) => Text(t,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: _C.textoMuted));

  // ── PUBLICAR ──────────────────────────────────────────────────
  Future<void> _publicar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaHoraInicio == null) {
      _snack('Selecciona fecha y hora del hueco');
      return;
    }

    setState(() => _publicando = true);
    try {
      final ahora = DateTime.now();
      final expiracion = ahora.add(Duration(hours: _horasVisibilidad));
      final descVal = double.tryParse(_ctrlDescuento.text) ?? 0;

      final slot = FlashSlotModel(
        id:                  '',
        negocioId:           widget.negocioId,
        negocioNombre:       widget.negocioNombre,
        negocioFotoUrl:      widget.negocioFotoUrl,
        empresaId:           widget.empresaId,
        servicioNombre:      _servicioNombre,
        servicioId:          _servicioId,
        precioOriginal:      _precioOriginal,
        tipoDescuento:       _esPortentaje ? 'porcentaje' : 'precio_fijo',
        valorDescuento:      descVal,
        precioFinal:         _precioFinal,
        fechaHoraInicio:     _fechaHoraInicio!,
        fechaHoraExpiracion: expiracion,
        huecosTotal:         _huecos,
        huecosReservados:    0,
        estado:              EstadoFlashSlot.activo,
        profesionalId:       _profesionalId,
        profesionalNombre:   _profesionalNombre,
        creadoAt:            ahora,
        reservasIds:         [],
      );

      await FlashSlotService.crearSlot(slot);
      if (!mounted) return;
      _snack('⚡ Flash slot publicado correctamente', ok: true);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  void _snack(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? const Color(0xFF1A2A1A) : _C.rojo,
      behavior: SnackBarBehavior.floating,
    ));
  }
}


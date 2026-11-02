import 'package:flutter/material.dart';
import '../servicios/fichaje_service.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import 'fichajes_colors.dart';

class DialogConfigurarPin extends StatefulWidget {
  final String uid, nombre, empresaId;
  final String? pinActual;
  final int jornadaActual;
  final String? horarioEntrada;
  final String? horarioSalida;
  final List<bool>? diasLaborables;
  final FichajeService svc;

  const DialogConfigurarPin({
    super.key,
    required this.uid,
    required this.nombre,
    required this.pinActual,
    required this.jornadaActual,
    required this.empresaId,
    required this.svc,
    this.horarioEntrada,
    this.horarioSalida,
    this.diasLaborables,
  });

  @override
  State<DialogConfigurarPin> createState() => _DialogConfigurarPinState();
}

class _DialogConfigurarPinState extends State<DialogConfigurarPin> {
  late final TextEditingController _pinCtrl;
  late final TextEditingController _entradaCtrl;
  late final TextEditingController _salidaCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;
  late int _jornadaDiaria;
  late List<bool> _dias;

  static const _kDiaLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  @override
  void initState() {
    super.initState();
    _pinCtrl = TextEditingController(text: widget.pinActual ?? '');
    _entradaCtrl =
        TextEditingController(text: widget.horarioEntrada ?? '09:00');
    _salidaCtrl = TextEditingController(text: widget.horarioSalida ?? '17:00');
    _jornadaDiaria = widget.jornadaActual;
    _dias = List.from(
        widget.diasLaborables ?? [true, true, true, true, true, false, false]);
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _entradaCtrl.dispose();
    _salidaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime(TextEditingController ctrl) async {
    final parts = ctrl.text.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      ctrl.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.pinActual == null
            ? 'Configurar acceso'
            : 'Parámetros del empleado'),
        content: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.nombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: _pinCtrl,
                    decoration: const InputDecoration(
                      labelText: 'PIN (4 dígitos)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    autofocus: true,
                    validator: (v) {
                      if (v == null || v.length != 4) return 'Debe tener 4 dígitos';
                      if (!RegExp(r'^\d{4}$').hasMatch(v)) return 'Solo números';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _jornadaDiaria,
                    decoration: const InputDecoration(
                      labelText: 'Jornada diaria',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                    items: const [
                      DropdownMenuItem(value: 240, child: Text('4 horas')),
                      DropdownMenuItem(value: 300, child: Text('5 horas')),
                      DropdownMenuItem(value: 360, child: Text('6 horas')),
                      DropdownMenuItem(value: 420, child: Text('7 horas')),
                      DropdownMenuItem(value: 480, child: Text('8 horas')),
                    ],
                    onChanged: (v) => setState(() => _jornadaDiaria = v!),
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Horario habitual',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kFText)),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _entradaCtrl,
                        readOnly: true,
                        onTap: () => _pickTime(_entradaCtrl),
                        decoration: const InputDecoration(
                          labelText: 'Entrada',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.login_rounded, size: 18),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _salidaCtrl,
                        readOnly: true,
                        onTap: () => _pickTime(_salidaCtrl),
                        decoration: const InputDecoration(
                          labelText: 'Salida',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.logout_rounded, size: 18),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Días laborables',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kFText)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (i) {
                      final activo = _dias[i];
                      return GestureDetector(
                        onTap: () => setState(() => _dias[i] = !_dias[i]),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: activo ? kFGreen : const Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: activo ? kFGreen : kFBorder),
                          ),
                          child: Center(
                            child: Text(_kDiaLabels[i],
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: activo ? Colors.white : kFSub)),
                          ),
                        ),
                      );
                    }),
                  ),
                ]),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _guardando ? null : _guardar,
            style: ElevatedButton.styleFrom(
                backgroundColor: kFGreen, foregroundColor: Colors.white),
            child: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Guardar'),
          ),
        ],
      );

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await widget.svc.configurarPINEmpleado(
        empresaId: widget.empresaId,
        uid: widget.uid,
        nombre: widget.nombre,
        pin: _pinCtrl.text,
        jornadaDiaria: _jornadaDiaria,
        horarioEntrada:
            _entradaCtrl.text.isNotEmpty ? _entradaCtrl.text : null,
        horarioSalida:
            _salidaCtrl.text.isNotEmpty ? _salidaCtrl.text : null,
        diasLaborables: _dias,
      );
      if (mounted) {
        Navigator.pop(context);
        FluxToast.exito(context, 'Empleado actualizado: ${widget.nombre}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        FluxToast.error(context, 'Error: $e');
      }
    }
  }
}

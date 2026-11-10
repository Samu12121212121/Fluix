import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../servicios/fichaje_service.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import 'fichajes_colors.dart';

class DialogAltaEmpleado extends StatefulWidget {
  final String empresaId;
  final FichajeService svc;

  const DialogAltaEmpleado({
    super.key,
    required this.empresaId,
    required this.svc,
  });

  @override
  State<DialogAltaEmpleado> createState() => _DialogAltaEmpleadoState();
}

class _DialogAltaEmpleadoState extends State<DialogAltaEmpleado> {
  String _modo = 'app';
  String? _uidSeleccionado;
  String? _nombreSeleccionado;
  final _nombreCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _horasCtrl = TextEditingController(text: '8');
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;
  bool _verPin = false;

  int get _jornadaDiaria => (int.tryParse(_horasCtrl.text.trim()) ?? 8) * 60;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _pinCtrl.dispose();
    _horasCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_modo == 'app' && _uidSeleccionado == null) {
      FluxToast.error(context, 'Selecciona un empleado de la lista');
      return;
    }
    final nombre =
        _modo == 'app' ? (_nombreSeleccionado ?? '') : _nombreCtrl.text.trim();
    if (nombre.isEmpty) {
      FluxToast.error(context, 'Introduce el nombre del empleado');
      return;
    }
    setState(() => _guardando = true);
    try {
      if (_modo == 'app') {
        await widget.svc.configurarPINEmpleado(
          empresaId: widget.empresaId,
          uid: _uidSeleccionado!,
          nombre: nombre,
          pin: _pinCtrl.text,
          jornadaDiaria: _jornadaDiaria,
        );
      } else {
        await widget.svc.crearEmpleadoExterno(
          empresaId: widget.empresaId,
          nombre: nombre,
          pin: _pinCtrl.text,
          jornadaDiaria: _jornadaDiaria,
        );
      }
      if (mounted) {
        Navigator.pop(context);
        FluxToast.exito(context, '$nombre dado de alta en fichajes');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        FluxToast.error(context,
            e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.how_to_reg_outlined, color: kFGreen),
        SizedBox(width: 10),
        Text('Dar de alta en fichajes'),
      ]),
      content: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(
                  child: _ModoChip(
                    label: 'Tiene cuenta en la app',
                    icon: Icons.phone_android_outlined,
                    activo: _modo == 'app',
                    onTap: () => setState(() {
                      _modo = 'app';
                      _uidSeleccionado = null;
                      _nombreSeleccionado = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModoChip(
                    label: 'Solo kiosk (sin cuenta)',
                    icon: Icons.tablet_outlined,
                    activo: _modo == 'externo',
                    onTap: () => setState(() {
                      _modo = 'externo';
                      _uidSeleccionado = null;
                    }),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              if (_modo == 'app')
                _SelectorUsuarioApp(
                  empresaId: widget.empresaId,
                  svc: widget.svc,
                  onSeleccionado: (uid, nombre) => setState(() {
                    _uidSeleccionado = uid;
                    _nombreSeleccionado = nombre;
                  }),
                  uidSeleccionado: _uidSeleccionado,
                  nombreSeleccionado: _nombreSeleccionado,
                )
              else
                TextFormField(
                  controller: _nombreCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: !_verPin,
                decoration: InputDecoration(
                  labelText: 'PIN (4 dígitos) *',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  border: const OutlineInputBorder(),
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: Icon(
                        _verPin
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18),
                    onPressed: () => setState(() => _verPin = !_verPin),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length != 4) {
                    return 'Debe tener exactamente 4 dígitos';
                  }
                  if (!RegExp(r'^\d{4}$').hasMatch(v)) return 'Solo números';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _horasCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jornada diaria (horas)',
                  prefixIcon: Icon(Icons.schedule_outlined),
                  suffixText: 'h',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                validator: (v) {
                  final h = int.tryParse(v?.trim() ?? '');
                  if (h == null || h < 1 || h > 24) return 'Introduce un número entre 1 y 24';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kFGreen.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kFGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 15, color: kFGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _modo == 'app'
                              ? 'El empleado usará este PIN en el tablet kiosk. También puede fichar desde su propia app.'
                              : 'Este empleado solo podrá fichar en el tablet kiosk con su PIN. No tendrá acceso a la app.',
                          style: const TextStyle(fontSize: 11, color: kFGreen),
                        ),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _guardando ? null : _guardar,
          icon: _guardando
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 16),
          label: const Text('Dar de alta'),
          style: FilledButton.styleFrom(backgroundColor: kFGreen),
        ),
      ],
    );
  }
}

class _ModoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool activo;
  final VoidCallback onTap;

  const _ModoChip({
    required this.label,
    required this.icon,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: activo
                ? kFGreen.withValues(alpha: 0.1)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: activo ? kFGreen : kFBorder,
                width: activo ? 1.5 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: activo ? kFGreen : kFSub),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        activo ? FontWeight.w600 : FontWeight.normal,
                    color: activo ? kFGreen : kFSub)),
          ]),
        ),
      );
}

class _SelectorUsuarioApp extends StatefulWidget {
  final String empresaId;
  final FichajeService svc;
  final String? uidSeleccionado;
  final String? nombreSeleccionado;
  final void Function(String uid, String nombre) onSeleccionado;

  const _SelectorUsuarioApp({
    required this.empresaId,
    required this.svc,
    required this.onSeleccionado,
    this.uidSeleccionado,
    this.nombreSeleccionado,
  });

  @override
  State<_SelectorUsuarioApp> createState() => _SelectorUsuarioAppState();
}

class _SelectorUsuarioAppState extends State<_SelectorUsuarioApp> {
  List<Map<String, String>> _usuarios = [];
  Set<String> _conPIN = {};
  bool _cargando = true;
  bool _errorCarga = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('usuarios')
            .where('empresa_id', isEqualTo: widget.empresaId)
            .get(),
        FirebaseFirestore.instance
            .collection('empresas')
            .doc(widget.empresaId)
            .collection('empleados_fichaje')
            .get(),
      ]);
      if (!mounted) return;
      setState(() {
        _conPIN = {for (final d in (results[1]).docs) d.id};
        _usuarios = (results[0])
            .docs
            .where((d) => (d.data())['estado'] != 'baja')
            .map((d) => {
                  'uid': d.id,
                  'nombre': (d.data())['nombre'] as String? ?? ''
                })
            .toList()
          ..sort((a, b) => a['nombre']!.compareTo(b['nombre']!));
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _cargando = false;
        _errorCarga = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const SizedBox(
          height: 48,
          child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: kFGreen)));
    }
    if (_errorCarga) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200)),
        child: Row(children: [
          Icon(Icons.wifi_off_rounded, size: 14, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  'No se pudo cargar la lista. Comprueba la conexión.',
                  style:
                      TextStyle(fontSize: 12, color: Colors.red.shade700))),
          TextButton(
              onPressed: () => setState(() {
                    _cargando = true;
                    _errorCarga = false;
                    _cargar();
                  }),
              child: const Text('Reintentar', style: TextStyle(fontSize: 11))),
        ]),
      );
    }
    final sinPIN =
        _usuarios.where((u) => !_conPIN.contains(u['uid'])).toList();
    if (sinPIN.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8)),
        child: const Text(
            'Todos los empleados con cuenta ya tienen PIN. Usa el modo "Solo kiosk" para añadir empleados sin cuenta.',
            style: TextStyle(fontSize: 12, color: kFSub),
            textAlign: TextAlign.center),
      );
    }
    return DropdownButtonFormField<String>(
      value: widget.uidSeleccionado,
      decoration: const InputDecoration(
        labelText: 'Seleccionar empleado *',
        prefixIcon: Icon(Icons.person_search_outlined),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      hint: const Text('Elige un empleado...', style: TextStyle(fontSize: 13)),
      items: sinPIN
          .map((u) => DropdownMenuItem<String>(
                value: u['uid'],
                child: Text(u['nombre']!,
                    style: const TextStyle(fontSize: 13)),
              ))
          .toList(),
      validator: (v) => v == null ? 'Selecciona un empleado' : null,
      onChanged: (uid) {
        if (uid == null) return;
        final nombre = sinPIN.firstWhere(
          (u) => u['uid'] == uid,
          orElse: () => {'uid': uid, 'nombre': ''},
        )['nombre'] ?? '';
        widget.onSeleccionado(uid, nombre);
      },
    );
  }
}

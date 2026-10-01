import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';

// Colores del sistema de diseño actual
const _kBlue   = Color(0xFF3B82F6);
const _kGreen  = Color(0xFF22C55E);
const _kBorder = Color(0xFFE5E7EB);
const _kBg     = Color(0xFFF8F9FA);
const _kText   = Color(0xFF111827);
const _kSub    = Color(0xFF6B7280);

class FormularioEmpleado extends StatefulWidget {
  final String empresaId;
  final String? id;
  final Map<String, dynamic>? data;

  const FormularioEmpleado({super.key, required this.empresaId, this.id, this.data});

  @override
  State<FormularioEmpleado> createState() => _FormularioEmpleadoState();
}

class _FormularioEmpleadoState extends State<FormularioEmpleado> {
  final _formKey   = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;

  late TextEditingController _nombreCtrl;
  late TextEditingController _correoCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _dniCtrl;
  late TextEditingController _nssCtrl;
  late TextEditingController _ibanCtrl;
  late TextEditingController _puestoCtrl;
  late TextEditingController _departamentoCtrl;
  late TextEditingController _direccionCtrl;

  String    _rolSeleccionado = 'staff';
  bool      _guardando       = false;
  bool      _soloFicha       = false;
  bool      _expandirExtra   = false;
  DateTime? _fechaAlta;

  bool get _esEdicion => widget.id != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl       = TextEditingController(text: widget.data?['nombre']       ?? '');
    _correoCtrl       = TextEditingController(text: widget.data?['correo']       ?? '');
    _telefonoCtrl     = TextEditingController(text: widget.data?['telefono']     ?? '');
    _passwordCtrl     = TextEditingController();
    _dniCtrl          = TextEditingController(text: widget.data?['dni']          ?? '');
    _nssCtrl          = TextEditingController(text: widget.data?['nss']          ?? '');
    _ibanCtrl         = TextEditingController(text: widget.data?['iban']         ?? '');
    _puestoCtrl       = TextEditingController(text: widget.data?['puesto']       ?? '');
    _departamentoCtrl = TextEditingController(text: widget.data?['departamento'] ?? '');
    _direccionCtrl    = TextEditingController(text: widget.data?['direccion']    ?? '');
    _rolSeleccionado  = widget.data?['rol'] ?? 'staff';
    // Fecha de alta
    final rawFecha = widget.data?['fecha_alta'];
    if (rawFecha is Timestamp) _fechaAlta = rawFecha.toDate();
    else if (rawFecha is String && rawFecha.isNotEmpty) _fechaAlta = DateTime.tryParse(rawFecha);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordCtrl.dispose();
    _dniCtrl.dispose();
    _nssCtrl.dispose();
    _ibanCtrl.dispose();
    _puestoCtrl.dispose();
    _departamentoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  String _generarPassword() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final rng = Random.secure();
    return List.generate(10, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ── Guardar ──────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final camposExtra = <String, dynamic>{
        if (_dniCtrl.text.trim().isNotEmpty)          'dni':          _dniCtrl.text.trim(),
        if (_nssCtrl.text.trim().isNotEmpty)          'nss':          _nssCtrl.text.trim(),
        if (_ibanCtrl.text.trim().isNotEmpty)         'iban':         _ibanCtrl.text.trim(),
        if (_puestoCtrl.text.trim().isNotEmpty)       'puesto':       _puestoCtrl.text.trim(),
        if (_departamentoCtrl.text.trim().isNotEmpty) 'departamento': _departamentoCtrl.text.trim(),
        if (_direccionCtrl.text.trim().isNotEmpty)    'direccion':    _direccionCtrl.text.trim(),
        if (_fechaAlta != null)                       'fecha_alta':   Timestamp.fromDate(_fechaAlta!),
      };
      if (_esEdicion) {
        await _firestore.collection('usuarios').doc(widget.id).set({
          'nombre':   _nombreCtrl.text.trim(),
          'telefono': _telefonoCtrl.text.trim(),
          'rol':      _rolSeleccionado,
          ...camposExtra,
        }, SetOptions(merge: true));
        if (mounted) {
          Navigator.pop(context);
          FluxToast.exito(context, 'Empleado actualizado correctamente');
        }
      } else if (_soloFicha) {
        final docRef = _firestore.collection('usuarios').doc();
        await docRef.set({
          'nombre':        _nombreCtrl.text.trim(),
          'correo':        _correoCtrl.text.trim(),
          'telefono':      _telefonoCtrl.text.trim(),
          'empresa_id':    widget.empresaId,
          'rol':           _rolSeleccionado,
          'activo':        true,
          'es_solo_ficha': true,
          'fecha_creacion': Timestamp.now(),
          'permisos':      [],
          ...camposExtra,
        });
        if (mounted) {
          Navigator.pop(context);
          FluxToast.exito(context, 'Ficha de ${_nombreCtrl.text.trim()} creada');
        }
      } else {
        final correo   = _correoCtrl.text.trim();
        final password = _generarPassword();
        String? nuevoUid;
        FirebaseApp? tempApp;
        try {
          tempApp = await Firebase.initializeApp(
              name: 'emp_${DateTime.now().millisecondsSinceEpoch}',
              options: Firebase.app().options);
          final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
          final cred = await tempAuth.createUserWithEmailAndPassword(
              email: correo, password: password);
          nuevoUid = cred.user!.uid;
          await tempAuth.signOut();
        } on FirebaseAuthException catch (e) {
          String msg = 'Error al crear la cuenta';
          if (e.code == 'email-already-in-use') msg = 'Este correo ya tiene cuenta registrada.';
          else if (e.code == 'invalid-email')   msg = 'Formato de correo no válido.';
          else msg = e.message ?? msg;
          if (mounted) FluxToast.error(context, msg);
          return;
        } finally {
          try { await tempApp?.delete(); } catch (_) {}
        }
        if (nuevoUid == null) throw Exception('No se pudo crear la cuenta');
        await _firestore.collection('usuarios').doc(nuevoUid).set({
          'nombre':        _nombreCtrl.text.trim(),
          'correo':        correo,
          'telefono':      _telefonoCtrl.text.trim(),
          'empresa_id':    widget.empresaId,
          'rol':           _rolSeleccionado,
          'activo':        true,
          'fecha_creacion': Timestamp.now(),
          'permisos':      [],
          'primera_vez':   true,
          ...camposExtra,
        });
        // Email con link para que el empleado establezca su contraseña
        try { await FirebaseAuth.instance.sendPasswordResetEmail(email: correo); } catch (_) {}
        if (mounted) {
          Navigator.pop(context);
          _mostrarCredenciales(correo, password);
        }
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarCredenciales(String correo, String password) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.check_circle_outline_rounded, color: _kGreen, size: 22),
          SizedBox(width: 8),
          Text('Empleado registrado', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Credenciales de acceso a la app:', style: TextStyle(fontSize: 13, color: _kSub)),
          const SizedBox(height: 14),
          _credFila('Correo', correo, Icons.email_outlined),
          const SizedBox(height: 8),
          _credFila('Contraseña', password, Icons.lock_outlined),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.5)),
            ),
            child: const Row(children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFF59E0B)),
              SizedBox(width: 6),
              Expanded(child: Text('Pide al empleado que cambie la contraseña al iniciar sesión.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E)))),
            ]),
          ),
        ]),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);      // cierra el diálogo
              Navigator.pop(context);  // cierra el bottom sheet
            },
            style: FilledButton.styleFrom(backgroundColor: _kBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _credFila(String label, String valor, IconData icono) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: _kBlue.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _kBlue.withValues(alpha: 0.15)),
    ),
    child: Row(children: [
      Icon(icono, size: 15, color: _kBlue),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _kSub)),
        Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kText)),
      ])),
    ]),
  );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.fromLTRB(0, 0, 0, MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Handle + header ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _kBorder)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_esEdicion ? Icons.edit_outlined : Icons.person_add_outlined,
                  color: _kBlue, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_esEdicion ? 'Editar empleado' : 'Nuevo empleado',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
              if (!_esEdicion)
                const Text('Elige cómo dar de alta al empleado',
                    style: TextStyle(fontSize: 11, color: _kSub)),
            ])),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: _kSub),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),

        // ── Contenido scrollable ───────────────────────────────────────────
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Selector modo (solo en creación) ────────────────────────
                if (!_esEdicion) ...[
                  Row(children: [
                    Expanded(child: _modoBtn(
                      seleccionado: !_soloFicha,
                      onTap: () => setState(() => _soloFicha = false),
                      icon: Icons.smartphone_rounded,
                      label: 'Con acceso a app',
                      sub: 'Crea cuenta + email bienvenida',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _modoBtn(
                      seleccionado: _soloFicha,
                      onTap: () => setState(() => _soloFicha = true),
                      icon: Icons.badge_outlined,
                      label: 'Solo ficha',
                      sub: 'Sin cuenta — solo datos',
                    )),
                  ]),
                  const SizedBox(height: 20),
                ],

                // ── Campos ─────────────────────────────────────────────────
                _campo(_nombreCtrl, 'Nombre completo *', Icons.person_outline,
                    validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null),
                _campo(_telefonoCtrl, 'Teléfono', Icons.phone_outlined,
                    tipo: TextInputType.phone),
                _campo(_puestoCtrl, 'Puesto / Cargo', Icons.work_outline),
                _campo(_departamentoCtrl, 'Departamento', Icons.business_outlined),

                // ── Datos de identidad y contrato ──────────────────────────
                GestureDetector(
                  onTap: () => setState(() => _expandirExtra = !_expandirExtra),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _expandirExtra ? _kBlue.withValues(alpha: 0.06) : _kBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _expandirExtra ? _kBlue.withValues(alpha: 0.3) : _kBorder),
                    ),
                    child: Row(children: [
                      Icon(Icons.folder_shared_outlined, size: 16,
                          color: _expandirExtra ? _kBlue : _kSub),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Datos laborales y personales',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: _expandirExtra ? _kBlue : _kText))),
                      Icon(_expandirExtra ? Icons.expand_less : Icons.expand_more,
                          size: 18, color: _expandirExtra ? _kBlue : _kSub),
                    ]),
                  ),
                ),
                if (_expandirExtra) ...[
                  _campo(_dniCtrl, 'DNI / NIE', Icons.badge_outlined),
                  _campo(_nssCtrl, 'NSS (Nº Seguridad Social)', Icons.security_outlined,
                      tipo: TextInputType.number),
                  _campo(_ibanCtrl, 'IBAN / Cuenta bancaria', Icons.account_balance_outlined),
                  _campo(_direccionCtrl, 'Dirección', Icons.home_outlined),
                  // Selector fecha de alta
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _fechaAlta ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                          locale: const Locale('es', 'ES'),
                          builder: (ctx, child) => Theme(
                            data: Theme.of(ctx).copyWith(
                              colorScheme: const ColorScheme.light(primary: _kBlue),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setState(() => _fechaAlta = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: _kBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_outlined, size: 17, color: _kSub),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            _fechaAlta != null
                                ? 'Alta: ${_fechaAlta!.day.toString().padLeft(2,'0')}/'
                                  '${_fechaAlta!.month.toString().padLeft(2,'0')}/'
                                  '${_fechaAlta!.year}'
                                : 'Fecha de incorporación',
                            style: TextStyle(fontSize: 13,
                                color: _fechaAlta != null ? _kText : _kSub),
                          )),
                          if (_fechaAlta != null)
                            GestureDetector(
                              onTap: () => setState(() => _fechaAlta = null),
                              child: const Icon(Icons.close, size: 14, color: _kSub),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ],

                // Email según modo
                if (!_esEdicion && !_soloFicha) ...[
                  _campo(_correoCtrl, 'Correo electrónico *', Icons.email_outlined,
                      tipo: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Obligatorio';
                        if (!v.contains('@')) return 'Correo no válido';
                        return null;
                      }),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text('Se generará una contraseña temporal y se enviará por email',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ),
                ],
                if (!_esEdicion && _soloFicha)
                  _campo(_correoCtrl, 'Correo (opcional)', Icons.email_outlined,
                      tipo: TextInputType.emailAddress),

                // Rol
                const SizedBox(height: 4),
                _labelCampo('Rol'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _rolSeleccionado,
                  decoration: _deco('', Icons.security_outlined),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('🛡️  Administrador')),
                    DropdownMenuItem(value: 'staff', child: Text('👤  Staff / Empleado')),
                  ],
                  onChanged: (v) => setState(() => _rolSeleccionado = v ?? 'staff'),
                ),
                const SizedBox(height: 24),

                // ── Botón guardar ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _guardando ? null : _guardar,
                    style: FilledButton.styleFrom(
                      backgroundColor: _soloFicha ? _kGreen : _kBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _guardando
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            _esEdicion ? 'Guardar cambios'
                                : _soloFicha ? 'Crear ficha'
                                : 'Registrar empleado',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _modoBtn({
    required bool seleccionado,
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required String sub,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: seleccionado ? _kBlue.withValues(alpha: 0.06) : _kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: seleccionado ? _kBlue : _kBorder,
            width: seleccionado ? 1.5 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: seleccionado ? _kBlue : _kSub),
            const Spacer(),
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: seleccionado ? _kBlue : Colors.transparent,
                border: Border.all(color: seleccionado ? _kBlue : _kBorder, width: 1.5),
              ),
              child: seleccionado
                  ? const Icon(Icons.check, size: 9, color: Colors.white)
                  : null,
            ),
          ]),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: seleccionado ? _kBlue : _kText)),
          Text(sub, style: const TextStyle(fontSize: 10, color: _kSub)),
        ]),
      ),
    );
  }

  Widget _labelCampo(String text) => Text(text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kSub));

  Widget _campo(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType tipo = TextInputType.text,
    bool oculto = false,
    String? Function(String?)? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: ctrl,
          keyboardType: tipo,
          obscureText: oculto,
          validator: validator,
          style: const TextStyle(fontSize: 13, color: _kText),
          decoration: _deco(label, icon),
        ),
      );

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label.isEmpty ? null : label,
        hintText: label.isEmpty ? null : null,
        prefixIcon: Icon(icon, size: 17, color: _kSub),
        filled: true,
        fillColor: _kBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kBlue, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        labelStyle: const TextStyle(fontSize: 13, color: _kSub),
        isDense: true,
      );
}

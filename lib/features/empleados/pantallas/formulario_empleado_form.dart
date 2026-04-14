import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FORMULARIO EMPLEADO (crear / editar)
// ─────────────────────────────────────────────────────────────────────────────

class FormularioEmpleado extends StatefulWidget {
  final String empresaId;
  final String? id;
  final Map<String, dynamic>? data;

  const FormularioEmpleado({super.key, required this.empresaId, this.id, this.data});

  @override
  State<FormularioEmpleado> createState() => _FormularioEmpleadoState();
}

class _FormularioEmpleadoState extends State<FormularioEmpleado> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  late TextEditingController _nombreCtrl;
  late TextEditingController _correoCtrl;
  late TextEditingController _telefonoCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _dniCtrl;
  late TextEditingController _puestoCtrl;
  late TextEditingController _direccionCtrl;
  String _rolSeleccionado = 'staff';
  bool _guardando = false;
  // Modo ficha: solo crea un documento Firestore sin cuenta Auth
  bool _soloFicha = false;

  bool get _esEdicion => widget.id != null;

  @override
  void initState() {
    super.initState();
    _nombreCtrl    = TextEditingController(text: widget.data?['nombre'] ?? '');
    _correoCtrl    = TextEditingController(text: widget.data?['correo'] ?? '');
    _telefonoCtrl  = TextEditingController(text: widget.data?['telefono'] ?? '');
    _passwordCtrl  = TextEditingController();
    _rolSeleccionado = widget.data?['rol'] ?? 'staff';
    _dniCtrl       = TextEditingController(text: widget.data?['dni'] ?? '');
    _puestoCtrl    = TextEditingController(text: widget.data?['puesto'] ?? '');
    _direccionCtrl = TextEditingController(text: widget.data?['direccion'] ?? '');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordCtrl.dispose();
    _dniCtrl.dispose();
    _puestoCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      if (_esEdicion) {
        await _firestore.collection('usuarios').doc(widget.id).set({
          'nombre':    _nombreCtrl.text.trim(),
          'telefono':  _telefonoCtrl.text.trim(),
          'rol':       _rolSeleccionado,
          if (_dniCtrl.text.trim().isNotEmpty) 'dni': _dniCtrl.text.trim(),
          if (_puestoCtrl.text.trim().isNotEmpty) 'puesto': _puestoCtrl.text.trim(),
          if (_direccionCtrl.text.trim().isNotEmpty) 'direccion': _direccionCtrl.text.trim(),
        }, SetOptions(merge: true));
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Empleado actualizado'),
              backgroundColor: Colors.green));
        }
      } else if (_soloFicha) {
        // ── CREAR SOLO FICHA (sin cuenta Auth) ─────────────────────────────
        final docRef = _firestore.collection('usuarios').doc();
        await docRef.set({
          'nombre':        _nombreCtrl.text.trim(),
          'correo':        _correoCtrl.text.trim(),
          'telefono':      _telefonoCtrl.text.trim(),
          'empresa_id':    widget.empresaId,
          'rol':           _rolSeleccionado,
          'activo':        true,
          'es_solo_ficha': true,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'permisos':      [],
          if (_dniCtrl.text.trim().isNotEmpty) 'dni': _dniCtrl.text.trim(),
          if (_puestoCtrl.text.trim().isNotEmpty) 'puesto': _puestoCtrl.text.trim(),
          if (_direccionCtrl.text.trim().isNotEmpty) 'direccion': _direccionCtrl.text.trim(),
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Ficha de ${_nombreCtrl.text.trim()} creada'),
            backgroundColor: Colors.green[700],
          ));
        }
      } else {
        // ── CREAR CON CUENTA FIREBASE AUTH ─────────────────────────────────
        final correo   = _correoCtrl.text.trim();
        final password = _passwordCtrl.text.trim();
        String? nuevoUid;
        FirebaseApp? tempApp;
        try {
          tempApp = await Firebase.initializeApp(
              name: 'tempCrear_${DateTime.now().millisecondsSinceEpoch}',
              options: Firebase.app().options);
          try {
            final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
            final cred = await tempAuth.createUserWithEmailAndPassword(
                email: correo, password: password);
            nuevoUid = cred.user!.uid;
            await tempAuth.signOut();
          } catch (_) {}
        } finally {
          try { await tempApp?.delete(); } catch (_) {}
        }

        if (nuevoUid == null) throw Exception('No se pudo crear la cuenta');

        await _firestore.collection('usuarios').doc(nuevoUid).set({
          'nombre':       _nombreCtrl.text.trim(),
          'correo':       correo,
          'telefono':     _telefonoCtrl.text.trim(),
          'empresa_id':   widget.empresaId,
          'rol':          _rolSeleccionado,
          'activo':       true,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'permisos':     [],
          'primera_vez':  true,
          if (_dniCtrl.text.trim().isNotEmpty) 'dni': _dniCtrl.text.trim(),
          if (_puestoCtrl.text.trim().isNotEmpty) 'puesto': _puestoCtrl.text.trim(),
          if (_direccionCtrl.text.trim().isNotEmpty) 'direccion': _direccionCtrl.text.trim(),
        });
        if (mounted) {
          Navigator.pop(context);
          _mostrarCredenciales(correo, password);
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Error: ${e.message}';
      if (e.code == 'email-already-in-use') msg = 'Este correo ya tiene cuenta registrada.';
      else if (e.code == 'weak-password') msg = 'La contraseña necesita mínimo 6 caracteres.';
      else if (e.code == 'invalid-email') msg = 'El formato del correo no es válido.';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('Empleado creado'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Entrega estas credenciales al empleado:',
                style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            _credFila('Correo', correo, Icons.email),
            const SizedBox(height: 8),
            _credFila('Contraseña', password, Icons.lock),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: const Text(
                '⚠️ Guarda estas credenciales. Pide al empleado que cambie la contraseña.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _credFila(String label, String valor, IconData icono) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D47A1).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF0D47A1).withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icono, size: 16, color: const Color(0xFF0D47A1)),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(valor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Widget _buildModoTile({
    required bool seleccionado,
    required VoidCallback onTap,
    required IconData icono,
    required String titulo,
    required String subtitulo,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icono, color: seleccionado ? color : Colors.grey, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: seleccionado ? color : Colors.grey[700])),
                  Text(subtitulo,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(
              seleccionado ? Icons.radio_button_checked : Icons.radio_button_off,
              color: seleccionado ? color : Colors.grey,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              Text(_esEdicion ? 'Editar Empleado' : 'Nuevo Empleado',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),

              // ── MODO: Con cuenta / Solo ficha ─────────────────────────────
              if (!_esEdicion) ...[
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Column(
                    children: [
                      _buildModoTile(
                        seleccionado: !_soloFicha,
                        onTap: () => setState(() => _soloFicha = false),
                        icono: Icons.phone_android,
                        titulo: 'Con acceso a la app',
                        subtitulo: 'Crea usuario + contraseña. El empleado puede iniciar sesión.',
                        color: const Color(0xFF0D47A1),
                      ),
                      const Divider(height: 1),
                      _buildModoTile(
                        seleccionado: _soloFicha,
                        onTap: () => setState(() => _soloFicha = true),
                        icono: Icons.person_pin_outlined,
                        titulo: 'Solo ficha (sin acceso)',
                        subtitulo: 'Añade los datos del empleado para nóminas sin crear cuenta.',
                        color: const Color(0xFF00796B),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── CAMPOS BÁSICOS ─────────────────────────────────────────────
              TextFormField(
                controller: _nombreCtrl,
                decoration: _deco('Nombre completo', Icons.person),
                validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),

              // Email y contraseña solo si tiene cuenta
              if (!_esEdicion && !_soloFicha) ...[
                TextFormField(
                  controller: _correoCtrl,
                  decoration: _deco('Correo electrónico *', Icons.email),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Obligatorio';
                    if (!v.contains('@')) return 'Correo no válido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: _deco('Contraseña temporal (mín. 6 caracteres) *', Icons.lock),
                  obscureText: true,
                  validator: (v) {
                    if (_esEdicion) return null;
                    if (v == null || v.isEmpty) return 'Obligatorio';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text('El empleado podrá cambiarla desde su perfil',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ),
                const SizedBox(height: 12),
              ],

              // Email opcional en modo ficha
              if (!_esEdicion && _soloFicha) ...[
                TextFormField(
                  controller: _correoCtrl,
                  decoration: _deco('Correo electrónico (opcional)', Icons.email),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
              ],

              // ── CAMPOS ADICIONALES ──────────────────────────────────────────
              TextFormField(
                controller: _dniCtrl,
                decoration: _deco('DNI / NIE', Icons.badge_outlined),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _puestoCtrl,
                decoration: _deco('Puesto / Categoría', Icons.work_outline),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _direccionCtrl,
                decoration: _deco('Dirección', Icons.home_outlined),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoCtrl,
                decoration: _deco('Teléfono', Icons.phone),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _rolSeleccionado,
                decoration: _deco('Rol', Icons.badge),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('🛡️ Administrador')),
                  DropdownMenuItem(value: 'staff', child: Text('👤 Staff / Empleado')),
                ],
                onChanged: (v) => setState(() => _rolSeleccionado = v ?? 'staff'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _soloFicha
                          ? const Color(0xFF00796B)
                          : const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          _esEdicion
                              ? 'Guardar cambios'
                              : _soloFicha
                                  ? 'Crear ficha'
                                  : 'Registrar empleado',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

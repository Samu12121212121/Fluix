import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../domain/modelos/sugerencia_empresa.dart';
import '../../../services/sugerencias_service.dart';
import '../../../services/auth/dos_factores_service.dart';
import '../../../services/auth/biometria_service.dart';
import 'gestionar_cuentas_screen.dart';
import 'pantalla_configuracion_pagos.dart';
import 'pantalla_sonidos_notificacion.dart';
import 'pantalla_auditoria.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class PantallaPerfil extends StatefulWidget {
  final SesionUsuario? sesion;
  const PantallaPerfil({super.key, this.sesion});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final numTabs = _calcularNumTabs();
    _tabController = TabController(length: numTabs, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _calcularNumTabs() {
    int n = 1; // Mi Perfil siempre
    if (widget.sesion?.esAdmin ?? false) n++; // Mi Empresa (propietario + admin)
    if (widget.sesion?.esPropietarioPlatforma ?? false) n++; // Gestión Cuentas
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final esAdminOProp = widget.sesion?.esAdmin ?? false;
    final esPlatAdmin = widget.sesion?.esPropietarioPlatforma ?? false;

    final tabs = <Tab>[
      const Tab(icon: Icon(Icons.person), text: 'Mi Perfil'),
      if (esAdminOProp)
        const Tab(icon: Icon(Icons.store), text: 'Mi Empresa'),
      if (esPlatAdmin)
        const Tab(icon: Icon(Icons.manage_accounts), text: 'Cuentas'),
    ];

    final views = <Widget>[
      _TabPerfil(sesion: widget.sesion),
      if (esAdminOProp) _TabEmpresa(sesion: widget.sesion),
      if (esPlatAdmin) const GestionarCuentasScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Perfil', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: tabs.length > 1
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorColor: Colors.white,
                tabs: tabs,
              )
            : null,
      ),
      body: tabs.length > 1
          ? TabBarView(controller: _tabController, children: views)
          : _TabPerfil(sesion: widget.sesion),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB: MI PERFIL
// ─────────────────────────────────────────────────────────────────────────────

class _TabPerfil extends StatefulWidget {
  final SesionUsuario? sesion;
  const _TabPerfil({this.sesion});

  @override
  State<_TabPerfil> createState() => _TabPerfilState();
}

class _TabPerfilState extends State<_TabPerfil> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passActualCtrl = TextEditingController();
  final _passNuevaCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  bool _guardando = false;
  bool _cambiarPassword = false;
  bool _obscureActual = true;
  bool _obscureNueva = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _passActualCtrl.dispose();
    _passNuevaCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await _firestore.collection('usuarios').doc(uid).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      _nombreCtrl.text = data['nombre'] ?? '';
      _telefonoCtrl.text = data['telefono'] ?? '';
      setState(() {});
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await _firestore.collection('usuarios').doc(uid).update({
        'nombre': _nombreCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
      });
      if (_cambiarPassword && _passNuevaCtrl.text.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser!;
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: _passActualCtrl.text,
        );
        await user.reauthenticateWithCredential(cred);
        await user.updatePassword(_passNuevaCtrl.text);
        _passActualCtrl.clear();
        _passNuevaCtrl.clear();
        _passConfirmCtrl.clear();
        setState(() => _cambiarPassword = false);
      }
      await PermisosService().cargarSesion();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Perfil actualizado'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _iniciales(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final sesion = widget.sesion;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar y rol
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        _iniciales(sesion?.nombre ?? user?.email ?? 'U'),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${sesion?.rolEmoji ?? ''} ${sesion?.rolNombre ?? 'Usuario'}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0D47A1)),
                  ),
                  const SizedBox(height: 4),
                  Text(user?.email ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Datos personales
            _seccion('Datos personales'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nombreCtrl,
              decoration: _deco('Nombre completo', Icons.person),
              validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefonoCtrl,
              decoration: _deco('Teléfono', Icons.phone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            // Cambiar contraseña
            _seccion('Seguridad'),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _cambiarPassword,
              onChanged: (v) => setState(() => _cambiarPassword = v),
              title: const Text('Cambiar contraseña'),
              subtitle: Text(
                _cambiarPassword ? 'Rellena los campos para cambiarla' : 'Pulsa para cambiar tu contraseña',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              activeThumbColor: const Color(0xFF0D47A1),
              contentPadding: EdgeInsets.zero,
            ),
            if (_cambiarPassword) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _passActualCtrl,
                obscureText: _obscureActual,
                decoration: _deco('Contraseña actual', Icons.lock).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscureActual ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureActual = !_obscureActual),
                  ),
                ),
                validator: (v) => _cambiarPassword && (v == null || v.isEmpty) ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passNuevaCtrl,
                obscureText: _obscureNueva,
                decoration: _deco('Nueva contraseña', Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNueva ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureNueva = !_obscureNueva),
                  ),
                ),
                validator: (v) {
                  if (!_cambiarPassword) return null;
                  if (v == null || v.isEmpty) return 'Obligatorio';
                  if (v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passConfirmCtrl,
                obscureText: _obscureConfirm,
                decoration: _deco('Confirmar nueva contraseña', Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (v) {
                  if (!_cambiarPassword) return null;
                  if (v != _passNuevaCtrl.text) return 'Las contraseñas no coinciden';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _guardando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_guardando ? 'Guardando...' : 'Guardar cambios',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),

            // Notificaciones
            _seccion('Notificaciones'),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: ListTile(
                leading: const Icon(Icons.music_note, color: Color(0xFF0D47A1)),
                title: const Text('Sonidos de notificación'),
                subtitle: const Text('Elige el sonido para cada tipo de aviso'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PantallaSonidosNotificacion())),
              ),
            ),
            const SizedBox(height: 20),

            // ── Seguridad adicional ──────────────────────────────────────
            _SeccionSeguridad2FA(uid: FirebaseAuth.instance.currentUser?.uid ?? ''),
            const SizedBox(height: 12),
            _ToggleBiometria(),
            const SizedBox(height: 12),

            // Auditoría (propietario y admin)
            if (widget.sesion?.esAdmin ?? false) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey[200]!),
                ),
                child: ListTile(
                  leading: const Icon(Icons.history, color: Color(0xFF0D47A1)),
                  title: const Text('Auditoría de accesos'),
                  subtitle: const Text('Log de logins, logouts y fallos de seguridad'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    final empresaId = widget.sesion?.empresaId;
                    if (empresaId != null) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => PantallaAuditoria(empresaId: empresaId),
                      ));
                    }
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: TOGGLE 2FA
// ─────────────────────────────────────────────────────────────────────────────

class _SeccionSeguridad2FA extends StatefulWidget {
  final String uid;
  const _SeccionSeguridad2FA({required this.uid});

  @override
  State<_SeccionSeguridad2FA> createState() => _SeccionSeguridad2FAState();
}

class _SeccionSeguridad2FAState extends State<_SeccionSeguridad2FA> {
  final _svc = DosFactoresService();
  bool _activo = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final config = await _svc.obtenerConfig(widget.uid);
    if (mounted) setState(() { _activo = config.activo; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: SwitchListTile(
        value: _activo,
        onChanged: (v) async {
          if (v) {
            // Activar: pedir teléfono y verificar
            _mostrarDialogoActivar2FA();
          } else {
            await _svc.desactivar2FA(widget.uid);
            setState(() => _activo = false);
          }
        },
        secondary: Icon(Icons.sms, color: _activo ? Colors.green : Colors.grey),
        title: const Text('Verificación en dos pasos'),
        subtitle: Text(_activo ? 'Activa — se pedirá código SMS tras el login' : 'Desactivada'),
      ),
    );
  }

  void _mostrarDialogoActivar2FA() {
    final telefonoCtrl = TextEditingController();
    bool enviando = false;
    String? errorLocal;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Activar verificación SMS'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Introduce tu número con prefijo país (ej: +34612345678)'),
            const SizedBox(height: 16),
            TextField(
              controller: telefonoCtrl,
              keyboardType: TextInputType.phone,
              enabled: !enviando,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone),
                border: const OutlineInputBorder(),
                hintText: '+34 612 345 678',
                errorText: errorLocal,
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: enviando ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: enviando
                  ? null
                  : () async {
                      final tel = telefonoCtrl.text
                          .trim()
                          .replaceAll(RegExp(r'\s+'), '');
                      if (!RegExp(r'^\+\d{7,15}$').hasMatch(tel)) {
                        setStateDialog(() =>
                            errorLocal = 'Formato: +34612345678');
                        return;
                      }
                      setStateDialog(() {
                        errorLocal = null;
                        enviando = true;
                      });
                      try {
                        final verificationId = await _svc.enviarCodigo(
                          telefono: tel,
                          onError: (msg) {
                            setStateDialog(() {
                              errorLocal = msg;
                              enviando = false;
                            });
                          },
                        );
                        if (mounted) {
                          Navigator.pop(ctx);
                          _mostrarDialogoCodigo(tel, verificationId);
                        }
                      } catch (e) {
                        setStateDialog(() => enviando = false);
                        if (mounted && errorLocal == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
              ),
              child: enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Enviar código'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoCodigo(String telefono, String verificationId) {
    final codigoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Introduce el código'),
        content: TextField(
          controller: codigoCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _svc.activar2FA(
                  uid: widget.uid,
                  verificationId: verificationId,
                  codigo: codigoCtrl.text.trim(),
                  telefono: telefono,
                );
                if (mounted) {
                  setState(() => _activo = true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('✅ 2FA activado correctamente'),
                    backgroundColor: Colors.green,
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Código incorrecto: $e'), backgroundColor: Colors.red,
                  ));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
            child: const Text('Verificar'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: TOGGLE BIOMETRÍA
// ─────────────────────────────────────────────────────────────────────────────

class _ToggleBiometria extends StatefulWidget {
  @override
  State<_ToggleBiometria> createState() => _ToggleBiometriaState();
}

class _ToggleBiometriaState extends State<_ToggleBiometria> {
  final _bio = BiometriaService();
  bool _activa = false;
  bool _soportada = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final activa = await _bio.estaActiva;
    final tipos = await _bio.tiposDisponibles();
    if (mounted) {
      setState(() {
        _activa = activa;
        _soportada = tipos.isNotEmpty;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando || !_soportada) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: SwitchListTile(
        value: _activa,
        onChanged: (v) async {
          if (v) {
            final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
            final email = FirebaseAuth.instance.currentUser?.email ?? '';
            await _bio.activar(uid: uid, email: email);
          } else {
            await _bio.desactivar();
          }
          setState(() => _activa = v);
        },
        secondary: Icon(Icons.fingerprint, color: _activa ? Colors.green : Colors.grey),
        title: const Text('Acceso biométrico'),
        subtitle: Text(_activa ? 'Activo — usa huella o Face ID al abrir la app' : 'Desactivado'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB: MI EMPRESA
// ─────────────────────────────────────────────────────────────────────────────

class _TabEmpresa extends StatefulWidget {
  final SesionUsuario? sesion;
  const _TabEmpresa({this.sesion});

  @override
  State<_TabEmpresa> createState() => _TabEmpresaState();
}

class _TabEmpresaState extends State<_TabEmpresa> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _aperturaCtrl = TextEditingController();
  final _cierreCtrl = TextEditingController();
  bool _guardando = false;
  bool _cargando = true;
  String _tipoNegocio = 'Otro';
  String _sectorEmpresa = 'hosteleria';
  final List<bool> _diasActivos = [true, true, true, true, true, false, false];
  final _diasNombres = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  final _diasClave = ['lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'];

  final _tiposNegocio = [
    'Peluquería / Estética', 'Restaurante / Bar', 'Clínica / Salud',
    'Spa / Masajes', 'Gimnasio / Fitness', 'Taller / Reparaciones',
    'Tienda / Comercio', 'Otro',
  ];

  static const List<Map<String, String>> _sectoresEmpresa = [
    {'id': 'hosteleria', 'label': 'Hostelería y Turismo'},
    {'id': 'comercio', 'label': 'Comercio'},
    {'id': 'peluqueria', 'label': 'Peluquería y Estética'},
    {'id': 'otros', 'label': 'Otro sector'},
  ];

  String _inferirSector(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('restaurante') || t.contains('bar') || t.contains('hostel')) return 'hosteleria';
    if (t.contains('tienda') || t.contains('comercio')) return 'comercio';
    if (t.contains('peluquer') || t.contains('estética') || t.contains('estetica') || t.contains('gimnasio')) return 'peluqueria';
    return 'otros';
  }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _direccionCtrl.dispose();
    _descripcionCtrl.dispose();
    _aperturaCtrl.dispose();
    _cierreCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    final empresaId = widget.sesion?.empresaId;
    if (empresaId == null) return;
    final doc = await _firestore.collection('empresas').doc(empresaId).get();
    if (!doc.exists || !mounted) return;
    final data = doc.data()!;
    _nombreCtrl.text = data['nombre'] ?? '';
    _telefonoCtrl.text = data['telefono'] ?? '';
    _direccionCtrl.text = data['direccion'] ?? '';
    _descripcionCtrl.text = data['descripcion'] ?? '';
    _tipoNegocio = data['tipo_negocio'] ?? 'Otro';
    final sectorFS = (data['sector'] as String?)?.toLowerCase().trim();
    _sectorEmpresa = _sectoresEmpresa.any((s) => s['id'] == sectorFS)
        ? sectorFS!
        : _inferirSector(_tipoNegocio);
    final horarios = data['horarios'] as Map<String, dynamic>?;
    if (horarios != null) {
      _aperturaCtrl.text = horarios['apertura'] ?? '09:00';
      _cierreCtrl.text = horarios['cierre'] ?? '20:00';
      for (int i = 0; i < _diasClave.length; i++) {
        _diasActivos[i] = horarios[_diasClave[i]] as bool? ?? false;
      }
    } else {
      _aperturaCtrl.text = '09:00';
      _cierreCtrl.text = '20:00';
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final empresaId = widget.sesion?.empresaId;
      if (empresaId == null) return;
      final horarios = <String, dynamic>{
        'apertura': _aperturaCtrl.text.trim(),
        'cierre': _cierreCtrl.text.trim(),
      };
      for (int i = 0; i < _diasClave.length; i++) {
        horarios[_diasClave[i]] = _diasActivos[i];
      }
      await _firestore.collection('empresas').doc(empresaId).update({
        'nombre': _nombreCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
        'direccion': _direccionCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'tipo_negocio': _tipoNegocio,
        'sector': _sectorEmpresa,
        'horarios': horarios,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Datos de la empresa actualizados'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info empresa
            _seccion('Información del negocio'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nombreCtrl,
              decoration: _deco('Nombre del negocio *', Icons.store),
              validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _tiposNegocio.contains(_tipoNegocio) ? _tipoNegocio : 'Otro',
              decoration: _deco('Tipo de negocio', Icons.category),
              items: _tiposNegocio.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) {
                final nuevo = v ?? 'Otro';
                setState(() {
                  final sectorAntes = _inferirSector(_tipoNegocio);
                  final eraInferido = _sectorEmpresa == sectorAntes;
                  _tipoNegocio = nuevo;
                  if (eraInferido) _sectorEmpresa = _inferirSector(_tipoNegocio);
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _sectoresEmpresa.any((s) => s['id'] == _sectorEmpresa) ? _sectorEmpresa : 'otros',
              decoration: _deco('Sector (para nóminas)', Icons.badge),
              items: _sectoresEmpresa.map((s) => DropdownMenuItem(value: s['id'], child: Text(s['label']!))).toList(),
              onChanged: (v) => setState(() => _sectorEmpresa = v ?? 'otros'),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _telefonoCtrl, decoration: _deco('Teléfono de contacto', Icons.phone), keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            TextFormField(controller: _direccionCtrl, decoration: _deco('Dirección', Icons.location_on)),
            const SizedBox(height: 12),
            TextFormField(controller: _descripcionCtrl, decoration: _deco('Descripción del negocio', Icons.description), maxLines: 3),
            const SizedBox(height: 24),

            // Horarios
            _seccion('Horarios de apertura'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: List.generate(7, (i) {
                final activo = _diasActivos[i];
                return GestureDetector(
                  onTap: () => setState(() => _diasActivos[i] = !activo),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: activo ? const Color(0xFF0D47A1) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: activo ? const Color(0xFF0D47A1) : Colors.grey[300]!),
                    ),
                    child: Text(_diasNombres[i],
                        style: TextStyle(color: activo ? Colors.white : Colors.grey[600], fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _aperturaCtrl, decoration: _deco('Apertura', Icons.wb_sunny))),
                const SizedBox(width: 16),
                const Text('—', style: TextStyle(fontSize: 20, color: Colors.grey)),
                const SizedBox(width: 16),
                Expanded(child: TextFormField(controller: _cierreCtrl, decoration: _deco('Cierre', Icons.nightlight_round))),
              ],
            ),
            const SizedBox(height: 32),

            // ── Configuración de pagos ─────────────────────────────────────
            if (widget.sesion?.empresaId != null) ...[
              _seccion('Pasarelas de pago y cobros'),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PantallaConfiguracionPagos(empresaId: widget.sesion!.empresaId),
                  )),
                  icon: const Icon(Icons.account_balance_wallet, size: 22),
                  label: const Text('Configurar pagos (Stripe, Banco, TPV…)',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D47A1),
                    side: const BorderSide(color: Color(0xFF0D47A1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // ── Sugerencias de mejora ──────────────────────────────────────
            if (!_cargando && widget.sesion?.empresaId != null)
              _SeccionSugerencias(
                empresaId: widget.sesion!.empresaId,
                nombreEmpresa: _nombreCtrl.text,
                autorUid: widget.sesion!.uid,
              ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _guardando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_guardando ? 'Guardando...' : 'Guardar cambios',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: SECCIÓN SUGERENCIAS DE MEJORA
// Diseño: historial de entradas (una card por sugerencia) + campo de texto
// para añadir una nueva. Cada envío crea una tarea automática solo visible
// para el propietario de la plataforma.
// ─────────────────────────────────────────────────────────────────────────────

class _SeccionSugerencias extends StatefulWidget {
  final String empresaId;
  final String nombreEmpresa;
  final String autorUid;

  const _SeccionSugerencias({
    required this.empresaId,
    required this.nombreEmpresa,
    required this.autorUid,
  });

  @override
  State<_SeccionSugerencias> createState() => _SeccionSugerenciasState();
}

class _SeccionSugerenciasState extends State<_SeccionSugerencias> {
  final _textoCtrl = TextEditingController();
  final _svc = SugerenciasService();
  bool _enviando = false;
  bool _mostrarHistorial = false;

  static const _colorAccent = Color(0xFF7B1FA2); // púrpura — diferenciado del azul principal

  @override
  void dispose() {
    _textoCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _textoCtrl.text.trim();
    if (texto.isEmpty) return;

    setState(() => _enviando = true);
    try {
      await _svc.guardarSugerencia(
        empresaId: widget.empresaId,
        texto: texto,
        nombreEmpresa: widget.nombreEmpresa.isEmpty
            ? 'Sin nombre'
            : widget.nombreEmpresa,
        autorUid: widget.autorUid,
      );
      _textoCtrl.clear();
      if (mounted) {
        setState(() => _mostrarHistorial = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('Sugerencia enviada. ¡Gracias por tu feedback!')),
            ]),
            backgroundColor: _colorAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _confirmarBorrado(SugerenciaEmpresa s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar sugerencia'),
        content: const Text(
          'Se eliminará la sugerencia y se cancelará la revisión pendiente.\n\n'
          '¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _svc.eliminarSugerencia(widget.empresaId, s);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabecera sección ────────────────────────────────────────────
        Row(
          children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                color: _colorAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '💡 Mejoras y sugerencias',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _colorAccent,
              ),
            ),
            const Spacer(),
            // Toggle historial
            TextButton.icon(
              onPressed: () => setState(() => _mostrarHistorial = !_mostrarHistorial),
              icon: Icon(
                _mostrarHistorial ? Icons.expand_less : Icons.history,
                size: 18,
                color: _colorAccent,
              ),
              label: Text(
                _mostrarHistorial ? 'Ocultar' : 'Ver historial',
                style: const TextStyle(fontSize: 12, color: _colorAccent),
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Propón mejoras o nuevas funcionalidades para la aplicación.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),

        // ── Campo de texto ──────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _colorAccent.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: _colorAccent.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _textoCtrl,
            maxLines: 4,
            maxLength: 800,
            decoration: InputDecoration(
              hintText: 'Ejemplo: "Necesitaría poder exportar las nóminas a Excel..."',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
              contentPadding: const EdgeInsets.all(14),
              border: InputBorder.none,
              counterStyle: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ── Botón enviar ────────────────────────────────────────────────
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _enviando ? null : _enviar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _colorAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: _enviando
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send, size: 18),
            label: Text(
              _enviando ? 'Enviando...' : 'Enviar sugerencia',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // ── Historial ───────────────────────────────────────────────────
        if (_mostrarHistorial) ...[
          const SizedBox(height: 16),
          StreamBuilder<List<SugerenciaEmpresa>>(
            stream: _svc.obtenerSugerencias(widget.empresaId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ));
              }
              final lista = snap.data ?? [];
              if (lista.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(children: [
                    Icon(Icons.inbox_outlined, color: Colors.grey[400]),
                    const SizedBox(width: 10),
                    Text(
                      'Aún no has enviado ninguna sugerencia.',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ]),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${lista.length} sugerencia${lista.length != 1 ? 's' : ''} enviada${lista.length != 1 ? 's' : ''}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  ...lista.map((s) => _TarjetaSugerencia(
                        sugerencia: s,
                        onEliminar: () => _confirmarBorrado(s),
                      )),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: tarjeta individual de sugerencia en el historial
// ─────────────────────────────────────────────────────────────────────────────

class _TarjetaSugerencia extends StatelessWidget {
  final SugerenciaEmpresa sugerencia;
  final VoidCallback onEliminar;

  const _TarjetaSugerencia({
    required this.sugerencia,
    required this.onEliminar,
  });

  Color _colorEstado(EstadoSugerencia estado) {
    switch (estado) {
      case EstadoSugerencia.pendiente:    return const Color(0xFFF57C00);
      case EstadoSugerencia.revisada:     return const Color(0xFF1976D2);
      case EstadoSugerencia.implementada: return const Color(0xFF388E3C);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fecha = DateFormat('d MMM yyyy', 'es').format(sugerencia.fechaCreacion);
    final color = _colorEstado(sugerencia.estado);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Texto de la sugerencia
          Text(
            sugerencia.texto,
            style: const TextStyle(fontSize: 13.5, height: 1.45),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // Metadatos: fecha + estado + acción
          Row(children: [
            Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[400]),
            const SizedBox(width: 4),
            Text(
              fecha,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            const SizedBox(width: 10),
            // Badge de estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                '${sugerencia.estado.emoji} ${sugerencia.estado.etiqueta}',
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            // Solo se puede eliminar si está pendiente
            if (sugerencia.estado == EstadoSugerencia.pendiente)
              GestureDetector(
                onTap: onEliminar,
                child: Icon(Icons.delete_outline,
                    size: 18, color: Colors.grey[400]),
              ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Widget _seccion(String titulo) {
  return Row(
    children: [
      Container(width: 4, height: 18, decoration: BoxDecoration(color: const Color(0xFF0D47A1), borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(titulo, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0D47A1))),
    ],
  );
}

InputDecoration _deco(String label, IconData icono) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icono),
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0D47A1), width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}


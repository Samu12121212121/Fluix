import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/empresa_config_provider.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../services/suscripcion_service.dart';
import '../../facturacion/pantallas/pantalla_configuracion_fiscal_empresa.dart';
import '../../../services/auth/dos_factores_service.dart';
import '../../../services/auth/biometria_service.dart';
import 'pantalla_auditoria.dart';
import 'integraciones_apis_popup.dart';
import '../../soporte/soporte_screen.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import 'gestionar_cuentas_screen.dart';
import '../../explorar_negocios/pantallas/pantalla_explorar.dart';
import '../../pdf_templates/presentation/screens/pdf_templates_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PANTALLA PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class PantallaPerfil extends StatelessWidget {
  final SesionUsuario? sesion;
  final bool embedded;
  final bool dark;
  final VoidCallback? onAbrirCuentas;
  const PantallaPerfil({super.key, this.sesion, this.embedded = false, this.dark = false, this.onAbrirCuentas});

  @override
  Widget build(BuildContext context) {
    final bg = dark ? const Color(0xFF0A0F23) : const Color(0xFFF5F7FA);
    final barBg = dark ? const Color(0xFF0A0F23) : Colors.white;
    final textCol = dark ? Colors.white : const Color(0xFF0F172A);
    final border = dark ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0);
    if (embedded) return _TabPerfil(sesion: sesion, dark: dark, onAbrirCuentas: onAbrirCuentas);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar( // standalone
        backgroundColor: barBg,
        foregroundColor: textCol,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: border),
        ),
        title: Row(children: [
          Icon(Icons.person_outline_rounded, size: 18, color: const Color(0xFF10B981)),
          const SizedBox(width: 8),
          Text('Mi perfil', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: textCol)),
        ]),
      ),
      body: _TabPerfil(sesion: sesion, dark: dark, onAbrirCuentas: onAbrirCuentas),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB: MI PERFIL
// ─────────────────────────────────────────────────────────────────────────────

class _TabPerfil extends StatefulWidget {
  final SesionUsuario? sesion;
  final bool dark;
  final VoidCallback? onAbrirCuentas;
  const _TabPerfil({this.sesion, this.dark = false, this.onAbrirCuentas});

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
  // Preferencias de notificación
  bool _notifPush = true;
  bool _notifResumen = true;
  // Foto y suscripción
  String? _fotoUrl;
  bool _subiendoFoto = false;
  DatosSuscripcion? _suscripcion;
  // 2FA
  bool _dos2faActivo = false;

  // ── Modo oscuro (heredado del dashboard) ──────────────────────────────────
  bool get _dark    => widget.dark;
  Color get _bg     => _dark ? const Color(0xFF0A0F23) : const Color(0xFFF5F7FA);
  Color get _cardBg => _dark ? const Color(0xFF131929) : Colors.white;
  Color get _border => _dark ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0);
  Color get _text   => _dark ? Colors.white : const Color(0xFF0F172A);
  Color get _sub    => _dark ? const Color(0xFFB0B3C1) : const Color(0xFF64748B);
  Color get _muted  => _dark ? const Color(0xFF7B8099) : const Color(0xFF94A3B8);
  Color get _div    => _dark ? const Color(0xFF1E2A42) : const Color(0xFFF1F5F9);

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
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) return;

    // Datos del usuario desde Firestore
    final doc = await _firestore.collection('usuarios').doc(uid).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      _nombreCtrl.text = data['nombre'] as String? ?? user?.displayName ?? '';
      _telefonoCtrl.text = data['telefono'] as String? ?? '';
      _fotoUrl = data['foto_url'] as String? ?? user?.photoURL;
    }

    // Estado 2FA
    try {
      final cfg = await DosFactoresService().obtenerConfig(uid);
      if (mounted) setState(() => _dos2faActivo = cfg.activo);
    } catch (_) {}

    // Suscripción
    if (widget.sesion?.empresaId != null) {
      try {
        final susc = await SuscripcionService()
            .cargarSuscripcion(widget.sesion!.empresaId);
        if (mounted) setState(() => _suscripcion = susc);
      } catch (_) {}
    }

    // Registrar inicio de sesión en actividad
    await _logActividad(uid, tipo: 'login', desc: 'Inicio de sesión');

    if (mounted) setState(() {});
  }

  Future<void> _logActividad(String uid, {
    required String tipo,
    required String desc,
    String? badge,
  }) async {
    try {
      await _firestore
          .collection('usuarios').doc(uid)
          .collection('actividad')
          .add({
        'tipo': tipo,
        'desc': desc,
        if (badge != null) 'badge': badge,
        'ts': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty) {
      if (mounted) FluxToast.error(context, 'El nombre es obligatorio');
      return;
    }
    setState(() => _guardando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await _firestore.collection('usuarios').doc(uid).update({
        'nombre': _nombreCtrl.text.trim(),
        'telefono': _telefonoCtrl.text.trim(),
      });
      await _logActividad(uid, tipo: 'perfil', desc: 'Actualización de perfil');
      if (_cambiarPassword && _passNuevaCtrl.text.isNotEmpty) {
        final user = FirebaseAuth.instance.currentUser!;
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: _passActualCtrl.text,
        );
        await user.reauthenticateWithCredential(cred);
        await user.updatePassword(_passNuevaCtrl.text);
        await _logActividad(uid, tipo: 'seguridad', desc: 'Cambio de contraseña');
        _passActualCtrl.clear();
        _passNuevaCtrl.clear();
        _passConfirmCtrl.clear();
        setState(() => _cambiarPassword = false);
      }
      await PermisosService().cargarSesion();
      if (mounted) {
        FluxToast.exito(context, 'Perfil actualizado');
      }
    } catch (e) {
      if (mounted) {
        FluxToast.error(context, 'Error: $e');
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
    final user  = FirebaseAuth.instance.currentUser;
    final sesion = widget.sesion;
    final nombre = _nombreCtrl.text.isNotEmpty
        ? _nombreCtrl.text
        : (sesion?.nombre ?? user?.displayName ?? user?.email?.split('@').first ?? 'Usuario');
    final email = user?.email ?? '';

    return Container(
      color: _bg,
      child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Título de página ──────────────────────────────────────────────
          Text('Mi perfil',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _text)),
          Text('Gestiona tu información personal y preferencias de la cuenta.',
              style: TextStyle(fontSize: 13, color: _sub)),
          const SizedBox(height: 20),

          // ── Hero card (avatar + info + plan) ──────────────────────────────
          _buildHeroCard(context, user, sesion, nombre, email),
          const SizedBox(height: 20),

          // ── 4 fichas iguales en 2 filas de 2 ────────────────────────────
          LayoutBuilder(builder: (ctx, cons) {
            final wide = cons.maxWidth > 640;
            final esAdmin = sesion?.esAdmin == true || sesion?.esPropietario == true;
            if (wide) {
              return Column(children: [
                // Fila 1: Info personal | Mi empresa (o full-width si no admin)
                if (esAdmin)
                  IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: _buildInfoPersonal(context, nombre, email, sesion)),
                    const SizedBox(width: 16),
                    Expanded(child: _MiEmpresaCard(sesion: sesion, dark: _dark)),
                  ]))
                else
                  _buildInfoPersonal(context, nombre, email, sesion),
                const SizedBox(height: 16),
                // Fila 2: Seguridad | Preferencias
                IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _buildSeguridad(context, user, sesion)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildPreferencias(context)),
                ])),
              ]);
            }
            return Column(children: [
              _buildInfoPersonal(context, nombre, email, sesion),
              const SizedBox(height: 16),
              if (esAdmin) ...[
                _MiEmpresaCard(sesion: sesion, dark: _dark),
                const SizedBox(height: 16),
              ],
              _buildSeguridad(context, user, sesion),
              const SizedBox(height: 16),
              _buildPreferencias(context),
            ]);
          }),
          // ── Sesiones activas (full-width) ──────────────────────────────────
          const SizedBox(height: 16),
          _buildSesionesActivasCard(context, user),

          // ── Gestión de cuentas (solo propietario de plataforma) ────────────
          if (sesion?.esPropietarioPlatforma == true) ...[
            const SizedBox(height: 16),
            _CuentasSection(sesion: sesion, onAbrirCuentas: widget.onAbrirCuentas),
          ],

          const SizedBox(height: 24),
        ]),
    ));
  }

  // ── Hero card ──────────────────────────────────────────────────────────────

  Widget _buildHeroCard(BuildContext context, user, sesion, String nombre, String email) {
    final lastSignIn = user?.metadata.lastSignInTime;
    final createdAt  = user?.metadata.creationTime;
    final lastStr = lastSignIn == null ? '—'
        : 'Hoy ${DateFormat('HH:mm').format(lastSignIn.toLocal())}';
    final memberStr = createdAt == null ? '—'
        : DateFormat('dd/MM/yyyy').format(createdAt.toLocal());

    final susc = _suscripcion;
    final planNombre = susc?.planNombre ?? _planBaseLabel(susc?.planBase) ?? 'Básico';
    final activa = susc?.estaActiva ?? true;
    final estadoLabel = activa ? (susc?.esPrueba == true ? 'Prueba' : 'Activo') : 'Inactivo';
    final estadoColor = activa ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final estadoBg   = activa ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);
    final fechaFin = susc?.fechaFin;
    final renovStr = fechaFin == null ? null
        : 'Renueva: ${DateFormat('dd/MM/yyyy').format(fechaFin)}';
    final progreso = () {
      if (susc == null || susc.fechaInicio == null || susc.fechaFin == null) return 0.0;
      final total = susc.fechaFin!.difference(susc.fechaInicio!).inDays;
      if (total <= 0) return 1.0;
      final usado = DateTime.now().difference(susc.fechaInicio!).inDays;
      return (usado / total).clamp(0.0, 1.0);
    }();

    final avatar = GestureDetector(
      onTap: _subiendoFoto ? null : _cambiarFoto,
      child: Stack(children: [
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _fotoUrl == null
                ? const LinearGradient(
                    colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
            image: _fotoUrl != null
                ? DecorationImage(image: NetworkImage(_fotoUrl!), fit: BoxFit.cover)
                : null,
          ),
          child: _subiendoFoto
              ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : (_fotoUrl == null
                  ? Center(child: Text(_iniciales(nombre),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)))
                  : null),
        ),
        Positioned(bottom: 2, left: 2, child: Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: const Color(0xFF64748B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 12),
        )),
      ]),
    );

    final infoCentral = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Flexible(child: Text(nombre, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
            color: _text, letterSpacing: -0.3), overflow: TextOverflow.ellipsis, maxLines: 1)),
        const SizedBox(width: 6),
        const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 17),
      ]),
      const SizedBox(height: 5),
      Wrap(spacing: 6, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(20)),
          child: Text(sesion?.rolNombre ?? 'Administrador',
              style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: estadoBg, borderRadius: BorderRadius.circular(20)),
          child: Text('Plan $planNombre',
              style: TextStyle(fontSize: 11, color: estadoColor, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 10),
      _heroMeta(Icons.email_outlined, email, badge: 'Verificado'),
      const SizedBox(height: 4),
      _heroMeta(Icons.access_time_rounded, 'Último acceso: $lastStr'),
      const SizedBox(height: 4),
      _heroMeta(Icons.calendar_today_outlined, 'Miembro desde: $memberStr'),
      if (renovStr != null) ...[
        const SizedBox(height: 4),
        _heroMeta(Icons.autorenew_rounded, renovStr),
      ],
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progreso,
          backgroundColor: const Color(0xFFE2E8F0),
          color: const Color(0xFF10B981),
          minHeight: 5,
        ),
      ),
      const SizedBox(height: 4),
      Text('${(progreso * 100).round()}% del límite utilizado',
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
    ]);

    final botonesRow = Wrap(spacing: 8, runSpacing: 6, children: [
      _heroBtn(
        _dos2faActivo ? Icons.shield_rounded : Icons.shield_outlined,
        _dos2faActivo ? '2FA activo' : 'Activar 2FA',
        () => _mostrarActivar2FA(context),
      ),
      _heroBtn(Icons.storefront_rounded, 'Explorar',
        () => Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PantallaExplorar()),
          (route) => false,
        ),
      ),
      FilledButton.icon(
        onPressed: () => _mostrarEditar(context),
        icon: const Icon(Icons.edit_rounded, size: 14),
        label: const Text('Editar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    ]);

    return LayoutBuilder(builder: (_, cons) {
      final narrow = cons.maxWidth < 560;
      return Container(
        padding: EdgeInsets.all(narrow ? 16 : 24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: _dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: narrow
            // ── Móvil: avatar arriba + info + botones
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  avatar,
                  const SizedBox(width: 16),
                  Expanded(child: infoCentral),
                ]),
                const SizedBox(height: 14),
                botonesRow,
              ])
            // ── Desktop/tablet: avatar izq + info expandible + botones arriba
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                avatar,
                const SizedBox(width: 20),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: infoCentral),
                    const SizedBox(width: 16),
                    botonesRow,
                  ]),
                ])),
              ]),
      );
    });
  }

  Widget _heroMeta(IconData icon, String text, {String? badge}) {
    return Row(children: [
      Icon(icon, size: 13, color: const Color(0xFF94A3B8)),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      if (badge != null) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(badge, style: const TextStyle(fontSize: 10.5, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
        ),
      ],
    ]);
  }

  Widget _heroBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF374151),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(tooltip, style: const TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }

  // ── Información personal ───────────────────────────────────────────────────

  Widget _buildInfoPersonal(BuildContext context, String nombre, String email, sesion) {
    final telefono = _telefonoCtrl.text.isEmpty ? '—' : _telefonoCtrl.text;
    final filas = [
      ('Nombre completo', nombre),
      ('Correo electrónico', email),
      ('Teléfono', telefono),
      ('Cargo', sesion?.rolNombre ?? 'Administrador'),
      ('Idioma', 'Español'),
      ('Zona horaria', '(GMT+1) Madrid, España'),
      ('Formato de fecha', 'DD/MM/YYYY'),
      ('Moneda', 'EUR (€)'),
    ];
    return _card(
      header: Row(children: [
        Icon(Icons.person_outline_rounded, size: 18, color: _text),
        const SizedBox(width: 8),
        Text('Información personal', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _text)),
        const Spacer(),
        _editLink(() => _mostrarEditar(context)),
      ]),
      child: Column(children: filas.map((f) {
        final isLast = f == filas.last;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              SizedBox(width: 140, child: Text(f.$1, style: TextStyle(fontSize: 12.5, color: _muted))),
              Expanded(child: Text(f.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _text))),
              if (f.$1 == 'Teléfono' && _telefonoCtrl.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Verificado', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                ),
            ]),
          ),
          if (!isLast) Divider(height: 1, color: _div),
        ]);
      }).toList()),
    );
  }

  // ── Preferencias ───────────────────────────────────────────────────────────

  Widget _buildPreferencias(BuildContext context) {
    return _card(
      header: Row(children: [
        Icon(Icons.tune_rounded, size: 18, color: _text),
        const SizedBox(width: 8),
        Text('Preferencias', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _text)),
      ]),
      child: Column(children: [
        _prefRow(Icons.notifications_outlined, 'Notificaciones push',
            'Activadas en este dispositivo', _notifPush,
            (v) => setState(() => _notifPush = v)),
        Divider(height: 1, color: _div),
        _prefRow(Icons.wb_sunny_outlined, 'Resumen diario',
            'Recibe un resumen de tu negocio cada mañana', _notifResumen,
            (v) => setState(() => _notifResumen = v)),
        Divider(height: 1, color: _div),
        _securityRow(Icons.api_rounded, const Color(0xFF3B82F6),
            'Integración con APIs',
            'Conecta servicios externos a Fluix',
            () => mostrarIntegracionesApis(context, dark: _dark, empresaId: widget.sesion?.empresaId ?? '')),
      ]),
    );
  }

  Widget _prefRow(IconData icon, String titulo, String sub, bool value,
      ValueChanged<bool> onChanged, {bool chevron = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        Icon(icon, size: 17, color: const Color(0xFF10B981)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _text)),
          Text(sub, style: TextStyle(fontSize: 11, color: _muted)),
        ])),
        if (chevron)
          Icon(Icons.chevron_right_rounded, size: 17, color: _border)
        else
          Switch(
            value: value, onChanged: onChanged,
            activeColor: const Color(0xFF10B981),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ]),
    );
  }

  // ── Plan ───────────────────────────────────────────────────────────────────

  Widget _buildPlanCard(BuildContext context, sesion) {
    final susc = _suscripcion;
    final planNombre = susc?.planNombre ?? _planBaseLabel(susc?.planBase) ?? 'Básico';
    final activa = susc?.estaActiva ?? true;
    final estado = activa ? (susc?.esPrueba == true ? 'Prueba' : 'Activo') : 'Inactivo';
    final estadoColor = activa ? const Color(0xFF059669) : const Color(0xFFDC2626);
    final estadoBg = activa ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);
    final fechaFin = susc?.fechaFin;
    final renovStr = fechaFin == null ? '—'
        : 'Renovación: ${DateFormat('dd/MM/yyyy').format(fechaFin)}';
    final diasRest = susc?.diasRestantes ?? -1;
    final progreso = (diasRest > 0 && fechaFin != null && susc?.fechaInicio != null)
        ? 1.0 - (diasRest / susc!.fechaFin!.difference(susc.fechaInicio!).inDays).clamp(0.0, 1.0)
        : 0.86;

    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Plan actual', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
        const SizedBox(height: 4),
        Row(children: [
          Text(planNombre,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: estadoBg, borderRadius: BorderRadius.circular(20)),
            child: Text(estado,
                style: TextStyle(fontSize: 11, color: estadoColor, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(renovStr, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progreso,
            backgroundColor: const Color(0xFFE2E8F0),
            color: const Color(0xFF10B981),
            minHeight: 7,
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text('${(progreso * 100).round()}% del período utilizado',
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const Spacer(),
          GestureDetector(
            onTap: () {},
            child: const Text('Ver mi suscripción →',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }

  String? _planBaseLabel(String? base) {
    if (base == null) return null;
    const labels = {
      'basico': 'Básico', 'profesional': 'Profesional',
      'empresa': 'Empresa', 'enterprise': 'Enterprise',
    };
    return labels[base] ?? base[0].toUpperCase() + base.substring(1);
  }

  // ── Seguridad ──────────────────────────────────────────────────────────────

  Widget _buildSeguridad(BuildContext context, user, sesion) {
    return _card(
      header: Row(children: [
        Icon(Icons.shield_outlined, size: 18, color: _text),
        const SizedBox(width: 8),
        Text('Seguridad de la cuenta', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _text)),
      ]),
      child: Column(children: [
        // ── 2FA ───────────────────────────────────────────────────────────
        _securityRow(
            _dos2faActivo ? Icons.verified_user_rounded : Icons.verified_user_outlined,
            _dos2faActivo ? const Color(0xFF10B981) : _muted,
            'Autenticación en dos pasos',
            _dos2faActivo ? 'Activada — protección extra al iniciar sesión' : 'No activada — toca para configurar',
            () => _mostrarActivar2FA(context)),
        if (sesion?.esAdmin == true) ...[
          Divider(height: 1, color: _div),
          // ── Auditoría ──────────────────────────────────────────────────
          _securityRow(Icons.history_rounded, const Color(0xFF6366F1),
              'Auditoría de accesos',
              'Registro de inicios de sesión y actividad',
              () => _mostrarAuditoria(context, sesion?.empresaId ?? '')),
        ],
        Divider(height: 1, color: _div),
        // ── Eliminar cuenta ────────────────────────────────────────────────
        InkWell(
          onTap: () => _mostrarEliminarCuenta(context),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(children: [
              Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red.shade400),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Eliminar cuenta', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.red.shade400)),
                Text('Solicita la eliminación permanente de tus datos', style: TextStyle(fontSize: 11, color: _muted)),
              ])),
              Icon(Icons.chevron_right_rounded, size: 17, color: Colors.red.shade200),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Bottom sheet: Auditoría de accesos ────────────────────────────────────
  void _mostrarAuditoria(BuildContext context, String empresaId) {
    if (empresaId.isEmpty) return;
    final dk    = _dark;
    final cardC = dk ? const Color(0xFF0A0F23) : const Color(0xFFF5F7FA);
    final barBg = dk ? const Color(0xFF1E2139) : Colors.white;
    final textC = dk ? Colors.white : const Color(0xFF0F172A);
    final subC  = dk ? const Color(0xFFB0B3C1) : const Color(0xFF64748B);
    final borderC = dk ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.88,
        decoration: BoxDecoration(
          color: cardC,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // ── Handle + header ──────────────────────────────────────────
          const SizedBox(height: 12),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: dk ? const Color(0xFF2A2E45) : Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Container(
            color: barBg,
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(children: [
              Icon(Icons.history_rounded, size: 18, color: const Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Expanded(child: Text('Auditoría de accesos',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textC))),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Icon(Icons.close_rounded, color: subC, size: 20),
              ),
            ]),
          ),
          Container(height: 1, color: borderC),
          // ── Contenido de la auditoría ───────────────────────────────
          Expanded(child: PantallaAuditoria(empresaId: empresaId, embedded: true)),
        ]),
      ),
    );
  }

  // ── Popup: Eliminar cuenta ─────────────────────────────────────────────────
  Future<void> _mostrarEliminarCuenta(BuildContext context) async {
    final dk    = _dark;
    final cardC = dk ? const Color(0xFF1E2139) : Colors.white;
    final textC = dk ? Colors.white : const Color(0xFF0F172A);
    final subC  = dk ? const Color(0xFFB0B3C1) : const Color(0xFF64748B);

    final primera = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardC,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Text('¿Eliminar cuenta?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.red.shade400)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Esta acción eliminará permanentemente tu cuenta y todos tus datos.', style: TextStyle(fontSize: 13, color: textC)),
          const SizedBox(height: 12),
          _infoChipDk(Icons.schedule_outlined, Colors.orange, 'Datos borrados en máx. 30 días', dk, subC),
          const SizedBox(height: 6),
          _infoChipDk(Icons.email_outlined, const Color(0xFF3B82F6), 'Recibirás confirmación por email', dk, subC),
          const SizedBox(height: 6),
          _infoChipDk(Icons.delete_forever_rounded, Colors.red, 'Perfil, historial y documentos eliminados', dk, subC),
        ]),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: OutlinedButton.styleFrom(foregroundColor: subC, side: BorderSide(color: dk ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 11)),
              child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 11)),
              child: const Text('Continuar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )),
          ]),
        ],
      ),
    );

    if (primera != true || !mounted) return;

    final confirmCtrl = TextEditingController();
    final segunda = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        backgroundColor: cardC,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        title: Text('Confirmación final', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.red.shade400)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Escribe BORRAR para confirmar:', style: TextStyle(fontSize: 13, color: textC)),
          const SizedBox(height: 10),
          TextField(
            controller: confirmCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(fontSize: 13, color: textC),
            decoration: InputDecoration(
              hintText: 'BORRAR',
              hintStyle: TextStyle(color: subC),
              filled: true,
              fillColor: dk ? const Color(0xFF0D1627) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            ),
            onChanged: (_) => setSt(() {}),
          ),
        ]),
        actions: [
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () { confirmCtrl.dispose(); Navigator.pop(ctx, false); },
              style: OutlinedButton.styleFrom(foregroundColor: subC, side: BorderSide(color: dk ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 11)),
              child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(
              onPressed: confirmCtrl.text.trim().toUpperCase() == 'BORRAR'
                  ? () { confirmCtrl.dispose(); Navigator.pop(ctx, true); }
                  : null,
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400, disabledBackgroundColor: dk ? const Color(0xFF2A2E45) : Colors.grey.shade200, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 11)),
              child: const Text('Eliminar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )),
          ]),
        ],
      )),
    );

    if (segunda != true || !mounted) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      if (uid != null) {
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
          'estado_cuenta': 'pendiente_borrado',
          'solicitud_borrado': FieldValue.serverTimestamp(),
          'fecha_borrado_estimada': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
          'email_borrado': email,
        });
        await FirebaseFirestore.instance.collection('solicitudes_borrado').add({
          'uid': uid, 'email': email,
          'nombre': widget.sesion?.nombre ?? '',
          'empresa_id': widget.sesion?.empresaId ?? '',
          'fecha_solicitud': FieldValue.serverTimestamp(),
          'fecha_borrado_max': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
          'estado': 'pendiente',
          'notificado_email': false,
        });
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          FluxToast.exito(context, 'Solicitud registrada. Recibirás un correo cuando se complete (máx. 30 días).');
        }
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    }
  }

  Widget _infoChipDk(IconData icon, Color color, String text, bool dark, Color sub) {
    return Row(children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(fontSize: 11, color: sub))),
    ]);
  }

  Widget _securityRow(IconData icon, Color iconColor, String titulo, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _text)),
            Text(sub, style: TextStyle(fontSize: 11, color: _muted)),
          ])),
          Icon(Icons.chevron_right_rounded, size: 17, color: _border),
        ]),
      ),
    );
  }

  // ── Sesiones activas (full-width con historial de logins) ────────────────

  Widget _buildSesionesActivasCard(BuildContext context, user) {
    final uid        = FirebaseAuth.instance.currentUser?.uid;
    final lastSignIn = user?.metadata.lastSignInTime;

    String _fmtTs(DateTime? dt) {
      if (dt == null) return '—';
      final d = dt.toLocal();
      final diff = DateTime.now().difference(d);
      if (diff.inMinutes < 2)   return 'Ahora mismo';
      if (diff.inMinutes < 60)  return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24)    return 'Hace ${diff.inHours}h';
      if (diff.inDays == 1)     return 'Ayer';
      return '${d.day}/${d.month}/${d.year}';
    }

    return _card(
      header: Row(children: [
        Icon(Icons.devices_rounded, size: 18, color: _text),
        const SizedBox(width: 8),
        Text('Sesiones activas', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _text)),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              backgroundColor: _cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Text('Cerrar sesión', style: TextStyle(color: _text, fontSize: 15)),
              content: Text('¿Cerrar la sesión actual en este dispositivo?', style: TextStyle(color: _sub, fontSize: 13)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: TextStyle(color: _sub))),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400), child: const Text('Cerrar sesión', style: TextStyle(fontSize: 13))),
              ],
            ));
            if (ok == true && mounted) await FirebaseAuth.instance.signOut();
          },
          child: Text('Cerrar sesión', style: TextStyle(fontSize: 12, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
        ),
      ]),
      child: Column(children: [
        // ── Sesión actual ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: _dark ? 0.12 : 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.smartphone_rounded, color: Color(0xFF10B981), size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Este dispositivo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _text)),
              Text('Último acceso: ${_fmtTs(lastSignIn)}', style: TextStyle(fontSize: 11, color: _sub)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: const Text('Activo', style: TextStyle(fontSize: 10.5, color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        // ── Historial de accesos ─────────────────────────────────────────
        const SizedBox(height: 12),
        Divider(height: 1, color: _div),
        const SizedBox(height: 8),
        if (uid != null)
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('usuarios').doc(uid)
                .collection('actividad')
                .where('tipo', isEqualTo: 'login')
                .orderBy('ts', descending: true)
                .limit(5)
                .snapshots(),
            builder: (ctx, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Text('Sin historial de accesos registrado',
                    style: TextStyle(fontSize: 11.5, color: _muted));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Historial de accesos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _muted, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  ...docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final ts = (d['ts'] as Timestamp?)?.toDate();
                    final desc = d['desc'] as String? ?? 'Inicio de sesión';
                    final device = d['device'] as String? ?? 'Dispositivo desconocido';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Container(width: 7, height: 7,
                            decoration: BoxDecoration(color: _muted.withValues(alpha: 0.5), shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(desc, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: _text)),
                          if (device.isNotEmpty)
                            Text(device, style: TextStyle(fontSize: 11, color: _muted)),
                        ])),
                        Text(_fmtTs(ts?.toLocal()), style: TextStyle(fontSize: 10.5, color: _muted)),
                      ]),
                    );
                  }),
                ],
              );
            },
          ),
      ]),
    );
  }

  // ── Actividad reciente ─────────────────────────────────────────────────────

  Widget _buildActividadReciente(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    const _tipoConfig = {
      'login':    (0xFF10B981, Icons.login_rounded),
      'perfil':   (0xFF2563EB, Icons.person_outline_rounded),
      'seguridad':(0xFF7C3AED, Icons.lock_outline_rounded),
      'foto':     (0xFF14B8A6, Icons.camera_alt_outlined),
      '2fa':      (0xFF6366F1, Icons.shield_outlined),
    };

    return _card(
      header: Row(children: [
        Icon(Icons.history_rounded, size: 18, color: _text),
        const SizedBox(width: 8),
        Text('Actividad reciente',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _text)),
      ]),
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('usuarios').doc(uid)
            .collection('actividad')
            .orderBy('ts', descending: true)
            .limit(8)
            .snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(children: [
                Icon(Icons.history_rounded, size: 36, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text('Sin actividad registrada',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400])),
              ]),
            );
          }
          return Column(children: docs.asMap().entries.map((e) {
            final isLast = e.key == docs.length - 1;
            final d = e.value.data() as Map<String, dynamic>;
            final tipo  = d['tipo'] as String? ?? 'perfil';
            final desc  = d['desc'] as String? ?? 'Acción';
            final badge = d['badge'] as String?;
            final ts    = d['ts'] as Timestamp?;
            final cfg   = _tipoConfig[tipo] ?? (0xFF94A3B8, Icons.info_outline_rounded);
            final color = Color(cfg.$1);

            String tiempo = '—';
            if (ts != null) {
              final dt   = ts.toDate().toLocal();
              final diff = DateTime.now().difference(dt);
              if (diff.inMinutes < 1)      tiempo = 'Ahora';
              else if (diff.inMinutes < 60) tiempo = 'Hace ${diff.inMinutes}m';
              else if (diff.inHours < 24)   tiempo = 'Hace ${diff.inHours}h';
              else if (diff.inDays == 1)    tiempo = 'Ayer';
              else                          tiempo = 'Hace ${diff.inDays}d';
            }

            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  Container(
                    width: 9, height: 9,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(desc, style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF334155))),
                    Text(tiempo, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ])),
                  if (badge != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(badge,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(cfg.$2, size: 14, color: color.withValues(alpha: 0.6)),
                ]),
              ),
              if (!isLast) const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ]);
          }).toList());
        },
      ),
    );
  }

  // ── Sesiones activas ───────────────────────────────────────────────────────

  Widget _buildSesionesActivas(BuildContext context) {
    final sesiones = [
      (Icons.desktop_windows_outlined, 'Windows · Chrome', 'Madrid, España — IP: 192.168.1.45', 'Hoy a las 15:42', true),
      (Icons.phone_iphone_rounded,      'iPhone 14 · Safari', 'Madrid, España — IP: 192.168.1.33', 'Ayer a las 22:17', false),
      (Icons.laptop_mac_rounded,         'MacOS · Chrome', 'Valencia, España — IP: 192.168.1.12', '26/07/2026 a las 10:11', false),
    ];
    return _card(
      header: Row(children: [
        const Icon(Icons.devices_rounded, size: 18, color: Color(0xFF334155)),
        const SizedBox(width: 8),
        const Text('Sesiones activas', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const Spacer(),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            textStyle: const TextStyle(fontSize: 12),
          ),
          child: const Text('Cerrar todas las sesiones'),
        ),
      ]),
      child: Column(children: sesiones.map((s) {
        final isLast = s == sesiones.last;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: s.$5 ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(s.$1, size: 20, color: s.$5 ? const Color(0xFF059669) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(s.$2, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  if (s.$5) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Actual', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
                Text(s.$3, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(s.$4, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
              ]),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFFCBD5E1)),
                onSelected: (_) {},
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'cerrar', child: Text('Cerrar esta sesión')),
                ],
              ),
            ]),
          ),
          if (!isLast) const Divider(height: 1, color: Color(0xFFF1F5F9)),
        ]);
      }).toList()),
    );
  }

  // ── Zona de peligro ────────────────────────────────────────────────────────

  Widget _buildZonaPeligro(BuildContext context) {
    return const SizedBox.shrink();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _card({required Widget child, Widget? header}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: _dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (header != null) ...[header, const SizedBox(height: 12), Divider(height: 1, color: _div), const SizedBox(height: 4)],
        child,
      ]),
    );
  }

  Widget _editLink(VoidCallback onTap, {String label = 'Editar'}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.edit_outlined, size: 13, color: _sub),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: _sub)),
      ]),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Future<void> _cambiarFoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85, maxWidth: 512);
    if (img == null || !mounted) return;
    setState(() => _subiendoFoto = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final bytes = await img.readAsBytes();
      final ref = FirebaseStorage.instance
          .ref('usuarios/$uid/avatar.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await _firestore
          .collection('usuarios')
          .doc(uid)
          .set({'foto_url': url}, SetOptions(merge: true));
      await FirebaseAuth.instance.currentUser!.updatePhotoURL(url);
      await _logActividad(uid, tipo: 'foto', desc: 'Actualización de foto de perfil');
      if (mounted) setState(() => _fotoUrl = url);
    } catch (e) {
      if (mounted) {
        FluxToast.error(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  void _mostrarActivar2FA(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final svc = DosFactoresService();

    if (_dos2faActivo) {
      // Desactivar
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desactivar 2FA'),
          content: const Text(
              '¿Estás seguro de que quieres desactivar la autenticación en dos pasos?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await svc.desactivar2FA(uid);
                if (mounted) setState(() => _dos2faActivo = false);
                if (mounted) FluxToast.exito(context, '2FA desactivado');
              },
              child: const Text('Desactivar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      return;
    }

    // Activar — paso 1: pedir teléfono
    final telCtrl = TextEditingController(text: _telefonoCtrl.text);
    bool enviando = false;
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Activar 2FA'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'Introduce tu número de teléfono. Recibirás un SMS con el código.'),
            const SizedBox(height: 12),
            TextField(
              controller: telCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Teléfono (+34...)',
                border: const OutlineInputBorder(),
                errorText: error,
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: enviando ? null : () async {
                final telefono = telCtrl.text.trim();
                if (telefono.isEmpty) return;
                setSt(() { enviando = true; error = null; });
                try {
                  final vId = await svc.enviarCodigo(
                    telefono: telefono,
                    onError: (msg) => setSt(() { error = msg; enviando = false; }),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _mostrarActivar2FAStep2(context, svc, vId);
                } catch (e) {
                  setSt(() { enviando = false; error = e.toString(); });
                }
              },
              child: enviando
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enviar código'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarActivar2FAStep2(
      BuildContext context, DosFactoresService svc, String verificationId) {
    final codeCtrl = TextEditingController();
    bool verificando = false;
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Verificar código SMS'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Introduce el código de 6 dígitos recibido por SMS.'),
            const SizedBox(height: 12),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Código de verificación',
                border: const OutlineInputBorder(),
                errorText: error,
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: verificando ? null : () async {
                setSt(() { verificando = true; error = null; });
                try {
                  final ok = await svc.verificarCodigo(
                    verificationId: verificationId,
                    codigo: codeCtrl.text.trim(),
                  );
                  if (!ok) {
                    setSt(() { verificando = false; error = 'Código incorrecto'; });
                    return;
                  }
                  if (mounted) setState(() => _dos2faActivo = true);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  FluxToast.exito(context, '2FA activado correctamente');
                } catch (e) {
                  setSt(() { verificando = false; error = 'Código incorrecto o expirado'; });
                }
              },
              child: verificando
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verificar'),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarEditar(BuildContext context) {
    final dk = _dark;
    // Controladores locales: evitan el error "used after disposed"
    final nombreLocal    = TextEditingController(text: _nombreCtrl.text);
    final telefonoLocal  = TextEditingController(text: _telefonoCtrl.text);
    final cardC = dk ? const Color(0xFF1E2139) : Colors.white;
    final textC = dk ? Colors.white : const Color(0xFF0F172A);
    final subC  = dk ? const Color(0xFFB0B3C1) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        bool guardando = false;
        return AlertDialog(
          backgroundColor: cardC,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          title: Row(children: [
            const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text('Editar perfil', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textC)),
            const Spacer(),
            GestureDetector(
              onTap: () { nombreLocal.dispose(); telefonoLocal.dispose(); Navigator.pop(ctx); },
              child: Icon(Icons.close_rounded, size: 18, color: subC),
            ),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nombreLocal,
              style: TextStyle(fontSize: 13, color: textC),
              decoration: _deco('Nombre completo', Icons.person_outline_rounded, dark: dk),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: telefonoLocal,
              style: TextStyle(fontSize: 13, color: textC),
              decoration: _deco('Teléfono', Icons.phone_outlined, dark: dk),
              keyboardType: TextInputType.phone,
            ),
          ]),
          actions: [
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () { nombreLocal.dispose(); telefonoLocal.dispose(); Navigator.pop(ctx); },
                style: OutlinedButton.styleFrom(
                  foregroundColor: subC,
                  side: BorderSide(color: dk ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
              )),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(
                onPressed: guardando ? null : () async {
                  if (nombreLocal.text.trim().isEmpty) {
                    FluxToast.error(context, 'El nombre es obligatorio');
                    return;
                  }
                  setSt(() => guardando = true);
                  // Copiar valores locales a los controllers del estado
                  _nombreCtrl.text   = nombreLocal.text.trim();
                  _telefonoCtrl.text = telefonoLocal.text.trim();
                  await _guardar();
                  nombreLocal.dispose();
                  telefonoLocal.dispose();
                  setSt(() => guardando = false);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: guardando
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              )),
            ]),
          ],
        );
      }),
    );
  }

  void _mostrarCambioPassword(BuildContext context) {
    final dk = _dark;
    // Controladores locales: evitan el error "used after disposed"
    final passActual  = TextEditingController();
    final passNueva   = TextEditingController();
    final passConfirm = TextEditingController();
    void _dispose() { passActual.dispose(); passNueva.dispose(); passConfirm.dispose(); }

    final cardC = dk ? const Color(0xFF1E2139) : Colors.white;
    final textC = dk ? Colors.white : const Color(0xFF0F172A);
    final subC  = dk ? const Color(0xFFB0B3C1) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        bool obscA = true, obscN = true, obscC = true, guardando = false;
        return AlertDialog(
          backgroundColor: cardC,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          title: Row(children: [
            const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF7C3AED)),
            const SizedBox(width: 8),
            Text('Cambiar contraseña', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textC)),
            const Spacer(),
            GestureDetector(
              onTap: () { _dispose(); Navigator.pop(ctx); },
              child: Icon(Icons.close_rounded, size: 18, color: subC),
            ),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: passActual,
              obscureText: obscA,
              style: TextStyle(fontSize: 13, color: textC),
              decoration: _deco('Contraseña actual', Icons.lock_outline_rounded, dark: dk).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(obscA ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: subC),
                  onPressed: () => setSt(() => obscA = !obscA),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passNueva,
              obscureText: obscN,
              style: TextStyle(fontSize: 13, color: textC),
              decoration: _deco('Nueva contraseña', Icons.lock_outline_rounded, dark: dk).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(obscN ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: subC),
                  onPressed: () => setSt(() => obscN = !obscN),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passConfirm,
              obscureText: obscC,
              style: TextStyle(fontSize: 13, color: textC),
              decoration: _deco('Confirmar contraseña', Icons.lock_outline_rounded, dark: dk).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(obscC ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: subC),
                  onPressed: () => setSt(() => obscC = !obscC),
                ),
              ),
            ),
          ]),
          actions: [
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () { _dispose(); Navigator.pop(ctx); },
                style: OutlinedButton.styleFrom(
                  foregroundColor: subC,
                  side: BorderSide(color: dk ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
              )),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(
                onPressed: guardando ? null : () async {
                  if (passActual.text.isEmpty) {
                    FluxToast.error(context, 'Introduce la contraseña actual'); return;
                  }
                  if (passNueva.text.length < 6) {
                    FluxToast.error(context, 'Mínimo 6 caracteres'); return;
                  }
                  if (passNueva.text != passConfirm.text) {
                    FluxToast.error(context, 'Las contraseñas no coinciden'); return;
                  }
                  setSt(() => guardando = true);
                  // Copiar a los controllers del estado para que _guardar() los lea
                  _passActualCtrl.text  = passActual.text;
                  _passNuevaCtrl.text   = passNueva.text;
                  _passConfirmCtrl.text = passConfirm.text;
                  setState(() => _cambiarPassword = true);
                  await _guardar();
                  if (mounted) setState(() => _cambiarPassword = false);
                  _dispose();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: guardando
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Actualizar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              )),
            ]),
          ],
        );
      }),
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
                          FluxToast.error(context, 'Error: $e');
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
          textInputAction: TextInputAction.done,
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
                  FluxToast.exito(context, '2FA activado correctamente');
                }
              } catch (e) {
                if (mounted) {
                  FluxToast.error(context, 'Código incorrecto: $e');
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
    // Usar isDeviceSupported() en vez de canCheckBiometrics.
    // En iOS, canCheckBiometrics devuelve false ANTES de que el usuario
    // conceda el permiso de Face ID, así que el widget nunca aparecería.
    final soporta = await _bio.dispositivoSoportaBiometria();
    if (mounted) {
      setState(() {
        _activa = activa;
        _soportada = soporta;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox.shrink();
    // Mostrar siempre si el dispositivo soporta biometría (aunque no esté activada)
    // Si no soporta, mostrar mensaje informativo
    if (!_soportada) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: const ListTile(
          leading: Icon(Icons.fingerprint, color: Colors.grey),
          title: Text('Acceso biométrico'),
          subtitle: Text('No disponible en este dispositivo',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      );
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: SwitchListTile(
        value: _activa,
        onChanged: _onToggle,
        secondary: Icon(Icons.fingerprint, color: _activa ? Colors.green : Colors.grey),
        title: const Text('Acceso biométrico'),
        subtitle: Text(_activa
            ? 'Activo — usa huella o Face ID al abrir la app'
            : 'Pulsa para activar Face ID / huella dactilar'),
      ),
    );
  }

  Future<void> _onToggle(bool activar) async {
    if (!activar) {
      // Desactivar
      await _bio.desactivar();
      if (mounted) setState(() => _activa = false);
      return;
    }

    // ── ACTIVAR: pedir autenticación biométrica para que iOS muestre
    //    el diálogo de permiso de Face ID ("¿Permitir que Fluix use Face ID?")
    final resultado = await _bio.autenticar();

    if (resultado.exito) {
      // Biometría exitosa → guardar preferencia
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      await _bio.activar(uid: uid, email: email);
      if (mounted) {
        setState(() => _activa = true);
        FluxToast.exito(context, 'Face ID / huella dactilar activado');
      }
    } else {
      // ── Manejar cada error con mensaje específico ──────────────────
      if (!mounted) return;
      final razon = resultado.razon;

      if (razon == BiometriaRazon.cancelada) {
        // El usuario simplemente canceló, no hacer nada
        return;
      }

      String titulo;
      String mensaje;
      bool mostrarAjustes = false;

      switch (razon) {
        case BiometriaRazon.noDisponible:
          titulo = 'Face ID no disponible';
          mensaje = 'Este dispositivo no soporta autenticación biométrica.';
          break;
        case BiometriaRazon.noConfigurada:
          titulo = 'Biometría no configurada';
          mensaje = 'No hay Face ID ni huella dactilar configurados en tu dispositivo.\n\n'
              'Ve a Ajustes del iPhone → Face ID y código (o Touch ID) y configúralo primero.';
          mostrarAjustes = true;
          break;
        case BiometriaRazon.bloqueada:
          titulo = 'Biometría bloqueada';
          mensaje = 'Demasiados intentos fallidos. Desbloquea tu dispositivo con el PIN '
              'e inténtalo de nuevo.';
          break;
        default:
          titulo = 'No se pudo activar';
          mensaje = 'La autenticación biométrica falló. Inténtalo de nuevo.\n\n'
              'Si el problema persiste, ve a Ajustes → Fluix → Face ID y verifica que el permiso está concedido.';
          mostrarAjustes = true;
          break;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16))),
            ],
          ),
          content: Text(mensaje),
          actions: [
            if (mostrarAjustes)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  // Abrir ajustes del dispositivo/app para conceder Face ID
                  try {
                    final uri = Uri.parse('app-settings:');
                    await launchUrl(uri);
                  } catch (_) {}
                },
                child: const Text('Ir a Ajustes'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
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
    'Tienda / Comercio', 'Construcción / Obra', 'Otro',
  ];

  static const List<Map<String, String>> _sectoresEmpresa = [
    {'id': 'hosteleria', 'label': 'Hostelería — Guadalajara'},
    {'id': 'comercio', 'label': 'Comercio — Guadalajara'},
    {'id': 'peluqueria', 'label': 'Peluquería y Estética'},
    {'id': 'construccion', 'label': 'Construcción — Guadalajara'},
    {'id': 'hosteleria_cuenca', 'label': 'Hostelería — Cuenca'},
    {'id': 'comercio_cuenca', 'label': 'Comercio en General — Cuenca'},
    {'id': 'construccion_cuenca', 'label': 'Construcción — Cuenca'},
    {'id': 'otros', 'label': 'Otro sector'},
  ];

  String _inferirSector(String tipo) {
    final t = tipo.toLowerCase();
    if (t.contains('restaurante') || t.contains('bar') || t.contains('hostel')) return 'hosteleria';
    if (t.contains('tienda') || t.contains('comercio')) return 'comercio';
    if (t.contains('peluquer') || t.contains('estética') || t.contains('estetica') || t.contains('gimnasio')) return 'peluqueria';
    if (t.contains('construcci') || t.contains('obra')) return 'construccion';
    return 'otros';
  }

  /// Carga datos existentes y, si el sector almacenado en Firestore incluye
  /// un sufijo de provincia (ej. 'hosteleria_cuenca'), lo mantiene tal cual.
  /// De este modo la app "sabe" que la empresa usa el convenio de Cuenca.

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
      final nombreTrim = _nombreCtrl.text.trim();
      await _firestore.collection('empresas').doc(empresaId).update({
        'nombre': nombreTrim,
        'nombre_empresa': nombreTrim,
        'telefono': _telefonoCtrl.text.trim(),
        'direccion': _direccionCtrl.text.trim(),
        'descripcion': _descripcionCtrl.text.trim(),
        'tipo_negocio': _tipoNegocio,
        'sector': _sectorEmpresa,
        'horarios': horarios,
      });
      if (mounted) {
        FluxToast.exito(context, 'Datos de la empresa actualizados');
      }
    } catch (e) {
      if (mounted) {
        FluxToast.error(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Widget _empresaCard({required String titulo, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    const accent = Color(0xFF2563EB);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mi empresa',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
          const Text('Gestiona los datos y la configuración de tu negocio.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 20),

          // ── Información del negocio ─────────────────────────────────────────
          _empresaCard(titulo: 'Información del negocio', child: Column(children: [
            _empresaField('Nombre del negocio', Icons.store_rounded,
                child: TextFormField(
                  controller: _nombreCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  validator: (v) => v == null || v.isEmpty ? 'Obligatorio' : null,
                )),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _empresaField('Tipo de negocio', Icons.category_rounded,
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                  value: _tiposNegocio.contains(_tipoNegocio) ? _tipoNegocio : 'Otro',
                  isExpanded: true, isDense: true,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                  onChanged: (v) {
                    final nuevo = v ?? 'Otro';
                    setState(() {
                      final sectorAntes = _inferirSector(_tipoNegocio);
                      final eraInferido = _sectorEmpresa == sectorAntes;
                      _tipoNegocio = nuevo;
                      if (eraInferido) _sectorEmpresa = _inferirSector(_tipoNegocio);
                    });
                  },
                  items: _tiposNegocio.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                ))),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _empresaField('Sector convenio', Icons.badge_rounded,
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                  value: _sectoresEmpresa.any((s) => s['id'] == _sectorEmpresa) ? _sectorEmpresa : 'otros',
                  isExpanded: true, isDense: true,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                  onChanged: (v) => setState(() => _sectorEmpresa = v ?? 'otros'),
                  items: _sectoresEmpresa.map((s) => DropdownMenuItem(value: s['id'], child: Text(s['label']!))).toList(),
                ))),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _empresaField('Teléfono', Icons.phone_rounded,
                child: TextFormField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                )),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _empresaField('Dirección', Icons.location_on_rounded,
                child: TextFormField(
                  controller: _direccionCtrl,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                )),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _empresaField('Descripción', Icons.description_outlined,
                child: TextFormField(
                  controller: _descripcionCtrl,
                  maxLines: 3, minLines: 1,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                    hintText: 'Breve descripción de tu negocio...',
                    hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  ),
                )),
          ])),

          // ── Horarios ─────────────────────────────────────────────────────────
          _empresaCard(titulo: 'Horarios de apertura', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Días activos', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: List.generate(7, (i) {
                final activo = _diasActivos[i];
                return GestureDetector(
                  onTap: () => setState(() => _diasActivos[i] = !activo),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: activo ? accent : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: activo ? accent : const Color(0xFFE2E8F0)),
                    ),
                    child: Text(_diasNombres[i],
                        style: TextStyle(
                            color: activo ? Colors.white : const Color(0xFF64748B),
                            fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _horarioField('Apertura', Icons.wb_sunny_outlined, _aperturaCtrl)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text('—', style: TextStyle(fontSize: 18, color: Color(0xFF94A3B8))),
              ),
              Expanded(child: _horarioField('Cierre', Icons.nightlight_round_outlined, _cierreCtrl)),
            ]),
          ])),

          // ── Configuración fiscal ──────────────────────────────────────────────
          _empresaCard(titulo: 'Configuración fiscal y PDFs', child: Column(children: [
            _configRow(
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF2563EB),
              titulo: 'Configuración Fiscal',
              sub: 'NIF, series de facturación, datos fiscales',
              onTap: () {
                final empresaId = widget.sesion?.empresaId;
                if (empresaId == null) return;
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider(
                    create: (_) => EmpresaConfigProvider(empresaId)..cargar(),
                    child: const PantallaConfiguracionFiscalEmpresa(),
                  ),
                ));
              },
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            _configRow(
              icon: Icons.picture_as_pdf_rounded,
              color: const Color(0xFFDC2626),
              titulo: 'Plantillas de PDF',
              sub: 'Diseño y configuración de documentos',
              onTap: () {
                final empresaId = widget.sesion?.empresaId;
                if (empresaId == null) return;
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PdfTemplatesListScreen(empresaId: empresaId)));
              },
            ),
          ])),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(_guardando ? 'Guardando...' : 'Guardar cambios',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _empresaField(String label, IconData icon, {required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 12),
        SizedBox(width: 140, child: Text(label,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)))),
        Expanded(child: child),
      ]),
    );
  }

  Widget _horarioField(String label, IconData icon, TextEditingController ctrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8))),
          SizedBox(
            width: 60,
            child: TextFormField(
              controller: ctrl,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _configRow({
    required IconData icon,
    required Color color,
    required String titulo,
    required String sub,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
            Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ])),
          const Icon(Icons.chevron_right_rounded, size: 17, color: Color(0xFFCBD5E1)),
        ]),
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

InputDecoration _deco(String label, IconData icono, {bool dark = false}) {
  final fillC   = dark ? const Color(0xFF0D1627) : Colors.white;
  final labelC  = dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  final borderC = dark ? const Color(0xFF2A2E45) : Colors.grey.shade300;
  final accent  = dark ? const Color(0xFF10B981) : const Color(0xFF0D47A1);
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: labelC, fontSize: 13),
    prefixIcon: Icon(icono, color: labelC, size: 18),
    filled: true,
    fillColor: fillC,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderC)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: accent, width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: MI EMPRESA (sección en la página de perfil)
// ─────────────────────────────────────────────────────────────────────────────

class _MiEmpresaCard extends StatefulWidget {
  final SesionUsuario? sesion;
  final bool dark;
  const _MiEmpresaCard({this.sesion, this.dark = false});

  @override
  State<_MiEmpresaCard> createState() => _MiEmpresaCardState();
}

class _MiEmpresaCardState extends State<_MiEmpresaCard> {
  Map<String, dynamic> _data = {};
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final eid = widget.sesion?.empresaId;
    if (eid == null) { setState(() => _cargando = false); return; }
    try {
      final doc = await FirebaseFirestore.instance.collection('empresas').doc(eid).get();
      if (mounted) setState(() { _data = doc.data() ?? {}; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Widget _infoRow(String label, String value, {bool dk = false}) {
    final textC = dk ? Colors.white : const Color(0xFF0F172A);
    final mutedC = dk ? const Color(0xFF7B8099) : const Color(0xFF94A3B8);
    final divC   = dk ? const Color(0xFF1E2A42) : const Color(0xFFF1F5F9);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(width: 130, child: Text(label, style: TextStyle(fontSize: 12.5, color: mutedC))),
          Expanded(child: Text(value.isEmpty ? '—' : value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textC))),
        ]),
      ),
      Divider(height: 1, color: divC),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox.shrink();
    if (widget.sesion?.empresaId == null) return const SizedBox.shrink();

    final nombre   = _data['nombre'] as String? ?? '—';
    final tipo     = _data['tipo_negocio'] as String? ?? '—';
    final sector   = _data['sector'] as String? ?? '—';
    final tel      = _data['telefono'] as String? ?? '—';
    final dir      = _data['direccion'] as String? ?? '—';
    final desc     = _data['descripcion'] as String? ?? '—';
    final horarios = _data['horarios'] as Map<String, dynamic>? ?? {};
    final apertura = horarios['apertura'] as String? ?? '—';
    final cierre   = horarios['cierre'] as String? ?? '—';

    final dk     = widget.dark;
    final cardC  = dk ? const Color(0xFF131929) : Colors.white;
    final borderC= dk ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0);
    final textC  = dk ? Colors.white : const Color(0xFF0F172A);
    final subC   = dk ? const Color(0xFFB0B3C1) : const Color(0xFF64748B);
    final divC   = dk ? const Color(0xFF1E2A42) : const Color(0xFFF1F5F9);
    final bg     = dk ? const Color(0xFF0A0F23) : const Color(0xFFF5F7FA);

    void _abrirFormEmpresa() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: borderC, borderRadius: BorderRadius.circular(2))),
            Container(
              color: cardC,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(children: [
                const Icon(Icons.store_outlined, size: 16, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(child: Text('Editar mi empresa',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textC))),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close_rounded, color: subC, size: 20),
                ),
              ]),
            ),
            Container(height: 1, color: borderC),
            Expanded(child: _TabEmpresa(sesion: widget.sesion)),
          ]),
        ),
      ).then((_) => _cargar()); // recargar datos al cerrar
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: cardC,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderC),
        boxShadow: dk ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.store_outlined, size: 18, color: textC),
          const SizedBox(width: 8),
          Text('Mi empresa', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textC)),
          const Spacer(),
          GestureDetector(
            onTap: _abrirFormEmpresa,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.edit_outlined, size: 13, color: subC),
              const SizedBox(width: 4),
              Text('Editar', style: TextStyle(fontSize: 12, color: subC)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Divider(height: 1, color: divC),
        const SizedBox(height: 4),
        _infoRow('Nombre', nombre, dk: dk),
        _infoRow('Tipo', tipo, dk: dk),
        _infoRow('Sector', sector, dk: dk),
        _infoRow('Teléfono', tel, dk: dk),
        _infoRow('Dirección', dir, dk: dk),
        if (desc.isNotEmpty && desc != '—') _infoRow('Descripción', desc, dk: dk),
        _infoRow('Horario', apertura.isNotEmpty && cierre.isNotEmpty ? '$apertura – $cierre' : '—', dk: dk),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: CUENTAS (sección de administración de plataforma)
// ─────────────────────────────────────────────────────────────────────────────

class _CuentasSection extends StatefulWidget {
  final SesionUsuario? sesion;
  final VoidCallback? onAbrirCuentas;
  const _CuentasSection({this.sesion, this.onAbrirCuentas});

  @override
  State<_CuentasSection> createState() => _CuentasSectionState();
}

class _CuentasSectionState extends State<_CuentasSection> {
  int _totalCuentas = 0;
  int _cuentasActivas = 0;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('empresas').get();
      int activas = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final susSnap = await doc.reference.collection('configuracion').doc('suscripcion').get();
        if (susSnap.exists) {
          final estado = (susSnap.data()?['estado'] as String? ?? '').toUpperCase();
          if (estado == 'ACTIVA' || estado == 'PRUEBA') activas++;
        }
      }
      if (mounted) setState(() {
        _totalCuentas = snap.docs.length;
        _cuentasActivas = activas;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark  = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final cardC = dark ? const Color(0xFF131929) : Colors.white;
    final borC  = dark ? const Color(0xFF2A2E45) : const Color(0xFFE2E8F0);
    final textC = dark ? Colors.white : const Color(0xFF0F172A);
    final subC  = dark ? const Color(0xFFB0B3C1) : const Color(0xFF64748B);
    final divC  = dark ? const Color(0xFF1E2A42) : const Color(0xFFF1F5F9);
    const accent = Color(0xFF7C3AED);

    // Si hay callback (desktop embedded), usarlo; si no, Navigator.push
    void _abrir() {
      if (widget.onAbrirCuentas != null) {
        widget.onAbrirCuentas!();
      } else {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => GestionarCuentasScreen(sesion: widget.sesion)));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardC,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borC),
        boxShadow: dark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.manage_accounts_rounded, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Gestión de cuentas',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textC)),
            Text('Administración de la plataforma Fluix',
                style: TextStyle(fontSize: 11, color: subC)),
          ]),
          const Spacer(),
          FilledButton(
            onPressed: _abrir,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Gestionar', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ]),
        if (!_cargando) ...[
          const SizedBox(height: 14),
          Divider(height: 1, color: divC),
          const SizedBox(height: 10),
          Row(children: [
            _statChip('Total', '$_totalCuentas', dark ? const Color(0xFFB0B3C1) : const Color(0xFF334155)),
            const SizedBox(width: 10),
            _statChip('Activas', '$_cuentasActivas', const Color(0xFF10B981)),
            const SizedBox(width: 10),
            _statChip('Inactivas', '${_totalCuentas - _cuentasActivas}', const Color(0xFFDC2626)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _abrir,
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: const Text('Abrir panel completo de cuentas'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: const BorderSide(color: accent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: accent)),
          ),
      ]),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10.5, color: color.withValues(alpha: 0.8))),
      ]),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: ELIMINAR CUENTA (requisito Apple App Store)
// ─────────────────────────────────────────────────────────────────────────────

class _BorrarCuentaWidget extends StatefulWidget {
  final SesionUsuario? sesion;
  const _BorrarCuentaWidget({this.sesion});

  @override
  State<_BorrarCuentaWidget> createState() => _BorrarCuentaWidgetState();
}

class _BorrarCuentaWidgetState extends State<_BorrarCuentaWidget> {
  bool _borrando = false;

  Future<void> _solicitarBorrado() async {
    // Primera confirmación
    final primera = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('¿Eliminar cuenta?', style: TextStyle(fontSize: 17)),
        ]),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Esta acción eliminará permanentemente tu cuenta y todos tus datos asociados.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            _InfoChip(
              icono: Icons.schedule,
              color: Colors.orange,
              texto: 'Los datos se borrarán en un plazo máximo de 30 días.',
            ),
            SizedBox(height: 8),
            _InfoChip(
              icono: Icons.email_outlined,
              color: Color(0xFF0D47A1),
              texto: 'Recibirás un correo de confirmación cuando se complete el borrado.',
            ),
            SizedBox(height: 8),
            _InfoChip(
              icono: Icons.delete_forever,
              color: Colors.red,
              texto: 'Se eliminarán: perfil, historial, documentos y acceso a la empresa.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (primera != true || !mounted) return;

    // Segunda confirmación (escribir texto)
    final confirmCtrl = TextEditingController();
    final segunda = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Confirmación final', style: TextStyle(fontSize: 17, color: Colors.red)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Para confirmar la eliminación, escribe BORRAR en el campo siguiente:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'BORRAR',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.red),
                  ),
                ),
                onChanged: (_) => setS(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: confirmCtrl.text.trim().toUpperCase() == 'BORRAR'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: const Text('Eliminar cuenta definitivamente'),
            ),
          ],
        ),
      ),
    );

    if (segunda != true || !mounted) return;

    setState(() => _borrando = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email ?? '';

      if (uid != null) {
        // Marcar la cuenta como "pendiente de borrado" en Firestore
        await FirebaseFirestore.instance.collection('usuarios').doc(uid).update({
          'estado_cuenta': 'pendiente_borrado',
          'solicitud_borrado': FieldValue.serverTimestamp(),
          'fecha_borrado_estimada': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
          'email_borrado': email,
        });

        // Registrar en colección de solicitudes de borrado
        await FirebaseFirestore.instance.collection('solicitudes_borrado').add({
          'uid': uid,
          'email': email,
          'nombre': widget.sesion?.nombre ?? '',
          'empresa_id': widget.sesion?.empresaId ?? '',
          'fecha_solicitud': FieldValue.serverTimestamp(),
          'fecha_borrado_max': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
          'estado': 'pendiente',
          'notificado_email': false,
        });
      }

      if (mounted) {
        // Cerrar sesión
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          FluxToast.exito(context, 'Solicitud registrada. Recibirás un correo cuando se complete el borrado (máx. 30 días).');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _borrando = false);
        FluxToast.error(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red[200]!),
      ),
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.delete_forever, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('Eliminar mi cuenta y datos',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red, fontSize: 14)),
            ]),
            const SizedBox(height: 6),
            Text(
              'Puedes solicitar la eliminación completa de tu cuenta. '
              'En un plazo máximo de 30 días se borrarán todos tus datos '
              'y serás notificado por correo electrónico cuando se complete.',
              style: TextStyle(fontSize: 12, color: Colors.red[700]),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _borrando ? null : _solicitarBorrado,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _borrando
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(_borrando ? 'Procesando...' : 'Solicitar eliminación de cuenta'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip informativo para el diálogo de borrado
class _InfoChip extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String texto;

  const _InfoChip({required this.icono, required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(texto, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ),
      ],
    );
  }
}

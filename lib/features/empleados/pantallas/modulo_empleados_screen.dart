import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../domain/modelos/convenio_colectivo.dart';
import '../../../services/convenio_firestore_service.dart';
import '../../../services/auth/invitaciones_service.dart';
// Widgets extraídos por funcionalidad
import '../widgets/tarjeta_empleado_widget.dart';
import '../widgets/selector_foto_widget.dart';
import '../widgets/seccion_embargos_widget.dart';
import 'formulario_empleado_form.dart';
import 'formulario_datos_nomina_form.dart';

// ═════════════════════════════════════════════════════════════════════════════
// MÓDULO EMPLEADOS
// ═════════════════════════════════════════════════════════════════════════════

class ModuloEmpleadosScreen extends StatefulWidget {
  final String empresaId;
  final SesionUsuario? sesion;
  const ModuloEmpleadosScreen({super.key, required this.empresaId, this.sesion});

  @override
  State<ModuloEmpleadosScreen> createState() => _ModuloEmpleadosScreenState();
}
class _ModuloEmpleadosScreenState extends State<ModuloEmpleadosScreen>
    with WidgetsBindingObserver {
  final _firestore = FirebaseFirestore.instance;
  Timer? _tokenRefreshTimer;
  final _convenioService = ConvenioFirestoreService();
  // Clave para forzar la reconstrucción del StreamBuilder tras token refresh
  Key _streamKey = UniqueKey();

  // Admin y propietario pueden gestionar empleados
  bool get _esPropietario =>
      widget.sesion?.esAdmin ??
      (PermisosService().sesion?.esAdmin ?? false);

  Future<void> _refreshToken() async {
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      debugPrint('🔑 Token renovado en ModuloEmpleados');
    } catch (e) {
      debugPrint('⚠️ Error renovando token en empleados: $e');
    }
  }

  /// Renueva el token y reconstruye el StreamBuilder para reconectarse a Firestore
  Future<void> _refreshTokenYRecargar() async {
    await _refreshToken();
    if (mounted) {
      setState(() => _streamKey = UniqueKey());
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    // Refrescar token inmediatamente al entrar
    _refreshToken();
    // Refrescar token cada 4 minutos para evitar expiración silenciosa
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 4), (_) {
      _refreshToken();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Forzar refresh cuando la app vuelve al primer plano
    if (state == AppLifecycleState.resumed) {
      _refreshTokenYRecargar();
    }
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    _seedConveniosSeguros();
  }

  Future<void> _seedConveniosSeguros() async {
    // Guard: solo plataforma admin puede ejecutar seeds de convenios
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final usuarioDoc = await _firestore.collection('usuarios').doc(uid).get();
    final userData = usuarioDoc.data();
    if (userData == null) return;
    final esPlataformaAdmin = userData['es_plataforma_admin'] == true;
    final esDemo = userData['es_demo'] == true;
    if (!esPlataformaAdmin || esDemo) {
      debugPrint('⏭️ seed convenios omitido — no es plataforma_admin o es cuenta demo');
      return;
    }
    final doc = await _firestore.collection('empresas').doc(widget.empresaId).get();
    final sector = (doc.data()?['sector'] as String? ?? '').toLowerCase();
    final tipo = (doc.data()?['tipo_negocio'] as String? ?? '').toLowerCase();
    final esConstruccion = sector.contains('construcci') || tipo.contains('construcci') || tipo.contains('obra');
    final esCuenca = sector.contains('cuenca');

    final seeds = [
      // Guadalajara (siempre se cargan los genéricos)
      _convenioService.seedConvenioHosteleriaGuadalajara,
      _convenioService.seedConvenioComercioGuadalajara,
      _convenioService.seedConvenioPeluqueriaEsteticaGimnasios,
      _convenioService.seedConvenioCarniceriasGuadalajara2025,
      _convenioService.seedConvenioVeterinariosGuadalajara2026,
      if (esConstruccion)
        _convenioService.seedConvenioConstruccionObrasPublicasGuadalajara,
      // Cuenca — se cargan si el sector indica Cuenca o si es construcción en Cuenca
      if (esCuenca || sector == 'hosteleria_cuenca')
        _convenioService.seedConvenioHosteleriaCuenca,
      if (esCuenca || sector == 'comercio_cuenca' || sector == 'comercio_general_cuenca')
        _convenioService.seedConvenioComercioCuenca,
      if (esConstruccion && esCuenca || sector == 'construccion_cuenca')
        _convenioService.seedConvenioConstruccionCuenca,
    ];
    for (final seed in seeds) {
      try { await seed(); } catch (e) { debugPrint('⚠️ seed: $e'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<QuerySnapshot>(
        key: _streamKey,
        stream: _firestore
            .collection('usuarios')
            .where('empresa_id', isEqualTo: widget.empresaId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final esPermission = snapshot.error.toString().contains('permission-denied') ||
                snapshot.error.toString().contains('PERMISSION_DENIED');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(esPermission ? Icons.lock_clock : Icons.error_outline,
                        size: 56, color: Colors.orange),
                    const SizedBox(height: 16),
                    Text(
                      esPermission
                          ? 'Token expirado. Pulsa "Actualizar" para reconectarte.'
                          : 'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _refreshTokenYRecargar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Actualizar sesión'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final empleados = snapshot.data?.docs ?? [];
          if (empleados.isEmpty) return _buildVacio();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildResumen(empleados)),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final data = empleados[i].data() as Map<String, dynamic>;
                      final id   = empleados[i].id;
                      return TarjetaEmpleado(
                        id: id,
                        data: data,
                        esPropietario: _esPropietario,
                        empresaId: widget.empresaId,
                        onEditar: () => _abrirFormulario(id: id, data: data),
                        onToggleActivo: () => _toggleActivo(id, data['activo'] ?? true),
                        onDatosNomina: () => _abrirFormularioNomina(id, data),
                        onEmbargos: () => _abrirEmbargos(id, data['nombre'] ?? 'Empleado'),
                        onFoto: () => _abrirFoto(id, data['nombre'] ?? 'Empleado'),
                      );
                    },
                    childCount: empleados.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
      floatingActionButton: _esPropietario
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'invitar_empleado',
                  onPressed: _invitarEmpleado,
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  tooltip: 'Invitar empleado',
                  child: const Icon(Icons.mail_outline),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  heroTag: 'crear_empleado',
                  onPressed: () => _abrirFormulario(),
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Nuevo empleado'),
                ),
              ],
            )
          : null,
    ),
    );
  }

  Widget _buildResumen(List<QueryDocumentSnapshot> empleados) {
    int activos = 0, propietarios = 0, admins = 0, staff = 0;
    for (final e in empleados) {
      final d = e.data() as Map<String, dynamic>;
      if (d['activo'] == true) activos++;
      if (d['rol'] == 'propietario') propietarios++;
      if (d['rol'] == 'admin') admins++;
      if (d['rol'] == 'staff') staff++;
    }
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          EmpleadosStatChip(label: 'Total',       valor: '${empleados.length}', icono: Icons.group),
          EmpleadosStatChip(label: 'Activos',     valor: '$activos',    icono: Icons.check_circle),
          EmpleadosStatChip(label: 'Propietario', valor: '$propietarios', icono: Icons.star),
          EmpleadosStatChip(label: 'Admin',       valor: '$admins',     icono: Icons.admin_panel_settings),
          EmpleadosStatChip(label: 'Staff',       valor: '$staff',      icono: Icons.badge),
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.group_add, size: 72, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text('No hay empleados registrados',
            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(
          _esPropietario
              ? 'Pulsa el botón para añadir el primero'
              : 'Solo el propietario puede añadir empleados',
          style: TextStyle(color: Colors.grey[500]),
        ),
      ]),
    );
  }

  Future<void> _toggleActivo(String id, bool actual) async {
    await _firestore.collection('usuarios').doc(id).update({'activo': !actual});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(!actual ? 'Empleado activado' : 'Empleado desactivado')));
    }
  }

  Future<void> _abrirFormulario({String? id, Map<String, dynamic>? data}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FormularioEmpleado(empresaId: widget.empresaId, id: id, data: data),
    );
  }

  // ── INVITAR EMPLEADO POR EMAIL ──────────────────────────────────────────

  Future<void> _invitarEmpleado() async {
    final emailCtrl = TextEditingController();
    String rolSeleccionado = 'staff';

    final resultado = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.mail_outline, color: Color(0xFF0D47A1)),
              SizedBox(width: 8),
              Text('Invitar empleado', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Envía una invitación por email. El empleado recibirá un código para unirse a tu empresa.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email del empleado',
                  hintText: 'ejemplo@correo.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: rolSeleccionado,
                decoration: InputDecoration(
                  labelText: 'Rol asignado',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('🛡️ Administrador')),
                  DropdownMenuItem(value: 'staff', child: Text('👤 Staff / Empleado')),
                ],
                onChanged: (v) => setDialogState(() => rolSeleccionado = v ?? 'staff'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final email = emailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Introduce un email válido')),
                  );
                  return;
                }
                Navigator.pop(ctx, {'email': email, 'rol': rolSeleccionado});
              },
              icon: const Icon(Icons.send),
              label: const Text('Enviar invitación'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    if (resultado == null || !mounted) return;

    try {
      // Obtener nombre de empresa
      final empresaDoc = await _firestore.collection('empresas').doc(widget.empresaId).get();
      final empresaNombre = (empresaDoc.data()?['perfil'] as Map<String, dynamic>?)?['nombre']
          ?? empresaDoc.data()?['nombre']
          ?? 'Mi Empresa';

      await InvitacionesService().enviarInvitacion(
        email: resultado['email']!,
        rol: resultado['rol']!,
        empresaId: widget.empresaId,
        empresaNombre: empresaNombre.toString(),
        creadoPorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Invitación enviada a ${resultado['email']}'),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _abrirFoto(String empleadoId, String nombre) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelectorFotoEmpleado(
          empresaId: widget.empresaId, empleadoId: empleadoId, nombreEmpleado: nombre),
    );
  }

  void _abrirEmbargos(String empleadoId, String nombreEmpleado) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => SeccionEmbargos(empleadoId: empleadoId, nombreEmpleado: nombreEmpleado),
    );
  }

  Future<void> _abrirFormularioNomina(String empleadoId, Map<String, dynamic> data) async {
    final datosNomina = data['datos_nomina'] as Map<String, dynamic>?;
    final empresaDoc  = await _firestore.collection('empresas').doc(widget.empresaId).get();
    final sector      = empresaDoc.data()?['sector'] as String? ?? 'otros';

    List<CategoriaConvenio> categorias = [];
    if (sector == 'hosteleria') {
      categorias = await _convenioService.obtenerCategorias('hosteleria-guadalajara');
    } else if (sector == 'comercio') {
      categorias = await _convenioService.obtenerCategorias('comercio-guadalajara');
    } else if (sector == 'peluqueria') {
      categorias = await _convenioService.obtenerCategorias('peluqueria-estetica-gimnasios');
    } else if (sector == 'carniceria' || sector == 'industrias_carnicas') {
      categorias = await _convenioService.obtenerCategorias('industrias-carnicas-guadalajara-2025');
    } else if (sector == 'veterinarios' || sector == 'veterinaria' || sector == 'clinica_veterinaria') {
      categorias = await _convenioService.obtenerCategorias('veterinarios-guadalajara-2026');
    } else if (sector == 'construccion' || sector == 'obras_publicas' || sector == 'construccion_obras_publicas') {
      // Cargar solo las categorías 2026 (año vigente por defecto)
      final todas = await _convenioService.obtenerCategorias('construccion-obras-publicas-guadalajara');
      categorias = todas.where((c) => c.id.endsWith('-2026')).toList();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => Material(
        color: Colors.transparent,
        child: FormularioDatosNomina(
          empleadoId: empleadoId,
          empleadoNombre: data['nombre'] ?? 'Empleado',
          datosActuales: datosNomina,
          categoriasConvenio: categorias,
        ),
      ),
    );
  }
}


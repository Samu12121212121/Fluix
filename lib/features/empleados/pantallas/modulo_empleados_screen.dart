import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/mixins/safe_stream_mixin.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../domain/modelos/convenio_colectivo.dart';
import '../../../services/convenio_firestore_service.dart';
import '../../../services/auth/invitaciones_service.dart';
import '../widgets/tarjeta_empleado_widget.dart';
import '../widgets/selector_foto_widget.dart';
import '../widgets/seccion_embargos_widget.dart';
import 'formulario_empleado_form.dart';
import 'formulario_datos_nomina_form.dart';
import 'empleados_baja_screen.dart';

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
    with WidgetsBindingObserver, SafeStreamMixin {
  final _firestore = FirebaseFirestore.instance;
  final _convenioService = ConvenioFirestoreService();
  Timer? _tokenRefreshTimer;
  Key _streamKey = UniqueKey();

  String _busqueda  = '';
  String _filtroRol = 'todos';

  static const _primary = Color(0xFF0D47A1);
  static const _accent  = Color(0xFF3B82F6);
  Color get _bg       => const Color(0xFFF4F6FB);
  Color get _panelBg  => Colors.white;
  Color get _border   => const Color(0x14000000);
  Color get _textMain => const Color(0xFF0F172A);
  Color get _textSoft => const Color(0xFF475569);

  bool get _esPropietario =>
      widget.sesion?.esAdmin ?? (PermisosService().sesion?.esAdmin ?? false);

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _refreshToken();
    _tokenRefreshTimer = Timer.periodic(const Duration(minutes: 4), (_) => _refreshToken());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshTokenYRecargar();
  }

  @override
  void dispose() {
    _tokenRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    _seedConveniosSeguros();
  }

  Future<void> _refreshToken() async {
    try { await FirebaseAuth.instance.currentUser?.getIdToken(true); } catch (_) {}
  }

  Future<void> _refreshTokenYRecargar() async {
    await _refreshToken();
    if (mounted) setState(() => _streamKey = UniqueKey());
  }

  // ── Filtrado ───────────────────────────────────────────────────────────────

  List<QueryDocumentSnapshot> _aplicarFiltros(List<QueryDocumentSnapshot> lista) {
    var r = lista.where((doc) {
      final d = doc.data() as Map<String, dynamic>;
      if (_filtroRol == 'activo')   return d['activo'] == true;
      if (_filtroRol == 'inactivo') return d['activo'] == false;
      if (_filtroRol == 'admin')    return d['rol'] == 'admin';
      if (_filtroRol == 'staff')    return d['rol'] == 'staff';
      return true;
    }).toList();
    if (_busqueda.isNotEmpty) {
      final q = _busqueda.toLowerCase();
      r = r.where((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return (d['nombre'] ?? '').toLowerCase().contains(q) ||
               (d['correo'] ?? '').toLowerCase().contains(q) ||
               (d['puesto'] ?? '').toLowerCase().contains(q) ||
               (d['dni']    ?? '').toLowerCase().contains(q);
      }).toList();
    }
    r.sort((a, b) {
      final na = (a.data() as Map<String, dynamic>)['nombre'] as String? ?? '';
      final nb = (b.data() as Map<String, dynamic>)['nombre'] as String? ?? '';
      return na.toLowerCase().compareTo(nb.toLowerCase());
    });
    return r;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: _bg,
        body: StreamBuilder<QuerySnapshot>(
          key: _streamKey,
          stream: _firestore
              .collection('usuarios')
              .where('empresa_id', isEqualTo: widget.empresaId)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) return _buildError(snap.error);
            final todos     = snap.data?.docs ?? [];
            final filtrados = _aplicarFiltros(List.from(todos));
            return Stack(children: [
              _glow(_accent,  top: -120, left: -80),
              _glow(_primary, top:  160, right: -100),
              Column(children: [
                _buildKpis(todos),
                Expanded(
                  child: todos.isEmpty
                      ? _buildVacio()
                      : LayoutBuilder(builder: (_, c) {
                          final wide = c.maxWidth > 700;
                          if (wide) {
                            return Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Expanded(flex: 5, child: _buildTabla(filtrados)),
                                const SizedBox(width: 14),
                                Expanded(flex: 3, child: _buildPanel(todos)),
                              ]),
                            );
                          }
                          return Padding(
                              padding: const EdgeInsets.all(12),
                              child: _buildTabla(filtrados));
                        }),
                ),
              ]),
            ]);
          },
        ),
        floatingActionButton: _esPropietario ? _buildFab() : null,
      ),
    );
  }

  Widget _glow(Color c, {double? top, double? left, double? right, double? bottom}) =>
      Positioned(
        top: top, left: left, right: right, bottom: bottom,
        child: IgnorePointer(child: Container(
          width: 300, height: 300,
          decoration: BoxDecoration(shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: c.withValues(alpha: 0.07), blurRadius: 100, spreadRadius: 40)]),
        )),
      );

  // ── KPIs ───────────────────────────────────────────────────────────────────

  Widget _buildKpis(List<QueryDocumentSnapshot> todos) {
    final activos   = todos.where((e) => (e.data() as Map)['activo'] == true).length;
    final inactivos = todos.length - activos;
    final admins    = todos.where((e) => (e.data() as Map)['rol'] == 'admin').length;
    return Container(
      color: _panelBg,
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        _kpiCard('Total',     '${todos.length}', const Color(0xFF0D47A1)),
        const SizedBox(width: 7),
        _kpiCard('Activos',   '$activos',         const Color(0xFF10B981)),
        const SizedBox(width: 7),
        _kpiCard('Inactivos', '$inactivos',       const Color(0xFFEF4444)),
        const SizedBox(width: 7),
        _kpiCard('Admins',    '$admins',           const Color(0xFF8B5CF6)),
        const SizedBox(width: 7),
        _kpiCardBtn('Bajas',    Icons.sick_outlined, const Color(0xFFF97316),
            () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => EmpleadosBajaScreen(empresaId: widget.empresaId)))),
        const SizedBox(width: 7),
        _kpiCardBtn('Invitar', Icons.mail_outline, const Color(0xFF06B6D4), _invitarEmpleado),
      ]),
    );
  }

  Widget _kpiCard(String label, String num, Color glow) => Expanded(
    child: Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          color: _panelBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
      child: Stack(children: [
        Positioned(top: -18, right: -18, child: Container(width: 62, height: 62,
          decoration: BoxDecoration(shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.35), blurRadius: 22, spreadRadius: 14)]))),
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(num, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _textMain),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10, color: _textSoft),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
      ]),
    ),
  );

  Widget _kpiCardBtn(String label, IconData icon, Color glow, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
            color: _panelBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
        child: Stack(children: [
          Positioned(top: -18, right: -18, child: Container(width: 62, height: 62,
            decoration: BoxDecoration(shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: glow.withValues(alpha: 0.35), blurRadius: 22, spreadRadius: 14)]))),
          Padding(padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: glow, size: 16),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textMain),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(children: [
                Text('Ver', style: TextStyle(fontSize: 9.5, color: glow)),
                Icon(Icons.chevron_right, color: glow, size: 11),
              ]),
            ])),
        ]),
      ),
    ),
  );

  // ── Tabla ──────────────────────────────────────────────────────────────────

  Widget _buildTabla(List<QueryDocumentSnapshot> lista) => Container(
    decoration: BoxDecoration(
      color: _panelBg, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: [
      // Búsqueda
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: TextField(
          onChanged: (v) => setState(() => _busqueda = v),
          style: TextStyle(color: _textMain, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre, correo, DNI o puesto…',
            hintStyle: TextStyle(fontSize: 12.5, color: _textSoft),
            prefixIcon: Icon(Icons.search, color: _textSoft, size: 17),
            suffixIcon: _busqueda.isNotEmpty
                ? IconButton(icon: Icon(Icons.clear, size: 15, color: _textSoft),
                    onPressed: () => setState(() => _busqueda = ''))
                : null,
            filled: true, fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _accent, width: 1.5)),
          ),
        ),
      ),
      // Filtros + botón
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip('Todos',     _filtroRol == 'todos',    () => setState(() => _filtroRol = 'todos')),
                _chip('Activos',   _filtroRol == 'activo',   () => setState(() => _filtroRol = 'activo')),
                _chip('Inactivos', _filtroRol == 'inactivo', () => setState(() => _filtroRol = 'inactivo')),
                _chip('Admin',     _filtroRol == 'admin',    () => setState(() => _filtroRol = 'admin')),
                _chip('Staff',     _filtroRol == 'staff',    () => setState(() => _filtroRol = 'staff')),
              ]),
            ),
          ),
          if (_esPropietario) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _abrirFormulario(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_primary, _accent]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 6))],
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add, color: Colors.white, size: 15),
                  SizedBox(width: 5),
                  Text('Nuevo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ]),
              ),
            ),
          ],
        ]),
      ),
      // Cabecera tabla
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border(top: BorderSide(color: _border), bottom: BorderSide(color: _border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Expanded(flex: 3, child: _colLabel('EMPLEADO')),
          Expanded(flex: 2, child: _colLabel('ROL')),
          Expanded(flex: 2, child: _colLabel('PUESTO')),
          Expanded(flex: 1, child: _colLabel('ESTADO')),
          const SizedBox(width: 24),
        ]),
      ),
      // Filas
      Expanded(
        child: lista.isEmpty
            ? Center(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Sin resultados para "$_busqueda"',
                    style: TextStyle(color: _textSoft, fontSize: 13))))
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: lista.length,
                itemBuilder: (_, i) => _tableRow(lista[i]),
              ),
      ),
    ]),
  );

  Widget _colLabel(String t) => Text(t,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          color: Color(0xFF94A3B8), letterSpacing: 0.8));

  Widget _tableRow(QueryDocumentSnapshot doc) {
    final d       = doc.data() as Map<String, dynamic>;
    final id      = doc.id;
    final activo  = d['activo'] as bool? ?? true;
    final rol     = d['rol'] as String? ?? 'staff';
    final nombre  = d['nombre'] as String? ?? 'Sin nombre';
    final correo  = d['correo'] as String? ?? '';
    final puesto  = d['puesto'] as String? ?? '—';
    final fotoUrl = d['foto_url'] as String?;

    Color colorRol; String etiqRol;
    switch (rol) {
      case 'propietario': colorRol = const Color(0xFF7B1FA2); etiqRol = 'Propietario'; break;
      case 'admin':       colorRol = _primary;                etiqRol = 'Admin'; break;
      default:            colorRol = const Color(0xFF00796B); etiqRol = 'Staff';
    }
    final iniciales = _iniciales(nombre);

    return InkWell(
      onTap: _esPropietario
          ? () => TarjetaEmpleado(
                id: id, data: d, esPropietario: _esPropietario, empresaId: widget.empresaId,
                onEditar:       () => _abrirFormulario(id: id, data: d),
                onToggleActivo: () => _toggleActivo(id, activo),
                onDatosNomina:  () => _abrirFormularioNomina(id, d),
                onEmbargos:     () => _abrirEmbargos(id, nombre),
                onFoto:         () => _abrirFoto(id, nombre),
              ).mostrarOpciones(context)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
        child: Row(children: [
          Expanded(flex: 3, child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorRol.withValues(alpha: 0.15),
              backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
              child: fotoUrl == null
                  ? Text(iniciales, style: TextStyle(color: colorRol, fontSize: 12, fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textMain),
                  overflow: TextOverflow.ellipsis),
              if (correo.isNotEmpty)
                Text(correo, style: TextStyle(fontSize: 11, color: _textSoft), overflow: TextOverflow.ellipsis),
            ])),
          ])),
          Expanded(flex: 2, child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: colorRol.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(etiqRol, style: TextStyle(color: colorRol, fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          ))),
          Expanded(flex: 2, child: Text(puesto,
              style: TextStyle(fontSize: 12, color: _textSoft), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 1, child: Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: activo ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(activo ? 'Activo' : 'Inactivo',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: activo ? const Color(0xFF059669) : Colors.red[700]),
                textAlign: TextAlign.center),
          ))),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: const Color(0xFF94A3B8), size: 16),
        ]),
      ),
    );
  }

  String _iniciales(String nombre) {
    final p = nombre.trim().split(' ');
    if (p.length >= 2 && p[0].isNotEmpty && p[1].isNotEmpty) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E';
  }

  // ── Panel derecho ──────────────────────────────────────────────────────────

  Widget _buildPanel(List<QueryDocumentSnapshot> todos) {
    final propietarios = todos.where((e) => (e.data() as Map)['rol'] == 'propietario').length;
    final admins       = todos.where((e) => (e.data() as Map)['rol'] == 'admin').length;
    final staff = todos.where((e) => !['propietario', 'admin'].contains((e.data() as Map)['rol'])).length;
    final total        = todos.length;
    final recientes    = List.from(todos)..sort((a, b) {
      final fa = (a.data() as Map)['fecha_creacion'] as String? ?? '';
      final fb = (b.data() as Map)['fecha_creacion'] as String? ?? '';
      return fb.compareTo(fa);
    });
    final top3 = recientes.take(3).toList();

    return SingleChildScrollView(child: Column(children: [
      _panelCard('Distribución por rol', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _rolBar('Propietarios', propietarios, total, const Color(0xFF7B1FA2)),
        const SizedBox(height: 10),
        _rolBar('Admins', admins, total, _primary),
        const SizedBox(height: 10),
        _rolBar('Staff', staff, total, const Color(0xFF00796B)),
      ])),
      const SizedBox(height: 14),
      _panelCard('Últimas incorporaciones', Column(children: [
        if (top3.isEmpty)
          Text('Sin incorporaciones recientes', style: TextStyle(fontSize: 12, color: _textSoft))
        else ...top3.map((doc) {
          final d      = doc.data() as Map<String, dynamic>;
          final nombre = d['nombre'] as String? ?? '';
          final rol    = d['rol'] as String? ?? 'staff';
          final fecha  = d['fecha_creacion'] as String? ?? '';
          final Color c = rol == 'propietario' ? const Color(0xFF7B1FA2)
                        : rol == 'admin'       ? _primary
                        : const Color(0xFF00796B);
          final dt = DateTime.tryParse(fecha);
          final fechaCorta = dt != null
              ? '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}'
              : '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              CircleAvatar(radius: 16, backgroundColor: c.withValues(alpha: 0.15),
                  child: Text(_iniciales(nombre),
                      style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(nombre, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textMain),
                    overflow: TextOverflow.ellipsis),
                if (fechaCorta.isNotEmpty)
                  Text(fechaCorta, style: TextStyle(fontSize: 10, color: _textSoft)),
              ])),
            ]),
          );
        }),
      ])),
    ]));
  }

  Widget _panelCard(String titulo, Widget content) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _panelBg, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _textMain)),
      const SizedBox(height: 12),
      content,
    ]),
  );

  Widget _rolBar(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 12, color: _textSoft)),
        Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textMain)),
      ]),
      const SizedBox(height: 4),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: pct,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color), minHeight: 6)),
    ]);
  }

  // ── Helpers UI ─────────────────────────────────────────────────────────────

  Widget _chip(String label, bool activo, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: activo ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? _primary : _border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: activo ? Colors.white : _textSoft)),
      ),
    ),
  );

  Widget _buildFab() => Column(mainAxisSize: MainAxisSize.min, children: [
    FloatingActionButton.small(
      heroTag: 'invitar_empleado', onPressed: _invitarEmpleado,
      backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white,
      tooltip: 'Invitar empleado', child: const Icon(Icons.mail_outline),
    ),
    const SizedBox(height: 8),
    FloatingActionButton.extended(
      heroTag: 'crear_empleado', onPressed: () => _abrirFormulario(),
      backgroundColor: _primary, foregroundColor: Colors.white,
      icon: const Icon(Icons.person_add), label: const Text('Nuevo empleado'),
    ),
  ]);

  Widget _buildVacio() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.group_add, size: 72, color: Colors.grey[400]),
    const SizedBox(height: 16),
    Text('No hay empleados registrados',
        style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
    const SizedBox(height: 8),
    Text(_esPropietario ? 'Pulsa el botón para añadir el primero' : 'Solo el propietario puede añadir empleados',
        style: TextStyle(color: Colors.grey[500])),
  ]));

  Widget _buildError(Object? error) {
    final esPermission = error.toString().contains('permission-denied') ||
        error.toString().contains('PERMISSION_DENIED');
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(esPermission ? Icons.lock_clock : Icons.error_outline, size: 56, color: Colors.orange),
        const SizedBox(height: 16),
        Text(esPermission
            ? 'Token expirado. Pulsa "Actualizar" para reconectarte.'
            : 'Error: $error',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _refreshTokenYRecargar,
          icon: const Icon(Icons.refresh), label: const Text('Actualizar sesión'),
          style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
        ),
      ]),
    ));
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _toggleActivo(String id, bool actual) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(actual ? 'Desactivar empleado' : 'Activar empleado'),
        content: Text(actual
            ? '¿Seguro que quieres desactivar este empleado? Perderá acceso a la app.'
            : '¿Activar este empleado?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: actual ? Colors.red : Colors.green, foregroundColor: Colors.white),
            child: Text(actual ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await _firestore.collection('usuarios').doc(id).update({'activo': !actual});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(!actual ? 'Empleado activado' : 'Empleado desactivado')));
    }
  }

  Future<void> _abrirFormulario({String? id, Map<String, dynamic>? data}) async {
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => FormularioEmpleado(empresaId: widget.empresaId, id: id, data: data),
    );
  }

  Future<void> _invitarEmpleado() async {
    final emailCtrl = TextEditingController();
    String rolSeleccionado = 'staff';
    final resultado = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.mail_outline, color: Color(0xFF0D47A1)),
            SizedBox(width: 8),
            Text('Invitar empleado', style: TextStyle(fontSize: 16)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('El empleado recibirá un código para unirse a tu empresa.',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email del empleado', hintText: 'ejemplo@correo.com',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: rolSeleccionado,
              decoration: InputDecoration(
                labelText: 'Rol asignado', prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('🛡️ Administrador')),
                DropdownMenuItem(value: 'staff', child: Text('👤 Staff / Empleado')),
              ],
              onChanged: (v) => setDialogState(() => rolSeleccionado = v ?? 'staff'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton.icon(
              onPressed: () {
                final email = emailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Introduce un email válido')));
                  return;
                }
                Navigator.pop(ctx, {'email': email, 'rol': rolSeleccionado});
              },
              icon: const Icon(Icons.send),
              label: const Text('Enviar invitación'),
              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
    if (resultado == null || !mounted) return;
    try {
      final empresaDoc  = await _firestore.collection('empresas').doc(widget.empresaId).get();
      final empresaNombre = (empresaDoc.data()?['perfil'] as Map<String, dynamic>?)?['nombre']
          ?? empresaDoc.data()?['nombre'] ?? 'Mi Empresa';
      await InvitacionesService().enviarInvitacion(
        email: resultado['email']!,
        rol: resultado['rol']!,
        empresaId: widget.empresaId,
        empresaNombre: empresaNombre.toString(),
        creadoPorUid: FirebaseAuth.instance.currentUser?.uid ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('✅ Invitación enviada a ${resultado['email']}'),
            backgroundColor: const Color(0xFF2E7D32)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _abrirFoto(String empleadoId, String nombre) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => SelectorFotoEmpleado(
          empresaId: widget.empresaId, empleadoId: empleadoId, nombreEmpleado: nombre),
    );
  }

  void _abrirEmbargos(String empleadoId, String nombreEmpleado) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, useSafeArea: true,
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
      final todas = await _convenioService.obtenerCategorias('construccion-obras-publicas-guadalajara');
      categorias = todas.where((c) => c.id.endsWith('-2026')).toList();
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, useSafeArea: true,
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

  Future<void> _seedConveniosSeguros() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final usuarioDoc = await _firestore.collection('usuarios').doc(uid).get();
    final userData   = usuarioDoc.data();
    if (userData == null) return;
    if (userData['es_plataforma_admin'] != true || userData['es_demo'] == true) return;

    final doc    = await _firestore.collection('empresas').doc(widget.empresaId).get();
    final sector = (doc.data()?['sector'] as String? ?? '').toLowerCase();
    final tipo   = (doc.data()?['tipo_negocio'] as String? ?? '').toLowerCase();
    final esConstruccion = sector.contains('construcci') || tipo.contains('construcci') || tipo.contains('obra');
    final esCuenca       = sector.contains('cuenca');

    final seeds = [
      _convenioService.seedConvenioHosteleriaGuadalajara,
      _convenioService.seedConvenioComercioGuadalajara,
      _convenioService.seedConvenioPeluqueriaEsteticaGimnasios,
      _convenioService.seedConvenioCarniceriasGuadalajara2025,
      _convenioService.seedConvenioVeterinariosGuadalajara2026,
      if (esConstruccion) _convenioService.seedConvenioConstruccionObrasPublicasGuadalajara,
      if (esCuenca || sector == 'hosteleria_cuenca') _convenioService.seedConvenioHosteleriaCuenca,
      if (esCuenca || sector == 'comercio_cuenca' || sector == 'comercio_general_cuenca')
        _convenioService.seedConvenioComercioCuenca,
      if (esConstruccion && esCuenca || sector == 'construccion_cuenca')
        _convenioService.seedConvenioConstruccionCuenca,
    ];
    for (final seed in seeds) {
      try { await seed(); } catch (e) { debugPrint('⚠️ seed: $e'); }
    }
  }
}

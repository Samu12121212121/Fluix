import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/app_settings.dart';
import '../../../core/widgets/flux_toast.dart';
import '../../../core/widgets/fluix_app_bar.dart';
import '../../../core/mixins/safe_stream_mixin.dart';
import '../../../core/utils/permisos_service.dart';
import '../../../domain/modelos/convenio_colectivo.dart';
import '../../../services/convenio_firestore_service.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../services/auth/invitaciones_service.dart';
import '../widgets/canal_comunicacion_widget.dart';
import '../widgets/selector_foto_widget.dart';
import '../widgets/seccion_embargos_widget.dart';
import '../widgets/documentos_empleado_widget.dart';
import '../../../services/suscripcion_service.dart';
import '../../fichajes/pantallas/gestion_fichajes_screen.dart';
import '../../vacaciones/pantallas/vacaciones_screen.dart';
import 'formulario_empleado_form.dart';
import 'formulario_datos_nomina_form.dart';
import 'empleados_baja_screen.dart' show EmpleadosBajaPopup;
import '../widgets/nominas_empleado_widget.dart';
import 'portal_empleado_screen.dart';
import '../../../services/widget_manager_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// MÓDULO EMPLEADOS — UI rediseñada
// ═════════════════════════════════════════════════════════════════════════════

// Colores de acento (invariantes)
const _kBlue   = Color(0xFF3B82F6);
const _kGreen  = Color(0xFF22C55E);
const _kOrange = Color(0xFFF59E0B);
const _kRed    = Color(0xFFEF4444);
// Colores base light (fallback)
const _kText   = Color(0xFF111827);
const _kSub    = Color(0xFF6B7280);
const _kBorder = Color(0xFFE5E7EB);
const _kBg     = Color(0xFFF8F9FA);

class ModuloEmpleadosScreen extends StatefulWidget {
  final String empresaId;
  final SesionUsuario? sesion;
  const ModuloEmpleadosScreen({super.key, required this.empresaId, this.sesion});

  @override
  State<ModuloEmpleadosScreen> createState() => _ModuloEmpleadosScreenState();
}

String _generarPassword() {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  final rng = Random.secure();
  return List.generate(10, (_) => chars[rng.nextInt(chars.length)]).join();
}

class _ModuloEmpleadosScreenState extends State<ModuloEmpleadosScreen>
    with WidgetsBindingObserver, SafeStreamMixin {

  final _firestore       = FirebaseFirestore.instance;
  final _convenioService = ConvenioFirestoreService();
  Timer? _autoRefreshTimer;

  // Dark mode
  bool _isDark = false;
  Color get _bg     => _isDark ? const Color(0xFF0F172A) : _kBg;
  Color get _surf   => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _text   => _isDark ? const Color(0xFFE2E8F0) : _kText;
  Color get _sub2   => _isDark ? const Color(0xFF94A3B8) : _kSub;
  Color get _border => _isDark ? const Color(0xFF334155) : _kBorder;

  // Estado de datos — sin stream, carga puntual
  List<QueryDocumentSnapshot> _empleados = [];
  Map<String, Map<String, String>> _fichajesHoy = {};
  // Saldos de vacaciones: empleadoId → {devengados, disfrutados}
  Map<String, Map<String, double>> _saldosVac = {};
  bool _cargando = true;
  DateTime? _ultimaCarga;
  Object? _errorCarga;

  int     _paginaGrid = 0;
  QueryDocumentSnapshot? _seleccionado;

  // Verdadero si el usuario actual es admin o propietario (puede gestionar empleados)
  bool get _esPropietario {
    // 1. Sesión pasada desde el widget (fuente más fiable)
    if (widget.sesion != null) return widget.sesion!.esAdmin;
    // 2. Servicio de permisos global
    final s = PermisosService().sesion;
    if (s != null) return s.esAdmin;
    // 3. Fallback: leer rol del usuario actual (cargado en _cargarTodo)
    return _rolActualLocal == 'propietario' || _rolActualLocal == 'admin';
  }

  String _rolActualLocal = '';

  @override
  void initState() {
    super.initState();
    _isDark = AppSettings.darkMode.value;
    AppSettings.darkMode.addListener(_onDarkChange);
    WidgetsBinding.instance.addObserver(this);
    _cargarTodo();
    // Refresco automático cada 5 min: suficiente para RRHH y coincide con TTL del token
    _autoRefreshTimer = Timer.periodic(
        const Duration(minutes: 10), (_) => _cargarTodo(silencioso: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _cargarTodo();
  }

  void _onDarkChange() {
    if (mounted) setState(() => _isDark = AppSettings.darkMode.value);
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    AppSettings.darkMode.removeListener(_onDarkChange);
    WidgetsBinding.instance.removeObserver(this);
    _seedConveniosSeguros().ignore();
    super.dispose();
  }

  // ── Carga puntual ─────────────────────────────────────────────────────────

  /// [silencioso] = true → no muestra spinner, actualiza en background.
  Future<void> _cargarTodo({bool silencioso = false, bool forzarRed = false}) async {
    if (!mounted) return;
    if (!silencioso) setState(() { _cargando = true; _errorCarga = null; });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await currentUser?.getIdToken(true);

      // Cargar rol del usuario actual como fallback de seguridad
      if (currentUser != null && _rolActualLocal.isEmpty) {
        final meDoc = await _firestore.collection('usuarios').doc(currentUser.uid).get();
        if (mounted) {
          _rolActualLocal = meDoc.data()?['rol'] as String? ?? '';
        }
      }

      final options = forzarRed
          ? const GetOptions(source: Source.server)
          : const GetOptions(source: Source.serverAndCache);

      final snap = await _firestore
          .collection('usuarios')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .get(options)
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;
      setState(() {
        _empleados   = snap.docs;
        _cargando    = false;
        _ultimaCarga = DateTime.now();
        _errorCarga  = null;
        // Resetear paginación si cambia el número de empleados
        _paginaGrid  = 0;
      });

      // Fichajes y saldos de vacaciones en la misma pasada
      await Future.wait([_cargarFichajeBatch(), _cargarSaldosVac()]);
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _errorCarga = e; });
    }
  }

  // Una sola query para todos los fichajes de hoy
  Future<void> _cargarFichajeBatch() async {
    final now = DateTime.now();
    final hoy = '${now.year}-${now.month.toString().padLeft(2,'0')}'
        '-${now.day.toString().padLeft(2,'0')}';
    try {
      final snap = await _firestore
          .collection('empresas').doc(widget.empresaId)
          .collection('fichajes')
          .where('fecha', isEqualTo: hoy)
          .get()
          .timeout(const Duration(seconds: 8));

      final Map<String, Map<String, String>> result = {};
      for (final doc in snap.docs) {
        final d     = doc.data();
        final empId = d['empleado_id'] as String?;
        if (empId == null) continue;
        final tsEntrada = d['entrada'] as Timestamp?;
        if (tsEntrada == null) continue;

        final dtE = tsEntrada.toDate().toLocal();
        final entradaStr = '${dtE.hour.toString().padLeft(2,'0')}:'
            '${dtE.minute.toString().padLeft(2,'0')}';

        final tsSalida = d['salida'] as Timestamp?;
        String ultimoStr;
        String horasStr = '—';
        if (tsSalida != null) {
          final dtS = tsSalida.toDate().toLocal();
          ultimoStr = '${dtS.hour.toString().padLeft(2,'0')}:'
              '${dtS.minute.toString().padLeft(2,'0')}';
          final mins = dtS.difference(dtE).inMinutes;
          horasStr = '${mins ~/ 60}h ${mins % 60}m';
        } else {
          ultimoStr = 'En jornada';
        }

        // Si ya existe uno para este empleado, sólo actualizar si éste es más reciente
        if (!result.containsKey(empId)) {
          result[empId] = {
            'entrada': entradaStr,
            'ultimo':  ultimoStr,
            'horas':   horasStr,
          };
        }
      }
      if (mounted) setState(() => _fichajesHoy = result);
    } catch (_) {}
  }

  // Batch saldos de vacaciones: una query para el año actual
  Future<void> _cargarSaldosVac() async {
    final anio = DateTime.now().year;
    try {
      final snap = await _firestore
          .collection('vacaciones').doc(widget.empresaId)
          .collection('saldos')
          .where('anio', isEqualTo: anio)
          .get()
          .timeout(const Duration(seconds: 8));

      final Map<String, Map<String, double>> result = {};
      for (final doc in snap.docs) {
        final d      = doc.data();
        final empId  = d['empleado_id'] as String?;
        if (empId == null) continue;
        result[empId] = {
          'devengados':   (d['dias_devengados']  as num?)?.toDouble() ?? 0,
          'disfrutados':  (d['dias_disfrutados'] as num?)?.toDouble() ?? 0,
          'arrastre':     (d['dias_arrastre']    as num?)?.toDouble() ?? 0,
        };
      }
      if (mounted) setState(() => _saldosVac = result);
    } catch (_) {}
  }

  // ── Ordenado alfabético ───────────────────────────────────────────────────

  List<QueryDocumentSnapshot> _filtrar(List<QueryDocumentSnapshot> lista) {
    final r = List<QueryDocumentSnapshot>.from(lista);
    r.sort((a, b) {
      final na = ((a.data() as Map)['nombre'] as String?) ?? '';
      final nb = ((b.data() as Map)['nombre'] as String?) ?? '';
      return na.toLowerCase().compareTo(nb.toLowerCase());
    });
    return r;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Staff (no admin): ve directamente su portal personal.
    // NO usa Scaffold propio — el dashboard ya provee sidebar + topbar.
    // Solo si es ruta hija (mobile push) añade FluixAppBar.
    final esStaff = widget.sesion?.esStaff == true;
    if (esStaff) {
      final esPush = ModalRoute.of(context)?.isFirst == false;
      final portal = ColoredBox(
        color: _bg,
        child: PortalEmpleadoScreen(
          empresaId: widget.empresaId,
          empleadoUid: widget.sesion?.uid,
          modoAdmin: false,
          isDark: _isDark,
        ),
      );
      if (!esPush) return portal; // embebido: el dashboard pone el marco
      return Scaffold(
        backgroundColor: _bg,
        appBar: FluixAppBar(
          titulo: 'Mi portal',
          titleNavigatesBack: true,
        ),
        body: portal,
      );
    }

    if (_cargando && _empleados.isEmpty) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kBlue)),
      );
    }
    if (_errorCarga != null && _empleados.isEmpty) {
      return Scaffold(backgroundColor: _kBg, body: _buildError(_errorCarga));
    }

    final canPop    = ModalRoute.of(context)?.isFirst == false;
    final filtrados = _filtrar(_empleados);
    final screenW   = MediaQuery.of(context).size.width;
    final wide      = screenW > 860;

    // En mobile (canPop), el header inline se oculta porque FluixAppBar lo reemplaza
    Widget columna = Column(children: [
      if (!canPop) _buildHeader(context),
      _buildKpis(),
      Expanded(child: _empleados.isEmpty ? _buildVacio() : _buildGrid(filtrados, context)),
    ]);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: _bg,
        // FluixAppBar idéntico al de clientes — solo en mobile (ruta empujada)
        appBar: canPop
            ? FluixAppBar(
                titulo:             'Empleados',
                titleNavigatesBack: true,
                extraActions: [
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 19, color: _kSub),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onSelected: (v) {
                      if (v == 'csv_dl')    _descargarCSV(context);
                      if (v == 'csv_share') _compartirCSV(context);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'csv_dl',    child: ListTile(leading: Icon(Icons.download_outlined), title: Text('Descargar CSV'), dense: true, contentPadding: EdgeInsets.zero)),
                      PopupMenuItem(value: 'csv_share', child: ListTile(leading: Icon(Icons.share_outlined),   title: Text('Compartir CSV'), dense: true, contentPadding: EdgeInsets.zero)),
                    ],
                  ),
                  if (_esPropietario)
                    IconButton(
                      tooltip: 'Nuevo empleado',
                      onPressed: () => _abrirFormulario(),
                      icon: const Icon(Icons.add_rounded, size: 20, color: _kBlue),
                    ),
                ],
              )
            : null,
        body: wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: columna),
                _buildDetailPanel(context),
              ])
            : columna,
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final fmt = _ultimaCarga == null ? '' :
        'Actualizado ${_ultimaCarga!.hour.toString().padLeft(2,'0')}'
        ':${_ultimaCarga!.minute.toString().padLeft(2,'0')}';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: _surf,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(children: [
        // Botón volver — solo cuando hay ruta anterior en el stack (mobile)
        if (ModalRoute.of(context)?.isFirst == false) ...[
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_ios_rounded, size: 18, color: _text),
            splashRadius: 18,
          ),
          const SizedBox(width: 4),
        ],
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text('Empleados', style: TextStyle(fontSize: 22,
              fontWeight: FontWeight.bold, color: _text),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(
            'Gestiona tu equipo${fmt.isNotEmpty ? ' · $fmt' : ''}',
            style: TextStyle(fontSize: 12, color: _sub2),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ])),
        const SizedBox(width: 4),
        // Mi portal (admin ve su propio portal)
        if (widget.sesion?.uid != null)
          Tooltip(
            message: 'Mi portal',
            child: IconButton(
              onPressed: () => _abrirPortalEmpleado(context,
                  widget.sesion!.uid, widget.sesion?.nombre ?? 'Mi portal'),
              icon: const Icon(Icons.person_pin_outlined, size: 20, color: _kBlue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        // Botón actualizar
        if (_cargando)
          const SizedBox(width: 32, height: 32,
              child: Center(child: SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _kBlue))))
        else
          Tooltip(
            message: 'Actualizar datos',
            child: IconButton(
              onPressed: () => _cargarTodo(forzarRed: true),
              icon: const Icon(Icons.refresh_rounded, size: 19, color: _kSub),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
        // Menú de exportación (CSV) condensado en un popup
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 19, color: _kSub),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onSelected: (v) {
            if (v == 'csv_dl') _descargarCSV(context);
            if (v == 'csv_share') _compartirCSV(context);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'csv_dl',    child: ListTile(leading: Icon(Icons.download_outlined), title: Text('Descargar CSV'), dense: true, contentPadding: EdgeInsets.zero)),
            PopupMenuItem(value: 'csv_share', child: ListTile(leading: Icon(Icons.share_outlined),   title: Text('Compartir CSV'), dense: true, contentPadding: EdgeInsets.zero)),
          ],
        ),
        if (_esPropietario) ...[
          Tooltip(
            message: 'Invitar empleado',
            child: IconButton(
              onPressed: _invitarEmpleado,
              icon: const Icon(Icons.mail_outline_rounded, size: 19, color: _kBlue),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ),
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: () => _abrirFormulario(),
            icon: const Icon(Icons.add_rounded, size: 15),
            label: const Text('Nuevo', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              backgroundColor: _kBlue,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ]),
    );
  }

  // ── KPI Cards ─────────────────────────────────────────────────────────────

  Widget _buildKpis() {
    final todos      = _empleados;
    final total      = todos.length;
    final activos    = todos.where((e) {
      final m = e.data() as Map;
      return m['activo'] == true && m['estado'] != 'baja';
    }).length;
    final vacaciones = todos.where((e) => (e.data() as Map)['estado'] == 'vacaciones').length;
    final bajas      = todos.where((e) => (e.data() as Map)['activo'] == false).length;
    final fichadosHoy = _fichajesHoy.length;

    const kpiW = 160.0;
    final kpis = [
      _kpiW(Icons.people_alt_outlined,   const Color(0xFFDCFCE7), _kGreen,
          'Total empleados', '$total', total > 0 ? '$activos activos' : '—'),
      _kpiW(Icons.check_circle_outline,  const Color(0xFFDBEAFE), _kBlue,
          'Activos', '$activos', '$activos de $total'),
      _kpiW(Icons.beach_access_outlined, const Color(0xFFFEF3C7), _kOrange,
          'Vacaciones', '$vacaciones',
          vacaciones == 0 ? 'Ninguno' : '$vacaciones empleado(s)'),
      _kpiW(Icons.fingerprint_rounded,   const Color(0xFFEDE9FE), const Color(0xFF7C3AED),
          'Fichados hoy', '$fichadosHoy',
          activos > 0 ? 'de $activos activos' : '—'),
      GestureDetector(
        onTap: () => EmpleadosBajaPopup.mostrar(context,
            empresaId: widget.empresaId),
        child: _kpiW(Icons.sick_outlined, const Color(0xFFFFE4E6), _kRed,
            'De baja', '$bajas', 'Ver detalle →', tappable: true),
      ),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: LayoutBuilder(builder: (_, constraints) {
        final totalW = kpiW * kpis.length + 10.0 * (kpis.length - 1);
        if (totalW <= constraints.maxWidth) {
          // Wide: Expanded igualados
          return Row(children: [
            for (int i = 0; i < kpis.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: kpis[i]),
            ],
          ]);
        }
        // Narrow: scroll horizontal con ancho fijo por tarjeta
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (int i = 0; i < kpis.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              SizedBox(width: kpiW, child: kpis[i]),
            ],
          ]),
        );
      }),
    );
  }

  // Layout vertical — funciona a cualquier ancho sin overflow
  Widget _kpiW(IconData icon, Color bgIcon, Color iconColor,
      String label, String valor, String sub, {bool tappable = false}) =>
      Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: tappable ? iconColor.withValues(alpha: 0.3) : _kBorder),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icono pequeño en la esquina superior
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: bgIcon, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 15),
            ),
            const SizedBox(height: 8),
            // Número grande
            Text(valor,
                style: const TextStyle(fontSize: 22,
                    fontWeight: FontWeight.bold, color: _kText),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            // Etiqueta
            Text(label,
                style: const TextStyle(fontSize: 10, color: _kSub),
                overflow: TextOverflow.ellipsis, maxLines: 1),
            const SizedBox(height: 1),
            // Sub texto
            Text(sub,
                style: TextStyle(fontSize: 9,
                    color: tappable ? iconColor : _kSub),
                overflow: TextOverflow.ellipsis, maxLines: 1),
          ],
        ),
      );

  // ── Grid de tarjetas: 6 por página (2 filas × 3), sin scroll ───────────

  Widget _buildGrid(List<QueryDocumentSnapshot> lista, BuildContext context) {
    if (lista.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.people_outline, size: 56, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text('Sin resultados', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
      ]));
    }

    const porPagina  = 6;
    final totalPaginas = (lista.length / porPagina).ceil();
    final paginaActual = _paginaGrid.clamp(0, totalPaginas - 1);
    final inicio = paginaActual * porPagina;
    final fin    = (inicio + porPagina).clamp(0, lista.length);
    final pagina = lista.sublist(inicio, fin);

    return LayoutBuilder(builder: (ctx, constraints) {
      const gap    = 12.0;
      const padH   = 16.0;
      const padV   = 10.0;
      const paginH = 48.0;

      final availW = constraints.maxWidth - padH * 2;
      // Columnas según ancho disponible
      final cols   = availW < 440 ? 1 : availW < 640 ? 2 : 3;

      // ── Mobile (1 col): ListView con altura natural, sin paginación ────────
      if (cols == 1) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(padH, padV, padH, padV),
          itemCount: lista.length,
          separatorBuilder: (_, __) => const SizedBox(height: gap),
          itemBuilder: (_, i) => _empCard(lista[i], context),
        );
      }

      // ── 2-3 columnas: GridView con ratio calculado ─────────────────────────
      final availH = constraints.maxHeight - padV * 2
          - (totalPaginas > 1 ? paginH : 0);
      final cardW  = (availW - gap * (cols - 1)) / cols;
      final cardH  = ((availH - gap) / 2).clamp(_esPropietario ? 250.0 : 200.0, 320.0);
      final ratio  = (cardW / cardH).clamp(0.5, 3.0);

      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(padH, padV, padH, 0),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: cols,
            childAspectRatio: ratio,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap,
            children: pagina.map((doc) => _empCard(doc, context)).toList(),
          ),
        ),
        if (totalPaginas > 1)
          SizedBox(
            height: paginH,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: paginaActual > 0
                    ? () => setState(() => _paginaGrid = paginaActual - 1)
                    : null,
                color: _kBlue,
              ),
              ...List.generate(totalPaginas, (i) => GestureDetector(
                onTap: () => setState(() => _paginaGrid = i),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: i == paginaActual ? _kBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: i == paginaActual ? _kBlue : _kBorder),
                  ),
                  child: Center(child: Text('${i + 1}',
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: i == paginaActual ? Colors.white : _kSub))),
                ),
              )),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: paginaActual < totalPaginas - 1
                    ? () => setState(() => _paginaGrid = paginaActual + 1)
                    : null,
                color: _kBlue,
              ),
            ]),
          ),
      ]);
    });
  }


  Widget _empCard(QueryDocumentSnapshot doc, BuildContext context) {
    final d       = doc.data() as Map<String, dynamic>;
    final activo  = d['activo'] as bool? ?? true;
    final nombre  = d['nombre'] as String? ?? 'Sin nombre';
    final puesto  = d['puesto'] as String? ?? '';
    final rol     = d['rol'] as String? ?? 'staff';
    final fotoUrl = d['foto_url'] as String?;
    final estado  = d['estado'] as String?;
    final dept    = d['departamento'] as String? ?? '';
    final ini     = _iniciales(nombre);
    final selec   = _seleccionado?.id == doc.id;

    // Vacaciones desde saldo real (vacaciones/{empresa}/saldos)
    final saldo         = _saldosVac[doc.id];
    final vacDevengados = saldo?['devengados'] ?? 0.0;
    final vacArrastre   = saldo?['arrastre']   ?? 0.0;
    final vacTotalesD   = vacDevengados + vacArrastre;
    final vacDisfD      = saldo?['disfrutados'] ?? 0.0;
    final vacDisfrutadas = vacDisfD.round();
    final vacTotales     = vacTotalesD.round();
    final vacPct         = vacTotalesD > 0
        ? (vacDisfD / vacTotalesD).clamp(0.0, 1.0) : 0.0;

    final estaEnVacaciones = estado == 'vacaciones';
    final badgeLabel = estaEnVacaciones ? 'En vacaciones' : activo ? 'En plantilla' : 'De baja';
    final badgeColor = estaEnVacaciones ? _kOrange : activo ? _kGreen : _kRed;
    final rolColor = rol == 'propietario' ? const Color(0xFF7B1FA2)
        : rol == 'admin' ? _kBlue : const Color(0xFF059669);

    return GestureDetector(
      onTap: () => setState(() => _seleccionado = selec ? null : doc),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selec ? _kBlue : _kBorder, width: selec ? 2 : 1),
          boxShadow: [BoxShadow(
            color: selec ? _kBlue.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.04),
            blurRadius: selec ? 12 : 6, offset: const Offset(0, 2),
          )],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(children: [

            // ── Cabecera: avatar izq + info dcha ──────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: badgeColor, width: 2.5),
                    boxShadow: [BoxShadow(color: badgeColor.withValues(alpha: 0.2),
                        blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: rolColor.withValues(alpha: 0.12),
                    backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                    child: fotoUrl == null
                        ? Text(ini, style: TextStyle(fontSize: 14,
                            fontWeight: FontWeight.bold, color: rolColor))
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(nombre,
                        style: const TextStyle(fontSize: 12.5,
                            fontWeight: FontWeight.bold, color: _kText),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(puesto.isNotEmpty ? puesto : _rolLabel(rol),
                        style: const TextStyle(fontSize: 10, color: _kSub),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Wrap(spacing: 4, runSpacing: 2, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
                        ),
                        child: Text('• $badgeLabel', style: TextStyle(fontSize: 8.5,
                            fontWeight: FontWeight.w700, color: badgeColor)),
                      ),
                      if (dept.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(dept, style: const TextStyle(fontSize: 8.5, color: _kSub),
                              overflow: TextOverflow.ellipsis),
                        ),
                    ]),
                  ],
                )),
              ]),
            ),

            // ── Barra de vacaciones ────────────────────────────────────────
            Container(
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _kBorder))),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.beach_access_outlined, size: 11, color: _kOrange),
                  const SizedBox(width: 5),
                  Text('Vacaciones', style: const TextStyle(fontSize: 10, color: _kSub)),
                  const Spacer(),
                  Text(
                    vacTotales > 0
                        ? '$vacDisfrutadas/$vacTotales días'
                        : vacDisfrutadas > 0
                            ? '$vacDisfrutadas días (sin límite)'
                            : '0 días disfrutados',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: vacTotales > 0 ? _kText : _kSub),
                  ),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: vacTotales > 0 ? vacPct.clamp(0.0, 1.0) : 0,
                    minHeight: 6,
                    backgroundColor: _kGreen.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(_kGreen),
                  ),
                ),
              ]),
            ),

            // ── Fichajes: datos del batch ya cargado ───────────────────────
            Builder(builder: (_) {
              final fi      = _fichajesHoy[doc.id];
              final entrada = fi?['entrada'] ?? '—';
              final ultimo  = fi?['ultimo']  ?? '—';
              final horas   = fi?['horas']   ?? '—';
              final enJornada = ultimo == 'En jornada';
              return Container(
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _kBorder))),
                child: Row(children: [
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
                    child: Row(children: [
                      Icon(Icons.login_outlined, size: 11, color: _kGreen),
                      const SizedBox(width: 5),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(entrada, style: const TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w700, color: _kText)),
                        const Text('Entrada hoy',
                            style: TextStyle(fontSize: 8.5, color: _kSub)),
                      ]),
                    ]),
                  )),
                  Container(width: 1, height: 32, color: _kBorder),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
                    child: Row(children: [
                      Icon(
                        enJornada ? Icons.circle : Icons.logout_outlined,
                        size: 11,
                        color: enJornada ? _kGreen : _kBlue,
                      ),
                      const SizedBox(width: 5),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(enJornada ? 'Trabajando' : ultimo,
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: enJornada ? _kGreen : _kText),
                            overflow: TextOverflow.ellipsis),
                        Text(enJornada ? 'En jornada' : horas,
                            style: const TextStyle(fontSize: 8.5, color: _kSub)),
                      ])),
                    ]),
                  )),
                ]),
              );
            }),

            // ── 4 botones de acción (solo propietario) ─────────────────────
            if (_esPropietario)
              Container(
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: _kBorder))),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _empBtn(Icons.edit_outlined,          'Editar',   _kBlue,
                      () => _abrirFormulario(id: doc.id, data: d)),
                  _empBtn(Icons.photo_camera_outlined,  'Foto',     _kSub,
                      () => _abrirFoto(doc.id, nombre)),
                  _empBtn(Icons.receipt_long_outlined,  'Nóminas',  _kGreen,
                      () => _abrirNominas(doc.id, nombre)),
                  _empBtn(Icons.gavel_outlined,         'Embargos', _kOrange,
                      () => _abrirEmbargos(doc.id, nombre)),
                  _empBtn(Icons.tune_rounded,           'Módulos',  const Color(0xFF7C3AED),
                      () => _abrirModulos(doc.id, nombre)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _empBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 9, color: _kSub)),
        ]),
      );

  String _rolLabel(String rol) => switch (rol) {
    'propietario' => 'Propietario',
    'admin'       => 'Admin',
    _             => 'Staff',
  };

  String _iniciales(String nombre) {
    final p = nombre.trim().split(' ');
    if (p.length >= 2 && p[0].isNotEmpty && p[1].isNotEmpty) {
      return '${p[0][0]}${p[1][0]}'.toUpperCase();
    }
    return nombre.isNotEmpty ? nombre[0].toUpperCase() : 'E';
  }

  // ── Panel de detalle (derecha) ────────────────────────────────────────────

  Widget _buildDetailPanel(BuildContext context) {
    if (_seleccionado == null) {
      return Container(
        width: 280,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: _kBorder)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.person_search_outlined, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('Selecciona un empleado\npara ver sus detalles',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _kSub)),
        ]),
      );
    }

    final doc    = _seleccionado!;
    final d      = doc.data() as Map<String, dynamic>;
    final id     = doc.id;
    final activo = d['activo'] as bool? ?? true;
    final nombre = d['nombre'] as String? ?? 'Sin nombre';
    final correo = d['correo'] as String? ?? '';
    final puesto = d['puesto'] as String? ?? '';
    final rol    = d['rol'] as String? ?? 'staff';
    final fotoUrl = d['foto_url'] as String?;
    final estado  = d['estado'] as String?;
    final dept    = d['departamento'] as String? ?? '';
    final _rawFechaC = d['fecha_creacion'];
    final fechaC = _rawFechaC is Timestamp
        ? _rawFechaC.toDate().toIso8601String()
        : (_rawFechaC as String? ?? '');
    final ini     = _iniciales(nombre);

    final rolColor = rol == 'propietario' ? const Color(0xFF7B1FA2)
        : rol == 'admin' ? _kBlue : const Color(0xFF00796B);

    final (badgeLabel, badgeColor) = estado == 'vacaciones'
        ? ('En vacaciones', _kOrange)
        : activo ? ('Activo', _kGreen) : ('De baja', _kRed);

    DateTime? fechaDt;
    if (fechaC.isNotEmpty) fechaDt = DateTime.tryParse(fechaC);

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: _kBorder)),
      ),
      child: Column(children: [
        // Header del panel
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kBorder))),
          child: Row(children: [
            const Text('Perfil del empleado',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: _kText)),
            const Spacer(),
            InkWell(
              onTap: () => setState(() => _seleccionado = null),
              borderRadius: BorderRadius.circular(4),
              child: const Icon(Icons.close, size: 16, color: _kSub),
            ),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(children: [
              // Avatar + nombre + rol
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Stack(alignment: Alignment.bottomRight, children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: rolColor.withValues(alpha: 0.12),
                      backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                      child: fotoUrl == null
                          ? Text(ini, style: TextStyle(fontSize: 22,
                              fontWeight: FontWeight.bold, color: rolColor))
                          : null,
                    ),
                    Container(width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: activo && estado != 'vacaciones' ? _kGreen : _kOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      )),
                  ]),
                  const SizedBox(height: 10),
                  Text(nombre, style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold, color: _kText),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 2),
                  Text(puesto.isNotEmpty ? puesto : _rolLabel(rol),
                      style: const TextStyle(fontSize: 12, color: _kSub)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badgeLabel, style: TextStyle(fontSize: 11,
                        fontWeight: FontWeight.w600, color: badgeColor)),
                  ),
                ]),
              ),

              // ── Portal del empleado (admin) ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: GestureDetector(
                  onTap: () => _abrirPortalEmpleado(context, id, nombre),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(children: [
                      Icon(Icons.person_pin_outlined, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Portal del empleado',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        Text('Ver horario, nóminas, IT y vacaciones',
                            style: TextStyle(fontSize: 10, color: Colors.white70)),
                      ])),
                      Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 12),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Botones de acción — 2 filas (3 + 2)
              if (_esPropietario) Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _actionBtn(Icons.edit_outlined, 'Editar', _kBlue,
                        () => _abrirFormulario(id: id, data: d)),
                    _actionBtn(Icons.photo_camera_outlined, 'Foto', _kSub,
                        () => _abrirFoto(id, nombre)),
                    _actionBtn(Icons.receipt_long_outlined, 'Nóminas', _kGreen,
                        () => _abrirNominas(id, nombre)),
                  ]),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _actionBtn(Icons.chat_bubble_outline_rounded, 'Mensaje',
                        const Color(0xFF3B82F6),
                        () => _abrirCanalComunicacion(id, nombre)),
                    _actionBtn(Icons.gavel_outlined, 'Embargos', _kOrange,
                        () => _abrirEmbargos(id, nombre)),
                    _actionBtn(
                      activo ? Icons.person_off_outlined : Icons.person_add_outlined,
                      activo ? 'Desactivar' : 'Activar',
                      activo ? _kRed : _kGreen,
                      () => _toggleActivo(id, activo),
                    ),
                  ]),
                ]),
              ),

              const Divider(height: 1, color: _kBorder),

              // Info rows
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _infoRow(Icons.badge_outlined, 'Rol', _rolLabel(rol)),
                  if (correo.isNotEmpty)
                    _infoRow(Icons.email_outlined, 'Email', correo),
                  if (dept.isNotEmpty)
                    _infoRow(Icons.business_outlined, 'Departamento', dept),
                  if (fechaDt != null)
                    _infoRow(Icons.calendar_today_outlined, 'Fecha ingreso',
                        '${fechaDt.day.toString().padLeft(2,'0')}/'
                        '${fechaDt.month.toString().padLeft(2,'0')}/'
                        '${fechaDt.year}'),
                  _infoRow(Icons.lock_outline, 'Acceso',
                      activo ? 'Activo' : 'Sin acceso'),
                ]),
              ),

              const Divider(height: 1, color: _kBorder),

              // Navegación a módulos
              ..._navItems(context, id, d),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 9.5, color: _kSub)),
        ]),
      );

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, size: 15, color: _kSub),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _kSub)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
            color: _kText), overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );

  List<Widget> _navItems(BuildContext context, String id, Map<String, dynamic> d) {
    final svc = SuscripcionService();
    final tieneNominas    = svc.tieneModulo('nominas') || svc.tieneModulo('gestion');
    final tieneFichaje    = svc.tieneModulo('fichaje');
    final tieneVacaciones = svc.tieneModulo('vacaciones') || tieneFichaje;

    final items = <(IconData, String, Color, VoidCallback)>[
      if (tieneNominas)
        (Icons.receipt_long_outlined, 'Nóminas del empleado', _kGreen,
            () => _abrirNominas(id, d['nombre'] as String? ?? '')),
      if (tieneNominas)
        (Icons.tune_rounded, 'Datos salariales', const Color(0xFF059669),
            () => _abrirFormularioNomina(id, d)),
      if (tieneVacaciones)
        (Icons.beach_access_outlined, 'Vacaciones y ausencias', _kOrange,
            () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => VacacionesScreen(
                    empresaId: widget.empresaId, sesion: widget.sesion)))),
      (Icons.folder_outlined, 'Documentos', _kBlue,
          () => _abrirDocumentos(id, d['nombre'] as String? ?? '')),
      (Icons.gavel_outlined, 'Embargos', _kRed,
          () => _abrirEmbargos(id, d['nombre'] as String? ?? '')),
      if (tieneFichaje)
        (Icons.fingerprint_rounded, 'Fichajes y jornadas', _kSub,
            () => _mostrarResumenFichajes(id, d['nombre'] as String? ?? '')),
      if (_esPropietario)
        (Icons.tune_rounded, 'Configurar módulos', const Color(0xFF7C3AED),
            () => _abrirModulos(id, d['nombre'] as String? ?? '')),
    ];

    return items.map((item) => InkWell(
      onTap: item.$4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _kBorder))),
        child: Row(children: [
          Container(width: 30, height: 30,
            decoration: BoxDecoration(
              color: item.$3.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.$1, size: 15, color: item.$3)),
          const SizedBox(width: 10),
          Expanded(child: Text(item.$2,
              style: const TextStyle(fontSize: 12, color: _kText))),
          const Icon(Icons.chevron_right, size: 16, color: _kSub),
        ]),
      ),
    )).toList();
  }

  // ── Widgets auxiliares ────────────────────────────────────────────────────

  Widget _buildVacio() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.group_add, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text('No hay empleados registrados',
          style: TextStyle(fontSize: 16, color: Colors.grey[500])),
      const SizedBox(height: 8),
      Text(_esPropietario
          ? 'Pulsa "+ Nuevo empleado" para añadir el primero'
          : 'Solo el administrador puede añadir empleados',
          style: TextStyle(color: Colors.grey[400], fontSize: 13)),
    ],
  ));

  Widget _buildError(Object? error) {
    final esPermiso = error.toString().contains('permission-denied') ||
        error.toString().contains('PERMISSION_DENIED');
    return Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(esPermiso ? Icons.lock_clock : Icons.error_outline,
            size: 56, color: Colors.orange),
        const SizedBox(height: 16),
        Text(esPermiso
            ? 'Token expirado. Pulsa "Actualizar" para reconectarte.'
            : 'Error: $error',
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _cargarTodo(forzarRed: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar sesión'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _kBlue, foregroundColor: Colors.white),
        ),
      ]),
    ));
  }

  // ── Export CSV ────────────────────────────────────────────────────────────

  bool get _puedeExportar => _esPropietario ||
      (widget.sesion?.rol == 'admin') ||
      (PermisosService().sesion?.rol == 'admin');

  Future<List<List<dynamic>>?> _construirFilasCSV(BuildContext context) async {
    if (!_puedeExportar) {
      FluxToast.error(context, 'Solo el propietario o administrador pueden exportar.');
      return null;
    }
    try {
      final snap = await _firestore
          .collection('usuarios')
          .where('empresa_id', isEqualTo: widget.empresaId)
          .get();

      final rows = <List<dynamic>>[
        ['Nombre', 'Correo', 'Puesto', 'Departamento', 'Rol',
         'Estado', 'Activo', 'Vacaciones disfrutadas', 'Vacaciones totales'],
      ];
      for (final doc in snap.docs) {
        final d = doc.data();
        rows.add([
          d['nombre'] ?? '',
          d['correo'] ?? '',
          d['puesto'] ?? '',
          d['departamento'] ?? '',
          d['rol'] ?? '',
          d['estado'] ?? 'activo',
          d['activo'] == true ? 'Sí' : 'No',
          (_saldosVac[doc.id]?['disfrutados'] ?? 0).toStringAsFixed(1),
          (_saldosVac[doc.id]?['devengados'] ?? 0).toStringAsFixed(1),
        ]);
      }
      return rows;
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error generando CSV: $e');
      return null;
    }
  }

  Future<File?> _generarArchivoCSV(
      List<List<dynamic>> rows, Directory dir) async {
    final csv  = const ListToCsvConverter().convert(rows);
    final file = File('${dir.path}/empleados_export.csv');
    await file.writeAsString(csv);
    return file;
  }

  Future<void> _descargarCSV(BuildContext context) async {
    final rows = await _construirFilasCSV(context);
    if (rows == null || !mounted) return;
    try {
      // Downloads o Documentos según plataforma
      final dir = (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
          ? await getApplicationDocumentsDirectory()
          : await getApplicationDocumentsDirectory();
      final file = await _generarArchivoCSV(rows, dir);
      if (file == null || !mounted) return;
      FluxToast.exito(context, 'CSV guardado en: ${file.path}',
          title: 'Descargado');
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al descargar: $e');
    }
  }

  Future<void> _compartirCSV(BuildContext context) async {
    final rows = await _construirFilasCSV(context);
    if (rows == null || !mounted) return;
    try {
      final dir  = await getTemporaryDirectory();
      final file = await _generarArchivoCSV(rows, dir);
      if (file == null) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Empleados — ${widget.empresaId}',
      );
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al compartir: $e');
    }
  }

  // ── Acciones ──────────────────────────────────────────────────────────────

  Future<void> _toggleActivo(String id, bool actual) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(actual ? 'Desactivar empleado' : 'Activar empleado'),
        content: Text(actual
            ? '¿Desactivar? El empleado perderá acceso a la app.'
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
      if (!actual) {
        FluxToast.exito(context, 'Empleado activado correctamente');
      } else {
        FluxToast.aviso(context, 'Empleado desactivado. Ha perdido el acceso.');
      }
      setState(() => _seleccionado = null);
    }
  }

  Future<void> _abrirFormulario({String? id, Map<String, dynamic>? data}) async {
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FormularioEmpleado(
          empresaId: widget.empresaId, id: id, data: data),
    );
    if (mounted) _cargarTodo(silencioso: true);
  }

  Future<void> _invitarEmpleado() async {
    final emailCtrl  = TextEditingController();
    final nombreCtrl = TextEditingController();
    String rolSel    = 'staff';

    final resultado = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Header ────────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                decoration: const BoxDecoration(
                  color: _kBlue,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Crear acceso para empleado',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      Text('Se enviará el acceso por email',
                          style: TextStyle(fontSize: 11, color: Colors.white70)),
                    ]),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                  ),
                ]),
              ),
              // ── Body ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBlue.withValues(alpha: 0.2)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded, size: 15, color: _kBlue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Se creará la cuenta y se enviará el acceso por email. '
                          'Verás la contraseña temporal al confirmar.',
                          style: TextStyle(fontSize: 12, color: _kBlue),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const Text('Nombre del empleado',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nombreCtrl,
                    autofocus: true,
                    style: const TextStyle(fontSize: 14, color: _kText),
                    decoration: InputDecoration(
                      hintText: 'Nombre Apellido',
                      hintStyle: const TextStyle(color: _kSub, fontSize: 13),
                      prefixIcon: const Icon(Icons.person_outline, size: 18, color: _kSub),
                      filled: true, fillColor: _kBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBlue, width: 2)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Email del empleado',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(fontSize: 14, color: _kText),
                    decoration: InputDecoration(
                      hintText: 'nombre@empresa.com',
                      hintStyle: const TextStyle(color: _kSub, fontSize: 13),
                      prefixIcon: const Icon(Icons.email_outlined, size: 18, color: _kSub),
                      filled: true, fillColor: _kBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kBlue, width: 2)),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text('Rol asignado',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _kText)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _rolChip('staff', 'Staff / Empleado',
                        Icons.person_outline, rolSel,
                        (v) => setModal(() => rolSel = v))),
                    const SizedBox(width: 10),
                    Expanded(child: _rolChip('admin', 'Administrador',
                        Icons.admin_panel_settings_outlined, rolSel,
                        (v) => setModal(() => rolSel = v))),
                  ]),
                ]),
              ),
              // ── Footer ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kSub,
                        side: const BorderSide(color: _kBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        final email  = emailCtrl.text.trim();
                        final nombre = nombreCtrl.text.trim();
                        if (nombre.isEmpty) {
                          FluxToast.aviso(ctx, 'Introduce el nombre del empleado');
                          return;
                        }
                        if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
                          FluxToast.aviso(ctx, 'Introduce un email válido');
                          return;
                        }
                        Navigator.pop(ctx, {'email': email, 'nombre': nombre, 'rol': rolSel});
                      },
                      icon: const Icon(Icons.person_add_rounded, size: 15),
                      label: const Text('Crear acceso'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );

    emailCtrl.dispose();
    nombreCtrl.dispose();
    if (resultado == null || !mounted) return;

    // Mostrar spinner mientras se crea
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final email    = resultado['email']!;
      final nombre   = resultado['nombre']!;
      final rol      = resultado['rol'] ?? 'staff';
      final password = _generarPassword();

      // Crear cuenta con Firebase app temporal para no cerrar sesión del admin
      String nuevoUid;
      FirebaseApp? tempApp;
      try {
        tempApp = await Firebase.initializeApp(
            name: 'inv_${DateTime.now().millisecondsSinceEpoch}',
            options: Firebase.app().options);
        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        final cred = await tempAuth.createUserWithEmailAndPassword(
            email: email, password: password);
        nuevoUid = cred.user!.uid;
        await tempAuth.signOut();
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          Navigator.pop(context);
          final msg = e.code == 'email-already-in-use'
              ? 'Ya existe un usuario con ese email'
              : (e.message ?? 'Error al crear la cuenta');
          FluxToast.error(context, msg);
        }
        return;
      } finally {
        try { await tempApp?.delete(); } catch (_) {}
      }

      await _firestore.collection('usuarios').doc(nuevoUid).set({
        'nombre':        nombre,
        'correo':        email,
        'empresa_id':    widget.empresaId,
        'rol':           rol,
        'activo':        true,
        'fecha_creacion': Timestamp.now(),
        'permisos':      [],
        'primera_vez':   true,
      });

      // Enviar email de bienvenida con link para establecer contraseña
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      } catch (_) {} // No crítico — el admin tiene la contraseña en el diálogo

      if (!mounted) return;
      Navigator.pop(context); // cerrar spinner

      final tempPass = password;

      // Mostrar contraseña temporal al admin
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 22),
            SizedBox(width: 8),
            Text('Acceso creado', style: TextStyle(fontSize: 17)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Se ha enviado un email al empleado para que establezca su contraseña. Anota también la contraseña temporal por si no llega el email:',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF0EA5E9)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Email: ${resultado['email']}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
                const SizedBox(height: 6),
                Text('Contraseña: $tempPass',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                        color: Color(0xFF0369A1), letterSpacing: 2)),
              ]),
            ),
            const SizedBox(height: 10),
            const Text('El empleado deberá cambiarla en su primer inicio de sesión.',
                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          ]),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1976D2)),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      // Recargar lista de empleados
      if (mounted) _cargarTodo(silencioso: true);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // cerrar spinner
        FluxToast.error(context, 'Error inesperado: $e');
      }
    }
  }

  Widget _rolChip(String valor, String label, IconData icon,
      String seleccionado, ValueChanged<String> onTap) {
    final sel = seleccionado == valor;
    return GestureDetector(
      onTap: () => onTap(valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: sel ? _kBlue.withValues(alpha: 0.08) : _kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: sel ? _kBlue : _kBorder, width: sel ? 2 : 1),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: sel ? _kBlue : _kSub),
          const SizedBox(width: 6),
          Flexible(child: Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: sel ? _kBlue : _kSub),
              overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  void _mostrarResumenFichajes(String empleadoId, String nombre) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _FichajesResumenSheet(
        empresaId: widget.empresaId,
        empleadoId: empleadoId,
        nombre: nombre,
        fichajeHoy: _fichajesHoy[empleadoId],
        onVerTodos: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => GestionFichajesScreen(
                  empresaId: widget.empresaId, esAdmin: _esPropietario)));
        },
      ),
    );
  }

  // ── Portal del empleado — header para staff ──────────────────────────────

  Widget _buildPortalStaffHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        const Icon(Icons.person_pin_outlined, color: Colors.white, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Mi portal', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(widget.sesion?.nombre ?? 'Empleado',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ])),
        if (_cargando)
          const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2)),
      ]),
    );
  }

  // ── Abrir portal del empleado (admin viendo uno concreto) ─────────────────

  void _abrirCanalComunicacion(String empleadoUid, String nombre) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          CanalComunicacionWidget(
            empresaId: widget.empresaId,
            empleadoUid: empleadoUid,
            empleadoNombre: nombre,
            modoAdmin: true,
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  void _abrirPortalEmpleado(BuildContext context, String uid, String nombre) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: _bg,
        appBar: FluixAppBar(
          titulo: 'Portal · $nombre',
          titleNavigatesBack: true,
        ),
        body: ColoredBox(
          color: _bg,
          child: PortalEmpleadoScreen(
            empresaId: widget.empresaId,
            empleadoUid: uid,
            modoAdmin: true,
            isDark: _isDark,
          ),
        ),
      ),
    ));
  }

  void _abrirModulos(String empleadoId, String nombre) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => _ModulosEmpleadoSheet(
        empresaId: widget.empresaId,
        empleadoUid: empleadoId,
        empleadoNombre: nombre,
      ),
    );
  }

  void _abrirNominas(String empleadoId, String nombre) {
    NominasEmpleadoWidget.mostrar(
      context,
      empleadoId:     empleadoId,
      empresaId:      widget.empresaId,
      nombreEmpleado: nombre,
    );
  }

  void _abrirFoto(String empleadoId, String nombre) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SelectorFotoEmpleado(
          empresaId: widget.empresaId, empleadoId: empleadoId, nombreEmpleado: nombre),
    );
  }

  void _abrirDocumentos(String empleadoId, String nombre) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) => DocumentosEmpleadoWidget(
          empleadoId: empleadoId,
          empresaId: widget.empresaId,
          nombreEmpleado: nombre,
        ),
      ),
    );
  }

  void _abrirEmbargos(String empleadoId, String nombre) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent, useSafeArea: true,
      builder: (_) => SeccionEmbargos(empleadoId: empleadoId, nombreEmpleado: nombre),
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
    } else if (sector == 'veterinarios' || sector == 'veterinaria') {
      categorias = await _convenioService.obtenerCategorias('veterinarios-guadalajara-2026');
    } else if (sector == 'construccion' || sector == 'obras_publicas') {
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
      if (esCuenca || sector == 'comercio_cuenca') _convenioService.seedConvenioComercioCuenca,
      if (esConstruccion && esCuenca) _convenioService.seedConvenioConstruccionCuenca,
    ];
    for (final seed in seeds) {
      try { await seed(); } catch (e) { debugPrint('⚠️ seed: $e'); }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom sheet: configurar módulos del empleado
// ═══════════════════════════════════════════════════════════════════════════

class _ModulosEmpleadoSheet extends StatefulWidget {
  final String empresaId;
  final String empleadoUid;
  final String empleadoNombre;

  const _ModulosEmpleadoSheet({
    required this.empresaId,
    required this.empleadoUid,
    required this.empleadoNombre,
  });

  @override
  State<_ModulosEmpleadoSheet> createState() => _ModulosEmpleadoSheetState();
}

class _ModulosEmpleadoSheetState extends State<_ModulosEmpleadoSheet> {
  final _db = FirebaseFirestore.instance;

  bool _cargando  = true;
  bool _guardando = false;
  String _rol     = 'staff';
  List<String> _modulosSeleccionados = [];
  bool _usarPersonalizados = false;
  List<String> _modulosEmpresa = [];

  static const _kPurple = Color(0xFF7C3AED);

  static const _modulosInfo = <String, ({IconData icono, String nombre})>{
    'dashboard':    (icono: Icons.dashboard,            nombre: 'Dashboard'),
    'reservas':     (icono: Icons.calendar_today,       nombre: 'Reservas'),
    'citas':        (icono: Icons.event,                nombre: 'Citas'),
    'clientes':     (icono: Icons.people,               nombre: 'Clientes'),
    'valoraciones': (icono: Icons.star,                 nombre: 'Valoraciones'),
    'estadisticas': (icono: Icons.bar_chart,            nombre: 'Estadísticas'),
    'servicios':    (icono: Icons.spa,                  nombre: 'Servicios'),
    'pedidos':      (icono: Icons.shopping_cart,        nombre: 'Pedidos'),
    'whatsapp':     (icono: Icons.chat,                 nombre: 'WhatsApp Bot'),
    'tareas':       (icono: Icons.task_alt,             nombre: 'Tareas'),
    'empleados':    (icono: Icons.badge,                nombre: 'Empleados'),
    'facturacion':  (icono: Icons.receipt_long,         nombre: 'Facturación'),
    'nominas':      (icono: Icons.payments,             nombre: 'Nóminas'),
    'web':          (icono: Icons.web,                  nombre: 'Contenido Web'),
    'app':          (icono: Icons.phone_android,        nombre: 'Mi App'),
    'tpv':          (icono: Icons.point_of_sale,        nombre: 'TPV / Cobros'),
    'fichaje':      (icono: Icons.access_time,          nombre: 'Fichaje'),
    'vacaciones':   (icono: Icons.beach_access,         nombre: 'Vacaciones'),
    'fiscal':       (icono: Icons.account_balance,      nombre: 'Fiscal AI'),
  };

  static const _modulosAutoConFacturacion = [
    'contabilidad', 'plantillas_pdf', 'verifactu',
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final modulosEmpresaSnap = await WidgetManagerService()
          .obtenerModulosActivos(widget.empresaId)
          .first;
      final modulosEnPlan = SuscripcionService().getModulosActivos();
      const activosPorDefecto = {
        'dashboard', 'reservas', 'citas', 'clientes', 'valoraciones',
        'fichaje', 'empleados',
      };
      final activos = modulosEmpresaSnap
          .where((m) => m.activo)
          .map((m) => m.id)
          .where((id) => !const {'propietario', 'explorar', 'citas_del_dia'}.contains(id))
          .where((id) => activosPorDefecto.contains(id) || modulosEnPlan.contains(id)
              || (id == 'web' && modulosEnPlan.contains('contenido_web')))
          .toList();

      final doc = await _db.collection('usuarios').doc(widget.empleadoUid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _rol = data['rol'] as String? ?? 'staff';
        final guardados = (data['modulos_permitidos'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .where((id) => activos.contains(id))
            .toList();
        if (guardados != null && guardados.isNotEmpty) {
          _usarPersonalizados = true;
          _modulosSeleccionados = guardados;
        } else {
          _usarPersonalizados = false;
          _modulosSeleccionados = _defaultsRol(_rol)
              .where((id) => activos.contains(id))
              .toList();
        }
      }
      setState(() => _modulosEmpresa = activos);
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al cargar módulos: $e');
    }
    if (mounted) setState(() => _cargando = false);
  }

  List<String> _defaultsRol(String rol) => switch (rol) {
    'propietario' => List.from(_modulosEmpresa),
    'admin'       => [
      'dashboard', 'reservas', 'citas', 'clientes', 'valoraciones',
      'estadisticas', 'servicios', 'pedidos', 'whatsapp', 'tareas', 'nominas',
    ],
    'staff'       => ['reservas', 'citas', 'clientes', 'valoraciones'],
    _             => ['reservas', 'citas'],
  };

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      if (_usarPersonalizados) {
        final modulos = List<String>.from(_modulosSeleccionados);
        if (modulos.contains('facturacion')) {
          for (final auto in _modulosAutoConFacturacion) {
            if (!modulos.contains(auto)) modulos.add(auto);
          }
        }
        await _db.collection('usuarios').doc(widget.empleadoUid).update({
          'modulos_permitidos': modulos,
        });
      } else {
        await _db.collection('usuarios').doc(widget.empleadoUid).update({
          'modulos_permitidos': FieldValue.delete(),
        });
      }
      if (mounted) {
        FluxToast.exito(context, 'Módulos actualizados correctamente');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error al guardar: $e');
    }
    if (mounted) setState(() => _guardando = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: _kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.tune_rounded, size: 18, color: _kPurple),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Módulos — ${widget.empleadoNombre}',
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold, color: _kText),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text('Rol: $_rol',
                      style: const TextStyle(fontSize: 11, color: _kSub)),
                ],
              )),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 18, color: _kSub),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ]),
          ),
          const Divider(height: 1, color: _kBorder),

          if (_cargando)
            const Expanded(
                child: Center(child: CircularProgressIndicator(color: _kBlue)))
          else
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // ── Toggle personalizado ────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kBorder),
                    ),
                    child: SwitchListTile(
                      title: const Text('Módulos personalizados',
                          style: TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600, color: _kText)),
                      subtitle: Text(
                        _usarPersonalizados
                            ? 'Módulos configurados manualmente'
                            : 'Por defecto del rol ($_rol)',
                        style: const TextStyle(fontSize: 11, color: _kSub),
                      ),
                      value: _usarPersonalizados,
                      activeTrackColor: _kPurple.withValues(alpha: 0.5),
                      thumbColor: WidgetStatePropertyAll(
                          _usarPersonalizados ? _kPurple : Colors.grey),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      onChanged: (v) => setState(() {
                        _usarPersonalizados = v;
                        if (!v) _modulosSeleccionados = _defaultsRol(_rol);
                      }),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Info si no es personalizado ─────────────────────────
                  if (!_usarPersonalizados)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _kBlue.withValues(alpha: 0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 15, color: _kBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'El empleado verá los módulos por defecto '
                            'de su rol ($_rol). Activa "Módulos personalizados" '
                            'para elegir manualmente.',
                            style: const TextStyle(fontSize: 12, color: _kBlue),
                          ),
                        ),
                      ]),
                    ),

                  // ── Botones rápidos + lista ─────────────────────────────
                  if (_usarPersonalizados) ...[
                    Row(children: [
                      _quickBtn(Icons.select_all, 'Todos',
                          () => setState(() => _modulosSeleccionados =
                              List.from(_modulosEmpresa))),
                      const SizedBox(width: 8),
                      _quickBtn(Icons.deselect, 'Ninguno',
                          () => setState(() => _modulosSeleccionados = [])),
                      const SizedBox(width: 8),
                      _quickBtn(Icons.restart_alt, 'Reset',
                          () => setState(() =>
                              _modulosSeleccionados = _defaultsRol(_rol))),
                    ]),
                    const SizedBox(height: 8),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _kBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: _modulosEmpresa.asMap().entries.map((entry) {
                          final i    = entry.key;
                          final id   = entry.value;
                          final info = _modulosInfo[id];
                          final sel  = _modulosSeleccionados.contains(id);
                          return Container(
                            decoration: BoxDecoration(
                              border: i < _modulosEmpresa.length - 1
                                  ? const Border(
                                      bottom: BorderSide(color: _kBorder))
                                  : null,
                            ),
                            child: CheckboxListTile(
                              value: sel,
                              activeColor: _kPurple,
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 2),
                              title: Row(children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? _kPurple.withValues(alpha: 0.1)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    info?.icono ?? Icons.extension,
                                    size: 15,
                                    color: sel ? _kPurple : _kSub,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  info?.nombre ?? id,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: sel ? _kText : _kSub,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ]),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _modulosSeleccionados.add(id);
                                } else {
                                  _modulosSeleccionados.remove(id);
                                }
                              }),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Botón guardar ───────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _guardando ? null : _guardar,
                      icon: _guardando
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.save_rounded, size: 17),
                      label: Text(
                        _guardando ? 'Guardando…' : 'Guardar módulos',
                        style: const TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPurple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ]),
      ),
    );
  }

  Widget _quickBtn(IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _kBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: _kSub),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(fontSize: 11, color: _kSub,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Bottom sheet: resumen de fichajes del empleado (últimos 7 días)
// ═══════════════════════════════════════════════════════════════════════════

class _FichajesResumenSheet extends StatefulWidget {
  final String empresaId;
  final String empleadoId;
  final String nombre;
  final Map<String, String>? fichajeHoy;
  final VoidCallback onVerTodos;

  const _FichajesResumenSheet({
    required this.empresaId,
    required this.empleadoId,
    required this.nombre,
    required this.fichajeHoy,
    required this.onVerTodos,
  });

  @override
  State<_FichajesResumenSheet> createState() => _FichajesResumenSheetState();
}

class _FichajesResumenSheetState extends State<_FichajesResumenSheet> {
  List<Map<String, dynamic>> _registros = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final now = DateTime.now();
    final hace7 = now.subtract(const Duration(days: 6));
    final fechaInicio = '${hace7.year}-${hace7.month.toString().padLeft(2,'0')}'
        '-${hace7.day.toString().padLeft(2,'0')}';

    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('fichajes')
          .where('empleado_id', isEqualTo: widget.empleadoId)
          .where('fecha', isGreaterThanOrEqualTo: fechaInicio)
          .orderBy('fecha', descending: true)
          .get()
          .timeout(const Duration(seconds: 8));

      final registros = snap.docs.map((doc) {
        final d = doc.data();
        final tsE = d['entrada'] as Timestamp?;
        final tsS = d['salida']  as Timestamp?;
        final fecha = d['fecha'] as String? ?? '';

        String entradaStr = '—';
        String salidaStr  = '—';
        String horasStr   = '—';

        if (tsE != null) {
          final dtE = tsE.toDate().toLocal();
          entradaStr = '${dtE.hour.toString().padLeft(2,'0')}:'
              '${dtE.minute.toString().padLeft(2,'0')}';
          if (tsS != null) {
            final dtS = tsS.toDate().toLocal();
            salidaStr = '${dtS.hour.toString().padLeft(2,'0')}:'
                '${dtS.minute.toString().padLeft(2,'0')}';
            final mins = dtS.difference(dtE).inMinutes;
            horasStr = '${mins ~/ 60}h ${mins % 60}m';
          } else {
            salidaStr = 'En jornada';
          }
        }

        // Formatear fecha dd/mm
        String fechaDisplay = fecha;
        if (fecha.length == 10) {
          final parts = fecha.split('-');
          if (parts.length == 3) fechaDisplay = '${parts[2]}/${parts[1]}';
        }

        return {
          'fecha': fechaDisplay,
          'fechaRaw': fecha,
          'entrada': entradaStr,
          'salida': salidaStr,
          'horas': horasStr,
          'activo': tsS == null && tsE != null,
        };
      }).toList();

      if (mounted) setState(() { _registros = registros; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fi = widget.fichajeHoy;
    final hayFichajeHoy = fi != null;
    final enJornada = fi?['ultimo'] == 'En jornada';

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: _kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _kSub.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fingerprint_rounded, size: 18, color: _kSub),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Fichajes — ${widget.nombre}',
                    style: const TextStyle(fontSize: 14,
                        fontWeight: FontWeight.bold, color: _kText),
                    overflow: TextOverflow.ellipsis),
                const Text('Últimos 7 días',
                    style: TextStyle(fontSize: 11, color: _kSub)),
              ])),
              TextButton(
                onPressed: widget.onVerTodos,
                child: const Text('Ver todos →',
                    style: TextStyle(fontSize: 12, color: _kBlue)),
              ),
            ]),
          ),
          // Resumen de hoy
          if (hayFichajeHoy) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: enJornada
                    ? _kGreen.withValues(alpha: 0.08)
                    : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: enJornada
                      ? _kGreen.withValues(alpha: 0.3)
                      : _kBlue.withValues(alpha: 0.2),
                ),
              ),
              child: Row(children: [
                Icon(
                  enJornada ? Icons.radio_button_checked : Icons.check_circle_outline,
                  color: enJornada ? _kGreen : _kBlue, size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(enJornada ? 'Actualmente en jornada' : 'Jornada completada hoy',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: enJornada ? _kGreen : _kBlue)),
                  const SizedBox(height: 2),
                  Text(
                    'Entrada: ${fi!['entrada'] ?? '—'}'
                    '${enJornada ? '' : '  ·  Salida: ${fi['ultimo']}'}'
                    '${!enJornada && (fi['horas'] ?? '—') != '—' ? '  ·  ${fi['horas']}' : ''}',
                    style: const TextStyle(fontSize: 11, color: _kSub),
                  ),
                ])),
              ]),
            ),
            const Divider(height: 1, color: _kBorder, indent: 16, endIndent: 16),
          ],
          // Lista 7 días
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(color: _kBlue))
                : _registros.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.fingerprint_rounded, size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        const Text('Sin fichajes en los últimos 7 días',
                            style: TextStyle(color: _kSub, fontSize: 13)),
                      ]))
                    : ListView.separated(
                        controller: ctrl,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _registros.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: _kBorder),
                        itemBuilder: (_, i) {
                          final r = _registros[i];
                          final activo = r['activo'] as bool;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(children: [
                              // Fecha
                              SizedBox(
                                width: 44,
                                child: Column(children: [
                                  Text(r['fecha'] as String,
                                      style: const TextStyle(fontSize: 13,
                                          fontWeight: FontWeight.w700, color: _kText)),
                                ]),
                              ),
                              const SizedBox(width: 12),
                              // Entrada
                              _fichaCol(Icons.login_outlined, _kGreen,
                                  r['entrada'] as String, 'Entrada'),
                              const SizedBox(width: 12),
                              // Salida
                              _fichaCol(
                                activo ? Icons.circle : Icons.logout_outlined,
                                activo ? _kGreen : _kSub,
                                activo ? 'En jornada' : r['salida'] as String,
                                activo ? '' : 'Salida',
                              ),
                              const Spacer(),
                              // Horas
                              if (!activo && r['horas'] != '—')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(r['horas'] as String,
                                      style: const TextStyle(fontSize: 11,
                                          fontWeight: FontWeight.w700, color: _kBlue)),
                                ),
                            ]),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _fichaCol(IconData icon, Color color, String valor, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(valor, style: const TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600, color: _kText)),
          if (label.isNotEmpty)
            Text(label, style: const TextStyle(fontSize: 9, color: _kSub)),
        ]),
      ]);
}

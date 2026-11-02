import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../modelos/fichaje.dart';
import '../servicios/fichaje_service.dart';
import '../../empleados/pantallas/portal_empleado_screen.dart';
import 'pantalla_fichaje_empleado.dart';
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import 'package:planeag_flutter/core/widgets/fluix_app_bar.dart';
import 'dialog_configurar_pin.dart';
import 'dialog_editar_fichaje.dart';
import 'fichaje_panel_central.dart';
import 'fichaje_panel_derecho.dart';
import 'fichajes_colors.dart';
import 'tab_empleados_fichaje.dart';
import 'tab_informes_fichaje.dart';

class GestionFichajesScreen extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;

  const GestionFichajesScreen({
    super.key,
    required this.empresaId,
    this.esAdmin = false,
  });

  @override
  State<GestionFichajesScreen> createState() => _GestionFichajesScreenState();
}

class _GestionFichajesScreenState extends State<GestionFichajesScreen> {
  final _svc = FichajeService();
  Timer? _clockTimer;
  StreamSubscription<QuerySnapshot>? _fichajeHoySub;
  DateTime _ahora = DateTime.now();
  Fichaje? _misFichaje;
  bool _fichando = false;
  List<double> _semanaData = [];
  List<String> _semanaLabels = [];
  bool _cargandoSemana = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _ahora = DateTime.now());
      });
    });
    _cargarMiFichaje();
    _cargarSemana();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _fichajeHoySub?.cancel();
    super.dispose();
  }

  Future<void> _cargarMiFichaje() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _fichajeHoySub?.cancel();
    _fichajeHoySub = FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('fichajes')
        .where('empleado_id', isEqualTo: uid)
        .where('fecha', isEqualTo: hoy)
        .where('es_correccion', isEqualTo: false)
        .orderBy('creado_at', descending: true)
        .limit(1)
        .snapshots()
        .listen(
          (snap) {
            if (!mounted) return;
            final f = snap.docs.isNotEmpty
                ? Fichaje.fromFirestore(snap.docs.first)
                : null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _misFichaje = f);
            });
          },
          onError: (e) => debugPrint('[Fichajes] error stream propio: $e'),
        );
  }

  Future<void> _fichar(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _fichando = true);
    try {
      final trabajando = _misFichaje != null && _misFichaje!.salida == null;
      if (trabajando) {
        await _svc.ficharSalida(
            empresaId: widget.empresaId, empleadoId: user.uid);
        if (mounted) FluxToast.exito(context, 'Salida registrada');
      } else {
        await _svc.ficharEntrada(
          empresaId: widget.empresaId,
          empleadoId: user.uid,
          empleadoNombre: user.displayName ?? user.email ?? 'Administrador',
          dispositivoId: 'app',
        );
        if (mounted) FluxToast.exito(context, 'Entrada registrada');
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _fichando = false);
    }
  }

  Future<void> _ficharPausa(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _fichando = true);
    try {
      final enPausa = _misFichaje != null &&
          _misFichaje!.pausas.any((p) => p.fin == null);
      if (enPausa) {
        await _svc.finalizarPausa(
            empresaId: widget.empresaId, empleadoId: user.uid);
        if (mounted) FluxToast.exito(context, 'Pausa finalizada');
      } else {
        await _svc.iniciarPausa(
            empresaId: widget.empresaId, empleadoId: user.uid);
        if (mounted) FluxToast.exito(context, 'Pausa iniciada');
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _fichando = false);
    }
  }

  Future<void> _cargarSemana() async {
    if (_cargandoSemana) return;
    if (mounted) setState(() => _cargandoSemana = true);
    try {
      final now = DateTime.now();
      final lunes = now.subtract(Duration(days: now.weekday - 1));
      final fichajes = await _svc.fichajesMes(
          empresaId: widget.empresaId, mes: DateTime(now.year, now.month));
      final empSnap = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('empleados_fichaje')
          .where('activo', isEqualTo: true)
          .get();
      final numEmp = empSnap.docs.length.clamp(1, 999);
      final targetMin = numEmp * 480.0;
      const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      final datos = <double>[];
      for (int i = 0; i < 7; i++) {
        final dia = lunes.add(Duration(days: i));
        if (dia.isAfter(now)) { datos.add(0.0); continue; }
        final diaKey = DateFormat('yyyy-MM-dd').format(dia);
        final minsDia = fichajes
            .where((f) => f.fecha == diaKey && !f.esCorreccion)
            .fold<int>(0, (s, f) => s + (f.tiempoNeto?.inMinutes ?? 0));
        datos.add((minsDia / targetMin * 100).clamp(0.0, 100.0));
      }
      if (mounted) setState(() {
        _semanaData = datos;
        _semanaLabels = List.from(labels);
      });
    } catch (e) {
      debugPrint('[Fichajes] error cargando semana: $e');
      if (mounted) setState(() => _semanaData = []);
    } finally {
      if (mounted) setState(() => _cargandoSemana = false);
    }
  }

  Stream<List<Fichaje>> get _fichajesHoyStream {
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('fichajes')
        .where('fecha', isEqualTo: hoy)
        .where('es_correccion', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.map(Fichaje.fromFirestore).toList());
  }

  void _verFichajeDetalleDialog(BuildContext context, Fichaje f) {
    showDialog(
      context: context,
      builder: (_) => DialogFichajesEmpleado(
        empresaId: widget.empresaId,
        empleadoId: f.empleadoId,
        empleadoNombre: f.empleadoNombre,
        mes: DateTime.now(),
        svc: _svc,
        onCorregido: () {},
      ),
    );
  }

  Future<void> _abrirConfigJornada(
      BuildContext context, String uid, String nombre) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('empleados_fichaje').doc(uid).get();
      final fichaje =
          snap.exists ? EmpleadoFichaje.fromFirestore(snap) : null;
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => DialogConfigurarPin(
          uid: uid,
          nombre: nombre,
          pinActual: fichaje?.pin,
          jornadaActual: fichaje?.jornadaDiaria ?? 480,
          horarioEntrada: fichaje?.horarioEntrada,
          horarioSalida: fichaje?.horarioSalida,
          diasLaborables: fichaje?.diasLaborables,
          empresaId: widget.empresaId,
          svc: _svc,
        ),
      );
    } catch (e) {
      if (context.mounted) FluxToast.error(context, 'Error cargando datos: $e');
    }
  }

  void _mostrarHistorialPropio(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    showDialog(
      context: context,
      builder: (_) => DialogFichajesEmpleado(
        empresaId: widget.empresaId,
        empleadoId: user.uid,
        empleadoNombre: user.displayName ?? 'Administrador',
        mes: DateTime.now(),
        svc: _svc,
        onCorregido: _cargarMiFichaje,
      ),
    );
  }

  void _openSheet(BuildContext context, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.85, child: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.esAdmin) {
      return Scaffold(
        backgroundColor: kFBg,
        appBar: Navigator.of(context).canPop()
            ? FluixAppBar(titulo: 'Mi fichaje', showLeading: true)
            : null,
        body: PortalEmpleadoScreen(
          empresaId: widget.empresaId,
          empleadoUid: FirebaseAuth.instance.currentUser?.uid,
          modoAdmin: false,
          standalone: false,
        ),
      );
    }
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: kFBg,
      appBar: canPop
          ? FluixAppBar(
              titulo: 'Fichajes',
              showLeading: true,
              extraActions: [
                IconButton(
                  icon: const Icon(Icons.tablet_android_outlined, size: 20),
                  tooltip: 'Kiosk empleados',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PantallaFichajeEmpleado(
                          empresaId: widget.empresaId,
                          dispositivoId: 'kiosk_movil'))),
                ),
                IconButton(
                  icon: const Icon(Icons.people_outline, size: 20),
                  tooltip: 'Empleados',
                  onPressed: () => _openSheet(context,
                      TabEmpleadosFichaje(empresaId: widget.empresaId)),
                ),
                IconButton(
                  icon: const Icon(Icons.bar_chart_rounded, size: 20),
                  tooltip: 'Informes',
                  onPressed: () => _openSheet(context,
                      TabInformesFichaje(empresaId: widget.empresaId)),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  tooltip: 'Informe PDF',
                  onPressed: () => _openSheet(context,
                      TabInformesFichaje(empresaId: widget.empresaId)),
                ),
              ],
            )
          : null,
      body: StreamBuilder<List<Fichaje>>(
        stream: _fichajesHoyStream,
        builder: (ctx, snap) {
          final fichajes = snap.data ?? [];
          return LayoutBuilder(builder: (lCtx, constraints) {
            final isMobile = constraints.maxWidth < 640;
            return Column(children: [
              if (!canPop) _header(context, isMobile),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      isMobile ? 12 : 20, 0, isMobile ? 12 : 20, 24),
                  child: Column(children: [
                    _kpis(fichajes, isMobile),
                    const SizedBox(height: 16),
                    if (isMobile) ...[
                      _heroCard(context),
                      const SizedBox(height: 14),
                      FichajesMobileList(
                        fichajes: fichajes,
                        esAdmin: widget.esAdmin,
                        onVerDetalle: (f) =>
                            _verFichajeDetalleDialog(context, f),
                        onConfigJornada: (uid, n) =>
                            _abrirConfigJornada(context, uid, n),
                      ),
                      const SizedBox(height: 14),
                      FichajeEstadoActualCard(
                        misFichaje: _misFichaje,
                        ahora: _ahora,
                        nombreUsuario: FirebaseAuth
                                .instance.currentUser?.displayName ??
                            'Usuario',
                      ),
                      const SizedBox(height: 14),
                      FichajeAsistenciaHoyCard(fichajes: fichajes),
                      const SizedBox(height: 14),
                      FichajeProductividadSemanalCard(
                        semanaData: _semanaData,
                        semanaLabels: _semanaLabels,
                        cargando: _cargandoSemana,
                        onVerInformes: () => _openSheet(context,
                            TabInformesFichaje(empresaId: widget.empresaId)),
                      ),
                    ] else
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(children: [
                                _heroCard(context),
                                const SizedBox(height: 16),
                                FichajesTableWidget(
                                  fichajes: fichajes,
                                  esAdmin: widget.esAdmin,
                                  onVerDetalle: (f) =>
                                      _verFichajeDetalleDialog(context, f),
                                  onConfigJornada: (uid, n) =>
                                      _abrirConfigJornada(context, uid, n),
                                ),
                              ]),
                            ),
                            const SizedBox(width: 20),
                            SizedBox(
                              width: 290,
                              child: Column(children: [
                                FichajeEstadoActualCard(
                                  misFichaje: _misFichaje,
                                  ahora: _ahora,
                                  nombreUsuario: FirebaseAuth.instance
                                          .currentUser?.displayName ??
                                      'Usuario',
                                ),
                                const SizedBox(height: 16),
                                FichajeAsistenciaHoyCard(fichajes: fichajes),
                                const SizedBox(height: 16),
                                FichajeProductividadSemanalCard(
                                  semanaData: _semanaData,
                                  semanaLabels: _semanaLabels,
                                  cargando: _cargandoSemana,
                                  onVerInformes: () => _openSheet(
                                      context,
                                      TabInformesFichaje(
                                          empresaId: widget.empresaId)),
                                ),
                              ]),
                            ),
                          ]),
                  ]),
                ),
              ),
            ]);
          });
        },
      ),
    );
  }

  Widget _heroCard(BuildContext context) => FichajeHeroCard(
        misFichaje: _misFichaje,
        ahora: _ahora,
        fichando: _fichando,
        empresaId: widget.empresaId,
        svc: _svc,
        onFichar: _fichar,
        onFicharPausa: _ficharPausa,
        onOlvisteFichar: () => _mostrarHistorialPropio(context),
      );

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _header(BuildContext context, bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: kFBorder))),
        child: Row(children: [
          const FluixLogo(size: 22),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: const Text('Inicio',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: -0.3,
                    color: kFSub)),
          ),
          const Icon(Icons.chevron_right_rounded, size: 16, color: kFSub),
          const Text('Fichajes',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: -0.2,
                  color: kFText)),
          const Spacer(),
          IconButton(
              icon: const Icon(Icons.tablet_android_outlined,
                  color: kFSub, size: 20),
              tooltip: 'Kiosk empleados',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PantallaFichajeEmpleado(
                          empresaId: widget.empresaId,
                          dispositivoId: 'kiosk_movil')))),
          IconButton(
              icon: const Icon(Icons.people_outline, color: kFSub, size: 20),
              tooltip: 'Empleados',
              onPressed: () => _openSheet(context,
                  TabEmpleadosFichaje(empresaId: widget.empresaId))),
          IconButton(
              icon: const Icon(Icons.bar_chart_rounded, color: kFSub, size: 20),
              tooltip: 'Informes',
              onPressed: () => _openSheet(context,
                  TabInformesFichaje(empresaId: widget.empresaId))),
          IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined,
                  color: kFSub, size: 20),
              tooltip: 'Descargar PDF de horas',
              onPressed: () => _openSheet(context,
                  TabInformesFichaje(empresaId: widget.empresaId))),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: kFBorder))),
      child: Row(children: [
        const Flexible(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fichajes',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: kFText)),
                SizedBox(height: 2),
                Text('Controla la jornada laboral de tu equipo en tiempo real.',
                    style: TextStyle(fontSize: 12, color: kFSub),
                    overflow: TextOverflow.ellipsis),
              ]),
        ),
        const SizedBox(width: 12),
        _hBtn(
            Icons.tablet_android_outlined,
            'Kiosk',
            () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PantallaFichajeEmpleado(
                        empresaId: widget.empresaId,
                        dispositivoId: 'kiosk_tablet')))),
        const SizedBox(width: 8),
        _hBtn(
            Icons.people_outline,
            'Empleados',
            () => _openSheet(
                context, TabEmpleadosFichaje(empresaId: widget.empresaId))),
        const SizedBox(width: 8),
        _hBtn(
            Icons.bar_chart_rounded,
            'Informes',
            () => _openSheet(
                context, TabInformesFichaje(empresaId: widget.empresaId))),
        const SizedBox(width: 8),
        _hBtn(
            Icons.picture_as_pdf_outlined,
            'Informe PDF',
            () => _openSheet(
                context, TabInformesFichaje(empresaId: widget.empresaId))),
      ]),
    );
  }

  Widget _hBtn(IconData icon, String label, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: kFSub,
          side: const BorderSide(color: kFBorder),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

  // ── KPIs ─────────────────────────────────────────────────────────────────────
  Widget _kpis(List<Fichaje> fichajes, bool isMobile) {
    final trabajando = fichajes
        .where((f) =>
            f.salida == null &&
            f.pausas.every((p) => p.fin != null || f.pausas.isEmpty))
        .length;
    final enPausa = fichajes
        .where((f) =>
            f.salida == null &&
            f.pausas.isNotEmpty &&
            f.pausas.any((p) => p.fin == null))
        .length;
    final totalMinHoy =
        fichajes.fold(0, (s, f) => s + (f.tiempoNeto?.inMinutes ?? 0));
    final hHoy = totalMinHoy ~/ 60;
    final mHoy = totalMinHoy % 60;

    final k1 = _kpiCard(
      icon: Icons.people_alt_outlined,
      iconBg: const Color(0xFFDCFCE7),
      iconColor: kFGreen,
      label: 'Trabajando',
      value: '$trabajando',
      sub: trabajando == 0
          ? 'Nadie fichado'
          : '$trabajando activo${trabajando > 1 ? 's' : ''}',
      subColor: trabajando > 0 ? kFGreen : kFSub,
    );
    final k2 = _kpiCard(
      icon: Icons.pause_circle_outline,
      iconBg: const Color(0xFFFEF3C7),
      iconColor: kFOrange,
      label: 'En pausa',
      value: '$enPausa',
      sub: enPausa == 0 ? 'Sin pausas' : 'En descanso',
      subColor: enPausa > 0 ? kFOrange : kFSub,
    );
    final k3 = _kpiCard(
      icon: Icons.access_time_outlined,
      iconBg: const Color(0xFFDCFCE7),
      iconColor: kFGreen,
      label: 'Horas hoy',
      value: '${hHoy}h ${mHoy.toString().padLeft(2, '0')}m',
      sub: fichajes.isEmpty
          ? 'Sin registros'
          : '${fichajes.length} fichaje${fichajes.length > 1 ? 's' : ''}',
      subColor: kFSub,
    );
    final k4 = _kpiCard(
      icon: Icons.calendar_today_outlined,
      iconBg: const Color(0xFFDCFCE7),
      iconColor: kFGreen,
      label: 'Fichajes hoy',
      value: '${fichajes.length}',
      sub: fichajes.isEmpty ? 'Sin actividad' : 'Registros del día',
      subColor: kFSub,
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(children: [
          Row(children: [k1, const SizedBox(width: 10), k2]),
          const SizedBox(height: 10),
          Row(children: [k3, const SizedBox(width: 10), k4]),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(children: [
        k1,
        const SizedBox(width: 12),
        k2,
        const SizedBox(width: 12),
        k3,
        const SizedBox(width: 12),
        k4,
      ]),
    );
  }

  Widget _kpiCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String value,
    required String sub,
    required Color subColor,
  }) =>
      Expanded(
        child: fichajeCard(
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration:
                  BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style:
                            const TextStyle(fontSize: 11, color: kFSub)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kFText)),
                    ),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: TextStyle(fontSize: 11, color: subColor)),
                  ]),
            ),
          ]),
        ),
      );
}

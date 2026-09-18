import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../modelos/fichaje.dart';
import '../servicios/fichaje_service.dart';
import '../../fichaje/pantalla_fichaje/pantalla_fichaje.dart';
import '../../pdf_templates/data/pdf_template_service.dart' as ptSvc;
import '../../pdf_templates/domain/models/pdf_template.dart' as ptModel;
import 'package:planeag_flutter/core/widgets/flux_toast.dart';
import 'package:planeag_flutter/core/widgets/fluix_app_bar.dart';

// ════════════════════════════════════════════════════════════════════════════
// COLORES FICHAJES
// ════════════════════════════════════════════════════════════════════════════
const _kGreen  = Color(0xFF22C55E);
const _kOrange = Color(0xFFF59E0B);
const _kGray   = Color(0xFF9CA3AF);
const _kBg     = Color(0xFFF8F9FA);
const _kBorder = Color(0xFFE5E7EB);
const _kText   = Color(0xFF111827);
const _kSub    = Color(0xFF6B7280);

class GestionFichajesScreen extends StatefulWidget {
  final String empresaId;
  final bool esAdmin;
  const GestionFichajesScreen({super.key, required this.empresaId, this.esAdmin = false});

  @override
  State<GestionFichajesScreen> createState() => _GestionFichajesScreenState();
}

class _GestionFichajesScreenState extends State<GestionFichajesScreen> {
  final _svc   = FichajeService();
  Timer?          _clockTimer;
  DateTime        _ahora            = DateTime.now();
  Fichaje?        _misFichaje;
  bool            _fichando         = false;
  List<double>    _semanaData       = [];
  List<String>    _semanaLabels     = [];
  bool            _cargandoSemana   = false;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _ahora = DateTime.now());
    });
    _cargarMiFichaje();
    _cargarSemana();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _cargarMiFichaje() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      // Stream en lugar de Future para que el fichaje se actualice en tiempo real
      FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('fichajes')
          .where('empleado_id', isEqualTo: uid)
          .where('fecha', isEqualTo: hoy)
          .limit(1)
          .snapshots()
          .listen((snap) {
        if (mounted) setState(() {
          _misFichaje = snap.docs.isNotEmpty ? Fichaje.fromFirestore(snap.docs.first) : null;
        });
      });
    } catch (_) {}
  }

  Future<void> _fichar(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _fichando = true);
    try {
      final trabajando = _misFichaje != null && _misFichaje!.salida == null;
      if (trabajando) {
        await _svc.ficharSalida(
          empresaId: widget.empresaId,
          empleadoId: user.uid,
        );
        if (mounted) FluxToast.exito(context, 'Salida registrada');
      } else {
        final nombre = user.displayName ?? user.email ?? 'Administrador';
        await _svc.ficharEntrada(
          empresaId: widget.empresaId,
          empleadoId: user.uid,
          empleadoNombre: nombre,
          dispositivoId: 'app',
        );
        if (mounted) FluxToast.exito(context, 'Entrada registrada');
      }
      await _cargarMiFichaje();
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
      final mesActual = DateTime(now.year, now.month);
      final fichajes = await _svc.fichajesMes(
          empresaId: widget.empresaId, mes: mesActual);

      // Número de empleados activos para calcular objetivo
      final empSnap = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('empleados_fichaje')
          .where('activo', isEqualTo: true).get();
      final numEmp = empSnap.docs.length.clamp(1, 999);
      final targetMin = numEmp * 480.0; // 8h × empleados activos

      const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      final datos = <double>[];
      for (int i = 0; i < 7; i++) {
        final dia = lunes.add(Duration(days: i));
        if (dia.isAfter(now)) { datos.add(0.0); continue; }
        final diaKey = DateFormat('yyyy-MM-dd').format(dia);
        final minsDia = fichajes
            .where((f) => f.fecha == diaKey)
            .fold<int>(0, (s, f) => s + (f.tiempoNeto?.inMinutes ?? 0));
        datos.add((minsDia / targetMin * 100).clamp(0.0, 100.0));
      }
      if (mounted) setState(() {
        _semanaData   = datos;
        _semanaLabels = List.from(labels);
      });
    } catch (_) {
      if (mounted) setState(() => _semanaData = []);
    } finally {
      if (mounted) setState(() => _cargandoSemana = false);
    }
  }

  // ── Streams ──────────────────────────────────────────────────────────────
  Stream<List<Fichaje>> get _fichajesHoyStream {
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return FirebaseFirestore.instance
        .collection('empresas').doc(widget.empresaId)
        .collection('fichajes')
        .where('fecha', isEqualTo: hoy)
        .snapshots()
        .map((s) => s.docs.map(Fichaje.fromFirestore).toList());
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (!widget.esAdmin) {
      return const Scaffold(backgroundColor: _kBg,
          body: PantallaFichaje(embedido: true));
    }
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: _kBg,
      appBar: canPop
          ? FluixAppBar(titulo: 'Fichajes', showLeading: true)
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
                  padding: EdgeInsets.fromLTRB(isMobile ? 12 : 20, 0, isMobile ? 12 : 20, 24),
                  child: Column(children: [
                    _kpis(fichajes, isMobile),
                    const SizedBox(height: 16),
                    if (isMobile) ...[
                      _fichajeHero(context),
                      const SizedBox(height: 14),
                      _fichajesListMobile(context, fichajes),
                      const SizedBox(height: 14),
                      _estadoActual(),
                      const SizedBox(height: 14),
                      _asistenciaHoy(fichajes),
                      const SizedBox(height: 14),
                      _productividadSemanal(),
                    ] else
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: _centerCol(context, fichajes)),
                        const SizedBox(width: 20),
                        SizedBox(width: 290, child: _rightCol(context, fichajes)),
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

  // ── Lista móvil de fichajes (alternativa a la tabla) ─────────────────────
  Widget _fichajesListMobile(BuildContext context, List<Fichaje> fichajes) {
    final hoy = DateFormat("d 'de' MMMM", 'es_ES').format(DateTime.now());
    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Fichajes hoy — $hoy',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _kText)),
        const Spacer(),
        Text('${fichajes.length} registros',
            style: const TextStyle(fontSize: 11, color: _kSub)),
      ]),
      const SizedBox(height: 10),
      if (fichajes.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: Text('Sin fichajes hoy', style: TextStyle(color: _kSub, fontSize: 13))),
        )
      else
        ...fichajes.take(12).map((f) => _fichajeCardMobile(context, f)),
    ]));
  }

  Widget _fichajeCardMobile(BuildContext context, Fichaje f) {
    final fmtH = DateFormat('HH:mm');
    final entH = f.entrada != null ? fmtH.format(f.entrada!.toDate().toLocal()) : '—';
    final salH = f.salida  != null ? fmtH.format(f.salida!.toDate().toLocal())  : '—';
    final neto = f.tiempoNeto;
    final netoTxt = neto != null ? '${neto.inHours}h ${(neto.inMinutes % 60).toString().padLeft(2, '0')}m' : '—';
    final enPausa = f.salida == null && f.pausas.any((p) => p.fin == null);
    final trabajando = f.salida == null;
    final (label, color) = enPausa
        ? ('En pausa', _kOrange)
        : trabajando ? ('Trabajando', _kGreen) : ('Finalizada', _kGray);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: const Color(0xFFE5E7EB),
          child: Text(f.empleadoNombre.isNotEmpty ? f.empleadoNombre[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _kText))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.empleadoNombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Row(children: [
            _tag(Icons.login_rounded, entH, _kGreen),
            const SizedBox(width: 6),
            _tag(Icons.logout_rounded, salH, _kGray),
            const SizedBox(width: 6),
            _tag(Icons.timer_outlined, netoTxt, _kSub),
          ]),
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ),
        IconButton(
          onPressed: () => _verFichajeDetalleDialog(context, f),
          icon: const Icon(Icons.chevron_right_rounded, size: 18, color: _kSub),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ]),
    );
  }

  Widget _tag(IconData icon, String text, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 10, color: color),
    const SizedBox(width: 2),
    Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
  ]);

  // ══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _header(BuildContext context, bool isMobile) {
    if (isMobile) {
      // Estilo idéntico a FluixAppBar: logo + breadcrumb "Inicio > Fichajes"
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: const BoxDecoration(
            color: Colors.white, border: Border(bottom: BorderSide(color: _kBorder))),
        child: Row(children: [
          const FluixLogo(size: 22),
          const SizedBox(width: 8),
          const Text('Inicio', style: TextStyle(fontWeight: FontWeight.w600,
              fontSize: 15, letterSpacing: -0.3, color: _kSub)),
          const Icon(Icons.chevron_right_rounded, size: 16, color: _kSub),
          const Text('Fichajes', style: TextStyle(fontWeight: FontWeight.w700,
              fontSize: 16, letterSpacing: -0.2, color: _kText)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.people_outline, color: _kSub, size: 20),
            tooltip: 'Empleados',
            onPressed: () => _openSheet(context, _TabEmpleados(empresaId: widget.empresaId)),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: _kSub, size: 20),
            tooltip: 'Informes',
            onPressed: () => _openSheet(context, _TabInformes(empresaId: widget.empresaId)),
          ),
        ]),
      );
    }
    // Tablet: Flexible en la columna para evitar overflow
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _kBorder))),
      child: Row(children: [
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Fichajes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                color: _kText)),
            SizedBox(height: 2),
            Text('Controla la jornada laboral de tu equipo en tiempo real.',
                style: TextStyle(fontSize: 12, color: _kSub),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 12),
        _hBtn(Icons.people_outline, 'Empleados',
            () => _openSheet(context, _TabEmpleados(empresaId: widget.empresaId))),
        const SizedBox(width: 8),
        _hBtn(Icons.bar_chart_rounded, 'Informes',
            () => _openSheet(context, _TabInformes(empresaId: widget.empresaId))),
      ]),
    );
  }

  Widget _hBtn(IconData icon, String label, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _kSub,
          side: const BorderSide(color: _kBorder),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

  void _openSheet(BuildContext context, Widget content) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SizedBox(height: MediaQuery.of(context).size.height * 0.85, child: content),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // KPI CARDS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _kpis(List<Fichaje> fichajes, bool isMobile) {
    final trabajando = fichajes.where((f) => f.salida == null && f.pausas.every((p) => p.fin != null || (f.pausas.isEmpty))).length;
    final enPausa    = fichajes.where((f) => f.salida == null && f.pausas.isNotEmpty && f.pausas.any((p) => p.fin == null)).length;
    final totalMinHoy = fichajes.fold(0, (s, f) => s + (f.tiempoNeto?.inMinutes ?? 0));
    final hHoy = totalMinHoy ~/ 60;
    final mHoy = totalMinHoy % 60;

    final k1 = _kpiCard(
      icon: Icons.people_alt_outlined, iconBg: const Color(0xFFDCFCE7), iconColor: _kGreen,
      label: 'Trabajando', value: '$trabajando',
      sub: trabajando == 0 ? 'Nadie fichado' : '${trabajando} activo${trabajando > 1 ? 's' : ''}',
      subColor: trabajando > 0 ? _kGreen : _kSub,
    );
    final k2 = _kpiCard(
      icon: Icons.pause_circle_outline, iconBg: const Color(0xFFFEF3C7), iconColor: _kOrange,
      label: 'En pausa', value: '$enPausa',
      sub: enPausa == 0 ? 'Sin pausas' : 'En descanso',
      subColor: enPausa > 0 ? _kOrange : _kSub,
    );
    final k3 = _kpiCard(
      icon: Icons.access_time_outlined, iconBg: const Color(0xFFDCFCE7), iconColor: _kGreen,
      label: 'Horas hoy', value: '${hHoy}h ${mHoy.toString().padLeft(2, '0')}m',
      sub: fichajes.isEmpty ? 'Sin registros' : '${fichajes.length} fichaje${fichajes.length > 1 ? 's' : ''}',
      subColor: _kSub,
    );
    final k4 = _kpiCard(
      icon: Icons.calendar_today_outlined, iconBg: const Color(0xFFDCFCE7), iconColor: _kGreen,
      label: 'Fichajes hoy', value: '${fichajes.length}',
      sub: fichajes.isEmpty ? 'Sin actividad' : 'Registros del día',
      subColor: _kSub,
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
      child: Row(children: [k1, const SizedBox(width: 12), k2, const SizedBox(width: 12), k3, const SizedBox(width: 12), k4]),
    );
  }

  Widget _kpiCard({
    required IconData icon, required Color iconBg, required Color iconColor,
    required String label, required String value, required String sub,
    required Color subColor,
  }) => Expanded(
    child: _card(
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: _kSub)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                color: _kText)),
          ),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 11, color: subColor)),
        ])),
      ]),
    ),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // COLUMNA CENTRAL
  // ══════════════════════════════════════════════════════════════════════════
  Widget _centerCol(BuildContext context, List<Fichaje> fichajes) {
    return Column(children: [
      _fichajeHero(context),
      const SizedBox(height: 16),
      _fichajesTable(context, fichajes),
    ]);
  }

  // ── Reloj + botón fichar ──────────────────────────────────────────────────
  Widget _fichajeHero(BuildContext context) {
    final entrada = _misFichaje?.entrada?.toDate().toLocal();
    final entradaStr = entrada != null ? DateFormat('HH:mm').format(entrada) : null;
    final trabajando = _misFichaje != null && _misFichaje!.salida == null;
    final enPausa = trabajando && _misFichaje!.pausas.isNotEmpty &&
        _misFichaje!.pausas.any((p) => p.fin == null);

    return _card(
      child: Column(children: [
        // Fecha
        Text(
          _fmtFecha(_ahora),
          style: const TextStyle(fontSize: 14, color: _kSub),
        ),
        const SizedBox(height: 12),
        // Reloj
        Text(
          DateFormat('HH:mm:ss').format(_ahora),
          style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800,
              color: _kText, letterSpacing: -2),
        ),
        const SizedBox(height: 10),
        // Estado badge
        if (entradaStr != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: enPausa
                  ? _kOrange.withValues(alpha: 0.12)
                  : _kGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 7, height: 7,
                decoration: BoxDecoration(
                  color: enPausa ? _kOrange : _kGreen,
                  shape: BoxShape.circle,
                )),
              const SizedBox(width: 6),
              Text(
                enPausa
                    ? 'En pausa desde $entradaStr'
                    : 'Trabajando desde $entradaStr',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500,
                  color: enPausa ? _kOrange : _kGreen,
                ),
              ),
            ]),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('Sin fichar hoy',
                style: TextStyle(fontSize: 13, color: _kSub)),
          ),
        const SizedBox(height: 20),
        // Botón principal
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _fichando ? null : () => _fichar(context),
            icon: _fichando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(
              _misFichaje == null
                  ? Icons.login_rounded
                  : trabajando ? Icons.logout_rounded : Icons.login_rounded,
              size: 20,
            ),
            label: Text(
              _misFichaje == null
                  ? 'Fichar entrada'
                  : trabajando ? 'Fichar salida' : 'Fichar entrada',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _misFichaje != null && trabajando
                  ? const Color(0xFF22C55E) : const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () {},
          child: const Text('¿Olvidaste fichar entrada?',
              style: TextStyle(fontSize: 12, color: _kGreen,
                  decoration: TextDecoration.underline)),
        ),
        const SizedBox(height: 8),
        // Línea jornada
        _jornadaTimeline(),
      ]),
    );
  }

  Widget _jornadaTimeline() {
    final entrada  = _misFichaje?.entrada?.toDate().toLocal();
    final salida   = _misFichaje?.salida?.toDate().toLocal();
    final pausas   = _misFichaje?.pausas ?? [];
    final pausaStr = pausas.isNotEmpty
        ? DateFormat('HH:mm').format(pausas.first.inicio.toDate().toLocal())
        : null;
    final reanuStr = pausas.isNotEmpty && pausas.first.fin != null
        ? DateFormat('HH:mm').format(pausas.first.fin!.toDate().toLocal())
        : null;

    return Column(children: [
      const Divider(height: 24, color: _kBorder),
      Row(children: [
        const Text('Mi jornada de hoy',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kText)),
        const Spacer(),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(foregroundColor: _kSub,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(fontSize: 12)),
          child: const Row(children: [
            Text('Ver jornada completa'),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward, size: 14),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _timelineItem(Icons.login_rounded, _kGreen,
              entrada != null ? DateFormat('HH:mm').format(entrada) : '--:--',
              'Entrada', true),
          _timelineLine(_kGreen),
          _timelineItem(Icons.coffee_rounded, _kOrange,
              pausaStr ?? '--:--', 'Descanso\n30m', pausaStr != null),
          _timelineLine(reanuStr != null ? _kGreen : _kBorder),
          _timelineItem(Icons.play_arrow_rounded, _kGreen,
              reanuStr ?? '--:--', 'Reanudación', reanuStr != null),
          _timelineLine(salida != null ? _kGreen : _kBorder),
          _timelineItem(Icons.logout_rounded, _kGray,
              salida != null
                  ? DateFormat('HH:mm').format(salida)
                  : '17:30',
              salida != null ? 'Salida' : 'Salida estimada', false),
        ]),
      ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _timelineItem(IconData icon, Color color, String time, String label, bool done) {
    return Column(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
          color: done ? color.withValues(alpha: 0.12) : const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
          border: Border.all(color: done ? color : _kBorder, width: 1.5),
        ),
        child: Icon(icon, size: 18, color: done ? color : _kGray),
      ),
      const SizedBox(height: 6),
      Text(time, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
          color: _kText)),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: _kSub, height: 1.3)),
      if (done) ...[
        const SizedBox(height: 2),
        const Icon(Icons.check, size: 14, color: _kGreen),
      ],
    ]);
  }

  Widget _timelineLine(Color color) => Container(
    width: 48, height: 2,
    margin: const EdgeInsets.only(bottom: 30),
    color: color,
  );

  // ── Tabla fichajes recientes ──────────────────────────────────────────────
  Widget _fichajesTable(BuildContext context, List<Fichaje> fichajes) {
    final hoy = DateFormat("d 'de' MMMM", 'es_ES').format(DateTime.now());
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cabecera
        Row(children: [
          const Text('Fichajes recientes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kText)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: _kSub),
              const SizedBox(width: 6),
              Text('Hoy, $hoy',
                  style: const TextStyle(fontSize: 12, color: _kSub)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 16, color: _kSub),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: _kBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.filter_list_rounded, size: 14, color: _kSub),
              SizedBox(width: 5),
              Text('Filtros', style: TextStyle(fontSize: 12, color: _kSub)),
            ]),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.more_vert, size: 18, color: _kSub),
        ]),
        const SizedBox(height: 16),
        if (fichajes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('Sin fichajes hoy',
                style: TextStyle(color: _kSub, fontSize: 13))),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 810,
              child: Column(children: [
                // Cabeceras de columna
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: _kBorder))),
                  child: Row(children: const [
                    SizedBox(width: 200, child: Text('EMPLEADO', style: _colHead)),
                    SizedBox(width: 80, child: Text('ENTRADA', style: _colHead)),
                    SizedBox(width: 80, child: Text('SALIDA', style: _colHead)),
                    SizedBox(width: 80, child: Text('HORAS', style: _colHead)),
                    SizedBox(width: 110, child: Text('ESTADO', style: _colHead)),
                    SizedBox(width: 130, child: Text('UBICACIÓN', style: _colHead)),
                    SizedBox(width: 100, child: Text('DISPOSITIVO', style: _colHead)),
                    SizedBox(width: 30),
                  ]),
                ),
                ...fichajes.take(10).map((f) => _fichajeRow(context, f)),
              ]),
            ),
          ),
      ]),
    );
  }

  static const _colHead = TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
      color: _kSub, letterSpacing: 0.5);

  Widget _fichajeRow(BuildContext context, Fichaje f) {
    final fmtH = DateFormat('HH:mm');
    final entH  = f.entrada != null ? fmtH.format(f.entrada!.toDate().toLocal()) : '—';
    final salH  = f.salida  != null ? fmtH.format(f.salida!.toDate().toLocal())  : '—';
    final neto  = f.tiempoNeto;
    final netoTxt = neto != null
        ? '${neto.inHours}h ${(neto.inMinutes % 60).toString().padLeft(2,'0')}m' : '—';
    final esTrabajando = f.salida == null;
    final enPausa = esTrabajando && f.pausas.any((p) => p.fin == null);
    final (badgeLabel, badgeColor) = enPausa
        ? ('En pausa', _kOrange)
        : esTrabajando
            ? ('Trabajando', _kGreen)
            : ('Finalizada', _kGray);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
      child: Row(children: [
        SizedBox(width: 200, child: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: const Color(0xFFE5E7EB),
              child: Text(f.empleadoNombre.isNotEmpty ? f.empleadoNombre[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                      color: _kText))),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.empleadoNombre, style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w600, color: _kText),
                overflow: TextOverflow.ellipsis),
            const Text('Empleado', style: TextStyle(fontSize: 10, color: _kSub)),
          ])),
        ])),
        SizedBox(width: 80, child: Text(entH,
            style: const TextStyle(fontSize: 12, color: _kText))),
        SizedBox(width: 80, child: Text(salH,
            style: const TextStyle(fontSize: 12, color: _kSub))),
        SizedBox(width: 80, child: Text(netoTxt,
            style: const TextStyle(fontSize: 12, color: _kText))),
        SizedBox(width: 110, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(badgeLabel, style: TextStyle(fontSize: 11,
              color: badgeColor, fontWeight: FontWeight.w600)),
        )),
        const SizedBox(width: 130,
            child: Text('Madrid, España', style: TextStyle(fontSize: 12, color: _kSub))),
        SizedBox(width: 100, child: Row(children: const [
          Icon(Icons.computer_rounded, size: 14, color: _kSub),
          SizedBox(width: 4),
          Text('Web', style: TextStyle(fontSize: 12, color: _kSub)),
        ])),
        InkWell(
          onTap: () => _verFichajeDetalleDialog(context, f),
          child: const SizedBox(width: 30,
              child: Icon(Icons.more_horiz, size: 16, color: _kSub)),
        ),
      ]),
    );
  }

  void _verFichajeDetalleDialog(BuildContext context, Fichaje f) {
    showDialog(
      context: context,
      builder: (ctx) => _DialogFichajesEmpleado(
        empresaId: widget.empresaId,
        empleadoId: f.empleadoId,
        empleadoNombre: f.empleadoNombre,
        mes: DateTime.now(),
        svc: _svc,
        onCorregido: () {},
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COLUMNA DERECHA
  // ══════════════════════════════════════════════════════════════════════════
  Widget _rightCol(BuildContext context, List<Fichaje> fichajes) {
    return Column(children: [
      _estadoActual(),
      const SizedBox(height: 16),
      _asistenciaHoy(fichajes),
      const SizedBox(height: 16),
      _productividadSemanal(),
    ]);
  }

  // Mi estado actual
  Widget _estadoActual() {
    final entrada = _misFichaje?.entrada?.toDate().toLocal();
    final trabajando = _misFichaje != null && _misFichaje!.salida == null;
    final horasMin = _misFichaje?.tiempoNeto?.inMinutes ?? 0;
    final horasTxt = '${horasMin ~/ 60}h ${(horasMin % 60).toString().padLeft(2,'0')}m';
    final entradaTxt = entrada != null ? DateFormat('HH:mm').format(entrada) : '—';
    final uid = FirebaseAuth.instance.currentUser?.displayName ?? 'Usuario';

    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Mi estado actual',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
      const SizedBox(height: 14),
      Row(children: [
        Stack(children: [
          const CircleAvatar(radius: 22, backgroundColor: Color(0xFFE5E7EB),
              child: Icon(Icons.person, size: 24, color: _kSub)),
          Positioned(bottom: 0, right: 0,
            child: Container(width: 11, height: 11,
              decoration: BoxDecoration(
                color: trabajando ? _kGreen : _kGray,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              )),
          ),
        ]),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(uid, style: const TextStyle(fontSize: 13,
              fontWeight: FontWeight.bold, color: _kText),
              overflow: TextOverflow.ellipsis),
          const Text('Administrador', style: TextStyle(fontSize: 11, color: _kSub)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: trabajando ? _kGreen.withValues(alpha: 0.1) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(trabajando ? 'Trabajando' : 'Sin fichar',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: trabajando ? _kGreen : _kGray)),
        ),
      ]),
      const SizedBox(height: 14),
      const Divider(height: 1, color: _kBorder),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _infoRow(Icons.access_time_outlined, 'Entrada hoy', entradaTxt)),
        Expanded(child: _infoRow(Icons.timer_outlined, 'Próxima pausa', '17:00')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _infoRow(Icons.schedule_outlined, 'Horas trabajadas', horasTxt)),
        Expanded(child: _infoRow(Icons.place_outlined, 'Ubicación', 'Madrid, España')),
      ]),
      const SizedBox(height: 12),
      // Mini mapa placeholder
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 80,
          width: double.infinity,
          color: const Color(0xFFE8F5E9),
          child: Stack(children: [
            Center(child: Icon(Icons.map_outlined, size: 40, color: Colors.green[200])),
            const Positioned(bottom: 8, right: 8,
              child: _MapButton(),
            ),
          ]),
        ),
      ),
    ]));
  }

  Widget _infoRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: _kSub),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _kSub)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: _kText)),
      ]),
    ],
  );

  // Asistencia hoy
  Widget _asistenciaHoy(List<Fichaje> fichajes) {
    final total = fichajes.length;
    final trabajando = fichajes.where((f) => f.salida == null && !f.pausas.any((p) => p.fin == null)).length;
    final enPausa    = fichajes.where((f) => f.pausas.any((p) => p.fin == null)).length;
    final finalizados = fichajes.where((f) => f.salida != null).length;
    final pW = total > 0 ? trabajando / total : 0.0;
    final pP = total > 0 ? enPausa / total : 0.0;

    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Asistencia hoy',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText)),
      const SizedBox(height: 16),
      Row(children: [
        // Donut
        SizedBox(width: 80, height: 80,
          child: CustomPaint(
            painter: _DonutPainter(trabajando: pW, enPausa: pP),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(children: [
          _legend(_kGreen, 'Trabajando', trabajando,
              total > 0 ? (trabajando * 100 ~/ total) : 0),
          const SizedBox(height: 8),
          _legend(_kOrange, 'En pausa', enPausa,
              total > 0 ? (enPausa * 100 ~/ total) : 0),
          const SizedBox(height: 8),
          _legend(_kGray, 'Finalizados', finalizados,
              total > 0 ? (finalizados * 100 ~/ total) : 0),
        ])),
      ]),
      const SizedBox(height: 10),
      const Divider(height: 1, color: _kBorder),
      const SizedBox(height: 8),
      Row(children: [
        const Text('Total empleados', style: TextStyle(fontSize: 11, color: _kSub)),
        const Spacer(),
        Text('$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
            color: _kText)),
      ]),
    ]));
  }

  Widget _legend(Color color, String label, int count, int pct) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: _kSub))),
    Text('$count ($pct%)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
        color: _kText)),
  ]);

  // Productividad semanal — datos reales de Firebase
  Widget _productividadSemanal() {
    final values = _semanaData.isEmpty
        ? List<double>.filled(7, 0.0) : _semanaData;
    final labels = _semanaLabels.isEmpty
        ? ['Lun','Mar','Mié','Jue','Vie','Sáb','Dom'] : _semanaLabels;
    final avg = values.where((v) => v > 0).isEmpty ? 0.0
        : values.where((v) => v > 0).fold(0.0, (s, v) => s + v) /
          values.where((v) => v > 0).length;

    return _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Productividad semanal',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kText))),
        if (_cargandoSemana)
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen))
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${avg.toStringAsFixed(0)}% prom',
                style: const TextStyle(fontSize: 10, color: _kGreen,
                    fontWeight: FontWeight.w600)),
          ),
      ]),
      const SizedBox(height: 4),
      const Text('% horas trabajadas vs objetivo (8h/empleado)',
          style: TextStyle(fontSize: 10, color: _kSub)),
      const SizedBox(height: 14),
      SizedBox(
        height: 110,
        child: CustomPaint(
          painter: _LinePainter(values: values, color: _kGreen),
          size: const Size(double.infinity, 110),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: labels.map((d) => Text(d,
            style: const TextStyle(fontSize: 9.5, color: _kSub))).toList(),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: () => _openSheet(context, _TabInformes(empresaId: widget.empresaId)),
        child: const Row(children: [
          Text('Ver informes detallados',
              style: TextStyle(fontSize: 12, color: _kGreen, fontWeight: FontWeight.w500)),
          SizedBox(width: 4),
          Icon(Icons.arrow_forward_rounded, size: 14, color: _kGreen),
        ]),
      ),
    ]));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: child,
  );

  String _fmtFecha(DateTime d) {
    final dias   = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
    final meses  = ['enero','febrero','marzo','abril','mayo','junio',
        'julio','agosto','septiembre','octubre','noviembre','diciembre'];
    return '${dias[d.weekday - 1]}, ${d.day} de ${meses[d.month - 1]} de ${d.year}';
  }
}

// ── Widget auxiliar para el botón del mapa ────────────────────────────────────
class _MapButton extends StatelessWidget {
  const _MapButton();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4)]),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Text('Ver en mapa', style: TextStyle(fontSize: 10, color: _kSub)),
      SizedBox(width: 4),
      Icon(Icons.open_in_new, size: 11, color: _kSub),
    ]),
  );
}

// ── DONUT CHART ───────────────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final double trabajando;
  final double enPausa;
  const _DonutPainter({required this.trabajando, required this.enPausa});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 4;
    final stroke = r * 0.38;
    final rect   = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    const start  = -math.pi / 2;

    void arc(double start, double sweep, Color color) {
      canvas.drawArc(rect, start, sweep, false,
          Paint()..color = color..strokeWidth = stroke
              ..style = PaintingStyle.stroke..strokeCap = StrokeCap.butt);
    }

    final fin = 1.0 - trabajando - enPausa;
    arc(start, 2 * math.pi * (fin > 0 ? fin : 0), _kGray);
    arc(start + 2 * math.pi * (fin > 0 ? fin : 0),
        2 * math.pi * enPausa, _kOrange);
    arc(start + 2 * math.pi * ((fin > 0 ? fin : 0) + enPausa),
        2 * math.pi * trabajando, _kGreen);

    // Hueco interior
    canvas.drawCircle(Offset(cx, cy), r - stroke / 2,
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.trabajando != trabajando || old.enPausa != enPausa;
}

// ── LINE CHART ────────────────────────────────────────────────────────────────
class _LinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  const _LinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final rng  = maxV - minV == 0 ? 1.0 : maxV - minV;

    // Y labels (usando párrafos nativos — sin TextPainter)
    const yPcts = [100, 75, 50, 25, 0];
    for (int i = 0; i < yPcts.length; i++) {
      final pBuilder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 8))
        ..pushStyle(ui.TextStyle(color: const Color(0xFF9CA3AF)))
        ..addText('${yPcts[i]}%');
      final para = pBuilder.build()..layout(const ui.ParagraphConstraints(width: 28));
      canvas.drawParagraph(para, Offset(0, (size.height / 4) * i - 5));
    }

    // Grid lines
    final gridPaint = Paint()..color = const Color(0xFFF3F4F6)..strokeWidth = 0.8;
    for (int i = 0; i <= 4; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(30, y), Offset(size.width, y), gridPaint);
    }

    // Puntos del gráfico
    final pts = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = 30 + (size.width - 30) / (values.length - 1) * i;
      final y = size.height - (values[i] - minV) / rng * size.height * 0.9 - size.height * 0.05;
      pts.add(Offset(x, y));
    }

    // Área bajo la curva
    final areaPath = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) { areaPath.lineTo(p.dx, p.dy); }
    areaPath.lineTo(pts.last.dx, size.height);
    areaPath.close();
    canvas.drawPath(areaPath, Paint()
      ..color = color.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill);

    // Línea
    final linePaint = Paint()..color = color..strokeWidth = 2
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) { linePath.lineTo(pts[i].dx, pts[i].dy); }
    canvas.drawPath(linePath, linePaint);

    // Puntos circulares
    for (final p in pts) {
      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
      canvas.drawCircle(p, 4, Paint()..color = color..strokeWidth = 2
          ..style = PaintingStyle.stroke);
    }

    // Valor máximo label
    final maxIdx = values.indexOf(values.reduce(math.max));
    final maxPt  = pts[maxIdx];
    final pBuilder2 = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 9))
      ..pushStyle(ui.TextStyle(color: color, fontWeight: ui.FontWeight.bold))
      ..addText('${values[maxIdx].toStringAsFixed(0)}%');
    final para2 = pBuilder2.build()..layout(const ui.ParagraphConstraints(width: 40));
    canvas.drawParagraph(para2, Offset(maxPt.dx - 20, maxPt.dy - 16));
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.values != values;
}

// ════════════════════════════════════════════════════════════════════════════
// TAB EMPLEADOS
// ════════════════════════════════════════════════════════════════════════════
class _TabEmpleados extends StatefulWidget {
  final String empresaId;
  const _TabEmpleados({required this.empresaId});
  @override
  State<_TabEmpleados> createState() => _TabEmpleadosState();
}

class _TabEmpleadosState extends State<_TabEmpleados> {
  final _svc   = FichajeService();
  String _busq = '';

  Stream<QuerySnapshot<Map<String, dynamic>>> get _usuariosStream =>
      FirebaseFirestore.instance.collection('usuarios')
          .where('empresa_id', isEqualTo: widget.empresaId).snapshots();

  Stream<Map<String, EmpleadoFichaje>> get _fichajeMapStream =>
      FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId)
          .collection('empleados_fichaje').snapshots()
          .map((s) => {for (final d in s.docs) d.id: EmpleadoFichaje.fromFirestore(d)});

  void _configurarPIN(String uid, String nombre, EmpleadoFichaje? fichaje) {
    showDialog(context: context, builder: (ctx) => _DialogConfigurarPIN(
        uid: uid,
        nombre: nombre,
        pinActual: fichaje?.pin,
        jornadaActual: fichaje?.jornadaDiaria ?? 480,
        horarioEntrada: fichaje?.horarioEntrada,
        horarioSalida: fichaje?.horarioSalida,
        diasLaborables: fichaje?.diasLaborables,
        empresaId: widget.empresaId,
        svc: _svc));
  }

  Future<void> _toggleActivo(EmpleadoFichaje emp) async {
    try {
      await _svc.actualizarEmpleado(
          empresaId: widget.empresaId, uid: emp.uid, activo: !emp.activo);
      if (mounted) {
        if (emp.activo) {
          FluxToast.aviso(context, 'Empleado desactivado');
        } else {
          FluxToast.exito(context, 'Empleado activado');
        }
      }
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Header ──────────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _kBorder)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Empleados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _kText)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => _DialogAltaEmpleado(
                  empresaId: widget.empresaId,
                  svc: _svc,
                ),
              ),
              icon: const Icon(Icons.person_add_outlined, size: 14),
              label: const Text('Dar de alta', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kGreen,
                side: const BorderSide(color: _kGreen),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          // Buscador
          TextField(
            onChanged: (v) => setState(() => _busq = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Buscar empleado...',
              hintStyle: const TextStyle(fontSize: 13, color: _kSub),
              prefixIcon: const Icon(Icons.search, size: 18, color: _kSub),
              filled: true, fillColor: _kBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _kGreen)),
              contentPadding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              isDense: true,
            ),
          ),
        ]),
      ),

      // ── Lista ────────────────────────────────────────────────────────────
      Expanded(
        child: StreamBuilder<Map<String, EmpleadoFichaje>>(
          stream: _fichajeMapStream,
          builder: (context, fichajeSnap) {
            final fichajeMap = fichajeSnap.data ?? {};
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _usuariosStream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _kGreen));
                }
                final docs = (snap.data?.docs ?? [])
                    .where((d) => d.data()['estado'] != 'baja')
                    .where((d) {
                      if (_busq.isEmpty) return true;
                      final n = ((d.data()['nombre'] as String?) ?? '').toLowerCase();
                      return n.contains(_busq);
                    })
                    .toList()
                  ..sort((a, b) => ((a.data()['nombre'] as String?) ?? '')
                      .compareTo((b.data()['nombre'] as String?) ?? ''));

                if (docs.isEmpty) return Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 56, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(_busq.isEmpty ? 'Sin empleados' : 'Sin resultados',
                        style: const TextStyle(color: _kSub, fontSize: 15)),
                  ],
                ));

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final doc    = docs[i];
                    final data   = doc.data();
                    final uid    = doc.id;
                    final nombre = (data['nombre'] as String?) ?? 'Sin nombre';
                    final rol    = (data['rol'] as String?) ?? (data['puesto'] as String?) ?? '';
                    final fichaje   = fichajeMap[uid];
                    final tienePIN  = fichaje != null;
                    final pinActivo = tienePIN && fichaje.activo;
                    final ini       = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      child: Row(children: [
                        // Avatar con indicador de estado
                        Stack(children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: pinActivo
                                ? _kGreen.withValues(alpha: 0.12)
                                : const Color(0xFFF3F4F6),
                            child: Text(ini, style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold,
                              color: pinActivo ? _kGreen : _kSub,
                            )),
                          ),
                          if (tienePIN) Positioned(bottom: 0, right: 0,
                            child: Container(width: 11, height: 11,
                              decoration: BoxDecoration(
                                color: pinActivo ? _kGreen : _kGray,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ))),
                        ]),
                        const SizedBox(width: 12),
                        // Info
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre, style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600, color: _kText)),
                            if (rol.isNotEmpty) Text(rol,
                                style: const TextStyle(fontSize: 11, color: _kSub)),
                            const SizedBox(height: 4),
                            if (tienePIN)
                              Row(children: [
                                const Icon(Icons.pin_outlined, size: 12, color: _kSub),
                                const SizedBox(width: 3),
                                Text('PIN: ${fichaje.pin}',
                                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace',
                                        color: _kSub, letterSpacing: 1.5)),
                                const SizedBox(width: 8),
                                Text('Jornada: ${fichaje.jornadaDiaria ~/ 60}h',
                                    style: const TextStyle(fontSize: 11, color: _kSub)),
                              ])
                            else
                              const Text('Sin PIN configurado',
                                  style: TextStyle(fontSize: 11, color: _kOrange)),
                          ],
                        )),
                        // Controles
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          // Badge estado
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: pinActivo
                                  ? _kGreen.withValues(alpha: 0.1)
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tienePIN ? (pinActivo ? 'Activo' : 'Inactivo') : 'Sin PIN',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                  color: pinActivo ? _kGreen : _kGray),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Botones acción
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            if (tienePIN) ...[
                              _empBtn(
                                icon: pinActivo ? Icons.person_off_outlined : Icons.person_add_outlined,
                                color: pinActivo ? _kOrange : _kGreen,
                                tooltip: pinActivo ? 'Desactivar' : 'Activar',
                                onTap: () => _toggleActivo(fichaje),
                              ),
                              const SizedBox(width: 4),
                            ],
                            _empBtn(
                              icon: tienePIN ? Icons.edit_outlined : Icons.add_rounded,
                              color: _kSub,
                              tooltip: tienePIN ? 'Editar' : 'Configurar PIN',
                              onTap: () => _configurarPIN(uid, nombre, fichaje),
                            ),
                          ]),
                        ]),
                      ]),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _empBtn({required IconData icon, required Color color,
      required String tooltip, required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Tooltip(
          message: tooltip,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// DIALOG: CONFIGURAR PIN (unchanged)
// ════════════════════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════════════════════
// DIÁLOGO ALTA EMPLEADO EN FICHAJES
// Permite dar de alta empleados con cuenta de app O empleados externos (solo kiosk).
// ════════════════════════════════════════════════════════════════════════════

class _DialogAltaEmpleado extends StatefulWidget {
  final String empresaId;
  final FichajeService svc;
  const _DialogAltaEmpleado({required this.empresaId, required this.svc});
  @override
  State<_DialogAltaEmpleado> createState() => _DialogAltaEmpleadoState();
}

class _DialogAltaEmpleadoState extends State<_DialogAltaEmpleado> {
  // Modo: 'app' = tiene cuenta, 'externo' = solo kiosk
  String _modo = 'app';

  // Para modo 'app': usuario seleccionado
  String? _uidSeleccionado;
  String? _nombreSeleccionado;

  // Para modo 'externo': nombre libre
  final _nombreCtrl = TextEditingController();

  // Comunes
  final _pinCtrl    = TextEditingController();
  final _formKey    = GlobalKey<FormState>();
  int _jornadaDiaria = 480;
  bool _guardando    = false;
  bool _verPin       = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    // Guardia explícita: en modo 'app' siempre se necesita usuario seleccionado
    if (_modo == 'app' && _uidSeleccionado == null) {
      FluxToast.error(context, 'Selecciona un empleado de la lista');
      return;
    }
    final nombre = _modo == 'app' ? (_nombreSeleccionado ?? '') : _nombreCtrl.text.trim();
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
        FluxToast.error(context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(children: [
        Icon(Icons.how_to_reg_outlined, color: _kGreen),
        SizedBox(width: 10),
        Text('Dar de alta en fichajes'),
      ]),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // ── Selector de modo ─────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: _ModoChip(
                    label: 'Tiene cuenta en la app',
                    icon: Icons.phone_android_outlined,
                    activo: _modo == 'app',
                    onTap: () => setState(() { _modo = 'app'; _uidSeleccionado = null; _nombreSeleccionado = null; }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModoChip(
                    label: 'Solo kiosk (sin cuenta)',
                    icon: Icons.tablet_outlined,
                    activo: _modo == 'externo',
                    onTap: () => setState(() { _modo = 'externo'; _uidSeleccionado = null; }),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Campo nombre / selector usuario ──────────────────────────
              if (_modo == 'app') ...[
                _SelectorUsuarioApp(
                  empresaId: widget.empresaId,
                  svc: widget.svc,
                  onSeleccionado: (uid, nombre) => setState(() {
                    _uidSeleccionado   = uid;
                    _nombreSeleccionado = nombre;
                  }),
                  uidSeleccionado: _uidSeleccionado,
                  nombreSeleccionado: _nombreSeleccionado,
                ),
              ] else ...[
                TextFormField(
                  controller: _nombreCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo *',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
                ),
              ],
              const SizedBox(height: 12),

              // ── PIN ──────────────────────────────────────────────────────
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
                    icon: Icon(_verPin ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                    onPressed: () => setState(() => _verPin = !_verPin),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length != 4) return 'Debe tener exactamente 4 dígitos';
                  if (!RegExp(r'^\d{4}$').hasMatch(v)) return 'Solo números';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ── Jornada ──────────────────────────────────────────────────
              DropdownButtonFormField<int>(
                value: _jornadaDiaria,
                decoration: const InputDecoration(
                  labelText: 'Jornada diaria',
                  prefixIcon: Icon(Icons.schedule_outlined),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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

              // ── Info box ─────────────────────────────────────────────────
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline, size: 15, color: _kGreen),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _modo == 'app'
                        ? 'El empleado usará este PIN en el tablet kiosk. También puede fichar desde su propia app.'
                        : 'Este empleado solo podrá fichar en el tablet kiosk con su PIN. No tendrá acceso a la app.',
                    style: const TextStyle(fontSize: 11, color: _kGreen),
                  )),
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
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded, size: 16),
          label: const Text('Dar de alta'),
          style: FilledButton.styleFrom(backgroundColor: _kGreen),
        ),
      ],
    );
  }
}

// ── Chip selector de modo ─────────────────────────────────────────────────────
class _ModoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool activo;
  final VoidCallback onTap;
  const _ModoChip({required this.label, required this.icon, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: activo ? _kGreen.withValues(alpha: 0.1) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: activo ? _kGreen : _kBorder, width: activo ? 1.5 : 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: activo ? _kGreen : _kSub),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
                color: activo ? _kGreen : _kSub)),
      ]),
    ),
  );
}

// ── Selector de usuario de la app ─────────────────────────────────────────────
class _SelectorUsuarioApp extends StatefulWidget {
  final String empresaId;
  final FichajeService svc;
  final String? uidSeleccionado;
  final String? nombreSeleccionado;
  final Function(String uid, String nombre) onSeleccionado;
  const _SelectorUsuarioApp({required this.empresaId, required this.svc,
      required this.onSeleccionado, this.uidSeleccionado, this.nombreSeleccionado});

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
      final [usSnap, empSnap] = await Future.wait([
        FirebaseFirestore.instance.collection('usuarios')
            .where('empresa_id', isEqualTo: widget.empresaId)
            .get(),
        FirebaseFirestore.instance.collection('empresas').doc(widget.empresaId)
            .collection('empleados_fichaje').get(),
      ]);
      if (!mounted) return;
      setState(() {
        _conPIN = {for (final d in (empSnap as QuerySnapshot).docs) d.id};
        _usuarios = (usSnap as QuerySnapshot).docs
            .where((d) => (d.data() as Map)['estado'] != 'baja')
            .map((d) => {'uid': d.id, 'nombre': (d.data() as Map)['nombre'] as String? ?? ''})
            .toList()
          ..sort((a, b) => a['nombre']!.compareTo(b['nombre']!));
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() { _cargando = false; _errorCarga = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const SizedBox(height: 48, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kGreen)));
    }
    if (_errorCarga) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200)),
        child: Row(children: [
          Icon(Icons.wifi_off_rounded, size: 14, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text('No se pudo cargar la lista. Comprueba la conexión.',
              style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
          TextButton(onPressed: () => setState(() { _cargando = true; _errorCarga = false; _cargar(); }),
              child: const Text('Reintentar', style: TextStyle(fontSize: 11))),
        ]),
      );
    }
    final sinPIN = _usuarios.where((u) => !_conPIN.contains(u['uid'])).toList();
    if (sinPIN.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(8)),
        child: const Text('Todos los empleados con cuenta ya tienen PIN. Usa el modo "Solo kiosk" para añadir empleados sin cuenta.',
            style: TextStyle(fontSize: 12, color: _kSub), textAlign: TextAlign.center),
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
      items: sinPIN.map((u) => DropdownMenuItem<String>(
        value: u['uid'],
        child: Text(u['nombre']!, style: const TextStyle(fontSize: 13)),
      )).toList(),
      validator: (v) => v == null ? 'Selecciona un empleado' : null,
      onChanged: (uid) {
        if (uid == null) return;
        final nombre = sinPIN.firstWhere((u) => u['uid'] == uid)['nombre'] ?? '';
        widget.onSeleccionado(uid, nombre);
      },
    );
  }
}

class _DialogConfigurarPIN extends StatefulWidget {
  final String uid, nombre, empresaId;
  final String? pinActual;
  final int jornadaActual;
  final String? horarioEntrada;
  final String? horarioSalida;
  final List<bool>? diasLaborables;
  final FichajeService svc;
  const _DialogConfigurarPIN({
    required this.uid, required this.nombre, required this.pinActual,
    required this.jornadaActual, required this.empresaId, required this.svc,
    this.horarioEntrada, this.horarioSalida, this.diasLaborables,
  });
  @override
  State<_DialogConfigurarPIN> createState() => _DialogConfigurarPINState();
}

class _DialogConfigurarPINState extends State<_DialogConfigurarPIN> {
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
    _entradaCtrl = TextEditingController(text: widget.horarioEntrada ?? '09:00');
    _salidaCtrl  = TextEditingController(text: widget.horarioSalida  ?? '17:00');
    _jornadaDiaria = widget.jornadaActual;
    _dias = List.from(widget.diasLaborables ?? [true, true, true, true, true, false, false]);
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
    title: Text(widget.pinActual == null ? 'Configurar acceso' : 'Parámetros del empleado'),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        const SizedBox(height: 16),
        Form(key: _formKey, child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── PIN ──────────────────────────────────────────────────────────
          TextFormField(
            controller: _pinCtrl,
            decoration: const InputDecoration(
                labelText: 'PIN (4 dígitos)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.pin_outlined)),
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
          // ── Jornada ──────────────────────────────────────────────────────
          DropdownButtonFormField<int>(
            value: _jornadaDiaria,
            decoration: const InputDecoration(
                labelText: 'Jornada diaria',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.schedule),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
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
          // ── Horario habitual ──────────────────────────────────────────────
          const Align(alignment: Alignment.centerLeft,
            child: Text('Horario habitual',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText))),
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
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
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          // ── Días laborables ───────────────────────────────────────────────
          const Align(alignment: Alignment.centerLeft,
            child: Text('Días laborables',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kText))),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final activo = _dias[i];
              return GestureDetector(
                onTap: () => setState(() => _dias[i] = !_dias[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: activo ? _kGreen : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: activo ? _kGreen : _kBorder),
                  ),
                  child: Center(child: Text(_kDiaLabels[i],
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: activo ? Colors.white : _kSub))),
                ),
              );
            }),
          ),
        ])),
      ])),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
      ElevatedButton(
        onPressed: _guardando ? null : _guardar,
        style: ElevatedButton.styleFrom(backgroundColor: _kGreen, foregroundColor: Colors.white),
        child: _guardando
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
        horarioEntrada: _entradaCtrl.text.isNotEmpty ? _entradaCtrl.text : null,
        horarioSalida:  _salidaCtrl.text.isNotEmpty  ? _salidaCtrl.text  : null,
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

// ════════════════════════════════════════════════════════════════════════════
// TAB INFORMES (unchanged logic, new wrapper)
// ════════════════════════════════════════════════════════════════════════════
class _ResumenEmpleadoMes {
  final String uid, nombre;
  final bool activo;
  final int dias, minutosNetos, minutosPlani, minutosExtra, numPausas, minutosPausa, incidencias;
  const _ResumenEmpleadoMes({required this.uid, required this.nombre, required this.activo,
    required this.dias, required this.minutosNetos, required this.minutosPlani,
    required this.minutosExtra, required this.numPausas,
    required this.minutosPausa, required this.incidencias});
  String get horasStr     => _m(minutosNetos);
  String get horasPlanifStr => minutosPlani > 0 ? _m(minutosPlani) : '—';
  String get horasExtraStr {
    if (minutosPlani > 0) { final e = minutosNetos - minutosPlani; return e > 0 ? _m(e) : '—'; }
    return minutosExtra > 0 ? _m(minutosExtra) : '—';
  }
  String get pausasStr => numPausas > 0 ? '$numPausas (${_m(minutosPausa)})' : '—';
  static String _m(int min) => '${min ~/ 60}h ${(min % 60).toString().padLeft(2,'0')}m';
}

class _TabInformes extends StatefulWidget {
  final String empresaId;
  const _TabInformes({required this.empresaId});
  @override
  State<_TabInformes> createState() => _TabInformesState();
}

class _TabInformesState extends State<_TabInformes> {
  final _svc = FichajeService();
  late DateTime _mes;
  bool _cargando = false;
  List<_ResumenEmpleadoMes> _datos = [];
  String _empresaNombre = '';

  static const _bandColor = Color(0xFF2E5A50);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _mes = DateTime(now.year, now.month);
    _cargar();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    setState(() => _cargando = true);
    try {
      final empDoc = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId).get();
      _empresaNombre = (empDoc.data()?['nombre'] as String? ?? '').isNotEmpty
          ? (empDoc.data()!['nombre'] as String)
          : 'Mi empresa';

      final empSnap = await FirebaseFirestore.instance
          .collection('empresas').doc(widget.empresaId)
          .collection('empleados_fichaje').orderBy('nombre').get();
      final empleados = empSnap.docs.map(EmpleadoFichaje.fromFirestore).toList();
      final jornadaMap = {for (final e in empleados) e.uid: e.jornadaDiaria};
      final fichajes = await _svc.fichajesMes(empresaId: widget.empresaId, mes: _mes);
      final Map<String, Fichaje> efectivos = {};
      for (final f in fichajes) {
        final key = '${f.empleadoId}_${f.fecha}';
        final actual = efectivos[key];
        if (actual == null) { efectivos[key] = f; }
        else if (f.esCorreccion && !actual.esCorreccion) { efectivos[key] = f; }
      }
      final Map<String, int> mins={}, dias={}, minsExtra={}, numPausas={}, minsPausa={}, incidencias={};
      final hoyKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      for (final f in efectivos.values) {
        final uid = f.empleadoId;
        mins[uid]      = (mins[uid]      ?? 0) + (f.tiempoNeto?.inMinutes ?? 0);
        dias[uid]      = (dias[uid]      ?? 0) + 1;
        if (f.tipoHoras == TipoHoras.extraordinarias) {
          minsExtra[uid] = (minsExtra[uid] ?? 0) + (f.tiempoNeto?.inMinutes ?? 0);
        }
        numPausas[uid] = (numPausas[uid] ?? 0) + f.pausas.where((p) => p.fin != null).length;
        minsPausa[uid] = (minsPausa[uid] ?? 0) + f.minutosPausa;
        if (f.salida == null && f.fecha != hoyKey) {
          incidencias[uid] = (incidencias[uid] ?? 0) + 1;
        }
      }
      final datos = empleados.map((e) => _ResumenEmpleadoMes(
        uid: e.uid, nombre: e.nombre, activo: e.activo,
        dias: dias[e.uid] ?? 0, minutosNetos: mins[e.uid] ?? 0,
        minutosPlani: (jornadaMap[e.uid] ?? 480) * (dias[e.uid] ?? 0),
        minutosExtra: minsExtra[e.uid] ?? 0,
        numPausas: numPausas[e.uid] ?? 0, minutosPausa: minsPausa[e.uid] ?? 0,
        incidencias: incidencias[e.uid] ?? 0,
      )).toList()..sort((a, b) => a.nombre.compareTo(b.nombre));
      if (mounted) setState(() => _datos = datos);
    } catch (e) {
      if (mounted) FluxToast.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt       = DateFormat('MMMM yyyy', 'es_ES');
    final mesTxt    = fmt.format(_mes);
    final mesLabel  = '${mesTxt[0].toUpperCase()}${mesTxt.substring(1)}';
    final totalMins = _datos.fold(0, (s, d) => s + d.minutosNetos);
    final totalDias = _datos.fold(0, (s, d) => s + d.dias);
    final conDias   = _datos.where((d) => d.dias > 0).length;
    final incTotal  = _datos.fold(0, (s, d) => s + d.incidencias);
    final avgMin    = conDias > 0 ? totalMins ~/ conDias : 0;
    final hoyStr    = DateFormat('dd/MM/yyyy').format(DateTime.now());

    return Column(children: [
      // ── Barra de control ──────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _kBorder)),
        ),
        child: Row(children: [
          const Text('Informes de horas',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _kText)),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                  context: context, initialDate: _mes,
                  firstDate: DateTime(2020), lastDate: DateTime.now(),
                  locale: const Locale('es', 'ES'));
              if (picked != null && mounted) {
                setState(() => _mes = DateTime(picked.year, picked.month));
                _cargar();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(border: Border.all(color: _kBorder),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_month_outlined, size: 14, color: _kGreen),
                const SizedBox(width: 6),
                Text(mesLabel, style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w600, color: _kText)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 16, color: _kSub),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _datos.isEmpty ? null : _descargarPdf,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.picture_as_pdf_outlined, size: 14, color: _kGreen),
                SizedBox(width: 5),
                Text('PDF', style: TextStyle(fontSize: 12, color: _kGreen,
                    fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: _cargar,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(border: Border.all(color: _kBorder),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.refresh_rounded, size: 16, color: _kSub),
            ),
          ),
        ]),
      ),

      if (_cargando) const LinearProgressIndicator(color: _kGreen, minHeight: 2),

      // ── Documento estilo informe (D1 Clásico Corporativo) ─────────────
      if (!_cargando && _datos.isEmpty)
        const Expanded(child: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, size: 56, color: Color(0xFFE5E7EB)),
            SizedBox(height: 12),
            Text('Sin datos para este mes', style: TextStyle(color: _kSub, fontSize: 14)),
          ],
        )))
      else Expanded(child: Container(
        color: const Color(0xFFF0F2F5),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 40, offset: const Offset(0, 12))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // Banda de color
                Container(
                  padding: const EdgeInsets.fromLTRB(40, 30, 40, 30),
                  color: _bandColor,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(_empresaNombre.toUpperCase(),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                              color: Colors.white, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      const Text('Departamento de Recursos Humanos',
                          style: TextStyle(fontSize: 11, color: Color(0xFFD0E5DE))),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      const Text('INFORME DE HORAS',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text('$mesLabel  ·  Generado $hoyStr',
                          style: const TextStyle(fontSize: 11, color: Colors.white70)),
                    ]),
                  ]),
                ),

                // Cuerpo del documento
                Padding(
                  padding: const EdgeInsets.fromLTRB(40, 30, 40, 40),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // KPIs
                    Row(children: [
                      _docKpi('Empleados activos', '$conDias'),
                      const SizedBox(width: 12),
                      _docKpi('Total horas', _fmtMin(totalMins)),
                      const SizedBox(width: 12),
                      _docKpi('Media por empleado', _fmtMin(avgMin)),
                      const SizedBox(width: 12),
                      _docKpi('Incidencias', '$incTotal',
                          accent: incTotal > 0 ? Colors.red : null),
                    ]),
                    const SizedBox(height: 28),

                    // Tabla
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(3.2),
                          1: FlexColumnWidth(1.8),
                          2: FlexColumnWidth(2.2),
                          3: FlexColumnWidth(1.8),
                          4: FlexColumnWidth(1.4),
                          5: FlexColumnWidth(2),
                        },
                        border: TableBorder.symmetric(
                            inside: const BorderSide(color: Color(0xFFEEEEEE))),
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(color: _bandColor),
                            children: ['EMPLEADO', 'H. PLANIF.', 'H. TRABAJADAS',
                              'H. EXTRA', 'DÍAS', 'INCIDENCIAS']
                                .map((h) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              child: Text(h, style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.bold,
                                  color: Colors.white, letterSpacing: 0.4)),
                            )).toList(),
                          ),
                          ..._datos.asMap().entries.map((entry) {
                            final i = entry.key; final d = entry.value;
                            final bg = i.isEven
                                ? const Color(0xFFF8F9FB) : Colors.white;
                            return TableRow(
                              decoration: BoxDecoration(color: bg),
                              children: [
                                _tcell(d.nombre, bold: true),
                                _tcell(d.horasPlanifStr),
                                _tcell(d.horasStr,
                                    color: d.minutosNetos > 0 ? _bandColor : null,
                                    bold: d.minutosNetos > 0),
                                _tcell(d.horasExtraStr,
                                    color: d.minutosExtra > 0
                                        ? const Color(0xFFF59E0B) : null),
                                _tcell('${d.dias}d'),
                                _tcell(d.incidencias > 0
                                    ? '⚠ ${d.incidencias}' : '—',
                                    color: d.incidencias > 0 ? Colors.red : null),
                              ],
                            );
                          }),
                          TableRow(
                            decoration: const BoxDecoration(
                                color: Color(0xFFF5F5F5)),
                            children: [
                              _tcell('TOTAL',
                                  bold: true, isLabel: true),
                              _tcell('—'),
                              _tcell(_fmtMin(totalMins),
                                  bold: true, color: _bandColor),
                              _tcell('—'),
                              _tcell('${totalDias}d', bold: true),
                              _tcell('$incTotal',
                                  bold: incTotal > 0,
                                  color: incTotal > 0 ? Colors.red : null),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Firmas
                    const SizedBox(height: 44),
                    Row(children: [
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const SizedBox(height: 40),
                        const Divider(color: Color(0xFF999999)),
                        const SizedBox(height: 6),
                        const Text('Firma del responsable de RRHH',
                            style: TextStyle(fontSize: 10.5,
                                color: Color(0xFF666666))),
                      ])),
                      const SizedBox(width: 48),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const SizedBox(height: 40),
                        const Divider(color: Color(0xFF999999)),
                        const SizedBox(height: 6),
                        const Text('Visto bueno — Dirección',
                            style: TextStyle(fontSize: 10.5,
                                color: Color(0xFF666666))),
                      ])),
                    ]),
                  ]),
                ),
              ]),
            ),
          )),
        ),
      )),
    ]);
  }

  Widget _docKpi(String label, String valor, {Color? accent}) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(4)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF999999),
            letterSpacing: 0.4)),
        const SizedBox(height: 5),
        Text(valor, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
            color: accent ?? _bandColor)),
      ]),
    ),
  );

  static Widget _tcell(String text,
      {bool bold = false, Color? color, bool isLabel = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Text(text, style: TextStyle(
        fontSize: isLabel ? 10 : 12,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: color ?? (isLabel ? const Color(0xFF8A8A8A) : const Color(0xFF1A1A1A)),
      )),
    );

  static String _fmtMin(int min) =>
      '${min ~/ 60}h ${(min % 60).toString().padLeft(2, '0')}m';

  Future<void> _descargarPdf() async {
    final fmt = DateFormat('MMMM yyyy', 'es_ES');
    final mesTxt = fmt.format(_mes);
    final titulo = 'Informe de Horas — ${mesTxt[0].toUpperCase()}${mesTxt.substring(1)}';
    String colorHex = '#22C55E';
    try {
      final p = await ptSvc.PdfTemplateService().getPlantillaDefault(
          widget.empresaId, ptModel.TipoDocumentoPdf.horasEmpleado)
          ?? await ptSvc.PdfTemplateService().getPlantillaDefault(
              widget.empresaId, ptModel.TipoDocumentoPdf.fichajes);
      if (p != null) colorHex = p.colorPrimario;
    } catch (_) {}
    PdfColor pdfColor(String hex) {
      try { return PdfColor.fromHex(hex); } catch (_) { return PdfColor.fromHex('#22C55E'); }
    }
    final colPrimary = pdfColor(colorHex);
    final pdf = pw.Document();
    final totalMins = _datos.fold(0, (s, d) => s + d.minutosNetos);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => [
        pw.Text(titulo, style: pw.TextStyle(fontSize: 16,
            fontWeight: pw.FontWeight.bold, color: colPrimary)),
        pw.SizedBox(height: 4),
        pw.Text('Generado: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text('Total horas: ${_fmtMin(totalMins)}  ·  Empleados: ${_datos.where((d) => d.dias > 0).length}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headers: ['Empleado', 'H. Planif.', 'H. Trab.', 'H. Extra',
              'Pausas', 'Días', 'Incidencias'],
          data: _datos.map((d) => [d.nombre, d.horasPlanifStr, d.horasStr,
            d.horasExtraStr, d.pausasStr, '${d.dias}d',
            d.incidencias > 0 ? '⚠ ${d.incidencias}' : '—']).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold,
              color: PdfColors.white, fontSize: 8),
          headerDecoration: pw.BoxDecoration(color: colPrimary),
          cellStyle: const pw.TextStyle(fontSize: 8),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DIALOGS (unchanged)
// ════════════════════════════════════════════════════════════════════════════
class _DialogFichajesEmpleado extends StatelessWidget {
  final String empresaId, empleadoId, empleadoNombre;
  final DateTime mes;
  final FichajeService svc;
  final VoidCallback onCorregido;
  const _DialogFichajesEmpleado({required this.empresaId, required this.empleadoId,
    required this.empleadoNombre, required this.mes, required this.svc, required this.onCorregido});

  @override
  Widget build(BuildContext context) {
    final mesTxt = DateFormat('MMMM yyyy', 'es_ES').format(mes);
    return AlertDialog(
      title: Text(empleadoNombre),
      content: SizedBox(width: 420, child: FutureBuilder<List<Fichaje>>(
        future: svc.fichajesMes(empresaId: empresaId, mes: mes),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final todos = (snap.data ?? []).where((f) => f.empleadoId == empleadoId).toList();
          final Map<String, Fichaje> efectivos = {};
          for (final f in todos) {
            final actual = efectivos[f.fecha];
            if (actual == null) { efectivos[f.fecha] = f; }
            else if (f.esCorreccion && !actual.esCorreccion) { efectivos[f.fecha] = f; }
          }
          final lista = efectivos.values.toList()..sort((a, b) => a.fecha.compareTo(b.fecha));
          if (lista.isEmpty) return Center(child: Text('Sin fichajes en ${mesTxt.toLowerCase()}',
              style: const TextStyle(color: Colors.grey)));
          return ListView.separated(
            shrinkWrap: true, itemCount: lista.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (c, i) {
              final f = lista[i];
              final fmtH = DateFormat('HH:mm');
              final fmtD = DateFormat('EEE d MMM', 'es_ES');
              final fecha  = DateTime.parse(f.fecha);
              final entH   = f.entrada != null ? fmtH.format(f.entrada!.toDate().toLocal()) : '—';
              final salH   = f.salida  != null ? fmtH.format(f.salida!.toDate().toLocal())  : '—';
              final neto   = f.tiempoNeto;
              final nTxt   = neto != null ? '${neto.inHours}h ${(neto.inMinutes % 60).toString().padLeft(2,'0')}m' : '—';
              return ListTile(
                dense: true,
                title: Text(fmtD.format(fecha), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text('$entH → $salH  ·  $nTxt', style: const TextStyle(fontSize: 12)),
                leading: f.esCorreccion
                    ? const Icon(Icons.edit_note, color: Colors.orange, size: 18)
                    : const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () async {
                    await showDialog(context: c, builder: (_) =>
                        _DialogEditarFichaje(empresaId: empresaId, fichaje: f, svc: svc));
                    if (c.mounted) Navigator.pop(c);
                    onCorregido();
                  }),
              );
            });
        })),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
    );
  }
}

class _DialogEditarFichaje extends StatefulWidget {
  final String empresaId;
  final Fichaje fichaje;
  final FichajeService svc;
  const _DialogEditarFichaje({required this.empresaId, required this.fichaje, required this.svc});
  @override
  State<_DialogEditarFichaje> createState() => _DialogEditarFichajeState();
}

class _DialogEditarFichajeState extends State<_DialogEditarFichaje> {
  late TimeOfDay _entrada, _salida;
  final _motivoCtrl = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final e = widget.fichaje.entrada?.toDate().toLocal() ?? DateTime.now();
    final s = widget.fichaje.salida?.toDate().toLocal()  ?? DateTime.now();
    _entrada = TimeOfDay(hour: e.hour, minute: e.minute);
    _salida  = TimeOfDay(hour: s.hour, minute: s.minute);
  }

  @override
  void dispose() { _motivoCtrl.dispose(); super.dispose(); }

  Future<void> _pickTime(bool esEntrada) async {
    final picked = await showTimePicker(context: context,
        initialTime: esEntrada ? _entrada : _salida);
    if (picked != null) setState(() => esEntrada ? _entrada = picked : _salida = picked);
  }

  @override
  Widget build(BuildContext context) {
    final fmtD = DateFormat("EEEE d 'de' MMMM", 'es_ES');
    final fecha = DateTime.parse(widget.fichaje.fecha);
    return AlertDialog(
      title: Text('Corregir fichaje — ${fmtD.format(fecha)}', style: const TextStyle(fontSize: 15)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.fichaje.empleadoNombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _TimeButton(label: 'Entrada', time: _entrada, onTap: () => _pickTime(true))),
          const SizedBox(width: 12),
          Expanded(child: _TimeButton(label: 'Salida', time: _salida, onTap: () => _pickTime(false))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _motivoCtrl,
          decoration: const InputDecoration(labelText: 'Motivo de corrección *',
              border: OutlineInputBorder(), prefixIcon: Icon(Icons.note_alt_outlined)),
          maxLines: 2),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _guardando ? null : _guardar,
          child: _guardando ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Guardar corrección')),
      ],
    );
  }

  Future<void> _guardar() async {
    final motivo = _motivoCtrl.text.trim();
    if (motivo.isEmpty) {
      FluxToast.error(context, 'El motivo es obligatorio');
      return;
    }
    setState(() => _guardando = true);
    try {
      final fechaBase = DateTime.parse(widget.fichaje.fecha);
      await widget.svc.corregirFichaje(
        empresaId: widget.empresaId,
        fichajeOriginalId: widget.fichaje.id,
        motivo: motivo, corregidoPorUid: 'admin',
        nuevaEntrada: Timestamp.fromDate(DateTime(fechaBase.year, fechaBase.month,
            fechaBase.day, _entrada.hour, _entrada.minute)),
        nuevaSalida: Timestamp.fromDate(DateTime(fechaBase.year, fechaBase.month,
            fechaBase.day, _salida.hour, _salida.minute)),
        nuevasPausas: widget.fichaje.pausas,
      );
      if (mounted) {
        Navigator.pop(context);
        FluxToast.exito(context, 'Corrección guardada');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        FluxToast.error(context, 'Error: $e');
      }
    }
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeButton({required this.label, required this.time, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
      child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text('$hh:$mm', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

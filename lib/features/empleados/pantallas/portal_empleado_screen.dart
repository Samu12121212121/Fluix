import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/flux_toast.dart';
import '../../fichajes/pantallas/gestion_fichajes_screen.dart';
import '../../fichajes/servicios/fichaje_service.dart';
import '../../vacaciones/pantallas/nueva_solicitud_form.dart';
import '../../vacaciones/pantallas/vacaciones_screen.dart';
import '../widgets/baja_laboral_widget.dart';
import '../widgets/canal_comunicacion_widget.dart';
import '../widgets/documentos_empleado_widget.dart';
import '../widgets/nominas_empleado_widget.dart' show NominasEmpleadoWidget;

// ═════════════════════════════════════════════════════════════════════════════
// PORTAL DEL EMPLEADO — Diseño tipo dashboard HR
// Sin Scaffold propio. isDark recibido del padre.
// ═════════════════════════════════════════════════════════════════════════════

class PortalEmpleadoScreen extends StatelessWidget {
  final String  empresaId;
  final String? empleadoUid;
  final bool    modoAdmin;
  final bool    isDark;

  const PortalEmpleadoScreen({
    super.key,
    required this.empresaId,
    this.empleadoUid,
    this.modoAdmin = false,
    this.isDark    = false,
  });

  String get _uid =>
      empleadoUid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Paleta ────────────────────────────────────────────────────────────────
  Color get _bg      => isDark ? const Color(0xFF0F172A) : const Color(0xFFF5F7FA);
  Color get _surf    => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _text    => isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _sub     => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _border  => isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  static const _green  = Color(0xFF22C55E);
  static const _blue   = Color(0xFF3B82F6);
  static const _amber  = Color(0xFFF59E0B);
  static const _red    = Color(0xFFEF4444);
  static const _purple = Color(0xFF8B5CF6);

  DocumentReference<Map<String, dynamic>> get _horarioRef =>
      FirebaseFirestore.instance
          .collection('empresas').doc(empresaId)
          .collection('horarios_empleados').doc(_uid);

  @override
  Widget build(BuildContext context) {
    // Guard: si NO es modoAdmin, verificar que el usuario actual es el empleado
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (!modoAdmin && currentUid.isNotEmpty && currentUid != _uid) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text('Acceso restringido', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
          const SizedBox(height: 6),
          const Text('Este portal es solo para el empleado asignado.',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        ],
      ));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('usuarios').doc(_uid).snapshots(),
      builder: (ctx, snap) {
        final emp    = snap.data?.data() as Map<String, dynamic>? ?? {};
        final nombre = emp['nombre']  as String? ?? 'Empleado';
        final baseCot= (emp['base_cotizacion'] as num?)?.toDouble() ?? 0.0;
        final hora   = DateTime.now().hour;
        final saludo = hora < 13 ? 'Hola' : hora < 20 ? 'Buenas tardes' : 'Buenas noches';
        final hoy    = DateFormat('EEEE, d MMMM yyyy', 'es_ES').format(DateTime.now());

        return ColoredBox(
          color: _bg,
          child: LayoutBuilder(builder: (ctx, cst) {
            final wide = cst.maxWidth > 700;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Saludo ────────────────────────────────────────────────
                  Text('$saludo, ${nombre.split(' ').first} 👋',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _text)),
                  const SizedBox(height: 4),
                  Text(hoy, style: TextStyle(fontSize: 13, color: _sub)),
                  const SizedBox(height: 20),

                  // ── Fila superior: Fichaje | Vacaciones ───────────────────
                  wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 6, child: _buildFichaje(context, nombre)),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: _buildVacaciones(context)),
                      ])
                    : Column(children: [
                        _buildFichaje(context, nombre),
                        const SizedBox(height: 14),
                        _buildVacaciones(context),
                      ]),
                  const SizedBox(height: 14),

                  // ── Fila media: Asistencia semana | Horario ───────────────
                  wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 6, child: _buildAsistenciaSemana()),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: _buildHorarioSemana(context)),
                      ])
                    : Column(children: [
                        _buildAsistenciaSemana(),
                        const SizedBox(height: 14),
                        _buildHorarioSemana(context),
                      ]),
                  const SizedBox(height: 24),

                  // ── Accesos rápidos ───────────────────────────────────────
                  Text('Accesos rápidos',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _text)),
                  const SizedBox(height: 12),
                  _buildAccesos(context, nombre, baseCot),

                  // ── IT (solo admin o si tiene bajas) ─────────────────────
                  if (modoAdmin) ...[
                    const SizedBox(height: 24),
                    Text('Incapacidad Temporal (IT)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _text)),
                    const SizedBox(height: 10),
                    _card(BajaLaboralWidget(
                      empleadoId: _uid,
                      baseCotizacionMesAnterior: baseCot,
                      esPropietario: true,
                    )),
                  ],

                  // ── Canal de comunicación interno ─────────────────────────
                  const SizedBox(height: 24),
                  Text('Mensajes',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _text)),
                  const SizedBox(height: 10),
                  CanalComunicacionWidget(
                    empresaId: empresaId,
                    empleadoUid: _uid,
                    empleadoNombre: nombre,
                    modoAdmin: modoAdmin,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FICHAJE DE HOY
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFichaje(BuildContext context, String nombre) {
    final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(empresaId)
          .collection('fichajes')
          .where('empleado_id', isEqualTo: _uid)
          .where('fecha', isEqualTo: hoy)
          .snapshots(),
      builder: (ctx, snap) {
        final docs  = snap.data?.docs ?? [];
        final docId = docs.isNotEmpty ? docs.first.id : null;
        final d     = docs.isNotEmpty ? docs.first.data() as Map<String, dynamic> : null;
        final tsE   = d?['entrada'] as Timestamp?;
        final tsS   = d?['salida']  as Timestamp?;
        final fichado   = tsE != null;
        final enJornada = tsE != null && tsS == null;

        String eStr = '—', sStr = '—';
        int mins = 0;
        if (tsE != null) {
          eStr = DateFormat('HH:mm').format(tsE.toDate().toLocal());
          final fin = tsS?.toDate() ?? DateTime.now();
          mins = fin.difference(tsE.toDate()).inMinutes;
        }
        if (tsS != null) sStr = DateFormat('HH:mm').format(tsS.toDate().toLocal());
        final jornadaStr = mins == 0 ? '0h'
            : '${mins ~/ 60}h ${(mins % 60).toString().padLeft(2,'0')}m';

        return _card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status row
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: fichado
                      ? (enJornada ? _green.withValues(alpha: 0.12) : _blue.withValues(alpha: 0.1))
                      : _green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.schedule_rounded,
                    color: fichado ? (enJornada ? _green : _blue) : _green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  fichado
                      ? (enJornada ? 'En jornada' : 'Jornada completada')
                      : 'No has fichado todavía',
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: fichado ? (enJornada ? _green : _blue) : _green,
                  ),
                ),
                Text(
                  fichado ? 'Fichaste a las $eStr' : 'Aún puedes fichar tu entrada.',
                  style: TextStyle(fontSize: 12, color: _sub),
                ),
              ])),
              if (!fichado)
                _FicharBtn(
                  label: 'FICHAR ENTRADA',
                  icon: Icons.login_rounded,
                  color: _blue,
                  onTap: () => _registrarEntrada(context, nombre),
                )
              else if (enJornada)
                _FicharBtn(
                  label: 'FICHAR SALIDA',
                  icon: Icons.logout_rounded,
                  color: _red,
                  onTap: () => _registrarSalida(context, docId),
                ),
            ]),
            const SizedBox(height: 16),
            Divider(color: _border, height: 1),
            const SizedBox(height: 14),
            // Entrada / Salida / Jornada
            Row(children: [
              _fichaCell('Entrada', eStr),
              _vDiv(),
              _fichaCell('Salida', sStr),
              _vDiv(),
              _fichaCell('Jornada', jornadaStr, bold: mins > 0),
            ]),
          ],
        ));
      },
    );
  }

  Widget _fichaCell(String label, String val, {bool bold = false}) =>
    Expanded(child: Column(children: [
      Text(label, style: TextStyle(fontSize: 11, color: _sub)),
      const SizedBox(height: 5),
      Text(val, style: TextStyle(fontSize: 17, fontWeight: bold ? FontWeight.bold : FontWeight.w400, color: _text)),
    ]));

  Widget _vDiv() => Container(width: 1, height: 36, color: _border,
      margin: const EdgeInsets.symmetric(horizontal: 8));

  // ══════════════════════════════════════════════════════════════════════════
  // VACACIONES
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildVacaciones(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vacaciones').doc(empresaId)
          .collection('saldos')
          .where('empleado_id', isEqualTo: _uid)
          .where('anio', isEqualTo: DateTime.now().year)
          .snapshots(),
      builder: (ctx, snap) {
        final vac = (snap.data?.docs.firstOrNull?.data() as Map<String, dynamic>?) ?? {};
        final dev   = (vac['dias_devengados']  as num?)?.toDouble() ?? 18;
        final dis   = (vac['dias_disfrutados'] as num?)?.toDouble() ?? 0;
        final plan  = (vac['dias_planificados'] as num?)?.toDouble() ?? 0;
        final pend  = (dev - dis - plan).clamp(0, 999).toDouble();
        final pct   = dev > 0 ? (dis / dev).clamp(0.0, 1.0) : 0.0;

        return _card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.beach_access_rounded, color: _blue, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Mis vacaciones',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text))),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => NuevaSolicitudForm(
                        empresaId: empresaId, empleadoIdFijo: _uid))),
                child: Text('Solicitar vacaciones',
                    style: TextStyle(fontSize: 11.5, color: _blue, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${pend.toInt()}',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _text, height: 1)),
                Text('días disponibles',
                    style: TextStyle(fontSize: 12, color: _sub)),
                const SizedBox(height: 10),
                _vacRow('${dis.toInt()} disfrutados'),
                _vacRow('${plan.toInt()} planificados'),
              ])),
              _CircularProgress(
                value: pct,
                label: '${dis.toInt()} / ${dev.toInt()}',
                sublabel: 'días del año',
                color: _green, isDark: isDark,
              ),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct, minHeight: 7,
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                color: _green,
              ),
            ),
            const SizedBox(height: 5),
            Text('${(pct * 100).toStringAsFixed(0)}% del año utilizado',
                style: TextStyle(fontSize: 10.5, color: _sub)),
          ],
        ));
      },
    );
  }

  Widget _vacRow(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(t, style: TextStyle(fontSize: 11.5, color: _sub)),
  );

  // ══════════════════════════════════════════════════════════════════════════
  // ASISTENCIA ESTA SEMANA
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAsistenciaSemana() {
    final ahora = DateTime.now();
    final lunes = ahora.subtract(Duration(days: ahora.weekday - 1));
    final dias  = List.generate(5, (i) => lunes.add(Duration(days: i)));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('empresas').doc(empresaId).collection('fichajes')
          .where('empleado_id', isEqualTo: _uid)
          .where('fecha', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(lunes))
          .where('fecha', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(
              lunes.add(const Duration(days: 4))))
          .snapshots(),
      builder: (ctx, snap) {
        final byDate = <String, Map<String, dynamic>>{};
        for (final d in snap.data?.docs ?? []) {
          final m = d.data() as Map<String, dynamic>;
          byDate[m['fecha'] as String? ?? ''] = m;
        }

        int totalMins = 0;
        for (final d in byDate.values) {
          final tsE = d['entrada'] as Timestamp?;
          final tsS = d['salida']  as Timestamp?;
          if (tsE != null && tsS != null) {
            totalMins += tsS.toDate().difference(tsE.toDate()).inMinutes;
          }
        }
        final totalStr = '${totalMins ~/ 60}h ${(totalMins % 60).toString().padLeft(2,'0')}m';

        return _card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.bar_chart_rounded, color: _purple, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Asistencia esta semana',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.calendar_today_outlined, size: 12, color: Color(0xFF64748B)),
                  SizedBox(width: 4),
                  Text('Esta semana', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  SizedBox(width: 3),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF64748B)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Text(totalStr, style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: _text, height: 1.1)),
            const SizedBox(height: 14),

            // Tabla días
            ...dias.map((fecha) {
              final key   = DateFormat('yyyy-MM-dd').format(fecha);
              final d     = byDate[key];
              final esHoy = key == DateFormat('yyyy-MM-dd').format(ahora);
              final tsE   = d?['entrada'] as Timestamp?;
              final tsS   = d?['salida']  as Timestamp?;

              String eStr = '—', sStr = '—', durStr = '—';
              if (tsE != null) eStr = DateFormat('HH:mm').format(tsE.toDate().toLocal());
              if (tsS != null) {
                sStr = DateFormat('HH:mm').format(tsS.toDate().toLocal());
                final m = tsS.toDate().difference(tsE!.toDate()).inMinutes;
                durStr = '${m ~/ 60}h ${(m % 60).toString().padLeft(2,'0')}m';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: esHoy
                      ? (isDark ? const Color(0xFF1E3A5F) : const Color(0xFFEFF6FF))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: esHoy
                      ? Border.all(color: _blue.withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(children: [
                  SizedBox(width: 32, child: Text(
                    ['Lun','Mar','Mié','Jue','Vie'][fecha.weekday - 1],
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: esHoy ? _blue : _sub),
                  )),
                  SizedBox(width: 22, child: Text(
                    DateFormat('d').format(fecha),
                    style: TextStyle(fontSize: 11, color: esHoy ? _blue : _sub),
                  )),
                  Expanded(child: tsE != null && tsS != null
                    ? _TimeBar(entrada: tsE.toDate(), salida: tsS.toDate(),
                        isDark: isDark, eStr: eStr, sStr: sStr)
                    : Row(children: [
                        Text(eStr, style: TextStyle(fontSize: 12, color: _sub)),
                        Expanded(child: Center(child: Text('—',
                            style: TextStyle(color: _sub)))),
                        Text(sStr, style: TextStyle(fontSize: 12, color: _sub)),
                      ])),
                  const SizedBox(width: 10),
                  SizedBox(width: 52, child: Text(durStr,
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                          color: tsS != null ? _text : _sub))),
                ]),
              );
            }),
            Divider(color: _border, height: 20),
            Row(children: [
              Text('Total semana', style: TextStyle(fontSize: 12.5, color: _sub)),
              const Spacer(),
              Text(totalStr, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: _text)),
            ]),
          ],
        ));
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HORARIO SEMANAL
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildHorarioSemana(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _horarioRef.snapshots(),
      builder: (ctx, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        const dias = ['lun','mar','mie','jue','vie','sab','dom'];
        const lbl  = ['LUN','MAR','MIÉ','JUE','VIE','SÁB','DOM'];
        const idx  = <String,int>{'lun':1,'mar':2,'mie':3,'jue':4,'vie':5,'sab':6,'dom':7};

        int planMins = 0;
        for (final k in dias) {
          final d = (data[k] as Map?)?.cast<String, dynamic>() ?? {};
          if (d['libre'] != true) {
            final e = d['entrada'] as String? ?? '';
            final s = d['salida']  as String? ?? '';
            if (e.isNotEmpty && s.isNotEmpty) {
              try {
                final ep = e.split(':'); final sp = s.split(':');
                planMins += (int.parse(sp[0]) * 60 + int.parse(sp[1])) -
                            (int.parse(ep[0]) * 60 + int.parse(ep[1]));
              } catch (_) {}
            }
          }
        }
        final planStr = planMins > 0
            ? '${planMins ~/ 60}h${planMins % 60 > 0 ? ' ${planMins % 60}m' : ''}'
            : '—';

        return _card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.calendar_month_rounded, color: _blue, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Mi horario esta semana',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text))),
              if (modoAdmin)
                GestureDetector(
                  onTap: () => _mostrarEditorHorario(context, data),
                  child: Text('Editar',
                      style: const TextStyle(fontSize: 11.5, color: _blue,
                          fontWeight: FontWeight.w600)),
                )
              else
                Text('Ver horario completo',
                    style: TextStyle(fontSize: 11, color: _blue, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 14),

            // Grid 7 días
            Row(children: List.generate(7, (i) {
              final key  = dias[i];
              final d    = (data[key] as Map?)?.cast<String, dynamic>() ?? {};
              final lib  = d['libre'] == true || (d['entrada'] as String? ?? '').isEmpty;
              final ent  = lib ? '' : d['entrada'] as String? ?? '';
              final sal  = lib ? '' : d['salida']  as String? ?? '';
              final esHoy = DateTime.now().weekday == (idx[key] ?? 0);

              return Expanded(child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Column(children: [
                  Text(lbl[i], style: TextStyle(
                      fontSize: 9.5, fontWeight: FontWeight.w700,
                      color: esHoy ? _blue : _sub)),
                  const SizedBox(height: 6),
                  if (lib) ...[
                    Text('—', style: TextStyle(fontSize: 11, color: _sub)),
                    const SizedBox(height: 4),
                    Text('—', style: TextStyle(fontSize: 11, color: _sub)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Libre', style: TextStyle(fontSize: 8.5, color: _sub)),
                    ),
                  ] else ...[
                    Text(ent, style: TextStyle(fontSize: 11, color: _text, fontWeight: FontWeight.w600)),
                    Container(
                      width: 1, height: 18,
                      color: esHoy ? _blue.withValues(alpha: 0.4) : _border,
                    ),
                    Text(sal, style: TextStyle(fontSize: 11, color: _text, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      decoration: BoxDecoration(
                        color: esHoy
                            ? _blue.withValues(alpha: 0.12)
                            : _green.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_calcHoras(ent, sal),
                          style: TextStyle(fontSize: 8.5,
                              color: esHoy ? _blue : _green,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ]),
              ));
            })),
            const SizedBox(height: 14),
            Divider(color: _border, height: 1),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.schedule_outlined, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text('Horas planificadas: ',
                  style: TextStyle(fontSize: 12, color: _sub)),
              Text(planStr, style: const TextStyle(
                  fontSize: 12, color: _blue, fontWeight: FontWeight.w700)),
            ]),
          ],
        ));
      },
    );
  }

  String _calcHoras(String e, String s) {
    try {
      final ep = e.split(':'); final sp = s.split(':');
      final m = (int.parse(sp[0]) * 60 + int.parse(sp[1])) -
                (int.parse(ep[0]) * 60 + int.parse(ep[1]));
      if (m <= 0) return '—';
      return '${m ~/ 60}h';
    } catch (_) { return '—'; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACCESOS RÁPIDOS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildAccesos(BuildContext ctx, String nombre, double baseCot) {
    final accesos = [
      (_blue,   Icons.fingerprint_rounded,      'Fichajes',    'Ver mis registros\nde fichaje'),
      (_amber,  Icons.beach_access_rounded,     'Vacaciones',  'Solicitar días\no consultar saldo'),
      (_green,  Icons.receipt_long_rounded,     'Nóminas',     'Ver mis nóminas\ny certificados'),
      (_purple, Icons.description_outlined,     'Documentos',  'Accede a tus\ndocumentos'),
      (_blue,   Icons.event_note_rounded,       'Solicitudes', 'Ver el estado\nde tus solicitudes'),
    ];

    return LayoutBuilder(builder: (_, c) {
      final wide = c.maxWidth > 500;
      return wide
        ? Row(children: [
            for (int i = 0; i < accesos.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _accesoCard(ctx, accesos[i].$1, accesos[i].$2,
                  accesos[i].$3, accesos[i].$4, nombre, baseCot)),
            ],
          ])
        : GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5,
            children: accesos.map((a) => _accesoCard(ctx, a.$1, a.$2, a.$3, a.$4, nombre, baseCot))
                .toList(),
          );
    });
  }

  Widget _accesoCard(BuildContext ctx, Color c, IconData icon, String titulo, String desc,
      String nombre, double baseCot) {
    return GestureDetector(
      onTap: () => _onAcceso(ctx, titulo, nombre, baseCot),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        decoration: BoxDecoration(
          color: _surf,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: c, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _text)),
            const SizedBox(height: 3),
            Text(desc, style: TextStyle(fontSize: 10.5, color: _sub, height: 1.3)),
          ])),
          Icon(Icons.arrow_forward_rounded, size: 16, color: _sub),
        ]),
      ),
    );
  }

  void _onAcceso(BuildContext ctx, String titulo, String nombre, double baseCot) {
    switch (titulo) {
      case 'Fichajes':
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            GestionFichajesScreen(empresaId: empresaId, esAdmin: modoAdmin)));
      case 'Vacaciones':
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            VacacionesScreen(empresaId: empresaId)));
      case 'Nóminas':
        NominasEmpleadoWidget.mostrar(ctx,
            empleadoId: _uid, empresaId: empresaId, nombreEmpleado: nombre);
      case 'Documentos':
        _abrirDocumentos(ctx, nombre);
      case 'Solicitudes':
        Navigator.push(ctx, MaterialPageRoute(builder: (_) =>
            NuevaSolicitudForm(empresaId: empresaId, empleadoIdFijo: _uid)));
      default:
        FluxToast.info(ctx, '$titulo — próximamente');
    }
  }

  void _abrirDocumentos(BuildContext ctx, String nombre) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Icon(Icons.description_outlined, color: _purple, size: 20),
              const SizedBox(width: 10),
              Text('Mis documentos', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A))),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close, size: 18,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                onPressed: () => Navigator.pop(ctx),
              ),
            ]),
          ),
          Expanded(child: DocumentosEmpleadoWidget(
            empleadoId: _uid,
            empresaId: empresaId,
            nombreEmpleado: nombre,
          )),
        ]),
      ),
    );
  }

  Future<void> _registrarEntrada(BuildContext ctx, String nombre) async {
    try {
      await FichajeService().ficharEntrada(
        empresaId: empresaId,
        empleadoId: _uid,
        empleadoNombre: nombre,
        dispositivoId: 'portal_empleado',
      );
      if (ctx.mounted) FluxToast.exito(ctx, 'Entrada registrada correctamente',
          title: 'Fichaje');
    } catch (e) {
      if (ctx.mounted) FluxToast.error(ctx, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _registrarSalida(BuildContext ctx, String? docId) async {
    try {
      await FichajeService().ficharSalida(
        empresaId: empresaId,
        empleadoId: _uid,
      );
      if (ctx.mounted) FluxToast.exito(ctx, 'Salida registrada correctamente',
          title: 'Fichaje');
    } catch (e) {
      if (ctx.mounted) FluxToast.error(ctx, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Editor horario (admin) ─────────────────────────────────────────────────
  void _mostrarEditorHorario(BuildContext ctx, Map<String, dynamic> actual) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HorarioEditorSheet(
        horarioActual: actual, isDark: isDark,
        onGuardar: (nuevo) async {
          try {
            await _horarioRef.set(nuevo, SetOptions(merge: true));
            if (ctx.mounted) FluxToast.exito(ctx, 'Horario guardado', title: 'Listo');
          } catch (e) {
            if (ctx.mounted) FluxToast.error(ctx, 'Error: $e');
          }
        },
      ),
    );
  }

  // ── Card helper ────────────────────────────────────────────────────────────
  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surf,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
          blurRadius: 10, offset: const Offset(0, 2))],
    ),
    child: child,
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// FICHAR BTN — botón con estado de carga
// ═════════════════════════════════════════════════════════════════════════════

class _FicharBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;
  const _FicharBtn({required this.label, required this.icon,
      required this.color, required this.onTap});
  @override
  State<_FicharBtn> createState() => _FicharBtnState();
}

class _FicharBtnState extends State<_FicharBtn> {
  bool _loading = false;

  Future<void> _press() async {
    if (_loading) return;
    setState(() => _loading = true);
    try { await widget.onTap(); } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: _loading ? null : _press,
    icon: _loading
        ? const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(widget.icon, size: 15),
    label: Text(widget.label, style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
    style: FilledButton.styleFrom(
      backgroundColor: widget.color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// TIME BAR — barra horizontal de tiempo (entrada → salida)
// ═════════════════════════════════════════════════════════════════════════════

class _TimeBar extends StatelessWidget {
  final DateTime entrada, salida;
  final bool isDark;
  final String eStr, sStr;

  const _TimeBar({
    required this.entrada, required this.salida,
    required this.isDark, required this.eStr, required this.sStr,
  });

  @override
  Widget build(BuildContext context) {
    // Rango de referencia: 07:00–20:00 = 780 min
    const refStart = 7 * 60;
    const refEnd   = 20 * 60;
    const refRange = refEnd - refStart;

    final eMins = entrada.hour * 60 + entrada.minute;
    final sMins = salida.hour  * 60 + salida.minute;
    final pctL  = ((eMins - refStart) / refRange).clamp(0.0, 1.0);
    final pctR  = ((sMins - refStart) / refRange).clamp(0.0, 1.0);

    return Row(children: [
      Text(eStr, style: TextStyle(fontSize: 11, color: isDark
          ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
      const SizedBox(width: 6),
      Expanded(child: LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth;
        return SizedBox(height: 8, child: Stack(children: [
          // Track
          Positioned.fill(child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
          )),
          // Fill
          Positioned(
            left: pctL * w, width: (pctR - pctL) * w,
            top: 0, bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ]));
      })),
      const SizedBox(width: 6),
      Text(sStr, style: TextStyle(fontSize: 11, color: isDark
          ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CIRCULAR PROGRESS
// ═════════════════════════════════════════════════════════════════════════════

class _CircularProgress extends StatelessWidget {
  final double value;
  final String label, sublabel;
  final Color color;
  final bool isDark;

  const _CircularProgress({
    required this.value, required this.label,
    required this.sublabel, required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 80, height: 80,
    child: Stack(alignment: Alignment.center, children: [
      CustomPaint(size: const Size(80, 80),
          painter: _ArcPainter(value: value, color: color, isDark: isDark)),
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A))),
        Text(sublabel, style: TextStyle(
            fontSize: 8.5,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            textAlign: TextAlign.center),
      ]),
    ]),
  );
}

class _ArcPainter extends CustomPainter {
  final double value;
  final Color color;
  final bool isDark;
  const _ArcPainter({required this.value, required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final c   = Offset(size.width / 2, size.height / 2);
    final r   = size.width / 2 - 5;
    final trk = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke ..strokeWidth = 8 ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color ..style = PaintingStyle.stroke
      ..strokeWidth = 8 ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: c, radius: r),
        -math.pi / 2, 2 * math.pi, false, trk);
    if (value > 0) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r),
          -math.pi / 2, 2 * math.pi * value, false, fill);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.value != value;
}

// ═════════════════════════════════════════════════════════════════════════════
// EDITOR DE HORARIO (Bottom Sheet)
// ═════════════════════════════════════════════════════════════════════════════

class _HorarioEditorSheet extends StatefulWidget {
  final Map<String, dynamic> horarioActual;
  final bool isDark;
  final Future<void> Function(Map<String, dynamic>) onGuardar;

  const _HorarioEditorSheet({
    required this.horarioActual,
    required this.isDark,
    required this.onGuardar,
  });

  @override
  State<_HorarioEditorSheet> createState() => _HorarioEditorSheetState();
}

class _HorarioEditorSheetState extends State<_HorarioEditorSheet> {
  static const _keys = ['lun','mar','mie','jue','vie','sab','dom'];
  static const _lbls = ['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];

  late Map<String, _DiaHorario> _dias;
  bool _guardando = false;

  Color get _bg     => widget.isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get _surf   => widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
  Color get _text   => widget.isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A);
  Color get _sub    => widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _border => widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _dias = { for (final k in _keys)
      k: _DiaHorario.fromMap(
          (widget.horarioActual[k] as Map?)?.cast<String, dynamic>() ?? {}) };
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    await widget.onGuardar({for (final e in _dias.entries) e.key: e.value.toMap()});
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: _bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
          const Icon(Icons.edit_calendar_rounded, color: Color(0xFF3B82F6), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('Horario semanal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _text))),
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: _sub))),
        ])),
        Padding(padding: const EdgeInsets.only(left: 20, bottom: 12),
            child: Text('Define el turno de cada día', style: TextStyle(fontSize: 12, color: _sub))),
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.46,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _keys.length,
            itemBuilder: (_, i) => _diaRow(_keys[i], _lbls[i]),
          ),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox(width: 15, height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 17),
            label: Text(_guardando ? 'Guardando...' : 'Guardar horario',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          )),
      ]),
    );
  }

  Widget _diaRow(String key, String label) {
    final dia = _dias[key]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
      decoration: BoxDecoration(
        color: _surf, borderRadius: BorderRadius.circular(11),
        border: Border.all(color: dia.libre ? _border : const Color(0xFF3B82F6).withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        SizedBox(width: 72, child: Text(label, style: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w600, color: _text))),
        GestureDetector(
          onTap: () => setState(() => _dias[key] = dia.copyWith(libre: !dia.libre)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: dia.libre
                  ? _sub.withValues(alpha: 0.1)
                  : const Color(0xFF22C55E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: dia.libre ? _border
                  : const Color(0xFF22C55E).withValues(alpha: 0.35)),
            ),
            child: Text(dia.libre ? 'Libre' : 'Trabaja',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: dia.libre ? _sub : const Color(0xFF22C55E))),
          ),
        ),
        const SizedBox(width: 8),
        if (!dia.libre) ...[
          Expanded(child: _tf(dia.entrada, 'Entrada',
              (v) => setState(() => _dias[key] = dia.copyWith(entrada: v)))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Text('→', style: TextStyle(color: _sub))),
          Expanded(child: _tf(dia.salida, 'Salida',
              (v) => setState(() => _dias[key] = dia.copyWith(salida: v)))),
        ] else const Spacer(),
      ]),
    );
  }

  Widget _tf(String val, String hint, ValueChanged<String> fn) => TextField(
    controller: TextEditingController(text: val)
      ..selection = TextSelection.fromPosition(TextPosition(offset: val.length)),
    onChanged: fn,
    keyboardType: TextInputType.datetime,
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _text),
    decoration: InputDecoration(
      hintText: hint, hintStyle: TextStyle(fontSize: 10, color: _sub),
      isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
      filled: true,
      fillColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
    ),
  );
}

class _DiaHorario {
  final String entrada, salida;
  final bool   libre;
  const _DiaHorario({this.entrada='', this.salida='', this.libre=true});

  factory _DiaHorario.fromMap(Map<String, dynamic> m) => _DiaHorario(
    entrada: m['entrada'] as String? ?? '',
    salida:  m['salida']  as String? ?? '',
    libre:   m['libre'] == true || (m['entrada'] as String? ?? '').isEmpty,
  );

  Map<String, dynamic> toMap() => {'entrada': entrada, 'salida': salida, 'libre': libre};

  _DiaHorario copyWith({String? entrada, String? salida, bool? libre}) => _DiaHorario(
    entrada: entrada ?? this.entrada,
    salida:  salida  ?? this.salida,
    libre:   libre   ?? this.libre,
  );
}
